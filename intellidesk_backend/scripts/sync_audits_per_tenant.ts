import 'dotenv/config';
import crypto from 'crypto';
import { supabase } from '../src/config/supabase.js';

async function syncAuditsPerTenant() {
  console.log('🏛️ Syncing audit logs strictly per-tenant from claims table...');

  // Fetch all claims
  const { data: claims } = await supabase.from('claims').select('*');
  if (!claims || claims.length === 0) {
    console.log('No claims found.');
    process.exit(0);
  }

  // Clear existing audit_logs
  await supabase.from('audit_logs').delete().neq('id', '00000000-0000-0000-0000-000000000000');

  let count = 0;
  for (const c of claims) {
    const claimId = c.id;
    const instId = c.institution_id || 'inst-001';
    const status = c.status || 'Submitted';
    const approvedAmt = Number(c.approved_amount || c.recommended_copay_amount || 0);

    let action = 'AI_TRIAGE_EVALUATED';
    let performedBy = 'MedAccess Autonomous AI';

    if (status === 'Disbursed' || status === 'Auto-Approved') {
      action = 'AUTO_APPROVAL_DISBURSED';
      performedBy = 'MedAccess Autonomous AI Engine';
    } else if (status === 'Approved') {
      action = 'MANUAL_CLINICAL_APPROVAL';
      performedBy = 'Dr. Aditya (Chief Medical Officer)';
    } else if (status === 'Flagged' || (c.fraud_risk_score && c.fraud_risk_score > 0.6)) {
      action = 'FRAUD_QUARANTINE_ALERT';
      performedBy = 'Fraud Sentinel AI';
    } else if (c.is_life_safety_alert || c.esi_level === 'ESI_1_CRITICAL') {
      action = 'LIFE_SAFETY_CRISIS_OVERRIDE';
      performedBy = 'Emergency Crisis Intervention Layer';
    }

    const payloadToSign = `${claimId}|${action}|${approvedAmt}|${instId}|${c.created_at || new Date().toISOString()}`;
    const checksum = crypto.createHash('sha256').update(payloadToSign).digest('hex');

    const auditPayload = {
      institution_id: instId,
      action: action,
      performed_by: performedBy,
      entity_type: 'CLAIM',
      entity_id: claimId,
      details: {
        esi_level: c.esi_level || 'ESI_3_URGENT',
        clinical_category: c.clinical_category || 'Medical Emergency & Inpatient Care',
        description: c.description,
        patient_phone: c.patient_phone,
        requested_amount: Number(c.extracted_bill_amount || c.recommended_copay_amount || 0),
        disbursed_amount: approvedAmt,
        currency: c.currency || 'INR',
        fraud_risk_score: Number(c.fraud_risk_score || 0),
        payout_reference: c.payout_reference || (status === 'Disbursed' ? 'pout_demo_settled' : null),
        payout_method: c.payout_method || 'RAZORPAY_UPI',
        checksum: checksum,
      },
    };

    const { error: insErr } = await supabase.from('audit_logs').insert(auditPayload);
    if (!insErr) count++;
  }

  console.log(`✅ Successfully synced ${count} strict per-tenant audit logs.`);

  const { data: inst1Audits } = await supabase.from('audit_logs').select('id').eq('institution_id', 'inst-001');
  const { data: nanoAudits } = await supabase.from('audit_logs').select('id').eq('institution_id', 'nano123');

  console.log(`📊 [inst-001 Audit Logs]: ${inst1Audits?.length || 0}`);
  console.log(`📊 [nano123 Audit Logs]: ${nanoAudits?.length || 0}`);

  process.exit(0);
}

syncAuditsPerTenant().catch(console.error);
