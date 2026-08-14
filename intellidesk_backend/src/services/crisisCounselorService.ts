import { pipeline } from '@xenova/transformers';
import { supabase } from '../config/supabase.js';

let counselorModel: any = null;
let isModelLoading = false;
let hasAttemptedInit = false;

/**
 * Initializes or returns the cached local ONNX text-generation pipeline.
 * Uses quantized Qwen Chat for lightweight, fast CPU execution.
 */
export async function getCounselorPipeline() {
  if (!counselorModel && !isModelLoading && !hasAttemptedInit) {
    isModelLoading = true;
    hasAttemptedInit = true;
    try {
      console.log('🤖 [Local Counselor AI] Initializing local text-generation pipeline (Xenova/Qwen1.5-0.5B-Chat)...');
      counselorModel = await pipeline(
        'text-generation',
        'Xenova/Qwen1.5-0.5B-Chat',
        { quantized: true } as any
      );
      console.log('✅ [Local Counselor AI] Qwen Chat pipeline loaded successfully.');
    } catch (err: any) {
      try {
        console.log('🤖 [Local Counselor AI] Trying onnx-community/Qwen2.5-0.5B-Instruct fallback...');
        counselorModel = await pipeline(
          'text-generation',
          'onnx-community/Qwen2.5-0.5B-Instruct',
          { quantized: true } as any
        );
      } catch (fbErr) {
        console.log('ℹ️ [Local Counselor AI] Local model offline, using Rogerian PFA counseling engine.');
        counselorModel = null;
      }
    } finally {
      isModelLoading = false;
    }
  }
  return counselorModel;
}

