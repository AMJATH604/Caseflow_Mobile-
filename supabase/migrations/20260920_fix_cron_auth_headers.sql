-- ═══════════════════════════════════════════════════════════════
-- Fix two cron jobs that have failed on every run
--
--   caveat-reminder-9am       read current_setting('app.settings.service_role_key'),
--                             which is not set on hosted Supabase:
--                             ERROR: unrecognized configuration parameter
--   daily-case-sync-monitor   read current_setting('request.headers'), which only
--                             exists inside a PostgREST request, never in pg_cron:
--                             ERROR: invalid input syntax for type json
--
-- Caveat reminders have therefore never been sent. Both jobs now authenticate
-- the way every working job does: the x-pg-trigger-secret header, read from
-- vault by public.get_pg_trigger_secret(). That also removes their dependency on
-- the legacy service_role key, which is being retired after it leaked into the
-- repository.
--
-- Schedules are unchanged (UTC):
--   03:30 = 09:00 IST   caveat reminders
--   13:15 = 18:45 IST   case sync monitor
-- ═══════════════════════════════════════════════════════════════

DO $$ BEGIN PERFORM cron.unschedule('caveat-reminder-9am');
EXCEPTION WHEN OTHERS THEN NULL; END $$;

SELECT cron.schedule(
  'caveat-reminder-9am',
  '30 3 * * *',
  $cron$
    SELECT net.http_post(
      url := 'https://asrjqsnyezvcakvkokcl.supabase.co/functions/v1/send-caveat-reminders',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-pg-trigger-secret', (SELECT public.get_pg_trigger_secret())
      ),
      body := '{}'::jsonb,
      timeout_milliseconds := 30000
    );
  $cron$
);

DO $$ BEGIN PERFORM cron.unschedule('daily-case-sync-monitor');
EXCEPTION WHEN OTHERS THEN NULL; END $$;

SELECT cron.schedule(
  'daily-case-sync-monitor',
  '15 13 * * *',
  $cron$
    SELECT net.http_post(
      url := 'https://asrjqsnyezvcakvkokcl.supabase.co/functions/v1/sync-case-monitor',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-pg-trigger-secret', (SELECT public.get_pg_trigger_secret())
      ),
      body := '{}'::jsonb,
      timeout_milliseconds := 30000
    );
  $cron$
);


-- ─────────────────────────────────────────────────────────
-- fetch-legal-news-job and generate-carousel-daily sent no credential at all.
-- They only worked because the DEPLOYED copies of those functions predate the
-- auth guard: fetch-legal-news answered an unauthenticated request with 200.
-- The repository versions call verifyWebhookAuth(), so deploying them would
-- start rejecting these jobs. Send the trigger secret now so the redeploy is
-- safe. Schedules unchanged (UTC): every 30 min; 22:30 = 04:00 IST.
-- ─────────────────────────────────────────────────────────
DO $$ BEGIN PERFORM cron.unschedule('fetch-legal-news-job');
EXCEPTION WHEN OTHERS THEN NULL; END $$;

SELECT cron.schedule(
  'fetch-legal-news-job',
  '*/30 * * * *',
  $cron$
    SELECT net.http_get(
      url := 'https://asrjqsnyezvcakvkokcl.supabase.co/functions/v1/fetch-legal-news',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-pg-trigger-secret', (SELECT public.get_pg_trigger_secret())
      ),
      timeout_milliseconds := 30000
    );
  $cron$
);

DO $$ BEGIN PERFORM cron.unschedule('generate-carousel-daily');
EXCEPTION WHEN OTHERS THEN NULL; END $$;

SELECT cron.schedule(
  'generate-carousel-daily',
  '30 22 * * *',
  $cron$
    SELECT net.http_post(
      url := 'https://asrjqsnyezvcakvkokcl.supabase.co/functions/v1/generate-carousel',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-pg-trigger-secret', (SELECT public.get_pg_trigger_secret())
      ),
      body := '{}'::jsonb,
      timeout_milliseconds := 60000
    );
  $cron$
);
