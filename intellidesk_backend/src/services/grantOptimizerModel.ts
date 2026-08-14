import '@tensorflow/tfjs-node';
import * as tf from '@tensorflow/tfjs';
import { supabase } from '../config/supabase.js';
import fs from 'fs';

let model: tf.Sequential;

export interface StudentMetrics {
  dropoutRiskScore: number;
  requestedAmount: number;
  institutionId: string;
  urgencyLevel: string;
}

export interface GrantPrediction {
  recommendedAmount: number;
  confidenceScore: number;
  variance: number;
}

export async function loadOrTrainGrantOptimizerModel() {
  console.log('[GrantOptimizer] Initializing model...');
  const modelPath = './models/grant_optimizer';
  
  if (fs.existsSync(modelPath + '/model.json')) {
    console.log('[GrantOptimizer] Loading existing model from disk...');
    model = (await tf.loadLayersModel(`file://${modelPath}/model.json`)) as tf.Sequential;
    
    // Compile after loading so it can be fine-tuned later
    model.compile({
      optimizer: tf.train.adam(0.001),
      loss: 'meanSquaredError',
    });
    return;
  }
  
  console.log('[GrantOptimizer] No existing model found. Training new model...');
  model = tf.sequential();
  
  // Input: 5 dense features
  model.add(tf.layers.dense({ 
    units: 32, 
    activation: 'relu', 
    inputShape: [5],
    kernelRegularizer: tf.regularizers.l2({ l2: 0.01 })
  }));
  
  model.add(tf.layers.dropout({ rate: 0.2 }));
  
  model.add(tf.layers.dense({ units: 16, activation: 'relu' }));
  
  // Output: 1 unit, sigmoid (approval ratio)
  model.add(tf.layers.dense({ units: 1, activation: 'sigmoid' }));

  model.compile({
    optimizer: tf.train.adam(0.001),
    loss: 'meanSquaredError',
  });

  // Synthetic training data
  const numSamples = 2000;
  const xs: number[][] = [];
  const ys: number[][] = [];

  for (let i = 0; i < numSamples; i++) {
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

  const xsTensor = tf.tensor2d(xs);
  const ysTensor = tf.tensor2d(ys);

  await model.fit(xsTensor, ysTensor, {
    epochs: 25,
    batchSize: 64,
    shuffle: true,
    verbose: 0,
  });

  console.log('[GrantOptimizer] Model training complete. Saving to disk...');
  
  fs.mkdirSync(modelPath, { recursive: true });
  await model.save(`file://${modelPath}`);
  
  xsTensor.dispose();
  ysTensor.dispose();
}

export async function fineTuneGrantOptimizerModel(pastTickets: any[]) {
  if (!model) {
    throw new Error('Model not initialized');
  }

  const xs: number[][] = [];
  const ys: number[][] = [];

  for (const t of pastTickets) {
    if (t.calculated_amount != null) {
      // Reconstruct features
      const dropoutRisk = t.dropout_risk_score || 0.0;
      const requested = t.calculated_amount; // assuming it was fully approved or similar for MVP, wait, requested amount might be different but we use calculated as requested for MVP fine-tuning proxy
      
      const FINANCIAL_AID_BUDGET = 50000;
      const remainingRatio = Math.random(); // simplified
      
      let urgencyNumeric = 1;
      if (t.urgency_level === 'High') urgencyNumeric = 2;
      if (t.urgency_level === 'Urgent') urgencyNumeric = 3;

      xs.push([dropoutRisk, requested, 0, remainingRatio, urgencyNumeric]);
      
      let targetRatio = t.calculated_amount / (requested || 1);
      targetRatio = Math.max(0, Math.min(1, targetRatio));
      ys.push([targetRatio]);
    }
  }

  if (xs.length > 0) {
    const xsTensor = tf.tensor2d(xs);
    const ysTensor = tf.tensor2d(ys);

    const history = await model.fit(xsTensor, ysTensor, {
      epochs: 5,
      batchSize: 32,
      shuffle: true,
      verbose: 0,
    });
    
    const modelPath = './models/grant_optimizer';
    await model.save(`file://${modelPath}`);
    
    xsTensor.dispose();
    ysTensor.dispose();
    
    return history.history.loss[history.history.loss.length - 1];
  }
  return null;
}

export async function predictGrantWithUncertainty(featureVector: number[], numPasses = 20): Promise<{ meanGrantRatio: number; variance: number; grantConfidenceScore: number }> {
  if (!model) {
    console.warn('[GrantOptimizer] Model not initialized. Returning fallback.');
    return { meanGrantRatio: 0.5, variance: 0, grantConfidenceScore: 0.5 };
  }

  try {
    const inputTensor = tf.tensor2d([featureVector], [1, 5]);
    const predictions: tf.Tensor[] = [];

    for (let i = 0; i < numPasses; i++) {
      // Use apply with { training: true } to enable dropout during inference
      const prediction = (model as any).apply(inputTensor, { training: true }) as tf.Tensor;
      predictions.push(prediction);
    }

    // Stack all predictions to calculate mean and variance
    const predictionsTensor = tf.stack(predictions);
    const meanGrantRatio = tf.mean(predictionsTensor).dataSync()[0];
    const variance = tf.moments(predictionsTensor).variance.dataSync()[0];
    const grantConfidenceScore = 1.0 - Math.min(variance * 10.0, 1.0);

    inputTensor.dispose();
    predictions.forEach(p => p.dispose());
    predictionsTensor.dispose();

    return {
      meanGrantRatio,
      variance,
      grantConfidenceScore
    };
  } catch (err) {
    console.error('[GrantOptimizer] Error during MC Dropout prediction:', err);
    return { meanGrantRatio: 0.5, variance: 0, grantConfidenceScore: 0.5 };
  }
}

export async function predictOptimalGrant(metrics: StudentMetrics): Promise<GrantPrediction> {
  try {
    // 1. Calculate Historical Grant Total
    const { data: pastTickets, error } = await supabase
      .from('tickets')
      .select('calculated_amount')
      .eq('institution_id', metrics.institutionId)
      .in('status', ['Resolved', 'Auto-Approved']);

    let historicalGrantTotal = 0;
    if (!error && pastTickets) {
      for (const t of pastTickets) {
        historicalGrantTotal += (t.calculated_amount || 0);
      }
    }

    const FINANCIAL_AID_BUDGET = 50000;
    const emergencyFundRemainingRatio = Math.max(0, (FINANCIAL_AID_BUDGET - historicalGrantTotal) / FINANCIAL_AID_BUDGET);
    const studentHistorical = 0; // Simple fallback

    let urgencyNumeric = 1;
    if (metrics.urgencyLevel === 'High') urgencyNumeric = 2;
    if (metrics.urgencyLevel === 'Urgent') urgencyNumeric = 3;

    const featureVector = [
      metrics.dropoutRiskScore,
      metrics.requestedAmount,
      studentHistorical,
      emergencyFundRemainingRatio,
      urgencyNumeric
    ];
    
    const { meanGrantRatio, variance, grantConfidenceScore } = await predictGrantWithUncertainty(featureVector);

    const recommendedAmount = Math.round(metrics.requestedAmount * meanGrantRatio * 100) / 100;

    return {
      recommendedAmount,
      confidenceScore: grantConfidenceScore,
      variance
    };
  } catch (err) {
    console.error('[GrantOptimizer] Error in optimal grant prediction:', err);
    return { recommendedAmount: Math.min(metrics.requestedAmount, 200), confidenceScore: 0.5, variance: 0 };
  }
}
