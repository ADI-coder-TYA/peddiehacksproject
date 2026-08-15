import 'dotenv/config';
import { supabase } from '../src/config/supabase.js';

async function checkJob8Messages() {
  const claimId = 'af33f76f-89d3-4073-bb5e-e88d6a138603';
  const { data: msgs, error } = await supabase.from('claim_messages').select('*').eq('claim_id', claimId);
  console.log('Error:', error);
  console.log('Messages for Claim', claimId, ':', msgs);
}

checkJob8Messages().catch(console.error);
