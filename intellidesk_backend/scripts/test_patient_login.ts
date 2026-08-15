const API_BASE = 'http://localhost:3000/api/v1';

async function testPatientLogin() {
  console.log('🧪 Testing Patient Login for Priya Sharma (priya.sharma@campushealth.edu)...');

  const res = await fetch(`${API_BASE}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      email: 'priya.sharma@campushealth.edu',
      password: 'Patient@123',
      role: 'PATIENT',
    }),
  });

  const json = await res.json() as any;
  console.log('Status:', res.status);
  console.log('Response User:', json.user);

  if (json.user?.institutionId === 'nano123') {
    console.log('✅ PASS: Institution ID correctly resolved as "nano123" from Supabase patient_rosters!');
  } else {
    console.log('⚠️ Institution ID received:', json.user?.institutionId);
  }

  if (!json.user?.department) {
    console.log('✅ PASS: No fake medical department/specialty attached to patient!');
  }
}

testPatientLogin().catch(console.error);
