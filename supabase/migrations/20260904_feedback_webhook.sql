-- ═══════════════════════════════════════════════════════════════
-- Database Webhook Trigger: user_feedback → feedback-telegram
-- Automatically invokes the feedback-telegram Edge Function
-- whenever a new row is inserted into public.user_feedback
-- ═══════════════════════════════════════════════════════════════

-- 1. Ensure pg_net extension is available
CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA net;

-- 2. Trigger function that posts the new feedback row to the Edge Function
CREATE OR REPLACE FUNCTION public.trigger_feedback_telegram_webhook()
RETURNS TRIGGER AS $$
DECLARE
  edge_function_url TEXT := 'https://asrjqsnyezvcakvkokcl.supabase.co/functions/v1/feedback-telegram';
  request_payload JSONB;
BEGIN
  -- Build the webhook payload matching Supabase standard webhook format
  request_payload := jsonb_build_object(
    'type', 'INSERT',
    'table', 'user_feedback',
    'schema', 'public',
    'record', row_to_json(NEW)
  );

  -- Asynchronously post to the Edge Function via pg_net
  PERFORM net.http_post(
    url := edge_function_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json'
    ),
    body := request_payload,
    timeout_milliseconds := 5000
  );

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  -- Never block user feedback submission if the notification fails
  RAISE WARNING 'Feedback Telegram webhook failed: %', SQLERRM;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Attach trigger to user_feedback table
DROP TRIGGER IF EXISTS trg_user_feedback_telegram ON public.user_feedback;

CREATE TRIGGER trg_user_feedback_telegram
  AFTER INSERT ON public.user_feedback
  FOR EACH ROW
  EXECUTE FUNCTION public.trigger_feedback_telegram_webhook();
