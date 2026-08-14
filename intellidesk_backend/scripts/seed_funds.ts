import 'dotenv/config';
import { v4 as uuidv4 } from 'uuid';
import { supabase } from '../src/config/supabase.js';

export interface FundDefinition {
  fund_name: string;
  category: string;
  total_budget: number;
  allocated_amount: number;
  institution_id: string;
}

export const CATEGORY_FUNDS: FundDefinition[] = [
  // 1. Housing (3 funds)
  { fund_name: "Emergency Housing & Eviction Relief Pool", category: "Housing", total_budget: 25000, allocated_amount: 0, institution_id: "edu-admin-123" },
  { fund_name: "Temporary Shelter & Lodging Emergency Fund", category: "Housing", total_budget: 18000, allocated_amount: 0, institution_id: "edu-admin-123" },
  { fund_name: "Utility Deposit & Shut-Off Prevention Pool", category: "Housing", total_budget: 12000, allocated_amount: 0, institution_id: "edu-admin-123" },

  // 2. Academic (3 funds)
  { fund_name: "Academic & Tuition Emergency Grant", category: "Academic", total_budget: 15000, allocated_amount: 0, institution_id: "edu-admin-123" },
  { fund_name: "Textbook, Lab & Digital Pass Access Fund", category: "Academic", total_budget: 10000, allocated_amount: 0, institution_id: "edu-admin-123" },
  { fund_name: "Graduation & Licensing Board Exam Subsidy", category: "Academic", total_budget: 8000, allocated_amount: 0, institution_id: "edu-admin-123" },

  // 3. Medical (3 funds)
  { fund_name: "Emergency Medical & Hospital Bill Relief Pool", category: "Medical", total_budget: 30000, allocated_amount: 0, institution_id: "edu-admin-123" },
  { fund_name: "Prescription Medication & Pharmacy Access Fund", category: "Medical", total_budget: 12000, allocated_amount: 0, institution_id: "edu-admin-123" },
  { fund_name: "Urgent Dental & Endodontic Care Relief Pool", category: "Medical", total_budget: 15000, allocated_amount: 0, institution_id: "edu-admin-123" },

  // 4. Mental Health (3 funds)
  { fund_name: "Student Crisis Counseling & Therapy Subsidy Fund", category: "Mental Health", total_budget: 14000, allocated_amount: 0, institution_id: "edu-admin-123" },
  { fund_name: "Psychiatric Care & Outpatient Support Pool", category: "Mental Health", total_budget: 10000, allocated_amount: 0, institution_id: "edu-admin-123" },
  { fund_name: "Mental Health Emergency Stabilization Fund", category: "Mental Health", total_budget: 9000, allocated_amount: 0, institution_id: "edu-admin-123" },

  // 5. Food & Living (3 funds)
  { fund_name: "Food Insecurity & Basic Living Security Grant", category: "Food & Living", total_budget: 15000, allocated_amount: 0, institution_id: "edu-admin-123" },
  { fund_name: "Campus Meal Swipe & Dining Credit Pool", category: "Food & Living", total_budget: 10000, allocated_amount: 0, institution_id: "edu-admin-123" },
  { fund_name: "Emergency Grocery & Food Pantry Voucher Fund", category: "Food & Living", total_budget: 8000, allocated_amount: 0, institution_id: "edu-admin-123" },

  // 6. Technology (3 funds)
  { fund_name: "Laptop Replacement & Hardware Repair Pool", category: "Technology", total_budget: 16000, allocated_amount: 0, institution_id: "edu-admin-123" },
  { fund_name: "Broadband Internet & Mobile Hotspot Grant", category: "Technology", total_budget: 9000, allocated_amount: 0, institution_id: "edu-admin-123" },
  { fund_name: "Assistive Technology & Accessibility Hardware Fund", category: "Technology", total_budget: 11000, allocated_amount: 0, institution_id: "edu-admin-123" },

  // 7. Transportation (3 funds)
  { fund_name: "Emergency Transit & Vehicle Repair Pool", category: "Transportation", total_budget: 12000, allocated_amount: 0, institution_id: "edu-admin-123" },
  { fund_name: "Public Transit Pass & Commuter Fare Fund", category: "Transportation", total_budget: 7000, allocated_amount: 0, institution_id: "edu-admin-123" },
  { fund_name: "Family Bereavement & Emergency Travel Grant", category: "Transportation", total_budget: 10000, allocated_amount: 0, institution_id: "edu-admin-123" },

  // 8. Childcare (3 funds)
  { fund_name: "Parenting Student Daycare Voucher Pool", category: "Childcare", total_budget: 18000, allocated_amount: 0, institution_id: "edu-admin-123" },
  { fund_name: "Single Parent Basic Needs Support Fund", category: "Childcare", total_budget: 12000, allocated_amount: 0, institution_id: "edu-admin-123" },
  { fund_name: "Dependent Healthcare Out-of-Pocket Pool", category: "Childcare", total_budget: 9000, allocated_amount: 0, institution_id: "edu-admin-123" },

  // 9. Legal Aid (3 funds)
  { fund_name: "DACA & International Student Visa Fee Relief Pool", category: "Legal Aid", total_budget: 15000, allocated_amount: 0, institution_id: "edu-admin-123" },
  { fund_name: "Tenant Rights & Eviction Defense Legal Aid Fund", category: "Legal Aid", total_budget: 11000, allocated_amount: 0, institution_id: "edu-admin-123" },
  { fund_name: "Domestic Violence Protective Order Filing Pool", category: "Legal Aid", total_budget: 13000, allocated_amount: 0, institution_id: "edu-admin-123" },

  // 10. Disaster Relief (3 funds)
  { fund_name: "Residential Fire & Flood Emergency Relief Pool", category: "Disaster Relief", total_budget: 25000, allocated_amount: 0, institution_id: "edu-admin-123" },
  { fund_name: "Storm & Extreme Weather Evacuation Relief Fund", category: "Disaster Relief", total_budget: 18000, allocated_amount: 0, institution_id: "edu-admin-123" },
  { fund_name: "Campus Safety Relocation & Emergency Security Grant", category: "Disaster Relief", total_budget: 14000, allocated_amount: 0, institution_id: "edu-admin-123" },

  // 11. Financial & General (3 funds)
  { fund_name: "General Student Hardship Fund", category: "Financial", total_budget: 10000, allocated_amount: 0, institution_id: "edu-admin-123" },
  { fund_name: "Institutional Micro-Grant Emergency Bridge Pool", category: "Financial", total_budget: 15000, allocated_amount: 0, institution_id: "edu-admin-123" },
  { fund_name: "Dean's Emergency Relief Fund", category: "Financial", total_budget: 20000, allocated_amount: 0, institution_id: "edu-admin-123" }
];

