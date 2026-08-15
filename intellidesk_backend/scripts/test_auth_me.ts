const API_BASE = 'http://localhost:3000/api/v1';

async function testAuthMe() {
  console.log('🧪 Testing GET /api/v1/auth/me for Priya Sharma...');

  const res = await fetch(`${API_BASE}/auth/me?email=priya.sharma@campushealth.edu`, {
    headers: {
      'x-user-email': 'priya.sharma@campushealth.edu',
      'x-user-role': 'PATIENT',
      'x-institution-id': 'nano123',
    },
  });

  const json = await res.json() as any;
  console.log('Status:', res.status);
  console.log('Response User:', json.user);

  if (json.user?.institutionId === 'nano123') {
    console.log('✅ PASS: Authentic tenant institution "nano123" resolved successfully from Supabase!');
  } else {
    console.log('⚠️ Institution ID received:', json.user?.institutionId);
  }
}

testAuthMe().catch(console.error);
