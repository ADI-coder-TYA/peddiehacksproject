import { pipeline, env } from '@xenova/transformers';
import * as os from 'os';
import * as path from 'path';

// Cache directory override for containerized/local environments
env.cacheDir = path.join(os.tmpdir(), '.transformers_cache');

let sentimentPipeline: any = null;

export interface NLPAnalysisResult {
  sentimentScore: number; // -1.0 (Negative) to 1.0 (Positive)
  negativeScore: number;  // 0.0 to 1.0 (Distress magnitude)
  isCriticalDistress: boolean;
  extractedKeywords: string[];
  medicalEntityCount: number;
}

const CLINICAL_URGENT_REGEX = /\b(hospital|emergency|er|icu|ambulance|surgery|trauma|blood|hemorrhage|seizure|overdose|suicide|kill|die|insulin|oxygen|stroke|infarct|cardiac|unconscious|severe|fracture|burn|resuscitation)\b/gi;

export async function analyzeClinicalText(text: string): Promise<NLPAnalysisResult> {
  const cleanText = (text || '').trim();
  if (!cleanText) {
    return {
      sentimentScore: 0.0,
      negativeScore: 0.0,
      isCriticalDistress: false,
      extractedKeywords: [],
      medicalEntityCount: 0,
    };
  }

  if (!sentimentPipeline) {
    try {
      sentimentPipeline = await pipeline('sentiment-analysis', 'Xenova/distilbert-base-uncased-finetuned-sst-2-english');
    } catch (err) {
      console.warn('⚠️ [NLP Pipeline] Failed to load transformer model, using fallback sentiment:', err);
    }
  }

  let sentimentScore = 0.0;
  let negativeScore = 0.0;

  if (sentimentPipeline) {
    try {
      const result = await sentimentPipeline(cleanText.substring(0, 512));
      const hfData = result[0]; // e.g. { label: 'NEGATIVE', score: 0.98 }
      sentimentScore = hfData.label === 'NEGATIVE' ? -hfData.score : hfData.score;
      negativeScore = hfData.label === 'NEGATIVE' ? hfData.score : 1.0 - hfData.score;
    } catch (inferErr) {
      console.warn('⚠️ [NLP Pipeline] Inference error, falling back to keyword heuristics:', inferErr);
    }
  }

  const keywordMatches = cleanText.match(CLINICAL_URGENT_REGEX) || [];
  const uniqueKeywords = Array.from(new Set(keywordMatches.map((k) => k.toLowerCase())));
  const isCriticalDistress = negativeScore >= 0.85 || uniqueKeywords.length >= 3;

  return {
    sentimentScore,
    negativeScore,
    isCriticalDistress,
    extractedKeywords: uniqueKeywords,
    medicalEntityCount: uniqueKeywords.length,
  };
}
