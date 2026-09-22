-- ═══════════════════════════════════════════════════════════════
-- Audit foundations
--
-- Groundwork for the admin console's Activity feed. Three problems with the
-- current audit trail, all of which make it unusable as evidence:
--
--   1. IT DELETES ITSELF. audit_logs.user_id is NOT NULL with ON DELETE
--      CASCADE to auth.users, so removing a user erases every record of what
--      they did — exactly backwards for an audit log. The row count has
--      already fallen from 835 to 460 through ordinary account cleanup.
--
--   2. IT ONLY SEES WHAT THE APP CHOOSES TO TELL IT. Logging is client-side
--      and fire-and-forget (AuditLogger in the Flutter app), covering only
--      `cases` and `strategy_tasks`. The web console logs nothing at all, a
--      modified client logs nothing, and a failed insert is swallowed.
--
--   3. NOTHING RECORDS ADMINISTRATOR ACTIONS. A console that can revoke
--      sessions or disable accounts must say who did so.
--
-- This migration moves capture into the database, where it cannot be skipped.
--
-- DELIBERATE OMISSION: the trigger records entity type, id, and the NAMES of
-- changed columns — never their values. CaseFlow holds privileged
-- advocate-client material, and the admin console reads this table. Storing
-- case titles or client names here would smuggle exactly the data the console
-- is designed not to expose.
-- ═══════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────
-- 1. MAKE THE TRAIL SURVIVE THE ACCOUNT
-- ─────────────────────────────────────────────────────────

-- Denormalised actor, so a deleted user's history stays attributable.
ALTER TABLE public.audit_logs ADD COLUMN IF NOT EXISTS actor_email TEXT;
ALTER TABLE public.audit_logs ADD COLUMN IF NOT EXISTS actor_name  TEXT;

COMMENT ON COLUMN public.audit_logs.actor_email IS
  'Actor email captured at write time. Survives deletion of the auth.users row.';

-- Backfill from the accounts that still exist.
UPDATE public.audit_logs a
   SET actor_email = u.email,
       actor_name  = p.full_name
  FROM auth.users u
  LEFT JOIN public.profiles p ON p.id = u.id
 WHERE a.user_id = u.id
   AND a.actor_email IS NULL;

-- user_id must become nullable before the FK can SET NULL.
ALTER TABLE public.audit_logs ALTER COLUMN user_id DROP NOT NULL;

ALTER TABLE public.audit_logs DROP CONSTRAINT IF EXISTS audit_logs_user_id_fkey;
ALTER TABLE public.audit_logs
  ADD CONSTRAINT audit_logs_user_id_fkey
  FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;


-- ─────────────────────────────────────────────────────────
-- 2. CAPTURE IN THE DATABASE
--
-- One generic trigger function for every audited table. auth.uid() identifies
-- the actor for anything coming through PostgREST; it is NULL for service-role
-- and cron work, which is recorded as such rather than mis-attributed.
-- ─────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.fn_audit_row()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_actor   UUID := auth.uid();
  v_action  TEXT;
  v_id      UUID;
  v_changed TEXT[];
  v_email   TEXT;
  v_name    TEXT;
BEGIN
  IF TG_OP = 'INSERT' THEN
    v_action := 'create';  v_id := NEW.id;
  ELSIF TG_OP = 'UPDATE' THEN
    v_action := 'update';  v_id := NEW.id;
    -- Column NAMES only. Values would put privileged content in the log.
    SELECT array_agg(n.key ORDER BY n.key) INTO v_changed
      FROM jsonb_each(to_jsonb(NEW)) n
      JOIN jsonb_each(to_jsonb(OLD)) o ON o.key = n.key
     WHERE n.value IS DISTINCT FROM o.value;

    -- A no-op UPDATE is not an event worth recording.
    IF v_changed IS NULL OR array_length(v_changed, 1) IS NULL THEN
      RETURN NULL;
    END IF;
  ELSE
    v_action := 'delete';  v_id := OLD.id;
  END IF;

  IF v_actor IS NOT NULL THEN
    SELECT u.email, p.full_name INTO v_email, v_name
      FROM auth.users u
      LEFT JOIN public.profiles p ON p.id = u.id
     WHERE u.id = v_actor;
  END IF;

  INSERT INTO public.audit_logs
    (user_id, actor_email, actor_name, action, entity, entity_id, details, context)
  VALUES
    (v_actor,
     v_email,
     v_name,
     v_action,
     TG_TABLE_NAME,
     v_id,
     CASE WHEN v_changed IS NULL THEN NULL
          ELSE jsonb_build_object('changed_columns', to_jsonb(v_changed)) END,
     CASE WHEN v_actor IS NULL THEN 'server' ELSE 'api' END);

  RETURN NULL;   -- AFTER trigger; return value is ignored
EXCEPTION WHEN OTHERS THEN
  -- An audit failure must never block the business write.
  RAISE WARNING 'Audit trigger failed on %: %', TG_TABLE_NAME, SQLERRM;
  RETURN NULL;
END;
$fn$;

REVOKE ALL ON FUNCTION public.fn_audit_row() FROM PUBLIC, anon, authenticated;

-- Attach to every entity the console reports on.
DO $attach$
DECLARE t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'cases','clients','hearings','payments',
    'efiling_records','certified_copies','strategy_tasks','caveats'
  ] LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS trg_audit_%1$s ON public.%1$I', t);
    EXECUTE format(
      'CREATE TRIGGER trg_audit_%1$s
         AFTER INSERT OR UPDATE OR DELETE ON public.%1$I
         FOR EACH ROW EXECUTE FUNCTION public.fn_audit_row()', t);
  END LOOP;
END
$attach$;


-- ─────────────────────────────────────────────────────────
-- 3. ADMINISTRATOR ACTIONS
--
-- Console actions (revoke sessions, disable an account, change a plan) run
-- server-side where auth.uid() is NULL, so they cannot be captured by the
-- table triggers. This is the explicit write path for them, callable only by
-- the service role from the admin edge function.
-- ─────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.record_admin_action(
  p_admin_id   UUID,
  p_action     TEXT,
  p_entity     TEXT,
  p_entity_id  UUID DEFAULT NULL,
  p_details    JSONB DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE v_email TEXT; v_name TEXT;
BEGIN
  SELECT u.email, p.full_name INTO v_email, v_name
    FROM auth.users u LEFT JOIN public.profiles p ON p.id = u.id
   WHERE u.id = p_admin_id;

  INSERT INTO public.audit_logs
    (user_id, actor_email, actor_name, action, entity, entity_id, details, context)
  VALUES
    (p_admin_id, v_email, v_name, p_action, p_entity, p_entity_id, p_details, 'admin');
END;
$fn$;

REVOKE ALL ON FUNCTION public.record_admin_action(UUID, TEXT, TEXT, UUID, JSONB)
  FROM PUBLIC, anon, authenticated;


-- ─────────────────────────────────────────────────────────
-- 4. KEEP IT APPEND-ONLY
--
-- There is deliberately no UPDATE or DELETE policy: with RLS enabled and no
-- policy, both are denied. Stated here so a future reader does not "helpfully"
-- add one. The existing INSERT policy stays for the client-side AuditLogger,
-- which still records things the database cannot observe — exports, AI
-- queries, sign-ins and screen context.
-- ─────────────────────────────────────────────────────────

CREATE INDEX IF NOT EXISTS idx_audit_logs_entity_created
  ON public.audit_logs (entity, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_logs_user_created
  ON public.audit_logs (user_id, created_at DESC);
