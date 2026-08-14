import '@tensorflow/tfjs-node';
import * as tf from '@tensorflow/tfjs';
import fs from 'fs';
import * as path from 'path';

let model: tf.LayersModel | null = null;

// ---------------------------------------------------------------------------
// Ticket shape — updated to match CSV training features
// ---------------------------------------------------------------------------
export interface TicketBatch {
  id: string;
  // New CSV-aligned fields
  word_count?: number;
  urgent_keyword_count?: number;
  sentiment_score?: number;
  historical_ticket_count?: number;
  // Inferred / computed fields
  crisis_severity_index?: number;
  // Legacy fields preserved for callers that still supply them
  dropout_risk_score?: number;
  calculated_amount?: number;
  created_at?: string;
  sentiment_negative_score?: number;
  multi_department_involvement?: number;
  policy_ambiguity_score?: number;
  [key: string]: any;
}

// ---------------------------------------------------------------------------
// Model loading — strict load-only, NO in-process training
// ---------------------------------------------------------------------------
export async function loadOrTrainDeepRankModel(): Promise<void> {
  console.log('[DeepRank] Initializing model...');
  const modelPath = path.join(process.cwd(), 'models', 'deep_rank', 'model.json');

  if (!fs.existsSync(modelPath)) {
    console.warn(
      `\n⚠️  [DeepRank] WARNING: Model files not found at ${modelPath}\n` +
      '   Please run  npm run train:ml  first to generate trained weights.\n' +
      '   The server will continue with degraded inference (all predictions = 0.5).\n'
    );
    model = null;
    return;
  }

  console.log('[DeepRank] Loading model from disk...');
  model = await tf.loadLayersModel(`file://${modelPath}`);
  // Compile for potential fine-tuning (not required for predict())
  (model as tf.Sequential).compile({
    optimizer: tf.train.adam(0.002),
    loss: 'meanSquaredError',
  });
  console.log('[DeepRank] ✅ Model loaded successfully.');
}

// ---------------------------------------------------------------------------
// Fine-tune on real resolved tickets (4-feature shape aligned with CSV)
// ---------------------------------------------------------------------------
export async function fineTuneDeepRankModel(pastTickets: any[]): Promise<number | null> {
  if (!model) {
    console.warn('[DeepRank] Cannot fine-tune — model not loaded.');
    return null;
  }

  const xs: number[][] = [];
  const ys: number[][] = [];

  for (const t of pastTickets) {
    const wordCount           = t.word_count            ?? 100;
    const urgentKeywordCount  = t.urgent_keyword_count  ?? 1;
    const sentimentScore      = t.sentiment_score       ?? t.sentiment_negative_score ?? 0.5;
    const historicalCount     = t.historical_ticket_count ?? 0;

    xs.push([
      wordCount,
      urgentKeywordCount,
      sentimentScore,
      Math.min(historicalCount / 20, 1),
    ]);

    // Reconstruct label proxy from available fields
    let severity = 0.0;
    severity += (urgentKeywordCount / 10) * 0.4;
    severity += sentimentScore * 0.4;
    severity += Math.min(historicalCount / 20, 1) * 0.2;
    ys.push([Math.max(0, Math.min(1, severity))]);
  }

  if (xs.length === 0) return null;

  const xsTensor = tf.tensor2d(xs);
  const ysTensor = tf.tensor2d(ys);

  const history = await (model as tf.Sequential).fit(xsTensor, ysTensor, {
    epochs: 5,
    batchSize: 32,
    shuffle: true,
    verbose: 0,
  });

  await model.save('file://./models/deep_rank');

  xsTensor.dispose();
  ysTensor.dispose();

  return history.history['loss'][history.history['loss'].length - 1] as number;
}

// ---------------------------------------------------------------------------
// Inference — rank a batch of tickets by predicted crisis_severity_index
// Input shape: [n, 4]  (word_count, urgent_keyword_count, sentiment_score, historical_ticket_count)
// ---------------------------------------------------------------------------
export function rankPendingQueue(ticketsArray: TicketBatch[]): TicketBatch[] {
  if (ticketsArray.length === 0) return ticketsArray;

  if (!model) {
    // Fallback: assign 0.5 to all so ordering is neutral
    return ticketsArray.map(t => ({ ...t, crisis_severity_index: 0.5 }));
  }

  try {
    const xs: number[][] = ticketsArray.map(t => [
      (t.word_count            ?? 100),
      (t.urgent_keyword_count  ?? 1),
       t.sentiment_score       ?? t.sentiment_negative_score ?? 0.5,
      Math.min((t.historical_ticket_count ?? 0) / 20, 1),
    ]);

    const inputTensor  = tf.tensor2d(xs);
    const predictions  = model.predict(inputTensor) as tf.Tensor;
    const scores       = predictions.dataSync();

    inputTensor.dispose();
    predictions.dispose();

    const ranked = ticketsArray.map((ticket, i) => ({
      ...ticket,
      crisis_severity_index: scores[i],
    }));

    ranked.sort((a, b) => (b.crisis_severity_index ?? 0) - (a.crisis_severity_index ?? 0));
    return ranked;
  } catch (err) {
    console.error('[DeepRank] Error during ranking:', err);
    return ticketsArray;
  }
}

// ---------------------------------------------------------------------------
// Direct Inference for a single ticket
// ---------------------------------------------------------------------------
export async function predict(features: number[]): Promise<number> {
  if (!model) return 0.5;
  try {
    const [wordCount, urgentKeywordCount, sentimentScore, historicalCount] = features;
    const normalizedFeatures = [
      wordCount,
      urgentKeywordCount,
      sentimentScore,
      Math.min(historicalCount / 20, 1),
    ];
    const inputTensor = tf.tensor2d([normalizedFeatures]);
    const predictions = model.predict(inputTensor) as tf.Tensor;
    const score = predictions.dataSync()[0];
    inputTensor.dispose();
    predictions.dispose();
    return score;
  } catch (err) {
    console.error('[DeepRank] Error during prediction:', err);
    return 0.5;
  }
}
