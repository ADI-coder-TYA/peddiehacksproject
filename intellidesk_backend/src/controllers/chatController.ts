import { Request, Response } from 'express';
import { supabase } from '../config/supabase.js';
import { getIO } from '../services/socketManager.js';
import { generateClinicalCounselorResponse } from '../services/clinicalCounselorService.js';
import { DatabaseService } from '../services/dbService.js';

export class ChatController {
  /**
   * POST /api/v1/claims/:id/messages
   * Post a new patient message, run PFA counselor AI, persist to claim_messages, and emit socket updates.
   */
  static async sendClaimMessage(req: Request, res: Response): Promise<void> {
    try {
      const claimId = (Array.isArray(req.params.id) ? req.params.id[0] : req.params.id) as string;
      const { message, patientPhone } = req.body || {};

      if (!message || typeof message !== 'string' || message.trim().length === 0) {
        res.status(400).json({ error: 'Message cannot be empty.' });
        return;
      }

      // 1. Insert patient's message into claim_messages table
      let userMessageRecord: any = null;
      try {
        const { data: userMsg, error: uErr } = await supabase
          .from('claim_messages')
          .insert([
            {
              claim_id: claimId,
              sender: 'PATIENT',
              message: message.trim(),
              is_crisis_response: false,
            },
          ])
          .select('*')
          .single();

        if (!uErr && userMsg) {
          userMessageRecord = userMsg;
        }
      } catch (dbErr) {
        console.warn(`[ChatController] User message insert notice:`, dbErr);
      }

      // Emit patient message to claim socket room
      try {
        const io = getIO();
        io.to(`claim:${claimId}`).emit('chat:new_message', {
          claimId,
          sender: 'PATIENT',
          message: message.trim(),
          createdAt: new Date().toISOString(),
        });
      } catch (_) {}

      // 2. Fetch recent conversation history for this claim
      let history: Array<{ sender: string; message: string }> = [];
      try {
        const { data: msgs } = await supabase
          .from('claim_messages')
          .select('sender, message')
          .eq('claim_id', claimId)
          .order('created_at', { ascending: true })
          .limit(8);

        if (msgs) {
          history = msgs.map((m) => ({ sender: m.sender, message: m.message }));
        }
      } catch (_) {}

      // 3. Generate empathetic PFA counselor response
      const counselorResult = await generateClinicalCounselorResponse(claimId, message.trim(), history);

      // 4. Insert AI counselor response into claim_messages
      let counselorMessageRecord: any = null;
      try {
        const { data: aiMsg, error: aiErr } = await supabase
          .from('claim_messages')
          .insert([
            {
              claim_id: claimId,
              sender: 'COUNSELOR_AI',
              message: counselorResult.reply,
              is_crisis_response: counselorResult.isCrisisResponse,
              suggested_resources: counselorResult.resources,
            },
          ])
          .select('*')
          .single();

        if (!aiErr && aiMsg) {
          counselorMessageRecord = aiMsg;
        }
      } catch (dbErr) {
        console.warn(`[ChatController] AI message insert notice:`, dbErr);
      }

      // 5. Emit AI reply to claim room
      try {
        const io = getIO();
        io.to(`claim:${claimId}`).emit('chat:new_message', {
          claimId,
          sender: 'COUNSELOR_AI',
          message: counselorResult.reply,
          isCrisisResponse: counselorResult.isCrisisResponse,
          resources: counselorResult.resources,
          createdAt: new Date().toISOString(),
        });
      } catch (_) {}

      res.status(200).json({
        success: true,
        reply: counselorResult.reply,
        isCrisisResponse: counselorResult.isCrisisResponse,
        isLifeSafetyAlert: counselorResult.isLifeSafetyAlert,
        resources: counselorResult.resources,
        latencyMs: counselorResult.latencyMs,
      });
    } catch (err: any) {
      console.error('[ChatController.sendClaimMessage] Error:', err);
      res.status(500).json({ error: err.message || 'Chat generation failed' });
    }
  }

  /**
   * GET /api/v1/claims/:id/messages
   * Fetch all message history for a given claim.
   */
  static async getClaimMessages(req: Request, res: Response): Promise<void> {
    try {
      const claimId = (Array.isArray(req.params.id) ? req.params.id[0] : req.params.id) as string;

      const { data: messages, error } = await supabase
        .from('claim_messages')
        .select('*')
        .eq('claim_id', claimId)
        .order('created_at', { ascending: true });

      if (error) {
        // Fallback to ticket_messages table
        const { data: ticketMsgs } = await supabase
          .from('ticket_messages')
          .select('*')
          .eq('ticket_id', claimId)
          .order('created_at', { ascending: true });

        res.status(200).json(ticketMsgs || []);
        return;
      }

      res.status(200).json(messages || []);
    } catch (err: any) {
      console.error('[ChatController.getClaimMessages] Error:', err);
      res.status(500).json({ error: err.message || 'Internal Server Error' });
    }
  }
}
