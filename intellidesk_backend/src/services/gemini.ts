import { GoogleGenAI, Type, Schema } from '@google/genai';
import { GoogleGenerativeAI } from '@google/generative-ai';
import { z } from 'zod';
import { supabase } from '../config/supabase.js';

const ai = new GoogleGenAI({ apiKey: process.env.GEMINI_API_KEY || '' });
const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY || '');

export const IntakeResultSchema = z.object({
  category: z.enum([
    'Medical Emergency & Inpatient Care',
    'Prescription & Pharmacy Copay',
    'Mental Health & Crisis Intervention',
    'Diagnostic, Lab & Imaging Relief',
    'Physical Therapy & Dental Crisis',
    'General Health & Basic Welfare'
  ]),
  urgency: z.enum(['Urgent', 'High', 'Routine']),
  plainTextSummary: z.string(),
  requestedAmount: z.number(),
  reliesOnMedicalOrAccommodation: z.boolean(),
  isAmbiguousDistress: z.boolean().default(false),
  sentimentNegativeScore: z.number().min(0).max(1).default(0),
  multiDepartmentInvolvement: z.number().min(0).max(1).default(0),
  policyAmbiguityScore: z.number().min(0).max(1).default(0),
});

export type IntakeResult = z.infer<typeof IntakeResultSchema>;

export async function processMultimodalIntake(textMessage: string, mediaUrl?: string): Promise<IntakeResult> {
  try {
    const promptContext = mediaUrl ? `\nThe patient/student also provided a medical invoice/receipt located at: ${mediaUrl}. Please analyze clinical breakdown.` : '';
    
    const prompt = `You are a MedAccess clinical triage and medical copay assessment AI specialist. Parse unstructured patient requests, clinical notes, and medical invoices to extract structured information.
    ${promptContext}
    
    Input: "${textMessage}"
    
    Output ONLY valid JSON matching this schema:
    {
      "category": "Medical Emergency & Inpatient Care" | "Prescription & Pharmacy Copay" | "Mental Health & Crisis Intervention" | "Diagnostic, Lab & Imaging Relief" | "Physical Therapy & Dental Crisis" | "General Health & Basic Welfare",
      "urgency": "Urgent" | "High" | "Routine",
      "plainTextSummary": "Clinical summary and distress level",
      "requestedAmount": Number (0 if none),
      "reliesOnMedicalOrAccommodation": true or false,
      "isAmbiguousDistress": true or false (true if acute psychiatric distress or urgent clinical emergency),
      "sentimentNegativeScore": float (0.0 to 1.0 based on clinical distress),
      "multiDepartmentInvolvement": float (0.0 to 1.0 based on ER/pharmacy/psychiatric overlap),
      "policyAmbiguityScore": float (0.0 to 1.0 based on policy match clarity)
    }`;

    const response = await ai.models.generateContent({
      model: 'gemini-2.0-flash',
      contents: prompt,
    });
    
    const text = response.text;
    if (!text) throw new Error("No response text from Gemini");

    const jsonMatch = text.match(/```json\n([\s\S]*?)\n```/) || text.match(/{[\s\S]*?}/);
    const jsonStr = jsonMatch ? (jsonMatch[1] || jsonMatch[0]) : text;

    return IntakeResultSchema.parse(JSON.parse(jsonStr));
  } catch (error) {
    console.error('Error in processMultimodalIntake:', error);
    return {
      category: 'General Health & Basic Welfare',
      urgency: 'Routine',
      plainTextSummary: textMessage,
      requestedAmount: 0,
      reliesOnMedicalOrAccommodation: false,
      isAmbiguousDistress: false,
      sentimentNegativeScore: 0.5,
      multiDepartmentInvolvement: 0.5,
      policyAmbiguityScore: 0.5
    };
  }
}

