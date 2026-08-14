-- Supabase setup for MedAccess AI Knowledge Base & Clinical Policies

-- Enable the pgvector extension for AI embeddings
create extension if not exists vector;

-- Create the policy_embeddings table
create table if not exists public.policy_embeddings (
    id uuid primary key default gen_random_uuid(),
    institution_id text not null,
    document_id text not null,
    document_name text not null,
    file_name text not null,
    chunk_index integer not null,
    chunk_text text not null,
    embedding vector(768) not null,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Enable Row Level Security (RLS) on the table
alter table public.policy_embeddings enable row level security;

-- Create an RLS policy that grants full access to the 'service_role' (which the backend uses)
create policy "Enable full access for service_role"
    on public.policy_embeddings
    as permissive
    for all
    to service_role
    using (true)
    with check (true);

-- Create an index on the document_id for faster lookups and deletions
create index if not exists policy_embeddings_document_id_idx
    on public.policy_embeddings (document_id);

-- Create an index on the institution_id for tenant isolation
create index if not exists policy_embeddings_institution_id_idx
    on public.policy_embeddings (institution_id);

GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO service_role;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO service_role;
