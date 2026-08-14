import 'dotenv/config';
import { supabase } from '../src/config/supabase.js';
import { v4 as uuidv4 } from 'uuid';

async function testInsert() {
  console.log('Testing Supabase profiles and institutions insert...');

  const instId = 'inst-001';
  const instName = 'Apex Health & Medical Center';

  // 1. Insert/Upsert Institution
  const { data: instData, error: instError } = await supabase.from('institutions').upsert({
    id: instId,
    name: instName,
    domain: 'apexhealth.edu',
    default_currency: 'INR',
  }).select();

  console.log('1. Institution Result:', { instData, instError });

  // 2. Insert/Upsert Admin Profile
  const adminId = '00000000-0000-0000-0000-000000000001';
  const { data: profData, error: profError } = await supabase.from('profiles').upsert({
    id: adminId,
    email: 'admin@campushealth.edu',
    full_name: 'Dr. Sarah Chen, MD',
    role: 'CLINICAL_ADMIN',
    institution_id: instId,
    phone: '+91 98111 22334',
    emergency_contact: 'Clinical Triage & Emergency Copay Desk',
    alerts_enabled: true,
  }).select();

  console.log('2. Profile Result:', { profData, profError });

  // 3. Query profiles
  const { data: allProfiles, error: fetchError } = await supabase.from('profiles').select('*');
  console.log('3. All Profiles in Supabase:', { count: allProfiles?.length, allProfiles, fetchError });
}

testInsert();
