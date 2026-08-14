import { Router, Request, Response } from 'express';
import { supabase } from '../config/supabase.js';

const router = Router();

/**
 * GET /api/v1/patients/profile
 * Retrieves patient profile by phone, email, or user id
 */
router.get('/profile', async (req: Request, res: Response) => {
  const patientPhone = (req.query.phone || req.query.patientPhone || req.headers['x-patient-phone']) as string;
  const patientEmail = (req.query.email || req.query.patientEmail || req.headers['x-patient-email']) as string;
  const patientId = (req.query.id || req.query.patientId || req.headers['x-patient-id']) as string;

  try {
    let query = supabase.from('profiles').select('*');
    if (patientId) {
      query = query.eq('id', patientId);
    } else if (patientEmail) {
      query = query.eq('email', patientEmail);
    } else if (patientPhone) {
      query = query.eq('phone', patientPhone);
    } else {
      // Return demo patient profile
      return res.json({
        id: 'usr_pat_001',
        full_name: 'Alex Rivera',
        email: 'alex.rivera@campushealth.edu',
        phone: '+91 98765 43210',
        role: 'PATIENT',
        emergency_contact: '+91 98765 43211',
        preferred_channel: 'SMS',
        institution_id: 'hosp-stanford-01',
      });
    }

    const { data: profile, error } = await query.maybeSingle();

    if (profile && !error) {
      return res.json(profile);
    }

    // Fallback: check students table for backward compatibility
    let studentQuery = supabase.from('students').select('*');
    if (patientEmail) studentQuery = studentQuery.eq('email', patientEmail);
    else if (patientPhone) studentQuery = studentQuery.eq('phone', patientPhone);

    const { data: student } = await studentQuery.maybeSingle();
    if (student) {
      return res.json({
        id: student.id,
        full_name: student.name || 'Alex Rivera',
        email: student.email,
        phone: student.phone,
        role: 'PATIENT',
        institution_id: student.institution_id || 'hosp-stanford-01',
      });
    }

    return res.json({
      id: patientId || 'usr_pat_001',
      full_name: 'Alex Rivera',
      email: patientEmail || 'alex.rivera@campushealth.edu',
      phone: patientPhone || '+91 98765 43210',
      role: 'PATIENT',
      emergency_contact: '+91 98765 43211',
      preferred_channel: 'SMS',
      institution_id: 'hosp-stanford-01',
    });
  } catch (error: any) {
    return res.status(500).json({ error: error.message });
  }
});

/**
 * POST /api/v1/patients/register
 * Registers or updates a patient profile
 */
router.post('/register', async (req: Request, res: Response) => {
  const { full_name, name, email, phone, emergency_contact, institution_id } = req.body;

  try {
    const patientName = full_name || name || 'Patient Member';
    const patientEmail = email || `${phone || Date.now()}@campushealth.edu`;

    const { data, error } = await supabase
      .from('profiles')
      .upsert({
        full_name: patientName,
        email: patientEmail,
        phone,
        role: 'PATIENT',
        emergency_contact,
        institution_id: institution_id || 'hosp-stanford-01',
      })
      .select()
      .maybeSingle();

    if (error) {
      return res.status(400).json({ error: error.message });
    }

    return res.status(201).json({
      success: true,
      patient: data,
    });
  } catch (error: any) {
    return res.status(500).json({ error: error.message });
  }
});

/**
 * GET /api/v1/patients/:id/claims
 * Lists all claims for a given patient
 */
router.get('/:id/claims', async (req: Request, res: Response) => {
  const { id } = req.params;
  try {
    const { data: claims, error } = await supabase
      .from('claims')
      .select('*')
      .or(`patient_id.eq.${id},patient_phone.eq.${id}`)
      .order('created_at', { ascending: false });

    if (error) {
      return res.status(400).json({ error: error.message });
    }

    return res.json(claims || []);
  } catch (error: any) {
    return res.status(500).json({ error: error.message });
  }
});

export default router;
