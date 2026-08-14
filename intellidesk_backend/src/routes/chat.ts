import { Router, Request, Response } from 'express';
import { z } from 'zod';
import { supabase } from '../config/supabase.js';
import { intakeQueue } from '../workers/queueManager.js';
import { 
  generateCounselorResponse, 
  CRITICAL_SELF_HARM_REGEX, 
  RELIEF_HARDSHIP_REGEX, 
  TICKET_CONFIRM_REGEX 
} from '../services/crisisCounselorService.js';
import { getIO } from '../services/socketManager.js';
import { evaluateLifeSafety } from '../services/safetyGuardrails.js';
import { classifyCategoryDynamic } from '../utils/categoryClassifier.js';

const chatRouter = Router();

const ChatMessageSchema = z.object({
  ticketId: z.string().uuid().optional().nullable(),
  studentPhone: z.string().optional().nullable().default('web-client'),
  studentName: z.string().optional().nullable().default('Anonymous'),
  message: z.string().min(1, 'Message cannot be empty'),
  contextMessage: z.string().optional().nullable(),
  history: z.array(z.object({ sender: z.string(), message: z.string() })).optional().nullable(),
  confirmTicket: z.boolean().optional().nullable(),
  institutionId: z.string().optional().nullable(),
  media_url: z.string().optional().nullable(),
  attachment_url: z.string().optional().nullable(),
  mediaUrl: z.string().optional().nullable(),
  attachmentUrl: z.string().optional().nullable(),
});

