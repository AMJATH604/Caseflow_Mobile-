-- ─────────────────────────────────────────────────────────
-- Joining a bar becomes claiming a place on its roll, not creating one.
--
-- join_bar_association() INSERTED a fresh bar_members row for whoever
-- presented the invite code. The code is six letters shared with every
-- member of the association, so anybody who saw it — in a WhatsApp group, on
-- a notice board, from a friend — became an active member of that bar in the
-- database. A clerk, a law student, a litigant. "Verified advocate"
-- therefore meant nothing, and the app had no way to tell one from another.
--
-- The association already knows who its members are; keeping that register
-- is what a bar association is for. So the secretary enters the roll first,
-- each row carrying a name and an enrolment number with user_id NULL, and an
-- advocate installing CaseFlow claims the row that is already there.
--
-- The claim is the verification: this account is the person the Tenkasi Bar
-- Association lists as Fathima, MS/1234/2015. That is a stronger assurance
-- than CaseFlow could produce on its own, and it costs nothing to obtain.
--
-- Also adds bar_roll_progress(), because "140 of 212 have joined" is what
-- turns onboarding from hopeful into something a secretary can chase.
-- ─────────────────────────────────────────────────────────

-- "MS/1234/2015", "ms 1234 2015" and "MS12342015" are one number written
-- three ways, and they will be — 212 people are typing them.
CREATE OR REPLACE FUNCTION public.bar_enrolment_key(p_value text)
RETURNS text LANGUAGE sql IMMUTABLE PARALLEL SAFE AS $fn$
  SELECT regexp_replace(lower(coalesce(p_value, '')), '[^a-z0-9]', '', 'g');
$fn$;

-- Last ten digits, so +91 and leading-zero prefixes do not defeat a match.
CREATE OR REPLACE FUNCTION public.bar_mobile_key(p_value text)
RETURNS text LANGUAGE sql IMMUTABLE PARALLEL SAFE AS $fn$
  SELECT right(regexp_replace(coalesce(p_value, ''), '[^0-9]', '', 'g'), 10);
$fn$;

CREATE INDEX IF NOT EXISTS bar_members_enrolment_key_idx
  ON public.bar_members (association_id, public.bar_enrolment_key(enrollment_number));

CREATE INDEX IF NOT EXISTS bar_members_mobile_key_idx
  ON public.bar_members (association_id, public.bar_mobile_key(mobile));

-- ─── The claim ────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.claim_bar_membership(
  p_invite_code text,
  p_identifier  text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_uid    uuid := auth.uid();
  v_assoc  public.bar_associations%ROWTYPE;
  v_member public.bar_members%ROWTYPE;
  v_key    text;
  v_mobile text;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '42501';
  END IF;

  -- Ten failed attempts an hour. Guessing now needs both a code and
  -- somebody's enrolment number, so this is a backstop rather than the
  -- only defence.
  IF (SELECT count(*) FROM public.bar_join_attempts
       WHERE user_id = v_uid AND attempted_at > now() - interval '1 hour') >= 10 THEN
    RAISE EXCEPTION 'Too many attempts. Please try again in an hour.'
      USING ERRCODE = '54000';
  END IF;

  SELECT * INTO v_assoc FROM public.bar_associations
   WHERE invite_code = upper(trim(p_invite_code));

  IF NOT FOUND THEN
    INSERT INTO public.bar_join_attempts (user_id) VALUES (v_uid);
    RAISE EXCEPTION 'Invalid invite code. Please check and try again.'
      USING ERRCODE = 'P0002';
  END IF;

  IF EXISTS (SELECT 1 FROM public.bar_members
              WHERE association_id = v_assoc.id AND user_id = v_uid) THEN
    RAISE EXCEPTION 'You have already joined this association.'
      USING ERRCODE = '23505';
  END IF;

  v_key    := public.bar_enrolment_key(p_identifier);
  v_mobile := public.bar_mobile_key(p_identifier);

  IF v_key = '' THEN
    INSERT INTO public.bar_join_attempts (user_id) VALUES (v_uid);
    RAISE EXCEPTION 'Enter your enrolment number.' USING ERRCODE = 'P0002';
  END IF;

  -- Enrolment number first; mobile is the fallback for rolls entered
  -- without numbers. A ten-digit identifier is treated as a mobile.
  SELECT * INTO v_member
    FROM public.bar_members m
   WHERE m.association_id = v_assoc.id
     AND m.is_deceased = false
     AND (
       (m.enrollment_number IS NOT NULL
         AND public.bar_enrolment_key(m.enrollment_number) = v_key)
       OR (length(v_mobile) = 10 AND public.bar_mobile_key(m.mobile) = v_mobile)
     )
   ORDER BY (m.user_id IS NOT NULL)   -- unclaimed rows first
   LIMIT 1;

  IF NOT FOUND THEN
    INSERT INTO public.bar_join_attempts (user_id) VALUES (v_uid);
    RAISE EXCEPTION 'You are not on this association''s roll. Ask the association to add you first.'
      USING ERRCODE = 'P0002';
  END IF;

  IF v_member.user_id IS NOT NULL THEN
    INSERT INTO public.bar_join_attempts (user_id) VALUES (v_uid);
    RAISE EXCEPTION 'That entry has already been claimed. Contact your association.'
      USING ERRCODE = '23505';
  END IF;

  UPDATE public.bar_members
     SET user_id = v_uid,
         is_caseflow_user = true,
         email = COALESCE(NULLIF(email, ''), (SELECT email FROM public.profiles WHERE id = v_uid)),
         updated_at = now()
   WHERE id = v_member.id;

  UPDATE public.profiles SET bar_association_id = v_assoc.id WHERE id = v_uid;

  RETURN (to_jsonb(v_assoc) - 'invite_code')
         || jsonb_build_object('claimed_member_id', v_member.id,
                               'claimed_name', v_member.name);
END;
$fn$;

REVOKE ALL ON FUNCTION public.claim_bar_membership(text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.claim_bar_membership(text, text) TO authenticated;

-- The create-on-join function has no safe use; it is what let anyone in.
DROP FUNCTION IF EXISTS public.join_bar_association(text);

-- ─── Adoption, for the secretary ──────────────────────────

CREATE OR REPLACE FUNCTION public.bar_roll_progress(p_association_id uuid)
RETURNS jsonb
LANGUAGE sql
STABLE
AS $fn$
  SELECT jsonb_build_object(
    'total',     count(*),
    'claimed',   count(*) FILTER (WHERE user_id IS NOT NULL),
    'unclaimed', count(*) FILTER (WHERE user_id IS NULL),
    'no_enrolment_number', count(*) FILTER (
       WHERE enrollment_number IS NULL OR btrim(enrollment_number) = '')
  )
  FROM public.bar_members
  WHERE association_id = p_association_id
    AND is_deceased = false;
$fn$;

REVOKE ALL ON FUNCTION public.bar_roll_progress(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.bar_roll_progress(uuid) TO authenticated;
