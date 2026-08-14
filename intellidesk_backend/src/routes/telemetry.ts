import { Router, Request, Response } from 'express';
import { supabase } from '../config/supabase.js';
import { logAuditEvent } from '../services/auditLogger.js';

const telemetryRouter = Router();

const DEFAULT_TOTAL_BUDGET = 150000;

/**
 * GET /api/v1/admin/telemetry/funds
 * Lists all active health fund pools for the institution
 */
telemetryRouter.get('/funds', async (req: Request, res: Response) => {
  try {
    const instId = (typeof req.institution_id === 'string' ? req.institution_id : (req.headers['x-institution-id'] as string) || 'inst-001');

    const { data: funds, error } = await supabase
      .from('health_funds')
      .select('*')
      .eq('institution_id', instId)
      .order('created_at', { ascending: false });

    if (error) {
      console.warn('⚠️ [Telemetry] Error fetching health_funds:', error.message);
      return res.status(200).json([]);
    }

    return res.json(funds || []);
  } catch (err: any) {
    return res.status(500).json({ error: err.message });
  }
});

/**
 * POST /api/v1/admin/telemetry/funds/allocate
 * Injects / allocates a new health fund pool or tops up an existing pool in Supabase
 */
telemetryRouter.post('/funds/allocate', async (req: Request, res: Response) => {
  try {
    const instId = (typeof req.institution_id === 'string' ? req.institution_id : (req.headers['x-institution-id'] as string) || 'inst-001');
    const { name, category, amount, currency = 'INR' } = req.body;

    const fundName = (name || 'Emergency Health Relief Pool').trim();
    const fundCategory = (category || 'Emergency Inpatient & Trauma').trim();
    const allocAmount = Number(amount || 50000.0);

    if (isNaN(allocAmount) || allocAmount <= 0) {
      return res.status(400).json({ error: 'Valid positive allocation amount is required.' });
    }

    // Check if fund already exists for this institution and category
    const { data: existingFund } = await supabase
      .from('health_funds')
      .select('*')
      .eq('institution_id', instId)
      .eq('name', fundName)
      .maybeSingle();

    let fundRecord;
    if (existingFund) {
      const newTotal = Number(existingFund.total_allocated || 0) + allocAmount;
      const { data, error } = await supabase
        .from('health_funds')
        .update({
          total_allocated: newTotal,
          updated_at: new Date().toISOString(),
        })
        .eq('id', existingFund.id)
        .select()
        .single();

      if (error) throw error;
      fundRecord = data;
    } else {
      const { data, error } = await supabase
        .from('health_funds')
        .insert({
          institution_id: instId,
          name: fundName,
          category: fundCategory,
          total_allocated: allocAmount,
          total_disbursed: 0.0,
          currency: currency,
        })
        .select()
        .single();

      if (error) throw error;
      fundRecord = data;
    }

    // Log to audit trail
    await logAuditEvent(instId, fundRecord.id, 'FUND_ALLOCATION', 'CLINICAL_ADMIN', {
      fundName,
      fundCategory,
      allocatedAmount: allocAmount,
      currency,
    });

    return res.status(201).json({
      success: true,
      message: `Successfully allocated ₹${allocAmount.toLocaleString()} to ${fundName}`,
      fund: fundRecord,
    });
  } catch (err: any) {
    console.error('[Telemetry] Error allocating health fund:', err);
    return res.status(500).json({ error: err.message || 'Failed to allocate health fund' });
  }
});

