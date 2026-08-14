import { supabase } from '../config/supabase.js';
import {
  Claim,
  ClaimMessage,
  HealthFund,
  Institution,
  PatientProfile,
  PatientRoster,
  DBClaimRow,
  DBHealthFundRow,
} from '../types/clinical.js';

export class DatabaseService {
  /**
   * Check database connectivity and ensure core tables (claims, health_funds) are reachable.
   */
  static async checkDatabaseHealth(): Promise<{ status: string; claimsReady: boolean; fundsReady: boolean; error?: string }> {
    try {
      const [claimsRes, fundsRes] = await Promise.allSettled([
        supabase.from('claims').select('id', { count: 'exact', head: true }),
        supabase.from('health_funds').select('id', { count: 'exact', head: true }),
      ]);

      const claimsReady = claimsRes.status === 'fulfilled' && !claimsRes.value.error;
      const fundsReady = fundsRes.status === 'fulfilled' && !fundsRes.value.error;

      return {
        status: claimsReady && fundsReady ? 'healthy' : 'degraded',
        claimsReady,
        fundsReady,
        error: claimsRes.status === 'rejected' ? String(claimsRes.reason) : undefined,
      };
    } catch (err: any) {
      return {
        status: 'unreachable',
        claimsReady: false,
        fundsReady: false,
        error: err?.message || String(err),
      };
    }
  }

  // ============================================================================
  // CLAIMS / EMERGENCY COPAY REQUESTS
  // ============================================================================

  static async createClaim(claim: Partial<Claim> & { institutionId: string; patientPhone: string; description: string }): Promise<Claim> {
    const payload: Partial<DBClaimRow> = {
      institution_id: claim.institutionId,
      patient_id: claim.patientId || null,
      patient_phone: claim.patientPhone,
      description: claim.description,
      clinical_category: claim.clinicalCategory || 'General Health & Basic Welfare',
      esi_level: claim.esiLevel || 'ROUTINE',
      crisis_severity_index: claim.crisisSeverityIndex ?? 0.0,
      is_life_safety_alert: claim.isLifeSafetyAlert ?? false,
      receipt_url: claim.receiptUrl || null,
      receipt_image_hash: claim.receiptImageHash || null,
      extracted_bill_amount: claim.extractedBillAmount || null,
      currency: claim.currency || 'INR',
      recommended_copay_amount: claim.recommendedCopayAmount ?? 0.0,
      approved_amount: claim.approvedAmount ?? 0.0,
      fraud_risk_score: claim.fraudRiskScore ?? 0.0,
      fraud_flags: claim.fraudFlags || null,
      status: claim.status || 'Submitted',
      clinical_notes: claim.clinicalNotes || null,
      matched_policy_id: claim.matchedPolicyId || null,
      payout_reference: claim.payoutReference || null,
      payout_method: claim.payoutMethod || null,
    };

    const { data, error } = await supabase
      .from('claims')
      .insert([payload])
      .select('*')
      .single();

    if (error) {
      throw new Error(`Failed to create clinical claim: ${error.message}`);
    }

    return this.mapDBRowToClaim(data);
  }

  static async getClaimById(id: string, institutionId?: string): Promise<Claim | null> {
    let query = supabase.from('claims').select('*').eq('id', id);
    if (institutionId) {
      query = query.eq('institution_id', institutionId);
    }

    const { data, error } = await query.maybeSingle();
    if (error || !data) return null;
    return this.mapDBRowToClaim(data);
  }

  static async getClaims(institutionId: string, filters?: { status?: string; esiLevel?: string; limit?: number }): Promise<Claim[]> {
    let query = supabase
      .from('claims')
      .select('*')
      .eq('institution_id', institutionId)
      .order('created_at', { ascending: false });

    if (filters?.status) {
      query = query.eq('status', filters.status);
    }
    if (filters?.esiLevel) {
      query = query.eq('esi_level', filters.esiLevel);
    }
    if (filters?.limit) {
      query = query.limit(filters.limit);
    }

    const { data, error } = await query;
    if (error || !data) return [];
    return data.map((row) => this.mapDBRowToClaim(row));
  }

  static async updateClaim(id: string, institutionId: string, updates: Partial<Claim>): Promise<Claim> {
    const payload: Record<string, any> = {
      updated_at: new Date().toISOString(),
    };

    if (updates.status !== undefined) payload.status = updates.status;
    if (updates.approvedAmount !== undefined) payload.approved_amount = updates.approvedAmount;
    if (updates.recommendedCopayAmount !== undefined) payload.recommended_copay_amount = updates.recommendedCopayAmount;
    if (updates.payoutReference !== undefined) payload.payout_reference = updates.payoutReference;
    if (updates.payoutMethod !== undefined) payload.payout_method = updates.payoutMethod;
    if (updates.clinicalNotes !== undefined) payload.clinical_notes = updates.clinicalNotes;
    if (updates.fraudRiskScore !== undefined) payload.fraud_risk_score = updates.fraudRiskScore;
    if (updates.fraudFlags !== undefined) payload.fraud_flags = updates.fraudFlags;
    if (updates.esiLevel !== undefined) payload.esi_level = updates.esiLevel;
    if (updates.crisisSeverityIndex !== undefined) payload.crisis_severity_index = updates.crisisSeverityIndex;

    const { data, error } = await supabase
      .from('claims')
      .update(payload)
      .eq('id', id)
      .eq('institution_id', institutionId)
      .select('*')
      .single();

    if (error) {
      throw new Error(`Failed to update claim ${id}: ${error.message}`);
    }

    return this.mapDBRowToClaim(data);
  }

