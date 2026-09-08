-- ═══════════════════════════════════════════════════════════════
-- Invitation notifications
--
-- Sends an FCM push (via the send-invitation-notification edge function) when
-- someone is invited:
--   • firm_members        INSERT (status pending) → "X invited you to join…"
--   • case_collaborations  INSERT (status pending) → "X shared a case with you"
--
-- Uses the same x-pg-trigger-secret mechanism as the DM/chat triggers.
--
-- ⚠️ PREREQUISITES (same as 20260908_notification_triggers.sql):
--   1. Edge secret set:  supabase secrets set PG_TRIGGER_SECRET=<random>
--   2. Vault secret 'pg_trigger_secret' set to the SAME value (the
--      notification-triggers migration does this; get_pg_trigger_secret()
--      reads it). This migration (re)creates that helper idempotently so it is
--      self-sufficient, but the vault secret must exist for auth to pass.
--   3. Deploy the function:  supabase functions deploy send-invitation-notification
-- ═══════════════════════════════════════════════════════════════

CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA net;

-- Helper: read the shared trigger secret from vault (idempotent redefinition).
CREATE OR REPLACE FUNCTION public.get_pg_trigger_secret()
RETURNS TEXT
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT decrypted_secret
  FROM vault.decrypted_secrets
  WHERE name = 'pg_trigger_secret'
  LIMIT 1;
$$;

-- ─────────────────────────────────────────────────────────
-- 1. FIRM INVITATION (firm_members INSERT)
-- ─────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.trigger_firm_invitation_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, net
AS $$
DECLARE
  payload JSONB;
BEGIN
  IF NEW.status IS DISTINCT FROM 'pending' THEN
    RETURN NEW;
  END IF;

  payload := jsonb_build_object(
    'type', 'INSERT',
    'table', 'firm_members',
    'record', jsonb_build_object(
      'id', NEW.id,
      'owner_id', NEW.owner_id,
      'member_id', NEW.member_id,
      'member_email', NEW.member_email,
      'status', NEW.status
    )
  );

  PERFORM net.http_post(
    url := 'https://asrjqsnyezvcakvkokcl.supabase.co/functions/v1/send-invitation-notification',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-pg-trigger-secret', public.get_pg_trigger_secret()
    ),
    body := payload,
    timeout_milliseconds := 10000
  );

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  -- Never break an invite insert because of a notification failure.
  RAISE WARNING 'Firm invitation notification trigger failed: %', SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_firm_member_insert_notify ON public.firm_members;
CREATE TRIGGER on_firm_member_insert_notify
  AFTER INSERT ON public.firm_members
  FOR EACH ROW
  EXECUTE FUNCTION public.trigger_firm_invitation_notification();

-- ─────────────────────────────────────────────────────────
-- 2. CASE INVITATION (case_collaborations INSERT)
-- ─────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.trigger_case_invitation_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, net
AS $$
DECLARE
  payload JSONB;
BEGIN
  IF NEW.status IS DISTINCT FROM 'pending' THEN
    RETURN NEW;
  END IF;

  payload := jsonb_build_object(
    'type', 'INSERT',
    'table', 'case_collaborations',
    'record', jsonb_build_object(
      'id', NEW.id,
      'owner_id', NEW.owner_id,
      'collaborator_id', NEW.collaborator_id,
      'collaborator_email', NEW.collaborator_email,
      'case_id', NEW.case_id,
      'status', NEW.status
    )
  );

  PERFORM net.http_post(
    url := 'https://asrjqsnyezvcakvkokcl.supabase.co/functions/v1/send-invitation-notification',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-pg-trigger-secret', public.get_pg_trigger_secret()
    ),
    body := payload,
    timeout_milliseconds := 10000
  );

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'Case invitation notification trigger failed: %', SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_case_collab_insert_notify ON public.case_collaborations;
CREATE TRIGGER on_case_collab_insert_notify
  AFTER INSERT ON public.case_collaborations
  FOR EACH ROW
  EXECUTE FUNCTION public.trigger_case_invitation_notification();