async function seedFunds() {
  console.log(`💰 [Seed Funds] Starting fund pool seeding (${CATEGORY_FUNDS.length} total funds across categories)...`);

  const institutions = ["edu-admin-123", "inst-001", "default"];

  for (const instId of institutions) {
    const { error: deleteError } = await supabase
      .from('funds')
      .delete()
      .eq('institution_id', instId);

    if (deleteError) {
      console.warn(`⚠️ Warning clearing existing funds for ${instId}:`, deleteError.message);
    }

    const rowsToInsert = CATEGORY_FUNDS.map(fund => ({
      id: uuidv4(),
      institution_id: instId,
      fund_name: fund.fund_name,
      total_budget: fund.total_budget,
      allocated_amount: fund.allocated_amount
    }));

    const { data, error } = await supabase
      .from('funds')
      .insert(rowsToInsert)
      .select();

    if (error) {
      console.error(`🚨 Error seeding funds for institution "${instId}":`, error.message);
    } else {
      console.log(`✅ Seeded ${data?.length || rowsToInsert.length} fund pools (3 per category) for institution "${instId}"!`);
    }
  }

  console.log("🎉 Fund pool seeding completed successfully!");
  process.exit(0);
}

seedFunds().catch((err) => {
  console.error("🚨 Error running seedFunds:", err);
  process.exit(1);
});
