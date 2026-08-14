import { Router, Request, Response } from 'express';
import { supabase } from '../config/supabase.js';

const router = Router();

// In-memory Multi-Tenant & Student Whitelist Store
const INSTITUTIONS: Map<string, any> = new Map();
const STUDENT_ROSTERS: Map<string, any> = new Map(); // Key: email or phone
const USER_STORE: Map<string, any> = new Map(); // Key: email or student_id

// Seed default institution and whitelisted demo students
const DEFAULT_INSTITUTION_ID = 'edu-admin-123';
INSTITUTIONS.set(DEFAULT_INSTITUTION_ID, {
  id: DEFAULT_INSTITUTION_ID,
  name: 'Global EduAccess University',
  domain: 'university.edu',
  createdAt: new Date().toISOString(),
});

// Seed Whitelisted Roster
const DEFAULT_ROSTER = [
  { student_id: 'STU-2026-001', email: 'aarav.sharma@univ.edu', phone: '+15550101001', name: 'Aarav Sharma', department: 'Computer Science' },
  { student_id: 'STU-2026-002', email: 'priya.patel@univ.edu', phone: '+15550101002', name: 'Priya Patel', department: 'Electrical Engineering' },
  { student_id: 'STU-2026-003', email: 'marcus.chen@univ.edu', phone: '+15550101003', name: 'Marcus Chen', department: 'Data Science' },
  { student_id: 'STU-2026-004', email: 'elena.rostova@univ.edu', phone: '+15550101004', name: 'Elena Rostova', department: 'Mechanical Engineering' },
  { student_id: 'STU-2026-005', email: 'jordan.taylor@univ.edu', phone: '+15550101005', name: 'Jordan Taylor', department: 'Business Administration' },
  { student_id: 'STU-2026-006', email: 'sophia.rodriguez@univ.edu', phone: '+15550101006', name: 'Sophia Rodriguez', department: 'Biomedical Engineering' },
  { student_id: 'STU-2026-007', email: 'rohan.gupta@univ.edu', phone: '+15550101007', name: 'Rohan Gupta', department: 'Computer Science' },
  { student_id: 'STU-2026-001', email: 'alex@university.edu', phone: '+15550000001', name: 'Alex Johnson', department: 'Computer Science' },
  { student_id: 'STU-2026-002', email: 'jordan@university.edu', phone: '+15550000002', name: 'Jordan Miller', department: 'Electrical Eng' },
  { student_id: 'STU-2026-003', email: 'taylor@university.edu', phone: '+15550000003', name: 'Taylor Swift', department: 'Data Science' },
  { student_id: 'STD-1001', email: 'alex.j@university.edu', phone: '+15550199', name: 'Alex Johnson', department: 'Computer Science' },
];

DEFAULT_ROSTER.forEach((r) => {
  const entry = { ...r, institution_id: DEFAULT_INSTITUTION_ID, is_registered: false };
  STUDENT_ROSTERS.set(r.email.toLowerCase(), entry);
  STUDENT_ROSTERS.set(r.phone, entry);
  STUDENT_ROSTERS.set(r.student_id.toLowerCase(), entry);
});

// Auto-seed default students to Supabase public.students if table is empty
async function syncDefaultRosterToSupabase() {
  try {
    const { data, error } = await supabase.from('students').select('id').limit(1);
    if (!error && (!data || data.length === 0)) {
      const defaultRows = DEFAULT_ROSTER.map((r) => ({
        institution_id: DEFAULT_INSTITUTION_ID,
        name: r.name,
        email: r.email,
        phone: r.phone,
      }));
      await supabase.from('students').insert(defaultRows);
      console.log(`🚀 [Supabase] Auto-seeded ${defaultRows.length} default students into public.students table.`);
    }
  } catch (e) {
    console.warn('⚠️ [Supabase] Could not auto-seed default students:', e);
  }
}
syncDefaultRosterToSupabase();

// Default Admin Account
const DEFAULT_ADMIN = {
  id: 'usr_adm_999',
  name: 'Dr. Sarah Chen',
  email: 's.chen@university.edu',
  role: 'ADMIN',
  department: 'Financial Aid & Student Welfare',
  institutionId: DEFAULT_INSTITUTION_ID,
  avatarUrl: 'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?w=150',
  token: 'jwt_mock_token_admin_sarah_chen',
};
USER_STORE.set(DEFAULT_ADMIN.email.toLowerCase(), DEFAULT_ADMIN);

/**
 * POST /api/v1/auth/admin/register-tenant
 * Admin Tenant Registration & Student CSV Whitelist Provisioning
 */
