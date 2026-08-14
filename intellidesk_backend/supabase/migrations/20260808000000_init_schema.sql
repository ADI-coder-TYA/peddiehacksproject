-- 1. Create tickets table with all ML metadata fields
CREATE EXTENSION IF NOT EXISTS vector;

CREATE TABLE IF NOT EXISTS public.tickets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_phone TEXT NOT NULL,
  student_name TEXT,
  institution_id TEXT NOT NULL DEFAULT 'default',
  raw_message TEXT,
  media_url TEXT,
  parsed_category TEXT,
  urgency_level TEXT DEFAULT 'Routine',
  status TEXT DEFAULT 'Pending',
  calculated_amount NUMERIC(10, 2),
  
  -- Core ML Metadata
  recommended_grant_amount NUMERIC(10, 2),
  grant_confidence_score NUMERIC(5, 4),
  crisis_severity_index NUMERIC(5, 4),
  anomaly_reconstruction_score NUMERIC(5, 4),
  dropout_risk_score NUMERIC(5, 4),
  sentiment_negative_score NUMERIC(5, 4),
  multi_department_involvement NUMERIC(5, 4),
  policy_ambiguity_score NUMERIC(5, 4),
  
  -- Vector Search specific
  embedding vector(768),
  
  -- GenAI Adjudication
  thought_process TEXT,
  matched_policy_name TEXT,
  flag_reason TEXT,
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Add full-text search capability
ALTER TABLE public.tickets ADD COLUMN fts tsvector GENERATED ALWAYS AS (to_tsvector('english', coalesce(raw_message, '') || ' ' || coalesce(parsed_category, ''))) STORED;
CREATE INDEX IF NOT EXISTS idx_tickets_fts ON public.tickets USING GIN (fts);

-- 3. Create policies table
CREATE TABLE IF NOT EXISTS public.policies (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  institution_id TEXT NOT NULL,
  policy_name TEXT NOT NULL,
  policy_text TEXT NOT NULL,
  embedding vector(768),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.policies ADD COLUMN fts tsvector GENERATED ALWAYS AS (to_tsvector('english', coalesce(policy_name, '') || ' ' || coalesce(policy_text, ''))) STORED;
CREATE INDEX IF NOT EXISTS idx_policies_fts ON public.policies USING GIN (fts);

-- 4. Hybrid Match Policies RPC (Dense Vector + BM25)
CREATE OR REPLACE FUNCTION public.hybrid_match_policies(
  query_text TEXT,
  query_embedding vector(768),
  match_count INT,
  full_text_weight FLOAT DEFAULT 1.0,
  semantic_weight FLOAT DEFAULT 1.0,
  rrf_k INT DEFAULT 60
)
RETURNS TABLE (
  id UUID,
  policy_name TEXT,
  policy_text TEXT,
  similarity FLOAT,
  rrf_score FLOAT
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  WITH semantic_search AS (
    SELECT policies.id,
           1 - (policies.embedding <=> query_embedding) as semantic_similarity,
           ROW_NUMBER() OVER (ORDER BY policies.embedding <=> query_embedding) as semantic_rank
    FROM public.policies
    WHERE policies.embedding IS NOT NULL
  ),
  keyword_search AS (
    SELECT policies.id,
           ts_rank_cd(policies.fts, websearch_to_tsquery('english', query_text)) as keyword_score,
           ROW_NUMBER() OVER (ORDER BY ts_rank_cd(policies.fts, websearch_to_tsquery('english', query_text)) DESC) as keyword_rank
    FROM public.policies
    WHERE policies.fts @@ websearch_to_tsquery('english', query_text)
  )
  SELECT 
    p.id,
    p.policy_name,
    p.policy_text,
    COALESCE(ss.semantic_similarity, 0) as similarity,
    (COALESCE(1.0 / (rrf_k + ss.semantic_rank), 0.0) * semantic_weight + 
     COALESCE(1.0 / (rrf_k + ks.keyword_rank), 0.0) * full_text_weight) as rrf_score
  FROM public.policies p
  LEFT JOIN semantic_search ss ON p.id = ss.id
  LEFT JOIN keyword_search ks ON p.id = ks.id
  WHERE ss.semantic_similarity > 0.0 OR ks.keyword_score > 0.0
  ORDER BY rrf_score DESC
  LIMIT match_count;
END;
$$;
