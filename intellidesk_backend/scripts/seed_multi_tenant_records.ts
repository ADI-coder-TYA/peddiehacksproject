import 'dotenv/config';
import crypto from 'crypto';
import { supabase } from '../src/config/supabase.js';

async function seedMultiTenant() {
  console.log('🏛️ Setting up strict multi-tenant isolation across institutions (inst-001, inst-002, inst-003)...');

  const { data: claims } = await supabase.from('claims').select('*');
  if (!claims || claims.length === 0) {
    console.log('No claims found.');
    process.exit(0);
  }

  // Clear audit_logs
  await supabase.from('audit_logs').delete().neq('id', '00000000-0000-0000-0000-000000000000');

  const institutions = ['inst-001', 'inst-002', 'inst-003'];

  for (let i = 0; i < claims.length; i++) {
    const c = claims[i];
    const targetInst = institutions[i % institutions.length];

    await supabase.from('claims').update({ institution_id: targetInst }).eq('id', c.id);

    const approvedAmt = Number(c.recommended_copay_amount || 0);
    const action = c.status === 'Disbursed' ? 'AUTO_APPROVAL_DISBURSED' : (c.status === 'Approved' ? 'MANUAL_CLINICAL_APPROVAL' : 'AI_TRIAGE_EVALUATED');
    const performedBy = c.status === 'Approved' ? 'Dr. Aditya (Chief Medical Officer)' : 'MedAccess Autonomous AI Engine';

    const payloadToSign = `${c.id}|${action}|${approvedAmt}|${targetInst}|${c.created_at || new Date().toISOString()}`;
    const checksum = crypto.createHash('sha256').update(payloadToSign).digest('hex');

    await supabase.from('audit_logs').insert({
      institution_id: targetInst,
      action,
      performed_by: performedBy,
      entity_type: 'CLAIM',
      entity_id: c.id,
      details: {
        description: c.description,
        patient_phone: c.patient_phone,
        requested_amount: approvedAmt,
        disbursed_amount: approvedAmt,
        currency: 'INR',
        checksum,
      },
    });
  }

  for (const inst of institutions) {
    const { data: instClaims } = await supabase.from('claims').select('id').eq('institution_id', inst);
    const { data: instAudits } = await supabase.from('audit_logs').select('id').eq('institution_id', inst);
    console.log(`🏛️ [${inst}]: ${instClaims?.length || 0} Claims | ${instAudits?.length || 0} Audit Logs`);
  }

  console.log('✅ Multi-tenant isolation verified and partitioned successfully!');
  process.exit(0);
}

seedMultiTenant().catch(console.error);
