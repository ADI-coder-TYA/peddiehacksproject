import { Router, Request, Response } from 'express';
import { z } from 'zod';
import multer from 'multer';
import { v4 as uuidv4 } from 'uuid';
import twilio from 'twilio';
import { intakeQueue } from '../workers/queueManager.js';
import { tenantScopeMiddleware } from '../middleware/tenant.js';
import { supabase } from '../config/supabase.js';
import { classifyCategoryDynamic } from '../utils/categoryClassifier.js';
import { transcribeLocalAudio } from '../services/localVoiceService.js';
import { evaluateLifeSafety } from '../services/safetyGuardrails.js';
import { extractTextFromPdf } from '../services/receiptParser.js';
import Tesseract from 'tesseract.js';

const asyncIntakeRouter = Router();
const MessagingResponse = twilio.twiml.MessagingResponse;

// Multer for Web File Uploads
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 10 * 1024 * 1024, files: 1 },
});

// Zod Validation Schemas
const WebIntakeSchema = z.object({
  message: z.string().optional(),
  description: z.string().optional(),
  patientName: z.string().optional(),
  studentName: z.string().optional(),
  patientContact: z.string().optional(),
  patientPhone: z.string().optional(),
  studentContact: z.string().optional(),
  studentPhone: z.string().optional(),
  clinicalCategory: z.string().optional(),
  category: z.string().optional(),
}).refine(
  (data) => {
    const hasTextContent = !!(data.message || data.description);
    const hasContact = !!(data.patientContact || data.patientPhone || data.studentContact || data.studentPhone);
    return hasTextContent || hasContact;
  },
  {
    message: "Validation failed: provide a medical description or document attachment with contact info.",
  }
);

const SmsIntakeSchema = z.object({
  Body: z.string().min(1, "Message body cannot be empty"),
  From: z.string().min(1, "Sender phone number is required"),
  MediaUrl0: z.string().url().optional(),
});

// Queue Backpressure Middleware
const checkBackpressure = async (req: Request, res: Response, next: Function) => {
  try {
    const waitingCount = await intakeQueue.getWaitingCount();
    if (waitingCount > 500) {
      res.setHeader('Retry-After', '60');
      res.status(429).json({ error: 'System is currently experiencing high volume. Please try again in 60 seconds.' });
      return;
    }
    next();
  } catch (error) {
    console.error('Failed to check queue count', error);
    next();
  }
};

