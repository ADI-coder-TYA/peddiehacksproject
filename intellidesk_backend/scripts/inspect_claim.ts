import 'dotenv/config';
import { supabase } from '../src/config/supabase.js';

async function inspectClaim() {
  const claimId = 'dfaa1d55-7630-43e4-8dc5-6a70b91dc6e8';
  const { data: claim } = await supabase.from('claims').select('*').eq('id', claimId).single();
  console.log('Final Claim State:');
  console.log(JSON.stringify(claim, null, 2));

  const nullKeys = Object.keys(claim).filter((k) => claim[k] === null);
  console.log('\nRemaining NULL columns count:', nullKeys.length);
  console.log('Remaining NULL columns:', nullKeys);
}

inspectClaim().catch(console.error);
