import { pipeline, env } from '@xenova/transformers';
import * as os from 'os';
import { extractInvoiceTotal, parseReceiptMedia } from '../services/receiptParser.js';

// Override the default cache directory to prevent Docker permission errors
env.cacheDir = os.tmpdir();

let qaPipelineInstance: any = null;

async function getQAPipeline() {
  if (!qaPipelineInstance) {
    qaPipelineInstance = await pipeline('question-answering', 'Xenova/distilbert-base-cased-distilled-squad');
  }
  return qaPipelineInstance;
}

export interface ExtractedAmountInfo {
  requestedAmount: number | null;
  receiptAmount: number | null;
  currency: 'INR' | 'USD';
}

function sanitizeAmount(amountStr: string): number | null {
  if (!amountStr) return null;
  // Remove currency symbols, commas, and letters, leaving only digits and decimals
  const cleaned = amountStr.replace(/[^0-9.]/g, '');
  const parsed = parseFloat(cleaned);
  if (isNaN(parsed) || parsed < 0) return null;
  return parsed;
}

export function detectCurrency(text: string): { currency: 'INR' | 'USD'; regexAmount: number | null } {
  if (!text) return { currency: 'USD', regexAmount: null };

  const invoice = extractInvoiceTotal(text);
  if (invoice.amount !== null) {
    return { currency: invoice.currency, regexAmount: invoice.amount };
  }

  const inrMatch = text.match(/(?:rs\.?|inr|₹|rupees?)\s*(\d+(?:,\d+)*(?:\.\d+)?)/i) ||
                   text.match(/(\d+(?:,\d+)*(?:\.\d+)?)\s*(?:rs\.?|inr|₹|rupees?)/i);

  const usdMatch = text.match(/(?:\$|usd|dollars?)\s*(\d+(?:,\d+)*(?:\.\d+)?)/i) ||
                   text.match(/(\d+(?:,\d+)*(?:\.\d+)?)\s*(?:\$|usd|dollars?)/i);

  if (inrMatch) {
    const rawVal = inrMatch[1].replace(/,/g, '');
    const parsed = parseFloat(rawVal);
    return { currency: 'INR', regexAmount: isNaN(parsed) ? null : parsed };
  }

  if (usdMatch) {
    const rawVal = usdMatch[1].replace(/,/g, '');
    const parsed = parseFloat(rawVal);
    return { currency: 'USD', regexAmount: isNaN(parsed) ? null : parsed };
  }

  return { currency: 'USD', regexAmount: null };
}

export async function extractVerifiedAmount(rawMessage: string, mediaUrl?: string | null): Promise<ExtractedAmountInfo> {
  let requestedAmount: number | null = null;
  let receiptAmount: number | null = null;
  let currency: 'INR' | 'USD' = 'USD';

  try {
    // 1. High-Priority Total Extractor & Currency Detection on rawMessage
    if (rawMessage) {
      const extracted = extractInvoiceTotal(rawMessage);
      if (extracted.amount !== null) {
        requestedAmount = extracted.amount;
        currency = extracted.currency;
      } else {
        const detected = detectCurrency(rawMessage);
        currency = detected.currency;
        if (detected.regexAmount !== null) {
          requestedAmount = detected.regexAmount;
        }
      }
    }

    // Step A: Question-Answering Fallback if requestedAmount still not resolved
    if (requestedAmount === null && rawMessage) {
      try {
        const qa = await getQAPipeline();
        const result = await qa('How much money is requested?', rawMessage);
        if (result && result.answer) {
          requestedAmount = sanitizeAmount(result.answer);
        }
      } catch (qaErr) {
        console.warn('[GrantExtractor] QA pipeline inference skipped:', qaErr);
      }
    }

    // Step B: Media / Attachment OCR & PDF Parser
    if (mediaUrl) {
      const mediaResult = await parseReceiptMedia(mediaUrl);
      if (mediaResult.amount !== null) {
        receiptAmount = mediaResult.amount;
        currency = mediaResult.currency;
      }
      if (requestedAmount === null && receiptAmount !== null) {
        requestedAmount = receiptAmount;
      }
    }
  } catch (err) {
    console.error('[GrantExtractor] Extraction pipeline error:', err);
  }

  return { requestedAmount, receiptAmount, currency };
}
