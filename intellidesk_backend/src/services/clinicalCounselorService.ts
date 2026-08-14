import { pipeline } from '@xenova/transformers';
import { supabase } from '../config/supabase.js';
import { getIO } from './socketManager.js';

let counselorPipeline: any = null;
let isModelLoading = false;

/**
 * Lazy singleton for onnx-community/Qwen2.5-0.5B-Instruct
 */
export async function getQwenCounselorPipeline() {
  if (!counselorPipeline && !isModelLoading) {
    isModelLoading = true;
    try {
      console.log('🤖 [Clinical Counselor] Initializing Qwen2.5-0.5B-Instruct local ONNX pipeline...');
      counselorPipeline = await pipeline(
        'text-generation',
        'onnx-community/Qwen2.5-0.5B-Instruct',
        { dtype: 'q4' } as any
      );
      console.log('✅ [Clinical Counselor] Qwen2.5-0.5B-Instruct pipeline loaded successfully.');
    } catch (err: any) {
      try {
        console.log('🤖 [Clinical Counselor] Fallback to Xenova/Qwen1.5-0.5B-Chat...');
        counselorPipeline = await pipeline(
          'text-generation',
          'Xenova/Qwen1.5-0.5B-Chat',
          { quantized: true } as any
        );
      } catch (fbErr) {
        console.warn('⚠️ [Clinical Counselor] Local ONNX model unavailable, using rule-based PFA engine.');
        counselorPipeline = null;
      }
    } finally {
      isModelLoading = false;
    }
  }
  return counselorPipeline;
}

export const LIFE_SAFETY_REGEX = /\b(suicid(e|al)|kill myself|end my life|self harm|hurt myself|want to die|overdose|severe bleeding|chest pain|unconscious|cant breathe|cannot breathe|heart attack|stroke)\b/i;

export interface EmergencyHelpline {
  name: string;
  number: string;
  category: string;
  actionUrl: string;
  description: string;
  icon: string;
}

export const CLINICAL_EMERGENCY_RESOURCES: EmergencyHelpline[] = [
  {
    name: "Tele-MANAS (Govt of India)",
    number: "14416",
    category: "Mental Health & Crisis Hotline",
    actionUrl: "tel:14416",
    description: "Toll-free 24/7 National Tele-Mental Health Programme (or 1800-891-4416).",
    icon: "support_agent",
  },
  {
    name: "Vandrevala Mental Health Helpline",
    number: "+91 9999 666 555",
    category: "24/7 Psychological First Aid",
    actionUrl: "tel:+919999666555",
    description: "Free, confidential 24/7 clinical counseling & de-escalation.",
    icon: "favorite",
  },
  {
    name: "988 Suicide & Crisis Lifeline (US)",
    number: "988",
    category: "Immediate Emergency Lifeline",
    actionUrl: "tel:988",
    description: "24/7 confidential clinical support for acute distress or self-harm prevention.",
    icon: "crisis_alert",
  },
  {
    name: "Campus 24/7 Medical Emergency Desk",
    number: "1800-MED-ACCESS",
    category: "Clinical Triage & Ambulance Dispatch",
    actionUrl: "tel:1800633222",
    description: "Institutional emergency medical escort, ER copay triage, and ambulance dispatch.",
    icon: "medical_services",
  },
];

const SYSTEM_PROMPT = `You are the MedAccess AI Clinical & Psychological First Aid Assistant.
Your objectives:
1. Respond with warmth, active listening, and calm empathy (2-4 sentences).
2. Ground the patient (e.g., "Take a steady breath, you are not alone in this").
3. Reassure them that their medical/copay request is actively being triaged by our clinical team.
4. If physical danger or acute distress is present, instruct them to seek immediate medical assistance or use the emergency numbers provided below.`;

export interface ClinicalCounselorResponse {
  reply: string;
  isCrisisResponse: boolean;
  isLifeSafetyAlert: boolean;
  resources: EmergencyHelpline[] | null;
  latencyMs: number;
}

/**
 * Psychological First Aid Rogerian fallback generator
 */