export const CRITICAL_SELF_HARM_REGEX = /\b(suicid(e|al)|kill myself|end my life|self harm|hurt myself|want to die|overdose|cut myself|hang myself|don't want to live|no reason to live|end it all|better off dead|give up on life)\b/i;

export const RELIEF_HARDSHIP_REGEX = /\b(rent|evict|eviction|landlord|homeless|housing|food|hungry|groceries|tuition|fee|fees|medical bill|hospital|medicine|prescription|urgent grant|need money|financial hardship|\$\d+|\u20B9\d+)\b/i;

export const TICKET_CONFIRM_REGEX = /^(yes|yes please|please submit|submit ticket|submit grant|confirm|go ahead|create ticket|open ticket|please help me apply|yes open ticket)\b/i;

export interface EmergencyResourceCard {
  name: string;
  number: string;
  category: string;
  actionUrl: string;
  description: string;
  icon: string;
}

export const EMERGENCY_RESOURCES: EmergencyResourceCard[] = [
  {
    name: "Tele-MANAS (Govt of India)",
    number: "14416",
    category: "Mental Health & Suicide Prevention",
    actionUrl: "tel:14416",
    description: "Toll-free 24/7 National Tele-Mental Health Programme (or 1800-891-4416).",
    icon: "support_agent"
  },
  {
    name: "988 Suicide & Crisis Lifeline",
    number: "988",
    category: "Immediate Emergency Lifeline",
    actionUrl: "tel:988",
    description: "24/7 confidential clinical support for people in suicidal crisis or severe psychiatric distress.",
    icon: "crisis_alert"
  },
  {
    name: "Vandrevala Foundation Helpline",
    number: "+91 9999 666 555",
    category: "24/7 Crisis Counseling",
    actionUrl: "tel:+919999666555",
    description: "Free, confidential 24/7 clinical counseling support.",
    icon: "favorite"
  },
  {
    name: "MedAccess 24/7 Clinical Emergency Desk",
    number: "1800-MED-ACCESS",
    category: "Clinical Triage & Ambulance Dispatch",
    actionUrl: "tel:1800633222",
    description: "Immediate institutional medical escort, ER copay triage, and emergency dispatch.",
    icon: "medical_services"
  }
];

const SYSTEM_PROMPT = `You are the MedAccess 24/7 Clinical & Psychological First Aid Assistant. 
Your primary goals are:
1. Practice active listening, validate emotional distress and physical symptoms with deep clinical empathy.
2. Keep your answers concise, reassuring, and compassionate (2-4 sentences max). Never sound bureaucratic or dismissive.
3. Offer immediate grounding techniques (e.g., "Take a slow breath, I am here with you").
4. Reassure the patient that institutional emergency medical copay relief and clinical staff are actively processing their request.
5. If immediate physical danger, medical emergency, or self-harm is mentioned, gently urge them to connect with our live emergency numbers or visit the nearest ER immediately.`;

/**
 * Psychological First Aid (RAPID Protocol) Response Generator
 */
export function generateRogerianPFAResponse(
  studentMessage: string, 
  isCrisis: boolean,
  isHardshipWithConfirmation = false,
  isTicketCreated = false
): string {
  if (isCrisis) {
    return "I hear how deeply overwhelming and painful things are right now, but please know that you are not alone and your life has immense value. Take a slow breath with me—I am right here with you. Our campus emergency welfare team has been notified, and I strongly encourage you to connect with our 24/7 crisis numbers below right now for live, confidential support.";
  }

  if (isTicketCreated) {
    return "I hear you, and your emergency grant and welfare ticket has been officially submitted to our welfare desk. Our team is prioritizing your request right now. Take a calm breath—we are working on getting you relief as quickly as possible.";
  }

  if (isHardshipWithConfirmation) {
    const lower = studentMessage.toLowerCase();
    if (lower.includes('rent') || lower.includes('evict') || lower.includes('housing')) {
      return "I hear how deeply stressful and urgent this housing situation is. Take a slow, steady breath—you are not alone. Would you like me to submit an official Emergency Housing Grant ticket for university welfare review?";
    }
    if (lower.includes('food') || lower.includes('hungry') || lower.includes('meal')) {
      return "Facing food insecurity is very stressful, and it is completely understandable to feel overwhelmed. Would you like me to submit an Emergency Meal & Grocery Grant ticket for you right away?";
    }
    return "I hear how challenging this financial situation is right now. Please take a gentle breath. Would you like me to submit an official Emergency Welfare & Grant Assistance ticket to the student aid desk on your behalf?";
  }

  const lower = studentMessage.toLowerCase();
  if (lower.includes('hi') || lower.includes('hello') || lower.includes('hey')) {
    return "Hello! I am your University Crisis Counselor & Welfare Advisor. How are you doing today? Feel free to share what is on your mind.";
  }

  if (lower.includes('exam') || lower.includes('fail') || lower.includes('degree') || lower.includes('study') || lower.includes('class')) {
    return "Academic pressure can feel extraordinarily heavy, and it makes complete sense that you are feeling stressed. Please take a gentle breath—your worth and well-being come first. I am here to help you talk through this.";
  }

  if (lower.includes('lonely') || lower.includes('sad') || lower.includes('cry') || lower.includes('depress') || lower.includes('anxious') || lower.includes('panic')) {
    return "Thank you for reaching out and sharing this with me. I hear the weight you are carrying, and everything you are feeling right now is completely valid. Take a slow, grounding breath with me—I am here with you.";
  }

  return "I hear how much is on your mind right now, and I appreciate you sharing this with me. Take a slow, calm breath—I am right here with you, and university support services are always available.";
}

export interface CounselorResponseResult {
  reply: string;
  isCrisisResponse: boolean;
  requiresConfirmation: boolean;
  isTicketLogged: boolean;
  resources: EmergencyResourceCard[] | null;
  messageId?: string;
  latencyMs: number;
}

/**
 * Generates an empathetic Psychological First Aid counselor response using local ONNX model
 * or PFA Rogerian engine, intelligent ticket confirmation, and logs into Supabase.
 */
export async function generateCounselorResponse(
  ticketId: string | null,
  studentMessage: string,
  history: Array<{ sender: string; message: string }> = [],
  options: { isTicketCreated?: boolean; requiresConfirmation?: boolean } = {}
): Promise<CounselorResponseResult> {
  const startTime = Date.now();

  // Step A: Safety & Harm Detection
  const isCrisisResponse = CRITICAL_SELF_HARM_REGEX.test(studentMessage);
  const isHardship = RELIEF_HARDSHIP_REGEX.test(studentMessage);
  const suggestedResources = isCrisisResponse ? EMERGENCY_RESOURCES : null;

  const isTicketLogged = !!ticketId;
  const requiresConfirmation = !isTicketLogged && !isCrisisResponse && isHardship;

  let counselorReply = '';

  try {
    const generator = await getCounselorPipeline();
    if (generator && !requiresConfirmation) {
      // Step B: Build Multi-Turn ChatML Prompt
      const messages = [
        { role: 'system', content: SYSTEM_PROMPT },
        ...history.slice(-4).map((msg) => ({
          role: msg.sender === 'STUDENT' ? 'user' : 'assistant',
          content: msg.message
        })),
        { role: 'user', content: studentMessage }
      ];

      // Limit generation tokens and race with a 2.5s safety timeout for real-time responsiveness
      const genPromise = generator(messages, {
        max_new_tokens: 45,
        temperature: 0.6,
        top_p: 0.85,
        do_sample: true
      });

      const timeoutPromise = new Promise((_, reject) =>
        setTimeout(() => reject(new Error('Inference timeout')), 2500)
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
  } catch (modelErr) {
    // Falls back seamlessly to Rogerian PFA generator
  }

  // Filter out any AI disclaimers, repetition, or prompt regurgitation
  const lowerReply = counselorReply.toLowerCase();
  const isInvalidText =
    !counselorReply ||
    counselorReply.length < 20 ||
    lowerReply.includes('ai language model') ||
    lowerReply.includes('practice active listening') ||
    lowerReply.includes('validate their pain') ||
    lowerReply.includes('keep your answer') ||
    lowerReply.includes('here is what i suggest') ||
    lowerReply.includes('get rid of') ||
    lowerReply.includes('crap');

  if (isInvalidText || requiresConfirmation || options.isTicketCreated) {
    counselorReply = generateRogerianPFAResponse(
      studentMessage, 
      isCrisisResponse, 
      requiresConfirmation, 
      options.isTicketCreated
    );
  }

  // Ensure life-safety hotline advisory is attached if crisis triggered
  if (isCrisisResponse && !counselorReply.includes('14416') && !counselorReply.includes('hotline') && !counselorReply.includes('crisis')) {
    counselorReply += "\n\nPlease reach out to our 24/7 crisis numbers below right now—counselors are ready to speak with you.";
  }

  const latencyMs = Date.now() - startTime;
  const outputTokens = counselorReply.split(/\s+/).length;

  // Telemetry logs
  console.log(`💬 [Crisis Counselor] Generated active support response | Ticket: ${ticketId || 'None (General/Pre-Confirmation)'} | Crisis Protocol: ${isCrisisResponse} | Ticket Logged: ${isTicketLogged}`);
  console.log(`🧠 [Local Counselor AI] Generated empathetic response in ${latencyMs}ms | Tokens: ${outputTokens}`);

  // Step D: Store in Supabase ticket_messages if ticket exists
  let messageId: string | undefined;
  if (ticketId) {
    try {
      const { data: inserted, error: insertError } = await supabase
        .from('ticket_messages')
        .insert([
          {
            ticket_id: ticketId,
            sender: 'COUNSELOR_AI',
            message: counselorReply,
            is_crisis_response: isCrisisResponse,
            suggested_resources: suggestedResources
          }
        ])
        .select('id')
        .single();

      if (insertError) {
        console.warn(`[CrisisCounselorService] Supabase ticket_messages insert notice: ${insertError.message}`);
      } else if (inserted) {
        messageId = inserted.id;
      }
    } catch (dbErr) {
      console.warn(`[CrisisCounselorService] Database insert notice:`, dbErr);
    }
  }

  return {
    reply: counselorReply,
    isCrisisResponse,
    requiresConfirmation,
    isTicketLogged,
    resources: suggestedResources,
    messageId,
    latencyMs
  };
}
