import 'dotenv/config';
import { supabase } from '../src/config/supabase.js';

async function inspectPolicies() {
  const { data: pe, error: peErr } = await supabase.from('policy_embeddings').select('*').limit(2);
  console.log('policy_embeddings:', peErr ? peErr.message : `Found ${pe?.length} rows`);
  if (pe && pe.length > 0) {
    console.log('Sample row keys:', Object.keys(pe[0]));
  }
}

inspectPolicies().catch(console.error);