  // ============================================================================
  // HEALTH FUNDS & RELIEF POOLS
  // ============================================================================

  static async getHealthFunds(institutionId: string): Promise<HealthFund[]> {
    const { data, error } = await supabase
      .from('health_funds')
      .select('*')
      .eq('institution_id', institutionId)
      .order('created_at', { ascending: true });

    if (error || !data) return [];
    return data.map((row: DBHealthFundRow) => ({
      id: row.id,
      institutionId: row.institution_id,
      name: row.name,
      category: row.category,
      totalAllocated: Number(row.total_allocated),
      totalDisbursed: Number(row.total_disbursed),
      currency: row.currency || 'INR',
      createdAt: row.created_at,
    }));
  }

  static async getHealthFundByCategory(category: string, institutionId: string): Promise<HealthFund | null> {
    const { data, error } = await supabase
      .from('health_funds')
      .select('*')
      .eq('institution_id', institutionId)
      .ilike('category', `%${category}%`)
      .maybeSingle();

    if (error || !data) return null;
    return {
      id: data.id,
      institutionId: data.institution_id,
      name: data.name,
      category: data.category,
      totalAllocated: Number(data.total_allocated),
      totalDisbursed: Number(data.total_disbursed),
      currency: data.currency || 'INR',
      createdAt: data.created_at,
    };
  }

  static async disburseHealthFund(fundId: string, amount: number): Promise<void> {
    // Increment total_disbursed in health_funds
    const { data: fund, error: fetchErr } = await supabase
      .from('health_funds')
      .select('total_disbursed')
      .eq('id', fundId)
      .single();

    if (fetchErr || !fund) {
      throw new Error(`Health fund not found: ${fundId}`);
    }

    const newDisbursed = Number(fund.total_disbursed || 0) + amount;
    const { error: updateErr } = await supabase
      .from('health_funds')
      .update({ total_disbursed: newDisbursed })
      .eq('id', fundId);

    if (updateErr) {
      throw new Error(`Failed to disburse from health fund: ${updateErr.message}`);
    }
  }

  // ============================================================================
  // CLAIM MESSAGES & CRISIS DIALOGUE
  // ============================================================================

  static async createClaimMessage(msg: {
    claimId: string;
    sender: 'PATIENT' | 'COUNSELOR_AI' | 'CLINICAL_ADMIN';
    message: string;
    isCrisisResponse?: boolean;
    suggestedResources?: Record<string, any>;
  }): Promise<ClaimMessage> {
    const { data, error } = await supabase
      .from('claim_messages')
      .insert([
        {
          claim_id: msg.claimId,
          sender: msg.sender,
          message: msg.message,
          is_crisis_response: msg.isCrisisResponse ?? false,
          suggested_resources: msg.suggestedResources || null,
        },
      ])
      .select('*')
      .single();

    if (error) {
      throw new Error(`Failed to insert claim message: ${error.message}`);
    }

    return {
      id: data.id,
      claimId: data.claim_id,
      sender: data.sender,
      message: data.message,
      isCrisisResponse: data.is_crisis_response,
      suggestedResources: data.suggested_resources,
      createdAt: data.created_at,
    };
  }

  static async getClaimMessages(claimId: string): Promise<ClaimMessage[]> {
    const { data, error } = await supabase
      .from('claim_messages')
      .select('*')
      .eq('claim_id', claimId)
      .order('created_at', { ascending: true });

    if (error || !data) return [];
    return data.map((row) => ({
      id: row.id,
      claimId: row.claim_id,
      sender: row.sender,
      message: row.message,
      isCrisisResponse: row.is_crisis_response,
      suggestedResources: row.suggested_resources,
      createdAt: row.created_at,
    }));
  }

  // ============================================================================
  // PATIENT ROSTER (WHITELISTING)
  // ============================================================================

  static async getPatientRoster(institutionId: string): Promise<PatientRoster[]> {
    const { data, error } = await supabase
      .from('patient_rosters')
      .select('*')
      .eq('institution_id', institutionId);

    if (error || !data) return [];
    return data.map((r) => ({
      id: r.id,
      institutionId: r.institution_id,
      patientId: r.patient_id,
      email: r.email,
      phone: r.phone,
      isRegistered: r.is_registered,
      createdAt: r.created_at,
    }));
  }

  // Helper mapper
  private static mapDBRowToClaim(row: DBClaimRow): Claim {
    return {
      id: row.id,
      institutionId: row.institution_id,
      patientId: row.patient_id,
      patientPhone: row.patient_phone,
      description: row.description,
      clinicalCategory: row.clinical_category,
      esiLevel: row.esi_level,
      crisisSeverityIndex: Number(row.crisis_severity_index || 0),
      isLifeSafetyAlert: Boolean(row.is_life_safety_alert),
      receiptUrl: row.receipt_url,
      receiptImageHash: row.receipt_image_hash,
      extractedBillAmount: row.extracted_bill_amount ? Number(row.extracted_bill_amount) : null,
      currency: row.currency || 'INR',
      recommendedCopayAmount: Number(row.recommended_copay_amount || 0),
      approvedAmount: Number(row.approved_amount || 0),
      fraudRiskScore: Number(row.fraud_risk_score || 0),
      fraudFlags: row.fraud_flags,
      status: row.status,
      clinicalNotes: row.clinical_notes,
      matchedPolicyId: row.matched_policy_id,
      payoutReference: row.payout_reference,
      payoutMethod: row.payout_method,
      createdAt: row.created_at,
      updatedAt: row.updated_at,
    };
  }
}