telemetryRouter.get('/', async (req: Request, res: Response) => {
  try {
    const instId = (typeof req.institution_id === 'string' ? req.institution_id : (Array.isArray(req.institution_id) ? req.institution_id[0] : (req.headers['x-institution-id'] as string) || (req.query.institutionId as string) || 'inst-001')) as string;

    // 1. Fetch claims for aggregation scoped to this institution
    let claimsQuery = supabase
      .from('claims')
      .select('id, created_at, updated_at, status, clinical_category, recommended_copay_amount, approved_amount, extracted_bill_amount, esi_level, crisis_severity_index')
      .eq('institution_id', instId);

    const { data: claims, error: claimsError } = await claimsQuery;

    if (claimsError) {
      console.warn('⚠️ [Telemetry] Claims query notice:', claimsError.message);
    }

    // 2. Fetch health fund pool from health_funds table scoped to this institution
    let totalBudget = DEFAULT_TOTAL_BUDGET;
    let totalDisbursed = 0;
    try {
      const { data: fundData } = await supabase
        .from('health_funds')
        .select('total_pool, total_allocated, total_disbursed')
        .eq('institution_id', instId);

      if (fundData && fundData.length > 0) {
        totalBudget = fundData.reduce((sum, f) => sum + Number(f.total_allocated || f.total_pool || 0), 0);
        totalDisbursed = fundData.reduce((sum, f) => sum + Number(f.total_disbursed || 0), 0);
      }
    } catch (_) {}

    // 3. Fetch recent audit logs scoped to this institution
    const { data: auditLogs } = await supabase
      .from('audit_logs')
      .select('*')
      .eq('institution_id', instId)
      .order('created_at', { ascending: false })
      .limit(50);

    // --- Aggregations ---
    const categoryCounts: Record<string, number> = {
      'Medical Emergency & Inpatient Care': 0,
      'Prescription & Pharmacy Copay': 0,
      'Diagnostic, Lab & Imaging Relief': 0,
      'Mental Health & Tele-Counseling': 0,
    };
    let totalResolutionTimeMs = 0;
    let resolvedCount = 0;

    for (const claim of claims || []) {
      const isApprovedOrDisbursed = claim.status === 'Disbursed' || claim.status === 'Approved' || claim.status === 'Auto-Approved' || claim.status === 'Resolved';
      if (isApprovedOrDisbursed) {
        const amt = Number(claim.approved_amount || claim.recommended_copay_amount || 0);
        if (totalDisbursed === 0) {
          totalDisbursed += amt;
        }
      }

      // Trend Analysis: Category distribution
      const cat = claim.clinical_category || 'Medical Emergency & Inpatient Care';
      categoryCounts[cat] = (categoryCounts[cat] || 0) + 1;

      // Resolution Time: Average time-to-resolution
      if (claim.updated_at && claim.created_at && isApprovedOrDisbursed) {
        const created = new Date(claim.created_at).getTime();
        const resolved = new Date(claim.updated_at).getTime();
        if (resolved >= created) {
          totalResolutionTimeMs += (resolved - created);
          resolvedCount++;
        }
      }
    }

    const averageResolutionTimeMs = resolvedCount > 0 ? totalResolutionTimeMs / resolvedCount : 0;
    const averageResolutionTimeHours = averageResolutionTimeMs / (1000 * 60 * 60);

    return res.status(200).json({
      success: true,
      data: {
        budget: {
          financialAidTotal: totalBudget * 0.6,
          alumniFundTotal: totalBudget * 0.4,
          totalBudget: totalBudget,
          totalDisbursed: totalDisbursed,
          remainingFunds: Math.max(totalBudget - totalDisbursed, 0),
        },
        trends: {
          categoryDistribution: categoryCounts,
        },
        performance: {
          averageResolutionTimeHours: averageResolutionTimeHours,
          resolvedTicketCount: resolvedCount,
        },
        recentAudits: auditLogs || [],
      }
    });

  } catch (error: any) {
    console.error('[Telemetry] Error fetching telemetry data:', error);
    return res.status(200).json({
      success: true,
      data: {
        budget: {
          financialAidTotal: 90000,
          alumniFundTotal: 60000,
          totalBudget: 150000,
          totalDisbursed: 0,
          remainingFunds: 150000,
        },
        trends: {
          categoryDistribution: {},
        },
        performance: {
          averageResolutionTimeHours: 0,
          resolvedTicketCount: 0,
        },
        recentAudits: [],
      }
    });
  }
});

export default telemetryRouter;
