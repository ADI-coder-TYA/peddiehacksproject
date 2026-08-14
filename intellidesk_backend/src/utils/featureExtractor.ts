import { pipeline, env } from '@xenova/transformers';
import * as os from 'os';
import * as path from 'path';

// Override the default cache directory to avoid Docker write permission errors
env.cacheDir = path.join(os.tmpdir(), '.transformers_cache');

let nlpPipeline: any = null;

export async function extractFeatures(rawMessage: string, amount: number = 0.0): Promise<number[]> {
  if (!nlpPipeline) {
    // Downloads a lightweight HF model on first run
    nlpPipeline = await pipeline('sentiment-analysis', 'Xenova/distilbert-base-uncased-finetuned-sst-2-english');
  }
  
  const word_count = rawMessage.trim() ? rawMessage.trim().split(/\s+/).length : 0;
  
  // Run HF Inference
  const result = await nlpPipeline(rawMessage);
  const hfData = result[0]; // e.g., { label: 'NEGATIVE', score: 0.98 }
  
  // Map HF score (0 to 1) to our -1.0 to 1.0 scale
  const sentiment_score = hfData.label === 'NEGATIVE' ? -hfData.score : hfData.score;
  
  // Keep a broader regex for hard keyword counting as a supplementary feature
  const urgentRegex = /urgent|help|evict|kicked out|danger|money|homeless|starving|abuse/gi;
  const matches = rawMessage.match(urgentRegex);
  const urgent_keyword_count = matches ? matches.length : 0;
  
  const norm_word_count = Math.min(word_count / 100, 1.0);
  const norm_urgent_keyword_count = Math.min(urgent_keyword_count / 5, 1.0);
  const norm_sentiment = (sentiment_score + 1.0) / 2.0;
  const norm_amount = Math.min(amount / 1000, 1.0);

  return [norm_word_count, norm_urgent_keyword_count, norm_sentiment, norm_amount];
}
