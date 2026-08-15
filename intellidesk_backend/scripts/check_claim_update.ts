import 'dotenv/config';
import { supabase } from '../src/config/supabase.js';

async function checkUpdate() {
  const { data: claims } = await supabase.from('claims').select('id, institution_id').limit(5);
  console.log('Current sample claims:', claims);

  if (claims && claims.length > 0) {
    const res = await supabase.from('claims').update({ institution_id: 'inst-002' }).eq('id', claims[0].id).select();
    console.log('Update res:', res.data, res.error);
  }
  process.exit(0);
}

checkUpdate();
