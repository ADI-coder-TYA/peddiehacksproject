-- Enable pgvector extension
CREATE EXTENSION IF NOT EXISTS vector;

-- Table for tickets
CREATE TABLE IF NOT EXISTS tickets (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    student_phone text NOT NULL,
    raw_message text NOT NULL,
    media_url text,
    parsed_category text,
    urgency_level text CHECK (urgency_level IN ('Urgent', 'High', 'Routine')),
    status text DEFAULT 'Pending' CHECK (status IN ('Pending', 'Auto-Approved', 'Escalated', 'Resolved', 'Denied')),
    calculated_amount numeric DEFAULT 0,
    policy_match_reason text,
    payout_reference text,
    payout_method text,
    created_at timestamptz DEFAULT now()
);

-- Table for policy embeddings
CREATE TABLE IF NOT EXISTS policy_embeddings (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    policy_name text NOT NULL,
    content text NOT NULL,
    embedding vector(768),
    created_at timestamptz DEFAULT now()
);

-- Index for vector ops
CREATE INDEX IF NOT EXISTS policy_embeddings_embedding_idx ON policy_embeddings USING ivfflat (embedding vector_cosine_ops);

-- Function to match policies
CREATE OR REPLACE FUNCTION match_policies(
    query_embedding vector(768),
    match_threshold float DEFAULT 0.7,
    match_count int DEFAULT 5
)
RETURNS TABLE (
    id uuid,
    policy_name text,
    content text,
    similarity float
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        policy_embeddings.id,
        policy_embeddings.policy_name,
        policy_embeddings.content,
        1 - (policy_embeddings.embedding <=> query_embedding) AS similarity
    FROM policy_embeddings
    WHERE 1 - (policy_embeddings.embedding <=> query_embedding) > match_threshold
    ORDER BY policy_embeddings.embedding <=> query_embedding
    LIMIT match_count;
END;
$$;
