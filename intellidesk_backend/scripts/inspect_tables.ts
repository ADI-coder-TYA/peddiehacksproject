import 'dotenv/config';
import { supabase } from '../src/config/supabase.js';

async function checkCols() {
  const { data, error } = await supabase.from('policy_embeddings').select('*').limit(1);
  console.log('policy_embeddings select:', data, error);

  const { data: insts } = await supabase.from('institutions').select('*');
  console.log('institutions:', insts);

  const { data: hf } = await supabase.from('health_funds').select('*');
  console.log('health_funds:', hf);

  process.exit(0);
}

checkCols();
