import { exec } from 'child_process';
import { promisify } from 'util';
import fs from 'fs/promises';
import * as syncFs from 'fs';
import path from 'path';
import os from 'os';
import axios from 'axios';
import { createWorker } from 'tesseract.js';
import { createRequire } from 'module';

const execAsync = promisify(exec);
const require = createRequire(import.meta.url);
const pdfModule = require('pdf-parse');

export interface ParsedReceiptResult {
  extractedText: string;
  receiptAmount: number | null;
  currency: 'INR' | 'USD';
  pageCount: number;
  isScannedImage: boolean;
}

export async function extractTextFromPdf(buffer: Buffer): Promise<string> {
  const tempPath = path.join(os.tmpdir(), `pdf_${Date.now()}_${Math.random().toString(36).substring(7)}.pdf`);
  try {
    await fs.writeFile(tempPath, buffer);
    const { stdout } = await execAsync(`pdftotext -layout "${tempPath}" -`);
    if (stdout && stdout.trim().length > 0) {
      return stdout;
    }
  } catch (err: any) {
    // pdftotext not available on host system; fallback to in-memory parser
  } finally {
    await fs.unlink(tempPath).catch(() => {});
  }

  try {
    const PDFParse = pdfModule.PDFParse || pdfModule.default?.PDFParse || (typeof pdfModule === 'function' ? pdfModule : null);
    if (PDFParse && typeof PDFParse === 'function') {
      try {
        const uint8 = new Uint8Array(buffer);
        const parser = new PDFParse(uint8);
        if (typeof parser.load === 'function') {
          await parser.load();
          const parsed = await parser.getText();
          if (parsed && typeof parsed === 'object' && parsed.text) {
            return parsed.text;
          }
          if (typeof parsed === 'string') return parsed;
        }
      } catch {
        const res = await (PDFParse as any)(buffer);
        return res?.text || '';
      }
    }
    if (typeof pdfModule === 'function') {
      const data = await pdfModule(buffer);
      return data.text || '';
    }
  } catch (parseErr) {
    console.warn('[Receipt Parser] In-memory PDF parser error:', parseErr);
  }

  return '';
}

export function extractInvoiceTotal(text: string): { amount: number | null; currency: 'INR' | 'USD' } {
  if (!text) return { amount: null, currency: 'USD' };

  // Currency Detection (INR vs USD)
  const detectedCurrency: 'INR' | 'USD' = /(?:INR|RS\.?|₹|RUPEE|LAKH|CRORE)/i.test(text) ? 'INR' : 'USD';

  // High-Precision Regex for Layout-Preserved Totals
  const totalPatterns = [
    /(?:TOTAL\s+AMOUNT\s+DUE|TOTAL\s+DUE|BALANCE\s+DUE|BALANCE|NET\s+PAYABLE|FINAL\s+TOTAL|GRAND\s+TOTAL)\s*[:\-]?\s*(?:INR|RS\.?|₹|\$|USD)?\s*([0-9]{1,3}(?:,[0-9]{3})*(?:\.[0-9]{2})?|[0-9]+(?:\.[0-9]{2})?)/i,
    /(?:INR|RS\.?|₹|\$|USD)\s*([0-9]{1,3}(?:,[0-9]{3})*(?:\.[0-9]{2})?|[0-9]+(?:\.[0-9]{2})?)\s*(?:TOTAL|DUE|BALANCE)/i,
    /(?:\bTOTAL\b)\s*[:\-]?\s*(?:INR|RS\.?|₹|\$|USD)?\s*([0-9]{1,3}(?:,[0-9]{3})*(?:\.[0-9]{2})?|[0-9]+(?:\.[0-9]{2})?)/i,
    /(?:\bDUE\b)\s*[:\-]?\s*(?:INR|RS\.?|₹|\$|USD)?\s*([0-9]{1,3}(?:,[0-9]{3})*(?:\.[0-9]{2})?|[0-9]+(?:\.[0-9]{2})?)/i,
    /(?:Subtotal|Taxable\s+amount|Line\s+Total)\s*[:\-]?\s*(?:INR|RS\.?|₹|\$|USD)?\s*([0-9]{1,3}(?:,[0-9]{3})*(?:\.[0-9]{2})?)/i
  ];

  let parsedAmount: number | null = null;
  for (const pattern of totalPatterns) {
    const match = text.match(pattern);
    if (match && match[1]) {
      const cleanVal = parseFloat(match[1].replace(/,/g, ''));
      if (!isNaN(cleanVal) && cleanVal > 0) {
        parsedAmount = cleanVal;
        console.log(`🎯 [Receipt Parser] Matched anchor "${match[0]}" ➔ Parsed: ${detectedCurrency} ${parsedAmount}`);
        return { amount: parsedAmount, currency: detectedCurrency };
      }
    }
  }

  // Fallback: search highest currency or line item value present in itemized rows
  const matches = [...text.matchAll(/(?:INR|RS\.?|₹|\$)?\s*([0-9]{1,3}(?:,[0-9]{3})*(?:\.[0-9]{2}))/gi)];
  if (matches.length > 0) {
    const nums = matches
      .map(m => parseFloat(m[1].replace(/,/g, '')))
      .filter(n => !isNaN(n) && n > 0 && n < 10000000);
    if (nums.length > 0) {
      parsedAmount = Math.max(...nums);
      console.log(`🎯 [Receipt Parser] Highest matched line item: ${detectedCurrency} ${parsedAmount}`);
      return { amount: parsedAmount, currency: detectedCurrency };
    }
  }

  return { amount: null, currency: detectedCurrency };
}

