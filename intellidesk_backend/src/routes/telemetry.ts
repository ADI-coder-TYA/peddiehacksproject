import { Router, Request, Response } from 'express';
import { supabase } from '../config/supabase.js';

const telemetryRouter = Router();

// Hardcoded budgets as per design constraints
const FINANCIAL_AID_BUDGET = 50000;
const ALUMNI_FUND_BUDGET = 25000;

telemetryRouter.get('/', async (req: Request, res: Response) => {
  try {
    // 1. Fetch all tickets for aggregation
    const { data: tickets, error: ticketsError } = await supabase
      .from('tickets')
      .select('id, created_at, resolved_at, status, parsed_category, calculated_amount')
      .eq('institution_id', req.institution_id);

    if (ticketsError) throw ticketsError;

    // 2. Fetch recent audit logs
    const { data: auditLogs, error: auditLogsError } = await supabase
      .from('audit_logs')
      .select('*')
      .eq('institution_id', req.institution_id)
      .order('created_at', { ascending: false })
      .limit(50);

    if (auditLogsError) throw auditLogsError;

    // --- Aggregations ---
    let totalDisbursed = 0;
    const categoryCounts: Record<string, number> = {
      Financial: 0,
      Academic: 0,
      Medical: 0,
      General: 0,
    };
    let totalResolutionTimeMs = 0;
    let resolvedCount = 0;

    for (const ticket of tickets || []) {
      // Budget Tracking (Only sum Financial tickets that are approved/resolved)
      if (
        (ticket.status === 'Auto-Approved' || ticket.status === 'Resolved') &&
        ticket.parsed_category === 'Financial'
      ) {
        totalDisbursed += ticket.calculated_amount || 0;
      }

      // Trend Analysis: Category distribution
      const cat = ticket.parsed_category || 'General';
      if (categoryCounts[cat] !== undefined) {
        categoryCounts[cat]++;
      } else {
        categoryCounts[cat] = 1;
      }

      // Resolution Time: Average time-to-resolution
      if (ticket.resolved_at && ticket.created_at) {
        const created = new Date(ticket.created_at).getTime();
        const resolved = new Date(ticket.resolved_at).getTime();
        totalResolutionTimeMs += (resolved - created);
        resolvedCount++;
      }
    }

    const averageResolutionTimeMs = resolvedCount > 0 ? totalResolutionTimeMs / resolvedCount : 0;
    
    // Convert ms to hours for easier reading, or keep as ms and let frontend decide.
    // We'll return hours.
    const averageResolutionTimeHours = averageResolutionTimeMs / (1000 * 60 * 60);

    res.status(200).json({
      success: true,
      data: {
        budget: {
          financialAidTotal: FINANCIAL_AID_BUDGET,
          alumniFundTotal: ALUMNI_FUND_BUDGET,
          totalBudget: FINANCIAL_AID_BUDGET + ALUMNI_FUND_BUDGET,
          totalDisbursed: totalDisbursed,
          remainingFunds: (FINANCIAL_AID_BUDGET + ALUMNI_FUND_BUDGET) - totalDisbursed,
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
    res.status(500).json({ error: error.message || 'Failed to fetch telemetry data.' });
  }
});

export default telemetryRouter;
