import 'dotenv/config';
import { supabase } from '../src/config/supabase.js';

async function main() {
  const { data, error } = await supabase
    .from('tickets')
    .select('*')
    .eq('id', '04094f59-7402-4139-8749-ed07b02b1cc4')
    .single();

  console.log('Ticket 04094f59-7402-4139-8749-ed07b02b1cc4:');
  console.log({
    id: data?.id,
    raw_message: data?.raw_message,
    media_url: data?.media_url ? (data.media_url.startsWith('data:') ? `[Base64: ${data.media_url.length} chars]` : data.media_url) : null,
    parsed_category: data?.parsed_category,
    calculated_amount: data?.calculated_amount,
    currency: data?.currency,
    created_at: data?.created_at
  });
}

main();
