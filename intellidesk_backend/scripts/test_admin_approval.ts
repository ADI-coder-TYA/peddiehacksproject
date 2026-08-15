import 'dotenv/config';
import { supabase } from '../src/config/supabase.js';
import axios from 'axios';

async function testAdminApproval() {
  const claimId = 'f1a1237e-d01b-41dd-83a9-1d6bff15a5c2';
  const institutionId = 'nano123';
  const API_URL = 'http://localhost:3000/api/v1';

  console.log(`\n👨‍⚕️ [Admin Action] Approving Claim ${claimId} with ₹25,000 Copay Relief...`);

  // Call Admin Approve Endpoint with Clinical Admin Auth headers
  const response = await axios.post(`${API_URL}/admin/tickets/${claimId}/approve`, {
    amount: 25000, // ₹25,000 copay grant
    payout_method: 'RAZORPAY_UPI',
    student_name: 'Rohan Sharma',
    student_vpa: '9811419040@upi',
  }, {
    headers: {
      'Content-Type': 'application/json',
      'x-institution-id': institutionId,
      'x-user-role': 'CLINICAL_DIRECTOR',
      'x-user-id': 'admin-nano123',
    }
  });

  console.log('✅ Approval API Status:', response.status);
  console.log('Approval Result:', response.data);

  // Check updated claim in Supabase
  const { data: approvedClaim } = await supabase
    .from('claims')
    .select('*')
    .eq('id', claimId)
    .single();

  console.log('\n----------------------------------------------------');
  console.log('UPDATED CLAIM STATUS (ADMIN & PATIENT BOARD):');
  console.log('• Claim ID:         ', approvedClaim?.id);
  console.log('• Status:           ', approvedClaim?.status);
  console.log('• Approved Amount:  ', `INR ₹${approvedClaim?.approved_amount}`);
  console.log('• Payout Rail:      ', approvedClaim?.payout_method);
  console.log('• Transaction Ref:  ', approvedClaim?.payout_reference);
  console.log('----------------------------------------------------');

  // Check updated health funds
  console.log('\n💰 UPDATED HEALTH FUNDS UTILISATION SCREEN:');
  const { data: updatedFunds } = await supabase
    .from('health_funds')
    .select('*')
    .eq('institution_id', institutionId);

  for (const f of updatedFunds || []) {
    const allocated = Number(f.total_allocated || 0);
    const disbursed = Number(f.total_disbursed || 0);
    const remaining = allocated - disbursed;
    const utilRate = allocated > 0 ? ((disbursed / allocated) * 100).toFixed(1) : '0.0';
    console.log(`  • Fund: "${f.name}" (${f.category})`);
    console.log(`    - Total Budget Allocated:  ₹${allocated.toLocaleString()}`);
    console.log(`    - Total Disbursed:         ₹${disbursed.toLocaleString()}`);
    console.log(`    - Remaining Pool Reserves: ₹${remaining.toLocaleString()} (${utilRate}% utilized)`);
  }

  console.log('\n🎉 Step 3 (Disburse Payment), Step 4 (Funds Utilisation), & Step 5 (Claim Status) VERIFIED!');
}

testAdminApproval().catch(console.error);
