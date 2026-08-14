import { Router, Request, Response } from 'express';
import { generateExecutiveReport } from '../services/pdfReportService.js';

const router = Router();

/**
 * Handler for generating clinical audit PDF stream
 */
async function handleClinicalAuditPdf(req: Request, res: Response) {
  try {
    const timeframe = (req.query.timeframe as string) || '30d';
    const instId = (typeof req.institution_id === 'string' ? req.institution_id : (Array.isArray(req.institution_id) ? req.institution_id[0] : (req.query.institutionId as string) || 'default')) as string;

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
}

// GET /api/v1/reports/clinical-audit-pdf
router.get('/clinical-audit-pdf', handleClinicalAuditPdf);

// GET /api/v1/reports/executive-pdf
router.get('/executive-pdf', handleClinicalAuditPdf);

export default router;
