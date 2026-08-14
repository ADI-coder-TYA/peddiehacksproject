import * as tf from '@tensorflow/tfjs-node';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

// Resolve current directory for model saving
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const MODELS_DIR = path.resolve(__dirname, '../models');

// Ensure models directory exists
if (!fs.existsSync(MODELS_DIR)) {
  fs.mkdirSync(MODELS_DIR, { recursive: true });
}

// ----------------------------------------------------------------------------
// 1. Synthetic Seed Data Generators
// ----------------------------------------------------------------------------

function generateGrantOptimizerData(count = 2000) {
  const xs: number[][] = [];
  const ys: number[][] = [];

  for (let i = 0; i < count; i++) {
    // Features: [dropoutRiskScore, requestedAmount, historicalGrantTotal, emergencyFundRemainingRatio, urgencyLevelNumeric]
    const dropoutRiskScore = Math.random();
    const requestedAmount = Math.random() * 500;
    const historicalGrantTotal = Math.random() * 2000;
    const emergencyFundRemainingRatio = Math.random();
    const urgencyLevelNumeric = Math.random() * 3; // 0 to 3

    xs.push([dropoutRiskScore, requestedAmount, historicalGrantTotal, emergencyFundRemainingRatio, urgencyLevelNumeric]);

    // Synthetic label: high risk/urgency + healthy fund -> higher ratio
    let targetRatio = 0.5; // base
    targetRatio += (dropoutRiskScore * 0.2);
    targetRatio += (urgencyLevelNumeric / 3) * 0.2;
    targetRatio += (emergencyFundRemainingRatio * 0.1);
    targetRatio -= (historicalGrantTotal / 2000) * 0.2;
    
    // cap between 0 and 1
    targetRatio = Math.max(0, Math.min(1, targetRatio));
    ys.push([targetRatio]);
  }

  return { 
    xs: tf.tensor2d(xs), 
    ys: tf.tensor2d(ys) 
  };
}

function generateDeepRankData(count = 2000) {
  const xs: number[][] = [];
  const ys: number[][] = [];

  for (let i = 0; i < count; i++) {
    // Features: [dropoutRisk, amount, daysPending, sentiment, multiDept, policyAmbiguity]
    const dropoutRisk = Math.random();
    const amount = Math.random() * 500;
    const daysPending = Math.random() * 30; // 0 to 30 days
    const sentiment = Math.random();
    const multiDept = Math.random();
    const policyAmbiguity = Math.random();

    xs.push([dropoutRisk, amount, daysPending, sentiment, multiDept, policyAmbiguity]);

    // Synthetic severity index mapping
    let severity = 0.0;
    severity += dropoutRisk * 0.3;
    severity += (daysPending / 30) * 0.2;
    severity += sentiment * 0.3;
    severity += multiDept * 0.1;
    severity += policyAmbiguity * 0.1;
    
    severity = Math.max(0, Math.min(1, severity));
    ys.push([severity]);
  }

  return { 
    xs: tf.tensor2d(xs), 
    ys: tf.tensor2d(ys) 
  };
}

function generateAutoencoderData(count = 3000) {
  const xs: number[][] = [];

  for (let i = 0; i < count; i++) {
    // Normal features are roughly uniform or Gaussian, mostly valid combinations
    const amountNorm = Math.random() * 0.5; // low amounts usually
    const textLenNorm = 0.2 + Math.random() * 0.6; // decent text length
    const hourNorm = (8 + Math.random() * 10) / 24; // mostly daytime 8am-6pm
    const sentiment = Math.random(); 
    const risk = Math.random() * 0.5; // normal risk
    const mediaPresent = Math.random() > 0.5 ? 1.0 : 0.0;

    xs.push([amountNorm, textLenNorm, hourNorm, sentiment, risk, mediaPresent]);
  }

  // Autoencoder tries to predict its own input
  return { 
    xs: tf.tensor2d(xs) 
  };
}

function generateLSTMSequenceData(count = 1500) {
  const xs: number[][][] = [];
  const ys: number[][] = [];

  for (let i = 0; i < count; i++) {
    const sequence: number[][] = [];
    let riskFactor = 0;
    
    for (let t = 0; t < 5; t++) {
      // Features: [urgencyNumeric, requestedNormalized, sentiment, timeDelta]
      const urgency = Math.random() * 3;
      const amount = Math.random();
      const sentiment = Math.random();
      const timeDelta = Math.random() * 30;
      
      sequence.push([urgency, amount, sentiment, timeDelta]);
      riskFactor += (urgency * 0.2) + (amount * 0.1) + (sentiment * 0.2);
    }
    
    xs.push(sequence);
    const label = riskFactor > 2.5 ? 1 : 0;
    ys.push([label]);
  }

  return { 
    xs: tf.tensor3d(xs, [count, 5, 4]), 
    ys: tf.tensor2d(ys) 
  };
}

