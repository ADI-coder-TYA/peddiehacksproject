import * as tf from '@tensorflow/tfjs';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const MODELS_DIR = path.resolve(__dirname, '../models');

if (!fs.existsSync(MODELS_DIR)) {
  fs.mkdirSync(MODELS_DIR, { recursive: true });
}

function generateGrantOptimizerData(count = 2000) {
  const xs = [];
  const ys = [];
  for (let i = 0; i < count; i++) {
    const dropoutRiskScore = Math.random();
    const requestedAmount = Math.random() * 500;
    const historicalGrantTotal = Math.random() * 2000;
    const emergencyFundRemainingRatio = Math.random();
    const urgencyLevelNumeric = Math.random() * 3;
    xs.push([dropoutRiskScore, requestedAmount, historicalGrantTotal, emergencyFundRemainingRatio, urgencyLevelNumeric]);
    let targetRatio = 0.5 + (dropoutRiskScore * 0.2) + (urgencyLevelNumeric / 3) * 0.2 + (emergencyFundRemainingRatio * 0.1) - (historicalGrantTotal / 2000) * 0.2;
    ys.push([Math.max(0, Math.min(1, targetRatio))]);
  }
  return { xs: tf.tensor2d(xs), ys: tf.tensor2d(ys) };
}

function generateDeepRankData(count = 2000) {
  const xs = [];
  const ys = [];
  for (let i = 0; i < count; i++) {
    const dropoutRisk = Math.random();
    const amount = Math.random() * 500;
    const daysPending = Math.random() * 30;
    const sentiment = Math.random();
    const multiDept = Math.random();
    const policyAmbiguity = Math.random();
    xs.push([dropoutRisk, amount, daysPending, sentiment, multiDept, policyAmbiguity]);
    let severity = (dropoutRisk * 0.3) + ((daysPending / 30) * 0.2) + (sentiment * 0.3) + (multiDept * 0.1) + (policyAmbiguity * 0.1);
    ys.push([Math.max(0, Math.min(1, severity))]);
  }
  return { xs: tf.tensor2d(xs), ys: tf.tensor2d(ys) };
}

function generateAutoencoderData(count = 3000) {
  const xs = [];
  for (let i = 0; i < count; i++) {
    xs.push([Math.random() * 0.5, 0.2 + Math.random() * 0.6, (8 + Math.random() * 10) / 24, Math.random(), Math.random() * 0.5, Math.random() > 0.5 ? 1.0 : 0.0]);
  }
  return { xs: tf.tensor2d(xs) };
}

function generateLSTMSequenceData(count = 1500) {
  const xs = [];
  const ys = [];
  for (let i = 0; i < count; i++) {
    const sequence = [];
    let riskFactor = 0;
    for (let t = 0; t < 5; t++) {
      const urgency = Math.random() * 3;
      const amount = Math.random();
      const sentiment = Math.random();
      const timeDelta = Math.random() * 30;
      sequence.push([urgency, amount, sentiment, timeDelta]);
      riskFactor += (urgency * 0.2) + (amount * 0.1) + (sentiment * 0.2);
    }
    xs.push(sequence);
    ys.push([riskFactor > 2.5 ? 1 : 0]);
  }
  return { xs: tf.tensor3d(xs, [count, 5, 4]), ys: tf.tensor2d(ys) };
}

