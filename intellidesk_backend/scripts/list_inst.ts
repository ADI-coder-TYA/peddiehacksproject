import 'dotenv/config';
import { supabase } from '../src/config/supabase.js';

async function listInst() {
  const { data: insts } = await supabase.from('institutions').select('*');
  console.log('INSTITUTIONS in DB:', insts);
  process.exit(0);
}

listInst();
