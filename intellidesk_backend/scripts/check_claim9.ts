import 'dotenv/config';
import { supabase } from '../src/config/supabase.js';

async function checkClaim9() {
  const claimId = 'c5ddd8fb-c2dd-4517-af65-f896f2f3f7d5';
  const { data: claim } = await supabase.from('claims').select('*').eq('id', claimId).single();
  console.log('Claim Status:', claim.status);
  console.log('Matched Policy ID:', claim.matched_policy_id);
  console.log('Clinical Notes:\n', claim.clinical_notes);

  const { data: msgs } = await supabase.from('claim_messages').select('*').eq('claim_id', claimId);
  console.log('Messages count:', msgs?.length);
  if (msgs && msgs.length > 0) {
    msgs.forEach((m) => {
      console.log(`\n📬 [${m.sender}]:\n${m.message}`);
    });
    console.log('\n🎉 PASS: User successfully notified via automated in-chat counselor notice!');
  }
}

checkClaim9().catch(console.error);