// ─── POST /api/v1/chat/message ───────────────────────────────────
chatRouter.post('/message', async (req: Request, res: Response) => {
  try {
    const institutionId = (req.headers['x-institution-id'] as string) || req.body.institutionId || 'edu-admin-123';
    const parsed = ChatMessageSchema.parse(req.body);

    let mediaUrl = parsed.media_url || parsed.attachment_url || parsed.mediaUrl || parsed.attachmentUrl || req.body.media_url || req.body.attachment_url || req.body.receipt_url || null;

    if (mediaUrl && mediaUrl.startsWith('data:')) {
      try {
        const commaIdx = mediaUrl.indexOf(',');
        const base64Data = commaIdx !== -1 ? mediaUrl.substring(commaIdx + 1) : mediaUrl;
        const mimeMatch = mediaUrl.match(/data:([^;]+);/);
        const mimeType = mimeMatch ? mimeMatch[1] : 'application/pdf';
        const ext = mimeType.includes('pdf') ? 'pdf' : (mimeType.includes('png') ? 'png' : 'jpg');
        const fileName = `chat_${Date.now()}_${Math.random().toString(36).substring(7)}.${ext}`;
        const buffer = Buffer.from(base64Data, 'base64');

        const { error: uploadError } = await supabase.storage.from('receipts').upload(fileName, buffer, {
          contentType: mimeType,
          upsert: true
        });

        if (!uploadError) {
          const { data: { publicUrl } } = supabase.storage.from('receipts').getPublicUrl(fileName);
          mediaUrl = publicUrl;
          console.log(`☁️ [Supabase Storage] Saved chat attachment to receipts bucket: ${publicUrl}`);
        }
      } catch (uploadErr: any) {
        console.warn(`⚠️ [Supabase Storage] Chat base64 upload notice: ${uploadErr.message}`);
      }
    }

    let activeTicketId: string | null = parsed.ticketId || null;
    let isNewTicketCreated = false;
    let triageJobId: string | null = null;

    const isLifeSafety = CRITICAL_SELF_HARM_REGEX.test(parsed.message);
    const isExplicitConfirmation = parsed.confirmTicket === true || TICKET_CONFIRM_REGEX.test(parsed.message.trim());
    const isHardshipInquiry = RELIEF_HARDSHIP_REGEX.test(parsed.message);

    // Assemble rich context message if this is a confirmation turn so ML model sees the real situation
    let effectiveMessage = parsed.message;
    if (isExplicitConfirmation) {
      if (parsed.contextMessage) {
        effectiveMessage = `${parsed.contextMessage}\n\n[Confirmation: ${parsed.message}]`;
      } else if (parsed.history && parsed.history.length > 0) {
        const priorUserMsgs = parsed.history.filter(h => h.sender.toUpperCase() === 'STUDENT' && h.message !== parsed.message);
        const lastPrior = priorUserMsgs.pop();
        if (lastPrior) {
          effectiveMessage = `${lastPrior.message}\n\n[Confirmation: ${parsed.message}]`;
        }
      }
    }

    const shouldCreateTicket = !activeTicketId && (isLifeSafety || isExplicitConfirmation);

    if (shouldCreateTicket) {
      const lifeSafety = evaluateLifeSafety(effectiveMessage);
      const initialCategory = lifeSafety.isLifeSafetyCritical
        ? lifeSafety.lockedCategory
        : await classifyCategoryDynamic(effectiveMessage);
      const initialUrgency = lifeSafety.isLifeSafetyCritical ? 'Critical' : (isHardshipInquiry || RELIEF_HARDSHIP_REGEX.test(effectiveMessage) ? 'High' : 'Routine');

      const { data: ticket, error: ticketErr } = await supabase
        .from('tickets')
        .insert([
          {
            institution_id: institutionId,
            student_phone: parsed.studentPhone,
            raw_message: effectiveMessage,
            media_url: mediaUrl,
            parsed_category: initialCategory,
            urgency_level: initialUrgency,
            status: 'Pending'
          }
        ])
        .select()
        .single();

      if (ticketErr) {
        console.error('[ChatRouter] Ticket creation error:', ticketErr);
        throw new Error(`Failed to create ticket for chat: ${ticketErr.message}`);
      }

      activeTicketId = ticket.id;
      isNewTicketCreated = true;

      // Dispatch Async Background Job to IntakeWorker (BullMQ) with full context
      try {
        const triageJob = await intakeQueue.add(
          'process-chat-triage',
          {
            ticketId: activeTicketId,
            rawMessage: effectiveMessage,
            mediaUrl: mediaUrl,
            media_url: mediaUrl,
            attachmentUrl: mediaUrl,
            studentName: parsed.studentName,
            studentPhone: parsed.studentPhone,
            institutionId,
            source: 'chat'
          },
          {
            attempts: 3,
            backoff: { type: 'exponential', delay: 2000 }
          }
        );
        triageJobId = triageJob.id ? String(triageJob.id) : null;
      } catch (queueErr) {
        console.warn('[ChatRouter] BullMQ queue dispatch warning:', queueErr);
      }
    }

    // Persist student message in ticket_messages if ticket exists
    if (activeTicketId) {
      try {
        await supabase.from('ticket_messages').insert([
          {
            ticket_id: activeTicketId,
            sender: 'STUDENT',
            message: parsed.message,
            is_crisis_response: isLifeSafety
          }
        ]);
      } catch (msgInsertErr) {
        console.warn('[ChatRouter] Warning inserting student message:', msgInsertErr);
      }
    }

    // Fetch recent chat history for context
    let history: Array<{ sender: string; message: string }> = [];
    if (activeTicketId) {
      try {
        const { data: historyData } = await supabase
          .from('ticket_messages')
          .select('sender, message')
          .eq('ticket_id', activeTicketId)
          .order('created_at', { ascending: true })
          .limit(10);

        if (historyData) {
          history = historyData.map((h) => ({ sender: h.sender, message: h.message }));
        }
      } catch (histErr) {
        console.warn('[ChatRouter] History fetch warning:', histErr);
      }
    }

    // Generate Real-Time Psychological First Aid Counselor Response
    const counselorResponse = await generateCounselorResponse(
      activeTicketId,
      parsed.message,
      history,
      { isTicketCreated: isNewTicketCreated }
    );

    // Emit Socket.io event if ticket is active
    if (activeTicketId) {
      try {
        const io = getIO();
        io.to(`ticket:${activeTicketId}`).emit('chat:new_message', {
          ticketId: activeTicketId,
          sender: 'COUNSELOR_AI',
          message: counselorResponse.reply,
          isCrisisResponse: counselorResponse.isCrisisResponse,
          resources: counselorResponse.resources,
          timestamp: new Date().toISOString()
        });
      } catch (socketErr) {
        console.warn('[ChatRouter] Socket emit notice:', socketErr);
      }
    }

    // Return immediate supportive response
    res.status(200).json({
      success: true,
      ticketId: activeTicketId,
      jobId: triageJobId,
      reply: counselorResponse.reply,
      isCrisisResponse: counselorResponse.isCrisisResponse,
      requiresConfirmation: counselorResponse.requiresConfirmation,
      isTicketLogged: counselorResponse.isTicketLogged,
      resources: counselorResponse.resources,
      latencyMs: counselorResponse.latencyMs
    });
  } catch (error: any) {
    if (error instanceof z.ZodError) {
      res.status(400).json({ error: 'Validation failed', details: error.issues });
      return;
    }
    console.error('[ChatRouter] Error processing chat message:', error);
    res.status(500).json({ error: error.message || 'Internal server error' });
  }
});

// ─── GET /api/v1/chat/messages/:ticketId ─────────────────────────
chatRouter.get('/messages/:ticketId', async (req: Request, res: Response) => {
  try {
    const { ticketId } = req.params;
    const { data: messages, error } = await supabase
      .from('ticket_messages')
      .select('*')
      .eq('ticket_id', ticketId)
      .order('created_at', { ascending: true });

    if (error) {
      throw error;
    }

    res.status(200).json({
      success: true,
      ticketId,
      messages: messages || []
    });
  } catch (error: any) {
    console.error('[ChatRouter] Error fetching ticket messages:', error);
    res.status(500).json({ error: error.message || 'Failed to fetch messages' });
  }
});

export default chatRouter;
