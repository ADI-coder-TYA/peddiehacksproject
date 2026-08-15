import 'dotenv/config';
import { supabase } from '../src/config/supabase.js';

async function checkClaimsInDb() {
  console.log('🔍 Querying claims in Supabase...');
  const { data, error } = await supabase.from('claims').select('*').order('created_at', { ascending: false }).limit(5);
  console.log('Error:', error);
  console.log('Claims Count:', data?.length);
  if (data && data.length > 0) {
    data.forEach((c) => {
      console.log(`- Claim ID: ${c.id} | Institution: ${c.institution_id} | Status: ${c.status} | Extracted: ${c.extracted_bill_amount}`);
    });
  }
}

checkClaimsInDb().catch(console.error);
