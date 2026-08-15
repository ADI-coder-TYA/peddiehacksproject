import 'dotenv/config';
import { supabase } from '../src/config/supabase.js';

async function verifyTable() {
  const testId = '00000000-0000-0000-0000-000000000001';
  
  // Ensure institution exists
  await supabase.from('institutions').upsert({
    id: 'inst-001',
    name: 'Apex Health & Medical Center',
    domain: 'campushealth.edu',
    default_currency: 'INR'
  });

  const { error: insertErr } = await supabase.from('policy_embeddings').insert({
    id: testId,
    institution_id: 'inst-001',
    category: 'Medical Emergency & Inpatient Care',
    policy_name: 'Test Policy Verification',
    policy_chunk: 'Sample test chunk content for verification.',
    max_coverage_limit: 250000.00,
    currency: 'INR',
  });

  if (insertErr) {
    console.error('Insert verification error:', insertErr);
    return false;
  }

  const { data, error: selectErr } = await supabase
    .from('policy_embeddings')
    .select('*')
    .eq('id', testId)
    .single();

  if (selectErr) {
    console.error('Select verification error:', selectErr);
    return false;
  }

  console.log('✅ Live schema verified:', Object.keys(data));
  console.log('Row:', data);

  // Clean up test row
  await supabase.from('policy_embeddings').delete().eq('id', testId);
  console.log('✅ Cleaned up verification row.');
  return true;
}

verifyTable();