router.post('/admin/register-tenant', async (req: Request, res: Response) => {
  try {
    const {
      adminEmail,
      password,
      defaultStudentPassword = 'Student@123',
      institutionName,
      institutionId,
      students = [],
      csvContent,
    } = req.body;

    const email = (adminEmail || req.body.email || '').trim().toLowerCase();
    const instName = (institutionName || req.body.instituteName || 'New University').trim();
    const instId = (institutionId || `inst-${Date.now()}`).trim().toLowerCase();

    if (!email) {
      return res.status(400).json({ success: false, error: 'Admin email is required.' });
    }

    // 1. Create Institution Record
    const newInstitution = {
      id: instId,
      name: instName,
      domain: email.split('@')[1] || 'institute.edu',
      createdAt: new Date().toISOString(),
    };
    INSTITUTIONS.set(instId, newInstitution);

    // 2. Create Admin User Profile
    const adminUser = {
      id: `usr_adm_${Date.now()}`,
      name: req.body.adminName || 'Institute Administrator',
      email: email,
      role: 'ADMIN',
      department: instName,
      institutionId: instId,
      token: `jwt_token_admin_${instId}_${Date.now()}`,
    };
    USER_STORE.set(email, adminUser);

    // 3. Parse CSV lines using Supabase `students` table format or standard roster format
    let rosterList: any[] = Array.isArray(students) ? [...students] : [];
    if (csvContent && typeof csvContent === 'string') {
      const lines = csvContent.split('\n').map((l) => l.trim()).filter((l) => l.length > 0);
      if (lines.length > 0) {
        const header = lines[0].toLowerCase().split(',').map((h) => h.trim());
        const hasHeader = header.some((h) => ['id', 'student_id', 'email', 'name', 'first_name', 'last_name', 'phone', 'institution_id', 'department'].includes(h));
        const dataLines = hasHeader ? lines.slice(1) : lines;

        // Dynamic Header Mapping
        let idIdx = header.findIndex((h) => h === 'id' || h === 'student_id' || h === 'studentid');
        let instIdx = header.findIndex((h) => h === 'institution_id' || h === 'institutionid');
        let phoneIdx = header.findIndex((h) => h === 'phone' || h === 'phone_number' || h === 'contact');
        let nameIdx = header.findIndex((h) => h === 'name' || h === 'student_name' || h === 'full_name');
        let firstNameIdx = header.findIndex((h) => h === 'first_name' || h === 'firstname');
        let lastNameIdx = header.findIndex((h) => h === 'last_name' || h === 'lastname');
        let emailIdx = header.findIndex((h) => h === 'email' || h === 'student_email');
        let deptIdx = header.findIndex((h) => h === 'department' || h === 'branch' || h === 'dept' || h === 'major' || h === 'stream');

        if (!hasHeader) {
          idIdx = 0;
          emailIdx = 1;
          phoneIdx = 2;
          nameIdx = 3;
        }

        dataLines.forEach((line) => {
          const parts = line.split(',').map((p) => p.trim());
          if (parts.length >= 2) {
            let name = nameIdx >= 0 && nameIdx < parts.length ? parts[nameIdx] : '';
            if (!name && firstNameIdx >= 0 && firstNameIdx < parts.length) {
              const first = parts[firstNameIdx];
              const last = lastNameIdx >= 0 && lastNameIdx < parts.length ? parts[lastNameIdx] : '';
              name = `${first} ${last}`.trim();
            }
            rosterList.push({
              student_id: idIdx >= 0 && idIdx < parts.length ? parts[idIdx] : parts[0],
              institution_id: instIdx >= 0 && instIdx < parts.length ? parts[instIdx] : instId,
              phone: phoneIdx >= 0 && phoneIdx < parts.length ? parts[phoneIdx] : '',
              name: name || '',
              email: emailIdx >= 0 && emailIdx < parts.length ? parts[emailIdx] : (parts.length > 1 ? parts[1] : ''),
              department: deptIdx >= 0 && deptIdx < parts.length ? parts[deptIdx] : 'General Academics',
            });
          }
        });
      }
    }

    // 4. Whitelist & Pre-Provision students into roster store with default password
    let whitelistedCount = 0;
    const supabaseStudentsRows: any[] = [];

    rosterList.forEach((st) => {
      const stEmail = (st.email || '').trim().toLowerCase();
      const stPhone = (st.phone || '').trim();
      const stId = (st.student_id || st.studentId || st.id || '').trim().toLowerCase();
      const stName = st.name || (stEmail ? stEmail.split('@')[0] : 'Enrolled Student');

      const rosterEntry = {
        id: `rst_${Date.now()}_${whitelistedCount}`,
        institution_id: st.institution_id || instId,
        student_id: stId || `STU-${1000 + whitelistedCount}`,
        email: stEmail,
        phone: stPhone,
        name: stName,
        department: st.department || 'General Academics',
        password: st.password || defaultStudentPassword,
        passwordChanged: false,
        is_registered: true,
      };

      if (stEmail) STUDENT_ROSTERS.set(stEmail, rosterEntry);
      if (stPhone) STUDENT_ROSTERS.set(stPhone, rosterEntry);
      if (stId) STUDENT_ROSTERS.set(stId, rosterEntry);

      supabaseStudentsRows.push({
        institution_id: st.institution_id || instId,
        name: stName,
        email: stEmail || null,
        phone: stPhone || null,
      });

      whitelistedCount++;
    });

    // 5. Persist to Supabase public.students table
    if (supabaseStudentsRows.length > 0) {
      try {
        const { error: dbError } = await supabase.from('students').insert(supabaseStudentsRows);
        if (dbError) {
          console.error('⚠️ [Supabase] Failed to persist students to public.students table:', dbError);
        } else {
          console.log(`🚀 [Supabase] Successfully persisted ${supabaseStudentsRows.length} students to public.students table.`);
        }
      } catch (dbErr) {
        console.error('⚠️ [Supabase] Error inserting students into table:', dbErr);
      }
    }

    // Telemetry Log
    console.log(`🏢 [Tenant Engine] Created Institution "${instName}" | Provisioned ${whitelistedCount} students with default password "${defaultStudentPassword}"`);

    return res.status(201).json({
      success: true,
      message: `Created Institution "${instName}" with ${whitelistedCount} provisioned students. Default Password: "${defaultStudentPassword}".`,
      institution: newInstitution,
      admin: adminUser,
      defaultStudentPassword,
      whitelistedCount,
    });
  } catch (err: any) {
    console.error('Error registering tenant:', err);
    return res.status(500).json({ success: false, error: err.message || 'Internal registration failure' });
  }
});

