import { Router, Request, Response } from 'express';
import { processMultimodalIntake, searchMatchingPolicies } from '../services/gemini.js';
import { supabase } from '../config/supabase.js';
import { evaluateAndExecute } from '../services/workflow.js';
import { getIO } from '../services/socketManager.js';
import { logAuditEvent } from '../services/auditLogger.js';
import { predictSequenceAttritionRisk } from '../services/attritionModel.js';
import { predictOptimalGrant } from '../services/grantOptimizerModel.js';
import { calculateAnomalyScore } from '../services/anomalyModel.js';
import twilio from 'twilio';

const router = Router();
const MessagingResponse = twilio.twiml.MessagingResponse;

router.post('/', async (req: Request, res: Response) => {
  try {
    const institutionId = (req.query.institutionId as string) || process.env.DEFAULT_INSTITUTION_ID;
    if (!institutionId) {
      res.status(400).send('Missing institution ID');
      return;
    }

    const { Body, From, MediaUrl0 } = req.body;

    if (!Body || !From) {
      res.status(400).send('Missing Body or From');
      return;
    }

    const parsedResult = await processMultimodalIntake(Body, MediaUrl0);

    const matchedPolicies = await searchMatchingPolicies(parsedResult.plainTextSummary, institutionId);

    let policyMatchReason = `reliesOnMedicalOrAccommodation:${parsedResult.reliesOnMedicalOrAccommodation}`;
    if (matchedPolicies && matchedPolicies.length > 0) {
        policyMatchReason += ` | Matched Policy: ${matchedPolicies[0].policy_name}`;
    }

    let status = 'Pending';
    let flagReason: string | null = null;
    
    if (parsedResult.requestedAmount <= 200 && parsedResult.urgency !== 'Urgent') {
        status = 'Auto-Approved';
    }

    const dropoutRiskScore = await predictSequenceAttritionRisk(From);

    // 4-feature vector aligned with CSV-trained AnomalyAutoencoder:
    //   [word_count_norm, urgent_keyword_count_norm, sentiment_score, historical_ticket_count_norm]
    const wordCountNorm          = Math.min(1, Body.split(/\s+/).length / 500);
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

    let finalAmount = parsedResult.requestedAmount;
    let grantConfidenceScore = null;
    let recommendedGrantAmount = null;

    let modelVariance = null;

    if (status === 'Auto-Approved' && parsedResult.category !== 'Mental Health & Crisis Intervention') {
      const grantPrediction = await predictOptimalGrant({
        dropoutRiskScore,
        requestedAmount: parsedResult.requestedAmount,
        institutionId,
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

    const { data: insertedTicket, error: insertError } = await supabase
      .from('tickets')
      .insert({
        institution_id: institutionId,
        student_phone: From,
        raw_message: Body,
        media_url: MediaUrl0,
        parsed_category: parsedResult.category,
        urgency_level: parsedResult.urgency,
        calculated_amount: finalAmount,
        status: status,
        policy_match_reason: policyMatchReason,
        flag_reason: flagReason,
        resolved_at: status === 'Auto-Approved' ? new Date().toISOString() : null,
        dropout_risk_score: dropoutRiskScore,
        recommended_grant_amount: recommendedGrantAmount,
        grant_confidence_score: grantConfidenceScore,
        model_variance: modelVariance,
        crisis_severity_index: null,
        sentiment_negative_score: parsedResult.sentimentNegativeScore,
        multi_department_involvement: parsedResult.multiDepartmentInvolvement,
        policy_ambiguity_score: parsedResult.policyAmbiguityScore,
        anomaly_reconstruction_score: reconstructionLoss,
      })
      .select('id')
      .single();

    if (insertError || !insertedTicket) {
      console.error("🚨 TICKET CREATION FAILED:", insertError);
      console.error('Error inserting ticket:', insertError);
      res.status(500).send('Internal Server Error');
      return;
    }

    if (status === 'Auto-Approved') {
      await logAuditEvent(institutionId, insertedTicket.id, 'AUTO_APPROVAL', 'AI_AGENT', {
        policy_match_reason: policyMatchReason,
        amount_disbursed: finalAmount
      });
    } else if (status === 'Escalated' && reconstructionLoss > 0.08) {
      await logAuditEvent(institutionId, insertedTicket.id, 'ANOMALY_FLAG', 'AI_AGENT', {
         reconstruction_loss: reconstructionLoss,
         notes: flagReason
      });
    } else if (status === 'Escalated' && modelVariance && modelVariance > 0.035) {
      await logAuditEvent(institutionId, insertedTicket.id, 'UNCERTAINTY_ESCALATION', 'AI_AGENT', {
         variance: modelVariance,
         notes: flagReason
      });
    }

    evaluateAndExecute(insertedTicket.id);

    try {
        const io = getIO();
        io.emit('ticket:created', { id: insertedTicket.id, ...parsedResult });
    } catch (e) {
        // socket might not be fully initialized yet during tests
    }

    const twiml = new MessagingResponse();
    twiml.message('Your request has been received and is being processed.');

    res.type('text/xml').send(twiml.toString());
  } catch (error) {
    console.error('Error handling intake:', error);
    res.status(500).send('Internal Server Error');
  }
});

export default router;
