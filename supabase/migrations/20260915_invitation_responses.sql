-- ═══════════════════════════════════════════════════════════════
-- Invitation responses: make Reject work, and notify the inviter
--
-- Two bugs, one root cause each.
--
-- 1. REJECTING A FIRM INVITATION SILENTLY DID NOTHING.
--    FirmService.declineInvitation issued a DELETE, but every DELETE-capable
--    policy on firm_members is owner-scoped (auth.uid() = owner_id). For the
--    invited junior, RLS filtered the row out, the DELETE matched ZERO rows,
--    and PostgREST still returned success — so the client threw nothing,
--    showed a "Invitation Rejected" toast, reloaded, and the still-pending
--    invitation reappeared.
--
--    Accept worked only because it writes exactly {member_id, status:
--    'accepted'} — the precise tuple demanded by the junior's sole UPDATE
--    policy, which was literally named "Juniors can accept their own
--    invitation". Rejection was never granted, so simply switching the client
--    to an UPDATE would have hard-failed with 42501 instead.
--
-- 2. NOBODY WAS EVER TOLD THE OUTCOME. Both invitation triggers were AFTER
--    INSERT only, and send-invitation-notification early-returns on anything
--    that is not 'pending' and always addresses the invitee. So the senior who
--    sent the invite learned nothing, whether it was accepted or declined.
--
-- Rejection now MARKS the row 'rejected' rather than deleting it — a deleted
-- row leaves nothing for a trigger to fire on, so keeping it is what makes
-- notifying the inviter possible at all.
--
-- Also fixes a third, quieter bug: re-inviting someone only touched
-- created_at, which fired no trigger, so the re-invite was never delivered.
-- The invite triggers now fire on any transition INTO 'pending'.
--
-- ⚠️ PREREQUISITES: vault secret 'pg_trigger_secret' must exist (created by
-- 20260908_notification_triggers.sql), and the edge function must be
-- redeployed:  supabase functions deploy send-invitation-notification
-- ═══════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────
-- 1. COLUMNS
-- ─────────────────────────────────────────────────────────

ALTER TABLE public.firm_members
  ADD COLUMN IF NOT EXISTS responded_at TIMESTAMPTZ;

ALTER TABLE public.case_collaborations
  ADD COLUMN IF NOT EXISTS responded_at TIMESTAMPTZ;

COMMENT ON COLUMN public.firm_members.responded_at IS
  'When the invitee accepted or rejected. NULL while still pending.';
COMMENT ON COLUMN public.case_collaborations.responded_at IS
  'When the invitee accepted or rejected. NULL while still pending.';

-- firm_members.status had NO constraint at all and accepted any string.
-- Normalise first so the constraint cannot fail on legacy data.
UPDATE public.firm_members
   SET status = 'pending'
 WHERE status IS NULL
    OR status NOT IN ('pending', 'accepted', 'rejected');

ALTER TABLE public.firm_members
  DROP CONSTRAINT IF EXISTS firm_members_status_check;
ALTER TABLE public.firm_members
  ADD CONSTRAINT firm_members_status_check
  CHECK (status IN ('pending', 'accepted', 'rejected'));


-- ─────────────────────────────────────────────────────────
-- 2. RLS — let the invitee reject, not just accept
--
-- The old policy's WITH CHECK was (status = 'accepted' AND member_id =
-- auth.uid()), which is why rejection was impossible. The replacement still
-- pins member_id to the caller — so an invitee can only ever respond as
-- themselves — but allows either terminal status.
-- ─────────────────────────────────────────────────────────

DROP POLICY IF EXISTS "Juniors can accept their own invitation"  ON public.firm_members;
DROP POLICY IF EXISTS "Juniors can respond to their own invitation" ON public.firm_members;
CREATE POLICY "Juniors can respond to their own invitation"
  ON public.firm_members
  FOR UPDATE
  TO authenticated
  USING (
    member_email = (auth.jwt() ->> 'email')
    OR member_id = auth.uid()
  )
  WITH CHECK (
    member_id = auth.uid()
    AND status IN ('accepted', 'rejected')
  );

-- case_collaborations already permits both outcomes
-- ("Collaborators can respond to invitations"), so it needs no change.


-- ─────────────────────────────────────────────────────────
-- 3. NOTIFICATION TYPE
-- ─────────────────────────────────────────────────────────

ALTER TABLE public.notifications
  DROP CONSTRAINT IF EXISTS notifications_type_check;
