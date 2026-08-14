import { v4 as uuidv4 } from 'uuid';

export interface SyntheticCrisisPayload {
  id: string;
  studentName: string;
  studentPhone: string;
  rawMessage: string;
  category: string;
  mediaUrl?: string;
  institutionId: string;
}

const CRISIS_ARCHETYPES = [
  {
    category: 'Medical Emergency & Inpatient Care',
    template: (amount: number) =>
      `Admitted to Emergency Department for severe acute abdominal trauma. Uncovered hospital copay is $${amount}. Urgent medical assistance requested.`,
  },
  {
    category: 'Prescription & Pharmacy Copay',
    template: (amount: number) =>
      `Need urgent $${amount} for critical prescription insulin and asthma inhaler refills. Pharmacy copay exceeds available funds.`,
  },
  {
    category: 'Mental Health & Crisis Intervention',
    template: (amount: number) =>
      `Experiencing acute panic attacks and severe depressive episode. Requesting $${amount} for urgent psychological first aid and psychiatric copay relief.`,
  },
  {
    category: 'Diagnostic, Lab & Imaging Relief',
    template: (amount: number) =>
      `Physician ordered urgent MRI and comprehensive diagnostic blood panel. Requesting $${amount} diagnostic imaging copay coverage.`,
  },
  {
    category: 'Physical Therapy & Dental Crisis',
    template: (amount: number) =>
      `Severe dental abscess requiring emergency root canal surgery today. Total out-of-pocket procedure balance is $${amount}.`,
  },
  {
    category: 'General Health & Basic Welfare',
    template: (amount: number) =>
      `Need urgent primary care consultation and preventative diagnostic checkup copay of $${amount} at university health clinic.`,
  },
];

const STUDENT_FIRST_NAMES = ['Alex', 'Jordan', 'Taylor', 'Morgan', 'Sam', 'Riley', 'Casey', 'Dakota', 'Avery', 'Reese'];
const STUDENT_LAST_NAMES = ['Chen', 'Patel', 'Washington', 'Garcia', 'Smith', 'Kim', 'Johnson', 'Mendoza', 'Williams', 'Nguyen'];

/**
 * Generate a synthetic batch of student crisis intake payloads
 */
export function generateSyntheticBatch(count: number = 10, institutionId: string = 'edu-admin-123'): SyntheticCrisisPayload[] {
  const batch: SyntheticCrisisPayload[] = [];

  for (let i = 0; i < count; i++) {
    const archetype = CRISIS_ARCHETYPES[i % CRISIS_ARCHETYPES.length];
    const amount = Math.floor(120 + Math.random() * 880);
    const firstName = STUDENT_FIRST_NAMES[Math.floor(Math.random() * STUDENT_FIRST_NAMES.length)];
    const lastName = STUDENT_LAST_NAMES[Math.floor(Math.random() * STUDENT_LAST_NAMES.length)];
    const phone = `+1555${Math.floor(1000000 + Math.random() * 9000000)}`;

    const hasAttachment = Math.random() > 0.4;
    const mediaUrl = hasAttachment
      ? `https://storage.university.edu/receipts/doc_${Math.floor(1000 + Math.random() * 9000)}.pdf`
      : undefined;

    batch.push({
      id: uuidv4(),
      studentName: `${firstName} ${lastName}`,
      studentPhone: phone,
      rawMessage: archetype.template(amount),
      category: archetype.category,
      mediaUrl,
      institutionId,
    });
  }

  return batch;
}
