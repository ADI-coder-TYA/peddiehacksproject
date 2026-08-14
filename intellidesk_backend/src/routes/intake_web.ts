// ============================================================
//  IntelliDesk EduAccess — Web / Flutter Client Intake Route
//  POST /api/v1/intake/web
//
//  Accepts multipart (text + optional file attachment) or JSON.
//  Unlike the Twilio SMS intake, this route:
//   - Returns a JSON response (not TwiML)
//   - Includes a voucher code in the response for auto-approved cases
//   - Handles image / PDF attachments via multer memory storage
// ============================================================

import { Router, Request, Response } from 'express';
import multer from 'multer';
import { processMultimodalIntake, generateEmbedding, parseMultimodalInput, searchMatchingPolicies } from '../services/gemini.js';
import { supabase } from '../config/supabase.js';
import { evaluateAndExecute } from '../services/workflow.js';
import { logAuditEvent } from '../services/auditLogger.js';
import { predictSequenceAttritionRisk } from '../services/attritionModel.js';
import { predictOptimalGrant } from '../services/grantOptimizerModel.js';
import { calculateAnomalyScore } from '../services/anomalyModel.js';
import { getIO } from '../services/socketManager.js';
import { v4 as uuidv4 } from 'uuid';

// ─── multer: memory storage for the optional attachment field ─

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 10 * 1024 * 1024, files: 1 }, // 10 MB
  fileFilter: (_req, file, cb) => {
    const allowed = [
      'image/jpeg', 'image/png', 'image/webp',
      'application/pdf',
      'application/msword',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    ];
    if (allowed.includes(file.mimetype)) {
      cb(null, true);
    } else {
      cb(new Error(`File type "${file.mimetype}" is not supported.`));
    }
  },
});

const webIntakeRouter = Router();

// ── Voucher generation helper ──────────────────────────────────

function generateVoucherCode(): string {
  return `EDUAID-${uuidv4().slice(0, 8).toUpperCase()}`;
}

// ─────────────────────────────────────────────────────────────
//  POST /  (mounted at /api/v1/intake/web)
// ─────────────────────────────────────────────────────────────

