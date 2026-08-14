// ============================================================
//  IntelliDesk EduAccess — PDF Parsing & Embedding Service
//  Route: POST /api/v1/admin/knowledge/upload
//
//  Pipeline:
//   1. multer accepts .pdf upload
//   2. poppler pdftotext -layout extracts structured 2D text
//   3. Smart chunker splits into overlapping paragraphs
//   4. Gemini gemini-embedding-001 generates 768-dim vectors
//   5. Supabase inserts chunks + vectors into policy_embeddings
// ============================================================

import { Router, Request, Response } from 'express';
import multer from 'multer';
import { extractTextFromPdf } from '../services/receiptParser.js';
import { GoogleGenerativeAI } from '@google/generative-ai';
import { supabase } from '../config/supabase.js';
import { v4 as uuidv4 } from 'uuid';

const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY || '');

// ─────────────────────────────────────────────────────────────
//  MULTER CONFIGURATION
//  Store in memory so we can pipe bytes directly to pdf-parse.
// ─────────────────────────────────────────────────────────────

const storage = multer.memoryStorage();

const upload = multer({
  storage,
  limits: {
    fileSize: 50 * 1024 * 1024, // 50 MB
    files: 1,
  },
  fileFilter: (_req, file, cb) => {
    if (file.mimetype === 'application/pdf') {
      cb(null, true);
    } else {
      cb(new Error('Only PDF files are accepted.'));
    }
  },
});

// ─────────────────────────────────────────────────────────────
//  CHUNKING UTILITIES
// ─────────────────────────────────────────────────────────────

const CHUNK_MAX_CHARS = 1500;   // ~375 tokens — fits embedding model context
const CHUNK_OVERLAP_CHARS = 150; // sliding overlap for context continuity

/**
 * Split extracted PDF text into overlapping character-window chunks.
 *
 * Strategy:
 *  - First try to split on paragraph boundaries (double newlines).
 *  - Merge short paragraphs until a chunk reaches CHUNK_MAX_CHARS.
 *  - If a single paragraph exceeds the limit, hard-split on sentence
 *    boundaries to avoid mid-sentence cuts.
 *  - Apply a trailing overlap to each chunk from the end of the previous one.
 */
function chunkText(text: string): string[] {
  // Normalise whitespace
  const normalised = text
    .replace(/\r\n/g, '\n')
    .replace(/\r/g, '\n')
    .replace(/\n{3,}/g, '\n\n')  // collapse triple+ newlines
    .trim();

  const paragraphs = normalised.split(/\n\n+/);
  const rawChunks: string[] = [];
  let buffer = '';

  for (const para of paragraphs) {
    const trimmed = para.trim();
    if (!trimmed) continue;

    // If a single paragraph overflows, sentence-split it first
    if (trimmed.length > CHUNK_MAX_CHARS) {
      if (buffer) {
        rawChunks.push(buffer.trim());
        buffer = '';
      }
      const sentences = trimmed.split(/(?<=[.!?])\s+/);
      let sentBuf = '';
      for (const sentence of sentences) {
        if ((sentBuf + ' ' + sentence).length > CHUNK_MAX_CHARS) {
          if (sentBuf) rawChunks.push(sentBuf.trim());
          sentBuf = sentence;
        } else {
          sentBuf = sentBuf ? `${sentBuf} ${sentence}` : sentence;
        }
      }
      if (sentBuf) rawChunks.push(sentBuf.trim());
      continue;
    }

    if ((buffer + '\n\n' + trimmed).length > CHUNK_MAX_CHARS) {
      if (buffer) rawChunks.push(buffer.trim());
      buffer = trimmed;
    } else {
      buffer = buffer ? `${buffer}\n\n${trimmed}` : trimmed;
    }
  }
  if (buffer.trim()) rawChunks.push(buffer.trim());

  // Apply sliding overlap
  if (rawChunks.length <= 1) return rawChunks;

  const overlappedChunks: string[] = [rawChunks[0]];
  for (let i = 1; i < rawChunks.length; i++) {
    const prev = rawChunks[i - 1];
    const overlap = prev.slice(-CHUNK_OVERLAP_CHARS).trim();
    overlappedChunks.push(`${overlap} ${rawChunks[i]}`.trim());
  }
  return overlappedChunks;
}

// ─────────────────────────────────────────────────────────────
//  EMBEDDING HELPER
// ─────────────────────────────────────────────────────────────

/**
 * Call Gemini gemini-embedding-001 for a single text chunk.
 * Returns a 768-dimensional float array.
 */
async function embedChunk(text: string): Promise<number[]> {
  const model = genAI.getGenerativeModel({ model: "gemini-embedding-001" });
  const response = await model.embedContent({
    content: { parts: [{ text: text }] },
    outputDimensionality: 768
  } as any);
  const values = response.embedding.values;
  
  if (!values || values.length !== 768) {
    throw new Error('Gemini returned empty embedding for chunk.');
  }
  return values;
}

// ─────────────────────────────────────────────────────────────
//  ROUTER
// ─────────────────────────────────────────────────────────────

const knowledgeRouter = Router();

// ── POST /upload ─────────────────────────────────────────────

