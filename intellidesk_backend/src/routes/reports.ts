import { Router, Request, Response } from 'express';
import { generateExecutiveReport } from '../services/pdfReportService.js';

const router = Router();

/**
 * GET /api/v1/reports/executive-pdf
 * GET /admin/reports/executive-pdf
 * 
 * Downloadable Executive Audit PDF Report for University Deans & State Auditors
 */
router.get('/executive-pdf', async (req: Request, res: Response) => {
  try {
    const timeframe = (req.query.timeframe as string) || '30d';
    const instId = (typeof req.institution_id === 'string' ? req.institution_id : (Array.isArray(req.institution_id) ? req.institution_id[0] : 'edu-admin-123')) as string;

    console.log(`📑 [PDF Report] Generating MedAccess Clinical Audit PDF for Institution: ${instId}, Timeframe: ${timeframe}`);

    const pdfBuffer = await generateExecutiveReport(timeframe, instId);

    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', 'attachment; filename="MedAccess_Clinical_Audit_Report.pdf"');
    res.setHeader('Content-Length', pdfBuffer.length.toString());

    res.send(pdfBuffer);
  } catch (error: any) {
    console.error('🚨 [PDF Report] Error generating PDF report:', error);
    res.status(500).json({ error: error.message || 'Internal Server Error' });
  }
});

export default router;