export async function generateEmbedding(text: string): Promise<number[]> {
  try {
    const model = genAI.getGenerativeModel({ model: "gemini-embedding-001" });
    const response = await model.embedContent({
      content: { parts: [{ text: text }] },
      outputDimensionality: 768
    } as any);
    
    return response.embedding.values || [];
  } catch (error) {
    console.error('Error generating embedding:', error);
    return new Array(768).fill(0);
  }
}

export async function searchMatchingPolicies(queryText: string, institutionId: string) {
  try {
    const queryEmbedding = await generateEmbedding(queryText);
    
    const { data: matchedPolicies, error } = await supabase
      .rpc('hybrid_match_policies', { 
        query_text: queryText,
        query_embedding: queryEmbedding, 
        match_count: 3 
      })
      .eq('institution_id', institutionId); // if applicable

    if (error) {
      console.error('Error running hybrid_match_policies RPC:', error);
      return [];
    }

    if (matchedPolicies && matchedPolicies.length > 0) {
      const topScore = matchedPolicies[0].rrf_score;
      if (topScore < 0.015) {
        console.warn(`[LOW_RRF_CONFIDENCE] Top RRF score for query is ${topScore}, which is below 0.015.`);
      }
    }

    return matchedPolicies || [];
  } catch (error) {
    console.error('Error in searchMatchingPolicies:', error);
    return [];
  }
}

export async function draftAccommodationEmail(ticketSummary: string, professorName: string): Promise<string> {
  try {
    const prompt = `Draft a privacy-redacted, ADA-compliant professor notification email requesting a deadline extension for a student.
    Professor Name: ${professorName}
    Issue Summary: ${ticketSummary}
    
    The email should be professional, concise, and protect the student's medical/personal privacy.`;

    const response = await ai.models.generateContent({
      model: 'gemini-2.0-flash',
      contents: prompt,
    });
    
    return response.text || "Could not generate email.";
  } catch (error) {
    console.error('Error drafting accommodation email:', error);
    return "Error drafting accommodation email.";
  }
}

export async function parseMultimodalInput(fileBuffer: Buffer, mimeType: string, textPrompt: string): Promise<{ narrative: string, detectedLanguage: string, amounts: number[] }> {
  try {
    const prompt = `You are a multimodal extraction assistant.
    Analyze the provided media file (which may be a voice note or an image like a hospital bill).
    ${textPrompt}
    
    Output ONLY valid JSON matching this schema:
    {
      "narrative": "A complete text description of the media, e.g., transcription translated to English, or OCR text of the bill",
      "detectedLanguage": "The language detected in the media (e.g., 'es', 'en')",
      "amounts": [Array of numbers found in the media (e.g. costs on a bill), empty if none]
    }`;

    const response = await ai.models.generateContent({
      model: 'gemini-2.5-flash',
      contents: [
        prompt,
        {
          inlineData: {
            data: fileBuffer.toString('base64'),
            mimeType: mimeType,
          }
        }
      ]
    });

    const text = response.text;
    if (!text) throw new Error("No response text from Gemini");

    const jsonMatch = text.match(/```json\n([\s\S]*?)\n```/) || text.match(/{[\s\S]*?}/);
    const jsonStr = jsonMatch ? (jsonMatch[1] || jsonMatch[0]) : text;

    const parsed = JSON.parse(jsonStr);
    return {
      narrative: parsed.narrative || '',
      detectedLanguage: parsed.detectedLanguage || 'en',
      amounts: Array.isArray(parsed.amounts) ? parsed.amounts : []
    };
  } catch (error) {
    console.error('Error in parseMultimodalInput:', error);
    throw new Error('Media parsing failed');
  }
}

export const AdjudicationResultSchema = z.object({
  thought_process: z.string(),
  matched_policy_name: z.string(),
  decision: z.enum(['Auto-Approved', 'Escalated', 'Denied']),
  approved_amount: z.number(),
  justification_to_admin: z.string(),
});

export type AdjudicationResult = z.infer<typeof AdjudicationResultSchema>;