// ----------------------------------------------------------------------------
// 2. Master Model Training Pipeline
// ----------------------------------------------------------------------------

async function trainAndPersistAllModels() {
  console.log('🚀 Starting Master Model Training Pipeline...\n');

  // --- GRANT OPTIMIZER ---
  console.log('=== Training GrantOptimizer ===');
  const grantData = generateGrantOptimizerData();
  const grantModel = tf.sequential();
  grantModel.add(tf.layers.dense({ units: 32, activation: 'relu', inputShape: [5], kernelRegularizer: tf.regularizers.l2({ l2: 0.01 }) }));
  grantModel.add(tf.layers.dropout({ rate: 0.2 }));
  grantModel.add(tf.layers.dense({ units: 16, activation: 'relu' }));
  grantModel.add(tf.layers.dense({ units: 1, activation: 'sigmoid' }));
  grantModel.compile({ optimizer: tf.train.adam(0.001), loss: 'meanSquaredError' });
  
  await grantModel.fit(grantData.xs, grantData.ys, {
    epochs: 30,
    batchSize: 64,
    validationSplit: 0.2,
    shuffle: true,
    callbacks: { onEpochEnd: (epoch, logs) => console.log(`  Epoch ${epoch + 1}: loss = ${logs?.loss.toFixed(4)}, val_loss = ${logs?.val_loss.toFixed(4)}`) }
  });
  const grantPath = `file://${path.join(MODELS_DIR, 'grant_optimizer')}`;
  await grantModel.save(grantPath);
  console.log(`✅ Saved GrantOptimizer to ${grantPath}\n`);

  // --- DEEP RANK ---
  console.log('=== Training DeepRank ===');
  const deepRankData = generateDeepRankData();
  const deepRankModel = tf.sequential();
  deepRankModel.add(tf.layers.dense({ units: 64, inputShape: [6] }));
  deepRankModel.add(tf.layers.leakyReLU());
  deepRankModel.add(tf.layers.batchNormalization());
  deepRankModel.add(tf.layers.dense({ units: 32 }));
  deepRankModel.add(tf.layers.leakyReLU());
  deepRankModel.add(tf.layers.dense({ units: 1, activation: 'sigmoid' }));
  deepRankModel.compile({ optimizer: tf.train.adam(0.002), loss: 'binaryCrossentropy' });
  
  await deepRankModel.fit(deepRankData.xs, deepRankData.ys, {
    epochs: 30,
    batchSize: 64,
    validationSplit: 0.2,
    shuffle: true,
    callbacks: { onEpochEnd: (epoch, logs) => console.log(`  Epoch ${epoch + 1}: loss = ${logs?.loss.toFixed(4)}, val_loss = ${logs?.val_loss.toFixed(4)}`) }
  });
  const deepRankPath = `file://${path.join(MODELS_DIR, 'deeprank')}`;
  await deepRankModel.save(deepRankPath);
  console.log(`✅ Saved DeepRank to ${deepRankPath}\n`);

  // --- ANOMALY AUTOENCODER ---
  console.log('=== Training AnomalyAutoencoder ===');
  const autoData = generateAutoencoderData();
  const autoModel = tf.sequential();
  autoModel.add(tf.layers.dense({ units: 16, activation: 'relu', inputShape: [6] }));
  autoModel.add(tf.layers.dense({ units: 4, activation: 'relu' })); // Latent space
  autoModel.add(tf.layers.dense({ units: 16, activation: 'relu' }));
  autoModel.add(tf.layers.dense({ units: 6, activation: 'sigmoid' }));
  autoModel.compile({ optimizer: tf.train.adam(0.001), loss: 'meanSquaredError' });
  
  await autoModel.fit(autoData.xs, autoData.xs, {
    epochs: 40,
    batchSize: 32,
    validationSplit: 0.2,
    shuffle: true,
    callbacks: { onEpochEnd: (epoch, logs) => console.log(`  Epoch ${epoch + 1}: loss = ${logs?.loss.toFixed(4)}, val_loss = ${logs?.val_loss.toFixed(4)}`) }
  });
  const autoPath = `file://${path.join(MODELS_DIR, 'anomaly_autoencoder')}`;
  await autoModel.save(autoPath);
  console.log(`✅ Saved AnomalyAutoencoder to ${autoPath}\n`);

  // --- TEMPORAL ATTRITION LSTM ---
  console.log('=== Training TemporalAttritionLSTM ===');
  const lstmData = generateLSTMSequenceData();
  const lstmModel = tf.sequential();
  lstmModel.add(tf.layers.lstm({ units: 32, returnSequences: true, inputShape: [5, 4], dropout: 0.2, recurrentDropout: 0.2 }));
  lstmModel.add(tf.layers.lstm({ units: 16, returnSequences: false, dropout: 0.2 }));
  lstmModel.add(tf.layers.dense({ units: 16, activation: 'relu' }));
  lstmModel.add(tf.layers.dense({ units: 1, activation: 'sigmoid' }));
  lstmModel.compile({ optimizer: tf.train.adam(0.001), loss: 'binaryCrossentropy' });
  
  await lstmModel.fit(lstmData.xs, lstmData.ys, {
    epochs: 30,
    batchSize: 32,
    validationSplit: 0.2,
    shuffle: true,
    callbacks: { onEpochEnd: (epoch, logs) => console.log(`  Epoch ${epoch + 1}: loss = ${logs?.loss.toFixed(4)}, val_loss = ${logs?.val_loss.toFixed(4)}`) }
  });
  const lstmPath = `file://${path.join(MODELS_DIR, 'temporal_attrition')}`;
  await lstmModel.save(lstmPath);
  console.log(`✅ Saved TemporalAttritionLSTM to ${lstmPath}\n`);

  // ----------------------------------------------------------------------------
  // 3. Artifact Export & Verification
  // ----------------------------------------------------------------------------
  console.log('🔍 Running Single-Sample Verification...\n');

  // Verify Grant Optimizer
  const testGrantFeatures = tf.tensor2d([[0.9, 500, 0, 0.9, 3]]); // High risk, urgent
  const grantOutput = grantModel.predict(testGrantFeatures) as tf.Tensor;
  console.log(`GrantOptimizer (High Risk Input): Target Ratio Pred = ${(grantOutput.dataSync()[0]).toFixed(3)}`);

  // Verify Deep Rank
  const testRankFeatures = tf.tensor2d([[0.9, 500, 20, 0.9, 0.9, 0.9]]); // Severe case
  const rankOutput = deepRankModel.predict(testRankFeatures) as tf.Tensor;
  console.log(`DeepRank (Severe Case Input): Crisis Severity Index = ${(rankOutput.dataSync()[0]).toFixed(3)}`);

  // Verify Autoencoder
  const testAutoFeatures = tf.tensor2d([[0.1, 0.5, 0.5, 0.1, 0.1, 0.0]]); // Normal case
  const autoOutput = autoModel.predict(testAutoFeatures) as tf.Tensor;
  const mseLoss = tf.losses.meanSquaredError(testAutoFeatures, autoOutput).dataSync()[0];
  console.log(`AnomalyAutoencoder (Normal Case Input): Reconstruction MSE = ${mseLoss.toFixed(5)}`);

  // Verify LSTM
  const testLSTMFeatures = tf.tensor3d([[[3, 1.0, 0.9, 5], [3, 1.0, 0.9, 2], [3, 1.0, 0.9, 1], [3, 1.0, 0.9, 1], [3, 1.0, 0.9, 1]]], [1, 5, 4]); // High risk sequence
  const lstmOutput = lstmModel.predict(testLSTMFeatures) as tf.Tensor;
  console.log(`TemporalAttritionLSTM (High Risk Sequence): Dropout Probability = ${(lstmOutput.dataSync()[0]).toFixed(3)}\n`);

  // Cleanup Tensors
  testGrantFeatures.dispose();
  grantOutput.dispose();
  testRankFeatures.dispose();
  rankOutput.dispose();
  testAutoFeatures.dispose();
  autoOutput.dispose();
  testLSTMFeatures.dispose();
  lstmOutput.dispose();
  
  grantData.xs.dispose(); grantData.ys.dispose();
  deepRankData.xs.dispose(); deepRankData.ys.dispose();
  autoData.xs.dispose();
  lstmData.xs.dispose(); lstmData.ys.dispose();

  console.log('🎉 All models trained and saved successfully!');
}

trainAndPersistAllModels().catch(console.error);