knowledgeRouter.post(
  '/upload',
  upload.single('pdf'),
  async (req: Request, res: Response) => {
    if (!req.file) {
      res.status(400).json({ error: 'No PDF file uploaded. Field name must be "pdf".' });
      return;
    }

    const originalName = req.file.originalname;
    const documentName = (req.body.documentName as string | undefined)?.trim()
      || originalName.replace(/\.pdf$/i, '').replace(/[-_]/g, ' ');

    console.log(`[KB] Upload received: "${originalName}" (${req.file.size} bytes)`);

    // ── Step 1: Parse PDF ──────────────────────────────────
    let extractedText: string;
    try {
      extractedText = await extractTextFromPdf(req.file.buffer);
      if (!extractedText || extractedText.trim().length < 50) {
        res.status(422).json({
          error: 'PDF appears to be empty or image-only (no extractable text).',
        });
        return;
      }
      console.log(`[KB] Extracted ${extractedText.length} characters from PDF via pdftotext -layout.`);
    } catch (err: any) {
      console.error('[KB] PDF parsing error:', err);
      res.status(422).json({ error: 'Failed to parse PDF. Ensure the file is a valid, text-based PDF.' });
      return;
    }

    // ── Step 2: Chunk ──────────────────────────────────────
    const chunks = chunkText(extractedText);
    console.log(`[KB] Split into ${chunks.length} chunks.`);

    if (chunks.length === 0) {
      res.status(422).json({ error: 'No text chunks could be extracted from this document.' });
      return;
    }

    // ── Step 3 & 4: Embed each chunk + Upsert to Supabase ──
    const documentId = uuidv4();
    const instId = (typeof req.institution_id === 'string' ? req.institution_id : 'inst-001');
    const insertedRows: Array<{
      id: string;
      institution_id: string;
      category: string;
      policy_name: string;
      policy_chunk: string;
      max_coverage_limit: number;
      currency: string;
      embedding?: number[];
    }> = [];

    const CONCURRENCY = 5; // embed N chunks in parallel to respect rate limits

    for (let i = 0; i < chunks.length; i += CONCURRENCY) {
      const batch = chunks.slice(i, i + CONCURRENCY);
      const embeddings = await Promise.all(batch.map(embedChunk));

      for (let j = 0; j < batch.length; j++) {
        insertedRows.push({
          id: uuidv4(),
          institution_id: instId,
          category: 'General Clinical & Welfare Guidelines',
          policy_name: documentName,
          policy_chunk: batch[j],
          max_coverage_limit: 50000.00,
          currency: 'INR',
          embedding: embeddings[j]?.slice(0, 384),
        });
      }
      console.log(`[KB] Embedded chunks ${i + 1}–${Math.min(i + CONCURRENCY, chunks.length)} / ${chunks.length}`);
    }

    // ── Step 5: Insert to Supabase ─────────────────────────
    const { error: insertError } = await supabase
      .from('policy_embeddings')
      .insert(insertedRows);

    if (insertError) {
      console.error('[KB] Supabase insert error:', insertError);
      res.status(500).json({ error: `Database error: ${insertError.message}` });
      return;
    }

    console.log(`[KB] Successfully saved ${insertedRows.length} rows for document "${documentName}".`);

    res.status(201).json({
      success: true,
      documentId,
      documentName,
      fileName: originalName,
      chunkCount: insertedRows.length,
      message: `"${documentName}" processed and embedded into the knowledge base.`,
    });
  }
);

// ── GET /list ─────────────────────────────────────────────────
// Returns deduplicated list of uploaded documents (one row per document).

knowledgeRouter.get('/list', async (req: Request, res: Response) => {
  try {
    const { data, error } = await supabase
      .from('policy_embeddings')
      .select('id, policy_name, category, policy_chunk, max_coverage_limit, created_at')
      .order('created_at', { ascending: false });

    if (error) {
      console.error('[KB] Supabase GET /list error:', error);
      res.status(200).json([]);
      return;
    }

    // Deduplicate — one entry per policy_name, compute chunk count
    const docMap = new Map<string, {
      id: string;
      document_name: string;
      file_name: string;
      uploaded_at: string;
      chunk_count: number;
    }>();

    for (const row of data ?? []) {
      const nameKey = row.policy_name || row.id;
      if (!docMap.has(nameKey)) {
        docMap.set(nameKey, {
          id: row.id,
          document_name: row.policy_name || 'Clinical Policy Document',
          file_name: `${row.policy_name || 'policy'}.pdf`,
          uploaded_at: row.created_at || new Date().toISOString(),
          chunk_count: 1,
        });
      } else {
        docMap.get(nameKey)!.chunk_count++;
      }
    }

    res.json([...docMap.values()]);
  } catch (err: any) {
    console.error('[KB] Supabase connection error in GET /list:', err?.message || err);
    res.status(200).json([]);
  }
});

// ── DELETE /:id ───────────────────────────────────────────────
// Removes all embedding chunks for the given document / policy name.

knowledgeRouter.delete('/:id', async (req: Request, res: Response) => {
  const { id } = req.params;
  if (!id) {
    res.status(400).json({ error: 'Invalid document ID.' });
    return;
  }

  const { error } = await supabase
    .from('policy_embeddings')
    .delete()
    .or(`id.eq.${id},policy_name.ilike.%${id}%`);

  if (error) {
    console.error('[KB] Supabase DELETE error:', error);
    res.status(400).json({ error: error.message });
    return;
  }

  res.json({ success: true, message: 'Document removed from knowledge base.' });
});

export default knowledgeRouter;
