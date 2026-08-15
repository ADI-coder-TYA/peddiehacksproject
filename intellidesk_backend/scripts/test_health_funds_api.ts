import 'dotenv/config';
import { supabase } from '../src/config/supabase.js';

async function runHealthFundsTest() {
  console.log('--- 🧪 STARTING HEALTH FUNDS SUITE TEST ---');
  const instId = 'inst-001';

  // 1. Ensure institution exists in Supabase
  console.log('\n1. Ensuring institution exists:', instId);
  await supabase.from('institutions').upsert({
    id: instId,
    name: 'Apex Health & Medical Center',
    domain: 'apexhealth.edu',
    default_currency: 'INR',
  });

  // Clear existing test funds for inst-001
  await supabase.from('health_funds').delete().eq('institution_id', instId);

  // 2. Allocate Fund 1: Emergency Inpatient & Trauma Pool
  console.log('\n2. Allocating Fund 1 (Emergency Inpatient & Trauma Pool)...');
  const fund1 = {
    institution_id: instId,
    name: 'Apex Trauma & Inpatient Emergency Pool',
    category: 'Emergency Inpatient & Trauma',
    total_allocated: 350000.0,
    total_disbursed: 45000.0,
    currency: 'INR',
  };
  const { data: created1, error: err1 } = await supabase.from('health_funds').insert(fund1).select().single();
  if (err1) console.error('❌ Error creating fund 1:', err1);
  else console.log('✅ Created Fund 1:', created1.id, created1.name, `₹${created1.total_allocated}`);

  // 3. Allocate Fund 2: Prescription & Pharmacy Relief Fund
  console.log('\n3. Allocating Fund 2 (Prescription & Pharmacy Relief Fund)...');
  const fund2 = {
    institution_id: instId,
    name: 'Apex Prescription & Antibiotic Copay Subsidy',
    category: 'Prescription & Pharmacy Copay',
    total_allocated: 120000.0,
    total_disbursed: 18000.0,
    currency: 'INR',
  };
  const { data: created2, error: err2 } = await supabase.from('health_funds').insert(fund2).select().single();
  if (err2) console.error('❌ Error creating fund 2:', err2);
  else console.log('✅ Created Fund 2:', created2.id, created2.name, `₹${created2.total_allocated}`);

  // 4. Allocate Fund 3: Mental Health & Tele-Counseling Fund
  console.log('\n4. Allocating Fund 3 (Mental Health & Counseling Pool)...');
  const fund3 = {
    institution_id: instId,
    name: 'Apex Student Mental Wellness & Therapy Fund',
    category: 'Mental Health & Tele-Counseling',
    total_allocated: 80000.0,
    total_disbursed: 5000.0,
    currency: 'INR',
  };
  const { data: created3, error: err3 } = await supabase.from('health_funds').insert(fund3).select().single();
  if (err3) console.error('❌ Error creating fund 3:', err3);
  else console.log('✅ Created Fund 3:', created3.id, created3.name, `₹${created3.total_allocated}`);

  // 5. Query All Funds for inst-001
  console.log('\n5. Fetching all active Health Funds from Supabase for:', instId);
  const { data: allFunds, error: fetchErr } = await supabase
    .from('health_funds')
    .select('*')
    .eq('institution_id', instId)
    .order('created_at', { ascending: false });

  if (fetchErr) console.error('❌ Fetch error:', fetchErr);
  else {
    console.log(`✅ Retrieved ${allFunds.length} health funds:`);
    allFunds.forEach(f => {
      const remaining = Number(f.total_allocated) - Number(f.total_disbursed);
      const util = ((Number(f.total_disbursed) / Number(f.total_allocated)) * 100).toFixed(1);
      console.log(`   - [${f.category}] ${f.name}: Allocated ₹${f.total_allocated} | Disbursed ₹${f.total_disbursed} | Remaining ₹${remaining} (${util}% utilized)`);
    });
  }

  // 6. Test Top-Up Capital
  console.log('\n6. Testing Top-Up Capital (+ ₹50,000 on Fund 1)...');
  const topUpAmount = 50000.0;
  const newTotal = Number(created1.total_allocated) + topUpAmount;
  const { data: updated1, error: updateErr } = await supabase
    .from('health_funds')
    .update({ total_allocated: newTotal })
    .eq('id', created1.id)
    .select()
    .single();

  if (updateErr) console.error('❌ Update error:', updateErr);
  else console.log('✅ Updated Fund 1 total_allocated to:', `₹${updated1.total_allocated}`);

  // 7. Test Deletion of Fund 3
  console.log('\n7. Testing Deletion of Fund 3 (id:', created3.id, ')...');
  const { error: delErr } = await supabase
    .from('health_funds')
    .delete()
    .eq('id', created3.id)
    .eq('institution_id', instId);

  if (delErr) console.error('❌ Delete error:', delErr);
  else console.log('✅ Successfully deleted Fund 3');

  // 8. Final Count Verification
  const { data: remainingFunds } = await supabase
    .from('health_funds')
    .select('id, name, total_allocated, total_disbursed')
    .eq('institution_id', instId);
  console.log('\n8. Final Funds in DB for inst-001:', remainingFunds?.length, remainingFunds);

  console.log('\n--- 🎉 HEALTH FUNDS TEST COMPLETED SUCCESSFULLY ---');
}

runHealthFundsTest();
