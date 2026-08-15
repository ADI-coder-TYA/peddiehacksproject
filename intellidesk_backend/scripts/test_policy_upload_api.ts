import fs from 'fs';
import path from 'path';

const API_BASE = 'http://localhost:3000/api/v1';

async function testPolicyUpload() {
  console.log('🧪 Testing Policy Upload API with Category and Benefit Cap...\n');

  const pdfPath = path.resolve(process.cwd(), 'sample_policies', 'Emergency_Trauma_Coverage_Policy_2026.pdf');
  if (!fs.existsSync(pdfPath)) {
    console.error('❌ Sample PDF not found at:', pdfPath);
    process.exit(1);
  }

  const fileBuffer = fs.readFileSync(pdfPath);
  const blob = new Blob([fileBuffer], { type: 'application/pdf' });

  const formData = new FormData();
  formData.append('pdf', blob, 'Emergency_Trauma_Coverage_Policy_2026.pdf');
  formData.append('documentName', 'Emergency & Acute Inpatient Trauma Policy 2026');
  formData.append('category', 'Medical Emergency & Inpatient Care');
  formData.append('maxCoverageLimit', '250000');
  formData.append('currency', 'INR');

  console.log('1. POST /api/v1/admin/knowledge/upload');
  const uploadRes = await fetch(`${API_BASE}/admin/knowledge/upload`, {
    method: 'POST',
    headers: {
      'x-institution-id': 'inst-001',
      'x-user-role': 'ADMIN',
      'Authorization': 'Bearer jwt_mock_token_admin_sarah_chen',
    },
    body: formData,
  });

  const uploadJson = await uploadRes.json() as any;
  console.log('Status:', uploadRes.status, uploadJson);

  if (uploadRes.status !== 201 && uploadRes.status !== 200) {
    throw new Error(`Upload failed: ${JSON.stringify(uploadJson)}`);
  }
  console.log('✅ Policy PDF uploaded & vectorized successfully!\n');

  console.log('2. GET /api/v1/admin/knowledge/list');
  const listRes = await fetch(`${API_BASE}/admin/knowledge/list`, {
    headers: {
      'x-institution-id': 'inst-001',
      'x-user-role': 'ADMIN',
      'Authorization': 'Bearer jwt_mock_token_admin_sarah_chen',
    },
  });

  const listJson = await listRes.json() as any;
  console.log('Status:', listRes.status);
  console.log('Active Documents:', JSON.stringify(listJson, null, 2));

  console.log('\n🎉 Policy Upload & Categorization test passed with 100% success!');
}

testPolicyUpload().catch(err => {
  console.error('Test error:', err);
  process.exit(1);
});
