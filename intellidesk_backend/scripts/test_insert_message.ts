import 'dotenv/config';
import { supabase } from '../src/config/supabase.js';

async function testInsertMessage() {
  const claimId = 'af33f76f-89d3-4073-bb5e-e88d6a138603';
  const { data, error } = await supabase.from('claim_messages').insert([
    {
      claim_id: claimId,
      sender: 'SYSTEM',
      message: 'Test policy notice message',
      is_crisis_response: false,
    },
  ]).select('*');

  console.log('Insert Error:', error);
  console.log('Inserted Data:', data);
}

testInsertMessage().catch(console.error);
