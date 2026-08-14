-- 1. Ensure required tables and columns exist
ALTER TABLE public.tickets ADD COLUMN IF NOT EXISTS student_id UUID;

CREATE TABLE IF NOT EXISTS public.audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    action TEXT NOT NULL,
    admin_id UUID,
    details JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Enable RLS on all tables
ALTER TABLE public.tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.policies ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

-- 3. Create Admin Check Function
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN (auth.jwt() -> 'user_metadata' ->> 'role') = 'admin';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Policies for 'tickets'
-- Students can SELECT their own tickets
CREATE POLICY "Students can view their own tickets"
ON public.tickets FOR SELECT
TO authenticated
USING (student_id = auth.uid());

-- Students can INSERT their own tickets
CREATE POLICY "Students can insert their own tickets"
ON public.tickets FOR INSERT
TO authenticated
WITH CHECK (student_id = auth.uid());

-- Students can UPDATE their own tickets ONLY if status is 'Pending'
CREATE POLICY "Students can update their own pending tickets"
ON public.tickets FOR UPDATE
TO authenticated
USING (student_id = auth.uid() AND status = 'Pending')
WITH CHECK (student_id = auth.uid() AND status = 'Pending');

-- Admins have full access to tickets (except INSERT which they usually don't need, but let's allow SELECT, UPDATE, DELETE as requested)
CREATE POLICY "Admins can select all tickets"
ON public.tickets FOR SELECT
TO authenticated
USING (public.is_admin());

CREATE POLICY "Admins can update all tickets"
ON public.tickets FOR UPDATE
TO authenticated
USING (public.is_admin());

CREATE POLICY "Admins can delete all tickets"
ON public.tickets FOR DELETE
TO authenticated
USING (public.is_admin());


-- 5. Policies for 'audit_logs'
-- Admins can SELECT all audit logs
CREATE POLICY "Admins can view audit logs"
ON public.audit_logs FOR SELECT
TO authenticated
USING (public.is_admin());

-- Note: No INSERT, UPDATE, or DELETE policies are created for audit_logs. 
-- Since RLS is enabled, this means these operations are denied for all users.
-- Only the backend using the service_role key will bypass RLS and be able to insert logs.


-- 6. Policies for 'policies' (referred to as policy_embeddings)
-- All authenticated users can SELECT policies
CREATE POLICY "Authenticated users can view policies"
ON public.policies FOR SELECT
TO authenticated
USING (auth.role() = 'authenticated');

-- Admins have FULL access to policies
CREATE POLICY "Admins can do everything on policies"
ON public.policies FOR ALL
TO authenticated
USING (public.is_admin());
