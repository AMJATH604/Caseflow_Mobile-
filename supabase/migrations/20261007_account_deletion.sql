-- ═══════════════════════════════════════════════════════════════
-- Account deletion with a 30-day grace period
--
-- Applied to production 2026-10-04 (edge function deployed the same day),
-- on its own in a transaction with
-- `supabase db query --linked --file`, then deploy the edge function
-- `purge-deleted-accounts` (verify_jwt false; it uses verifyWebhookAuth).
--
-- Flow
--   1. The user taps "Delete my account". The app calls
--      request_account_deletion(), which refuses while the user owns a firm
--      with accepted juniors or clerks (they must remove the team first), and
--      otherwise stamps deletion_requested_at / deletion_scheduled_for
--      (now + 30 days). The apps then show only a "scheduled for deletion"
--      screen with Cancel and Sign out.
--   2. cancel_account_deletion() clears both stamps.
--   3. Daily at 02:30 IST a cron job calls the edge function, which for each
--      account past its date: lists the files to remove
--      (account_deletion_files), runs purge_account() — one transaction that
--      hands firm records back to the firm owner, deletes the user's own data
--      and finally the auth user — and then removes the files through the
--      Storage API (direct deletes on storage.objects are not allowed).
--
-- Firm records are never lost with a junior or clerk. Everything a member
-- created inside their senior's firm (cases, clients, hearings, payments,
-- documents, commissions, strategy tasks…) is reassigned to the senior
-- before the member's login is removed; created_by cascades would otherwise
-- delete those rows with the member.
--
-- Security: the two user-facing functions take no user id — they act on
-- auth.uid() only, so they cannot be pointed at someone else. The purge and
-- file-listing functions take a user id and are revoked from every API role;
-- only the service role (the edge function) can execute them.
-- ═══════════════════════════════════════════════════════════════

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS deletion_requested_at TIMESTAMPTZ;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS deletion_scheduled_for TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS profiles_deletion_due_idx
  ON public.profiles (deletion_scheduled_for)
  WHERE deletion_scheduled_for IS NOT NULL;

-- The two stamps change only through the functions below, so a client cannot
-- shorten its own grace period or skip the team check with a plain UPDATE.
CREATE OR REPLACE FUNCTION public.guard_profile_deletion_stamps()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF (NEW.deletion_requested_at IS DISTINCT FROM OLD.deletion_requested_at
      OR NEW.deletion_scheduled_for IS DISTINCT FROM OLD.deletion_scheduled_for)
     AND coalesce(current_setting('caseflow.account_deletion', true), '') <> 'on' THEN
    NEW.deletion_requested_at := OLD.deletion_requested_at;
    NEW.deletion_scheduled_for := OLD.deletion_scheduled_for;
  END IF;
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.guard_profile_deletion_stamps() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_guard_profile_deletion_stamps ON public.profiles;
CREATE TRIGGER trg_guard_profile_deletion_stamps
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.guard_profile_deletion_stamps();

-- ── Email change: keep profiles.email in step with the login ─────
-- The apps start an email change with auth.updateUser; the login email
-- changes only once the user opens the confirmation link. This copies the
-- confirmed address onto the profile, which the directory and invitations use.
CREATE OR REPLACE FUNCTION public.sync_profile_email()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.email IS DISTINCT FROM OLD.email THEN
    UPDATE public.profiles SET email = NEW.email WHERE id = NEW.id;
  END IF;
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'sync_profile_email failed for %: %', NEW.id, SQLERRM;
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.sync_profile_email() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_sync_profile_email ON auth.users;
CREATE TRIGGER trg_sync_profile_email
  AFTER UPDATE OF email ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.sync_profile_email();

-- ── Request / cancel (called by the signed-in user) ─────────────
CREATE OR REPLACE FUNCTION public.request_account_deletion()
RETURNS timestamptz
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  uid uuid := auth.uid();
  team int;
  due timestamptz := now() + interval '30 days';
BEGIN
  IF uid IS NULL THEN
    RAISE EXCEPTION 'Not signed in' USING ERRCODE = '28000';
  END IF;

  SELECT count(*) INTO team
    FROM public.firm_members
   WHERE owner_id = uid AND member_id IS NOT NULL AND member_id <> uid AND status = 'accepted';
  IF team > 0 THEN
    -- The apps match on CF_TEAM_EXISTS and explain what to do.
    RAISE EXCEPTION 'CF_TEAM_EXISTS: remove your % team member(s) first', team
      USING ERRCODE = 'P0001';
  END IF;

  PERFORM set_config('caseflow.account_deletion', 'on', true);
  UPDATE public.profiles
     SET deletion_requested_at = now(), deletion_scheduled_for = due
   WHERE id = uid;
  RETURN due;
