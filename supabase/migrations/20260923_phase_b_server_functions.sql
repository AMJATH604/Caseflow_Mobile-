-- ═══════════════════════════════════════════════════════════════
-- Phase B, stage 1 — server-side functions the next app release calls
--
-- Additive only: the currently released app keeps working unchanged. Stage 2
-- (20260924_phase_b_lockdown.sql) removes the direct table access these replace,
-- and must only be applied after the new APK is installed and app_config
-- min_version forces older builds to update.
--
-- What each replaces, and why:
--   is_platform_admin()          admin checks that read profiles.is_admin, which
--                                stage 2 stops ordinary roles selecting
--   get_my_profile()             SELECT * on your own profile row
--   get_profiles(ids)            reading other users' contact details directly;
--                                contact fields now only for directory opt-ins
--                                and your own firm
--   search_advocate_directory()  directory query that selected email/mobile
--   find_profile_id_by_email()   invite flows that filtered profiles by email
--   join_bar_association(code)   client-side invite-code check (every user could
--                                read every invite code)
--   get_association_invite_code  BarDesk reading invite_code directly
--   cast_bar_votes()             client-side voting with a voter hash derived
--                                from a salt published in the app source, which
--                                let anyone link ballots to members
--
-- Also enforced now (compatible with the current app):
--   direct_messages: a user may only send as themselves, and may not edit
--   another person's message text.
-- ═══════════════════════════════════════════════════════════════


-- ─────────────────────────────────────────────────────────
-- Admin check
-- ─────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.is_platform_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $fn$
  SELECT COALESCE((SELECT is_admin FROM public.profiles WHERE id = auth.uid()), false);
$fn$;

REVOKE ALL ON FUNCTION public.is_platform_admin() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_platform_admin() TO authenticated;

-- Re-point the phase A admin policies at the function, so they keep working
-- once stage 2 revokes SELECT on profiles.is_admin.
DROP POLICY IF EXISTS "Admins can insert bare acts" ON public.bare_acts;
DROP POLICY IF EXISTS "Admins can update bare acts" ON public.bare_acts;
DROP POLICY IF EXISTS "Admins can delete bare acts" ON public.bare_acts;
CREATE POLICY "Admins can insert bare acts" ON public.bare_acts FOR INSERT TO authenticated
  WITH CHECK (public.is_platform_admin());
CREATE POLICY "Admins can update bare acts" ON public.bare_acts FOR UPDATE TO authenticated
  USING (public.is_platform_admin()) WITH CHECK (public.is_platform_admin());
CREATE POLICY "Admins can delete bare acts" ON public.bare_acts FOR DELETE TO authenticated
  USING (public.is_platform_admin());

DROP POLICY IF EXISTS "Admins can insert sections" ON public.bare_act_sections;
DROP POLICY IF EXISTS "Admins can update sections" ON public.bare_act_sections;
DROP POLICY IF EXISTS "Admins can delete sections" ON public.bare_act_sections;
CREATE POLICY "Admins can insert sections" ON public.bare_act_sections FOR INSERT TO authenticated
  WITH CHECK (public.is_platform_admin());
CREATE POLICY "Admins can update sections" ON public.bare_act_sections FOR UPDATE TO authenticated
  USING (public.is_platform_admin()) WITH CHECK (public.is_platform_admin());
CREATE POLICY "Admins can delete sections" ON public.bare_act_sections FOR DELETE TO authenticated
  USING (public.is_platform_admin());

DROP POLICY IF EXISTS "Admins can insert stamp_values" ON public.stamp_values;
DROP POLICY IF EXISTS "Admins can update stamp_values" ON public.stamp_values;
DROP POLICY IF EXISTS "Admins can delete stamp_values" ON public.stamp_values;
CREATE POLICY "Admins can insert stamp_values" ON public.stamp_values FOR INSERT TO authenticated
  WITH CHECK (public.is_platform_admin());
CREATE POLICY "Admins can update stamp_values" ON public.stamp_values FOR UPDATE TO authenticated
  USING (public.is_platform_admin()) WITH CHECK (public.is_platform_admin());
CREATE POLICY "Admins can delete stamp_values" ON public.stamp_values FOR DELETE TO authenticated
  USING (public.is_platform_admin());

DROP POLICY IF EXISTS "Admins manage legal templates" ON public.legal_templates;
CREATE POLICY "Admins manage legal templates" ON public.legal_templates FOR ALL TO authenticated
  USING (public.is_platform_admin()) WITH CHECK (public.is_platform_admin());

DROP POLICY IF EXISTS "Admins can insert portals" ON public.district_portals;
CREATE POLICY "Admins can insert portals" ON public.district_portals FOR INSERT TO authenticated
  WITH CHECK (public.is_platform_admin());

