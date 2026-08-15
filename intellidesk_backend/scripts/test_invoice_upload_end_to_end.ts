import 'dotenv/config';
import { supabase } from '../src/config/supabase.js';

async function testInvoiceUploadEndToEnd() {
  console.log('🧪 Testing Full Invoice Upload with Copay Auto-Approval & Null Elimination...');

  // Create mock base64 invoice PDF
  const payload = {
    patientPhone: '+919811122334',
    studentPhone: '+919811122334',
    studentName: 'Priya Sharma',
    patientName: 'Priya Sharma',
    studentId: 'PAT-2026-002',
    patientId: 'PAT-2026-002',
    email: 'priya.sharma@campushealth.edu',
    description: 'Urgent emergency accident trauma surgery hospital bill INR ₹4305.',
    message: 'Urgent emergency accident trauma surgery hospital bill INR ₹4305.',
    clinicalCategory: 'Medical Emergency & Inpatient Care',
    category: 'Medical Emergency & Inpatient Care',
    institutionId: 'nano123',
    institution_id: 'nano123',
    media_url: 'https://iwxdsspvsenlhiigkakw.supabase.co/storage/v1/object/public/receipts/receipt_1786787411270_o2jm6.pdf',
    source: 'flutter-test-runner',
  };

  const intakeRes = await fetch('http://localhost:3000/api/v1/intake/web', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-institution-id': 'nano123',
      'x-user-role': 'PATIENT',
      'x-user-phone': '+919811122334',
      'x-user-email': 'priya.sharma@campushealth.edu',
    },
    body: JSON.stringify(payload),
  });

  const intakeJson = await intakeRes.json() as any;
  console.log('Intake Response:', intakeJson);
  const claimId = intakeJson.claimId || intakeJson.ticketId;

  console.log(`⏳ Waiting 5s for full AI worker triage & disbursement on ${claimId}...`);
  await new Promise((r) => setTimeout(r, 5000));

  const { data: claim, error } = await supabase.from('claims').select('*').eq('id', claimId).single();
  if (error || !claim) {
    throw new Error(`Failed to query claim: ${error?.message}`);
  }

  console.log('\n================ COMPLETE CLAIM AUDIT ================');
  console.log('ID:', claim.id);
  console.log('Institution ID:', claim.institution_id);
  console.log('Patient ID (UUID):', claim.patient_id);
  console.log('Patient Phone:', claim.patient_phone);
  console.log('Clinical Category:', claim.clinical_category);
  console.log('ESI Level:', claim.esi_level);
  console.log('Matched Policy ID:', claim.matched_policy_id);
  console.log('Status:', claim.status);
  console.log('Receipt URL:', claim.receipt_url);
  console.log('Receipt Image Hash:', claim.receipt_image_hash);
  console.log('Extracted Bill Amount:', claim.extracted_bill_amount);
  console.log('Recommended Copay Amount:', claim.recommended_copay_amount);
  console.log('Approved Amount:', claim.approved_amount);
  console.log('Payout Method:', claim.payout_method);
  console.log('Payout Reference:', claim.payout_reference);
  console.log('Fraud Risk Score:', claim.fraud_risk_score);
  console.log('Fraud Flags:', claim.fraud_flags);
  console.log('======================================================\n');

  const nullKeys = Object.keys(claim).filter((k) => claim[k] === null);
  console.log('Remaining NULL columns count:', nullKeys.length);
  console.log('Remaining NULL columns:', nullKeys);
  if (nullKeys.length === 0) {
    console.log('🎉 100% COMPLETE: ZERO NULL COLUMNS IN SUPABASE RECORD!');
  }
}

testInvoiceUploadEndToEnd().catch(console.error);
