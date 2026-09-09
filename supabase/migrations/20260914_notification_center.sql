-- ═══════════════════════════════════════════════════════════════
-- Notification Center
--
-- The "Updates" screen in the More hub was a placeholder: it listed the
-- user's cases and stamped every row with DateTime.now(), so it showed the
-- current clock time rather than an event time. Meanwhile every push
-- notification CaseFlow sends (DM, chambers, invitation, hearing, caveat)
-- is fire-and-forget — nothing is persisted. A push that arrives while the
-- phone is off, gets swiped away, or is never delivered because the user
-- declined notification permission is gone with no in-app record of it.
--
-- This migration adds the missing store:
--   1. public.notifications — one row per recipient per event
--   2. public.record_notification() — the single write path
--   3. Four triggers for events that had no notification at all today
--      (case status change, task assignment, payment, bar notice)
--   4. Two cron jobs — the daily "task due" sweep, and the 24-hour purge
--
-- Retention: notifications are transient by design. A rolling 24-hour
-- window is purged hourly (NOT a fixed daily wipe, which would delete an
-- 11:55 PM notification five minutes after it arrived). This is the first
-- retention job in the project.
--
-- Chat is deliberately EXCLUDED. Direct messages and Chambers messages keep
-- their existing push plus in-chat unread state; routing them here too would
-- drown the feed and double-count against the chat hub's own badge.
-- ═══════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────
-- 1. TABLE
-- ─────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.notifications (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  type       TEXT NOT NULL CHECK (type IN (
               'hearing_reminder','caveat_reminder','invitation',
               'case_status','task_assigned','task_due','payment','bar_notice')),
  title      TEXT NOT NULL,
  body       TEXT NOT NULL DEFAULT '',
  -- go_router path pushed when the row is tapped, e.g. '/cases/<uuid>'.
  route      TEXT,
  -- Type-specific ids (case_id, task_id, …) for future use by the client.
  payload    JSONB NOT NULL DEFAULT '{}'::jsonb,
  -- Retry guard. A cron job or webhook that fires twice for the same logical
  -- event reuses the same key and the second insert is silently dropped.
  dedupe_key TEXT,
  read_at    TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.notifications IS
  'In-app notification centre. One row per recipient per event. Rows older than 24 hours are purged hourly by the purge-expired-notifications cron job.';

-- Feed query: newest first, scoped to one user.
CREATE INDEX IF NOT EXISTS idx_notifications_user_created
  ON public.notifications (user_id, created_at DESC);

-- Badge query: unread count for one user.
CREATE INDEX IF NOT EXISTS idx_notifications_unread
  ON public.notifications (user_id)
  WHERE read_at IS NULL;

-- Purge scan.
CREATE INDEX IF NOT EXISTS idx_notifications_created_at
  ON public.notifications (created_at);

-- Backs the ON CONFLICT DO NOTHING in record_notification(). Partial, so the
-- many rows that legitimately carry no dedupe key don't collide with each other.
CREATE UNIQUE INDEX IF NOT EXISTS idx_notifications_dedupe
  ON public.notifications (dedupe_key)
  WHERE dedupe_key IS NOT NULL;


-- ─────────────────────────────────────────────────────────
-- 2. RLS
-- ─────────────────────────────────────────────────────────

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- (No CREATE POLICY IF NOT EXISTS in Postgres, so drop-then-create keeps this
-- script safely re-runnable.)
DROP POLICY IF EXISTS "Users read their own notifications" ON public.notifications;
CREATE POLICY "Users read their own notifications"
  ON public.notifications
  FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users update their own notifications" ON public.notifications;
CREATE POLICY "Users update their own notifications"
  ON public.notifications
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users delete their own notifications" ON public.notifications;
CREATE POLICY "Users delete their own notifications"
  ON public.notifications
  FOR DELETE
  USING (auth.uid() = user_id);

-- Deliberately NO INSERT policy. Rows are written only by the SECURITY DEFINER
-- triggers below and by the service-role edge functions, both of which bypass
-- RLS. A client must never be able to forge a notification for another user.


-- Realtime is required — the unread badge subscribes to postgres_changes on
-- this table and would otherwise only update on a manual refresh.
DO $do$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'notifications'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
  END IF;
END $do$;


-- ─────────────────────────────────────────────────────────
-- 3. THE SINGLE WRITE PATH
-- ─────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.record_notification(
  p_user_id    UUID,
  p_type       TEXT,
  p_title      TEXT,
  p_body       TEXT DEFAULT '',
  p_route      TEXT DEFAULT NULL,
  p_payload    JSONB DEFAULT '{}'::jsonb,
  p_dedupe_key TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
BEGIN
  IF p_user_id IS NULL OR p_title IS NULL THEN
    RETURN;
  END IF;

  INSERT INTO public.notifications
    (user_id, type, title, body, route, payload, dedupe_key)
  VALUES
    (p_user_id, p_type, p_title, COALESCE(p_body, ''), p_route,
     COALESCE(p_payload, '{}'::jsonb), p_dedupe_key)
  ON CONFLICT DO NOTHING;   -- absorbs dedupe_key collisions
END;
$fn$;

COMMENT ON FUNCTION public.record_notification IS
  'Single write path for public.notifications. SECURITY DEFINER so triggers can fan out to users other than the caller. Silently no-ops on a dedupe_key collision.';


-- ─────────────────────────────────────────────────────────
-- 4. TRIGGERS — events that produced no notification before
--
-- Every body follows the convention established in
-- 20260908_notification_triggers.sql: swallow all errors so a notification
-- failure can never block the underlying business write.
--
-- Each uses auth.uid() to skip notifying whoever caused the change. Note that
-- this means a solo advocate who closes their own case or records their own
-- payment gets nothing — deliberate, since self-notification is pure noise.
-- These three only produce rows in multi-user firms and on shared cases.
-- ─────────────────────────────────────────────────────────

-- ── 4a. Case status change ──────────────────────────────
CREATE OR REPLACE FUNCTION public.trigger_case_status_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_actor UUID := auth.uid();
  r       RECORD;
BEGIN
  IF NEW.deleted_at IS NOT NULL THEN
    RETURN NEW;
  END IF;

  FOR r IN
    SELECT uid FROM (
      SELECT NEW.created_by AS uid
      UNION
      SELECT cc.collaborator_id
        FROM public.case_collaborations cc
       WHERE cc.case_id = NEW.id
         AND cc.status = 'accepted'
    ) AS recipients
    WHERE uid IS NOT NULL
      AND uid IS DISTINCT FROM v_actor
  LOOP
    PERFORM public.record_notification(
      r.uid,
      'case_status',
      COALESCE(NEW.case_title, 'Case updated'),
      'Status changed to ' || COALESCE(NEW.status, 'unknown'),
      '/cases/' || NEW.id,
      jsonb_build_object(
        'case_id', NEW.id,
        'status', NEW.status,
        'previous_status', OLD.status
      ),
      NULL
    );
  END LOOP;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'Case status notification failed: %', SQLERRM;
  RETURN NEW;
END;
$fn$;

DROP TRIGGER IF EXISTS on_case_status_notify ON public.cases;
CREATE TRIGGER on_case_status_notify
  AFTER UPDATE ON public.cases
  FOR EACH ROW
  WHEN (OLD.status IS DISTINCT FROM NEW.status)
  EXECUTE FUNCTION public.trigger_case_status_notification();


-- ── 4b. Task assigned ───────────────────────────────────
CREATE OR REPLACE FUNCTION public.trigger_task_assigned_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_actor      UUID := auth.uid();
  v_case_title TEXT;
BEGIN
  IF NEW.assigned_to IS NULL OR NEW.deleted_at IS NOT NULL THEN
    RETURN NEW;
  END IF;

  -- Only fire when the assignee actually changed.
  IF TG_OP = 'UPDATE' AND NEW.assigned_to IS NOT DISTINCT FROM OLD.assigned_to THEN
    RETURN NEW;
  END IF;

  -- Assigning a task to yourself is not news.
  IF NEW.assigned_to IS NOT DISTINCT FROM v_actor THEN
    RETURN NEW;
  END IF;

  SELECT c.case_title INTO v_case_title
    FROM public.cases c
   WHERE c.id = NEW.case_id;

  PERFORM public.record_notification(
    NEW.assigned_to,
    'task_assigned',
    'New task assigned',
    COALESCE(NEW.title, 'Task') || COALESCE(' · ' || v_case_title, ''),
    CASE WHEN NEW.case_id IS NOT NULL THEN '/cases/' || NEW.case_id ELSE NULL END,
    jsonb_build_object('task_id', NEW.id, 'case_id', NEW.case_id),
    'task_assigned:' || NEW.id || ':' || NEW.assigned_to
  );

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'Task assignment notification failed: %', SQLERRM;
  RETURN NEW;
END;
$fn$;

DROP TRIGGER IF EXISTS on_task_assigned_notify ON public.strategy_tasks;
CREATE TRIGGER on_task_assigned_notify
  AFTER INSERT OR UPDATE OF assigned_to ON public.strategy_tasks
  FOR EACH ROW
  EXECUTE FUNCTION public.trigger_task_assigned_notification();


-- ── 4c. Payment recorded ────────────────────────────────
CREATE OR REPLACE FUNCTION public.trigger_payment_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_actor      UUID := auth.uid();
  v_owner      UUID;
  v_case_title TEXT;
BEGIN
  IF NEW.case_id IS NULL OR NEW.deleted_at IS NOT NULL THEN
    RETURN NEW;
  END IF;

  SELECT c.created_by, c.case_title
    INTO v_owner, v_case_title
    FROM public.cases c
   WHERE c.id = NEW.case_id;

  IF v_owner IS NULL OR v_owner IS NOT DISTINCT FROM v_actor THEN
    RETURN NEW;
  END IF;

  PERFORM public.record_notification(
    v_owner,
    'payment',
    'Payment recorded',
    '₹' || TRIM(TO_CHAR(COALESCE(NEW.paid_amount, 0), 'FM999999999990.00'))
         || COALESCE(' · ' || v_case_title, ''),
    '/payments',
    jsonb_build_object(
      'payment_id', NEW.id,
      'case_id', NEW.case_id,
      'paid_amount', NEW.paid_amount
    ),
    'payment:' || NEW.id
  );

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'Payment notification failed: %', SQLERRM;
  RETURN NEW;
END;
$fn$;

DROP TRIGGER IF EXISTS on_payment_notify ON public.payments;
CREATE TRIGGER on_payment_notify
  AFTER INSERT ON public.payments
  FOR EACH ROW
  EXECUTE FUNCTION public.trigger_payment_notification();


-- ── 4d. Bar association notice ──────────────────────────
CREATE OR REPLACE FUNCTION public.trigger_bar_notice_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  r RECORD;
BEGIN
  -- A notice queued for later publication shouldn't notify now.
  IF NEW.scheduled_for IS NOT NULL AND NEW.scheduled_for > now() THEN
    RETURN NEW;
  END IF;

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
      'bar_notice',
      COALESCE(NEW.title, 'Bar notice'),
      COALESCE(NEW.body, ''),
      '/bar-association',
      jsonb_build_object(
        'notice_id', NEW.id,
        'association_id', NEW.association_id,
        'category', NEW.category
      ),
      'bar_notice:' || NEW.id || ':' || r.uid
    );
  END LOOP;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'Bar notice notification failed: %', SQLERRM;
  RETURN NEW;
END;
$fn$;

DROP TRIGGER IF EXISTS on_bar_notice_notify ON public.bar_notices;
CREATE TRIGGER on_bar_notice_notify
  AFTER INSERT ON public.bar_notices
  FOR EACH ROW
  EXECUTE FUNCTION public.trigger_bar_notice_notification();


-- ─────────────────────────────────────────────────────────
-- 5. CRON
--
-- Both jobs are plain SQL — unlike the existing notification schedules they
-- need no pg_net round-trip to an edge function.
-- ─────────────────────────────────────────────────────────

DO $do$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    RAISE NOTICE 'pg_cron not available — skipping notification schedules';
    RETURN;
  END IF;

  -- ── Purge: rolling 24-hour window, swept hourly ────────
  BEGIN
    PERFORM cron.unschedule('purge-expired-notifications');
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  PERFORM cron.schedule(
    'purge-expired-notifications',
    '7 * * * *',
    $cron$
    DELETE FROM public.notifications
     WHERE created_at < now() - interval '24 hours';
    $cron$
  );
  RAISE NOTICE 'Scheduled purge-expired-notifications hourly at minute 7';

  -- ── Tasks due today, 9:00 AM IST = 3:30 AM UTC ─────────
  BEGIN
    PERFORM cron.unschedule('notify-tasks-due');
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  PERFORM cron.schedule(
    'notify-tasks-due',
    '30 3 * * *',
    $cron$
    INSERT INTO public.notifications
      (user_id, type, title, body, route, payload, dedupe_key)
    SELECT
      t.assigned_to,
      'task_due',
      'Task due today',
      COALESCE(t.title, 'Task'),
      CASE WHEN t.case_id IS NOT NULL THEN '/cases/' || t.case_id ELSE NULL END,
      jsonb_build_object('task_id', t.id, 'case_id', t.case_id),
      'task_due:' || t.id || ':' || t.due_date
    FROM public.strategy_tasks t
    WHERE t.assigned_to IS NOT NULL
      AND t.due_date = (now() AT TIME ZONE 'Asia/Kolkata')::date
      AND t.completed_at IS NULL
      AND t.deleted_at IS NULL
    ON CONFLICT DO NOTHING;
    $cron$
  );
  RAISE NOTICE 'Scheduled notify-tasks-due at 3:30 UTC (9:00 AM IST)';
END $do$;


-- ─────────────────────────────────────────────────────────
-- 6. LOCK DOWN THE RPC SURFACE
--
-- PostgREST exposes every function in `public` as an RPC endpoint, and
-- EXECUTE is granted to anon/authenticated by default. Without this,
-- `record_notification()` — SECURITY DEFINER, taking `p_user_id` as an
-- argument — is callable as POST /rest/v1/rpc/record_notification by any
-- signed-in user, or even anonymously.
--
-- That is a forgery hole: anyone could write an arbitrary notification into
-- ANY other user's feed, which is exactly what omitting the INSERT policy on
-- public.notifications above was meant to prevent.
--
-- The trigger functions are revoked for the same reason. They are far less
-- exploitable (invoking one outside a trigger errors on NEW/TG_OP), but they
-- have no business on the public API surface either.
--
-- This does not affect normal operation: the triggers are SECURITY DEFINER
-- owned by postgres, so they still call record_notification() as the owner,
-- and the notification edge functions insert into the table directly with the
-- service-role key rather than through this RPC.
-- ─────────────────────────────────────────────────────────

REVOKE ALL ON FUNCTION public.record_notification(
  UUID, TEXT, TEXT, TEXT, TEXT, JSONB, TEXT
) FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION public.trigger_case_status_notification()    FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.trigger_task_assigned_notification()  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.trigger_payment_notification()        FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.trigger_bar_notice_notification()     FROM PUBLIC, anon, authenticated;
