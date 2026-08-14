import 'dotenv/config';
import { supabase } from '../src/config/supabase.js';
import { approveTicketAndIssueVoucher } from '../src/services/voucherEngine.js';
import { v4 as uuidv4 } from 'uuid';

async function testApproval() {
  console.log("\n🧪 Testing End-to-End Fund Deduction and Voucher Engine Approval...\n");

  const instId = "edu-admin-123";

  // Create a test ticket for Medical bills
  const ticketId = uuidv4();
  const studentPhone = "+15550192834";
  const { data: ticket, error: insertError } = await supabase
    .from('tickets')
    .insert({
      id: ticketId,
      institution_id: instId,
      student_phone: studentPhone,
      raw_message: "Need emergency grant for hospital medical bills and cancer prescription treatment.",
      parsed_category: "Medical",
      urgency_level: "High",
      status: "Pending",
      calculated_amount: 750,
      recommended_grant_amount: 750
    })
    .select()
    .single();

  if (insertError) {
    console.error("🚨 Error creating test ticket:", insertError.message);
    process.exit(1);
  }

  console.log(`Created test ticket ${ticketId} with category "${ticket.parsed_category}" for $${ticket.recommended_grant_amount}`);

  // Execute approval
  const result = await approveTicketAndIssueVoucher(ticketId, instId, 750);

  console.log(`\n🎉 Test Approval Completed!`);
  console.log(`   ➔ Status: ${result.status}`);
  console.log(`   ➔ Voucher Code: ${result.voucherCode}`);
  console.log(`   ➔ Voucher ID: ${result.voucherId}`);
  console.log(`   ➔ Fund Name Matched: ${result.fundName}`);
  console.log(`   ➔ Amount Approved: $${result.grantAmount}`);
  console.log(`   ➔ Student Phone: ${result.studentPhone}\n`);

  // Verify voucher row in database
  const { data: voucher } = await supabase
    .from('vouchers')
    .select('*')
    .eq('ticket_id', ticketId)
    .single();

  if (voucher) {
    console.log(`✅ Verified Voucher Row in Supabase Database:`, voucher);
  }

  process.exit(0);
}

testApproval().catch((err) => {
  console.error("🚨 Error running approval test:", err);
  process.exit(1);
});
