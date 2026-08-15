import 'dotenv/config';
import { supabase } from '../src/config/supabase.js';

async function testCounselorAi() {
  const claimId = 'af33f76f-89d3-4073-bb5e-e88d6a138603';
  const { data, error } = await supabase.from('claim_messages').insert([
    {
      claim_id: claimId,
      sender: 'COUNSELOR_AI',
      message: '⚠️ Institutional Policy Notice: We could not find a pre-configured institutional health policy directly matching your treatment category. Your claim has been registered and forwarded to the Institutional Healthcare Review Board for discretionary copay assistance.',
      is_crisis_response: false,
    },
  ]).select('*');

  console.log('Error:', error);
  console.log('Inserted Message:', data);
}

testCounselorAi().catch(console.error);
