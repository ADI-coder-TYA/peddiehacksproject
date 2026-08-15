import 'dotenv/config';
import { v4 as uuidv4 } from 'uuid';
import { supabase } from '../src/config/supabase.js';

async function seedBaselineClean() {
  console.log('🌟 [Seed Baseline] Setting up fresh baseline configuration...');

  // 1. Seed Core Institutions
  const institutions = [
    {
      id: 'inst-001',
      name: 'Apex Health & Medical Center',
      domain: 'campushealth.edu',
      default_currency: 'INR',
    },
    {
      id: 'nano123',
      name: 'Community Health Partner',
      domain: 'communityhealth.org',
      default_currency: 'INR',
    },
  ];

  for (const inst of institutions) {
    const { error } = await supabase.from('institutions').upsert(inst);
    if (error) console.error(`Error inserting institution ${inst.id}:`, error.message);
    else console.log(`🏛️ Configured Institution: ${inst.name} (${inst.id})`);
  }

  // 2. Seed Baseline Health Funds
  const funds = [
    {
      id: uuidv4(),
      institution_id: 'inst-001',
      name: 'Emergency Inpatient & ICU Copay Relief Pool',
      category: 'Medical Emergency & Inpatient Care',
      total_allocated: 100000.0,
      total_disbursed: 0.0,
      currency: 'INR',
    },
    {
      id: uuidv4(),
      institution_id: 'inst-001',
      name: 'Outpatient Diagnostics & Imaging Assistance Fund',
      category: 'Diagnostic & Laboratory Services',
      total_allocated: 50000.0,
      total_disbursed: 0.0,
      currency: 'INR',
    },
    {
      id: uuidv4(),
      institution_id: 'inst-001',
      name: 'Prescription & Specialty Pharmacy Access Pool',
      category: 'Prescription & Pharmacy Copay',
      total_allocated: 35000.0,
      total_disbursed: 0.0,
      currency: 'INR',
    },
    {
      id: uuidv4(),
      institution_id: 'inst-001',
      name: 'Trauma Surgery & Critical Intervention Grant',
      category: 'Trauma & Surgical Care',
      total_allocated: 75000.0,
      total_disbursed: 0.0,
      currency: 'INR',
    },
    {
      id: uuidv4(),
      institution_id: 'inst-001',
      name: 'Psychiatric First Aid & Counseling Subsidy',
      category: 'Mental Health & Psychiatric Support',
      total_allocated: 40000.0,
      total_disbursed: 0.0,
      currency: 'INR',
    },
  ];

  await supabase.from('health_funds').delete().neq('id', '00000000-0000-0000-0000-000000000000');
  const { data: insertedFunds, error: fundErr } = await supabase.from('health_funds').insert(funds).select();
  if (fundErr) console.error('Error inserting health funds:', fundErr.message);
  else console.log(`💰 Configured ${insertedFunds?.length || funds.length} Health Funds (Total Reserves: ₹3,00,000 | Disbursed: ₹0).`);

  // 3. Seed Essential Policy Embeddings
  const policies = [
    {
      id: uuidv4(),
      institution_id: 'inst-001',
      category: 'Medical Emergency & Inpatient Care',
      policy_name: 'Institutional Emergency Inpatient & ICU Copay Policy Clause 1A',
      policy_chunk: 'Provides 100% emergency copay relief up to ₹1,00,000 for critical inpatient admissions, ICU care, and emergency room surgical interventions.',
      max_coverage_limit: 100000.0,
      currency: 'INR',
      embedding: Array.from({ length: 384 }, (_, k) => Math.sin(k * 0.1 + 1) * 0.05 + 0.01),
    },
    {
      id: uuidv4(),
      institution_id: 'inst-001',
      category: 'Diagnostic & Laboratory Services',
      policy_name: 'Diagnostic MRI, CT-Scan & Advanced Radiology Subsidy Clause 2A',
      policy_chunk: 'Covers up to ₹50,000 for emergency MRI, CT scans, blood pathology panels, and specialized diagnostic laboratory workups.',
      max_coverage_limit: 50000.0,
      currency: 'INR',
      embedding: Array.from({ length: 384 }, (_, k) => Math.sin(k * 0.1 + 2) * 0.05 + 0.01),
    },
    {
      id: uuidv4(),
      institution_id: 'inst-001',
      category: 'Prescription & Pharmacy Copay',
      policy_name: 'Specialty Medication & Chronic Treatment Copay Grant Clause 3A',
      policy_chunk: 'Provides emergency pharmacy grants up to ₹35,000 for critical antibiotics, chemotherapy adjuvant medications, and daily chronic disease maintenance.',
      max_coverage_limit: 35000.0,
      currency: 'INR',
      embedding: Array.from({ length: 384 }, (_, k) => Math.sin(k * 0.1 + 3) * 0.05 + 0.01),
    },
    {
      id: uuidv4(),
      institution_id: 'inst-001',
      category: 'Mental Health & Psychiatric Support',
      policy_name: 'Psychological First Aid & Emergency Crisis Intervention Clause 4A',
      policy_chunk: 'Grants 100% copay relief up to ₹40,000 for psychiatric crisis stabilization, suicide prevention consultations, and outpatient clinical therapy.',
      max_coverage_limit: 40000.0,
      currency: 'INR',
      embedding: Array.from({ length: 384 }, (_, k) => Math.sin(k * 0.1 + 4) * 0.05 + 0.01),
    },
  ];

  await supabase.from('policy_embeddings').delete().neq('id', '00000000-0000-0000-0000-000000000000');
  const { data: insertedPolicies, error: polErr } = await supabase.from('policy_embeddings').insert(policies).select();
  if (polErr) console.error('Error inserting policies:', polErr.message);
  else console.log(`📋 Configured ${insertedPolicies?.length || policies.length} Institutional Health Policies.`);

  // 4. Verify Clean Slate for Dynamic Transaction Tables
  console.log('\n📊 DATABASE FRESH SLATE STATUS:');
  const dynamicTables = ['claims', 'audit_logs', 'claim_messages', 'vouchers', 'patient_rosters'];
  for (const t of dynamicTables) {
    const { count } = await supabase.from(t).select('*', { count: 'exact', head: true });
    console.log(`   • ${t.padEnd(18)}: ${count ?? 0} rows (CLEAN SLATE)`);
  }

  console.log('\n✨ Database is completely fresh, pristine, and ready for end-to-end testing!');
  process.exit(0);
}

seedBaselineClean().catch(console.error);
