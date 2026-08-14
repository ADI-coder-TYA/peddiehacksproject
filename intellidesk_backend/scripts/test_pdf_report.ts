import 'dotenv/config';
import { fetchReportMetrics, generateExecutiveReport } from '../src/services/pdfReportService.js';

async function testPdfGeneration() {
  console.log('🧪 Testing Executive PDF Audit Report Generator metrics...\n');

  const metrics = await fetchReportMetrics('edu-admin-123', '30d');
  console.log('Fetched Metrics:', JSON.stringify(metrics, null, 2));

  const pdfBuffer = await generateExecutiveReport('30d', 'edu-admin-123');
  console.log(`\n✅ Generated PDF Report Buffer Size: ${pdfBuffer.length} bytes`);
}

testPdfGeneration().catch((err) => {
  console.error('❌ Test failed:', err);
  process.exit(1);
});
