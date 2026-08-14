/**
 * IntelliDesk EduAccess — Life-Safety Sentinel & Crisis Guardrails
 * 
 * Provides hard safety bypass and crisis de-escalation for active self-harm,
 * suicidal ideation, or extreme student distress.
 */

export const LIFE_SAFETY_PATTERN = /\b(suicid(e|al)|kill myself|end my life|self harm|hurt myself|want to die|overdose)\b/i;

export interface LifeSafetyEvaluation {
  isLifeSafetyCritical: boolean;
  matchedTrigger?: string;
  lockedCategory: string;
  crisisHotlineText: string;
}

export function evaluateLifeSafety(message: string): LifeSafetyEvaluation {
  if (!message || typeof message !== 'string') {
    return {
      isLifeSafetyCritical: false,
      lockedCategory: 'General Health & Basic Welfare',
      crisisHotlineText: '',
    };
  }

  const match = message.match(LIFE_SAFETY_PATTERN);
  if (match) {
    return {
      isLifeSafetyCritical: true,
      matchedTrigger: match[0],
      lockedCategory: 'Mental Health & Crisis Intervention',
      crisisHotlineText: '🚨 LIFE-SAFETY ALERT: Immediate clinical counselor notification dispatched. Crisis Lifeline (988 / Vandrevala Foundation) injected into clinical response.',
    };
  }

  return {
    isLifeSafetyCritical: false,
    lockedCategory: 'General Health & Basic Welfare',
    crisisHotlineText: '',
  };
}
