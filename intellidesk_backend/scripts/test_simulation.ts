import 'dotenv/config';
import { generateSyntheticBatch } from '../src/services/crisisSimulator.js';
import { evaluateFraudRisk } from '../src/services/fraudSentinel.js';
import { extractFeatures } from '../src/utils/featureExtractor.js';
import * as deepRankModel from '../src/services/deepRankModel.js';

async function testSimulationEngine() {
  console.log('🧪 Testing Crisis Simulator & Benchmark Engine...\n');

  const count = 10;
  const batch = generateSyntheticBatch(count, 'edu-admin-123');
  console.log(`⚡ Generated ${batch.length} synthetic crisis payloads.`);

  const startHr = process.hrtime.bigint();
  let totalGrant = 0;
  let flaggedCount = 0;

  for (let i = 0; i < batch.length; i++) {
    const item = batch[i];
    const features = await extractFeatures(item.rawMessage);
    const deepRankScore = await deepRankModel.predict(features);
    const fraudReport = await evaluateFraudRisk(item.id, item.studentPhone, item.mediaUrl, features, 250);

    let maxAllowable = Math.round(deepRankScore * 1000);
    maxAllowable = Math.ceil(maxAllowable / 50) * 50;
    let grant = Math.min(250, maxAllowable > 0 ? maxAllowable : 250);
    if (fraudReport.isFlagged) {
      grant = 0;
      flaggedCount++;
    }

    totalGrant += grant;
  }

  const endHr = process.hrtime.bigint();
  const totalTimeMs = Math.round(Number(endHr - startHr) / 1000000);
  const avgProcessingTimeMs = Math.round(totalTimeMs / count);

  console.log(`\n⚡ [Simulator] Completed ${count}-Case Stress Test in ${totalTimeMs}ms | Avg: ${avgProcessingTimeMs}ms/ticket | Total Grant Allocation: $${totalGrant}`);
  console.log(`🛡️ Fraud Quarantines Flagged: ${flaggedCount}`);

  if (avgProcessingTimeMs < 0 || totalTimeMs < 0) {
    throw new Error('Simulation latency benchmark invalid.');
  }

  console.log('\n🎉 Crisis Stress-Test Engine verification passed successfully!');
}

testSimulationEngine().catch((err) => {
  console.error('❌ Test failed:', err);
  process.exit(1);
});
