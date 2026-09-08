-- ═══════════════════════════════════════════════════════════════
-- Notification triggers & cron schedules
--
-- This migration sets up:
--   1. pg_cron hearing reminder schedules (9 AM, 7 PM, 9 PM IST)
--   2. SQL trigger for DM notifications (direct_messages INSERT)
--   3. SQL trigger for Chat notifications (case_discussions INSERT)
--
-- Auth mechanism:
--   Edge functions use verifyWebhookAuth() which now accepts a
--   custom `x-pg-trigger-secret` header. The shared secret is:
--   - Stored as a Supabase Edge Function secret: PG_TRIGGER_SECRET
--   - Stored in Supabase vault for SQL functions to read at runtime
--
-- ⚠️  PREREQUISITE: Before running this migration, set the secret:
--   1. Generate a random string: openssl rand -hex 32
--   2. Set it as edge function secret:
--        supabase secrets set PG_TRIGGER_SECRET=<your-random-string>
--   3. The migration below stores it in vault automatically.
--      BUT you must replace YOUR_TRIGGER_SECRET_HERE below with 
--      the same random string you used in step 2.
-- ═══════════════════════════════════════════════════════════════

-- Ensure required extensions
CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA cron;
CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA net;

-- ─────────────────────────────────────────────────────────
-- Store the shared trigger secret in vault
-- Replace the placeholder below with your actual secret!
-- ─────────────────────────────────────────────────────────

-- Remove old secret if exists, then insert fresh
DELETE FROM vault.secrets WHERE name = 'pg_trigger_secret';
INSERT INTO vault.secrets (name, secret)
VALUES ('pg_trigger_secret', 'caseflow_pg_trigger_2024_secure_key');


-- ─────────────────────────────────────────────────────────
-- Helper: Read the trigger secret from vault
-- ─────────────────────────────────────────────────────────

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
-- 1. HEARING REMINDER CRON JOBS
-- ─────────────────────────────────────────────────────────

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    RAISE NOTICE 'pg_cron not available — skipping hearing reminder schedules';
    RETURN;
  END IF;

  -- ── Morning 9:00 AM IST = 3:30 AM UTC ──────────────────
  BEGIN
    PERFORM cron.unschedule('hearing-reminder-morning');
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  PERFORM cron.schedule(
    'hearing-reminder-morning',
    '30 3 * * *',
    $cron$
    SELECT net.http_post(
      url := 'https://asrjqsnyezvcakvkokcl.supabase.co/functions/v1/send-hearing-reminders?type=morning_9am',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-pg-trigger-secret', (SELECT public.get_pg_trigger_secret())
      ),
      body := '{"reminder_type":"morning_9am"}'::jsonb,
      timeout_milliseconds := 30000
    );
    $cron$
  );
  RAISE NOTICE 'Scheduled hearing-reminder-morning at 3:30 UTC (9:00 AM IST)';

  -- ── Evening 7:00 PM IST = 1:30 PM UTC ──────────────────
  BEGIN
    PERFORM cron.unschedule('hearing-reminder-evening-7pm');
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  PERFORM cron.schedule(
    'hearing-reminder-evening-7pm',
    '30 13 * * *',
    $cron$
    SELECT net.http_post(
      url := 'https://asrjqsnyezvcakvkokcl.supabase.co/functions/v1/send-hearing-reminders?type=evening_7pm',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-pg-trigger-secret', (SELECT public.get_pg_trigger_secret())
      ),
      body := '{"reminder_type":"evening_7pm"}'::jsonb,
      timeout_milliseconds := 30000
    );
    $cron$
  );
  RAISE NOTICE 'Scheduled hearing-reminder-evening-7pm at 13:30 UTC (7:00 PM IST)';

  -- ── Evening 9:00 PM IST = 3:30 PM UTC ──────────────────
  BEGIN
    PERFORM cron.unschedule('hearing-reminder-evening-9pm');
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  PERFORM cron.schedule(
    'hearing-reminder-evening-9pm',
    '30 15 * * *',
    $cron$
    SELECT net.http_post(
      url := 'https://asrjqsnyezvcakvkokcl.supabase.co/functions/v1/send-hearing-reminders?type=evening_9pm',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-pg-trigger-secret', (SELECT public.get_pg_trigger_secret())
      ),
      body := '{"reminder_type":"evening_9pm"}'::jsonb,
      timeout_milliseconds := 30000
    );
    $cron$
  );
  RAISE NOTICE 'Scheduled hearing-reminder-evening-9pm at 15:30 UTC (9:00 PM IST)';

END $$;


-- ─────────────────────────────────────────────────────────
-- 2. DM NOTIFICATION TRIGGER (direct_messages INSERT)
-- ─────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.trigger_dm_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, net
AS $$
DECLARE
  payload  JSONB;
  trigger_secret TEXT;
BEGIN
  -- Read shared secret from vault
  trigger_secret := public.get_pg_trigger_secret();

  -- Build webhook-style payload
  payload := jsonb_build_object(
    'type', 'INSERT',
    'table', 'direct_messages',
    'record', jsonb_build_object(
      'id', NEW.id,
      'sender_id', NEW.sender_id,
      'conversation_id', NEW.conversation_id,
      'message', COALESCE(NEW.message, ''),
      'attachment_type', NEW.attachment_type,
      'attachment_url', NEW.attachment_url
    )
  );

  -- Fire-and-forget HTTP POST via pg_net
  PERFORM net.http_post(
    url := 'https://asrjqsnyezvcakvkokcl.supabase.co/functions/v1/send-dm-notification',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-pg-trigger-secret', trigger_secret
    ),
    body := payload,
    timeout_milliseconds := 10000
  );

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  -- Never break a message insert because of notification failure
  RAISE WARNING 'DM notification trigger failed: %', SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_dm_insert_notify ON public.direct_messages;

CREATE TRIGGER on_dm_insert_notify
  AFTER INSERT ON public.direct_messages
  FOR EACH ROW
  EXECUTE FUNCTION public.trigger_dm_notification();


-- ─────────────────────────────────────────────────────────
-- 3. CHAT NOTIFICATION TRIGGER (case_discussions INSERT)
-- ─────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.trigger_chat_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, net
AS $$
DECLARE
  payload  JSONB;
  trigger_secret TEXT;
BEGIN
  -- Skip system messages
  IF NEW.is_system = TRUE THEN
    RETURN NEW;
  END IF;

  -- Read shared secret from vault
  trigger_secret := public.get_pg_trigger_secret();

  -- Build webhook-style payload
  payload := jsonb_build_object(
    'type', 'INSERT',
    'table', 'case_discussions',
    'record', jsonb_build_object(
      'id', NEW.id,
      'sender_id', NEW.sender_id,
      'firm_id', NEW.firm_id,
      'case_id', NEW.case_id,
      'message', COALESCE(NEW.message, ''),
      'sender_name', COALESCE(NEW.sender_name, 'Team Member'),
      'attachment_type', NEW.attachment_type,
      'is_system', COALESCE(NEW.is_system, false)
    )
  );

  -- Fire-and-forget HTTP POST via pg_net
  PERFORM net.http_post(
    url := 'https://asrjqsnyezvcakvkokcl.supabase.co/functions/v1/send-chat-notification',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-pg-trigger-secret', trigger_secret
    ),
    body := payload,
    timeout_milliseconds := 10000
  );

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'Chat notification trigger failed: %', SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_chat_insert_notify ON public.case_discussions;

CREATE TRIGGER on_chat_insert_notify
  AFTER INSERT ON public.case_discussions
  FOR EACH ROW
  EXECUTE FUNCTION public.trigger_chat_notification();
