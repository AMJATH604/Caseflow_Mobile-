-- ═══════════════════════════════════════════════════════════════
-- Live invitation badge
--
-- The dashboard's "Invitations" badge now subscribes to realtime changes on
-- the two invitation tables so the count updates the moment an invite arrives
-- (or is accepted/rejected) — no manual refresh needed.
--
-- Realtime only delivers changes for tables in the `supabase_realtime`
-- publication, and only for rows the subscriber can SELECT under RLS. Adding
-- the tables here is what makes the badge live; RLS still limits each user to
-- their own invitations.
-- ═══════════════════════════════════════════════════════════════

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'firm_members'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.firm_members;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'case_collaborations'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.case_collaborations;
  END IF;
END $$;
