import 'dotenv/config';
import { evaluateFraudRisk, computeImageHash } from '../src/services/fraudSentinel.js';

async function testFraudSentinel() {
  console.log('🧪 Testing Emergency Fund Fraud & Duplicate Detection Sentinel...\n');

  // 1. Test Image Hashing
  const sampleMediaUrl = 'https://example.com/hospital_receipt_receipt_123.jpg';
  const hash = await computeImageHash(sampleMediaUrl);
  console.log(`📸 Image Hash Computed: ${hash}`);
  if (!hash) throw new Error('Image hash calculation failed.');

  // 2. Test Normal Ticket Evaluation
  console.log('\n--- Scenario 1: Clean Normal Ticket ---');
  const normalReport = await evaluateFraudRisk(
    'test-ticket-001',
    '+15550001111',
    'https://example.com/valid_receipt.jpg',
    [15, 0, 0.8, 1],
    100
  );
  console.log('Normal Ticket Report:', JSON.stringify(normalReport, null, 2));

  // 3. Test High Velocity & Threshold Gaming
  console.log('\n--- Scenario 2: High Velocity & Micro-Grant Gaming Ticket ---');
  const gamingReport = await evaluateFraudRisk(
    'test-ticket-002',
    '+15550001111',
    'https://example.com/valid_receipt.jpg',
    [50, 4, 0.1, 5],
    180
  );
  console.log('Gaming Ticket Report:', JSON.stringify(gamingReport, null, 2));

  // 4. Test Autoencoder Anomaly Scoring
  console.log('\n--- Scenario 3: Anomalous Payload (Autoencoder MSE >= 0.75) ---');
  const anomalousFeatures = [250, 15, -0.9, 15]; // Extreme anomalous feature vector
  const anomalyReport = await evaluateFraudRisk(
    'test-ticket-003',
    '+15559998888',
    undefined,
    anomalousFeatures,
    950
  );
  console.log('Anomaly Ticket Report:', JSON.stringify(anomalyReport, null, 2));

  console.log('\n✅ All Fraud Sentinel Scenarios Evaluated Successfully!');
}

testFraudSentinel().catch((err) => {
  console.error('❌ Test failed:', err);
  process.exit(1);
});
