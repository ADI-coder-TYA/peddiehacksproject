import { Router, Request, Response } from 'express';
import { supabase } from '../config/supabase.js';
import { getIO } from '../services/socketManager.js';
import { dispatchAccommodationNotices } from '../services/emailDispatch.js';

const workflowDispatchRouter = Router();

// ── POST /dispatch-academic/:ticketId ──────────────────────────
// Triggered by the Admin UI to approve and send out academic notices.

workflowDispatchRouter.post('/dispatch-academic/:ticketId', async (req: Request, res: Response) => {
  try {
    const ticketId = req.params.ticketId as string;
    const { professorEmails, studentDetails } = req.body;

    if (!professorEmails || !Array.isArray(professorEmails) || professorEmails.length === 0) {
      res.status(400).json({ error: 'professorEmails array is required and must not be empty.' });
      return;
    }

    if (!studentDetails || !studentDetails.name) {
      res.status(400).json({ error: 'studentDetails object with a name is required.' });
      return;
    }

    // 1. Dispatch the accommodation notices (this redacts and logs to audit_logs)
    await dispatchAccommodationNotices(req.institution_id!, ticketId, studentDetails, professorEmails);

    // 2. Update the ticket status to 'Resolved' and set resolved_at
    const { error: updateError } = await supabase
      .from('tickets')
      .update({ status: 'Resolved', resolved_at: new Date().toISOString() })
      .eq('id', ticketId)
      .eq('institution_id', req.institution_id);

    if (updateError) {
      console.error('[WorkflowDispatch] Error updating ticket status:', updateError);
      res.status(500).json({ error: 'Emails sent, but failed to update ticket status.' });
      return;
    }

    // 3. Emit real-time update so Admin UI refreshes
    try {
      const io = getIO();
      io.emit('ticket:updated', { id: ticketId, status: 'Resolved' });
    } catch (e) {
      // Socket not initialized during tests, ignore
    }

    res.status(200).json({
      success: true,
      message: 'Academic notices successfully dispatched and ticket resolved.',
    });
  } catch (error: any) {
    console.error('[WorkflowDispatch] Error in dispatch-academic:', error);
    res.status(500).json({
      error: error.message || 'An unexpected error occurred during dispatch.',
    });
  }
});

export default workflowDispatchRouter;
