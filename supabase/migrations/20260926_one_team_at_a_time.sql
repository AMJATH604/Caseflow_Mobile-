-- ═══════════════════════════════════════════════════════════════
-- Firm membership: one team at a time
--
-- Rules:
--   • Accepting a firm invitation while already in another team removes you
--     from that team and adds you to the new one, in one transaction.
--   • Leaving a team leaves you unassigned — you do not fall back to a
--     previous team.
--   • Whenever someone leaves a team (by switching or leaving), cases of that
--     firm assigned to them are unassigned and the senior is notified.
--   • (Firm work staying with the firm after you leave is in
--     20260927_firm_cases_stay_with_firm.sql.)
--
-- Previously an advocate could be an accepted member of several firms at once,
-- while profiles.firm_id — which decides case access — could only point at one.
-- Access silently followed whichever invitation was accepted last, and there
-- was no way to leave a team at all.
-- ═══════════════════════════════════════════════════════════════


-- ─────────────────────────────────────────────────────────
-- Internal: detach a member from one firm
-- ─────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.detach_member_from_firm(
  p_member uuid,
  p_owner  uuid,
  p_notify_body text   -- NULL = do not notify the senior
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_name text;
BEGIN
  UPDATE public.cases
     SET assigned_to = NULL
   WHERE firm_id = p_owner AND assigned_to = p_member;

  UPDATE public.strategy_tasks
     SET assigned_to = NULL
   WHERE firm_id = p_owner AND assigned_to = p_member;

  DELETE FROM public.firm_members
   WHERE owner_id = p_owner AND member_id = p_member;

  UPDATE public.profiles
     SET firm_id = NULL
   WHERE id = p_member AND firm_id = p_owner;

  IF p_notify_body IS NOT NULL THEN
    SELECT COALESCE(NULLIF(full_name, ''), 'An associate') INTO v_name
      FROM public.profiles WHERE id = p_member;
    BEGIN
      PERFORM public.record_notification(
        p_owner,
        'invitation_response',
        v_name || ' left your team',
        v_name || ' ' || p_notify_body,
        '/tools',
        jsonb_build_object('member_id', p_member, 'event', 'left_team'),
        'team_left:' || p_owner || ':' || p_member || ':' || floor(extract(epoch FROM now()))::bigint
      );
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'detach_member_from_firm: notification failed: %', SQLERRM;
    END;
  END IF;
END;
$fn$;

REVOKE ALL ON FUNCTION public.detach_member_from_firm(uuid, uuid, text) FROM PUBLIC, anon, authenticated;


-- ─────────────────────────────────────────────────────────
-- Accept a firm invitation (switching teams if needed)
-- ─────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.accept_firm_invitation(p_invitation_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_uid   uuid := auth.uid();
  v_email text := auth.jwt() ->> 'email';
  v_inv   public.firm_members%ROWTYPE;
  v_prev  record;
  v_left  text[] := '{}';
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_inv
    FROM public.firm_members
   WHERE id = p_invitation_id
     AND status = 'pending'
     AND (member_id = v_uid OR lower(member_email) = lower(v_email))
   FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'This invitation is no longer available.' USING ERRCODE = 'P0002';
  END IF;

  IF v_inv.owner_id = v_uid THEN
    RAISE EXCEPTION 'You cannot join your own team.' USING ERRCODE = '22023';
  END IF;

  -- One team at a time: leave every other team first.
  FOR v_prev IN
    SELECT fm.owner_id, COALESCE(NULLIF(p.full_name, ''), 'your previous senior') AS owner_name
      FROM public.firm_members fm
      LEFT JOIN public.profiles p ON p.id = fm.owner_id
     WHERE fm.member_id = v_uid
       AND fm.status = 'accepted'
       AND fm.owner_id <> v_inv.owner_id
  LOOP
    PERFORM public.detach_member_from_firm(v_uid, v_prev.owner_id,
      'joined another firm and is no longer part of your team.');
    v_left := v_left || v_prev.owner_name;
  END LOOP;

  UPDATE public.firm_members
     SET member_id = v_uid, status = 'accepted', responded_at = now()
   WHERE id = p_invitation_id;

  UPDATE public.profiles SET firm_id = v_inv.owner_id WHERE id = v_uid;

  RETURN jsonb_build_object(
    'owner_id',   v_inv.owner_id,
    'left_teams', to_jsonb(v_left)
  );
END;
$fn$;

REVOKE ALL ON FUNCTION public.accept_firm_invitation(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.accept_firm_invitation(uuid) TO authenticated;


-- ─────────────────────────────────────────────────────────
-- Leave a team → unassigned
-- ─────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.leave_firm_team(p_owner_id uuid DEFAULT NULL)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_uid  uuid := auth.uid();
  v_prev record;
  v_count integer := 0;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '42501';
  END IF;

  FOR v_prev IN
    SELECT owner_id FROM public.firm_members
     WHERE member_id = v_uid
       AND status = 'accepted'
       AND (p_owner_id IS NULL OR owner_id = p_owner_id)
  LOOP
    PERFORM public.detach_member_from_firm(v_uid, v_prev.owner_id, 'is no longer part of your team.');
    v_count := v_count + 1;
  END LOOP;

  IF v_count = 0 THEN
    RAISE EXCEPTION 'You are not part of that team.' USING ERRCODE = 'P0002';
  END IF;

  -- Unassigned: never fall back to a previous firm.
  UPDATE public.profiles SET firm_id = NULL WHERE id = v_uid;

  RETURN v_count;
END;
$fn$;

REVOKE ALL ON FUNCTION public.leave_firm_team(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.leave_firm_team(uuid) TO authenticated;


-- ─────────────────────────────────────────────────────────
-- Existing data: anyone in more than one team keeps the latest
-- ─────────────────────────────────────────────────────────
DO $$
DECLARE v record;
BEGIN
  FOR v IN
    SELECT member_id, owner_id
      FROM (
        SELECT member_id, owner_id,
               row_number() OVER (PARTITION BY member_id
                                  ORDER BY COALESCE(responded_at, created_at) DESC) AS rn
          FROM public.firm_members
         WHERE status = 'accepted' AND member_id IS NOT NULL
      ) ranked
     WHERE rn > 1
  LOOP
    PERFORM public.detach_member_from_firm(v.member_id, v.owner_id, NULL);
  END LOOP;

  -- Point each remaining associate's profile at the team they are still in.
  UPDATE public.profiles p
     SET firm_id = fm.owner_id
    FROM public.firm_members fm
   WHERE fm.member_id = p.id
     AND fm.status = 'accepted'
     AND p.firm_id IS DISTINCT FROM fm.owner_id;
END $$;
