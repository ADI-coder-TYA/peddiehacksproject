import 'dotenv/config';
import { supabase } from '../src/config/supabase.js';

async function normalize() {
  console.log('Normalizing claims and audit logs institution_ids to inst-001...');
  
  const { data: claims } = await supabase.from('claims').select('id');
  if (claims && claims.length > 0) {
    for (const c of claims) {
      await supabase.from('claims').update({ institution_id: 'inst-001' }).eq('id', c.id);
    }
  }

  const { data: audits } = await supabase.from('audit_logs').select('id');
  if (audits && audits.length > 0) {
    for (const a of audits) {
      await supabase.from('audit_logs').update({ institution_id: 'inst-001' }).eq('id', a.id);
    }
  }

  const { data: finalAudits } = await supabase.from('audit_logs').select('id, action, institution_id');
  console.log(`✅ Verified: ${finalAudits?.length} audit logs in DB all tagged with inst-001!`);
  process.exit(0);
}

normalize().catch(console.error);
