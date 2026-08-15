import 'dotenv/config';
import { supabase } from '../src/config/supabase.js';

async function testFullIntakeAndCheckNulls() {
  console.log('🧪 Testing End-to-End Multimodal Intake & Null Field Elimination...');

  // 1. Submit claim via /api/v1/intake/web
  const payload = {
    patientPhone: '+918826810145',
    studentPhone: '+918826810145',
    studentName: 'Priya Sharma',
    patientName: 'Priya Sharma',
    studentId: 'PAT-2026-002',
    patientId: 'PAT-2026-002',
    email: 'priya.sharma@campushealth.edu',
    description: 'Emergency accident trauma care needed immediately.',
    message: 'Emergency accident trauma care needed immediately.',
    clinicalCategory: 'Medical Emergency & Inpatient Care',
    category: 'Medical Emergency & Inpatient Care',
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
      'x-user-phone': '+918826810145',
      'x-user-email': 'priya.sharma@campushealth.edu',
    },
    body: JSON.stringify(payload),
  });

  const intakeJson = await intakeRes.json() as any;
  console.log('Intake response status:', intakeRes.status);
  console.log('Intake response body:', intakeJson);

  const claimId = intakeJson.claimId || intakeJson.ticketId;
  if (!claimId) {
    throw new Error('No claimId returned from intake endpoint');
  }

  console.log(`⏳ Waiting 3.5s for BullMQ triage worker to finish on claim ${claimId}...`);
  await new Promise((r) => setTimeout(r, 3500));

  // 2. Fetch updated claim from Supabase
  const { data: claim, error } = await supabase.from('claims').select('*').eq('id', claimId).single();
  if (error || !claim) {
    throw new Error(`Failed to query claim from Supabase: ${error?.message}`);
  }

  console.log('\n================ RECORD AUDIT ================');
  console.log('ID:', claim.id);
  console.log('Institution ID:', claim.institution_id);
  console.log('Patient ID (UUID):', claim.patient_id);
  console.log('Patient Phone:', claim.patient_phone);
  console.log('Clinical Category:', claim.clinical_category);
  console.log('ESI Level:', claim.esi_level);
  console.log('Matched Policy ID:', claim.matched_policy_id);
  console.log('Status:', claim.status);
  console.log('Extracted Bill Amount:', claim.extracted_bill_amount);
  console.log('Recommended Copay Amount:', claim.recommended_copay_amount);
  console.log('Approved Amount:', claim.approved_amount);
  console.log('Payout Method:', claim.payout_method);
  console.log('Payout Reference:', claim.payout_reference);
  console.log('Fraud Risk Score:', claim.fraud_risk_score);
  console.log('Fraud Flags:', claim.fraud_flags);
  console.log('==============================================\n');

  const nullKeys = Object.keys(claim).filter((k) => claim[k] === null);
  console.log('Remaining NULL columns:', nullKeys);
}

testFullIntakeAndCheckNulls().catch(console.error);
