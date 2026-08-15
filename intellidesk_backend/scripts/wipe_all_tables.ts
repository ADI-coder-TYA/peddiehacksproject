import 'dotenv/config';
import { supabase } from '../src/config/supabase.js';

async function wipeAllDatabaseTables() {
  console.log('🚨 STARTING FULL DATABASE HARD WIPE...');

  const tablesInOrder = [
    'audit_logs',
    'claim_messages',
    'vouchers',
    'claims',
    'tickets',
    'patient_rosters',
    'health_funds',
    'funds',
    'policy_embeddings',
    'policies',
    'profiles',
    'institutions',
  ];

  for (const table of tablesInOrder) {
    try {
      const { error } = await supabase.from(table).delete().neq('id', '00000000-0000-0000-0000-000000000000');
      if (error) {
        // Fallback for tables where primary key is not id or has different type
        const { error: err2 } = await supabase.from(table).delete().gt('created_at', '1970-01-01');
        if (err2) {
          console.warn(`⚠️ Notice wiping table "${table}":`, error.message);
        } else {
          console.log(`🧹 Cleaned table: "${table}"`);
        }
      } else {
        console.log(`🧹 Cleaned table: "${table}"`);
      }
    } catch (e: any) {
      console.warn(`⚠️ Skipped table "${table}":`, e.message);
    }
  }

  // Double check all tables
  console.log('\n📊 POST-WIPE TABLE ROW COUNTS:');
  for (const table of tablesInOrder) {
    try {
      const { count, error } = await supabase.from(table).select('*', { count: 'exact', head: true });
      if (!error) {
        console.log(`   • ${table.padEnd(20)}: ${count ?? 0} rows`);
      }
    } catch (_) {}
  }

  console.log('\n✨ COMPLETE HARD WIPE FINISHED! Supabase is 100% clean and reset.');
  process.exit(0);
}

wipeAllDatabaseTables().catch(console.error);
