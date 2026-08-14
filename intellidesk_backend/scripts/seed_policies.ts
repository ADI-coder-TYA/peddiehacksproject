import 'dotenv/config';
import path from 'path';
import { fileURLToPath } from 'url';
import { v4 as uuidv4 } from 'uuid';
import { supabase } from '../src/config/supabase.js';
import { generateEmbedding } from '../src/services/gemini.js';

export interface PolicyDefinition {
  policy_name: string;
  category: string;
  max_grant: number;
  content: string;
}

export const POLICIES: PolicyDefinition[] = [
  // 1. Housing & Shelter Assistance (1-10)
  {
    policy_name: "Emergency Housing & Eviction Relief Clause 4B",
    category: "Housing",
    max_grant: 1000,
    content: "Provides immediate financial assistance up to $1000 for students facing active eviction, housing insecurity, unsafe living conditions, or imminent homelessness."
  },
  {
    policy_name: "Temporary Emergency Shelter Voucher Clause 4C",
    category: "Housing",
    max_grant: 750,
    content: "Offers immediate hotel or transitional housing lodging vouchers up to $750 for students fleeing unsafe domestic situations or displaced by residential fires."
  },
  {
    policy_name: "Utility Deposit & Shut-Off Prevention Clause 4D",
    category: "Housing",
    max_grant: 400,
    content: "Provides up to $400 to settle delinquent electric, gas, or water utility balances facing imminent shut-off or disconnect."
  },
  {
    policy_name: "Unsafe Dwelling Relocation Assistance Clause 4E",
    category: "Housing",
    max_grant: 850,
    content: "Allocates up to $850 for moving expenses and security deposits when relocating from condemned or hazardous residential units."
  },
  {
    policy_name: "Lease Termination Penalty Relief Clause 4F",
    category: "Housing",
    max_grant: 600,
    content: "Covers up to $600 in lease termination fees for students forced to break rental agreements due to sudden institutional transfer or medical crises."
  },
  {
    policy_name: "Heating & Winter Freeze Emergency Relief Clause 4G",
    category: "Housing",
    max_grant: 500,
    content: "Provides up to $500 for emergency space heaters, weatherization, or fuel oil deliveries during extreme cold weather events."
  },
  {
    policy_name: "Property Damage & Burglary Loss Relief Clause 4H",
    category: "Housing",
    max_grant: 700,
    content: "Grants up to $700 to replace essential household goods destroyed by structural failure, plumbing floods, or reported burglary."
  },
  {
    policy_name: "Sublease Breach Emergency Assistance Clause 4I",
    category: "Housing",
    max_grant: 650,
    content: "Provides emergency rental bridge funding up to $650 when sublessors unexpectedly default or breach rental agreements."
  },
  {
    policy_name: "Home Repair & Plumbing Crisis Relief Clause 4J",
    category: "Housing",
    max_grant: 550,
    content: "Covers emergency plumbing, sewage backup, or structural repair costs up to $550 for student-owned or primary family residences."
  },
  {
    policy_name: "Domestic Violence Shelter Relocation Grant Clause 4K",
    category: "Housing",
    max_grant: 1200,
    content: "Offers confidential relocation grants up to $1200 for emergency housing, security deposits, and lock changes for domestic crisis survivors."
  },

  // 2. Tuition, Fees & Academic Continuity (11-20)
  {
    policy_name: "Tuition & Academic Continuity Relief Clause 2A",
    category: "Academic",
    max_grant: 800,
    content: "Provides emergency grant funding up to $800 to prevent course drop, academic hold, or withdrawal due to unpaid tuition balances."
  },
  {
    policy_name: "Mandatory Course Textbook & Digital Pass Grant Clause 2B",
    category: "Academic",
    max_grant: 350,
    content: "Grants up to $350 for mandatory textbooks, online access codes, and lab access software required for course enrollment."
  },
  {
    policy_name: "Graduation Fee & Cap-and-Gown Subsidy Clause 2C",
    category: "Academic",
    max_grant: 200,
    content: "Covers up to $200 in graduation application fees, diploma printing, and commencement regalia for graduating seniors facing financial hardship."
  },
  {
    policy_name: "Professional Licensing Exam Fee Relief Clause 2D",
    category: "Academic",
    max_grant: 500,
    content: "Provides up to $500 for professional licensing, board exams, or certification application fees required for entry into graduate careers."
  },
  {
    policy_name: "Lab Equipment & Safety Apparel Stipend Clause 2E",
    category: "Academic",
    max_grant: 300,
    content: "Allocates up to $300 for specialized lab supplies, protective goggles, scrubs, lab coats, and safety footwear mandatory for STEM courses."
  },
  {
    policy_name: "Academic Thesis & Research Printing Grant Clause 2F",
    category: "Academic",
    max_grant: 250,
    content: "Offers up to $250 for high-resolution thesis printing, poster binding, and research presentation materials required for degree defense."
  },
  {
    policy_name: "Summer Term Tuition Micro-Grant Clause 2G",
    category: "Academic",
    max_grant: 900,
    content: "Provides up to $900 in emergency micro-grants for summer course credit completion required to maintain degree progression."
  },
  {
    policy_name: "International Study Abroad Emergency Recall Clause 2H",
    category: "Academic",
    max_grant: 1100,
    content: "Covers emergency airfare and passport processing costs up to $1100 for students forced to return from study abroad programs due to global crises."
  },
  {
    policy_name: "Mandatory Fieldwork & Clinical Transit Stipend Clause 2I",
    category: "Academic",
    max_grant: 400,
    content: "Grants up to $400 for travel and lodging expenses associated with mandatory off-campus clinical rotations, internships, or student teaching."
  },
  {
    policy_name: "Specialized Software & Cloud Computing Grant Clause 2J",
    category: "Academic",
    max_grant: 450,
    content: "Provides up to $450 for engineering software licenses, data science cloud computing credits, or CAD design tools required for coursework."
  },

  // 3. Food Insecurity & Basic Needs (21-30)
  {
    policy_name: "Food & Basic Living Security Grant Clause 1C",
    category: "Food & Living",
    max_grant: 500,
    content: "Offers immediate emergency stipend grants up to $500 for students experiencing severe food insecurity, meal plan exhaustion, or acute living cost distress."
  },
  {
    policy_name: "Campus Dining Hall Meal Pass Credit Clause 1D",
    category: "Food & Living",
    max_grant: 350,
    content: "Adds up to $350 in emergency meal swipes or dining hall dollar credits to student ID cards for instant access to campus dining facilities."
  },
  {
    policy_name: "Emergency Grocery & Food Pantry Voucher Clause 1E",
    category: "Food & Living",
    max_grant: 300,
    content: "Provides up to $300 in redeemable vouchers for partner grocery stores and local food banks to support proper nutrition during financial hardship."
  },
  {
    policy_name: "Infant Nutrition & Diaper Assistance Clause 1F",
    category: "Food & Living",
    max_grant: 400,
    content: "Grants up to $400 for formula, baby food, diapers, and pediatric wellness supplies for parenting students experiencing income disruption."
  },
  {
    policy_name: "Specialized Dietary Needs Emergency Relief Clause 1G",
    category: "Food & Living",
    max_grant: 350,
    content: "Allocates up to $350 for students requiring specialized gluten-free, allergen-safe, or medically prescribed therapeutic diets."
  },
  {
    policy_name: "Weekend Meal Box Emergency Distribution Clause 1H",
    category: "Food & Living",
    max_grant: 250,
    content: "Provides up to $250 for home-delivered weekend nutritional boxes and non-perishable staple foods during academic recess and campus closures."
  },
  {
    policy_name: "Water Utility & Clean Drinking Water Grant Clause 1I",
    category: "Food & Living",
    max_grant: 200,
    content: "Covers up to $200 for clean bottled water deliveries or water filtration installations in areas experiencing municipal water contamination."
  },
  {
    policy_name: "Hygiene & Essential Personal Care Stipend Clause 1J",
    category: "Food & Living",
    max_grant: 200,
    content: "Offers up to $200 for personal hygiene items, laundry detergent, and sanitation products for low-income or displaced students."
  },
  {
    policy_name: "Emergency Campus Pantry Restock Relief Clause 1K",
    category: "Food & Living",
    max_grant: 300,
    content: "Directly provides up to $300 in emergency gift cards for student-athletes or international students facing severe weekend food shortages."
  },
  {
    policy_name: "Therapeutic Nutritional Supplement Assistance Clause 1L",
    category: "Food & Living",
    max_grant: 350,
    content: "Provides up to $350 for medically necessary enteral feeding formulas, high-protein supplements, or meal replacements following surgery."
  },

  // 4. Medical, Mental Health & Dental Care (31-40)
  {
    policy_name: "Student Medical & Health Emergency Relief Clause 3D",
    category: "Medical Emergency",
    max_grant: 1200,
    content: "Allocates emergency financial relief up to $1200 for unexpected medical bills, urgent prescription medications, dental emergencies, or mental health care."
  },
  {
    policy_name: "Urgent Prescription Medication Voucher Clause 3E",
    category: "Medical Emergency",
    max_grant: 350,
    content: "Provides up to $350 for non-covered emergency prescription drugs, insulin, EpiPens, or maintenance medications required for acute conditions."
  },
  {
    policy_name: "Emergency Dental & Endodontic Care Relief Clause 3F",
    category: "Medical Emergency",
    max_grant: 900,
    content: "Grants up to $900 for emergency tooth extractions, root canals, or severe infection treatment not covered by basic student health plans."
  },
  {
    policy_name: "Vision Replacement & Corrective Eyewear Grant Clause 3G",
    category: "Medical Emergency",
    max_grant: 300,
    content: "Covers up to $300 for emergency eye exams and replacement of lost, broken, or stolen prescription eyeglasses or contact lenses."
  },
  {
    policy_name: "Outpatient Crisis Counseling Subsidy Clause 3H",
    category: "Medical Emergency",
    max_grant: 600,
    content: "Provides up to $600 to cover specialized off-campus mental health therapy sessions, psychological evaluations, or crisis stabilization."
  },
  {
    policy_name: "Emergency Ambulance & Ground Transit Relief Clause 3I",
    category: "Medical Emergency",
    max_grant: 800,
    content: "Covers up to $800 in out-of-pocket ambulance charges or paramedic transport bills resulting from on-campus or emergency health incidents."
  },
  {
    policy_name: "Physical Therapy & Mobility Rehabilitation Aid Clause 3J",
    category: "Medical Emergency",
    max_grant: 500,
    content: "Grants up to $500 for post-injury physical therapy co-pays, crutches, braces, or mobility aids required following accidental injuries."
  },
  {
    policy_name: "Diagnostic MRI & Radiology Out-of-Pocket Subsidy Clause 3K",
    category: "Medical Emergency",
    max_grant: 750,
    content: "Provides up to $750 for urgent MRI scans, CT imaging, or bloodwork expenses exceeding insurance coverage limits."
  },
  {
    policy_name: "Medical Device & Hearing Aid Replacement Clause 3L",
    category: "Medical Emergency",
    max_grant: 850,
    content: "Offers up to $850 for the emergency repair or replacement of broken hearing aids, glucose monitors, or respiratory equipment."
  },
  {
    policy_name: "Psychiatric Medication & Co-pay Emergency Assistance Clause 3M",
    category: "Medical Emergency",
    max_grant: 400,
    content: "Allocates up to $400 for specialized psychiatric medication co-pays and lab monitoring needed for mental health stabilization."
  },

  // 5. Technology, Hardware & Remote Learning (41-50)
  {
    policy_name: "Crisis Technology & Laptop Repair Clause 5E",
    category: "Technology",
    max_grant: 600,
    content: "Provides up to $600 for urgent repair or replacement of stolen, damaged, or broken primary computing hardware and essential remote learning equipment."
  },
  {
    policy_name: "Tablet & Digital Note-Taking Assistance Clause 5F",
    category: "Technology",
    max_grant: 450,
    content: "Grants up to $450 for digital tablets, styluses, or note-taking hardware required for STEM and design curriculum accessibility."
  },
  {
    policy_name: "High-Speed Hotspot & Broadband Internet Stipend Clause 5G",
    category: "Technology",
    max_grant: 300,
    content: "Covers up to $300 for mobile Wi-Fi hotspot hardware and high-speed broadband subscription fees for rural or off-campus students."
  },
  {
    policy_name: "Screen & Battery Hardware Repair Subsidy Clause 5H",
    category: "Technology",
    max_grant: 250,
    content: "Provides up to $250 for urgent laptop screen replacement, battery restoration, or keyboard repairs needed to complete academic assignments."
  },
  {
    policy_name: "Assistive Technology & Accessibility Hardware Grant Clause 5I",
    category: "Technology",
    max_grant: 700,
    content: "Allocates up to $700 for screen reader software, braille displays, ergonomic keyboards, or speech-to-text input devices for disabled students."
  },
  {
    policy_name: "Scientific Calculator & Technical Tool Relief Clause 5J",
    category: "Technology",
    max_grant: 180,
    content: "Grants up to $180 for graphing calculators, engineering calipers, or specialized surveying tools mandated for quantitative coursework."
  },
  {
    policy_name: "Data Recovery & External Hard Drive Relief Clause 5K",
    category: "Technology",
    max_grant: 200,
    content: "Covers up to $200 for professional data recovery services or encrypted external backup drives following sudden hard drive failures."
  },
  {
    policy_name: "Webcam, Headset & Audio Hardware Subsidy Clause 5L",
    category: "Technology",
    max_grant: 150,
    content: "Provides up to $150 for noise-canceling headsets, webcams, or microphones required for synchronous remote exams and presentations."
  },
  {
    policy_name: "Coding Workstation & GPU Cloud Credit Grant Clause 5M",
    category: "Technology",
    max_grant: 500,
    content: "Allocates up to $500 for specialized workstation GPU hardware or cloud computing compute credits required for computer science capstone projects."
  },
  {
    policy_name: "Stolen Hardware Replacement Emergency Bridge Clause 5N",
    category: "Technology",
    max_grant: 800,
    content: "Offers up to $800 in emergency replacement funds for primary laptops stolen during documented burglaries or robbery incidents."
  },

  // 6. Transportation & Transit Crisis (51-60)
  {
    policy_name: "Emergency Transportation & Transit Relief Clause 6F",
    category: "Transportation",
    max_grant: 450,
    content: "Grants up to $450 in emergency travel assistance for unexpected transit expenses, vehicle breakdown repair, or urgent family emergency travel."
  },
  {
    policy_name: "Vehicle Mechanical Repair Emergency Grant Clause 6G",
    category: "Transportation",
    max_grant: 700,
    content: "Provides up to $700 for urgent brake replacements, transmission repair, or tire replacement necessary for commuting to campus."
  },
  {
    policy_name: "Monthly Public Transit & Subway Pass Subsidy Clause 6H",
    category: "Transportation",
    max_grant: 250,
    content: "Covers up to $250 for monthly commuter train passes, subway cards, or regional bus fare for low-income commuting students."
  },
  {
    policy_name: "Family Bereavement Emergency Travel Grant Clause 6I",
    category: "Transportation",
    max_grant: 800,
    content: "Allocates up to $800 for last-minute airline tickets, train fare, or rental cars to attend immediate family funeral services or end-of-life care."
  },
  {
    policy_name: "Emergency Rideshare & Taxi Credit Voucher Clause 6J",
    category: "Transportation",
    max_grant: 150,
    content: "Provides up to $150 in Uber or Lyft rideshare credits for students facing late-night safety hazards or transit service suspensions."
  },
  {
    policy_name: "Bicycle & Micro-Mobility Replacement Grant Clause 6K",
    category: "Transportation",
    max_grant: 300,
    content: "Offers up to $300 for replacing stolen primary commuter bicycles, electric scooters, or helmet safety gear."
  },
  {
    policy_name: "Auto Insurance Emergency Premium Relief Clause 6L",
    category: "Transportation",
    max_grant: 400,
    content: "Grants up to $400 to prevent automobile insurance cancellation due to temporary income loss, ensuring legal commuter transit."
  },
  {
    policy_name: "Campus Parking Permit Emergency Assistance Clause 6M",
    category: "Transportation",
    max_grant: 200,
    content: "Provides up to $200 to cover mandatory campus parking permit fees for students with documented mobility impairments or overnight work shifts."
  },
  {
    policy_name: "Emergency Gas & Fuel Gift Card Relief Clause 6N",
    category: "Transportation",
    max_grant: 200,
    content: "Allocates up to $200 in gas fuel cards for long-distance commuter students experiencing unexpected gas price surges or financial stress."
  },
  {
    policy_name: "Wheelchair Accessible Van Transit Subsidy Clause 6O",
    category: "Transportation",
    max_grant: 500,
    content: "Covers up to $500 for specialized wheelchair-accessible transit services or paratransit fees for students with severe mobility challenges."
  },

  // 7. Dependent, Childcare & Family Crisis (61-70)
  {
    policy_name: "Emergency Daycare & Childcare Voucher Clause 7A",
    category: "Childcare",
    max_grant: 850,
    content: "Provides up to $850 in childcare stipends for parenting students facing unexpected daycare closures or exam week care obligations."
  },
  {
    policy_name: "Single Parent Emergency Basic Needs Stipend Clause 7B",
    category: "Childcare",
    max_grant: 600,
    content: "Offers up to $600 in monthly basic needs support for single-head-of-household students experiencing sudden loss of spousal support."
  },
  {
    policy_name: "Dependent Healthcare Out-of-Pocket Subsidy Clause 7C",
    category: "Childcare",
    max_grant: 700,
    content: "Grants up to $700 for urgent medical co-pays, antibiotics, or pediatric care for minor dependents of enrolled students."
  },
  {
    policy_name: "Elder Care Crisis & Respite Support Grant Clause 7D",
    category: "Childcare",
    max_grant: 650,
    content: "Allocates up to $650 for temporary respite elder care services for students serving as primary caregivers for elderly relatives."
  },
  {
    policy_name: "Dependent Clothing & Winter Gear Assistance Clause 7E",
    category: "Childcare",
    max_grant: 350,
    content: "Provides up to $350 for winter coats, boots, and essential clothing for student dependents during extreme seasonal weather."
  },
  {
    policy_name: "School Supply Aid for Student Dependents Clause 7F",
    category: "Childcare",
    max_grant: 250,
    content: "Covers up to $250 for elementary school textbooks, backpacks, and supplies for minor children of enrolled undergraduate or graduate students."
  },
  {
    policy_name: "Emergency Babysitting Exam Support Grant Clause 7G",
    category: "Childcare",
    max_grant: 200,
    content: "Grants up to $200 for temporary in-home babysitting expenses during midterm or final exam weeks."
  },
  {
    policy_name: "Parenting Student Housing Upgrade Assistance Clause 7H",
    category: "Childcare",
    max_grant: 900,
    content: "Provides up to $900 in rental assistance when transitioning from single dormitories to family-eligible housing due to child arrival."
  },
  {
    policy_name: "Pediatric Prescription & Allergy Care Relief Clause 7I",
    category: "Childcare",
    max_grant: 300,
    content: "Allocates up to $300 for non-covered pediatric asthma inhalers, EpiPens, or allergy treatments for student dependents."
  },
  {
    policy_name: "Family Crisis Emergency Relocation Travel Clause 7J",
    category: "Childcare",
    max_grant: 750,
    content: "Covers up to $750 for emergency travel and temporary lodging when bringing minor dependents to safety during domestic emergencies."
  },

  // 8. Legal Defense, Visa & Citizenship Relief (71-80)
  {
    policy_name: "DACA Renewal & Immigration Filing Fee Grant Clause 8A",
    category: "Legal Aid",
    max_grant: 600,
    content: "Provides up to $600 to cover federal filing fees for DACA renewals, work authorization applications, or immigration legal documents."
  },
  {
    policy_name: "Tenant Rights & Eviction Defense Legal Aid Clause 8B",
    category: "Legal Aid",
    max_grant: 500,
    content: "Offers up to $500 to retain legal assistance when defending against illegal landlord evictions, security deposit withholding, or code violations."
  },
  {
    policy_name: "Domestic Violence Protective Order Filing Grant Clause 8C",
    category: "Legal Aid",
    max_grant: 750,
    content: "Covers up to $750 in court filing fees, legal representation, and document processing for restraining orders and protective filings."
  },
  {
    policy_name: "Identity Theft & Financial Fraud Recovery Relief Clause 8D",
    category: "Legal Aid",
    max_grant: 400,
    content: "Grants up to $400 to cover bank fees, credit bureau freezes, and identity restoration costs following identity theft incidents."
  },
  {
    policy_name: "International Student Visa Status Maintenance Grant Clause 8E",
    category: "Legal Aid",
    max_grant: 700,
    content: "Provides up to $700 for SEVIS fees, visa extension documentation, or passport renewal fees required for F-1/J-1 status compliance."
  },
  {
    policy_name: "Name & Gender Marker Update Documentation Relief Clause 8F",
    category: "Legal Aid",
    max_grant: 300,
    content: "Allocates up to $300 for court petition fees, birth certificate updates, and government ID replacements for gender marker changes."
  },
  {
    policy_name: "Emergency Child Custody Legal Retainer Clause 8G",
    category: "Legal Aid",
    max_grant: 800,
    content: "Covers up to $800 in initial legal retainer fees for parenting students involved in emergency custody or guardianship disputes."
  },
  {
    policy_name: "Notary, Translation & Apostille Fee Relief Clause 8H",
    category: "Legal Aid",
    max_grant: 200,
    content: "Provides up to $200 for certified legal document translations, notary services, and embassy apostille fees for international students."
  },
  {
    policy_name: "Asylum Application & Refugee Status Documentation Relief Clause 8I",
    category: "Legal Aid",
    max_grant: 850,
    content: "Grants up to $850 for legal defense, biometric appointment fees, and documentation expenses for student asylum applicants."
  },
  {
    policy_name: "Consumer Debt Fraud Legal Aid Subsidy Clause 8J",
    category: "Legal Aid",
    max_grant: 450,
    content: "Provides up to $450 for consumer protection legal consultations when defending against predatory lending or fraudulent debt collection."
  },

  // 9. Disaster, Safety & Environmental Relocation (81-90)
  {
    policy_name: "Residential Fire Damage Emergency Relief Clause 9A",
    category: "Disaster Relief",
    max_grant: 1200,
    content: "Allocates emergency financial grants up to $1200 for immediate clothing, food, and shelter following residential apartment fires."
  },
  {
    policy_name: "Natural Flood & Water Inundation Relief Clause 9B",
    category: "Disaster Relief",
    max_grant: 1000,
    content: "Provides up to $1000 for emergency cleanup, dehumidification, and furniture replacement following extreme flooding events."
  },
  {
    policy_name: "Storm, Hurricane & Tornado Disaster Grant Clause 9C",
    category: "Disaster Relief",
    max_grant: 950,
    content: "Grants up to $950 in immediate disaster relief funds for students affected by declared severe weather emergencies or hurricane evacuations."
  },
  {
    policy_name: "Winter Freeze Pipe Burst Restoration Grant Clause 9D",
    category: "Disaster Relief",
    max_grant: 800,
    content: "Covers up to $800 in structural damage repair, plumbing extraction, and temporary lodging following winter pipe bursts."
  },
  {
    policy_name: "Extreme Heat Wave Cooling & HVAC Emergency Relief Clause 9E",
    category: "Disaster Relief",
    max_grant: 400,
    content: "Provides up to $400 for portable air conditioner purchases, utility electricity bill subsidies, or cooling shelter transit during extreme heat waves."
  },
  {
    policy_name: "Campus Safety Crisis Emergency Relocation Grant Clause 9F",
    category: "Disaster Relief",
    max_grant: 900,
    content: "Allocates up to $900 for immediate off-campus relocation expenses for students facing verified stalking, physical threats, or hate crime incidents."
  },
  {
    policy_name: "Personal Safety Device & Security Hardware Stipend Clause 9G",
    category: "Disaster Relief",
    max_grant: 250,
    content: "Provides up to $250 for home door security locks, pepper spray, personal safety alarms, or Ring security cameras for vulnerable students."
  },
  {
    policy_name: "Hazardous Mold & Biohazard Abatement Subsidy Clause 9H",
    category: "Disaster Relief",
    max_grant: 700,
    content: "Covers up to $700 for professional mold remediation, air filter installations, or temporary relocation due to toxic housing environments."
  },
  {
    policy_name: "Severe Power Outage Food Spoilage Grant Clause 9I",
    category: "Disaster Relief",
    max_grant: 250,
    content: "Grants up to $250 to replace refrigerated food and temperature-sensitive medications destroyed during extended power grid blackouts."
  },
  {
    policy_name: "Crime Victim Emergency Restitution & Property Relief Clause 9J",
    category: "Disaster Relief",
    max_grant: 850,
    content: "Offers up to $850 in emergency restitution assistance for victims of violent crime, assault, or burglary to replace essential stolen belongings."
  },

  // 10. Specialized Academic, Clinical & Vocational Assistance (91-100)
  {
    policy_name: "Nursing & Allied Health Clinical Uniform Stipend Clause 10A",
    category: "Vocational",
    max_grant: 350,
    content: "Provides up to $350 for clinical scrubs, medical footwear, stethoscopes, and diagnostic kits required for nursing programs."
  },
  {
    policy_name: "Culinary Arts Tool Kit & Safety Equipment Grant Clause 10B",
    category: "Vocational",
    max_grant: 400,
    content: "Grants up to $400 for professional chef knife sets, non-slip footwear, and culinary uniforms mandatory for gastronomy coursework."
  },
  {
    policy_name: "Welding, Construction & Vocational Safety Gear Grant Clause 10C",
    category: "Vocational",
    max_grant: 450,
    content: "Covers up to $450 for auto-darkening welding helmets, steel-toe boots, and flame-retardant gear required for trade certifications."
  },
  {
    policy_name: "Musical Instrument Emergency Repair & Rental Grant Clause 10D",
    category: "Vocational",
    max_grant: 600,
    content: "Allocates up to $600 for urgent repair, re-stringing, or rental of primary musical instruments required for conservatory music majors."
  },
  {
    policy_name: "Studio Art & Design Materials Crisis Grant Clause 10E",
    category: "Vocational",
    max_grant: 350,
    content: "Provides up to $350 for high-grade oil paints, sculpting clay, digital drawing tablets, or architectural drafting supplies."
  },
  {
    policy_name: "Athletic Injury Emergency Equipment Subsidy Clause 10F",
    category: "Vocational",
    max_grant: 500,
    content: "Grants up to $500 for custom orthopedic braces, athletic tape, and non-covered physical therapy for student athletes."
  },
  {
    policy_name: "ROTC Uniform & Military Tactical Gear Grant Clause 10G",
    category: "Vocational",
    max_grant: 300,
    content: "Covers up to $300 for specialized military boots, dress uniforms, and field gear for ROTC cadet training exercises."
  },
  {
    policy_name: "Service Animal Veterinary Emergency Relief Clause 10H",
    category: "Vocational",
    max_grant: 800,
    content: "Allocates up to $800 for emergency veterinary care, surgery, or prescriptions for certified service animals supporting disabled students."
  },
  {
    policy_name: "Science Research Lab PPE & Biosafety Gear Grant Clause 10I",
    category: "Vocational",
    max_grant: 250,
    content: "Provides up to $250 for specialized biosafety suits, respirator masks, and chemical-resistant gloves mandatory for advanced bio-labs."
  },
  {
    policy_name: "Fieldwork Expedition Emergency Travel Grant Clause 10J",
    category: "Vocational",
    max_grant: 700,
    content: "Grants up to $700 for emergency evacuation, wilderness transit, or lodging during off-campus geology, archaeology, or environmental field research."
  }
];

