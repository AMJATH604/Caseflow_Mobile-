-- ═══════════════════════════════════════════════════════════════
-- Firm member roles: junior and clerk
--
-- Applied to production 2026-10-03, on its own in a transaction with
-- `supabase db query --linked --file`. Not via `db push`: the remote history
-- uses dashboard timestamps, so push would re-run every local migration.
--
-- A senior can now invite someone as a junior or as a clerk. Both work inside
-- the senior's firm and see its cases; the difference:
--
--   • junior — everything a member could do before.
--   • clerk  — adds and edits cases, hearings and clients, uses the diary,
--              eCourts import and documents, but never sees fees: every row
--              of public.payments and every payment receipt is hidden.
--
-- Enforced here for fees only. "Clerks and juniors cannot delete cases" stays
-- in the apps: mobile deletes a case's hearings, documents and payments before
-- the case row itself, so a policy that refused the final DELETE would leave a
-- case with its history already gone. Team management needs nothing new —
-- firm_members writes are already owner-only, and guard_invitation_response
-- (20260922) stops a member changing their own role.
-- ═══════════════════════════════════════════════════════════════


-- ─────────────────────────────────────────────────────────
-- firm_members.role: 'junior' | 'clerk'
-- ─────────────────────────────────────────────────────────
-- Mobile wrote no role, read null as 'member', and nothing branched on it, so
-- every existing value means "junior".
UPDATE public.firm_members
   SET role = 'junior'
 WHERE role IS DISTINCT FROM 'clerk' AND role IS DISTINCT FROM 'junior';

ALTER TABLE public.firm_members ALTER COLUMN role SET DEFAULT 'junior';
ALTER TABLE public.firm_members ALTER COLUMN role SET NOT NULL;

ALTER TABLE public.firm_members DROP CONSTRAINT IF EXISTS firm_members_role_check;
ALTER TABLE public.firm_members
  ADD CONSTRAINT firm_members_role_check CHECK (role IN ('junior', 'clerk'));


-- ─────────────────────────────────────────────────────────
-- is_firm_clerk(): is the caller a clerk in the firm they belong to?
-- ─────────────────────────────────────────────────────────
-- SECURITY DEFINER so a policy can read firm_members without recursing through
-- its RLS. It takes no user id — it only ever answers for auth.uid() — so being
-- reachable as an RPC exposes nothing beyond the caller's own role.
CREATE OR REPLACE FUNCTION public.is_firm_clerk()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $fn$
  SELECT EXISTS (
    SELECT 1
      FROM public.profiles p
      JOIN public.firm_members fm
        ON fm.owner_id = p.firm_id
       AND fm.member_id = p.id
     WHERE p.id = auth.uid()
       AND fm.status = 'accepted'
       AND fm.role = 'clerk'
  );
$fn$;

REVOKE ALL ON FUNCTION public.is_firm_clerk() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_firm_clerk() TO authenticated;


-- ─────────────────────────────────────────────────────────
-- Clerks never see fees
-- ─────────────────────────────────────────────────────────
-- RESTRICTIVE, so it is ANDed with whatever permissive policies already exist
-- on these tables (they predate tracked migrations) without restating them.
DROP POLICY IF EXISTS "Clerks cannot see fees" ON public.payments;
CREATE POLICY "Clerks cannot see fees" ON public.payments
  AS RESTRICTIVE
  FOR ALL
  TO authenticated
  USING (NOT public.is_firm_clerk())
  WITH CHECK (NOT public.is_firm_clerk());

DROP POLICY IF EXISTS "Clerks cannot see payment receipts" ON storage.objects;
CREATE POLICY "Clerks cannot see payment receipts" ON storage.objects
  AS RESTRICTIVE
  FOR ALL
  TO authenticated
  USING (bucket_id <> 'payment-receipts' OR NOT public.is_firm_clerk())
  WITH CHECK (bucket_id <> 'payment-receipts' OR NOT public.is_firm_clerk());