DROP POLICY IF EXISTS "Admins upload content files" ON storage.objects;
CREATE POLICY "Admins upload content files" ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id IN ('bare_acts', 'legal_templates') AND public.is_platform_admin());


-- ─────────────────────────────────────────────────────────
-- Profiles
-- ─────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_my_profile()
RETURNS SETOF public.profiles
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $fn$
  SELECT * FROM public.profiles WHERE id = auth.uid();
$fn$;

REVOKE ALL ON FUNCTION public.get_my_profile() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_profile() TO authenticated;


-- Contact details (email, mobile, registration number, office address) are
-- returned only when the person opted into the public directory, is you, or is
-- in the same firm as you. Everything else about a profile is non-sensitive.
CREATE OR REPLACE FUNCTION public.get_profiles(p_ids uuid[])
RETURNS TABLE (
  id uuid,
  full_name text,
  avatar_url text,
  practice_state text,
  practice_district text,
  user_role text,
  subscription_tier text,
  last_seen_at timestamptz,
  email text,
  mobile_number text,
  registration_number text,
  office_address text
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $fn$
  WITH me AS (
    SELECT auth.uid() AS uid,
           COALESCE((SELECT firm_id FROM public.profiles WHERE id = auth.uid()), auth.uid()) AS firm
  )
  SELECT p.id, p.full_name, p.avatar_url, p.practice_state, p.practice_district,
         p.user_role, p.subscription_tier, p.last_seen_at,
         CASE WHEN c.ok THEN p.email END,
         CASE WHEN c.ok THEN p.mobile_number END,
         CASE WHEN c.ok THEN p.registration_number END,
         CASE WHEN c.ok THEN p.office_address END
    FROM public.profiles p
    CROSS JOIN me
    CROSS JOIN LATERAL (
      SELECT (p.id = me.uid
              OR COALESCE(p.is_public_directory_enabled, false)
              OR p.id = me.firm
              OR p.firm_id = me.firm) AS ok
    ) c
   WHERE me.uid IS NOT NULL
     AND p.id = ANY (p_ids)
   LIMIT 500;
$fn$;

REVOKE ALL ON FUNCTION public.get_profiles(uuid[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_profiles(uuid[]) TO authenticated;


CREATE OR REPLACE FUNCTION public.search_advocate_directory(
  p_state    text DEFAULT NULL,
  p_district text DEFAULT NULL,
  p_query    text DEFAULT NULL
)
RETURNS TABLE (
  id uuid,
  full_name text,
  email text,
  mobile_number text,
  practice_state text,
  practice_district text,
  office_address text,
  registration_number text,
  avatar_url text
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $fn$
  SELECT p.id, p.full_name, p.email, p.mobile_number, p.practice_state,
         p.practice_district, p.office_address, p.registration_number, p.avatar_url
    FROM public.profiles p
   WHERE auth.uid() IS NOT NULL
     AND p.is_public_directory_enabled = true
     AND (NULLIF(p_state, '') IS NULL OR p.practice_state = p_state)
     AND (NULLIF(p_district, '') IS NULL OR p.practice_district = p_district)
     AND (NULLIF(p_query, '') IS NULL
          OR p.full_name ILIKE '%' || replace(replace(replace(p_query, '\', '\\'), '%', '\%'), '_', '\_') || '%')
   ORDER BY p.full_name
   LIMIT 300;
$fn$;

REVOKE ALL ON FUNCTION public.search_advocate_directory(text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.search_advocate_directory(text, text, text) TO authenticated;


-- Exact-match only, returns the id and nothing else. Used to pre-link firm and
-- case invitations to an existing account.
CREATE OR REPLACE FUNCTION public.find_profile_id_by_email(p_email text)
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $fn$
  SELECT id FROM public.profiles
   WHERE auth.uid() IS NOT NULL
     AND lower(email) = lower(trim(p_email))
   LIMIT 1;
$fn$;

REVOKE ALL ON FUNCTION public.find_profile_id_by_email(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.find_profile_id_by_email(text) TO authenticated;


-- ─────────────────────────────────────────────────────────
-- Bar association: join by invite code
-- ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.bar_join_attempts (
  id           bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id      uuid NOT NULL,
  attempted_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS bar_join_attempts_user_time_idx
  ON public.bar_join_attempts (user_id, attempted_at DESC);
-- Written only by join_bar_association(); no policies means no client access.
ALTER TABLE public.bar_join_attempts ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.join_bar_association(p_invite_code text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_uid     uuid := auth.uid();
  v_assoc   public.bar_associations%ROWTYPE;
  v_profile public.profiles%ROWTYPE;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '42501';
  END IF;

  -- 10 failed codes an hour per user makes guessing a 6-letter code hopeless.
  IF (SELECT count(*) FROM public.bar_join_attempts
       WHERE user_id = v_uid AND attempted_at > now() - interval '1 hour') >= 10 THEN
    RAISE EXCEPTION 'Too many attempts. Please try again in an hour.' USING ERRCODE = '54000';
  END IF;

  SELECT * INTO v_assoc FROM public.bar_associations
   WHERE invite_code = upper(trim(p_invite_code));

  IF NOT FOUND THEN
    INSERT INTO public.bar_join_attempts (user_id) VALUES (v_uid);
    RAISE EXCEPTION 'Invalid invite code. Please check and try again.' USING ERRCODE = 'P0002';
  END IF;

  IF EXISTS (SELECT 1 FROM public.bar_members WHERE association_id = v_assoc.id AND user_id = v_uid) THEN
    RAISE EXCEPTION 'You are already a member of this association.' USING ERRCODE = '23505';
  END IF;

  SELECT * INTO v_profile FROM public.profiles WHERE id = v_uid;

  INSERT INTO public.bar_members (
    association_id, user_id, name, mobile, email, membership_type, status, joined_year, is_caseflow_user
  ) VALUES (
    v_assoc.id, v_uid,
    COALESCE(NULLIF(v_profile.full_name, ''), split_part(COALESCE(v_profile.email, ''), '@', 1), 'Member'),
    COALESCE(v_profile.mobile_number, ''),
    v_profile.email,
    'regular', 'active', EXTRACT(YEAR FROM now())::int, true
  );

  UPDATE public.profiles SET bar_association_id = v_assoc.id WHERE id = v_uid;

  RETURN to_jsonb(v_assoc) - 'invite_code';
END;
$fn$;

REVOKE ALL ON FUNCTION public.join_bar_association(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.join_bar_association(text) TO authenticated;


CREATE OR REPLACE FUNCTION public.get_association_invite_code(p_association_id uuid)
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $fn$
BEGIN
  IF NOT public.is_association_admin(p_association_id, auth.uid()) THEN
    RAISE EXCEPTION 'Only association administrators can view the invite code.' USING ERRCODE = '42501';
  END IF;
  RETURN (SELECT invite_code FROM public.bar_associations WHERE id = p_association_id);
END;
$fn$;

REVOKE ALL ON FUNCTION public.get_association_invite_code(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_association_invite_code(uuid) TO authenticated;


-- ─────────────────────────────────────────────────────────
-- Bar association: secret ballot
-- ─────────────────────────────────────────────────────────
-- The voter hash is an HMAC keyed with a secret held in vault. It still makes
-- the (post, voter) pair unique, but without the key nobody — including anyone
-- who can read bar_votes and bar_members — can link a ballot to a member.
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM vault.secrets WHERE name = 'bar_vote_secret') THEN
    PERFORM vault.create_secret(encode(extensions.gen_random_bytes(32), 'hex'), 'bar_vote_secret',
      'HMAC key for anonymous bar election voter hashes. Rotating it breaks double-vote detection for open elections.');
  END IF;
END $$;

CREATE OR REPLACE FUNCTION public.cast_bar_votes(p_election_id uuid, p_votes jsonb)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_uid      uuid := auth.uid();
  v_election public.bar_elections%ROWTYPE;
  v_member   uuid;
  v_hash     text;
  v_post     text;
  v_nom      text;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_election FROM public.bar_elections WHERE id = p_election_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Election not found.' USING ERRCODE = 'P0002';
  END IF;

  IF v_election.status <> 'voting'
     OR (v_election.voting_start IS NOT NULL AND now() < v_election.voting_start)
     OR (v_election.voting_end   IS NOT NULL AND now() > v_election.voting_end) THEN
    RAISE EXCEPTION 'Voting is not open for this election.' USING ERRCODE = '22023';
  END IF;

  SELECT id INTO v_member FROM public.bar_members
   WHERE association_id = v_election.association_id
     AND user_id = v_uid
     AND status = 'active';
  IF v_member IS NULL THEN
    RAISE EXCEPTION 'Only active members of this association can vote.' USING ERRCODE = '42501';
  END IF;

  IF EXISTS (SELECT 1 FROM public.bar_voter_participation
              WHERE election_id = p_election_id AND member_id = v_member) THEN
    RAISE EXCEPTION 'You have already voted in this election.' USING ERRCODE = '23505';
  END IF;

  IF p_votes IS NULL OR jsonb_typeof(p_votes) <> 'object' OR p_votes = '{}'::jsonb THEN
    RAISE EXCEPTION 'No votes supplied.' USING ERRCODE = '22023';
  END IF;

  v_hash := encode(
    extensions.hmac(
      v_member::text || ':' || p_election_id::text,
      (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'bar_vote_secret'),
      'sha256'),
    'hex');

  FOR v_post, v_nom IN SELECT key, value #>> '{}' FROM jsonb_each(p_votes) LOOP
    IF NOT EXISTS (
      SELECT 1
        FROM public.bar_nominations n
        JOIN public.bar_election_posts bp ON bp.id = n.post_id
       WHERE n.id::text = v_nom
         AND bp.id::text = v_post
         AND bp.election_id = p_election_id
         AND n.status = 'approved'
    ) THEN
      RAISE EXCEPTION 'A selected candidate is not valid for this election.' USING ERRCODE = '22023';
    END IF;

    INSERT INTO public.bar_votes (post_id, nomination_id, voter_hash)
    VALUES (v_post::uuid, v_nom::uuid, v_hash);
  END LOOP;

  INSERT INTO public.bar_voter_participation (election_id, member_id, otp_verified)
  VALUES (p_election_id, v_member, true);
END;
$fn$;

REVOKE ALL ON FUNCTION public.cast_bar_votes(uuid, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cast_bar_votes(uuid, jsonb) TO authenticated;


-- ─────────────────────────────────────────────────────────
-- Direct messages: send only as yourself; don't edit others' text
-- ─────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "Users see own messages" ON public.direct_messages;
DROP POLICY IF EXISTS "Participants read messages" ON public.direct_messages;
DROP POLICY IF EXISTS "Participants send messages as themselves" ON public.direct_messages;
DROP POLICY IF EXISTS "Participants update messages" ON public.direct_messages;
DROP POLICY IF EXISTS "Participants delete messages" ON public.direct_messages;

CREATE POLICY "Participants read messages" ON public.direct_messages FOR SELECT TO authenticated
  USING (conversation_id IN (SELECT d.id FROM public.direct_conversations d
                              WHERE d.participant_1 = auth.uid() OR d.participant_2 = auth.uid()));
CREATE POLICY "Participants send messages as themselves" ON public.direct_messages FOR INSERT TO authenticated
  WITH CHECK (sender_id = auth.uid()
              AND conversation_id IN (SELECT d.id FROM public.direct_conversations d
                                       WHERE d.participant_1 = auth.uid() OR d.participant_2 = auth.uid()));
CREATE POLICY "Participants update messages" ON public.direct_messages FOR UPDATE TO authenticated
  USING (conversation_id IN (SELECT d.id FROM public.direct_conversations d
                              WHERE d.participant_1 = auth.uid() OR d.participant_2 = auth.uid()))
  WITH CHECK (conversation_id IN (SELECT d.id FROM public.direct_conversations d
                                   WHERE d.participant_1 = auth.uid() OR d.participant_2 = auth.uid()));
CREATE POLICY "Participants delete messages" ON public.direct_messages FOR DELETE TO authenticated
  USING (conversation_id IN (SELECT d.id FROM public.direct_conversations d
                              WHERE d.participant_1 = auth.uid() OR d.participant_2 = auth.uid()));

-- The recipient legitimately updates read/delivery state on the sender's
-- message; everything else about a message belongs to its sender.
CREATE OR REPLACE FUNCTION public.guard_direct_message_update()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $fn$
BEGIN
  IF auth.uid() IS NULL OR auth.uid() = OLD.sender_id THEN
    IF NEW.sender_id IS DISTINCT FROM OLD.sender_id
       OR NEW.conversation_id IS DISTINCT FROM OLD.conversation_id THEN
      IF auth.uid() IS NOT NULL THEN
        RAISE EXCEPTION 'A message cannot be moved or re-attributed.' USING ERRCODE = '42501';
      END IF;
    END IF;
    RETURN NEW;
  END IF;

  IF NEW.sender_id IS DISTINCT FROM OLD.sender_id
     OR NEW.conversation_id IS DISTINCT FROM OLD.conversation_id
     OR NEW.message IS DISTINCT FROM OLD.message
     OR NEW.attachment_url IS DISTINCT FROM OLD.attachment_url
     OR NEW.attachment_type IS DISTINCT FROM OLD.attachment_type
     OR NEW.reply_to_id IS DISTINCT FROM OLD.reply_to_id
     OR NEW.reply_to_message IS DISTINCT FROM OLD.reply_to_message
     OR NEW.reply_to_sender IS DISTINCT FROM OLD.reply_to_sender
     OR NEW.edited_at IS DISTINCT FROM OLD.edited_at
     OR NEW.created_at IS DISTINCT FROM OLD.created_at THEN
    RAISE EXCEPTION 'You can only change read and delivery status on messages you received.'
      USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END;
$fn$;

REVOKE ALL ON FUNCTION public.guard_direct_message_update() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_guard_direct_message_update ON public.direct_messages;
CREATE TRIGGER trg_guard_direct_message_update
  BEFORE UPDATE ON public.direct_messages
  FOR EACH ROW EXECUTE FUNCTION public.guard_direct_message_update();
