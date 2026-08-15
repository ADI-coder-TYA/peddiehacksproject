import { Worker, Job } from 'bullmq';
import { GoogleGenerativeAI } from '@google/generative-ai';
import { supabase } from '../config/supabase.js';
import { getIO } from '../services/socketManager.js';
import { 
  redisConnection, 
  CLINICAL_INTAKE_QUEUE_NAME, 
  INTAKE_QUEUE_NAME,
  moveToDeadLetterQueue 
} from './queueManager.js';
import { generateEmbedding } from '../services/gemini.js';
import { extractFeatures } from '../utils/featureExtractor.js';
import { extractVerifiedAmount } from '../utils/grantExtractor.js';
import { extractInvoiceTotal, extractReceiptData } from '../services/receiptParser.js';
import { classifyCategoryDynamic } from '../utils/categoryClassifier.js';
import * as deepRankModel from '../services/deepRankModel.js';
import * as anomalyModel from '../services/anomalyModel.js';
import * as attritionModel from '../services/attritionModel.js';
import { evaluateFraudRisk } from '../services/fraudSentinel.js';
import { evaluateLifeSafety } from '../services/safetyGuardrails.js';
import { analyzeClinicalText } from '../services/nlpPipeline.js';
import { EsiLevel, ClaimStatus } from '../types/clinical.js';

const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY || 'dummy_key');

/**
 * Maps Crisis Severity Index (CSI) score & life-safety alerts to ESI Tier
 */
export function classifyEsiLevel(csiScore: number, isLifeSafetyAlert: boolean): EsiLevel {
  if (isLifeSafetyAlert || csiScore >= 0.85) {
    return 'ESI_1_CRITICAL';
  } else if (csiScore >= 0.60) {
    return 'ESI_2_EMERGENT';
  } else if (csiScore >= 0.35) {
    return 'ESI_3_URGENT';
  } else {
    return 'ROUTINE';
  }
}

/**
 * Formats ESI level into user-facing human title
 */
export function formatEsiDisplay(esi: EsiLevel, csi: number): string {
  switch (esi) {
    case 'ESI_1_CRITICAL':
      return `ESI Level 1 (Resuscitation / Critical - CSI ${csi.toFixed(2)})`;
    case 'ESI_2_EMERGENT':
      return `ESI Level 2 (Emergent / High Distress - CSI ${csi.toFixed(2)})`;
    case 'ESI_3_URGENT':
      return `ESI Level 3 (Urgent / Acute Relief - CSI ${csi.toFixed(2)})`;
    default:
      return `ESI Level 4 (Routine / Standard Copay - CSI ${csi.toFixed(2)})`;
  }
}