END;
$$;

CREATE OR REPLACE FUNCTION public.cancel_account_deletion()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not signed in' USING ERRCODE = '28000';
  END IF;
  PERFORM set_config('caseflow.account_deletion', 'on', true);
  UPDATE public.profiles
     SET deletion_requested_at = NULL, deletion_scheduled_for = NULL
   WHERE id = auth.uid();
END;
$$;

REVOKE ALL ON FUNCTION public.request_account_deletion() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.cancel_account_deletion() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.request_account_deletion() TO authenticated;
GRANT EXECUTE ON FUNCTION public.cancel_account_deletion() TO authenticated;

-- ── Files that go with the account ──────────────────────────────
-- Paths: case-documents/<case id>/…, commission-*/<commission id>/…,
-- chat-attachments/chambers/<firm id>/…, chat-attachments/dms/<conversation>/…,
-- profile-photos/<user id>/…
CREATE OR REPLACE FUNCTION public.account_deletion_files(p_user uuid)
RETURNS TABLE (bucket text, path text)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, storage
AS $$
  WITH own_cases AS (
    -- Cases that will be deleted: the user's own firm, or personal cases
    -- outside any other firm. A member's cases in their senior's firm stay.
    SELECT c.id FROM public.cases c
     WHERE c.firm_id = p_user
        OR (c.created_by = p_user AND (c.firm_id IS NULL OR c.firm_id = p_user))
  ),
  own_commissions AS (
    SELECT m.id FROM public.commissions m
     WHERE m.firm_id = p_user
        OR (m.created_by = p_user AND (m.firm_id IS NULL OR m.firm_id = p_user))
  ),
  own_dms AS (
    SELECT d.id FROM public.direct_conversations d
     WHERE d.participant_1 = p_user OR d.participant_2 = p_user
  )
  SELECT o.bucket_id::text, o.name::text
    FROM storage.objects o
   WHERE (o.bucket_id = 'profile-photos' AND split_part(o.name, '/', 1) = p_user::text)
      OR (o.bucket_id = 'case-documents' AND split_part(o.name, '/', 1) IN (SELECT id::text FROM own_cases))
      OR (o.bucket_id IN ('commission-evidence', 'commission-sketches', 'commission-witnesses')
          AND split_part(o.name, '/', 1) IN (SELECT id::text FROM own_commissions))
      OR (o.bucket_id = 'chat-attachments' AND split_part(o.name, '/', 1) = 'chambers'
          AND split_part(o.name, '/', 2) = p_user::text)
      OR (o.bucket_id = 'chat-attachments' AND split_part(o.name, '/', 1) = 'dms'
          AND split_part(o.name, '/', 2) IN (SELECT id::text FROM own_dms));
$$;
REVOKE ALL ON FUNCTION public.account_deletion_files(uuid) FROM PUBLIC, anon, authenticated;

