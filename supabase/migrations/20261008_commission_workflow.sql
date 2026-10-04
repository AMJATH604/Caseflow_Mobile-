-- ═══════════════════════════════════════════════════════════════
-- Advocate Commissioner: the steps of an Order XXVI CPC commission
--
-- NOT YET APPLIED. Apply on its own in a transaction with
-- `supabase db query --linked --file`, not `db push`.
--
-- Adds what the redesigned module records and the report prints:
--   commissions          + inspection date/place (the notice), the fee fixed
--                          by the court, who deposited it, what was received,
--                          and the date the report was filed.
--   commission_parties   parties and others given notice of the inspection:
--                          served / refused / informed, how and when, and
--                          whether they attended.
--   commission_measurements
--                        boundaries (N/S/E/W, bounded by and length) and the
--                          extent found at site, compared with the schedule.
--
-- Access mirrors commissions_select: the commission's creator, its appointed
-- commissioner, or the firm owner. Additive only — nothing existing changes.
-- ═══════════════════════════════════════════════════════════════

ALTER TABLE public.commissions ADD COLUMN IF NOT EXISTS inspection_at TIMESTAMPTZ;
ALTER TABLE public.commissions ADD COLUMN IF NOT EXISTS inspection_place TEXT;
ALTER TABLE public.commissions ADD COLUMN IF NOT EXISTS fee_fixed NUMERIC(12, 2);
ALTER TABLE public.commissions ADD COLUMN IF NOT EXISTS fee_deposited_by TEXT;
ALTER TABLE public.commissions ADD COLUMN IF NOT EXISTS fee_received NUMERIC(12, 2);
ALTER TABLE public.commissions ADD COLUMN IF NOT EXISTS fee_received_on DATE;
ALTER TABLE public.commissions ADD COLUMN IF NOT EXISTS submitted_on DATE;

-- ── Parties given notice ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.commission_parties (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  commission_id  UUID NOT NULL REFERENCES public.commissions (id) ON DELETE CASCADE,
  name           TEXT NOT NULL CHECK (char_length(btrim(name)) BETWEEN 1 AND 160),
  role           TEXT NOT NULL DEFAULT 'party'
                 CHECK (role IN ('plaintiff', 'petitioner', 'defendant', 'respondent', 'party', 'official', 'other')),
  role_label     TEXT CHECK (role_label IS NULL OR char_length(role_label) <= 60),
  advocate       TEXT CHECK (advocate IS NULL OR char_length(advocate) <= 160),
  phone          TEXT CHECK (phone IS NULL OR char_length(phone) <= 30),
  notice_status  TEXT NOT NULL DEFAULT 'pending'
                 CHECK (notice_status IN ('pending', 'served', 'refused', 'informed', 'not_served')),
  served_on      DATE,
  served_how     TEXT CHECK (served_how IS NULL OR char_length(served_how) <= 200),
  attended       BOOLEAN,
  sort_order     INT NOT NULL DEFAULT 0,
  created_by     UUID DEFAULT auth.uid() REFERENCES auth.users (id) ON DELETE SET NULL,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS commission_parties_commission_idx ON public.commission_parties (commission_id, sort_order);

-- ── Boundaries and extent ───────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.commission_measurements (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  commission_id    UUID NOT NULL REFERENCES public.commissions (id) ON DELETE CASCADE,
  visit_id         UUID REFERENCES public.commission_visits (id) ON DELETE SET NULL,
  label            TEXT NOT NULL DEFAULT 'Schedule property' CHECK (char_length(label) BETWEEN 1 AND 80),
  north_by         TEXT, north_len TEXT,
  south_by         TEXT, south_len TEXT,
  east_by          TEXT, east_len TEXT,
  west_by          TEXT, west_len TEXT,
  extent           NUMERIC(14, 4),
  extent_unit      TEXT NOT NULL DEFAULT 'sq_ft' CHECK (extent_unit IN ('sq_ft', 'sq_m', 'cents', 'acres', 'hectares')),
  schedule_extent  NUMERIC(14, 4),
  notes            TEXT CHECK (notes IS NULL OR char_length(notes) <= 4000),
  sort_order       INT NOT NULL DEFAULT 0,
  created_by       UUID DEFAULT auth.uid() REFERENCES auth.users (id) ON DELETE SET NULL,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS commission_measurements_commission_idx ON public.commission_measurements (commission_id, sort_order);

-- ── Access: whoever can see the commission ─────────────────────
ALTER TABLE public.commission_parties ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.commission_measurements ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Commission team manages parties" ON public.commission_parties;
CREATE POLICY "Commission team manages parties" ON public.commission_parties
  FOR ALL TO authenticated
  USING (commission_id IN (
    SELECT c.id FROM public.commissions c
     WHERE c.created_by = auth.uid() OR c.commissioner_id = auth.uid() OR c.firm_id = auth.uid()))
  WITH CHECK (commission_id IN (
    SELECT c.id FROM public.commissions c
     WHERE c.created_by = auth.uid() OR c.commissioner_id = auth.uid() OR c.firm_id = auth.uid()));

DROP POLICY IF EXISTS "Commission team manages measurements" ON public.commission_measurements;
CREATE POLICY "Commission team manages measurements" ON public.commission_measurements
  FOR ALL TO authenticated
  USING (commission_id IN (
    SELECT c.id FROM public.commissions c
     WHERE c.created_by = auth.uid() OR c.commissioner_id = auth.uid() OR c.firm_id = auth.uid()))
  WITH CHECK (commission_id IN (
    SELECT c.id FROM public.commissions c
     WHERE c.created_by = auth.uid() OR c.commissioner_id = auth.uid() OR c.firm_id = auth.uid()));

REVOKE ALL ON public.commission_parties FROM anon;
REVOKE ALL ON public.commission_measurements FROM anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.commission_parties TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.commission_measurements TO authenticated;

-- updated_at on edit (reuses the website migration's trigger function)
DROP TRIGGER IF EXISTS trg_commission_parties_touch ON public.commission_parties;
CREATE TRIGGER trg_commission_parties_touch
  BEFORE UPDATE ON public.commission_parties
  FOR EACH ROW EXECUTE FUNCTION public.website_touch_updated_at();
DROP TRIGGER IF EXISTS trg_commission_measurements_touch ON public.commission_measurements;
CREATE TRIGGER trg_commission_measurements_touch
  BEFORE UPDATE ON public.commission_measurements
  FOR EACH ROW EXECUTE FUNCTION public.website_touch_updated_at();