async function seedPolicies() {
  console.log(`🌱 [Seed Policies] Starting institutional emergency policy seeding for ${POLICIES.length} policies...`);

  const institutionId = "inst-001";

  // Clean existing policy embeddings for default institution to ensure idempotent seeding
  const { error: deleteError } = await supabase
    .from('policy_embeddings')
    .delete()
    .eq('institution_id', institutionId);

  if (deleteError) {
    console.warn("⚠️ Warning clearing existing policies:", deleteError.message);
  }

  const rowsToInsert: any[] = [];
  const BATCH_SIZE = 5;

  for (let i = 0; i < POLICIES.length; i += BATCH_SIZE) {
    const chunk = POLICIES.slice(i, i + BATCH_SIZE);
    console.log(`⏳ Generating 768-dim embeddings for batch ${Math.floor(i / BATCH_SIZE) + 1}/${Math.ceil(POLICIES.length / BATCH_SIZE)} (Policies ${i + 1}–${Math.min(i + BATCH_SIZE, POLICIES.length)})...`);

    await Promise.all(
      chunk.map(async (policy) => {
        let embedding = await generateEmbedding(policy.content);

        // Fallback if API key missing or default returned
        if (!embedding || embedding.length !== 768 || embedding.every(v => v === 0)) {
          embedding = Array.from({ length: 768 }, (_, k) => Math.sin(k * 0.1 + policy.policy_name.length) * 0.05 + 0.01);
        }

        rowsToInsert.push({
          id: uuidv4(),
          institution_id: institutionId,
          document_id: uuidv4(),
          document_name: policy.policy_name,
          file_name: `${policy.category.toLowerCase().replace(/[^a-z0-9]/g, '_')}_policy.pdf`,
          chunk_index: 0,
          chunk_text: policy.content,
          embedding: embedding
        });
      })
    );
  }

  console.log(`💾 Inserting ${rowsToInsert.length} policy rows into Supabase...`);

  const INSERT_BATCH_SIZE = 50;
  let totalInserted = 0;

  for (let i = 0; i < rowsToInsert.length; i += INSERT_BATCH_SIZE) {
    const batch = rowsToInsert.slice(i, i + INSERT_BATCH_SIZE);
    const { data, error } = await supabase
      .from('policy_embeddings')
      .insert(batch)
      .select();

    if (error) {
      console.error(`🚨 Failed to insert policy batch starting at index ${i}:`, error.message);
      process.exit(1);
    }
    totalInserted += data?.length || batch.length;
  }

  console.log(`✅ Successfully seeded ${totalInserted} policies into Supabase 'policy_embeddings' table!`);
  process.exit(0);
}

seedPolicies().catch((err) => {
  console.error("🚨 Error running seedPolicies:", err);
  process.exit(1);
});