-- ── The purge: one transaction ──────────────────────────────────
CREATE OR REPLACE FUNCTION public.purge_account(p_user uuid)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  team int;
BEGIN
  -- Re-check at purge time; skip rather than strand a team.
  SELECT count(*) INTO team FROM public.firm_members
   WHERE owner_id = p_user AND member_id IS NOT NULL AND member_id <> p_user AND status = 'accepted';
  IF team > 0 THEN
    RETURN 'skipped: team';
  END IF;

  -- 1. Records made inside another advocate's firm go back to that firm's
  --    owner — the user's current senior, or a firm they left earlier.
  --    Without this, created_by cascades would delete the firm's records.
  UPDATE public.cases SET created_by = firm_id
   WHERE created_by = p_user AND firm_id IS NOT NULL AND firm_id <> p_user;
  UPDATE public.clients SET created_by = firm_id
   WHERE created_by = p_user AND firm_id IS NOT NULL AND firm_id <> p_user;
  UPDATE public.commissions SET created_by = firm_id
   WHERE created_by = p_user AND firm_id IS NOT NULL AND firm_id <> p_user;
  UPDATE public.hearings x SET created_by = k.firm_id FROM public.cases k
   WHERE x.case_id = k.id AND x.created_by = p_user AND k.firm_id IS NOT NULL AND k.firm_id <> p_user;
  UPDATE public.payments x SET created_by = k.firm_id FROM public.cases k
   WHERE x.case_id = k.id AND x.created_by = p_user AND k.firm_id IS NOT NULL AND k.firm_id <> p_user;
  UPDATE public.case_acts x SET created_by = k.firm_id FROM public.cases k
   WHERE x.case_id = k.id AND x.created_by = p_user AND k.firm_id IS NOT NULL AND k.firm_id <> p_user;
  UPDATE public.case_ia_applications x SET created_by = k.firm_id FROM public.cases k
   WHERE x.case_id = k.id AND x.created_by = p_user AND k.firm_id IS NOT NULL AND k.firm_id <> p_user;
  UPDATE public.case_interim_orders x SET created_by = k.firm_id FROM public.cases k
   WHERE x.case_id = k.id AND x.created_by = p_user AND k.firm_id IS NOT NULL AND k.firm_id <> p_user;
  UPDATE public.certified_copies x SET created_by = k.firm_id FROM public.cases k
   WHERE x.case_id = k.id AND x.created_by = p_user AND k.firm_id IS NOT NULL AND k.firm_id <> p_user;
  UPDATE public.efiling_records x SET created_by = k.firm_id FROM public.cases k
   WHERE x.case_id = k.id AND x.created_by = p_user AND k.firm_id IS NOT NULL AND k.firm_id <> p_user;
  UPDATE public.evidence_checklists x SET created_by = k.firm_id FROM public.cases k
   WHERE x.case_id = k.id AND x.created_by = p_user AND k.firm_id IS NOT NULL AND k.firm_id <> p_user;
  UPDATE public.evidence_photos x SET created_by = k.firm_id FROM public.cases k
   WHERE x.case_id = k.id AND x.created_by = p_user AND k.firm_id IS NOT NULL AND k.firm_id <> p_user;
  UPDATE public.witness_examination_notes x SET created_by = k.firm_id FROM public.cases k
   WHERE x.case_id = k.id AND x.created_by = p_user AND k.firm_id IS NOT NULL AND k.firm_id <> p_user;
  UPDATE public.cross_exam_sessions x SET user_id = k.firm_id FROM public.cases k
   WHERE x.case_id = k.id AND x.user_id = p_user AND k.firm_id IS NOT NULL AND k.firm_id <> p_user;
  UPDATE public.ecourt_hearing_history x SET created_by = k.firm_id FROM public.cases k
   WHERE x.case_id = k.id AND x.created_by = p_user AND k.firm_id IS NOT NULL AND k.firm_id <> p_user;
  UPDATE public.ecourt_sync_records x SET synced_by = k.firm_id FROM public.cases k
   WHERE x.case_id = k.id AND x.synced_by = p_user AND k.firm_id IS NOT NULL AND k.firm_id <> p_user;
  UPDATE public.strategy_tasks x SET created_by = k.firm_id FROM public.cases k
   WHERE x.case_id = k.id AND x.created_by = p_user AND k.firm_id IS NOT NULL AND k.firm_id <> p_user;
  UPDATE public.commission_visits x SET created_by = m.firm_id FROM public.commissions m
   WHERE x.commission_id = m.id AND x.created_by = p_user AND m.firm_id IS NOT NULL AND m.firm_id <> p_user;
  UPDATE public.commission_observations x SET created_by = m.firm_id FROM public.commissions m
   WHERE x.commission_id = m.id AND x.created_by = p_user AND m.firm_id IS NOT NULL AND m.firm_id <> p_user;
  UPDATE public.commission_evidence x SET created_by = m.firm_id FROM public.commissions m
   WHERE x.commission_id = m.id AND x.created_by = p_user AND m.firm_id IS NOT NULL AND m.firm_id <> p_user;
  UPDATE public.commission_witnesses x SET created_by = m.firm_id FROM public.commissions m
   WHERE x.commission_id = m.id AND x.created_by = p_user AND m.firm_id IS NOT NULL AND m.firm_id <> p_user;
  UPDATE public.commission_sketches x SET created_by = m.firm_id FROM public.commissions m
   WHERE x.commission_id = m.id AND x.created_by = p_user AND m.firm_id IS NOT NULL AND m.firm_id <> p_user;
  UPDATE public.commission_expenses x SET created_by = m.firm_id FROM public.commissions m
   WHERE x.commission_id = m.id AND x.created_by = p_user AND m.firm_id IS NOT NULL AND m.firm_id <> p_user;
  UPDATE public.commission_reports x SET created_by = m.firm_id FROM public.commissions m
   WHERE x.commission_id = m.id AND x.created_by = p_user AND m.firm_id IS NOT NULL AND m.firm_id <> p_user;
  UPDATE public.commission_notifications x SET created_by = m.firm_id FROM public.commissions m
   WHERE x.commission_id = m.id AND x.created_by = p_user AND m.firm_id IS NOT NULL AND m.firm_id <> p_user;
  UPDATE public.task_comments x SET user_id = k.firm_id
    FROM public.strategy_tasks st JOIN public.cases k ON k.id = st.case_id
   WHERE x.task_id = st.id AND x.user_id = p_user AND k.firm_id IS NOT NULL AND k.firm_id <> p_user;
  UPDATE public.task_attachments x SET uploaded_by = k.firm_id
    FROM public.strategy_tasks st JOIN public.cases k ON k.id = st.case_id
   WHERE x.task_id = st.id AND x.uploaded_by = p_user AND k.firm_id IS NOT NULL AND k.firm_id <> p_user;
  UPDATE public.task_activity_log x SET user_id = k.firm_id
    FROM public.strategy_tasks st JOIN public.cases k ON k.id = st.case_id
   WHERE x.task_id = st.id AND x.user_id = p_user AND k.firm_id IS NOT NULL AND k.firm_id <> p_user;

  -- 2. The user's own firm and personal records (children cascade).
  DELETE FROM public.commissions
   WHERE firm_id = p_user OR (created_by = p_user AND (firm_id IS NULL OR firm_id = p_user));
  DELETE FROM public.cases
   WHERE firm_id = p_user OR (created_by = p_user AND (firm_id IS NULL OR firm_id = p_user));
  DELETE FROM public.clients WHERE firm_id = p_user OR created_by = p_user;

  -- 3. Rows that would block deleting the login (no ON DELETE action).
  DELETE FROM public.commission_visits WHERE created_by = p_user;
  DELETE FROM public.commission_observations WHERE created_by = p_user;
  DELETE FROM public.commission_evidence WHERE created_by = p_user;
  DELETE FROM public.commission_witnesses WHERE created_by = p_user;
  DELETE FROM public.commission_sketches WHERE created_by = p_user;
  DELETE FROM public.commission_expenses WHERE created_by = p_user;
  DELETE FROM public.commission_reports WHERE created_by = p_user;
  DELETE FROM public.commission_notifications WHERE created_by = p_user;
  UPDATE public.commissions SET commissioner_id = NULL WHERE commissioner_id = p_user;
  DELETE FROM public.task_comments WHERE user_id = p_user;
  DELETE FROM public.task_attachments WHERE uploaded_by = p_user;
  DELETE FROM public.task_activity_log WHERE user_id = p_user;
  DELETE FROM public.strategy_tasks WHERE created_by = p_user;
  UPDATE public.ecourt_hearing_history SET created_by = NULL WHERE created_by = p_user;
  UPDATE public.ecourt_sync_records SET synced_by = NULL WHERE synced_by = p_user;
  UPDATE public.bar_events SET created_by = NULL WHERE created_by = p_user;
  UPDATE public.bar_notices SET published_by = NULL WHERE published_by = p_user;
  DELETE FROM public.case_collaborations WHERE owner_id = p_user OR collaborator_id = p_user;
  DELETE FROM public.firm_members WHERE owner_id = p_user OR member_id = p_user;
  -- Former members still pointing at this firm.
  UPDATE public.profiles SET firm_id = NULL WHERE firm_id = p_user AND id <> p_user;

  -- 4. The login itself. profiles and every user_id/created_by that cascades
  --    from auth.users go with it.
  DELETE FROM auth.users WHERE id = p_user;
  RETURN 'deleted';