const ADJUDICATION_SYSTEM_PROMPT = `You are a strict University Compliance Officer for IntelliDesk EduAccess.
Your job is to adjudicate student micro-grant and crisis requests based strictly on the provided policy context.

RULES:
1. You must use Chain-of-Thought reasoning. First cite the exact clause from the provided RAG context, evaluate the student's eligibility criteria (e.g., enrollment status, financial caps), and only then determine approval or escalation.
2. If the provided policy context does not explicitly cover the student's situation, you must output 'Escalated' with the reason 'Out of Scope'. Do not invent rules.
3. Zero hallucinations: Do not rely on external knowledge. If the policy context is empty or irrelevant, escalate.`;

export async function evaluatePolicyMatch(studentMessage: string, retrievedPolicyContext: string): Promise<AdjudicationResult> {
  try {
    const prompt = `Student Request: "${studentMessage}"\n\nPolicy Context:\n${retrievedPolicyContext}`;
    
    const responseSchema: Schema = {
      type: Type.OBJECT,
      properties: {
        thought_process: {
          type: Type.STRING,
          description: "Step-by-step reasoning citing specific clauses from the policy context."
        },
        matched_policy_name: {
          type: Type.STRING,
          description: "The exact name of the policy matched, or 'None'."
        },
        decision: {
          type: Type.STRING,
          enum: ['Auto-Approved', 'Escalated', 'Denied'],
          description: "The final adjudication decision."
        },
        approved_amount: {
          type: Type.NUMBER,
          description: "The approved amount in dollars. 0 if denied or escalated."
        },
        justification_to_admin: {
          type: Type.STRING,
          description: "A brief justification of the decision for the administrator."
        }
      },
      required: ['thought_process', 'matched_policy_name', 'decision', 'approved_amount', 'justification_to_admin']
    };

    const response = await ai.models.generateContent({
      model: 'gemini-1.5-pro',
      contents: prompt,
      config: {
        systemInstruction: ADJUDICATION_SYSTEM_PROMPT,
        responseMimeType: 'application/json',
        responseSchema: responseSchema,
      }
    });

    const text = response.text;
    if (!text) throw new Error("No response text from Gemini");

    return AdjudicationResultSchema.parse(JSON.parse(text));
  } catch (error) {
    console.error('Error in evaluatePolicyMatch:', error);
    return {
      thought_process: "Error during policy evaluation.",
      matched_policy_name: "None",
      decision: "Escalated",
      approved_amount: 0,
      justification_to_admin: "System Error during AI adjudication."
    };
  }
}

export class PrivacyViolationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'PrivacyViolationError';
  }
}

export async function redactSensitiveInfo(draftedEmail: string, flaggedTerms: string[] = []): Promise<string> {
  const prompt = `You are a FERPA and HIPAA compliance filter. Review the following drafted email intended for a university professor. You must remove any specific medical diagnoses (e.g., 'concussion', 'broken leg', 'clinical depression') and replace them with generic institutional phrasing (e.g., 'a documented medical emergency', 'an approved health accommodation'). Do not alter the mandated accommodations (e.g., '1.5x time on exams').
  
  Drafted Email:
  """
  ${draftedEmail}
  """
  
  Output ONLY the sanitized email text.`;

  const response = await ai.models.generateContent({
    model: 'gemini-1.5-flash',
    contents: prompt,
  });

  const sanitizedEmail = (response.text || '').trim();
  
  const searchTerms = ['diagnosis', ...flaggedTerms.map(t => t.toLowerCase())];
  const originalLower = draftedEmail.toLowerCase();
  const sanitizedLower = sanitizedEmail.toLowerCase();
  
  for (const term of searchTerms) {
    if (term && originalLower.includes(term) && sanitizedLower.includes(term)) {
      throw new PrivacyViolationError(`Failed to redact sensitive term: ${term}`);
    }
  }

  return sanitizedEmail;
}
