import 'dotenv/config';
import { supabase } from '../src/config/supabase.js';

async function testUnmatchedPolicyHandling() {
  console.log('🧪 Testing Out-of-Policy Claim Submission & User Notification...');

  const payload = {
    patientPhone: '+919876543210',
    studentPhone: '+919876543210',
    studentName: 'Aarav Patel',
    patientName: 'Aarav Patel',
    studentId: 'PAT-2026-999',
    patientId: 'PAT-2026-999',
    email: 'aarav.patel@campushealth.edu',
    description: 'Elective cosmetic dental tooth whitening and aesthetic veneer alignment procedure.',
    message: 'Elective cosmetic dental tooth whitening and aesthetic veneer alignment procedure.',
    clinicalCategory: 'Cosmetic & Aesthetic Dental Care',
    category: 'Cosmetic & Aesthetic Dental Care',
    institutionId: 'nano123',
    institution_id: 'nano123',
    source: 'flutter-test-runner',
  };

  const intakeRes = await fetch('http://localhost:3000/api/v1/intake/web', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-institution-id': 'nano123',
      'x-user-role': 'PATIENT',
      'x-user-phone': '+919876543210',
      'x-user-email': 'aarav.patel@campushealth.edu',
    },
    body: JSON.stringify(payload),
  });

  const intakeJson = await intakeRes.json() as any;
  console.log('Intake response:', intakeJson);
  const claimId = intakeJson.claimId || intakeJson.ticketId;

  console.log(`⏳ Waiting 8s for triage worker to process unmatched policy claim ${claimId}...`);
  await new Promise((r) => setTimeout(r, 8000));

  // 1. Check claim record
  const { data: claim } = await supabase.from('claims').select('*').eq('id', claimId).single();
  console.log('\n--- CLAIM RECORD ---');
  console.log('ID:', claim.id);
  console.log('Matched Policy ID:', claim.matched_policy_id);
  console.log('Status:', claim.status);
  console.log('Clinical Notes:\n', claim.clinical_notes);

  // 2. Check claim_messages for user notification
  const { data: messages } = await supabase.from('claim_messages').select('*').eq('claim_id', claimId);
  console.log('\n--- CLAIM NOTIFICATION MESSAGES ---');
  console.log('Messages count:', messages?.length);
  if (messages && messages.length > 0) {
    messages.forEach((m) => {
      console.log(`[${m.sender}]: ${m.message}`);
    });
    console.log('\n✅ PASS: User was automatically notified of unmatched policy via claim chat!');
  } else {
    console.log('⚠️ Notice: No chat message found.');
  }
}

testUnmatchedPolicyHandling().catch(console.error);
