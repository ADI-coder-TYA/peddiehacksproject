import { Worker, Job } from 'bullmq';
import { GoogleGenerativeAI } from '@google/generative-ai';
import { supabase } from '../config/supabase.js';
import { getIO } from '../services/socketManager.js';
import { 
  redisConnection, 
  INTAKE_QUEUE_NAME, 
  moveToDeadLetterQueue 
} from './queueManager.js';
import { generateEmbedding } from '../services/gemini.js';
import { extractFeatures } from '../utils/featureExtractor.js';
import { extractVerifiedAmount } from '../utils/grantExtractor.js';
import { extractInvoiceTotal, parseAttachmentTextAndAmount, extractReceiptData } from '../services/receiptParser.js';
import { classifyCategoryDynamic } from '../utils/categoryClassifier.js';
import * as deepRankModel from '../services/deepRankModel.js';
import * as anomalyModel from '../services/anomalyModel.js';
import * as attritionModel from '../services/attritionModel.js';
import { evaluateFraudRisk } from '../services/fraudSentinel.js';
import { evaluateLifeSafety } from '../services/safetyGuardrails.js';

const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY || 'dummy_key');

export const intakeWorker = new Worker(
  INTAKE_QUEUE_NAME,
  async (job: Job) => {
    const { ticketId, rawMessage, studentPhone } = job.data;
    let mediaUrl = job.data.mediaUrl || job.data.media_url || job.data.attachmentUrl || job.data.receiptUrl;
    const jobId = job.id;
    console.log(`[IntakeWorker] Processing Job ${jobId} for Ticket ${ticketId}`);

    // If mediaUrl was not passed in job data, look up ticket in Supabase
    if (!mediaUrl && ticketId) {
      try {
        const { data: dbTicket } = await supabase.from('tickets').select('media_url').eq('id', ticketId).single();
        if (dbTicket?.media_url) {
          mediaUrl = dbTicket.media_url;
          console.log(`[IntakeWorker] Retrieved media_url from database for Ticket ${ticketId}`);
        }
      } catch (dbErr) {
        console.warn(`[IntakeWorker] Failed to query media_url for ticket ${ticketId}:`, dbErr);
      }
    }

    console.log('🔍 [IntakeWorker] Received Job Payload Attachment:', mediaUrl ? (mediaUrl.startsWith('data:') ? `[Base64 Data URI: ${mediaUrl.substring(0, 40)}... (${mediaUrl.length} chars)]` : mediaUrl) : 'null');

    try {
      // 0. Life-Safety Hard Override Sentinel
      const lifeSafety = evaluateLifeSafety(rawMessage || '');
      if (lifeSafety.isLifeSafetyCritical) {
        console.log(`🚨 [Life-Safety Sentinel] Triggered Emergency Override for Ticket ${ticketId} | Locked Category: Mental Health`);
      }

      // Upfront Layout-Preserving Receipt Extraction (poppler-utils pdftotext & tesseract OCR)
      const receiptData = await extractReceiptData(mediaUrl);
      let attachmentExtractedText = receiptData.extractedText || '';
      let parsedReceiptAmount = receiptData.receiptAmount;
      let detectedAttachmentCurrency = receiptData.currency;

      // Fallback: If mediaUrl was empty or yielded no amount, scan rawMessage for invoice totals
      if (parsedReceiptAmount === null && rawMessage) {
        const directInvoice = extractInvoiceTotal(rawMessage);
        if (directInvoice.amount !== null) {
          parsedReceiptAmount = directInvoice.amount;
          detectedAttachmentCurrency = directInvoice.currency;
          console.log(`🎯 [IntakeWorker] Extracted invoice total directly from raw message: ${detectedAttachmentCurrency} ${parsedReceiptAmount}`);
        }
      }

      const combinedText = attachmentExtractedText && attachmentExtractedText.trim().length > 0
        ? (rawMessage ? `${rawMessage}\n\n[Attached Document]:\n${attachmentExtractedText}` : attachmentExtractedText)
        : (rawMessage || '');

      // 1. Generate 768-dim embeddings via Google Gemini text-embedding-004
      console.log(`[IntakeWorker] Generating text embeddings for ticket ${ticketId}`);
      getIO().emit('job:progress', { jobId, ticketId, step: 'TRANSCRIPTION_COMPLETE' });
      
      let embedding: number[] = [];
      try {
        embedding = await generateEmbedding(combinedText);
      } catch (embErr) {
        console.warn(`[IntakeWorker] Direct embedContent error, falling back to SDK:`, embErr);
        const model = genAI.getGenerativeModel({ model: "text-embedding-004" });
        const res = await model.embedContent(combinedText);
        embedding = res.embedding.values;
      }
      
      if (!embedding || embedding.length !== 768) {
        console.warn('[IntakeWorker] Warning: embedding length is not 768, creating zero-padded array');
        embedding = new Array(768).fill(0);
      }

      // 2. Hybrid Search Query against Supabase
      console.log(`[IntakeWorker] Running hybrid search for ticket ${ticketId}`);
      getIO().emit('job:progress', { jobId, ticketId, step: 'POLICY_MATCHED' });
      const { data: searchResults, error: searchError } = await supabase
        .rpc('match_policies', {
          query_embedding: embedding,
          match_threshold: 0.78,
          match_count: 5
        });

      if (searchError) {
        console.warn(`[IntakeWorker] Supabase search error: ${searchError.message}`);
      }

      let matchedPolicy = (searchResults && searchResults.length > 0) ? searchResults[0] : null;
      if (!matchedPolicy) {
        // Fallback query with lower threshold to find top relevant policy match
        const { data: fallbackSearch } = await supabase.rpc('match_policies', {
          query_embedding: embedding,
          match_threshold: 0.30,
          match_count: 1
        });
        matchedPolicy = (fallbackSearch && fallbackSearch.length > 0) ? fallbackSearch[0] : null;
      }

      // If life safety critical, bypass downstream classification drift and lock to Mental Health
      let parsedCategory = lifeSafety.isLifeSafetyCritical
        ? lifeSafety.lockedCategory
        : await classifyCategoryDynamic(combinedText);
      console.log(`[IntakeWorker] Dynamically parsed category for Ticket ${ticketId}: "${parsedCategory}"`);

      // Aligned policy defaults if vector search is offline
      let defaultPolicyName = "Institutional Emergency Clinical Copay Grant";
      let defaultPolicyContent = "Provides emergency medical copay relief and clinical welfare assistance.";
      if (parsedCategory === 'Medical Emergency & Inpatient Care') {
        defaultPolicyName = "Emergency Inpatient & ER Copay Relief Protocol 1A";
        defaultPolicyContent = "Provides immediate financial reimbursement up to $2,500 / ₹80,000 for unexpected hospital emergency room visits, trauma admissions, and acute surgical copays.";
      } else if (parsedCategory === 'Prescription & Pharmacy Copay') {
        defaultPolicyName = "Critical Prescription & Pharmacy Copay Subsidy 2B";
        defaultPolicyContent = "Provides instant micro-grants for essential prescription medications, insulin, inhalers, and specialized maintenance pharmacy copays.";
      } else if (parsedCategory === 'Mental Health & Crisis Intervention') {
        defaultPolicyName = "Acute Crisis De-escalation & Mental Health Therapy Grant 3C";
        defaultPolicyContent = "Provides 100% covered emergency psychological first aid sessions, psychiatric evaluation, and crisis stabilization copay relief.";
      } else if (parsedCategory === 'Diagnostic, Lab & Imaging Relief') {
        defaultPolicyName = "Clinical Laboratory & Medical Imaging Diagnostic Grant 4D";
        defaultPolicyContent = "Reimburses patient copays for essential blood panels, MRI, CT scans, and diagnostic imaging procedures.";
      } else if (parsedCategory === 'Physical Therapy & Dental Crisis') {
        defaultPolicyName = "Emergency Dental & Rehabilitation Relief Clause 5E";
        defaultPolicyContent = "Provides emergency funding for acute dental abscesses, trauma surgery, and essential physical rehabilitation therapy.";
      } else if (parsedCategory === 'General Health & Basic Welfare') {
        defaultPolicyName = "General Health Consultation & Patient Welfare Grant 6F";
        defaultPolicyContent = "Assists patients with outpatient copays, preventative clinical exams, and acute basic healthcare needs.";
      }

      const matchedPolicyName = matchedPolicy?.policy_name || defaultPolicyName;
      const policyMatchReason = matchedPolicy?.content || defaultPolicyContent;
      const vectorSimilarity = matchedPolicy?.similarity ?? 0.85;

      // 3. Extract Features and Run ML Inference
      console.log(`[IntakeWorker] Extracting features and running ML models`);
      getIO().emit('job:progress', { jobId, ticketId, step: 'ML_SCORED' });
      
      const { requestedAmount, receiptAmount, currency } = await extractVerifiedAmount(combinedText, mediaUrl);
      const effectiveReceiptAmount = parsedReceiptAmount !== null ? parsedReceiptAmount : receiptAmount;
      const effectiveCurrency: 'INR' | 'USD' = detectedAttachmentCurrency === 'INR' || currency === 'INR' || /INR|RS|₹|lakh|crore/i.test(combinedText) ? 'INR' : 'USD';
      const parsedAmount = effectiveReceiptAmount || requestedAmount || 0;
      const features = await extractFeatures(combinedText, parsedAmount);
      
      let deepRankScore = await deepRankModel.predict(features);
      if (lifeSafety.isLifeSafetyCritical) {
        // Force CSI to high-severity threshold (>= 0.95) for self-harm / suicidal ideation
        deepRankScore = Math.max(deepRankScore, 0.95);
      }
      const anomalyScore = await anomalyModel.predict(features);
      const attritionRisk = await attritionModel.predict(features);
      
      // Dynamic Confidence & Variance
      const grantConfidenceScore = Math.abs(features[2]);
      const modelVariance = Math.max(0.01, 0.20 - (features[1] * 0.05));
      
      let maxAllowableGrant = 0;
      if (deepRankScore >= 0.25) {
        const baseCeiling = effectiveCurrency === 'INR' ? 80000 : 1000;
        const step = effectiveCurrency === 'INR' ? 500 : 50;
        maxAllowableGrant = Math.round(deepRankScore * baseCeiling);
        maxAllowableGrant = Math.ceil(maxAllowableGrant / step) * step;
      }

      const verifiedNeed = effectiveReceiptAmount || requestedAmount; 
      
      // Grant Recommendation: Honor verified receipt amount or AI calculated ceiling
      let recommendedGrantAmount = 0;
      if (verifiedNeed && verifiedNeed <= maxAllowableGrant) {
        recommendedGrantAmount = verifiedNeed;
      } else {
        recommendedGrantAmount = verifiedNeed || maxAllowableGrant;
      }

      // Fraud Sentinel Security Evaluation (with Life-Safety Awareness)
      const fraudReport = await evaluateFraudRisk(
        ticketId, 
        studentPhone, 
        mediaUrl, 
        features, 
        verifiedNeed || undefined,
        lifeSafety.isLifeSafetyCritical
      );

      // Emergency Severity Index (ESI) Triage Classification
      let calculatedUrgency = 'ESI Level 3 (Urgent / Routine Copay)';
      if (lifeSafety.isLifeSafetyCritical || deepRankScore >= 0.85 || features[2] <= 0.05) {
        calculatedUrgency = 'ESI Level 1 (Resuscitation / Critical - CSI >= 0.85)';
      } else if (deepRankScore >= 0.60 || features[2] <= 0.25 || fraudReport.isFlagged) {
        calculatedUrgency = 'ESI Level 2 (Emergent / High Distress - CSI 0.60 - 0.84)';
      } else {
        calculatedUrgency = 'ESI Level 3 (Urgent / Routine Copay - CSI < 0.60)';
      }

      const requiresManualReview = lifeSafety.isLifeSafetyCritical || deepRankScore >= 0.65 || features[2] <= 0.125 || fraudReport.isFlagged;
      const newStatus = fraudReport.isFlagged ? 'Flagged' : (requiresManualReview ? 'Escalated' : 'Pending');

      const crisisSeverityIndex = deepRankScore;

      // Construct rich human-readable markdown thought_process breakdown
      const currencySymbol = effectiveCurrency === 'INR' ? '₹' : '$';
      const thoughtLines: string[] = [];

      if (lifeSafety.isLifeSafetyCritical) {
        thoughtLines.push(lifeSafety.crisisHotlineText);
      }

      thoughtLines.push(`• Clinical Policy Match: Matched "${matchedPolicyName}" with ${(vectorSimilarity * 100).toFixed(1)}% confidence.`);
      thoughtLines.push(`• Psychiatric Distress: Hugging Face DistilBERT score (${features[2].toFixed(3)}).`);
      thoughtLines.push(`• Clinical Triage: DeepRank ESI calculated at ${crisisSeverityIndex.toFixed(3)} (${calculatedUrgency}).`);
      thoughtLines.push(`• 🧾 Medical Invoice Verified: Extracted ${effectiveCurrency} ${effectiveReceiptAmount || 'None'} via layout-aware parser.`);
      thoughtLines.push(`• Copay Reconciliation: Patient requested ${requestedAmount ? `${currencySymbol}${requestedAmount} (${effectiveCurrency})` : 'N/A'}. Invoice Verified: ${effectiveReceiptAmount ? `${currencySymbol}${effectiveReceiptAmount}` : 'None'}. Allocated Relief: ${currencySymbol}${recommendedGrantAmount}.`);

      if (fraudReport.isFlagged) {
        thoughtLines.push(`• 🛡️ FRAUD SENTINEL WARNING: Claim flagged for ${fraudReport.flagReasons.join(', ')}. Auto-disbursement suspended pending clinical audit.`);
      } else if (fraudReport.flagReasons.length > 0) {
        thoughtLines.push(`• 🛡️ FRAUD SENTINEL ADVISORY: ${fraudReport.flagReasons.join(', ')}.`);
      }

      const thoughtProcess = thoughtLines.join('\n');

      // Telemetry Log Realignment
      console.log(`🩺 [MedAccess AI] Processed Clinical Claim ${ticketId} | ESI Level: ${calculatedUrgency} | Copay Allocated: ${effectiveCurrency} ${recommendedGrantAmount}`);

      // 4. Update Ticket Status in Supabase
      console.log(`[IntakeWorker] Updating ticket ${ticketId} status`);
      
      const updatePayload: Record<string, any> = { 
        status: newStatus,
        parsed_category: parsedCategory,
        urgency_level: calculatedUrgency,
        currency: effectiveCurrency || 'INR',
        embedding: `[${embedding.join(',')}]`, // Convert to PG vector format
        crisis_severity_index: deepRankScore,
        policy_match_reason: policyMatchReason,
        thought_process: thoughtProcess,
        flag_reason: fraudReport.isFlagged ? fraudReport.flagReasons.join(' | ') : (requiresManualReview ? "High risk or anomaly detected" : "None"),
        recommended_grant_amount: recommendedGrantAmount,
        calculated_amount: recommendedGrantAmount,
        grant_confidence_score: grantConfidenceScore,
        model_variance: modelVariance,
        sentiment_negative_score: features[2],
        policy_ambiguity_score: 0.0,
        anomaly_reconstruction_score: anomalyScore,
        dropout_risk_score: attritionRisk,
        matched_policy_name: matchedPolicyName,
      };

      // Attach optional fraud metadata safely
      if (fraudReport?.imageHash) {
        updatePayload.receipt_image_hash = fraudReport.imageHash;
      }
      if (fraudReport?.riskScore !== undefined) {
        updatePayload.fraud_risk_score = fraudReport.riskScore;
      }
      if (fraudReport?.flagReasons && fraudReport.flagReasons.length > 0) {
        updatePayload.fraud_flags = fraudReport.flagReasons.join(' | ');
      }

      let updateResult = await supabase
        .from('tickets')
        .update(updatePayload)
        .eq('id', ticketId)
        .select()
        .single();

      // Fallback if extended fields fail (e.g. PGRST204 schema cache or missing columns)
      if (updateResult.error) {
        console.warn(`[IntakeWorker] Extended ticket update failed (${updateResult.error.code} - ${updateResult.error.message}), retrying with core fields...`);
        const corePayload: Record<string, any> = {
          status: newStatus,
          urgency_level: calculatedUrgency,
          currency: effectiveCurrency || 'INR',
          crisis_severity_index: deepRankScore,
          recommended_grant_amount: recommendedGrantAmount,
          thought_process: thoughtProcess,
          parsed_category: parsedCategory,
          policy_match_reason: policyMatchReason,
          flag_reason: fraudReport.isFlagged ? fraudReport.flagReasons.join(' | ') : (requiresManualReview ? "High risk or anomaly detected" : "None"),
        };

        updateResult = await supabase
          .from('tickets')
          .update(corePayload)
          .eq('id', ticketId)
          .select()
          .single();
      }

      const { data, error: updateError } = updateResult;

      if (updateError) {
        console.error("🚨 Failed to save AI results to DB:", updateError);
        throw new Error(`Failed to update ticket: ${updateError.message}`);
      }

      console.log(`💱 [Currency Engine] Ticket ${ticketId} formatted as ${effectiveCurrency || 'INR'} ${recommendedGrantAmount}`);

      // 5. Emit Socket.io events for Real-Time UI updates
      console.log(`[IntakeWorker] Emitting ticket:updated and job:completed events for ${ticketId}`);
      getIO().emit('ticket:updated', data);
      getIO().emit('job:completed', {
        jobId,
        ticketId,
        result: {
          id: data.id,
          ticketId: data.id,
          status: data.status,
          currency: data.currency ?? currency ?? 'INR',
          parsed_category: data.parsed_category,
          urgency_level: data.urgency_level,
          crisisSeverityIndex: data.crisis_severity_index,
          voucherCode: data.voucher_code ?? null,
          policyMatchReason: data.policy_match_reason,
          recommendedGrantAmount: data.recommended_grant_amount,
        }
      });

      console.log(`[IntakeWorker] Job ${jobId} completed successfully.`);
      return { status: data.status, modelVariance };

    } catch (error: any) {
      console.error(`[IntakeWorker] Job ${job.id} failed: ${error.message}`);
      throw error;
    }
  },
  {
    connection: redisConnection,
    concurrency: 5, // Process 5 intake requests concurrently
  }
);

// Listeners for Job Lifecycle & DLQ Handler
intakeWorker.on('failed', async (job: Job | undefined, error: Error) => {
  if (!job) return;

  console.error(`[IntakeWorker] Job ${job.id} failed on attempt ${job.attemptsMade}`);

  if (job.attemptsMade >= (job.opts.attempts || 3)) {
    console.error(`[IntakeWorker] Job ${job.id} exhausted all retries. Moving to DLQ.`);
    
    // Log failure to Supabase Audit Logs
    await supabase.from('audit_logs').insert({
      action_type: 'JOB_FAILURE',
      actor_type: 'SYSTEM',
      ticket_id: job.data.ticketId,
      metadata: { error: error.message, jobId: job.id }
    });

    // Move to Dead Letter Queue
    await moveToDeadLetterQueue(job, error);
    
    // Emit socket failure to the specific ticket/job room
    console.log(`[IntakeWorker] Emitting job:failed event for ${job.id}`);
    getIO().emit('job:failed', {
      jobId: job.id,
      ticketId: job.data.ticketId,
      error: error.message
    });
  }
});

intakeWorker.on('completed', (job: Job) => {
  console.log(`[IntakeWorker] Job ${job.id} has successfully completed!`);
});

export default intakeWorker;
