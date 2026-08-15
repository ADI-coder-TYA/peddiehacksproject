import 'dotenv/config';
import { supabase } from '../src/config/supabase.js';

async function checkSchema() {
  const { data, error } = await supabase
    .from('policy_embeddings')
    .select('*')
    .limit(1);

  if (error) {
    console.error('Schema check error:', error);
  } else {
    console.log('Sample row from policy_embeddings:', data);
  }
}

checkSchema();
