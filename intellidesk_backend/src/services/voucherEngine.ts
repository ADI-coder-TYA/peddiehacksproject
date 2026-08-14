import { supabase } from '../config/supabase.js';
import { processRazorpayPayout, RazorpayPayoutMethod } from './disbursementService.js';

export interface ApproveTicketResult {
  success: boolean;
  ticketId: string;
  claimId: string;
  status: string;
  payoutMethod: string;
  transactionReference: string;
  voucherCode: string;
  voucherId: string | null;
  grantAmount: number;
  fundName: string;
  studentPhone: string;
}

/**
 * Claim Approval & Live Payout / Voucher Generation Handler
 */
export async function approveTicketAndIssueVoucher(
  claimId: string,
  institutionId?: string,
  customAmount?: number,
  payoutMethod?: RazorpayPayoutMethod,
  patientDetails?: {
    studentName?: string;
    studentVpa?: string;
    accountNumber?: string;
    ifscCode?: string;
  }
): Promise<ApproveTicketResult> {
  // 1. Fetch claim details from claims table
  const { data: claim, error: fetchError } = await supabase
    .from('claims')
    .select('*')
    .eq('id', claimId)
    .maybeSingle();

  if (fetchError || !claim) {
    throw new Error(`Claim ${claimId} not found.`);
  }

  const instId = institutionId || claim.institution_id || 'inst-001';
  const grantAmount = (customAmount && Number(customAmount) > 0)
    ? Number(customAmount)
    : (Number(claim.recommended_copay_amount) > 0
        ? Number(claim.recommended_copay_amount)
        : (Number(claim.extracted_bill_amount) > 0 ? Number(claim.extracted_bill_amount) : 500));
  const rawCat = (claim.clinical_category || 'Medical Emergency & Inpatient Care').trim();
  const chosenMethod: RazorpayPayoutMethod = payoutMethod || 'RAZORPAY_UPI';

  // Step A: Process Live Disbursement via RazorpayX Payouts or Digital Voucher
  const payoutReceipt = await processRazorpayPayout({
    ticketId: claim.id,
    institutionId: instId,
    amount: grantAmount,
    payoutMethod: chosenMethod,
    studentPhone: claim.patient_phone,
    studentName: patientDetails?.studentName,
    studentVpa: patientDetails?.studentVpa,
    accountNumber: patientDetails?.accountNumber,
    ifscCode: patientDetails?.ifscCode,
  });

  // Step B: Find matching Health Fund and deduct budget
  const { data: allFunds } = await supabase
    .from('health_funds')
    .select('*')
    .eq('institution_id', instId);

  let matchedFund = (allFunds || []).find((f: any) =>
    f.category.toLowerCase().includes(rawCat.toLowerCase()) ||
    rawCat.toLowerCase().includes(f.category.toLowerCase())
  ) || (allFunds && allFunds.length > 0 ? allFunds[0] : null);

  let fundNameUsed = matchedFund ? matchedFund.name : "Emergency Copay Relief Fund";

  if (matchedFund) {
    fundNameUsed = matchedFund.name;
    const currentDisbursed = Number(matchedFund.total_disbursed || 0);
    const newDisbursed = currentDisbursed + Number(grantAmount);

    const { error: fundUpdateError } = await supabase
      .from('health_funds')
      .update({ total_disbursed: newDisbursed })
      .eq('id', matchedFund.id);

    if (fundUpdateError) {
      console.warn(`⚠️ [Voucher Engine] Warning updating health fund: ${fundUpdateError.message}`);
    } else {
      console.log(`💰 [Voucher Engine] Disbursed ₹${grantAmount} from "${fundNameUsed}". Total Disbursed: ₹${newDisbursed}`);
    }
  }

  // Step C: Persist voucher if generated
  let voucherId: string | null = null;
  const voucherCode = payoutReceipt.voucherCode || `MED-VCH-${Date.now().toString(36).toUpperCase()}`;
  try {
    const { data: vchData } = await supabase
      .from('vouchers')
      .insert({
        claim_id: claim.id,
        patient_phone: claim.patient_phone,
        voucher_code: voucherCode,
        vendor_name: 'MedAccess Clinical Network Partner',
        amount: grantAmount,
        currency: claim.currency || 'INR',
        status: 'ISSUED',
      })
      .select()
      .maybeSingle();

    if (vchData) voucherId = vchData.id;
  } catch (_) {}

  // Step D: Update Claim status
  const claimUpdatePayload: Record<string, any> = {
    status: 'Approved',
    approved_amount: grantAmount,
    recommended_copay_amount: grantAmount,
    payout_reference: payoutReceipt.transactionReference,
    payout_method: payoutReceipt.disbursementMethod,
    updated_at: new Date().toISOString(),
  };

  const { error: claimUpdateError } = await supabase
    .from('claims')
    .update(claimUpdatePayload)
    .eq('id', claim.id);

  if (claimUpdateError) {
    console.error(`🚨 [Voucher Engine] Error updating claim status: ${claimUpdateError.message}`);
  }

  return {
    success: true,
    ticketId: claim.id,
    claimId: claim.id,
    status: 'Approved',
    payoutMethod: payoutReceipt.disbursementMethod,
    transactionReference: payoutReceipt.transactionReference,
    voucherCode,
    voucherId,
    grantAmount,
    fundName: fundNameUsed,
    studentPhone: claim.patient_phone,
  };
}
