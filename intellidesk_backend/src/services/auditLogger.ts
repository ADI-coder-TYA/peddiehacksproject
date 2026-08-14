import { supabase } from '../config/supabase.js';

export async function logAuditEvent(
  institutionId: string,
  entityId: string | null,
  action: string,
  performedBy: string,
  details: any,
  entityType: string = 'CLAIM'
): Promise<void> {
  try {
    const { error } = await supabase.from('audit_logs').insert({
      institution_id: institutionId || 'inst-001',
      action: action || 'CLAIM_UPDATE',
      performed_by: performedBy || 'SYSTEM',
      entity_type: entityType,
      entity_id: entityId || 'N/A',
      details: details || {},
    });

    if (error) {
      console.warn('[AuditLogger] Notice inserting audit log:', error.message);
    }
  } catch (err: any) {
    console.warn('[AuditLogger] Exception logging audit event:', err.message);
  }
}
