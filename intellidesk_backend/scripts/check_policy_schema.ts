import 'dotenv/config';
import { supabase } from '../src/config/supabase.js';

async function checkPolicyEmbeddingSchema() {
  const { data: policies } = await supabase.from('policy_embeddings').select('*').limit(5);
  console.log('Sample Policy Embeddings:');
  console.log(policies);

  const { data: sampleClaim } = await supabase.from('claims').select('id, matched_policy_id, clinical_notes').limit(1);
  console.log('Sample Claim:', sampleClaim);
}

checkPolicyEmbeddingSchema().catch(console.error);