END;
$$;
REVOKE ALL ON FUNCTION public.purge_account(uuid) FROM PUBLIC, anon, authenticated;

-- Accounts whose grace period is over.
CREATE OR REPLACE FUNCTION public.accounts_due_for_deletion()
RETURNS SETOF uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT id FROM public.profiles
   WHERE deletion_scheduled_for IS NOT NULL
     AND deletion_scheduled_for <= now()
     AND deletion_requested_at <= now() - interval '30 days'
   ORDER BY deletion_scheduled_for
   LIMIT 50;
$$;
REVOKE ALL ON FUNCTION public.accounts_due_for_deletion() FROM PUBLIC, anon, authenticated;

-- ── Daily run: 21:00 UTC = 02:30 IST ────────────────────────────
DO $$
BEGIN
  BEGIN
    PERFORM cron.unschedule('purge-deleted-accounts');
  EXCEPTION WHEN OTHERS THEN NULL;
  END;
  PERFORM cron.schedule(
    'purge-deleted-accounts',
    '0 21 * * *',
    $cron$
    SELECT net.http_post(
      url := 'https://asrjqsnyezvcakvkokcl.supabase.co/functions/v1/purge-deleted-accounts',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-pg-trigger-secret', (SELECT public.get_pg_trigger_secret())
      ),
      body := '{}'::jsonb,
      timeout_milliseconds := 120000
    );
    $cron$
  );
END;
$$;
