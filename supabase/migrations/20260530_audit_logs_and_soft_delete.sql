-- CaseFlow Audit Logging Table
-- Tracks all critical data mutations for legal compliance.
-- Created as part of the security hardening audit.

CREATE TABLE IF NOT EXISTS public.audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  action TEXT NOT NULL CHECK (action IN (
    'create', 'update', 'delete', 'view',
    'export_data', 'import_data',
    'signIn', 'signOut',
    'subscriptionChange', 'firmMembershipChange', 'collaborationChange',
    'aiQuery'
  )),
  entity TEXT NOT NULL,           -- Table/entity name (e.g., 'cases', 'hearings')
  entity_id TEXT NOT NULL,        -- Primary key of the affected record
  details JSONB DEFAULT '{}',     -- Additional context (old/new values, field names)
  context TEXT,                   -- Screen/source identifier
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- Index for querying audit logs by user
CREATE INDEX IF NOT EXISTS idx_audit_logs_user_id ON public.audit_logs(user_id);

-- Index for querying audit logs by entity
CREATE INDEX IF NOT EXISTS idx_audit_logs_entity ON public.audit_logs(entity, entity_id);

-- Index for time-range queries
CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at ON public.audit_logs(created_at DESC);

-- RLS: Users can only insert their own audit logs, admins can read all
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

-- Allow authenticated users to insert their own audit entries
CREATE POLICY "Users can insert own audit logs" ON public.audit_logs
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- Allow service role to read all audit logs (for admin dashboard)
CREATE POLICY "Service role can read all audit logs" ON public.audit_logs
  FOR SELECT TO service_role
  USING (true);

-- Users can read their own audit logs
CREATE POLICY "Users can read own audit logs" ON public.audit_logs
  FOR SELECT TO authenticated
  USING (auth.uid() = user_id);

-- Add soft delete column to key tables (if not exists)
-- These are idempotent: won't fail if column already exists
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'cases' AND column_name = 'deleted_at') THEN
    ALTER TABLE public.cases ADD COLUMN deleted_at TIMESTAMPTZ DEFAULT NULL;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'clients' AND column_name = 'deleted_at') THEN
    ALTER TABLE public.clients ADD COLUMN deleted_at TIMESTAMPTZ DEFAULT NULL;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'hearings' AND column_name = 'deleted_at') THEN
    ALTER TABLE public.hearings ADD COLUMN deleted_at TIMESTAMPTZ DEFAULT NULL;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'payments' AND column_name = 'deleted_at') THEN
    ALTER TABLE public.payments ADD COLUMN deleted_at TIMESTAMPTZ DEFAULT NULL;
  END IF;
END $$;

COMMENT ON TABLE public.audit_logs IS 'Audit trail for all critical data mutations. Required for legal compliance.';
COMMENT ON COLUMN public.audit_logs.action IS 'Type of mutation: create, update, delete, view, etc.';
COMMENT ON COLUMN public.audit_logs.entity IS 'Table/entity name affected (e.g., cases, hearings)';
COMMENT ON COLUMN public.audit_logs.details IS 'JSON context: old/new values, field names, cascade info';
