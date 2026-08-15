import 'dotenv/config';
import { supabase } from '../src/config/supabase.js';

async function checkClaimMessages() {
  const { data: messages, error } = await supabase.from('claim_messages').select('*').limit(5);
  console.log('Claim Messages Error:', error);
  console.log('Sample Claim Messages:', messages);
}

checkClaimMessages().catch(console.error);
