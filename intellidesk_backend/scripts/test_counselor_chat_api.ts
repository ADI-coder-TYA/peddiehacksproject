const API_BASE = 'http://localhost:3000/api/v1';

async function testCounselorChat() {
  const claimId = 'dfaa1d55-7630-43e4-8dc5-6a70b91dc6e8';
  console.log('🧪 Testing POST /api/v1/chat/claims/:id/messages...');

  const startTime = Date.now();
  const res = await fetch(`${API_BASE}/chat/claims/${claimId}/messages`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-institution-id': 'nano123',
      'x-user-role': 'PATIENT',
    },
    body: JSON.stringify({
      message: 'I got CT Scan reports and now have severe stress',
      patientPhone: '+919811122334',
    }),
  });

  const latency = Date.now() - startTime;
  console.log(`HTTP Status: ${res.status} | Latency: ${latency}ms`);
  const json = await res.json() as any;
  console.log('\nCounselor Response:\n', json);

  if (res.status === 200 && json.reply) {
    console.log('\n✅ PASS: Clinical Counselor responded fast and successfully!');
  }
}

testCounselorChat().catch(console.error);
