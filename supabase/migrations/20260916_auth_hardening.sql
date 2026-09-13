-- ═══════════════════════════════════════════════════════════════
-- Authentication hardening
--
-- Findings from a security review of the auth surface. Every one below was
-- verified exploitable against the live project before being fixed, and
-- verified closed afterwards.
--
--   CRITICAL  public.get_pg_trigger_secret() was callable by `anon`.
--             An unauthenticated POST to /rest/v1/rpc/get_pg_trigger_secret
--             carrying only the public anon key — which ships inside the
--             released APK — returned the decrypted shared secret that
--             authenticates every notification edge function. Those functions
--             build a SERVICE-ROLE client and bypass RLS, so this was an
--             anonymous path to service-role-backed writes.
--
--   HIGH      public.profiles was readable by `anon` via a
--             SELECT / public / USING (true) policy. An unauthenticated call
--             returned all 18 profiles: name, email, mobile, registration
--             number, office address.
--
--   HIGH      Any authenticated user could DELETE any other user's profile
--             (DELETE / authenticated / USING (true)).
--
--   HIGH      Any authenticated user could set is_admin = true on their own
--             profile. The web dashboard's admin gate reads exactly that
--             column, so this was a one-statement path to administrator.
--
-- RLS policies are OR'd, which is why the three permissive policies on
-- `profiles` silently nullified the eight scoped ones sitting beside them.
-- ═══════════════════════════════════════════════════════════════


-- ─────────────────────────────────────────────────────────
-- 1. The secret reader must not be a public endpoint
--
-- PostgREST exposes every function in `public` as an RPC and grants EXECUTE to
-- anon/authenticated by default. The trigger functions are revoked for the
-- same reason; that is safe because a trigger function is invoked by the
-- executor, not by the querying role, so no caller needs EXECUTE on it.
--
-- NOT revoked, deliberately:
--   • is_association_member / is_association_admin — called from inside 18 RLS
--     policies, which evaluate as the querying user. Revoking would break
--     every bar-association read and write.
--   • get_vote_counts — the only function the client calls via .rpc().
-- ─────────────────────────────────────────────────────────

REVOKE ALL ON FUNCTION public.get_pg_trigger_secret()                FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION public.handle_new_user()                      FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.increment_notice_read_count()          FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.notify_chat_message()                  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.notify_dm_message()                    FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.on_sync_notification_created()         FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.trigger_chat_notification()            FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.trigger_dm_notification()              FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.trigger_feedback_telegram_webhook()    FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.update_chat_session_timestamp()        FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.update_member_fee_status()             FROM PUBLIC, anon, authenticated;

-- A mutable search_path on a SECURITY DEFINER function lets a caller who can
-- create objects shadow what the body resolves to.
ALTER FUNCTION public.get_pg_trigger_secret() SET search_path = public, vault;


-- ─────────────────────────────────────────────────────────
-- 2. profiles — SELECT
--
-- Remove every `public`-role read. `public` includes `anon`, which is what
-- made the directory world-readable. Nothing needs profile data before
-- sign-in: the guest routes are tools / track-case / know-your-rights, and
-- fetchProfile() only runs once a session exists.
--
-- "Allow all users to read profiles" (authenticated, true) is KEPT: the app
-- relies on profiles:owner_id(full_name)-style joins throughout (firm
-- invitations, case collaborators, chat sender names) and narrowing it now
-- would break them. Restricting that to a column-limited view is follow-up
-- work — it still exposes email and mobile to any signed-in user.
-- ─────────────────────────────────────────────────────────

DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON public.profiles;
DROP POLICY IF EXISTS "Anyone can view public profiles"          ON public.profiles;
DROP POLICY IF EXISTS "Users can only view their own profile"    ON public.profiles;
DROP POLICY IF EXISTS "Users can view own profile"               ON public.profiles;
DROP POLICY IF EXISTS "Users can view their own profile"         ON public.profiles;


-- ─────────────────────────────────────────────────────────
-- 3. profiles — INSERT / UPDATE / DELETE
-- ─────────────────────────────────────────────────────────

-- WITH CHECK (true) let any signed-in user create a row under any id.
DROP POLICY IF EXISTS "Enable insert for authenticated users" ON public.profiles;
DROP POLICY IF EXISTS "Users can insert their own profile"    ON public.profiles;
CREATE POLICY "Users can insert their own profile"
  ON public.profiles FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = id);

-- The old UPDATE policies had USING but no WITH CHECK, so the row could be
-- re-pointed at another user's id.
DROP POLICY IF EXISTS "Users can only update their own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can update their own profile"      ON public.profiles;
CREATE POLICY "Users can update their own profile"
  ON public.profiles FOR UPDATE TO authenticated
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "Enable delete for authenticated users" ON public.profiles;
DROP POLICY IF EXISTS "Users can delete their own profile"    ON public.profiles;
CREATE POLICY "Users can delete their own profile"
  ON public.profiles FOR DELETE TO authenticated
  USING (auth.uid() = id);


-- ─────────────────────────────────────────────────────────
-- 4. Privilege columns are not self-service
--
-- RLS gates rows, not columns, so no WITH CHECK can stop a user flipping
-- is_admin on a row they legitimately own. This pins the privilege- and
-- billing-bearing columns whenever the row is updated by its own owner
-- through the API.
--
-- auth.uid() is NULL for service-role and for SECURITY DEFINER server code, so
-- billing webhooks, admin tooling and handle_new_user are unaffected. Verified
-- beforehand that no client code writes any of these columns.
-- ─────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.protect_profile_privilege_columns()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() = NEW.id THEN
    NEW.id                 := OLD.id;
    NEW.is_admin           := OLD.is_admin;
    NEW.user_role          := OLD.user_role;
    NEW.subscription_tier  := OLD.subscription_tier;
    NEW.trial_ends_at      := OLD.trial_ends_at;
    NEW.current_period_end := OLD.current_period_end;
  END IF;
  RETURN NEW;
END;
$fn$;

REVOKE ALL ON FUNCTION public.protect_profile_privilege_columns() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_protect_profile_privileges ON public.profiles;
CREATE TRIGGER trg_protect_profile_privileges
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.protect_profile_privilege_columns();