export const intakeWorker = new Worker(
  CLINICAL_INTAKE_QUEUE_NAME || INTAKE_QUEUE_NAME,
  async (job: Job) => {
    const claimId = job.data.claimId || job.data.ticketId || job.data.id;
    const rawMessage = job.data.rawMessage || job.data.description || '';
    const patientPhone = job.data.patientPhone || job.data.studentPhone || '+15550000000';
    let mediaUrl = job.data.mediaUrl || job.data.media_url || job.data.attachmentUrl || job.data.receiptUrl;
    const instId = job.data.institutionId || job.data.institution_id || 'inst-001';
    const jobId = job.id;

    console.log(`🩺 [Clinical Triage Worker] Starting processing for Job ${jobId} | Claim ${claimId}`);

    // 1. Fetch Claim record from database if mediaUrl or description wasn't fully supplied
    let dbClaim: any = null;
    try {
      const { data: claimData } = await supabase
        .from('claims')
        .select('*')
        .eq('id', claimId)
        .maybeSingle();

      if (claimData) {
        dbClaim = claimData;
        if (!mediaUrl && claimData.receipt_url) {
          mediaUrl = claimData.receipt_url;
        }
      } else {
        // Fallback: check tickets table
        const { data: ticketData } = await supabase
          .from('tickets')
          .select('*')
          .eq('id', claimId)
          .maybeSingle();
        if (ticketData) {
          dbClaim = ticketData;
          if (!mediaUrl && ticketData.media_url) {
            mediaUrl = ticketData.media_url;
          }
        }
      }
    } catch (dbErr) {
      console.warn(`[IntakeWorker] Failed to query existing claim ${claimId}:`, dbErr);
    }

    try {
      // 2. Life-Safety Hard Override Sentinel
      const lifeSafety = evaluateLifeSafety(rawMessage || dbClaim?.description || dbClaim?.raw_message || '');
      const isLifeSafetyAlert = lifeSafety.isLifeSafetyCritical;
      if (isLifeSafetyAlert) {
        console.log(`🚨 [Life-Safety Sentinel] Emergency Override for Claim ${claimId} | Locked Category: Mental Health`);
      }

      // 3. Layout-Preserving Receipt / Invoice OCR Extraction
      const receiptData = await extractReceiptData(mediaUrl);
      const attachmentExtractedText = receiptData.extractedText || '';
      let parsedReceiptAmount = receiptData.receiptAmount;
      let detectedAttachmentCurrency = receiptData.currency;

      // Fallback: Scan text for invoice totals
      const effectiveMessage = rawMessage || dbClaim?.description || dbClaim?.raw_message || '';
      if (parsedReceiptAmount === null && effectiveMessage) {
        const directInvoice = extractInvoiceTotal(effectiveMessage);
        if (directInvoice.amount !== null) {
          parsedReceiptAmount = directInvoice.amount;
          detectedAttachmentCurrency = directInvoice.currency;
        }
      }

      const combinedText = attachmentExtractedText && attachmentExtractedText.trim().length > 0
        ? (effectiveMessage ? `${effectiveMessage}\n\n[Attached Document]:\n${attachmentExtractedText}` : attachmentExtractedText)
        : effectiveMessage;

      // 4. Run local Hugging Face NLP Analysis & Keyword Extraction
      getIO().emit('job:progress', { jobId, ticketId: claimId, step: 'TRANSCRIPTION_COMPLETE' });
      const nlpAnalysis = await analyzeClinicalText(combinedText);

      // 5. Generate 768-dim embeddings via Google Gemini text-embedding-004
      console.log(`[IntakeWorker] Generating vector embeddings for claim ${claimId}`);
      getIO().emit('job:progress', { jobId, ticketId: claimId, step: 'POLICY_MATCHED' });
      
      let embedding: number[] = [];
      try {
        embedding = await generateEmbedding(combinedText);
      } catch (embErr) {
        try {
          const model = genAI.getGenerativeModel({ model: "text-embedding-004" });
          const res = await model.embedContent(combinedText);
          embedding = res.embedding.values;
        } catch {
          embedding = new Array(768).fill(0);
        }
      }

      if (!embedding || embedding.length !== 768) {
        embedding = new Array(768).fill(0);
      }

      // 6. Hybrid Policy Search Query against Supabase
      let matchedPolicy: any = null;
      try {
        const { data: searchResults } = await supabase.rpc('match_policies', {
          query_embedding: embedding,
          match_threshold: 0.65,
          match_count: 3
        });
        matchedPolicy = (searchResults && searchResults.length > 0) ? searchResults[0] : null;
      } catch (_) {}

      // 7. Dynamic Category Classification
      const parsedCategory = isLifeSafetyAlert
        ? lifeSafety.lockedCategory
        : await classifyCategoryDynamic(combinedText);

      // 8. Extract Features and Run DeepRank & Anomaly Inference
      getIO().emit('job:progress', { jobId, ticketId: claimId, step: 'ML_SCORED' });
      const { requestedAmount, receiptAmount, currency } = await extractVerifiedAmount(combinedText, mediaUrl);
      const effectiveReceiptAmount = parsedReceiptAmount !== null ? parsedReceiptAmount : receiptAmount;
      const effectiveCurrency: 'INR' | 'USD' = detectedAttachmentCurrency === 'INR' || currency === 'INR' || /INR|RS|₹|lakh|crore/i.test(combinedText) ? 'INR' : 'USD';
      const parsedAmount = effectiveReceiptAmount || requestedAmount || 0;
      
      const features = await extractFeatures(combinedText, parsedAmount);
      let deepRankScore = await deepRankModel.predict(features);
      if (isLifeSafetyAlert) {
        deepRankScore = Math.max(deepRankScore, 0.95);
      }
      const anomalyScore = await anomalyModel.predict(features);
      const attritionRisk = await attritionModel.predict(features);

      const csiScore = Math.min(Math.max(deepRankScore, 0.0), 1.0);

      // 9. Map CSI to Clinical Emergency Severity Index (ESI)
      const esiLevel = classifyEsiLevel(csiScore, isLifeSafetyAlert);
      const formattedEsi = formatEsiDisplay(esiLevel, csiScore);

      // 10. Fraud Sentinel Security Evaluation
      const fraudReport = await evaluateFraudRisk(
        claimId,
        patientPhone,
        mediaUrl,
        features,
        effectiveReceiptAmount || requestedAmount || undefined,
        isLifeSafetyAlert
      );

      const isFlagged = fraudReport.isFlagged;

      // 10.5. Resolve Per-Incident Policy Cap & Matched Policy ID from Knowledge Base
      let policyLimit = effectiveCurrency === 'INR' ? 100000 : 2500;
      let policyCapSource = 'Standard Institutional Baseline';
      let matchedPolicyId: string | null = null;
      try {
        const { data: matchedPolicyRows } = await supabase
          .from('policy_embeddings')
          .select('id, policy_name, max_coverage_limit, category')
          .eq('institution_id', instId)
          .or(`category.ilike.%${parsedCategory}%,policy_name.ilike.%${parsedCategory}%`)
          .order('max_coverage_limit', { ascending: false })
          .limit(1);

        if (matchedPolicyRows && matchedPolicyRows.length > 0) {
          matchedPolicyId = matchedPolicyRows[0].id;
          const matchedLimit = Number(matchedPolicyRows[0].max_coverage_limit);
          if (matchedLimit > 0) {
            policyLimit = matchedLimit;
            policyCapSource = `${matchedPolicyRows[0].policy_name} (₹${policyLimit})`;
          }
        }
      } catch (_) {}

      // 10.6. Resolve Patient Profile UUID for Foreign Key Binding
      let resolvedPatientId: string | null = null;
      try {
        const cleanPhone = patientPhone.replace(/[^\d]/g, '');
        const { data: profData } = await supabase
          .from('profiles')
          .select('id')
          .or(`phone.ilike.%${cleanPhone.slice(-8)}%,phone.eq.${patientPhone},email.ilike.%${job.data.email || ''}%`)
          .maybeSingle();

        if (profData) {
          resolvedPatientId = profData.id;
        } else {
          const { data: rosterData } = await supabase
            .from('patient_rosters')
            .select('id, patient_id, email, phone')
            .or(`phone.ilike.%${cleanPhone.slice(-8)}%,phone.eq.${patientPhone},email.ilike.%${job.data.email || ''}%`)
            .maybeSingle();

          if (rosterData) {
            const patientName = rosterData.email ? rosterData.email.split('@')[0].replace(/[._-]/g, ' ') : 'Registered Patient';
            const { data: createdProf } = await supabase.from('profiles').upsert({
              id: rosterData.id,
              email: rosterData.email || `${rosterData.patient_id || cleanPhone}@campushealth.edu`,
              full_name: patientName,
              role: 'PATIENT',
              institution_id: instId,
              phone: rosterData.phone || patientPhone,
              emergency_contact: 'Verified Institutional Patient Roster',
              alerts_enabled: true,
            }).select('id').maybeSingle();

            if (createdProf) {
              resolvedPatientId = createdProf.id;
            }
          }
        }
      } catch (pErr) {
        console.warn('[IntakeWorker] Patient ID resolution note:', pErr);
      }

      // 11. Calculate Copay Recommendation with Per-Incident Cap
      let finalCopay = 0.00;
      if (isFlagged) {
        finalCopay = 0.00;
      } else {
        const baseBill = effectiveReceiptAmount || requestedAmount || (effectiveCurrency === 'INR' ? 5000 : 250);
        if (esiLevel === 'ESI_1_CRITICAL') {
          // 100% coverage up to policy incident ceiling
          finalCopay = Math.min(baseBill, policyLimit);
        } else if (esiLevel === 'ESI_2_EMERGENT') {
          // 80% coverage up to policy incident ceiling
          finalCopay = Math.min(Math.round(baseBill * 0.8), Math.round(policyLimit * 0.85));
        } else if (esiLevel === 'ESI_3_URGENT') {
          // 50% coverage up to policy incident ceiling
          finalCopay = Math.min(Math.round(baseBill * 0.5), Math.round(policyLimit * 0.5));
        } else {
          // Routine copay relief
          finalCopay = Math.min(Math.round(baseBill * 0.3), Math.round(policyLimit * 0.3));
        }
      }

      // 12. Construct Clinical Audit Notes & Payout Disbursal Allocation
      const currencySymbol = effectiveCurrency === 'INR' ? '₹' : '$';
      const riskScore = (fraudReport?.riskScore || 0.0).toFixed(2);
      const invoiceLabel = effectiveReceiptAmount ? `${currencySymbol}${effectiveReceiptAmount}` : 'Unattached / Self-Reported';

      const clinicalNotes = [
        `• 🩺 ESI Triage: Evaluated as ${esiLevel} (Score: ${csiScore.toFixed(3)})`,
        `• 🧾 Invoice: Verified ${effectiveCurrency} ${invoiceLabel}`,
        `• 📋 Policy Cap: ${policyCapSource} [Max Cap: ${currencySymbol}${policyLimit}]`,
        `• 🛡️ Fraud Sentinel: ${isFlagged ? `FLAGGED (${fraudReport.flagReasons.join(', ')})` : `Clean (Risk: ${riskScore})`}`,
        `• 💳 Copay Allocation: Recommended ${currencySymbol}${finalCopay.toFixed(2)} based on ${esiLevel} clinical tier.`,
        isLifeSafetyAlert ? `• 🚨 LIFE SAFETY OVERRIDE: ${lifeSafety.crisisHotlineText}` : null,
      ].filter(Boolean).join('\n');

      let claimStatus: ClaimStatus = isFlagged ? 'Flagged' : 'Triage Active';
      let approvedAmount = 0.00;
      let payoutReference: string = isFlagged ? 'FLAGGED_AUDIT_REQUIRED' : 'PENDING_APPROVAL';
      let payoutMethod: string = isFlagged ? 'HELD_FOR_ADMIN_AUDIT' : 'DIRECT_HEALTHCARE_FACILITY';

      if (!isFlagged && (esiLevel === 'ESI_1_CRITICAL' || esiLevel === 'ESI_2_EMERGENT')) {
        claimStatus = 'Approved';
        approvedAmount = finalCopay;
        payoutMethod = effectiveCurrency === 'INR' ? 'RAZORPAY_INSTANT' : 'DIRECT_ACH';
        payoutReference = `TXN_MED_${Date.now()}_${Math.random().toString(36).substring(2, 7).toUpperCase()}`;
      }

      // 13. Update Database Write (claims primary table)
      const claimUpdatePayload: Record<string, any> = {
        status: claimStatus,
        patient_id: resolvedPatientId,
        esi_level: esiLevel,
        crisis_severity_index: csiScore,
        is_life_safety_alert: isLifeSafetyAlert,
        receipt_image_hash: fraudReport?.imageHash || null,
        extracted_bill_amount: effectiveReceiptAmount || null,
        recommended_copay_amount: finalCopay,
        approved_amount: approvedAmount,
        payout_reference: payoutReference,
        payout_method: payoutMethod,
        fraud_risk_score: fraudReport?.riskScore || 0.0,
        fraud_flags: isFlagged ? (fraudReport?.flagReasons?.join(' | ') || 'SUSPICIOUS_ANOMALY') : 'CLEAN_VERIFIED',
        matched_policy_id: matchedPolicyId,
        clinical_notes: clinicalNotes,
        clinical_category: parsedCategory,
        currency: effectiveCurrency,
        updated_at: new Date().toISOString(),
      };

      let savedClaim: any = null;
      try {
        const { data: updatedClaim, error: claimErr } = await supabase
          .from('claims')
          .update(claimUpdatePayload)
          .eq('id', claimId)
          .select()
          .maybeSingle();

        if (!claimErr && updatedClaim) {
          savedClaim = updatedClaim;
        }
      } catch (cErr) {
        console.warn('[IntakeWorker] Direct claims table update warning:', cErr);
      }

      // Sync to tickets table for backward compatibility
      try {
        const ticketUpdatePayload: Record<string, any> = {
          status: isFlagged ? 'Flagged' : (esiLevel === 'ESI_1_CRITICAL' ? 'Escalated' : 'Pending'),
          urgency_level: formattedEsi,
          parsed_category: parsedCategory,
          crisis_severity_index: csiScore,
          recommended_grant_amount: finalCopay,
          calculated_amount: finalCopay,
          currency: effectiveCurrency,
          thought_process: clinicalNotes,
          flag_reason: isFlagged ? fraudReport.flagReasons.join(' | ') : 'None',
          receipt_image_hash: fraudReport?.imageHash || null,
          fraud_risk_score: fraudReport?.riskScore || 0.0,
          updated_at: new Date().toISOString(),
        };

        const { data: updatedTicket } = await supabase
          .from('tickets')
          .update(ticketUpdatePayload)
          .eq('id', claimId)
          .select()
          .maybeSingle();

        if (!savedClaim && updatedTicket) {
          savedClaim = updatedTicket;
        }
      } catch (_) {}

      // 14. Telemetry Log
      console.log(`🩺 [Clinical Triage] Claim ${claimId} processed | ESI: ${esiLevel} | Copay Recommended: ${effectiveCurrency} ${finalCopay}`);

      // 15. Emit Socket.io events for real-time frontend UI update
      getIO().emit('claim:updated', savedClaim || { id: claimId, ...claimUpdatePayload });
      getIO().emit('ticket:updated', savedClaim || { id: claimId, ...claimUpdatePayload });
      getIO().emit('job:completed', {
        jobId,
        claimId,
        ticketId: claimId,
        result: {
          id: claimId,
          status: claimStatus,
          esiLevel,
          formattedEsi,
          crisisSeverityIndex: csiScore,
          recommendedCopayAmount: finalCopay,
          clinicalCategory: parsedCategory,
          currency: effectiveCurrency,
          clinicalNotes,
        },
      });

      return {
        status: claimStatus,
        esiLevel,
        csiScore,
        recommendedCopayAmount: finalCopay,
      };

    } catch (error: any) {
      console.error(`[IntakeWorker] Job ${job.id} failed: ${error.message}`);
      throw error;
    }
  },
  {
    connection: redisConnection,
    concurrency: 5,
  }
);

intakeWorker.on('failed', async (job: Job | undefined, error: Error) => {
  if (!job) return;
  console.error(`[IntakeWorker] Job ${job.id} failed on attempt ${job.attemptsMade}`);

  if (job.attemptsMade >= (job.opts.attempts || 3)) {
    console.error(`[IntakeWorker] Job ${job.id} exhausted retries. Moving to DLQ.`);
    await moveToDeadLetterQueue(job, error);
    getIO().emit('job:failed', {
      jobId: job.id,
      claimId: job.data.claimId || job.data.ticketId,
      error: error.message,
    });
  }
});

intakeWorker.on('completed', (job: Job) => {
  console.log(`🩺 [IntakeWorker] Clinical triage job ${job.id} completed successfully.`);
});

export default intakeWorker;
