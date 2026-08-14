import 'dotenv/config';
import { processRazorpayPayout } from '../src/services/disbursementService.js';
import { v4 as uuidv4 } from 'uuid';

async function runDisbursementTests() {
  console.log('🧪 Testing RazorpayX Payouts & Voucher Integration...\n');

  // Test 1: Razorpay UPI
  console.log('--- Test 1: RAZORPAY_UPI ---');
  const upiReceipt = await processRazorpayPayout({
    ticketId: uuidv4(),
    institutionId: 'edu-admin-123',
    amount: 750,
    payoutMethod: 'RAZORPAY_UPI',
    studentVpa: 'student@upi',
    studentName: 'Alex Student'
  });
  console.log('UPI Receipt:', upiReceipt);
  if (!upiReceipt.success || !upiReceipt.transactionReference.startsWith('pout_')) {
    throw new Error('UPI Payout Test Failed');
  }

  // Test 2: Razorpay Bank Transfer (IMPS)
  console.log('\n--- Test 2: RAZORPAY_BANK ---');
  const bankReceipt = await processRazorpayPayout({
    ticketId: uuidv4(),
    institutionId: 'edu-admin-123',
    amount: 1200,
    payoutMethod: 'RAZORPAY_BANK',
    accountNumber: '918273645019',
    ifscCode: 'SBIN0001234',
    studentName: 'Jordan Student'
  });
  console.log('Bank Receipt:', bankReceipt);
  if (!bankReceipt.success || !bankReceipt.transactionReference.startsWith('pout_')) {
    throw new Error('Bank Payout Test Failed');
  }

  // Test 3: Digital Voucher
  console.log('\n--- Test 3: VOUCHER ---');
  const voucherReceipt = await processRazorpayPayout({
    ticketId: uuidv4(),
    institutionId: 'edu-admin-123',
    amount: 300,
    payoutMethod: 'VOUCHER'
  });
  console.log('Voucher Receipt:', voucherReceipt);
  if (!voucherReceipt.success || !voucherReceipt.voucherCode?.startsWith('EDU-GRANT-')) {
    throw new Error('Voucher Test Failed');
  }

  console.log('\n✅ All Disbursement Rail tests passed successfully!');
}

runDisbursementTests().catch((err) => {
  console.error('❌ Test failed:', err);
  process.exit(1);
});
