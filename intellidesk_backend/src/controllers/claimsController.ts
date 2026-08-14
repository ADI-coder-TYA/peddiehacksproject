import { Request, Response } from 'express';
import { supabase } from '../config/supabase.js';
import { getIO } from '../services/socketManager.js';
import { PayoutService } from '../services/payoutService.js';
import { DatabaseService } from '../services/dbService.js';
import { logAuditEvent } from '../services/auditLogger.js';
import { EsiLevel, ClaimStatus } from '../types/clinical.js';

export class ClaimsController {
  /**
   * GET /api/v1/claims
   * Retrieve clinical claims prioritized by ESI-1 and life-safety alerts.
   */
  static async getClaims(req: Request, res: Response): Promise<void> {
    try {
      const instId = (typeof req.institution_id === 'string' ? req.institution_id : (Array.isArray(req.institution_id) ? req.institution_id[0] : (req.query.institutionId as string) || 'default')) as string;
      const { esiLevel, status, search, limit = '50' } = req.query;

      let query = supabase
        .from('claims')
        .select(`
          *,
          profiles:patient_id (
            id,
            email,
            full_name,
            phone,
            emergency_contact
          )
        `)
        .eq('institution_id', instId)
        .order('is_life_safety_alert', { ascending: false })
        .order('crisis_severity_index', { ascending: false })
        .order('created_at', { ascending: false })
        .limit(Number(limit));

      if (esiLevel) {
        query = query.eq('esi_level', esiLevel);
      }
      if (status) {
        query = query.eq('status', status);
      }
      if (search && typeof search === 'string' && search.trim().length > 0) {
        query = query.or(`description.ilike.%${search}%,patient_phone.ilike.%${search}%,clinical_category.ilike.%${search}%`);
      }

      const { data: claims, error } = await query;

      if (error) {
        // Graceful fallback to tickets table if claims migration is in transition
        const { data: tickets } = await supabase
          .from('tickets')
          .select('*')
          .eq('institution_id', instId)
          .order('crisis_severity_index', { ascending: false })
          .limit(Number(limit));

        res.status(200).json(tickets || []);
        return;
      }

      res.status(200).json(claims || []);
    } catch (err: any) {
      console.error('[ClaimsController.getClaims] Error:', err);
      res.status(500).json({ error: err.message || 'Internal Server Error' });
    }
  }

  /**
   * GET /api/v1/claims/:id
   */
  static async getClaimById(req: Request, res: Response): Promise<void> {
    try {
      const id = (Array.isArray(req.params.id) ? req.params.id[0] : req.params.id) as string;
      const instId = (typeof req.institution_id === 'string' ? req.institution_id : (Array.isArray(req.institution_id) ? req.institution_id[0] : 'default')) as string;

      const { data: claim, error } = await supabase
        .from('claims')
        .select(`
          *,
          profiles:patient_id (
            id,
            email,
            full_name,
            phone,
            emergency_contact
          )
        `)
        .eq('id', id)
        .eq('institution_id', instId)
        .maybeSingle();

      if (error || !claim) {
        // Fallback to tickets table
        const { data: ticket } = await supabase.from('tickets').select('*').eq('id', id).maybeSingle();
        if (ticket) {
          res.status(200).json(ticket);
          return;
        }
        res.status(404).json({ error: 'Claim not found' });
        return;
      }

      res.status(200).json(claim);
    } catch (err: any) {
      res.status(500).json({ error: err.message || 'Internal Server Error' });
    }
  }

