import fs from 'fs';
import path from 'path';
import PDFDocument from 'pdfkit';

const outputDirs = [
  path.resolve(process.cwd(), 'sample_policies'),
  path.resolve(process.cwd(), '..', 'sample_policies'),
];

outputDirs.forEach(dir => {
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
});

interface PolicyDoc {
  filename: string;
  title: string;
  code: string;
  category: string;
  maxLimit: string;
  effectiveDate: string;
  sections: { heading: string; body: string }[];
}

const policies: PolicyDoc[] = [
  {
    filename: 'Emergency_Trauma_Coverage_Policy_2026.pdf',
    title: 'Emergency & Acute Inpatient Trauma Relief Policy',
    code: 'POL-EMRG-2026-V1',
    category: 'Medical Emergency & Inpatient Care',
    maxLimit: 'INR 2,50,000 per incident',
    effectiveDate: 'January 1, 2026',
    sections: [
      {
        heading: '1. Policy Scope & Purpose',
        body: 'This institutional policy provides immediate copay assistance and full financial relief for acute medical emergencies, polytrauma, Intensive Care Unit (ICU) admissions, and urgent surgical interventions. It is designed to ensure no student or registered patient suffers delayed acute clinical triage due to out-of-pocket payment constraints.'
      },
      {
        heading: '2. Eligibility Criteria & Triage Severity',
        body: 'All registered students, staff members, and enrolled hospital patients classified under Emergency Severity Index (ESI) Levels 1 (Resuscitation) and 2 (Emergent) qualify for 100% immediate copay grant approval. ESI Level 3 (Urgent) admissions qualify for up to 85% relief subject to institutional bed availability.'
      },
      {
        heading: '3. Covered Services & Expense Categories',
        body: '- Emergency Department triage, resuscitation, and monitoring.\n- ICU / CCU inpatient room charges, ventilator management, and life-support systems.\n- Emergency surgical procedures, orthopedic trauma reductions, and trauma anesthesia.\n- Blood transfusions, plasma expanders, and emergency intravenous medications.\n- Emergency ambulance transport and paramedic inter-facility transfers.'
      },
      {
        heading: '4. Benefit Maximums & Disbursement Protocol',
        body: 'The maximum assistance payable under this policy is INR 2,50,000 per emergency incident. Claims processed via MedAccess AI with valid hospital admission receipts, clinical triage records, and discharge summaries are auto-disbursed directly to the healthcare provider or reimbursed to the patient within 15 minutes.'
      },
      {
        heading: '5. Exclusions & Limitations',
        body: 'Elective cosmetic surgeries, non-emergency pre-existing outpatient consultations, and unverified private luxury suite upgrades are strictly excluded from emergency pool relief.'
      }
    ]
  },
  {
    filename: 'Prescription_Pharmacy_Relief_Policy_2026.pdf',
    title: 'Prescription & Essential Pharmacy Subsidy Policy',
    code: 'POL-PHARM-2026-V2',
    category: 'Prescription & Pharmacy Copay',
    maxLimit: 'INR 75,000 per academic year',
    effectiveDate: 'January 1, 2026',
    sections: [
      {
        heading: '1. Policy Overview',
        body: 'This policy guarantees continuous financial assistance for prescription pharmaceuticals, vital chronic medications, post-operative antibiotic regimens, and critical biologics prescribed by verified institutional physicians.'
      },
      {
        heading: '2. Covered Drug Schedules & Therapeutic Classes',
        body: '- Chronic maintenance drugs: Insulin, oral hypoglycemics, antihypertensives, asthma inhalers, and cardiac medications.\n- Acute infectious disease treatments: Injectable and oral broad-spectrum antibiotics, antivirals, and anti-fungals.\n- Psychiatric medications: Antidepressants, anxiolytics, and mood stabilizers prescribed by campus counselors.\n- Oncology adjuncts and specialized immunotherapy medications.\n- Post-surgical wound care supplies and sterile dressing kits.'
      },
      {
        heading: '3. Subsidy Rates & Tiered Reimbursement',
        body: 'Tier 1 (Generic Essential Formularies): 100% subsidy coverage.\nTier 2 (Branded Specialized Therapeutics): 80% subsidy coverage.\nTier 3 (Specialty Biologics & Non-Formulary Drugs): 65% coverage with clinical chief officer review.'
      },
      {
        heading: '4. Fast-Track Optical Claim Intake',
        body: 'Patients may upload pharmacy tax invoices or digitally signed prescription receipts through MedAccess AI OCR intake for instantaneous price verification against standard CGHS/NLEM national drug price caps.'
      },
      {
        heading: '5. Non-Covered Items',
        body: 'Over-the-counter dietary protein supplements, multivitamin gummies without diagnosed clinical deficiencies, herbal cosmetics, and fitness steroids are excluded.'
      }
    ]
  },
  {
    filename: 'Diagnostic_Imaging_Lab_Coverage_Policy_2026.pdf',
    title: 'Diagnostic Imaging & Advanced Laboratory Relief Policy',
    code: 'POL-DIAG-2026-V1',
    category: 'Diagnostic, Lab & Imaging Relief',
    maxLimit: 'INR 50,000 per diagnostic episode',
    effectiveDate: 'January 1, 2026',
    sections: [
      {
        heading: '1. Objectives & Diagnostic Mandate',
        body: 'To eliminate diagnostic delays by funding advanced radiological imaging and specialized clinical laboratory investigations recommended by attending medical specialists.'
      },
      {
        heading: '2. Covered Diagnostic Modalities',
        body: '- High-Resolution Magnetic Resonance Imaging (1.5T / 3.0T MRI brain, spine, musculoskeletal).\n- Multi-Slice Contrast Computed Tomography (CT chest, abdomen, angiography).\n- Doppler Ultrasound Sonography and 2D Echocardiography.\n- Comprehensive Histopathology, Core Biopsies, and Cytology evaluations.\n- Molecular diagnostics, RT-PCR panels, blood cultures, and hormone assays.'
      },
      {
        heading: '3. Approved Diagnostic Networks & Reimbursements',
        body: 'Investigations performed at empanelled hospital radiodiagnostic departments or NABL-accredited diagnostic labs qualify for 80% to 100% instant reimbursement. Emergency urgent scans ordered by ER staff are reimbursed at 100% rate without prior pre-authorization.'
      },
      {
        heading: '4. Documentation Requirements',
        body: 'A valid prescription with clinical indication from a registered medical practitioner and the itemized radiology/pathology invoice with QR code or official lab seal must be submitted.'
      },
      {
        heading: '5. Exclusions',
        body: 'Routine corporate wellness executive checkups and non-clinical genomic ancestry tests are not covered.'
      }
    ]
  },
  {
    filename: 'Mental_Health_Counseling_Policy_2026.pdf',
    title: 'Mental Health & Psychological Counseling Support Policy',
    code: 'POL-MNHL-2026-V3',
    category: 'Mental Health & Tele-Counseling',
    maxLimit: 'INR 60,000 per academic year',
    effectiveDate: 'January 1, 2026',
    sections: [
      {
        heading: '1. Policy Statement & Commitment to Student Wellness',
        body: 'Recognizing mental health as fundamental to student well-being and academic success, this institutional policy provides robust financial support for licensed clinical psychological therapy, crisis de-escalation, and psychiatric management.'
      },
      {
        heading: '2. Scope of Mental Health Benefits',
        body: '- Individual and group psychotherapy sessions with licensed clinical psychologists (up to 20 funded sessions/year).\n- Comprehensive neuropsychiatric diagnostic evaluations and ADHD/mood assessments.\n- 24/7 Acute Behavioral Health Emergency Tele-Counseling and Crisis Triage.\n- Partial hospitalization and acute inpatient psychiatric stabilization care.\n- Prescribed psychiatric pharmacotherapy copays.'
      },
      {
        heading: '3. Complete Privacy & HIPAA De-Identification',
        body: 'All psychological and psychiatric claim submissions are protected under strict HIPAA Privacy Rule (§ 164.514) guidelines. Diagnostic psych notes are tokenized with AES-256 encryption, ensuring student therapeutic records remain confidential from academic and administrative transcripts.'
      },
      {
        heading: '4. Rapid Distress Priority Routing',
        body: 'Voice or text intakes exhibiting high psychological distress indicators (Severe Panic, Depressive Crisis, Self-Harm Risk) trigger automated ESI Level 2 priority flags and direct linkage to campus on-call emergency counseling staff.'
      },
      {
        heading: '5. Copay Coverage Ratio',
        body: 'Outpatient therapy and counseling sessions are subsidized at 100% for the first 10 sessions and 80% for subsequent sessions up to the annual limit of INR 60,000.'
      }
    ]
  }
];

