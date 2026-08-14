import '@tensorflow/tfjs-node';
import * as tf from '@tensorflow/tfjs';
import fs from 'fs';
import * as path from 'path';

let model: tf.LayersModel | null = null;

// ---------------------------------------------------------------------------
// Load model from disk — strict load-only, NO training
// ---------------------------------------------------------------------------
export async function loadOrTrainAnomalyModel(): Promise<void> {
  console.log('[AnomalyAutoencoder] Initializing model...');
  const modelPath = path.join(process.cwd(), 'models', 'autoencoder', 'model.json');

  if (!fs.existsSync(modelPath)) {
    console.warn(
      `\n⚠️  [AnomalyAutoencoder] WARNING: Model files not found at ${modelPath}\n` +
      '   Please run  npm run train:ml  first to generate trained weights.\n' +
      '   The server will continue with degraded inference (anomaly score = 0.0).\n'
    );
    model = null;
    return;
  }

  console.log('[AnomalyAutoencoder] Loading model from disk...');
  model = await tf.loadLayersModel(`file://${modelPath}`);
  console.log('[AnomalyAutoencoder] ✅ Model loaded successfully.');
}

// ---------------------------------------------------------------------------
// Inference — compute reconstruction MSE as anomaly score
//
// featureVector: 4 elements aligned with CSV training features:
//   [word_count_norm, urgent_keyword_count_norm, sentiment_score, historical_ticket_count_norm]
//
// Higher MSE → more anomalous (potential fraud / bot).
// Returns 0.0 as a safe fallback if the model is not loaded.
// ---------------------------------------------------------------------------
export async function calculateAnomalyScore(featureVector: number[]): Promise<number> {
  if (!model) {
    console.warn('[AnomalyAutoencoder] Model not loaded. Returning fallback score (0.0).');
    return 0.0;
  }

  try {
    const inputTensor  = tf.tensor2d([featureVector], [1, featureVector.length]);
    const outputTensor = model.predict(inputTensor) as tf.Tensor;

    const reconstructionLoss =
      tf.losses.meanSquaredError(inputTensor, outputTensor).dataSync()[0];

    inputTensor.dispose();
    outputTensor.dispose();

    return reconstructionLoss;
  } catch (err) {
    console.error('[AnomalyAutoencoder] Error calculating anomaly score:', err);
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
    const inputTensor = tf.tensor2d([normalizedFeatures]);
    const outputTensor = model.predict(inputTensor) as tf.Tensor;
    const reconstructionLoss = tf.losses.meanSquaredError(inputTensor, outputTensor).dataSync()[0];
    inputTensor.dispose();
    outputTensor.dispose();
    return reconstructionLoss;
  } catch (err) {
    console.error('[AnomalyAutoencoder] Error during prediction:', err);
    return 0.0;
  }
}
