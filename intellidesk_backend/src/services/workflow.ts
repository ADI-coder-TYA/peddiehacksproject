import { supabase } from '../config/supabase.js';
import { draftAccommodationEmail } from './gemini.js';
import { getIO } from './socketManager.js';
import { logAuditEvent } from './auditLogger.js';
import { v4 as uuidv4 } from 'uuid';
import twilio from 'twilio';

const twilioClient = twilio(process.env.TWILIO_ACCOUNT_SID!, process.env.TWILIO_AUTH_TOKEN!);

export async function evaluateAndExecute(ticketId: string): Promise<void> {
  try {
    const { data: ticket, error: fetchError } = await supabase
      .from('tickets')
      .select('*')
      .eq('id', ticketId)
      .single();

    if (fetchError || !ticket) {
      console.error('Error fetching ticket for workflow execution:', fetchError);
      return;
    }

    let newStatus = ticket.status;
    let policyMatchReason = ticket.policy_match_reason || '';
    let accommodationMandate: string | null = null;

    const reliesOnMedicalOrAccommodation = policyMatchReason.includes('reliesOnMedicalOrAccommodation:true'); // Or any other check

    if (ticket.urgency_level === 'Routine' || ticket.calculated_amount <= 200) {
      newStatus = 'Auto-Approved';
      const voucherCode = `EDUAID-${uuidv4().slice(0, 8).toUpperCase()}`;
      
      if (process.env.TWILIO_PHONE_NUMBER) {
          try {
              await twilioClient.messages.create({
                  body: `Your request has been auto-approved. Your pharmacy voucher code is: ${voucherCode}. Present this at any campus pharmacy.`,
                  from: process.env.TWILIO_PHONE_NUMBER,
                  to: ticket.student_phone
              });
          } catch (smsError) {
              console.error('Error sending SMS:', smsError);
          }
      }
    } else if (reliesOnMedicalOrAccommodation) {
      newStatus = 'Escalated';
      accommodationMandate = await draftAccommodationEmail(ticket.raw_message, "Professor");
      console.log('Drafted Accommodation Email:', accommodationMandate);
    } else {
      newStatus = 'Pending';
    }

    const updatePayload: Record<string, any> = { status: newStatus };
    if (accommodationMandate) {
      updatePayload.accommodation_mandate = accommodationMandate;
    }
    if (newStatus === 'Auto-Approved') {
      updatePayload.resolved_at = new Date().toISOString();
      await logAuditEvent(ticket.institution_id, ticketId, 'AUTO_APPROVAL', 'AI_AGENT', {
        policy_match_reason: policyMatchReason,
        amount_disbursed: ticket.calculated_amount
      });
    }

    const { error: updateError } = await supabase
      .from('tickets')
      .update(updatePayload)
      .eq('id', ticketId);

    if (updateError) {
      console.error('Error updating ticket status:', updateError);
      return;
    }

    const io = getIO();
    io.emit('ticket:updated', { id: ticketId, status: newStatus });
    
  } catch (error) {
    console.error('Error in evaluateAndExecute:', error);
  }
}
