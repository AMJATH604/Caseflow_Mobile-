-- ═══════════════════════════════════════════════════════════════
-- Digital Chambers read tracking
--
-- The group chat (case_discussions with case_id IS NULL) had no notion of
-- "read", so the chat hub could never show an unread badge for Chambers and
-- there were no group read receipts.
--
-- This table records, per user per firm, the moment they last read the
-- Chambers thread. Unread count = Chambers messages created after that
-- moment that the user did not send. A single row per (user, firm) keeps it
-- cheap — we do NOT track read state per individual message here.
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.chambers_reads (
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  firm_id UUID NOT NULL,
  last_read_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, firm_id)
);

ALTER TABLE public.chambers_reads ENABLE ROW LEVEL SECURITY;

-- Each user can only see and manage their own read markers.
-- (No CREATE POLICY IF NOT EXISTS in Postgres, so drop-then-create keeps this
-- script safely re-runnable.)
DROP POLICY IF EXISTS "Users manage their own chambers reads" ON public.chambers_reads;
CREATE POLICY "Users manage their own chambers reads"
  ON public.chambers_reads
  FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Optional but recommended: let Realtime broadcast changes so the chat hub's
-- unread badge clears the moment the user opens Chambers on any device.
-- (Safe to skip if the publication already includes the table.)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'chambers_reads'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.chambers_reads;
  END IF;
END $$;
