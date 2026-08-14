import 'dotenv/config';
import { supabase } from '../src/config/supabase.js';
import { v4 as uuidv4 } from 'uuid';

async function testTenantRegistration() {
  const instId = 'nano123';
  const instName = 'Nano Care Medical Center';
  const adminEmail = 'admin@nanocare.org';
  const adminName = 'Dr. Neil Armstrong, MD';
  const adminPhone = '+91 99887 76655';
  const specialty = 'Pediatric Trauma & Emergency Care';

  console.log(`Testing full registration for institution "${instId}"...`);

  // 1. Insert Institution
  const { data: instData, error: instError } = await supabase.from('institutions').upsert({
    id: instId,
    name: instName,
    domain: 'nanocare.org',
    default_currency: 'INR',
  }).select();

  console.log('1. Institution:', { instData, instError });

  // 2. Insert Health Fund
  const { data: fundData, error: fundError } = await supabase.from('health_funds').upsert({
    institution_id: instId,
    name: `${instName} Emergency Health Relief Fund`,
    category: 'Emergency Relief Pool',
    total_allocated: 200000.0,
    total_disbursed: 0.0,
    currency: 'INR',
  }).select();

  console.log('2. Health Fund:', { fundData, fundError });

  // 3. Insert Admin Profile
  const adminId = uuidv4();
  const { data: profData, error: profError } = await supabase.from('profiles').upsert({
    id: adminId,
    email: adminEmail,
    full_name: adminName,
    role: 'CLINICAL_ADMIN',
    institution_id: instId,
    phone: adminPhone,
    emergency_contact: specialty,
    alerts_enabled: true,
  }).select();

  console.log('3. Admin Profile:', { profData, profError });

  // 4. Insert Sample Patient Rosters
  const samplePatients = [
    {
      institution_id: instId,
      patient_id: 'PAT-NANO-001',
      email: 'patient1@nanocare.org',
      phone: '+91 91234 56780',
      is_registered: true,
    },
    {
      institution_id: instId,
      patient_id: 'PAT-NANO-002',
      email: 'patient2@nanocare.org',
      phone: '+91 91234 56781',
      is_registered: true,
    }
  ];

  const { data: rosterData, error: rosterError } = await supabase
    .from('patient_rosters')
    .insert(samplePatients)
    .select();

  console.log('4. Patient Rosters:', { rosterCount: rosterData?.length, rosterData, rosterError });

  // 5. Query All Profiles
  const { data: allProfiles } = await supabase.from('profiles').select('*');
  console.log('5. Total Profiles in DB:', allProfiles?.map(p => ({ email: p.email, name: p.full_name, role: p.role, inst: p.institution_id })));
}

testTenantRegistration();