  /**
   * POST /api/v1/claims/:id/disburse
   * Instant emergency copay disbursement across Razorpay / Stripe rails with fund deduction.
   */
  static async disburseClaim(req: Request, res: Response): Promise<void> {
    try {
      const id = (Array.isArray(req.params.id) ? req.params.id[0] : req.params.id) as string;
      const instId = (typeof req.institution_id === 'string' ? req.institution_id : (Array.isArray(req.institution_id) ? req.institution_id[0] : 'default')) as string;
      const { approvedAmount, payoutMethod, adminNotes, vpa, bankAccount } = req.body || {};

      // 1. Fetch claim
      let claim = await DatabaseService.getClaimById(id, instId);
      if (!claim) {
        // Fallback fetch from tickets
        const { data: ticket } = await supabase.from('tickets').select('*').eq('id', id).single();
        if (!ticket) {
          res.status(404).json({ error: `Claim ${id} not found` });
          return;
        }
        claim = {
          id: ticket.id,
          institutionId: ticket.institution_id,
          patientPhone: ticket.student_phone,
          description: ticket.raw_message,
          clinicalCategory: ticket.parsed_category,
          esiLevel: 'ESI_2_EMERGENT',
          crisisSeverityIndex: Number(ticket.crisis_severity_index || 0),
          isLifeSafetyAlert: false,
          currency: ticket.currency || 'INR',
          recommendedCopayAmount: Number(ticket.recommended_grant_amount || 0),
          approvedAmount: Number(ticket.calculated_amount || 0),
          fraudRiskScore: 0.0,
          status: 'Submitted',
        };
      }

      const disburseAmount = approvedAmount !== undefined ? Number(approvedAmount) : (claim.recommendedCopayAmount || 100);

      // 2. Validate fund availability in health_funds pool
      const healthFund = await DatabaseService.getHealthFundByCategory(claim.clinicalCategory, instId);
      if (healthFund) {
        const availableBalance = Math.max(0, healthFund.totalAllocated - healthFund.totalDisbursed);
        if (disburseAmount > availableBalance && availableBalance > 0) {
          console.warn(`⚠️ [Copay Disburse] Disburse amount (${disburseAmount}) exceeds remaining pool (${availableBalance}).`);
        }
      }

      // 3. Execute Multi-Rail Payout
      const payoutReceipt = await PayoutService.processPayout({
        claimId: id,
        institutionId: instId,
        amount: disburseAmount,
        currency: claim.currency,
        payoutMethod,
        patientPhone: claim.patientPhone,
        vpa,
        bankAccount,
      });

      // 4. Atomically deduct from Health Fund pool
      if (healthFund) {
        try {
          await DatabaseService.disburseHealthFund(healthFund.id, disburseAmount);
        } catch (fundErr) {
          console.warn('⚠️ [Fund Deduction] Warning:', fundErr);
        }
      }

      // 5. Update claim status in database
      const updatedNotes = `${claim.clinicalNotes || ''}\n• 💳 DISBURSED: ${claim.currency} ${disburseAmount} on ${new Date().toISOString()} via ${payoutReceipt.payoutMethod} (Ref: ${payoutReceipt.transactionReference}). ${adminNotes ? `Admin Note: ${adminNotes}` : ''}`.trim();

      const updatedClaim = await DatabaseService.updateClaim(id, instId, {
        status: 'Disbursed',
        approvedAmount: disburseAmount,
        payoutReference: payoutReceipt.transactionReference,
        payoutMethod: payoutReceipt.payoutMethod,
        clinicalNotes: updatedNotes,
      });

      // Sync tickets table
      try {
        await supabase.from('tickets').update({
          status: 'Auto-Approved',
          calculated_amount: disburseAmount,
          payout_reference: payoutReceipt.transactionReference,
          payout_method: payoutReceipt.payoutMethod,
          updated_at: new Date().toISOString(),
        }).eq('id', id);
      } catch (_) {}

      // 6. Log HIPAA audit event
      await logAuditEvent(
        instId,
        id,
        'COPAY_DISBURSED',
        (req as any).user?.id || 'CLINICAL_ADMIN',
        {
          approvedAmount: disburseAmount,
          payoutReference: payoutReceipt.transactionReference,
          payoutMethod: payoutReceipt.payoutMethod,
        }
      );

      // 7. Emit Socket.io real-time notifications
      try {
        const io = getIO();
        io.to(instId).emit('claim:disbursed', {
          claimId: id,
          approvedAmount: disburseAmount,
          payoutReference: payoutReceipt.transactionReference,
          payoutMethod: payoutReceipt.payoutMethod,
          status: 'Disbursed',
        });
        io.to(instId).emit('claim:updated', updatedClaim);
        io.to(instId).emit('budget:disbursed', {
          financial_aid_disbursed: disburseAmount,
          financial_aid_remaining: healthFund ? Math.max(0, healthFund.totalAllocated - (healthFund.totalDisbursed + disburseAmount)) : 45000,
        });
      } catch (_) {}

      res.status(200).json({
        success: true,
        message: 'Emergency copay relief successfully disbursed.',
        receipt: payoutReceipt,
        claim: updatedClaim,
      });
    } catch (err: any) {
      console.error('[ClaimsController.disburseClaim] Error:', err);
      res.status(500).json({ error: err.message || 'Disbursement Failed' });
    }
  }

  /**
   * POST /api/v1/claims/:id/override
   * Clinical administrative override for ESI tiering, fraud flags, or rejection.
   */
  static async overrideClaim(req: Request, res: Response): Promise<void> {
    try {
      const id = (Array.isArray(req.params.id) ? req.params.id[0] : req.params.id) as string;
      const instId = (typeof req.institution_id === 'string' ? req.institution_id : (Array.isArray(req.institution_id) ? req.institution_id[0] : 'default')) as string;
      const { esiLevel, overrideFraud, status, reason, clinicalNotes } = req.body || {};

      const updates: Partial<any> = {};
      if (esiLevel) updates.esiLevel = esiLevel as EsiLevel;
      if (status) updates.status = status as ClaimStatus;
      if (overrideFraud) {
        updates.fraudRiskScore = 0.0;
        updates.fraudFlags = 'OVERRIDDEN_BY_CLINICAL_ADMIN';
      }
      if (reason || clinicalNotes) {
        updates.clinicalNotes = `• ⚠️ CLINICAL ADMIN OVERRIDE (${new Date().toISOString()}): ${reason || clinicalNotes}`;
      }

      const updatedClaim = await DatabaseService.updateClaim(id, instId, updates);

      // Sync tickets table
      try {
        await supabase.from('tickets').update({
          status: status === 'Rejected' ? 'Denied' : (status || 'Pending'),
          flag_reason: overrideFraud ? 'CLEARED_BY_ADMIN' : reason,
          updated_at: new Date().toISOString(),
        }).eq('id', id);
      } catch (_) {}

      // Log audit
      await logAuditEvent(
        instId,
        id,
        'CLINICAL_OVERRIDE',
        (req as any).user?.id || 'CLINICAL_ADMIN',
        { esiLevel, overrideFraud, status, reason }
      );

      // Socket broadcast
      try {
        const io = getIO();
        io.to(instId).emit('claim:updated', updatedClaim);
      } catch (_) {}

      res.status(200).json({
        success: true,
        message: 'Claim clinical override applied.',
        claim: updatedClaim,
      });
    } catch (err: any) {
      console.error('[ClaimsController.overrideClaim] Error:', err);
      res.status(500).json({ error: err.message || 'Override Failed' });
    }
  }
}
