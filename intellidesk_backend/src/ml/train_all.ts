import '@tensorflow/tfjs-node';
import { DeepRankModel } from './deep_rank.js';
import { TemporalAttritionLSTM } from './lstm.js';
import { AnomalyAutoencoder } from './autoencoder.js';

async function main(): Promise<void> {
  console.log('🚀 IntelliDesk — Master ML Training Pipeline\n');
  console.log('Training order: DeepRank → TemporalAttritionLSTM → AnomalyAutoencoder\n');
  console.log('='.repeat(60));

  // 1. DeepRank — crisis severity regression
  console.log('\n[1/3] DeepRank');
  console.log('-'.repeat(40));
  const deepRank = new DeepRankModel();
  await deepRank.train();

  // 2. TemporalAttritionLSTM — dropout risk classification
  console.log('\n[2/3] TemporalAttritionLSTM');
  console.log('-'.repeat(40));
  const lstm = new TemporalAttritionLSTM();
  await lstm.train();

  // 3. AnomalyAutoencoder — reconstruction-based anomaly detection
  console.log('\n[3/3] AnomalyAutoencoder');
  console.log('-'.repeat(40));
  const autoencoder = new AnomalyAutoencoder();
  await autoencoder.train();

  console.log('\n' + '='.repeat(60));
  console.log('🎉 All models trained and persisted successfully!');
  console.log('   models/deep_rank/      → DeepRank (crisis_severity_index)');
  console.log('   models/lstm/           → TemporalAttritionLSTM (dropout_risk)');
  console.log('   models/autoencoder/    → AnomalyAutoencoder (reconstruction)');
}

main().catch(err => {
  console.error('\n❌ Training pipeline failed:', err);
  process.exit(1);
});
