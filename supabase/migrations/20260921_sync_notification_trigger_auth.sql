-- ═══════════════════════════════════════════════════════════════
-- Authenticate the sync_notifications → send-sync-notifications call
--
-- send-sync-notifications was deployed with no authentication and accepted any
-- user_id, title and message from anyone holding the app's public key. It now
-- runs verifyWebhookAuth(), so the trigger that calls it must present the
-- shared trigger secret like every other trigger in the notification pipeline.
--
-- Also brings the function up to house style: pinned search_path (the security
-- advisor flagged it as mutable), and an exception handler so a failed push can
-- never roll back the sync_notifications insert.
-- ═══════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.on_sync_notification_created()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
BEGIN
  PERFORM net.http_post(
    url := 'https://asrjqsnyezvcakvkokcl.supabase.co/functions/v1/send-sync-notifications',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-pg-trigger-secret', (SELECT public.get_pg_trigger_secret())
    ),
    body := jsonb_build_object(
      'notification_id', NEW.id,
      'user_id', NEW.user_id,
      'title', NEW.title,
      'message', NEW.body
    ),
    timeout_milliseconds := 30000
  );
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'on_sync_notification_created: push request failed: %', SQLERRM;
  RETURN NEW;
END;
$fn$;

-- Trigger functions are not meant to be RPCs.
REVOKE ALL ON FUNCTION public.on_sync_notification_created() FROM PUBLIC, anon, authenticated;
