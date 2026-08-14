export type UserClinicalRole = 'PATIENT' | 'STUDENT' | 'CLINICAL_ADMIN' | 'AUDITOR';

export type EsiLevel = 'ESI_1_CRITICAL' | 'ESI_2_EMERGENT' | 'ESI_3_URGENT' | 'ROUTINE';

export type ClaimStatus = 'Submitted' | 'Triage Active' | 'Approved' | 'Disbursed' | 'Flagged' | 'Rejected';

export type ClaimMessageSender = 'PATIENT' | 'COUNSELOR_AI' | 'CLINICAL_ADMIN';

export interface Institution {
  id: string;
  name: string;
  domain?: string | null;
  default_currency?: string;
  createdAt?: string;
}

export interface PatientProfile {
  id: string;
  email: string;
  fullName?: string | null;
  phone?: string | null;
  role: UserClinicalRole;
  institutionId?: string | null;
  emergencyContact?: string | null;
  preferredChannel?: 'SMS' | 'Email' | 'WhatsApp' | string;
  alertsEnabled?: boolean;
  createdAt?: string;
  updatedAt?: string;
}

export interface PatientRoster {
  id: string;
  institutionId: string;
  patientId: string;
  email?: string | null;
  phone?: string | null;
  isRegistered: boolean;
  createdAt?: string;
}

export interface HealthFund {
  id: string;
  institutionId: string;
  name: string;
  category: string;
  totalAllocated: number;
  totalDisbursed: number;
  currency: string;
  createdAt?: string;
}

export interface Claim {
  id: string;
  institutionId?: string;
  patientId?: string | null;
  patientPhone: string;
  description: string;
  clinicalCategory: string;
  esiLevel: EsiLevel;
  crisisSeverityIndex: number;
  isLifeSafetyAlert: boolean;
  receiptUrl?: string | null;
  receiptImageHash?: string | null;
  extractedBillAmount?: number | null;
  currency: string;
  recommendedCopayAmount: number;
  approvedAmount: number;
  fraudRiskScore: number;
  fraudFlags?: string | null;
  status: ClaimStatus;
  clinicalNotes?: string | null;
  matchedPolicyId?: string | null;
  payoutReference?: string | null;
  payoutMethod?: string | null;
  createdAt?: string;
  updatedAt?: string;
}

export interface ClaimMessage {
  id: string;
  claimId: string;
  sender: ClaimMessageSender;
  message: string;
  isCrisisResponse: boolean;
  suggestedResources?: Record<string, any> | null;
  createdAt?: string;
}

// Database schema snake_case representation
export interface DBClaimRow {
  id: string;
  institution_id: string;
  patient_id?: string | null;
  patient_phone: string;
  description: string;
  clinical_category: string;
  esi_level: EsiLevel;
  crisis_severity_index: number;
  is_life_safety_alert: boolean;
  receipt_url?: string | null;
  receipt_image_hash?: string | null;
  extracted_bill_amount?: number | null;
  currency: string;
  recommended_copay_amount: number;
  approved_amount: number;
  fraud_risk_score: number;
  fraud_flags?: string | null;
  status: ClaimStatus;
  clinical_notes?: string | null;
  matched_policy_id?: string | null;
  payout_reference?: string | null;
  payout_method?: string | null;
  created_at: string;
  updated_at: string;
}

export interface DBHealthFundRow {
  id: string;
  institution_id: string;
  name: string;
  category: string;
  total_allocated: number;
  total_disbursed: number;
  currency: string;
  created_at: string;
}