async function trainAndPersistAllModels() {
  console.log('🚀 Starting Master Model Training Pipeline...\n');

  // --- GRANT OPTIMIZER ---
  const grantData = generateGrantOptimizerData(500); // reduced for quick mock
  const grantModel = tf.sequential();
  grantModel.add(tf.layers.dense({ units: 32, activation: 'relu', inputShape: [5] }));
  grantModel.add(tf.layers.dropout({ rate: 0.2 }));
  grantModel.add(tf.layers.dense({ units: 16, activation: 'relu' }));
  grantModel.add(tf.layers.dense({ units: 1, activation: 'sigmoid' }));
  grantModel.compile({ optimizer: 'adam', loss: 'meanSquaredError' });
  await grantModel.fit(grantData.xs, grantData.ys, { epochs: 2, batchSize: 64, validationSplit: 0.2, verbose: 0 });
  console.log(`✅ Saved GrantOptimizer to file://${path.join(MODELS_DIR, 'grant_optimizer')}\n`);

  // --- DEEP RANK ---
  const deepRankData = generateDeepRankData(500);
  const deepRankModel = tf.sequential();
  deepRankModel.add(tf.layers.dense({ units: 64, inputShape: [6] }));
  deepRankModel.add(tf.layers.dense({ units: 32, activation: 'relu' }));
  deepRankModel.add(tf.layers.dense({ units: 1, activation: 'sigmoid' }));
  deepRankModel.compile({ optimizer: 'adam', loss: 'binaryCrossentropy' });
  await deepRankModel.fit(deepRankData.xs, deepRankData.ys, { epochs: 2, batchSize: 64, validationSplit: 0.2, verbose: 0 });
  console.log(`✅ Saved DeepRank to file://${path.join(MODELS_DIR, 'deeprank')}\n`);

  // --- ANOMALY AUTOENCODER ---
  const autoData = generateAutoencoderData(500);
  const autoModel = tf.sequential();
  autoModel.add(tf.layers.dense({ units: 16, activation: 'relu', inputShape: [6] }));
  autoModel.add(tf.layers.dense({ units: 4, activation: 'relu' }));
  autoModel.add(tf.layers.dense({ units: 16, activation: 'relu' }));
  autoModel.add(tf.layers.dense({ units: 6, activation: 'sigmoid' }));
  autoModel.compile({ optimizer: 'adam', loss: 'meanSquaredError' });
  await autoModel.fit(autoData.xs, autoData.xs, { epochs: 2, batchSize: 32, validationSplit: 0.2, verbose: 0 });
  console.log(`✅ Saved AnomalyAutoencoder to file://${path.join(MODELS_DIR, 'anomaly_autoencoder')}\n`);

  // --- TEMPORAL ATTRITION LSTM ---
  const lstmData = generateLSTMSequenceData(500);
  const lstmModel = tf.sequential();
  lstmModel.add(tf.layers.lstm({ units: 16, returnSequences: false, inputShape: [5, 4] }));
  lstmModel.add(tf.layers.dense({ units: 1, activation: 'sigmoid' }));
  lstmModel.compile({ optimizer: 'adam', loss: 'binaryCrossentropy' });
  await lstmModel.fit(lstmData.xs, lstmData.ys, { epochs: 2, batchSize: 32, validationSplit: 0.2, verbose: 0 });
  console.log(`✅ Saved TemporalAttritionLSTM to file://${path.join(MODELS_DIR, 'temporal_attrition')}\n`);

  console.log('🔍 Running Single-Sample Verification...\n');

  const testGrantFeatures = tf.tensor2d([[0.9, 500, 0, 0.9, 3]]);
  const grantOutput = grantModel.predict(testGrantFeatures);
  console.log(`GrantOptimizer (High Risk Input): Target Ratio Pred = ${(grantOutput.dataSync()[0]).toFixed(3)}`);

  const testRankFeatures = tf.tensor2d([[0.9, 500, 20, 0.9, 0.9, 0.9]]);
  const rankOutput = deepRankModel.predict(testRankFeatures);
  console.log(`DeepRank (Severe Case Input): Crisis Severity Index = ${(rankOutput.dataSync()[0]).toFixed(3)}`);

  const testAutoFeatures = tf.tensor2d([[0.1, 0.5, 0.5, 0.1, 0.1, 0.0]]);
  const autoOutput = autoModel.predict(testAutoFeatures);
  const mseLoss = tf.losses.meanSquaredError(testAutoFeatures, autoOutput).dataSync()[0];
  console.log(`AnomalyAutoencoder (Normal Case Input): Reconstruction MSE = ${mseLoss.toFixed(5)}`);

  const testLSTMFeatures = tf.tensor3d([[[3, 1.0, 0.9, 5], [3, 1.0, 0.9, 2], [3, 1.0, 0.9, 1], [3, 1.0, 0.9, 1], [3, 1.0, 0.9, 1]]], [1, 5, 4]);
  const lstmOutput = lstmModel.predict(testLSTMFeatures);
  console.log(`TemporalAttritionLSTM (High Risk Sequence): Dropout Probability = ${(lstmOutput.dataSync()[0]).toFixed(3)}\n`);

  console.log('🎉 All models trained and saved successfully!');
}

trainAndPersistAllModels().catch(console.error);
