-- ─────────────────────────────────────────────────────────
-- Push what a bar association publishes to its members' phones.
--
-- bar_notices already had a trigger, but it only called
-- record_notification(), which writes a row into the in-app Notification
-- Centre and nothing else — there is no trigger on public.notifications and
-- record_notification() makes no FCM call. So a bar notice reached an
-- advocate whenever they next opened CaseFlow.
--
-- That is no use for the two things a bar publishes urgently: a court not
-- sitting tomorrow, and a death. By convention the bar does not take up work
-- on the day of a member's death, and an advocate travelling in from a taluk
-- needs to know before they set out — not from another advocate at the court
-- gate.
--
-- Condolences therefore go out at high priority and keep their in-app record
-- as well, matching how notices behave.
-- ─────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.trigger_bar_push(p_kind text, p_row jsonb)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
BEGIN
  PERFORM net.http_post(
    url := current_setting('app.settings.supabase_url', true)
           || '/functions/v1/send-bar-notification',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      -- The trigger sends no Authorization header, so the edge function is
      -- deployed with verify_jwt false and authenticates on this instead.
      'x-pg-trigger-secret', (SELECT public.get_pg_trigger_secret())
    ),
    body := jsonb_build_object('kind', p_kind, 'record', p_row)
  );
EXCEPTION WHEN OTHERS THEN
  -- A failed push must never stop the association from publishing.
  RAISE WARNING 'Bar push (%) failed: %', p_kind, SQLERRM;
END;
$fn$;

REVOKE ALL ON FUNCTION public.trigger_bar_push(text, jsonb) FROM PUBLIC, anon, authenticated;

-- ─── Notices ──────────────────────────────────────────────
-- A separate trigger from the existing in-app one, rather than a rewrite:
-- both the Notification Centre row and the push are wanted.

CREATE OR REPLACE FUNCTION public.trigger_bar_notice_push()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
BEGIN
  IF NEW.scheduled_for IS NOT NULL AND NEW.scheduled_for > now() THEN
    RETURN NEW;
  END IF;
  IF COALESCE(NEW.fcm_sent, false) THEN
    RETURN NEW;
  END IF;

  PERFORM public.trigger_bar_push('notice', to_jsonb(NEW));
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'Bar notice push failed: %', SQLERRM;
  RETURN NEW;
END;
$fn$;

DROP TRIGGER IF EXISTS on_bar_notice_push ON public.bar_notices;
CREATE TRIGGER on_bar_notice_push
  AFTER INSERT ON public.bar_notices
  FOR EACH ROW EXECUTE FUNCTION public.trigger_bar_notice_push();

-- ─── Condolences ──────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.trigger_bar_condolence_push()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  r RECORD;
  v_meeting text;
BEGIN
  v_meeting := CASE
    WHEN NEW.meeting_at IS NOT NULL
      THEN ' Condolence meeting ' ||
           to_char(NEW.meeting_at AT TIME ZONE 'Asia/Kolkata', 'DD Mon, HH12:MI AM') || '.'
    ELSE ''
  END;

  FOR r IN
    SELECT bm.user_id AS uid
      FROM public.bar_members bm
     WHERE bm.association_id = NEW.association_id
       AND bm.status = 'active'
       AND bm.user_id IS NOT NULL
       AND bm.user_id IS DISTINCT FROM NEW.published_by
  LOOP
    PERFORM public.record_notification(
      r.uid,
      'bar_condolence',
      NEW.deceased_name || ' — condolence',
      CASE WHEN NEW.no_work_resolution
           THEN 'The bar will not take up work.' || v_meeting
           ELSE trim(v_meeting) END,
      '/bar-association',
      jsonb_build_object(
        'condolence_id', NEW.id,
        'association_id', NEW.association_id
      ),
      'bar_condolence:' || NEW.id || ':' || r.uid
    );
  END LOOP;

  PERFORM public.trigger_bar_push('condolence', to_jsonb(NEW));
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'Bar condolence notification failed: %', SQLERRM;
  RETURN NEW;
END;
$fn$;

DROP TRIGGER IF EXISTS on_bar_condolence_notify ON public.bar_condolences;
CREATE TRIGGER on_bar_condolence_notify
  AFTER INSERT ON public.bar_condolences
  FOR EACH ROW EXECUTE FUNCTION public.trigger_bar_condolence_push();