webIntakeRouter.post(
  '/',
  upload.single('attachment'),
  async (req: Request, res: Response) => {
    try {
      // ── 1. Extract fields ───────────────────────────────────
      // Supports both multipart/form-data and application/json bodies.
      const message: string =
        (req.body?.message as string | undefined)?.trim() ?? '';
      const studentName: string =
        (req.body?.studentName as string | undefined)?.trim() ?? 'Anonymous';
      const studentContact: string =
        (req.body?.studentContact as string | undefined)?.trim() ?? '';

      if (!message && !req.file) {
        res.status(400).json({
          error: 'Please provide a message or attach a supporting document.',
        });
        return;
      }

      // ── 2. Build context text for the AI ───────────────────
      let contextText = message;
      let flagReason: string | null = null;
      let mediaPending = false;
      let mediaEmbedding: number[] | null = null;

      if (req.file) {
        try {
          const parsedMedia = await parseMultimodalInput(
            req.file.buffer,
            req.file.mimetype,
            "Extract any text, narratives, or financial amounts."
          );
          
          mediaEmbedding = await generateEmbedding(parsedMedia.narrative);
          contextText = `${message}\n\n[Media Content - Language: ${parsedMedia.detectedLanguage}]\nNarrative: ${parsedMedia.narrative}\nExtracted Amounts: ${parsedMedia.amounts.join(', ')}`;
        } catch (error: any) {
          console.error('[WebIntake] Media parsing failed:', error);
          flagReason = 'Media parsing failed: ' + error.message;
          mediaPending = true;
          const mimeNote = req.file.mimetype.startsWith('image/')
            ? `[Student attached an image file: "${req.file.originalname}"]`
            : `[Student attached a document: "${req.file.originalname}" (${req.file.mimetype})]`;
          contextText = `${message}\n\n${mimeNote}`;
        }
      }

      // ── 3. AI multimodal intake ─────────────────────────────
      const parsedResult = await processMultimodalIntake(
        contextText,
        undefined, // no remote media URL for web uploads
      );

      // ── 4. Policy hybrid search ───────────────────────────
      const matchedPolicies = await searchMatchingPolicies(parsedResult.plainTextSummary, req.institution_id!);

      const policyNames =
        matchedPolicies && matchedPolicies.length > 0
          ? matchedPolicies.map((p: any) => p.policy_name).join(', ')
          : 'None';

      const policyMatchReason =
        `reliesOnMedicalOrAccommodation:${parsedResult.reliesOnMedicalOrAccommodation}` +
        (policyNames !== 'None' ? ` | Matched Policies: ${policyNames}` : '');

      // ── 5. Auto-approval & Fraud logic ────────────────────────
      const topMatch = matchedPolicies?.[0];
      const rrfScore = topMatch?.rrf_score || 0;
      
      let status = 'Pending';
      let autoApprove = false;
      let voucherCode: string | null = null;
      let fraudMatchId: string | null = null;

      if (mediaEmbedding) {
        const { data: matchedDuplicates } = await supabase.rpc('check_duplicate_evidence', {
          query_embedding: mediaEmbedding,
          match_threshold: 0.95,
          p_institution_id: req.institution_id
        });
        if (matchedDuplicates && matchedDuplicates.length > 0) {
          fraudMatchId = matchedDuplicates[0].id;
        }
      }

      if (fraudMatchId) {
         status = 'Escalated';
         flagReason = `POTENTIAL FRAUD: Duplicate evidence detected matching Ticket ID ${fraudMatchId}`;
      } else if (mediaPending) {
         status = 'Pending';
      } else if (rrfScore < 0.015 || parsedResult.isAmbiguousDistress) {
         status = 'Escalated';
         flagReason = 'Low Confidence Policy Match';
      } else {
        autoApprove =
          parsedResult.requestedAmount <= 200 &&
          parsedResult.urgency !== 'Urgent' &&
          matchedPolicies?.length > 0;
        
        status = autoApprove ? 'Auto-Approved' : 'Pending';
        if (autoApprove && parsedResult.category !== 'Mental Health & Crisis Intervention') {
          voucherCode = generateVoucherCode();
        }
      }

      // ── 6. Calculate Attrition Risk ──────────────────────────
      const dropoutRiskScore = await predictSequenceAttritionRisk(
        studentContact || 'web-client'
      );

      // ── X. Calculate Autoencoder Anomaly Score ─────────────────
      // 4-feature vector aligned with CSV-trained AnomalyAutoencoder:
      //   [word_count_norm, urgent_keyword_count_norm, sentiment_score, historical_ticket_count_norm]
      const wordCountNorm          = Math.min(1, contextText.split(/\s+/).length / 500);
      const urgentKeywordCountNorm = parsedResult.urgency === 'Urgent' ? 1.0
                                   : parsedResult.urgency === 'High'   ? 0.6
                                   : parsedResult.urgency === 'Routine' ? 0.3 : 0.0;
      const sentimentScore         = parsedResult.sentimentNegativeScore ?? 0.5;
      const historicalCountNorm    = Math.min(1, dropoutRiskScore); // proxy: attrition risk correlates with ticket history

      const featureVector = [
        wordCountNorm,
        urgentKeywordCountNorm,
        sentimentScore,
        historicalCountNorm,
      ];
      
      const reconstructionLoss = await calculateAnomalyScore(featureVector);
      
      if (reconstructionLoss > 0.08 && status !== 'Escalated') {
         status = 'Escalated';
         flagReason = `ANOMALY DETECTED: High Reconstruction Error (${reconstructionLoss.toFixed(4)}) - Possible Fraud or Bot Attack`;
      }

      // ── 7. Calculate Optimal Grant ───────────────────────────
      let finalAmount = parsedResult.requestedAmount;
      let grantConfidenceScore = null;
      let recommendedGrantAmount = null;

      let modelVariance = null;

      if (status === 'Auto-Approved' && parsedResult.category !== 'Mental Health & Crisis Intervention') {
        const grantPrediction = await predictOptimalGrant({
          dropoutRiskScore,
          requestedAmount: parsedResult.requestedAmount,
          institutionId: req.institution_id!,
          urgencyLevel: parsedResult.urgency
        });
        finalAmount = grantPrediction.recommendedAmount;
        recommendedGrantAmount = grantPrediction.recommendedAmount;
        grantConfidenceScore = grantPrediction.confidenceScore;
        modelVariance = grantPrediction.variance;
        
        if (modelVariance > 0.035) {
          status = 'Escalated';
          flagReason = `HIGH MODEL UNCERTAINTY: Epistemic Variance (${modelVariance.toFixed(4)}) exceeds threshold. Manual Dean review required.`;
        }
      }

      // ── 8. Persist ticket ───────────────────────────────────
      const { data: insertedTicket, error: insertError } = await supabase
        .from('tickets')
        .insert({
          institution_id: req.institution_id,
          student_phone: studentContact || 'web-client',
          student_name: studentName,
          raw_message: contextText,
          media_url: req.file
            ? `local-upload:${req.file.originalname}`
            : null,
          media_embedding: mediaEmbedding,
          parsed_category: parsedResult.category,
          urgency_level: parsedResult.urgency,
          calculated_amount: finalAmount,
          status,
          policy_match_reason: policyMatchReason,
          flag_reason: flagReason,
          voucher_code: voucherCode,
          resolved_at: status === 'Auto-Approved' ? new Date().toISOString() : null,
          dropout_risk_score: dropoutRiskScore,
          recommended_grant_amount: recommendedGrantAmount,
          grant_confidence_score: grantConfidenceScore,
          model_variance: modelVariance,
          crisis_severity_index: null, // To be updated via background ranking if needed, or initialized here
          sentiment_negative_score: parsedResult.sentimentNegativeScore,
          multi_department_involvement: parsedResult.multiDepartmentInvolvement,
          policy_ambiguity_score: parsedResult.policyAmbiguityScore,
          anomaly_reconstruction_score: reconstructionLoss,
        })
        .select('id')
        .single();

      if (insertError || !insertedTicket) {
        console.error("🚨 TICKET CREATION FAILED:", insertError);
        console.error('[WebIntake] Supabase insert error:', insertError);
        res.status(500).json({ error: 'Failed to save your request. Please try again.' });
        return;
      }

      if (fraudMatchId) {
        await logAuditEvent(req.institution_id!, insertedTicket.id, 'FRAUD_ALERT', 'AI_AGENT', {
           matched_ticket_id: fraudMatchId,
           notes: flagReason
        });
      } else if (autoApprove) {
        await logAuditEvent(req.institution_id!, insertedTicket.id, 'AUTO_APPROVAL', 'AI_AGENT', {
          policy_match_reason: policyMatchReason,
          amount_disbursed: finalAmount
        });
      } else if (status === 'Escalated' && flagReason === 'Low Confidence Policy Match') {
        await logAuditEvent(req.institution_id!, insertedTicket.id, 'POLICY_MATCH_FAILURE', 'AI_AGENT', {
           rrf_score: rrfScore,
           is_ambiguous_distress: parsedResult.isAmbiguousDistress,
           notes: 'Escalated due to low confidence or ambiguous distress.'
        });
      } else if (status === 'Escalated' && reconstructionLoss > 0.08) {
        await logAuditEvent(req.institution_id!, insertedTicket.id, 'ANOMALY_FLAG', 'AI_AGENT', {
           reconstruction_loss: reconstructionLoss,
           notes: flagReason
        });
      } else if (status === 'Escalated' && modelVariance && modelVariance > 0.035) {
        await logAuditEvent(req.institution_id!, insertedTicket.id, 'UNCERTAINTY_ESCALATION', 'AI_AGENT', {
           variance: modelVariance,
           notes: flagReason
        });
      }

      // ── 9. Background workflow ──────────────────────────────
      evaluateAndExecute(insertedTicket.id).catch((e) =>
        console.error('[WebIntake] Workflow error:', e),
      );

      // ── 10. Real-time broadcast to admin dashboard ───────────
      try {
        const io = getIO();
        io.emit('ticket:created', {
          id: insertedTicket.id,
          category: parsedResult.category,
          urgency: parsedResult.urgency,
          status,
          studentName,
        });
      } catch {
        // Socket not initialised during tests — silently skip
      }

      // ── 11. JSON response to Flutter client ─────────────────
      const responseBody: Record<string, unknown> = {
        success: true,
        ticketId: insertedTicket.id,
        status,
        category: parsedResult.category,
        urgencyLevel: parsedResult.urgency,
        summary: parsedResult.plainTextSummary,
        matchedPolicies: policyNames,
        message:
          status === 'Auto-Approved'
            ? `Your ${parsedResult.category} request has been automatically approved.`
            : `Your request has been received and will be reviewed by the welfare team.`,
      };

      // Include voucher code if applicable
      if (voucherCode) {
        responseBody.voucherCode = voucherCode;
      }

      res.status(201).json(responseBody);
    } catch (error) {
      console.error('[WebIntake] Unhandled error:', error);
      res.status(500).json({
        error: 'An unexpected error occurred. Please try again or contact the Student Welfare Office.',
      });
    }
  }
);

export default webIntakeRouter;