// ─── 1. WEB INTAKE ENDPOINT ─────────────────────────────────────
asyncIntakeRouter.post('/web', checkBackpressure, tenantScopeMiddleware, upload.single('attachment'), async (req: Request, res: Response) => {
  try {
    const institutionId = (req as any).institution_id || 'default';
    
    // Validate payload
    const parsedData = WebIntakeSchema.parse(req.body);
    let fullMessage = parsedData.message || parsedData.description || req.body.description || '';
    if (!fullMessage && !req.file) {
       res.status(400).json({ error: 'Please provide a clinical description or attach a hospital receipt.' });
       return;
    }

    let mediaUrl: string | undefined = req.body.media_url || req.body.attachment_url || req.body.receipt_url || req.body.mediaUrl || req.body.attachmentUrl || undefined;

    if (req.file) {
      console.log(`📎 [AsyncWebIntake] Upload received: "${req.file.originalname}" (${req.file.size} bytes, ${req.file.mimetype})`);
      let attachmentText = '';
      try {
        if (req.file.mimetype === 'application/pdf' || req.file.originalname.toLowerCase().endsWith('.pdf')) {
          attachmentText = await extractTextFromPdf(req.file.buffer);
        } else if (req.file.mimetype.startsWith('image/')) {
          const { data: { text } } = await Tesseract.recognize(req.file.buffer, 'eng');
          attachmentText = text;
        }
      } catch (ocrErr) {
        console.error('[AsyncWebIntake] Attachment extraction failed:', ocrErr);
      }

      // Upload file directly to Supabase storage receipts bucket
      try {
        const fileName = `${Date.now()}_${req.file.originalname.replace(/[^\w\.-]/g, '_')}`;
        const { error: uploadError } = await supabase.storage.from('receipts').upload(fileName, req.file.buffer, {
          contentType: req.file.mimetype || 'application/pdf',
          upsert: true
        });

        if (!uploadError) {
          const { data: { publicUrl } } = supabase.storage.from('receipts').getPublicUrl(fileName);
          mediaUrl = publicUrl;
          console.log(`☁️ [Supabase Storage] Saved file to receipts bucket: ${publicUrl}`);
        } else {
          console.warn(`⚠️ [Supabase Storage] Upload notice: ${uploadError.message}`);
        }
      } catch (storageErr: any) {
        console.warn(`⚠️ [Supabase Storage] Bucket upload error: ${storageErr.message}`);
      }

      if (!mediaUrl) {
        mediaUrl = `data:${req.file.mimetype || 'application/octet-stream'};base64,${req.file.buffer.toString('base64')}`;
      }

      if (attachmentText && attachmentText.trim().length > 0) {
        fullMessage = fullMessage ? `${fullMessage}\n\n[Document Content - ${req.file.originalname}]:\n${attachmentText.trim()}` : attachmentText.trim();
        console.log(`📄 [AsyncWebIntake] Appended ${attachmentText.length} extracted characters to message.`);
      } else {
        fullMessage += `\n\n[Attachment: ${req.file.originalname}]`;
      }
    } else if (mediaUrl && mediaUrl.startsWith('data:')) {
      // If client sent base64 data URI, upload decoded bytes to Supabase storage receipts bucket
      try {
        const commaIdx = mediaUrl.indexOf(',');
        const base64Data = commaIdx !== -1 ? mediaUrl.substring(commaIdx + 1) : mediaUrl;
        const mimeMatch = mediaUrl.match(/data:([^;]+);/);
        const mimeType = mimeMatch ? mimeMatch[1] : 'application/pdf';
        const ext = mimeType.includes('pdf') ? 'pdf' : (mimeType.includes('png') ? 'png' : 'jpg');
        const fileName = `receipt_${Date.now()}_${Math.random().toString(36).substring(7)}.${ext}`;
        const buffer = Buffer.from(base64Data, 'base64');

        const { error: uploadError } = await supabase.storage.from('receipts').upload(fileName, buffer, {
          contentType: mimeType,
          upsert: true
        });

        if (!uploadError) {
          const { data: { publicUrl } } = supabase.storage.from('receipts').getPublicUrl(fileName);
          mediaUrl = publicUrl;
          console.log(`☁️ [Supabase Storage] Saved base64 payload to receipts bucket: ${publicUrl}`);
        }
      } catch (uploadErr: any) {
        console.warn(`⚠️ [Supabase Storage] Base64 upload notice: ${uploadErr.message}`);
      }
    }

    const lifeSafety = evaluateLifeSafety(fullMessage);
    const initialCategory = lifeSafety.isLifeSafetyCritical
      ? lifeSafety.lockedCategory
      : await classifyCategoryDynamic(fullMessage);
    const initialUrgency = lifeSafety.isLifeSafetyCritical ? 'Critical' : 'Routine';

    const patientContact = parsedData.patientContact || parsedData.patientPhone || parsedData.studentContact || parsedData.studentPhone || req.body.patientPhone || 'web-client';
    let claimId: string = '';
    
    try {
      const { data: claimRow, error: claimErr } = await supabase.from('claims').insert([{
        institution_id: institutionId,
        patient_phone: patientContact,
        description: fullMessage,
        receipt_url: mediaUrl,
        clinical_category: initialCategory,
        esi_level: lifeSafety.isLifeSafetyCritical ? 'ESI_1_CRITICAL' : 'ROUTINE',
        status: 'Submitted'
      }]).select().single();

      if (!claimErr && claimRow) {
        claimId = claimRow.id;
      }
    } catch (_) {}

    // Synchronize to tickets table for backward compatibility
    let ticketId: string = claimId;
    try {
      const { data: ticket, error: insertError } = await supabase.from('tickets').insert([{
        id: claimId || undefined,
        institution_id: institutionId,
        student_phone: parsedData.studentContact || 'web-client',
        raw_message: fullMessage,
        media_url: mediaUrl,
        parsed_category: initialCategory,
        urgency_level: initialUrgency,
        status: 'Pending'
      }]).select().single();

      if (ticket) {
        ticketId = ticket.id;
        if (!claimId) claimId = ticket.id;
      }
    } catch (_) {}

    const job = await intakeQueue.add('process-web-intake', {
      claimId,
      ticketId,
      rawMessage: fullMessage,
      description: fullMessage,
      mediaUrl,
      media_url: mediaUrl,
      attachmentUrl: mediaUrl,
      studentName: parsedData.studentName || 'Anonymous',
      studentPhone: parsedData.studentContact || 'web-client',
      patientPhone: parsedData.studentContact || 'web-client',
      institutionId,
      source: 'web'
    }, {
      attempts: 3,
      backoff: { type: 'exponential', delay: 2000 }
    });

    res.status(202).json({
      success: true,
      message: 'Clinical claim queued for triage.',
      jobId: job.id,
      claimId,
      ticketId,
      status: 'queued',
      trackingUrl: `/api/v1/intake/status/${job.id}`
    });
  } catch (error: any) {
    if (error instanceof z.ZodError) {
       res.status(400).json({ error: 'Validation failed', details: error.issues });
       return;
    }
    console.error('[AsyncWebIntake] Error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─── 2. SMS INTAKE ENDPOINT (Twilio) ────────────────────────────
asyncIntakeRouter.post('/sms', checkBackpressure, async (req: Request, res: Response) => {
  try {
    const institutionId = (typeof req.query.institutionId === 'string' ? req.query.institutionId : undefined) || process.env.DEFAULT_INSTITUTION_ID || 'default';
    
    // Validate payload
    const parsedData = SmsIntakeSchema.parse(req.body);

    const initialCategory = await classifyCategoryDynamic(parsedData.Body);

    const { data: ticket, error: insertError } = await supabase.from('tickets').insert([{
      institution_id: institutionId,
      student_phone: parsedData.From,
      raw_message: parsedData.Body,
      media_url: parsedData.MediaUrl0,
      parsed_category: initialCategory,
      urgency_level: 'Routine',
      status: 'Pending'
    }]).select().single();

    if (insertError) {
      throw new Error(`Failed to create ticket: ${insertError.message}`);
    }

    const ticketId = ticket.id;

    const job = await intakeQueue.add('process-sms-intake', {
      ticketId,
      rawMessage: parsedData.Body,
      studentPhone: parsedData.From,
      mediaUrl: parsedData.MediaUrl0,
      institutionId,
      source: 'sms'
    }, {
      attempts: 3,
      backoff: { type: 'exponential', delay: 2000 }
    });

    // Twilio needs TwiML back instantly
    const twiml = new MessagingResponse();
    twiml.message(`Your request is queued (Job: ${job.id}). We will notify you once processed.`);
    res.type('text/xml').send(twiml.toString());
  } catch (error: any) {
    if (error instanceof z.ZodError) {
       res.status(400).send('Invalid request payload');
       return;
    }
    console.error('[AsyncSmsIntake] Error:', error);
    res.status(500).send('Internal Server Error');
  }
});

// ─── 3. REAL-TIME JOB PROGRESS & STATUS POLLING ─────────────────
asyncIntakeRouter.get('/status/:jobId', async (req: Request, res: Response) => {
  try {
    const { jobId } = req.params;
    const job = await intakeQueue.getJob(jobId as string);

    if (!job) {
      res.status(404).json({ error: 'Job not found' });
      return;
    }

    const state = await job.getState(); // 'active', 'completed', 'waiting', 'failed', 'delayed'
    
    if (state === 'completed') {
      res.json({
        jobId,
        status: state,
        result: job.returnvalue, // e.g., { status: 'AUTO_APPROVED', epistemicUncertainty: ... }
        processedAt: job.finishedOn
      });
      return;
    }

    if (state === 'failed') {
      res.json({
        jobId,
        status: state,
        error: job.failedReason,
        attemptsMade: job.attemptsMade,
        failedAt: job.finishedOn
      });
      return;
    }

    // Active, waiting, or delayed
    res.json({
      jobId,
      status: state,
      progress: job.progress,
      attemptsMade: job.attemptsMade,
    });
  } catch (error) {
    console.error('[JobStatus] Error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─── 4. IN-APP VOICE INTAKE ENDPOINT (Local Whisper STT) ─────────
asyncIntakeRouter.post('/voice', checkBackpressure, tenantScopeMiddleware, upload.single('audio'), async (req: Request, res: Response) => {
  try {
    const institutionId = (req as any).institution_id || 'default';
    const studentPhone = (req.body.studentContact || req.body.studentPhone || 'voice-client').trim();
    const studentName = (req.body.studentName || 'Anonymous').trim();

    let transcript = '';
    if (req.file && req.file.buffer) {
      transcript = await transcribeLocalAudio(req.file.buffer);
    } else if (req.body.transcript) {
      transcript = req.body.transcript;
    } else {
      res.status(400).json({ error: 'Please upload an audio file or transcript.' });
      return;
    }

    const initialCategory = await classifyCategoryDynamic(transcript);

    const { data: ticket, error: insertError } = await supabase.from('tickets').insert([{
      institution_id: institutionId,
      student_phone: studentPhone,
      raw_message: transcript,
      parsed_category: initialCategory,
      urgency_level: 'Routine',
      status: 'Pending'
    }]).select().single();

    if (insertError) {
      throw new Error(`Failed to create ticket: ${insertError.message}`);
    }

    const ticketId = ticket.id;

    const job = await intakeQueue.add('process-voice-intake', {
      ticketId,
      rawMessage: transcript,
      studentName,
      studentPhone,
      institutionId,
      source: 'voice'
    }, {
      attempts: 3,
      backoff: { type: 'exponential', delay: 2000 }
    });

    res.status(202).json({
      success: true,
      message: 'Voice distress note transcribed offline and queued for processing.',
      transcript,
      jobId: job.id,
      ticketId,
      status: 'queued',
      trackingUrl: `/api/v1/intake/status/${job.id}`
    });
  } catch (error: any) {
    console.error('[AsyncVoiceIntake] Error:', error);
    res.status(500).json({ error: error.message || 'Internal server error' });
  }
});

export default asyncIntakeRouter;
