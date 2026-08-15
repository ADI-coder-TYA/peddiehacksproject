const API_BASE = 'http://localhost:3000/api/v1';

async function testPatientClaims() {
  console.log('🧪 Testing GET /api/v1/claims for Priya Sharma with NO claims...');

  const res = await fetch(`${API_BASE}/claims?phone=%2B91%2098111%2022334&institutionId=nano123`, {
    headers: {
      'x-institution-id': 'nano123',
      'x-user-role': 'PATIENT',
      'x-user-phone': '+91 98111 22334',
    },
  });

  const json = await res.json() as any[];
  console.log('Status:', res.status);
  console.log('Claims Count:', json.length);
  console.log('Claims Data:', json);

  if (Array.isArray(json) && json.length === 0) {
    console.log('✅ PASS: Returned 0 claims (empty array) for new patient without leaking demo claims!');
  } else {
    console.log('⚠️ Claims found:', json);
  }
}

testPatientClaims().catch(console.error);
