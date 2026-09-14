-- ═══════════════════════════════════════════════════════════════
-- Phase B, stage 2 — lock-down
--
-- ⚠️  DO NOT APPLY until app 2.2.0 is installed by your users.
--
-- Builds before 2.2.0 read files by public link, load their own profile with
-- SELECT *, and join/vote directly against the tables. Every one of those stops
-- working here. The last statement raises app_config.min_version to 2.2.0 so
-- older builds show the blocking update dialog instead of breaking silently.
--
-- Order of operations:
--   1. Build and distribute 2.2.0; confirm login, cases, chat files, commission
--      photos, directory and bar association screens work on it.
--   2. Apply this migration.
--   3. Re-run the Phase B verification queries.
--
-- Rollback (if 2.2.0 turns out to have a problem after applying):
--   UPDATE storage.buckets SET public = true WHERE id IN (<the six below>);
--   GRANT SELECT ON public.profiles TO authenticated;
--   GRANT SELECT ON public.bar_associations TO authenticated;
--   UPDATE public.app_config SET value = '2.1.0' WHERE key = 'min_version';
-- ═══════════════════════════════════════════════════════════════


-- ─────────────────────────────────────────────────────────
-- 1. Private files: no more permanent public links
-- ─────────────────────────────────────────────────────────
-- Size limits sit above the largest file each bucket actually holds today
-- (case documents 44.5 MB, chat 8.1 MB, commission images < 1 MB).
UPDATE storage.buckets SET public = false, file_size_limit = 52428800   -- 50 MB
 WHERE id = 'case-documents';
UPDATE storage.buckets SET public = false, file_size_limit = 26214400   -- 25 MB
 WHERE id = 'chat-attachments';
UPDATE storage.buckets SET public = false, file_size_limit = 15728640   -- 15 MB
 WHERE id IN ('commission-evidence', 'commission-sketches', 'commission-witnesses');
UPDATE storage.buckets SET public = false, file_size_limit = 10485760   -- 10 MB
 WHERE id = 'payment-receipts';

-- payment-receipts had no policies at all, so receipt uploads were already
-- failing. Path: <user_id>/<case_id>/<timestamp>.<ext>
DROP POLICY IF EXISTS "payment_receipts_select" ON storage.objects;
DROP POLICY IF EXISTS "payment_receipts_insert" ON storage.objects;
CREATE POLICY "payment_receipts_select" ON storage.objects FOR SELECT TO authenticated
  USING (bucket_id = 'payment-receipts'
         AND EXISTS (SELECT 1 FROM public.cases c WHERE c.id::text = (storage.foldername(name))[2]));
CREATE POLICY "payment_receipts_insert" ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'payment-receipts'
              AND (storage.foldername(name))[1] = auth.uid()::text
              AND EXISTS (SELECT 1 FROM public.cases c WHERE c.id::text = (storage.foldername(name))[2]));


-- ─────────────────────────────────────────────────────────
-- 2. Profiles: other users' contact details are not selectable
-- ─────────────────────────────────────────────────────────
-- Row policy stays as it is (any signed-in user sees the row); what changes is
-- which columns. Your own full profile comes from get_my_profile(); contact
-- fields for others from get_profiles() / search_advocate_directory(), which
-- only return them for directory opt-ins and your own firm.
REVOKE SELECT ON public.profiles FROM anon, authenticated;
GRANT SELECT (
  id, full_name, avatar_url, practice_state, practice_district, user_role,
  last_seen_at, firm_id, is_public_directory_enabled, bar_association_id, created_at
) ON public.profiles TO authenticated;


-- ─────────────────────────────────────────────────────────
-- 3. Bar associations: invite codes and ballots are server-side only
-- ─────────────────────────────────────────────────────────
REVOKE SELECT ON public.bar_associations FROM anon, authenticated;
GRANT SELECT (
  id, name, district, court, address, logo_url, annual_fee,
  subscription_plan, subscription_expires_at, created_at, updated_at
) ON public.bar_associations TO authenticated;

-- Joining is only through join_bar_association(); voting only through
-- cast_bar_votes(). Association admins keep "Admins manage members".
DROP POLICY IF EXISTS "Users can insert their own member record" ON public.bar_members;
DROP POLICY IF EXISTS "Members cast votes in their association" ON public.bar_votes;
DROP POLICY IF EXISTS "Authenticated users cast votes" ON public.bar_votes;
DROP POLICY IF EXISTS "Members record participation" ON public.bar_voter_participation;

-- Re-key ballots cast under the old, publicly known salt, so they can no longer
-- be linked to members either. Participation rows say which member voted in
-- which election; that is enough to find their old hash and replace it.
UPDATE public.bar_votes v
   SET voter_hash = encode(
         extensions.hmac(
           vp.member_id::text || ':' || vp.election_id::text,
           (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'bar_vote_secret'),
           'sha256'),
         'hex')
  FROM public.bar_voter_participation vp
  JOIN public.bar_election_posts bp ON bp.election_id = vp.election_id
 WHERE v.post_id = bp.id
   AND v.voter_hash = encode(
         extensions.digest(vp.member_id::text || vp.election_id::text || 'caseflow_bar_election_salt_2026', 'sha256'),
         'hex');

-- The old helper hard-codes that salt. Nothing calls it any more.
DROP FUNCTION IF EXISTS public.generate_voter_hash(uuid, uuid);


-- ─────────────────────────────────────────────────────────
-- 4. Force older app builds to update
-- ─────────────────────────────────────────────────────────
UPDATE public.app_config SET value = '2.2.0', updated_at = now() WHERE key = 'min_version';
