import 'dotenv/config';
import { supabase } from '../src/config/supabase.js';

async function main() {
  const { data: claims } = await supabase.from('claims').select('*').order('created_at', { ascending: false }).limit(3);
  console.log('Recent Claims:');
  console.dir(claims, { depth: null });

  const { data: tickets } = await supabase.from('tickets').select('*').order('created_at', { ascending: false }).limit(3);
  console.log('Recent Tickets:');
  console.dir(tickets, { depth: null });
}

main().catch(console.error);
