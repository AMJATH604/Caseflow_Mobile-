-- ═══════════════════════════════════════════════════════════════
-- Firm team directory for associates
--
-- The Recruit Associate screen asked juniors for every firm_members row of
-- their senior's firm, but RLS lets a junior read only their OWN membership
-- row. A junior therefore saw a single card — themselves, "ACCEPTED" — with no
-- senior and no teammates, so the firm hierarchy was invisible.
--
-- This returns, for each firm the caller has accepted an invitation to: the
-- senior, when the caller joined, and the accepted associates. Names and
-- avatars only — email, phone and pending invitations stay with the senior.
-- ═══════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.get_my_senior_firms()
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $fn$
  SELECT COALESCE(jsonb_agg(
           jsonb_build_object(
             'owner_id',         fm.owner_id,
             'owner_name',       COALESCE(NULLIF(o.full_name, ''), 'Senior Advocate'),
             'owner_avatar_url', o.avatar_url,
             'joined_at',        COALESCE(fm.responded_at, fm.created_at),
             'teammates', (
               SELECT COALESCE(jsonb_agg(
                        jsonb_build_object(
                          'member_id',  t.member_id,
                          'name',       COALESCE(NULLIF(tp.full_name, ''), 'Associate'),
                          'avatar_url', tp.avatar_url,
                          'is_me',      t.member_id = auth.uid()
                        ) ORDER BY (t.member_id = auth.uid()) DESC, tp.full_name), '[]'::jsonb)
                 FROM public.firm_members t
                 LEFT JOIN public.profiles tp ON tp.id = t.member_id
                WHERE t.owner_id = fm.owner_id
                  AND t.status = 'accepted'
                  AND t.member_id IS NOT NULL
             )
           ) ORDER BY fm.created_at), '[]'::jsonb)
    FROM public.firm_members fm
    LEFT JOIN public.profiles o ON o.id = fm.owner_id
   WHERE auth.uid() IS NOT NULL
     AND fm.member_id = auth.uid()
     AND fm.status = 'accepted';
$fn$;

REVOKE ALL ON FUNCTION public.get_my_senior_firms() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_senior_firms() TO authenticated;
