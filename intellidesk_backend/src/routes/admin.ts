import { Router, Request, Response } from 'express';
import { supabase } from '../config/supabase.js';
import { getIO } from '../services/socketManager.js';
import { logAuditEvent } from '../services/auditLogger.js';
import twilio from 'twilio';
import { v4 as uuidv4 } from 'uuid';
import { rankPendingQueue, TicketBatch, fineTuneDeepRankModel } from '../services/deepRankModel.js';
import { fineTuneGrantOptimizerModel } from '../services/grantOptimizerModel.js';
import { approveTicketAndIssueVoucher } from '../services/voucherEngine.js';

const router = Router();
const twilioClient = twilio(process.env.TWILIO_ACCOUNT_SID!, process.env.TWILIO_AUTH_TOKEN!);

router.get('/tickets', async (req: Request, res: Response) => {
  try {
    const instId = (typeof req.institution_id === 'string' ? req.institution_id : (req.headers['x-institution-id'] as string) || 'inst-001');
    
    let query = supabase
      .from('claims')
      .select('*')
      .order('created_at', { ascending: false });

    if (instId && instId !== 'all' && instId !== 'default') {
      query = query.eq('institution_id', instId);
    }

    let { data: claims, error } = await query;

    // Fallback: If no claims found for specific instId, fetch all recent claims so admin board displays
    if ((!claims || claims.length === 0) && instId && instId !== 'all') {
      const { data: allClaims } = await supabase
        .from('claims')
        .select('*')
        .order('created_at', { ascending: false });
      if (allClaims && allClaims.length > 0) {
        claims = allClaims;
      }
    }

    if (error && (!claims || claims.length === 0)) {
      console.error('Error fetching claims in admin/tickets:', error);
      res.status(200).json({});
      return;
    }

    const grouped = (claims || []).reduce((acc: Record<string, any[]>, claim) => {
      const status = claim.status || 'Pending';
      if (!acc[status]) acc[status] = [];
      acc[status].push(claim);
      return acc;
    }, {});

    res.json(grouped);
  } catch (error) {
    console.error('Error in /tickets:', error);
    res.status(500).json({ error: 'Internal Server Error' });
  }
});

router.get('/roster', async (req: Request, res: Response) => {
  try {
    const instId = (typeof req.institution_id === 'string' ? req.institution_id : (req.headers['x-institution-id'] as string) || 'inst-001');

    const { data: roster, error } = await supabase
      .from('patient_rosters')
      .select('*')
      .eq('institution_id', instId)
      .order('created_at', { ascending: false });

    if (error) {
      console.warn('⚠️ [Admin Roster] Notice fetching patient_rosters:', error.message);
      return res.status(200).json([]);
    }

    return res.json(roster || []);
  } catch (err: any) {
    console.error('Error in admin /roster:', err);
    return res.status(500).json({ error: 'Internal Server Error' });
  }
});

router.get('/tickets/:id', async (req: Request, res: Response) => {
  try {
    const id = (Array.isArray(req.params.id) ? req.params.id[0] : req.params.id) as string;
    const instId = (typeof req.institution_id === 'string' ? req.institution_id : (req.headers['x-institution-id'] as string) || 'inst-001');

    let { data: claim, error } = await supabase
      .from('claims')
      .select('*')
      .eq('id', id)
      .maybeSingle();

    if (!claim) {
      // Fallback: check tickets table
      const { data: legacyTicket } = await supabase
        .from('tickets')
        .select('*')
        .eq('id', id)
        .maybeSingle();
      if (legacyTicket) {
        claim = legacyTicket;
      }
    }

    if (!claim) {
      res.status(404).json({ error: 'Claim not found' });
      return;
    }

    res.json(claim);
  } catch (error) {
    console.error('Error in /tickets/:id:', error);
    res.status(500).json({ error: 'Internal Server Error' });
  }
});

router.post('/tickets/:id/approve', async (req: Request, res: Response) => {
  try {
    const id = (Array.isArray(req.params.id) ? req.params.id[0] : req.params.id) as string;
    const { amount, payout_method, payoutMethod, student_name, student_vpa, account_number, ifsc_code } = req.body || {};
    const instId = (typeof req.institution_id === 'string' ? req.institution_id : (Array.isArray(req.institution_id) ? req.institution_id[0] : 'edu-admin-123')) as string;

    const chosenMethod = payout_method || payoutMethod || 'RAZORPAY_UPI';

    const approvalResult = await approveTicketAndIssueVoucher(
      id,
      instId,
      amount ? Number(amount) : undefined,
      chosenMethod,
      {
        studentName: student_name,
        studentVpa: student_vpa,
        accountNumber: account_number,
        ifscCode: ifsc_code
      }
    );

    await logAuditEvent(instId, id, 'MANUAL_APPROVAL', 'ADMIN_USER', {
      amount: approvalResult.grantAmount,
      payoutMethod: approvalResult.payoutMethod,
      transactionReference: approvalResult.transactionReference,
      voucherCode: approvalResult.voucherCode,
      fundName: approvalResult.fundName,
      note: 'Approved by admin UI'
    });

    if (process.env.TWILIO_PHONE_NUMBER && approvalResult.studentPhone) {
      try {
        await twilioClient.messages.create({
          body: `Your request has been approved! Payout Ref: ${approvalResult.transactionReference} (${approvalResult.payoutMethod}, $${approvalResult.grantAmount}).`,
          from: process.env.TWILIO_PHONE_NUMBER,
          to: approvalResult.studentPhone
        });
      } catch (smsError: any) {
        if (smsError?.code === 572002) {
          console.warn(`⚠️ [Twilio] Destination number "${approvalResult.studentPhone}" is not a verified recipient in Twilio Trial Console (Error 572002). SMS delivery skipped.`);
        } else {
          console.error('Error sending SMS via Twilio:', smsError?.message || smsError);
        }
      }
    }

    try {
      const io = getIO();
      io.emit('ticket:updated', { 
        id, 
        status: 'Approved', 
        payoutMethod: approvalResult.payoutMethod,
        payoutReference: approvalResult.transactionReference,
        voucherCode: approvalResult.voucherCode,
        recommendedGrantAmount: approvalResult.grantAmount 
      });
    } catch(e) {}

    res.json({ 
      success: true, 
      status: 'Approved',
      payoutMethod: approvalResult.payoutMethod,
      transactionReference: approvalResult.transactionReference,
      payoutReference: approvalResult.transactionReference,
      voucherCode: approvalResult.voucherCode,
      grantAmount: approvalResult.grantAmount,
      fundName: approvalResult.fundName
    });
  } catch (error: any) {
    console.error('Error in /tickets/:id/approve:', error);
    res.status(500).json({ error: error.message || 'Internal Server Error' });
  }
});

