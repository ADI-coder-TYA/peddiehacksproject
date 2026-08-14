import PDFDocument from 'pdfkit';
import fs from 'fs';
import path from 'path';

function createPdf(filename: string, title: string, policies: Array<{ code: string; name: string; category: string; maxLimit: string; description: string; criteria: string[] }>) {
  return new Promise<void>((resolve, reject) => {
    const doc = new PDFDocument({ margin: 40, size: 'A4' });
    const writeStream = fs.createWriteStream(filename);

    doc.pipe(writeStream);

    // Header styling
    doc.rect(0, 0, doc.page.width, 70).fill('#0F172A');
    doc.fillColor('#FFFFFF').fontSize(18).font('Helvetica-Bold').text(title.toUpperCase(), 40, 25);
    doc.fontSize(10).font('Helvetica').fillColor('#94A3B8').text('Apex Health & Medical Center — Clinical Financial Relief Protocol', 40, 48);

    doc.moveDown(3);
    doc.fillColor('#0F172A');

    policies.forEach((policy, idx) => {
      doc.fontSize(13).font('Helvetica-Bold').fillColor('#0284C7').text(`${idx + 1}. [${policy.code}] ${policy.name}`);
      doc.moveDown(0.2);

      doc.fontSize(9).font('Helvetica-Bold').fillColor('#475569')
        .text(`Category: ${policy.category}   |   Max Coverage: ${policy.maxLimit}   |   Currency: INR`);
      doc.moveDown(0.4);

      doc.fontSize(10).font('Helvetica').fillColor('#1E293B')
        .text(policy.description, { align: 'justify', lineGap: 3 });
      doc.moveDown(0.4);

      doc.fontSize(9).font('Helvetica-Bold').fillColor('#334155').text('Eligibility & Clinical Authorization Criteria:');
      policy.criteria.forEach((crit) => {
        doc.fontSize(9).font('Helvetica').fillColor('#475569').text(`  •  ${crit}`, { lineGap: 2 });
      });

      doc.moveDown(1.2);
      if (idx < policies.length - 1) {
        doc.moveTo(40, doc.y).lineTo(doc.page.width - 40, doc.y).strokeColor('#E2E8F0').stroke();
        doc.moveDown(1);
      }
    });

    // Footer
    doc.fontSize(8).font('Helvetica-Oblique').fillColor('#94A3B8')
      .text('Confidential Clinical Governance Document — Authorized for Apex Health Network AI Triage.', 40, doc.page.height - 35, {
        align: 'center',
        width: doc.page.width - 80,
      });

    doc.end();
    writeStream.on('finish', () => resolve());
    writeStream.on('error', reject);
  });
}

