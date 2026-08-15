import 'dotenv/config';
import { supabase } from '../src/config/supabase.js';

async function testMoreSenders() {
  const claimId = 'af33f76f-89d3-4073-bb5e-e88d6a138603';
  const candidates = ['STUDENT', 'COUNSELLOR', 'AI', 'AGENT', 'DOCTOR', 'CLINICIAN', 'SYSTEM_AGENT', 'COPAY_ASSISTANT', 'SYSTEM_NOTICE'];

  for (const sender of candidates) {
    const { data, error } = await supabase.from('claim_messages').insert([
      {
        claim_id: claimId,
        sender,
        message: `Testing sender ${sender}`,
        is_crisis_response: false,
      },
    ]).select('*');

    if (!error && data) {
      console.log(`✅ SUCCESS for sender: "${sender}"`);
      await supabase.from('claim_messages').delete().eq('id', data[0].id);
    } else {
      console.log(`❌ FAILED for sender: "${sender}" (${error?.message})`);
    }
  }
}

testMoreSenders().catch(console.error);
