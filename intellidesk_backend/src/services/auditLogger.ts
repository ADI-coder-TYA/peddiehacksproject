import { supabase } from '../config/supabase.js';

export async function logAuditEvent(
  institutionId: string,
  ticketId: string | null,
  actionType: string,
  actorType: string,
  details: any
): Promise<void> {
  try {
    const { error } = await supabase.from('audit_logs').insert({
      institution_id: institutionId,
      ticket_id: ticketId,
      action_type: actionType,
      actor_type: actorType,
      details: details,
    });

    if (error) {
      console.error('[AuditLogger] Failed to insert audit log:', error);
    }
  } catch (err) {
    console.error('[AuditLogger] Exception while logging audit event:', err);
  }
}
