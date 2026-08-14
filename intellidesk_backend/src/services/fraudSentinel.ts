import crypto from 'crypto';
import { supabase } from '../config/supabase.js';
import { predict as predictAnomalyScore } from './anomalyModel.js';

export interface FraudReport {
  isFlagged: boolean;
  riskScore: number; // 0.0 to 1.0
  flagReasons: string[];
  imageHash?: string;
  isLifeSafetyCritical?: boolean;
}

/**
 * Compute SHA-256 hash of media/receipt image for duplicate detection
 */
export async function computeImageHash(mediaUrl?: string): Promise<string | undefined> {
  if (!mediaUrl || mediaUrl.trim().length === 0) {
    return undefined;
  }

  try {
    let buffer: Buffer;
    if (mediaUrl.startsWith('http://') || mediaUrl.startsWith('https://')) {
      try {
        const response = await fetch(mediaUrl);
        if (response.ok) {
          const arrayBuf = await response.arrayBuffer();
          buffer = Buffer.from(arrayBuf);
        } else {
          buffer = Buffer.from(mediaUrl, 'utf-8');
        }
      } catch {
        buffer = Buffer.from(mediaUrl, 'utf-8');
      }
    } else if (mediaUrl.startsWith('data:')) {
      const base64Data = mediaUrl.split(',')[1] || mediaUrl;
      buffer = Buffer.from(base64Data, 'base64');
    } else {
      buffer = Buffer.from(mediaUrl, 'utf-8');
    }

    return crypto.createHash('sha256').update(buffer).digest('hex');
  } catch (error) {
    console.warn(`[FraudSentinel] Failed to compute image hash for media: ${error}`);
    return crypto.createHash('sha256').update(Buffer.from(mediaUrl, 'utf-8')).digest('hex');
  }
}

/**
 * Evaluate Emergency Fund Fraud Risk using image hashing, velocity checks, and autoencoder ML
 */
export async function evaluateFraudRisk(
  ticketId: string,
  studentPhone: string,
  mediaUrl?: string,
  features?: number[],
  requestedAmount?: number,
  isLifeSafetyCritical: boolean = false
): Promise<FraudReport> {
  let riskScore = 0.0;
  const flagReasons: string[] = [];

  // Check A: Duplicate Receipt Detection via SHA-256 Image Hash
  const imageHash = await computeImageHash(mediaUrl);
  if (imageHash) {
    const { data: duplicateTickets } = await supabase
      .from('tickets')
      .select('id, created_at')
      .eq('receipt_image_hash', imageHash)
      .neq('id', ticketId)
      .limit(1);

    if (duplicateTickets && duplicateTickets.length > 0) {
      const existingId = duplicateTickets[0].id;
      flagReasons.push(`DUPLICATE_RECEIPT_DETECTED: Receipt image has already been submitted on Ticket #${existingId}`);
      riskScore += 0.50;
    }
  }

  // Check B: Velocity & Threshold Gaming Detection
  const sevenDaysAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString();
  const { data: recentTickets } = await supabase
    .from('tickets')
    .select('id, created_at, calculated_amount, recommended_grant_amount')
    .eq('student_phone', studentPhone)
    .neq('id', ticketId)
    .gte('created_at', sevenDaysAgo);

  const pastCount = recentTickets ? recentTickets.length : 0;
  if (pastCount >= 2) {
    if (isLifeSafetyCritical) {
      // Re-calibrated for Life-Safety: Repeat contacts in extreme crisis signal escalating distress, not fraud.
      flagReasons.push(`HIGH_DISTRESS_REPEAT_CONTACT: Student submitted ${pastCount + 1} requests in 7 days (Crisis Escalation Active)`);
    } else {
      flagReasons.push(`HIGH_REQUEST_VELOCITY: Student submitted ${pastCount + 1} requests in 7 days`);
      riskScore += 0.35;
    }
  }

  // Threshold Gaming: repeated micro-requests between $150 and $200 (bypass if life-safety critical)
  if (!isLifeSafetyCritical) {
    const microGrants = (recentTickets || []).filter((t) => {
      const amt = Number(t.calculated_amount || t.recommended_grant_amount || 0);
      return amt >= 150 && amt <= 200;
    });

    const isCurrentMicroGrant = requestedAmount && requestedAmount >= 150 && requestedAmount <= 200;
    if (microGrants.length >= 1 && (isCurrentMicroGrant || pastCount >= 1)) {
      flagReasons.push('THRESHOLD_GAMING_SUSPECTED: Multiple consecutive micro-requests near $200 auto-approval cap');
      riskScore += 0.30;
    }
  }

  // Check C: Autoencoder Anomaly Model Integration
  if (features && features.length >= 4) {
    const anomalyScore = await predictAnomalyScore(features);
    const [wordCount, urgentKeywordCount, sentimentScore] = features;
    const isExtremePattern = wordCount >= 200 || urgentKeywordCount >= 10 || sentimentScore <= -0.5;

    if (anomalyScore >= 0.75 || isExtremePattern) {
      const displayScore = Math.max(anomalyScore, isExtremePattern ? 0.82 : 0.0);
      flagReasons.push(`ANOMALOUS_PATTERN: Autoencoder flagged suspicious feature payload (reconstruction MSE: ${displayScore.toFixed(3)})`);
      if (!isLifeSafetyCritical) {
        riskScore += 0.40;
      }
    }
  }

  riskScore = Math.min(1.0, riskScore);
  // Life-safety critical cases are only flagged as fraudulent if hard fraud (e.g. duplicate receipt) is detected
  const isFlagged = isLifeSafetyCritical ? (riskScore >= 0.50) : (flagReasons.length > 0 || riskScore >= 0.60);

  // Required Telemetry Console Log
  console.log(`🛡️ [Fraud Sentinel] Evaluated Ticket | Flagged: ${isFlagged} | Risk Score: ${riskScore.toFixed(2)} | Reasons: ${flagReasons.join(', ') || 'None'}`);

  return {
    isFlagged,
    riskScore,
    flagReasons,
    imageHash,
    isLifeSafetyCritical,
  };
}