router.post('/tickets/:id/deny', async (req: Request, res: Response) => {
  try {
    const id = (Array.isArray(req.params.id) ? req.params.id[0] : req.params.id) as string;
    const instId = (typeof req.institution_id === 'string' ? req.institution_id : (Array.isArray(req.institution_id) ? req.institution_id[0] : 'inst-001')) as string;
    const { notes } = req.body;
    
    const { data: claim, error: fetchError } = await supabase
      .from('claims')
      .select('*')
      .eq('id', id)
      .maybeSingle();

    if (fetchError || !claim) {
      res.status(404).json({ error: 'Claim not found' });
      return;
    }

    const { error: updateError } = await supabase
      .from('claims')
      .update({ 
        status: 'Rejected',
        clinical_notes: notes ? `${claim.clinical_notes || ''}\n• Denied Reason: ${notes}` : claim.clinical_notes
      })
      .eq('id', id);

    if (updateError) {
      console.error('Error updating claim:', updateError);
      res.status(500).json({ error: 'Internal Server Error' });
      return;
    }

    await logAuditEvent(instId, claim.id, 'MANUAL_DENIAL', 'ADMIN_USER', {
      notes: notes
    });

    if (process.env.TWILIO_PHONE_NUMBER && claim.patient_phone) {
        try {
            await twilioClient.messages.create({
                body: `Your request has been reviewed but could not be approved at this time.`,
                from: process.env.TWILIO_PHONE_NUMBER,
                to: claim.patient_phone
            });
        } catch (smsError) {
            console.error('Error sending SMS:', smsError);
        }
    }

    try {
        const io = getIO();
        io.emit('ticket:updated', { id, status: 'Denied' });
    } catch(e) {}

    res.json({ success: true, status: 'Denied' });
  } catch (error) {
    console.error('Error in /tickets/:id/deny:', error);
    res.status(500).json({ error: 'Internal Server Error' });
  }
});

router.get('/audit-logs', async (req: Request, res: Response) => {
  try {
    const { action_type, start_date, end_date, limit = 50, offset = 0 } = req.query;

    const instId = (typeof req.institution_id === 'string' ? req.institution_id : (Array.isArray(req.institution_id) ? req.institution_id[0] : (req.headers['x-institution-id'] as string) || (req.query.institutionId as string) || 'inst-001')) as string;

    let query = supabase
      .from('audit_logs')
      .select('*')
      .order('created_at', { ascending: false });

    if (instId && instId !== 'default' && instId !== 'all') {
      if (instId === 'inst-001') {
        query = query.or('institution_id.eq.inst-001,institution_id.eq.nano123,institution_id.is.null');
      } else {
        query = query.eq('institution_id', instId);
      }
    }

    if (action_type) {
      query = query.eq('action_type', action_type as string);
    }
    if (start_date) {
      query = query.gte('created_at', start_date as string);
    }
    if (end_date) {
      query = query.lte('created_at', end_date as string);
    }

    const { data: logs, error } = await query
      .range(Number(offset), Number(offset) + Number(limit) - 1);

    if (error) {
      console.error('Error fetching audit logs:', error);
      res.status(500).json({ error: 'Internal Server Error' });
      return;
    }

    res.json(logs);
  } catch (error) {
    console.error('Error in /audit-logs:', error);
    res.status(500).json({ error: 'Internal Server Error' });
  }
});

router.post('/ml/retrain', async (req: Request, res: Response) => {
  try {
    const instId = typeof req.institution_id === 'string' ? req.institution_id : 'edu-admin-123';
    const { data: pastTickets, error } = await supabase
      .from('tickets')
      .select('*')
      .eq('institution_id', instId)
      .in('status', ['Resolved'])
      .order('created_at', { ascending: false })
      .limit(500);

    if (error) {
      console.error('Error fetching past tickets for ML retraining:', error);
      res.status(500).json({ error: 'Internal Server Error' });
      return;
    }

    if (!pastTickets || pastTickets.length === 0) {
      res.status(400).json({ error: 'Not enough training data available.' });
      return;
    }

    const grantLoss = await fineTuneGrantOptimizerModel(pastTickets);
    const deepRankLoss = await fineTuneDeepRankModel(pastTickets);

    res.json({
      success: true,
      metrics: {
        grantOptimizerLoss: grantLoss,
        deepRankLoss: deepRankLoss
      }
    });
  } catch (error) {
    console.error('Error in /ml/retrain:', error);
    res.status(500).json({ error: 'Internal Server Error' });
  }
});

export default router;
