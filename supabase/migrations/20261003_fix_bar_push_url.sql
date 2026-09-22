-- Bar pushes could never have worked, independently of the edge function
-- being undeployed.
--
-- trigger_bar_push built its URL from
--   current_setting('app.settings.supabase_url', true)
-- a GUC that was never set on this project. The `true` argument means
-- "missing setting returns NULL instead of raising", so the URL evaluated to
--   NULL || '/functions/v1/send-bar-notification'  =  NULL
-- net.http_post rejected that, and the function's own EXCEPTION handler
-- turned the failure into a WARNING nobody reads. Every bar notice and every
-- condolence push failed silently, leaving no trace in net._http_response
-- because the request was never made.
--
-- Every other notification trigger in this database hardcodes the project
-- URL. Match them, but keep the setting as an override so another
-- environment can still point somewhere else.
--
-- One change covers both paths: trigger_bar_notice_push and
-- trigger_bar_condolence_push each delegate here.

CREATE OR REPLACE FUNCTION public.trigger_bar_push(p_kind text, p_row jsonb)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_base text;
BEGIN
  v_base := coalesce(
    nullif(current_setting('app.settings.supabase_url', true), ''),
    'https://asrjqsnyezvcakvkokcl.supabase.co'
  );

  PERFORM net.http_post(
    url := v_base || '/functions/v1/send-bar-notification',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-pg-trigger-secret', (SELECT public.get_pg_trigger_secret())
    ),
    body := jsonb_build_object('kind', p_kind, 'record', p_row)
  );
EXCEPTION WHEN OTHERS THEN
  -- A failed push must never block the association from publishing.
  RAISE WARNING 'Bar push (%) failed: %', p_kind, SQLERRM;
END;
$function$;

-- A SECURITY DEFINER function in public is exposed as a PostgREST RPC by
-- default. This one takes the row to broadcast as an argument, so leaving it
-- callable would let any signed-in user push a notification to a whole bar.
REVOKE ALL ON FUNCTION public.trigger_bar_push(text, jsonb)
  FROM PUBLIC, anon, authenticated;

-- The two trigger functions that delegate here were themselves exposed at
-- /rest/v1/rpc/ as SECURITY DEFINER, which the security advisor flags.
-- A trigger function needs no EXECUTE grant to fire — it runs as the trigger
-- owner — and calling these directly would fail on the unassigned NEW record
-- rather than push anything. Still, an endpoint that cannot work should not
-- be reachable.
REVOKE ALL ON FUNCTION public.trigger_bar_notice_push()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.trigger_bar_condolence_push()
  FROM PUBLIC, anon, authenticated;