function generatePdf(policy: PolicyDoc, targetPath: string): Promise<void> {
  return new Promise((resolve, reject) => {
    const doc = new PDFDocument({
      size: 'A4',
      margins: { top: 50, bottom: 50, left: 50, right: 50 }
    });

    const stream = fs.createWriteStream(targetPath);
    doc.pipe(stream);

    // Header Badge
    doc
      .rect(50, 45, 495, 60)
      .fill('#0D9488');

    doc
      .fillColor('#FFFFFF')
      .font('Helvetica-Bold')
      .fontSize(16)
      .text('MEDACCESS AI  |  INSTITUTIONAL HEALTHCARE POLICY', 65, 58);

    doc
      .font('Helvetica')
      .fontSize(10)
      .text(`Official Policy Code: ${policy.code}  |  Effective: ${policy.effectiveDate}`, 65, 80);

    doc.moveDown(3);

    // Title Section
    doc
      .fillColor('#0F172A')
      .font('Helvetica-Bold')
      .fontSize(18)
      .text(policy.title, 50, 125);

    // Metadata Table / Box
    doc
      .rect(50, 155, 495, 48)
      .fillAndStroke('#F8FAFC', '#E2E8F0');

    doc
      .fillColor('#0D9488')
      .font('Helvetica-Bold')
      .fontSize(9)
      .text('CLINICAL CATEGORY', 65, 163);

    doc
      .fillColor('#0F172A')
      .font('Helvetica')
      .fontSize(11)
      .text(policy.category, 65, 178);

    doc
      .fillColor('#0D9488')
      .font('Helvetica-Bold')
      .fontSize(9)
      .text('MAXIMUM BENEFIT CAP', 320, 163);

    doc
      .fillColor('#0F172A')
      .font('Helvetica-Bold')
      .fontSize(11)
      .text(policy.maxLimit, 320, 178);

    let currentY = 220;

    // Policy Sections
    for (const section of policy.sections) {
      if (currentY > 680) {
        doc.addPage();
        currentY = 50;
      }

      doc
        .fillColor('#0D9488')
        .font('Helvetica-Bold')
        .fontSize(12)
        .text(section.heading, 50, currentY);

      currentY += 18;

      doc
        .fillColor('#334155')
        .font('Helvetica')
        .fontSize(10)
        .text(section.body, 50, currentY, {
          width: 495,
          lineGap: 4,
          align: 'left'
        });

      currentY = doc.y + 16;
    }

    // Footer Box
    const footerY = 740;
    doc
      .rect(50, footerY, 495, 35)
      .fill('#F1F5F9');

    doc
      .fillColor('#64748B')
      .font('Helvetica')
      .fontSize(8)
      .text('MedAccess AI Clinical Governance Board  •  HIPAA De-Identified Protocol Compliant  •  Official Institutional Policy Document', 55, footerY + 12, {
        align: 'center',
        width: 485
      });

    doc.end();

    stream.on('finish', () => resolve());
    stream.on('error', (err) => reject(err));
  });
}

async function main() {
  console.log('Generating 4 Institutional Policy PDFs...');
  for (const policy of policies) {
    for (const outDir of outputDirs) {
      const fullPath = path.join(outDir, policy.filename);
      await generatePdf(policy, fullPath);
      console.log(`✅ Generated PDF: ${fullPath} (${(fs.statSync(fullPath).size / 1024).toFixed(1)} KB)`);
    }
  }
  console.log('\n🎉 All 4 Policy PDFs successfully generated and ready for upload!');
}

main().catch(err => {
  console.error('Error generating policy PDFs:', err);
  process.exit(1);
});