function getRogerianPFABackup(patientMessage: string, isLifeSafety: boolean): string {
  if (isLifeSafety) {
    return "I hear how deeply overwhelming and acute things are right now. Please take a slow, steady breath with me—you are not alone and your safety is our utmost priority. Our emergency medical triage desk has been alerted, and I strongly urge you to call one of the 24/7 crisis numbers below right now for immediate support.";
  }

  const lower = patientMessage.toLowerCase();
  if (lower.includes('pain') || lower.includes('er') || lower.includes('hospital') || lower.includes('doctor') || lower.includes('prescription') || lower.includes('medicine')) {
    return "I hear what you are experiencing with your medical needs right now. Take a calm, gentle breath. Your emergency medical copay request is actively being triaged by our clinical team to ensure you receive immediate financial and clinical assistance.";
  }

  if (lower.includes('anxious') || lower.includes('panic') || lower.includes('scared') || lower.includes('stress') || lower.includes('overwhelm')) {
    return "Thank you for reaching out and sharing what you are going through. Everything you are feeling right now is completely valid. Take a slow, grounding breath with me—we are right here with you, and support is available 24/7.";
  }

  return "I hear you, and thank you for connecting with MedAccess AI. Please take a gentle breath—our clinical team is reviewing your intake details and processing your assistance request without delay.";
}

/**
 * Generates an empathetic clinical PFA response using local Qwen model or Rogerian PFA engine.
 */
export async function generateClinicalCounselorResponse(
  claimId: string,
  patientMessage: string,
  history: Array<{ sender: string; message: string }> = []
): Promise<ClinicalCounselorResponse> {
  const startTime = Date.now();

  // Step A: Life-Safety Pattern Check
  const isLifeSafetyAlert = LIFE_SAFETY_REGEX.test(patientMessage);
  const isCrisisResponse = isLifeSafetyAlert;
  const suggestedResources = isLifeSafetyAlert ? CLINICAL_EMERGENCY_RESOURCES : null;

  let counselorReply = '';

  try {
    const generator = await getQwenCounselorPipeline();
    if (generator) {
      // Step B: Multi-Turn ChatML Conversation Format
      const messages = [
        { role: 'system', content: SYSTEM_PROMPT },
        ...history.slice(-4).map((msg) => ({
          role: msg.sender === 'PATIENT' || msg.sender === 'STUDENT' ? 'user' : 'assistant',
          content: msg.message,
        })),
        { role: 'user', content: patientMessage },
      ];

      const genPromise = generator(messages, {
        max_new_tokens: 130,
        temperature: 0.7,
        top_p: 0.9,
        do_sample: true,
      });

      const timeoutPromise = new Promise((_, reject) =>
        setTimeout(() => reject(new Error('Model timeout')), 3000)
      );

      const output: any = await Promise.race([genPromise, timeoutPromise]);

      if (Array.isArray(output) && output.length > 0) {
        const genText = output[0]?.generated_text;
        if (Array.isArray(genText)) {
          const lastMsg = genText.at(-1);
          counselorReply = lastMsg?.content?.trim() || '';
        } else if (typeof genText === 'string') {
          counselorReply = genText.replace(/<\|.*?\|>/g, '').trim();
          if (counselorReply.includes('assistant\n')) {
            counselorReply = counselorReply.split('assistant\n').pop()?.trim() || counselorReply;
          }
        }
      }
    }
  } catch (err) {
    // Model fallback to Rogerian PFA generator
  }

  // Validate reply text
  const lower = counselorReply.toLowerCase();
  const isInvalid =
    !counselorReply ||
    counselorReply.length < 20 ||
    lower.includes('ai language model') ||
    lower.includes('system prompt') ||
    lower.includes('respond with warmth') ||
    lower.includes('objectives:');

  if (isInvalid) {
    counselorReply = getRogerianPFABackup(patientMessage, isLifeSafetyAlert);
  }

  // Step C: Life-Safety Database Escalation & War Room Notification
  if (isLifeSafetyAlert && claimId) {
    try {
      await supabase
        .from('claims')
        .update({
          esi_level: 'ESI_1_CRITICAL',
          is_life_safety_alert: true,
          status: 'Triage Active',
          updated_at: new Date().toISOString(),
        })
        .eq('id', claimId);

      // Emit emergency alert to Admin War Room
      const io = getIO();
      io.emit('emergency:alert', {
        claimId,
        esiLevel: 'ESI_1_CRITICAL',
        isLifeSafetyAlert: true,
        patientMessage,
        timestamp: new Date().toISOString(),
      });
      io.to(`claim:${claimId}`).emit('emergency:alert', {
        claimId,
        isLifeSafetyAlert: true,
      });
    } catch (dbErr) {
      console.warn(`[ClinicalCounselor] Escalation write warning:`, dbErr);
    }
  }

  const latencyMs = Date.now() - startTime;

  // Step D: Telemetry Log
  console.log(`💬 [MedAccess Counselor] Generated response for Claim ${claimId} in ${latencyMs}ms | Crisis Protocol: ${isCrisisResponse}`);

  return {
    reply: counselorReply,
    isCrisisResponse,
    isLifeSafetyAlert,
    resources: suggestedResources,
    latencyMs,
  };
}