export async function extractReceiptData(mediaUrl?: string | null): Promise<ParsedReceiptResult> {
  if (!mediaUrl || typeof mediaUrl !== 'string' || mediaUrl.trim().length === 0) {
    return { extractedText: '', receiptAmount: null, currency: 'USD', pageCount: 0, isScannedImage: false };
  }

  const isRemote = mediaUrl.startsWith('http://') || mediaUrl.startsWith('https://');
  const isDataUri = mediaUrl.startsWith('data:');
  const isLocalFile = syncFs.existsSync(mediaUrl);

  if (!isRemote && !isDataUri && !isLocalFile) {
    // Media URL is raw text
    const { amount, currency } = extractInvoiceTotal(mediaUrl);
    return { extractedText: mediaUrl, receiptAmount: amount, currency, pageCount: 1, isScannedImage: false };
  }

  const tempFileName = `receipt_${Date.now()}_${Math.random().toString(36).substring(7)}`;
  const isPdfUrl = mediaUrl.toLowerCase().includes('.pdf');
  const tempFilePath = path.join(os.tmpdir(), `${tempFileName}${isPdfUrl ? '.pdf' : '.png'}`);

  console.log(`📥 [Receipt Parser] Downloading attachment from: ${mediaUrl.substring(0, 120)}...`);

  try {
    let buffer: Buffer;

    if (mediaUrl.startsWith('data:')) {
      console.log('📥 [Receipt Parser] Decoding base64 data URI...');
      const base64Data = mediaUrl.split(',')[1] || mediaUrl;
      buffer = Buffer.from(base64Data, 'base64');
    } else if (mediaUrl.startsWith('http://') || mediaUrl.startsWith('https://')) {
      console.log(`📥 [Receipt Parser] Downloading attachment from: ${mediaUrl}`);
      const response = await axios.get(mediaUrl, { responseType: 'arraybuffer', timeout: 15000 });
      buffer = Buffer.from(response.data);
    } else if (syncFs.existsSync(mediaUrl)) {
      console.log(`📥 [Receipt Parser] Reading local attachment file: ${mediaUrl}`);
      buffer = await fs.readFile(mediaUrl);
    } else {
      console.warn(`⚠️ [Receipt Parser] Unrecognized media_url format: ${mediaUrl.substring(0, 80)}`);
      return { extractedText: '', receiptAmount: null, currency: 'USD', pageCount: 0, isScannedImage: false };
    }

    await fs.writeFile(tempFilePath, buffer);

    const isPdf = isPdfUrl || buffer.slice(0, 4).toString() === '%PDF';
    let extractedText = '';
    let isScannedImage = false;

    if (isPdf) {
      try {
        // 1. Primary: Extract text preserving 2D table layout & right-aligned invoice totals via poppler pdftotext
        const { stdout } = await execAsync(`pdftotext -layout "${tempFilePath}" -`);
        extractedText = stdout || '';
        if (extractedText.trim().length > 0) {
          console.log(`📄 [Receipt Parser] Layout extraction completed (${extractedText.length} characters).`);
        }
      } catch (cmdErr: any) {
        // Fallback in-memory PDF extraction
      }

      if (!extractedText || extractedText.trim().length === 0) {
        extractedText = await extractTextFromPdf(buffer);
      }
    } else {
      // Image file (PNG, JPEG, etc.) -> Tesseract OCR
      console.log(`🖼️ [Receipt Parser] Running Tesseract OCR on image (${buffer.length} bytes)...`);
      isScannedImage = true;
      const worker = await createWorker('eng');
      const ret = await worker.recognize(tempFilePath);
      extractedText = ret.data.text || '';
      await worker.terminate();
    }

    console.log(`📝 [Receipt Parser Raw Preview]:\n${extractedText.substring(0, 400)}...\n---`);

    // Currency Detection & High-Precision Regex Extraction
    const { amount, currency } = extractInvoiceTotal(extractedText);
    const pageCount = isPdf ? (extractedText.match(/\f/g)?.length || 0) + 1 : 1;

    console.log(`🧾 [Receipt Parser] Verified Invoice Total: ${currency} ${amount}`);

    return {
      extractedText,
      receiptAmount: amount,
      currency,
      pageCount,
      isScannedImage
    };
  } catch (err: any) {
    console.error(`🚨 [Receipt Parser Error]: ${err.message}`);
    return { extractedText: '', receiptAmount: null, currency: 'USD', pageCount: 0, isScannedImage: false };
  } finally {
    // Guaranteed cleanup of temp file
    await fs.unlink(tempFilePath).catch(() => {});
  }
}

// Backwards compatibility wrappers
export async function parseAttachmentTextAndAmount(mediaUrl?: string | null): Promise<{
  extractedText: string;
  receiptAmount: number | null;
  currency: 'INR' | 'USD';
}> {
  const result = await extractReceiptData(mediaUrl);
  return {
    extractedText: result.extractedText,
    receiptAmount: result.receiptAmount,
    currency: result.currency
  };
}

export async function parseReceiptMedia(
  mediaInput: Buffer | string,
  mimeType?: string
): Promise<{ text: string; amount: number | null; currency: 'INR' | 'USD' }> {
  if (typeof mediaInput === 'string') {
    const res = await extractReceiptData(mediaInput);
    return { text: res.extractedText, amount: res.receiptAmount, currency: res.currency };
  }

  let text = '';
  try {
    if (mimeType === 'application/pdf' || (!mimeType && mediaInput.slice(0, 4).toString() === '%PDF')) {
      text = await extractTextFromPdf(mediaInput);
    } else {
      const worker = await createWorker('eng');
      const ret = await worker.recognize(mediaInput);
      text = ret.data.text || '';
      await worker.terminate();
    }
  } catch (err) {
    console.error('[Receipt Parser] Media extraction error:', err);
  }

  const { amount, currency } = extractInvoiceTotal(text);
  return { text, amount, currency };
}
