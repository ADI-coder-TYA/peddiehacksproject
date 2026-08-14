import { supabase } from '../config/supabase.js';
import { processRazorpayPayout, RazorpayPayoutMethod } from './disbursementService.js';

export interface ApproveTicketResult {
  success: boolean;
  ticketId: string;
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
 * Ticket Approval & Live Payout / Voucher Generation Handler
 * 
 * Step A: Execute processRazorpayPayout for chosen rail ('RAZORPAY_UPI', 'RAZORPAY_BANK', or 'VOUCHER').
 * Step B: Find matching Fund based on ticket category and deduct grant amount (allocated_amount += grantAmount).
 * Step C: Set ticket status to 'Approved', store payout_reference, payout_method, and update resolved_at.
 */
export async function approveTicketAndIssueVoucher(
  ticketId: string,
  institutionId?: string,
  customAmount?: number,
  payoutMethod?: RazorpayPayoutMethod,
  studentDetails?: {
    studentName?: string;
    studentVpa?: string;
    accountNumber?: string;
    ifscCode?: string;
  }
): Promise<ApproveTicketResult> {
  // Fetch ticket details
  const { data: ticket, error: fetchError } = await supabase
    .from('tickets')
    .select('*')
    .eq('id', ticketId)
    .single();

  if (fetchError || !ticket) {
    throw new Error(`Ticket ${ticketId} not found.`);
  }

  const instId = institutionId || ticket.institution_id || 'edu-admin-123';
  const grantAmount = (customAmount && Number(customAmount) > 0)
    ? Number(customAmount)
    : (Number(ticket.calculated_amount) > 0
        ? Number(ticket.calculated_amount)
        : (Number(ticket.recommended_grant_amount) > 0 ? Number(ticket.recommended_grant_amount) : 500));
  const rawCat = (ticket.parsed_category || 'General').trim();
  const chosenMethod: RazorpayPayoutMethod = payoutMethod || 'RAZORPAY_UPI';

  // Step A: Process Live Disbursement via RazorpayX Payouts or Digital Voucher
  const payoutReceipt = await processRazorpayPayout({
    ticketId: ticket.id,
    institutionId: instId,
    amount: grantAmount,
    payoutMethod: chosenMethod,
    studentPhone: ticket.student_phone,
    studentName: studentDetails?.studentName,
    studentVpa: studentDetails?.studentVpa,
    accountNumber: studentDetails?.accountNumber,
    ifscCode: studentDetails?.ifscCode,
  });

  // Step B: Find candidate Fund for institution matching category & deduct budget
  const { data: allFunds } = await supabase
    .from('funds')
    .select('*')
    .eq('institution_id', instId);

  let candidateFunds = (allFunds || []).filter(f => {
    const fn = f.fund_name.toLowerCase();
    const c = rawCat.toLowerCase();
    if (c === 'housing' && (fn.includes('housing') || fn.includes('shelter') || fn.includes('utility'))) return true;
    if (c === 'academic' && (fn.includes('academic') || fn.includes('tuition') || fn.includes('textbook') || fn.includes('graduation'))) return true;
    if (c === 'medical' && (fn.includes('medical') || fn.includes('hospital') || fn.includes('prescription') || fn.includes('dental'))) return true;
    if (c === 'mental health' && (fn.includes('counseling') || fn.includes('therapy') || fn.includes('psychiatric') || fn.includes('mental'))) return true;
    if (c === 'food & living' && (fn.includes('food') || fn.includes('meal') || fn.includes('grocery') || fn.includes('living'))) return true;
    if (c === 'technology' && (fn.includes('laptop') || fn.includes('broadband') || fn.includes('technology') || fn.includes('hardware'))) return true;
    if (c === 'transportation' && (fn.includes('transit') || fn.includes('vehicle') || fn.includes('travel') || fn.includes('commuter'))) return true;
    if (c === 'childcare' && (fn.includes('daycare') || fn.includes('parenting') || fn.includes('dependent') || fn.includes('child'))) return true;
    if (c === 'legal aid' && (fn.includes('visa') || fn.includes('legal') || fn.includes('eviction defense') || fn.includes('daca'))) return true;
    if (c === 'disaster relief' && (fn.includes('fire') || fn.includes('disaster') || fn.includes('weather') || fn.includes('storm'))) return true;
    return false;
  });

  if (candidateFunds.length === 0) {
    candidateFunds = allFunds || [];
  }

  // Sort candidate funds by highest remaining budget
  candidateFunds.sort((a, b) => {
    const remA = Number(a.total_budget || 0) - Number(a.allocated_amount || 0);
    const remB = Number(b.total_budget || 0) - Number(b.allocated_amount || 0);
    return remB - remA;
  });

  const matchedFund = candidateFunds[0] || null;
  let fundNameUsed = matchedFund ? matchedFund.fund_name : "General Student Hardship Fund";

  if (matchedFund) {
    fundNameUsed = matchedFund.fund_name;
    const currentAllocated = Number(matchedFund.allocated_amount || 0);
    const newAllocated = currentAllocated + Number(grantAmount);

    const { error: fundUpdateError } = await supabase
      .from('funds')
      .update({ allocated_amount: newAllocated })
      .eq('id', matchedFund.id);

    if (fundUpdateError) {
      console.warn(`⚠️ [Voucher Engine] Warning updating fund budget: ${fundUpdateError.message}`);
    } else {
      console.log(`💰 [Voucher Engine] Deducted $${grantAmount} from "${fundNameUsed}". New Allocated Total: $${newAllocated}`);
    }
  }

  // Step C: Set ticket status to 'Approved', store payout_reference & payout_method, and update resolved_at
  const ticketUpdatePayload: Record<string, any> = {
    status: 'Approved',
    calculated_amount: grantAmount,
    recommended_grant_amount: grantAmount,
    payout_reference: payoutReceipt.transactionReference,
    payout_method: payoutReceipt.disbursementMethod,
    resolved_at: payoutReceipt.timestamp
  };

  let { error: ticketUpdateError } = await supabase
    .from('tickets')
    .update(ticketUpdatePayload)
    .eq('id', ticket.id);

  if (ticketUpdateError && (ticketUpdateError.message.includes('payout_method') || ticketUpdateError.message.includes('payout_reference') || ticketUpdateError.message.includes('schema cache'))) {
    console.warn(`⚠️ [Voucher Engine] Missing 'payout_method' / 'payout_reference' in Supabase schema cache. Retrying update with base columns.`);
    delete ticketUpdatePayload.payout_method;
    delete ticketUpdatePayload.payout_reference;
    const retryRes = await supabase
      .from('tickets')
      .update(ticketUpdatePayload)
      .eq('id', ticket.id);
    ticketUpdateError = retryRes.error;
  }

  if (ticketUpdateError) {
    console.error(`🚨 [Voucher Engine] Error updating ticket status to Approved: ${ticketUpdateError.message}`);
  }

  return {
    success: true,
    ticketId: ticket.id,
    status: 'Approved',
    payoutMethod: payoutReceipt.disbursementMethod,
    transactionReference: payoutReceipt.transactionReference,
    voucherCode: payoutReceipt.voucherCode || payoutReceipt.transactionReference,
    voucherId: payoutReceipt.voucherId || null,
    grantAmount,
    fundName: fundNameUsed,
    studentPhone: ticket.student_phone
  };
}
