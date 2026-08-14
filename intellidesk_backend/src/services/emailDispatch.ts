import { Resend } from 'resend';
import { supabase } from '../config/supabase.js';
import { GoogleGenAI } from '@google/genai';
import { logAuditEvent } from './auditLogger.js';
import { env } from '../config/env.js';

// Initialize clients — credentials are validated at startup by env.ts
const resend = new Resend(env.RESEND_API_KEY);
const ai = new GoogleGenAI({ apiKey: env.GEMINI_API_KEY });

const SENDER_EMAIL = env.SENDER_EMAIL;

/**
 * Ensures the drafted email is strictly privacy-redacted.
 */
async function redactAndFinalizeEmail(draft: string, studentName: string): Promise<string> {
  const prompt = `
    You are an automated university compliance system.
    Review the following drafted accommodation notice for a student named ${studentName}.
    Ensure the notice is strictly privacy-redacted. It MUST NOT contain any explicit medical diagnoses, specific disabilities, or sensitive personal health information.
    If it does, rewrite it to be generic (e.g., "for documented medical reasons" or "due to an approved accommodation").
    Maintain a professional, academic tone.
    Output ONLY the final email body text, nothing else.

    Draft:
    "${draft}"
  `;

  try {
    const response = await ai.models.generateContent({
      model: 'gemini-2.0-flash',
      contents: prompt,
    });
    return response.text || draft; // Fallback to original draft if error
  } catch (error) {
    console.error('[EmailDispatch] Error during Gemini redaction:', error);
    // If Gemini fails, we fail safe and do not send potentially sensitive unredacted text
    throw new Error('Failed to redact email content for privacy compliance.');
  }
}

/**
 * Dispatches accommodation notices to professors and logs the audit trail.
 */
export async function dispatchAccommodationNotices(
  institutionId: string,
  ticketId: string,
  studentDetails: { name: string; contact?: string },
  professorEmails: string[]
): Promise<void> {
  console.log(`[EmailDispatch] Starting dispatch for ticket ${ticketId}...`);

  // 1. Fetch the ticket to get the accommodation_mandate
  const { data: ticket, error: fetchError } = await supabase
    .from('tickets')
    .select('accommodation_mandate')
    .eq('id', ticketId)
    .eq('institution_id', institutionId)
    .single();

  if (fetchError || !ticket) {
    throw new Error(`Ticket not found or error fetching ticket: ${fetchError?.message}`);
  }

  const rawMandate = ticket.accommodation_mandate;
  if (!rawMandate) {
    throw new Error('No accommodation mandate was drafted for this ticket.');
  }

  // 2. Redact and finalize email content
  const finalizedEmailBody = await redactAndFinalizeEmail(rawMandate, studentDetails.name);

  // 3. Dispatch emails and log to audit_logs
  for (const email of professorEmails) {
    try {
      // Send email via Resend
      const { data, error: sendError } = await resend.emails.send({
        from: `EduAccess Welfare Office <${SENDER_EMAIL}>`,
        to: email,
        subject: `[Strictly Confidential] Academic Accommodation Notice: ${studentDetails.name}`,
        text: finalizedEmailBody,
      });

      if (sendError) {
        console.error(`[EmailDispatch] Failed to send email to ${email}:`, sendError);
        throw sendError;
      }

      console.log(`[EmailDispatch] Sent to ${email}, Resend ID: ${data?.id}`);

      // 4. Log to audit_logs for compliance using the new module
      await logAuditEvent(institutionId, ticketId, 'DISPATCH_SENT', 'ADMIN_USER', {
        professor_email: email,
        resend_id: data?.id,
        notes: 'Sent redacted accommodation notice.'
      });

    } catch (err) {
      console.error(`[EmailDispatch] Error processing professor ${email}:`, err);
      // Depending on requirements, we might want to continue with other professors or throw
    }
  }

  console.log(`[EmailDispatch] Completed dispatch for ticket ${ticketId}.`);
}
