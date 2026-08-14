-- Migration: Add ticket_messages table for multi-turn crisis chat
create table if not exists public.ticket_messages (
    id uuid primary key default gen_random_uuid(),
    ticket_id uuid not null references public.tickets(id) on delete cascade,
    sender text not null check (sender in ('STUDENT', 'COUNSELOR_AI', 'HUMAN_ADMIN')),
    message text not null,
    is_crisis_response boolean default false,
    suggested_resources jsonb,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

alter table public.ticket_messages enable row level security;
create policy "Enable full access for service_role on ticket_messages" on public.ticket_messages for all to service_role using (true) with check (true);
create index if not exists ticket_messages_ticket_id_idx on public.ticket_messages (ticket_id);
create index if not exists ticket_messages_created_at_idx on public.ticket_messages (created_at);

GRANT ALL PRIVILEGES ON TABLE public.ticket_messages TO service_role;