ALTER TABLE public.notifications
  ADD CONSTRAINT notifications_type_check
  CHECK (type IN (
    'hearing_reminder','caveat_reminder','invitation','invitation_response',
    'case_status','task_assigned','task_due','payment','bar_notice'));


-- ─────────────────────────────────────────────────────────
-- 4. INVITE TRIGGERS — now also fire on re-invite
--
-- Redefined only to report the real TG_OP and to tag the payload with
-- event='invite' so the edge function can tell the two directions apart.
-- The triggers below widen them to any transition INTO 'pending'.
-- ─────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.trigger_firm_invitation_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, net
AS $fn$
DECLARE
  payload JSONB;
BEGIN
  IF NEW.status IS DISTINCT FROM 'pending' THEN
    RETURN NEW;
  END IF;

  payload := jsonb_build_object(
    'type', TG_OP,
    'event', 'invite',
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
  RAISE WARNING 'Firm invitation notification trigger failed: %', SQLERRM;
  RETURN NEW;
END;
$fn$;

DROP TRIGGER IF EXISTS on_firm_member_insert_notify ON public.firm_members;
CREATE TRIGGER on_firm_member_insert_notify
  AFTER INSERT OR UPDATE OF status ON public.firm_members
  FOR EACH ROW
  WHEN (NEW.status = 'pending')
  EXECUTE FUNCTION public.trigger_firm_invitation_notification();


CREATE OR REPLACE FUNCTION public.trigger_case_invitation_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, net
AS $fn$
DECLARE
  payload JSONB;
BEGIN
  IF NEW.status IS DISTINCT FROM 'pending' THEN
    RETURN NEW;
  END IF;

  payload := jsonb_build_object(
    'type', TG_OP,
    'event', 'invite',
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
$fn$;

DROP TRIGGER IF EXISTS on_case_collab_insert_notify ON public.case_collaborations;
CREATE TRIGGER on_case_collab_insert_notify
  AFTER INSERT OR UPDATE OF status ON public.case_collaborations
  FOR EACH ROW
  WHEN (NEW.status = 'pending')
  EXECUTE FUNCTION public.trigger_case_invitation_notification();


-- ─────────────────────────────────────────────────────────
-- 5. RESPONSE TRIGGERS — tell the inviter what happened
--
-- UPDATE-only and gated on an actual status transition, so re-saving a row
-- without changing its status stays silent.
-- ─────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.trigger_firm_response_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, net
AS $fn$
DECLARE
  payload JSONB;
BEGIN
  payload := jsonb_build_object(
    'type', TG_OP,
    'event', 'response',
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
  -- Never break the invitee's response because the inviter's notification
  -- could not be sent.
  RAISE WARNING 'Firm response notification trigger failed: %', SQLERRM;
  RETURN NEW;
END;
$fn$;

DROP TRIGGER IF EXISTS on_firm_member_response_notify ON public.firm_members;
CREATE TRIGGER on_firm_member_response_notify
  AFTER UPDATE OF status ON public.firm_members
  FOR EACH ROW
  WHEN (OLD.status IS DISTINCT FROM NEW.status
        AND NEW.status IN ('accepted', 'rejected'))
  EXECUTE FUNCTION public.trigger_firm_response_notification();


CREATE OR REPLACE FUNCTION public.trigger_case_response_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, net
AS $fn$
DECLARE
  payload JSONB;
BEGIN
  payload := jsonb_build_object(
    'type', TG_OP,
    'event', 'response',
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
  RAISE WARNING 'Case response notification trigger failed: %', SQLERRM;
  RETURN NEW;
END;
$fn$;

DROP TRIGGER IF EXISTS on_case_collab_response_notify ON public.case_collaborations;
CREATE TRIGGER on_case_collab_response_notify
  AFTER UPDATE OF status ON public.case_collaborations
  FOR EACH ROW
  WHEN (OLD.status IS DISTINCT FROM NEW.status
        AND NEW.status IN ('accepted', 'rejected'))
  EXECUTE FUNCTION public.trigger_case_response_notification();


-- ─────────────────────────────────────────────────────────
-- 6. LOCK DOWN THE RPC SURFACE
--
-- PostgREST exposes every public function as an RPC with EXECUTE granted to
-- anon/authenticated by default. Trigger functions have no business there.
-- (See the same note in 20260914_notification_center.sql.)
-- ─────────────────────────────────────────────────────────

REVOKE ALL ON FUNCTION public.trigger_firm_response_notification() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.trigger_case_response_notification() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.trigger_firm_invitation_notification() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.trigger_case_invitation_notification() FROM PUBLIC, anon, authenticated;