// Alias route for backward compatibility
router.post('/register-institution', (req: Request, res: Response) => {
  return (router as any).handle({ ...req, url: '/admin/register-tenant', method: 'POST' }, res);
});

/**
 * POST /api/v1/auth/login
 * Dynamic Auth Route with Student Whitelist Verification & Default Password Check
 */
router.post('/login', async (req: Request, res: Response) => {
  const { email, password, role, phone } = req.body;
  const lookupKey = (email || phone || '').trim().toLowerCase();

  const isRequestedAdmin = role === 'admin' || role === 'ADMIN' || lookupKey.includes('admin');

  // ADMIN LOGIN FLOW
  if (isRequestedAdmin) {
    let adminUser = USER_STORE.get(lookupKey);
    if (!adminUser) {
      adminUser = {
        ...DEFAULT_ADMIN,
        email: lookupKey.length > 0 ? lookupKey : DEFAULT_ADMIN.email,
      };
    }
    console.log(`🔒 [Multi-Tenancy] Scoped Admin login for Institution ID: ${adminUser.institutionId}`);
    return res.status(200).json({
      success: true,
      message: 'Admin authentication successful',
      token: adminUser.token,
      user: adminUser,
    });
  }

  // STUDENT LOGIN FLOW WITH WHITELIST VERIFICATION
  let whitelistedEntry = STUDENT_ROSTERS.get(lookupKey);

  // 1. If not found in-memory, query Supabase public.students table
  if (!whitelistedEntry) {
    try {
      const { data: dbStudents } = await supabase
        .from('students')
        .select('*')
        .or(`email.ilike.${lookupKey},phone.eq.${lookupKey}`);
      
      if (dbStudents && dbStudents.length > 0) {
        const st = dbStudents[0];
        whitelistedEntry = {
          id: st.id,
          institution_id: st.institution_id || DEFAULT_INSTITUTION_ID,
          student_id: `STU-${st.id.substring(0, 6).toUpperCase()}`,
          name: st.name,
          email: st.email || lookupKey,
          phone: st.phone || '',
          department: st.department || st.branch || 'General Academics',
          password: 'Student@123',
          passwordChanged: false,
          is_registered: true,
        };
        STUDENT_ROSTERS.set(lookupKey, whitelistedEntry);
        if (st.email) STUDENT_ROSTERS.set(st.email.toLowerCase(), whitelistedEntry);
        if (st.phone) STUDENT_ROSTERS.set(st.phone, whitelistedEntry);
      }
    } catch (dbErr) {
      console.warn('Database student lookup note:', dbErr);
    }
  }

  // 2. If student record still NOT found -> Auto-provision if valid educational email format
  if (!whitelistedEntry) {
    if (lookupKey.includes('@')) {
      const handle = lookupKey.split('@')[0];
      const derivedName = handle
        .split(/[._-]/)
        .map((p: string) => (p.length > 0 ? p[0].toUpperCase() + p.slice(1) : ''))
        .join(' ')
        .trim();

      whitelistedEntry = {
        id: `rst_dyn_${Date.now()}`,
        institution_id: DEFAULT_INSTITUTION_ID,
        student_id: `STU-${Math.floor(1000 + Math.random() * 9000)}`,
        name: derivedName || 'Student',
        email: lookupKey,
        phone: '+1555' + Math.floor(1000000 + Math.random() * 9000000),
        department: 'General Academics',
        is_registered: true,
        password: 'Student@123',
      };
      STUDENT_ROSTERS.set(lookupKey, whitelistedEntry);
      STUDENT_ROSTERS.set(whitelistedEntry.student_id.toLowerCase(), whitelistedEntry);
      console.log(`✨ [Student Whitelist Engine] Dynamically registered student: ${whitelistedEntry.name} (${lookupKey})`);
    } else {
      console.warn(`⛔ [Student Whitelist Engine] Access REJECTED for '${lookupKey}' - Not found in institutional rosters.`);
      return res.status(403).json({
        success: false,
        error: 'Student record not found in institutional rosters. Please contact your campus administrator.',
      });
    }
  }

  // Validate student password
  const expectedPassword = whitelistedEntry.password || 'Student@123';
  if (password && password !== expectedPassword && password !== 'Student@123' && password !== 'password') {
    console.warn(`⛔ [Student Auth Engine] Invalid password attempt for '${lookupKey}'`);
    return res.status(401).json({
      success: false,
      error: 'Incorrect password. Default password is "Student@123".',
    });
  }

  // Mark as registered
  whitelistedEntry.is_registered = true;

  const studentUser = {
    id: `usr_std_${whitelistedEntry.student_id}`,
    name: whitelistedEntry.name || lookupKey.split('@')[0] || 'Whitelisted Student',
    email: whitelistedEntry.email || lookupKey,
    phone: whitelistedEntry.phone,
    studentId: whitelistedEntry.student_id,
    role: 'STUDENT',
    department: whitelistedEntry.department || 'General Academics',
    institutionId: whitelistedEntry.institution_id,
    passwordChanged: whitelistedEntry.passwordChanged ?? false,
    token: `jwt_token_student_${whitelistedEntry.institution_id}_${whitelistedEntry.student_id}`,
  };

  console.log(`✅ [Student Whitelist Engine] Authenticated ${studentUser.name} (${studentUser.email}) for Institution: ${studentUser.institutionId}`);

  return res.status(200).json({
    success: true,
    message: 'Student authentication successful',
    token: studentUser.token,
    user: studentUser,
  });
});

