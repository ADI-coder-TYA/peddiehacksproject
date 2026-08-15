const API_BASE = 'http://localhost:3000/api/v1';

async function testClaimFetch() {
  const claimId = 'd2185dc4-3762-4517-b5ea-4700dd7b94ac';
  console.log(`🧪 Testing GET /api/v1/claims/${claimId}...`);

  const res = await fetch(`${API_BASE}/claims/${claimId}`, {
    headers: {
      'x-institution-id': 'nano123',
      'x-user-role': 'PATIENT',
      'x-user-phone': '+918826810145',
    },
  });

  const json = await res.json() as any;
  console.log('Status:', res.status);
  console.log('Fetched Claim:', {
    id: json.id,
    status: json.status,
    esi: json.esi_level,
    extracted_bill: json.extracted_bill_amount,
    recommended_copay: json.recommended_copay_amount,
  });

  console.log('\n🧪 Testing GET /api/v1/claims for patient in nano123...');
  const resList = await fetch(`${API_BASE}/claims?institutionId=nano123`, {
    headers: {
      'x-institution-id': 'nano123',
      'x-user-role': 'PATIENT',
      'x-user-phone': '+918826810145',
    },
  });
  const listJson = await resList.json() as any[];
  console.log('Claims in list count:', listJson.length);
  if (listJson.length > 0) {
    console.log('First claim ID in list:', listJson[0].id);
    console.log('✅ PASS: Claim list returned successfully!');
  }
}

testClaimFetch().catch(console.error);
