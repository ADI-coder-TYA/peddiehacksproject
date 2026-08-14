import '@tensorflow/tfjs-node';
import * as tf from '@tensorflow/tfjs';
import fs from 'fs';
import * as path from 'path';
import { supabase } from '../config/supabase.js';

let model: tf.LayersModel | null = null;

// ---------------------------------------------------------------------------
// Build inference tensor for a student — shape [1, 1, 4]
// Matches the CSV-trained LSTM inputShape [timeSteps=1, features=4]
// Features: word_count, urgent_keyword_count, sentiment_score, historical_ticket_count
// ---------------------------------------------------------------------------
export async function buildStudentSequenceTensor(studentPhone: string): Promise<tf.Tensor3D> {
  const { data: tickets, error } = await supabase
    .from('tickets')
    .select('urgency_level, calculated_amount, sentiment_negative_score, created_at')
    .eq('student_phone', studentPhone)
    .order('created_at', { ascending: true })
    .limit(10); // fetch more for better aggregation

  const rawTickets = (!error && tickets) ? tickets : [];

  // Aggregate across historical tickets into a single time-step vector
  // Proxy mappings (DB fields → CSV training features):
  //   word_count            ← calculated_amount * 5  (rough proxy for ticket length/complexity)
  //   urgent_keyword_count  ← derived from urgency_level  (High=3, Medium=1, Low/other=0)
  //   sentiment_score       ← sentiment_negative_score
  //   historical_ticket_count ← number of historical tickets

  let totalWordCount          = 0;
  let totalUrgentKeywords     = 0;
  let totalSentiment          = 0;

  for (const ticket of rawTickets) {
    totalWordCount      += Math.min(500, (ticket.calculated_amount || 0) * 5);
    totalSentiment      += ticket.sentiment_negative_score ?? 0.5;

    const ul = (ticket.urgency_level || '').toLowerCase();
    if (ul === 'urgent') totalUrgentKeywords += 5;
    else if (ul === 'high') totalUrgentKeywords += 3;
    else if (ul === 'medium') totalUrgentKeywords += 1;
  }

  const n = rawTickets.length || 1; // avoid div-by-zero
  const wordCount           = Math.round(totalWordCount / n);
  const urgentKeywordCount  = Math.round(totalUrgentKeywords / n);
  const sentimentScore      = totalSentiment / n;
  const historicalCount     = rawTickets.length;

  // Normalize to [0,1] to match CSV training normalization
  return tf.tensor3d([[[Math.min(wordCount / 100, 1.0), Math.min(urgentKeywordCount / 5, 1.0), sentimentScore, Math.min(historicalCount / 20, 1)]]]);
}

// ---------------------------------------------------------------------------
// Load model from disk — strict load-only, NO training
// ---------------------------------------------------------------------------
export async function loadOrTrainLSTMModel(): Promise<void> {
  console.log('[TemporalAttritionLSTM] Initializing model...');
  const modelPath = path.join(process.cwd(), 'models', 'lstm', 'model.json');

  if (!fs.existsSync(modelPath)) {
    console.warn(
      `\n⚠️  [TemporalAttritionLSTM] WARNING: Model files not found at ${modelPath}\n` +
      '   Please run  npm run train:ml  first to generate trained weights.\n' +
      '   The server will continue with degraded inference (all risk scores = 0.0).\n'
    );
    model = null;
    return;
  }

  console.log('[TemporalAttritionLSTM] Loading model from disk...');
  model = await tf.loadLayersModel(`file://${modelPath}`);
  console.log('[TemporalAttritionLSTM] ✅ Model loaded successfully.');
}

// ---------------------------------------------------------------------------
// Inference — predict dropout risk for a student
// Returns a score in [0, 1]; 0.0 is the safe fallback if model is missing
// ---------------------------------------------------------------------------
export async function predictSequenceAttritionRisk(studentPhone: string): Promise<number> {
  if (!model) {
    console.warn('[TemporalAttritionLSTM] Model not loaded. Returning fallback risk score (0.0).');
    return 0.0;
  }

  try {
    // Input tensor shape: [1, 1, 4]  (batch=1, timeSteps=1, features=4)
    const sequenceTensor = await buildStudentSequenceTensor(studentPhone);
    const prediction     = model.predict(sequenceTensor) as tf.Tensor;
    const riskScoreData  = await prediction.data();

    sequenceTensor.dispose();
    prediction.dispose();

    return Math.round(riskScoreData[0] * 10000) / 10000;
  } catch (err) {
    console.error('[TemporalAttritionLSTM] Error during inference:', err);
    return 0.0;
  }
}

// ---------------------------------------------------------------------------
// Direct Inference for a single ticket with extracted features
// ---------------------------------------------------------------------------
export async function predict(features: number[]): Promise<number> {
  if (!model) return 0.0;
  try {
    const [wordCount, urgentKeywordCount, sentimentScore, historicalCount] = features;
    const normalizedFeatures = [
      wordCount,
      urgentKeywordCount,
      sentimentScore,
      Math.min(historicalCount / 20, 1),
    ];
    // Shape [1, 1, 4]
    const inputTensor = tf.tensor3d([[normalizedFeatures]]);
    const prediction = model.predict(inputTensor) as tf.Tensor;
    const riskScore = prediction.dataSync()[0];
    inputTensor.dispose();
    prediction.dispose();
    return Math.round(riskScore * 10000) / 10000;
  } catch (err) {
    console.error('[TemporalAttritionLSTM] Error during prediction:', err);
    return 0.0;
  }
}