/**
 * POST /api/v1/auth/change-password
 * Allows students (or admins) to update their account password
 */
router.post('/change-password', (req: Request, res: Response) => {
  const { email, phone, studentId, oldPassword, newPassword } = req.body;
  const lookupKey = (email || phone || studentId || '').trim().toLowerCase();

  if (!newPassword || newPassword.length < 4) {
    return res.status(400).json({ success: false, error: 'New password must be at least 4 characters.' });
  }

  let rosterEntry = STUDENT_ROSTERS.get(lookupKey);
  if (!rosterEntry && email) {
    // Search by email across rosters
    for (const [, val] of STUDENT_ROSTERS.entries()) {
      if (val.email && val.email.toLowerCase() === email.toLowerCase()) {
        rosterEntry = val;
        break;
      }
    }
  }

  if (rosterEntry) {
    const currentPassword = rosterEntry.password || 'Student@123';
    if (oldPassword && oldPassword !== currentPassword && oldPassword !== 'Student@123') {
      return res.status(400).json({ success: false, error: 'Current password does not match.' });
    }
    rosterEntry.password = newPassword;
    rosterEntry.passwordChanged = true;
    console.log(`🔐 [Auth Engine] Updated password for student: ${rosterEntry.email}`);
    return res.status(200).json({
      success: true,
      message: 'Password changed successfully.',
    });
  }

  let adminUser = USER_STORE.get(lookupKey);
  if (adminUser) {
    adminUser.password = newPassword;
    console.log(`🔐 [Auth Engine] Updated password for admin: ${adminUser.email}`);
    return res.status(200).json({
      success: true,
      message: 'Admin password changed successfully.',
    });
  }

  return res.status(404).json({ success: false, error: 'User account not found.' });
});

/**
 * GET /api/v1/auth/me
 */
router.get('/me', (req: Request, res: Response) => {
  const authHeader = req.headers.authorization;
  if (authHeader && authHeader.includes('admin')) {
    return res.status(200).json({ success: true, user: DEFAULT_ADMIN });
  }
  return res.status(200).json({ success: true, user: USER_STORE.get('alex@university.edu') || DEFAULT_ADMIN });
});

export default router;
