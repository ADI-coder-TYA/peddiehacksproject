import 'dotenv/config';
import { supabase } from '../src/config/supabase.js';

async function listLive() {
  const { data, error } = await supabase
    .from('policy_embeddings')
    .select('id, institution_id, category, policy_name, max_coverage_limit, created_at');

  if (error) {
    console.error('Error fetching live policies:', error);
  } else {
    console.log('Live policy_embeddings in Supabase:', data);
  }
}

listLive();
