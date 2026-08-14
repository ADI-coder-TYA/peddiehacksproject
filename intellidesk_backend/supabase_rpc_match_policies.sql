CREATE OR REPLACE FUNCTION public.match_policies (
  query_embedding vector(768),
  match_threshold float,
  match_count int
)
RETURNS TABLE (
  id uuid,
  policy_name text,
  content text,
  similarity float
)
LANGUAGE sql STABLE
AS $$
  SELECT 
    id,
    document_name AS policy_name,
    chunk_text AS content,
    1 - (embedding <=> query_embedding) AS similarity
  FROM policy_embeddings
  WHERE 1 - (embedding <=> query_embedding) > match_threshold
  ORDER BY embedding <=> query_embedding
  LIMIT match_count;
$$;

GRANT EXECUTE ON FUNCTION public.match_policies(vector(768), float, int) TO service_role;