async function main() {
  const rootDir = path.resolve(process.cwd(), '..');
  const pdf1Path = path.join(rootDir, 'sample_clinical_emergency_policies.pdf');
  const pdf2Path = path.join(rootDir, 'sample_mental_health_and_diagnostics_policies.pdf');

  console.log('Generating PDF 1: sample_clinical_emergency_policies.pdf...');
  await createPdf(pdf1Path, 'Emergency & Acute Clinical Relief Policies', [
    {
      code: 'CLIN-ER-001',
      name: 'Acute Inpatient & Emergency Resuscitation Protocol (ESI-1 & ESI-2)',
      category: 'Medical Emergency & Inpatient Care',
      maxLimit: 'INR 1,50,000',
      description: 'Provides direct institutional financial underwriting for patients admitted to the emergency department or intensive care unit with acute life-threatening trauma, respiratory failure, cardiac arrest, or severe sepsis. All emergency triage fees, ICU bed charges, supplemental oxygen therapy, and life-safety procedures are 100% covered up to the maximum allowable limit with zero upfront patient deductible.',
      criteria: [
        'Confirmed Emergency Severity Index of ESI-1 (Immediate Resuscitation) or ESI-2 (Emergent High Risk).',
        'Valid admission discharge summary, itemized emergency room bill, or physician emergency certificate.',
        'Zero-waitlist instantaneous co-pay authorization via institutional automated claims clearinghouse.',
      ],
    },
    {
      code: 'CLIN-RX-002',
      name: 'Vital Maintenance & Specialty Pharmacy Copay Coverage (ESI-2 & ESI-3)',
      category: 'Prescription & Pharmacy Copay',
      maxLimit: 'INR 50,000',
      description: 'Guarantees immediate pharmacy copay relief and digital prescription voucher issuance for essential chronic and acute maintenance drugs. Covered medications include insulin analogs, cardiovascular agents, post-chemotherapy antiemetics, high-grade immunosuppressants, and emergency broad-spectrum intravenous antibiotics.',
      criteria: [
        'Active physician prescription signed by a registered medical officer (RMO) within 14 days.',
        'Itemized pharmacy invoice showing GST, batch number, and national drug classification code.',
        'Immediate digital medical voucher issued redeemable across all Apollo, MedPlus, and hospital network pharmacies.',
      ],
    },
    {
      code: 'CLIN-AMB-003',
      name: 'Rapid Ambulance Response & Trauma Transit Assistance (ESI-3)',
      category: 'Medical Emergency & Inpatient Care',
      maxLimit: 'INR 25,000',
      description: 'Covers Advanced Life Support (ALS) and Basic Life Support (BLS) inter-facility emergency transfers, paramedical emergency dispatch fees, and oxygen transit expenses for patients requiring urgent hospital stabilization or trauma transfer.',
      criteria: [
        'Official ambulance trip sheet indicating patient pickup coordinates and receiving trauma center.',
        'Validated emergency dispatch timestamp matching the emergency room admission window.',
      ],
    },
  ]);

  console.log('Generating PDF 2: sample_mental_health_and_diagnostics_policies.pdf...');
  await createPdf(pdf2Path, 'Mental Health, Diagnostics & Trauma Policies', [
    {
      code: 'CLIN-MH-001',
      name: 'Psychological First Aid & Acute Crisis Intervention Grant (ESI-1 / Crisis)',
      category: 'Mental Health & Crisis Intervention',
      maxLimit: 'INR 75,000',
      description: 'Full institutional subsidy for emergency psychiatric admissions, suicide crisis intervention, tele-counseling support sessions, and psychological first aid (PFA). Ensures immediate confidential access to certified clinical psychologists, psychiatric pharmacotherapy, and crisis stabilization beds without bureaucratic delays.',
      criteria: [
        'Assessment of acute distress or referral from Tele-MANAS, National Suicide Helpline, or campus counselor.',
        'Includes up to 12 fully sponsored psychotherapy sessions and crisis psychiatric evaluation.',
        'Strict HIPAA and clinical confidentiality protections applied to all patient counseling logs.',
      ],
    },
    {
      code: 'CLIN-DX-002',
      name: 'Advanced Diagnostic Imaging & Urgent Biomarker Relief (ESI-2 & ESI-3)',
      category: 'Diagnostic, Lab & Imaging Relief',
      maxLimit: 'INR 60,000',
      description: 'Covers essential diagnostic imaging and high-complexity laboratory investigations required for emergency clinical diagnosis, including 3T MRI, 128-slice CT angiography, ultrasonography, PET scans, troponin-I cardiac biomarkers, and comprehensive oncology blood panels.',
      criteria: [
        'Clinical requisition form completed by attending consultant or ER duty physician.',
        'Diagnostic center receipt with NABL accreditation certificate and QR verification code.',
        'Direct reimbursement disbursed within 6 hours of verified radiologist diagnostic report upload.',
      ],
    },
    {
      code: 'CLIN-REHAB-003',
      name: 'Dental Trauma & Post-Operative Physical Rehabilitation (Routine / ESI-3)',
      category: 'Physical Therapy & Dental Crisis',
      maxLimit: 'INR 40,000',
      description: 'Financial aid for emergency maxillofacial dental surgery, traumatic tooth avulsion replantation, post-surgical physiotherapy, wheelchair mobility aids, and orthotic rehabilitation for acute musculoskeletal injuries.',
      criteria: [
        'Pre-and-post procedure clinical dental photographs or radiographic verification.',
        'Licensed physiotherapist or dental surgeon itemized bill and treatment plan.',
      ],
    },
  ]);

  console.log(`✅ Generated both policy PDFs successfully:\n1. ${pdf1Path}\n2. ${pdf2Path}`);
}

main().catch(console.error);
