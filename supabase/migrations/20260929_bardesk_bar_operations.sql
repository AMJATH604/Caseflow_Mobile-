-- ─────────────────────────────────────────────────────────
-- BarDesk, rebuilt around what a Tamil Nadu district bar
-- association actually does.
--
-- Elections are removed entirely. What replaces them is the work a
-- secretary does every week and currently does on paper: chasing renewals
-- before they lapse, tracking welfare fund claims through the Bar Council's
-- defect process, publishing a death the same morning it happens, issuing
-- identity cards, carrying advocates' clerks on the roll, and holding the
-- stipend record the Madras High Court directed associations to keep.
--
-- The lapse watch is the reason this migration exists. Welfare compensation
-- on an advocate's death is refused when the membership had lapsed, and
-- nothing in the old schema could answer "who expires next month" — the
-- membership year was an integer, so there was no date to count down to.
-- ─────────────────────────────────────────────────────────

-- ─── 1. Elections, removed ────────────────────────────────
-- Children first. Only test rows existed (2 elections, 3 votes).

DROP TABLE IF EXISTS public.bar_votes               CASCADE;
DROP TABLE IF EXISTS public.bar_voter_participation CASCADE;
DROP TABLE IF EXISTS public.bar_nominations         CASCADE;
DROP TABLE IF EXISTS public.bar_election_posts      CASCADE;
DROP TABLE IF EXISTS public.bar_elections           CASCADE;

DROP FUNCTION IF EXISTS public.cast_bar_votes(uuid, jsonb);
DROP FUNCTION IF EXISTS public.get_vote_counts(uuid);

-- The ballot-signing secret has nothing left to sign.
DO $$
BEGIN
  DELETE FROM vault.secrets WHERE name = 'bar_vote_secret';
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'vault secret bar_vote_secret not removed: %', SQLERRM;
END $$;

-- ─── 2. Members: what a bar register actually holds ───────

ALTER TABLE public.bar_members
  -- Enrolment with the Bar Council, which is what welfare eligibility and
  -- seniority are both reckoned from — distinct from joining this bar.
  ADD COLUMN IF NOT EXISTS enrolment_date        date,
  ADD COLUMN IF NOT EXISTS date_of_birth         date,
  ADD COLUMN IF NOT EXISTS address               text,
  ADD COLUMN IF NOT EXISTS blood_group           text,

  -- Clerks sit on the same roll as a separate class, attached to the
  -- advocate they work under. They have their own welfare fund and their
  -- families make their own claims, so they cannot simply be left out.
  ADD COLUMN IF NOT EXISTS member_class          text NOT NULL DEFAULT 'advocate',
  ADD COLUMN IF NOT EXISTS works_under_member_id uuid REFERENCES public.bar_members(id) ON DELETE SET NULL,

  -- A real date, not a year. "fee_paid_until = 2026" cannot answer
  -- "who lapses in the next 30 days", which is the whole point.
  ADD COLUMN IF NOT EXISTS membership_expires_on date,

  ADD COLUMN IF NOT EXISTS welfare_fund_number   text,
  ADD COLUMN IF NOT EXISTS welfare_fund_status   text NOT NULL DEFAULT 'unknown',

  ADD COLUMN IF NOT EXISTS id_card_number        text,
  ADD COLUMN IF NOT EXISTS id_card_issued_on     date,
  ADD COLUMN IF NOT EXISTS id_card_valid_until   date,

  ADD COLUMN IF NOT EXISTS is_deceased           boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS date_of_death         date,
  ADD COLUMN IF NOT EXISTS notes                 text,
  ADD COLUMN IF NOT EXISTS updated_at            timestamptz NOT NULL DEFAULT now();

DO $$
BEGIN
  ALTER TABLE public.bar_members
    ADD CONSTRAINT bar_members_member_class_check
    CHECK (member_class IN ('advocate', 'clerk'));
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  ALTER TABLE public.bar_members
    ADD CONSTRAINT bar_members_welfare_status_check
    CHECK (welfare_fund_status IN ('unknown','active','arrears','not_enrolled','retired','claimed'));
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Backfill an expiry from the year already held, so the lapse watch has
-- something to work with on day one. The TN membership year runs to 31 March.
UPDATE public.bar_members
   SET membership_expires_on = make_date(fee_paid_until + 1, 3, 31)
 WHERE membership_expires_on IS NULL
   AND fee_paid_until IS NOT NULL;

CREATE INDEX IF NOT EXISTS bar_members_expiry_idx
  ON public.bar_members (association_id, membership_expires_on)
  WHERE is_deceased = false;

CREATE INDEX IF NOT EXISTS bar_members_class_idx
  ON public.bar_members (association_id, member_class);

-- ─── 3. Association: office bearers and the stipend floor ─

ALTER TABLE public.bar_associations
  ADD COLUMN IF NOT EXISTS president_name  text,
  ADD COLUMN IF NOT EXISTS secretary_name  text,
  ADD COLUMN IF NOT EXISTS treasurer_name  text,
  ADD COLUMN IF NOT EXISTS contact_phone   text,
  ADD COLUMN IF NOT EXISTS contact_email   text,
  -- Madras HC, June 2024: ₹20,000 in Chennai, Coimbatore and Madurai;
  -- ₹15,000 elsewhere in Tamil Nadu and Puducherry.
  ADD COLUMN IF NOT EXISTS junior_stipend_floor numeric NOT NULL DEFAULT 15000;

UPDATE public.bar_associations
   SET junior_stipend_floor = 20000
 WHERE lower(district) IN ('chennai', 'coimbatore', 'madurai')
   AND junior_stipend_floor = 15000;

-- ─── 4. Condolences ───────────────────────────────────────
-- Separate from notices: different urgency, a fixed shape, and the
-- association keeps it as a record. Publishing one is also what starts the
-- family's welfare claim, so the two are linked.

CREATE TABLE IF NOT EXISTS public.bar_condolences (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  association_id        uuid NOT NULL REFERENCES public.bar_associations(id) ON DELETE CASCADE,
  -- Null when the deceased was never on this roll (a retired member, or a
  -- clerk of a neighbouring bar) but the association still meets.
  member_id             uuid REFERENCES public.bar_members(id) ON DELETE SET NULL,
  deceased_name         text NOT NULL,
  enrolment_number      text,
  date_of_death         date NOT NULL,
  age                   integer,
  message               text,
  -- Convention is that the bar does not take up work, so the time matters
  -- as much as the fact.
  meeting_at            timestamptz,
  meeting_venue         text,
  no_work_resolution    boolean NOT NULL DEFAULT false,
  published_by          uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  published_at          timestamptz NOT NULL DEFAULT now(),
  fcm_sent              boolean NOT NULL DEFAULT false,
  created_at            timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS bar_condolences_assoc_idx
  ON public.bar_condolences (association_id, date_of_death DESC);

-- ─── 5. Welfare claims ────────────────────────────────────
-- Modelled on how the Bar Council actually processes these: an application
-- is raised, comes back with a defect, is resubmitted, and is eventually
-- sanctioned. Members currently learn where theirs is by telephoning.

CREATE TABLE IF NOT EXISTS public.bar_welfare_claims (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  association_id    uuid NOT NULL REFERENCES public.bar_associations(id) ON DELETE CASCADE,
  member_id         uuid REFERENCES public.bar_members(id) ON DELETE SET NULL,
  claim_type        text NOT NULL,
  -- For a death claim the applicant is the family, not the member.
  claimant_name     text,
  claimant_relation text,
  claimant_mobile   text,
  amount            numeric,
  reference_number  text,
  status            text NOT NULL DEFAULT 'draft',
  -- What the Bar Council returned it for. This is the "defect list" that
  -- otherwise lives in a letter nobody can find.
  defect_notes      text,
  submitted_on      date,
  sanctioned_on     date,
  created_by        uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT bar_welfare_claims_type_check
    CHECK (claim_type IN ('death','retirement','medical','disability','other')),
  CONSTRAINT bar_welfare_claims_status_check
    CHECK (status IN ('draft','submitted','defect','resubmitted','sanctioned','rejected'))
);

CREATE INDEX IF NOT EXISTS bar_welfare_claims_assoc_idx
  ON public.bar_welfare_claims (association_id, status, submitted_on DESC);

-- ─── 6. Welfare stamps ────────────────────────────────────
-- Every vakalat carries one. Associations buy them in books and sell them
-- across the counter, and the reconciliation is usually from memory.

CREATE TABLE IF NOT EXISTS public.bar_welfare_stamps (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  association_id uuid NOT NULL REFERENCES public.bar_associations(id) ON DELETE CASCADE,
  txn_type       text NOT NULL,
  quantity       integer NOT NULL,
  denomination   numeric NOT NULL DEFAULT 25,
  member_id      uuid REFERENCES public.bar_members(id) ON DELETE SET NULL,
  notes          text,
  recorded_by    uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  recorded_at    timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT bar_welfare_stamps_txn_check CHECK (txn_type IN ('received','sold','returned')),
  CONSTRAINT bar_welfare_stamps_qty_check  CHECK (quantity > 0)
);

CREATE INDEX IF NOT EXISTS bar_welfare_stamps_assoc_idx
  ON public.bar_welfare_stamps (association_id, recorded_at DESC);

-- ─── 7. Stipend register ──────────────────────────────────
-- The Madras High Court directed the Bar Council to circular every
-- association on minimum junior stipends. The association received the
-- circular and has no way to answer it.

CREATE TABLE IF NOT EXISTS public.bar_stipend_declarations (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  association_id     uuid NOT NULL REFERENCES public.bar_associations(id) ON DELETE CASCADE,
  senior_member_id   uuid NOT NULL REFERENCES public.bar_members(id) ON DELETE CASCADE,
  -- The junior may not be on this roll yet — a first-year often is not.
  junior_member_id   uuid REFERENCES public.bar_members(id) ON DELETE SET NULL,
  junior_name        text NOT NULL,
  junior_mobile      text,
  monthly_stipend    numeric NOT NULL,
  effective_from     date NOT NULL,
  effective_to       date,
  -- The junior's own confirmation is what makes this worth anything.
  confirmed_by_junior boolean NOT NULL DEFAULT false,
  confirmed_at       timestamptz,
  declared_by        uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT bar_stipend_amount_check CHECK (monthly_stipend >= 0)
);

CREATE INDEX IF NOT EXISTS bar_stipend_assoc_idx
  ON public.bar_stipend_declarations (association_id, effective_from DESC);

-- ─── 8. Row level security ────────────────────────────────
-- Members read their association's records; admins write them. Reuses the
-- SECURITY DEFINER helpers the other bar tables already use, which exist to
-- keep these policies from recursing through bar_members.

ALTER TABLE public.bar_condolences          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bar_welfare_claims       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bar_welfare_stamps       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bar_stipend_declarations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS bar_condolences_read ON public.bar_condolences;
CREATE POLICY bar_condolences_read ON public.bar_condolences
  FOR SELECT TO authenticated
  USING (public.is_association_member(association_id, auth.uid()));

DROP POLICY IF EXISTS bar_condolences_write ON public.bar_condolences;
CREATE POLICY bar_condolences_write ON public.bar_condolences
  FOR ALL TO authenticated
  USING (public.is_association_admin(association_id, auth.uid()))
  WITH CHECK (public.is_association_admin(association_id, auth.uid()));

DROP POLICY IF EXISTS bar_welfare_claims_read ON public.bar_welfare_claims;
CREATE POLICY bar_welfare_claims_read ON public.bar_welfare_claims
  FOR SELECT TO authenticated
  USING (public.is_association_member(association_id, auth.uid()));

DROP POLICY IF EXISTS bar_welfare_claims_write ON public.bar_welfare_claims;
CREATE POLICY bar_welfare_claims_write ON public.bar_welfare_claims
  FOR ALL TO authenticated
  USING (public.is_association_admin(association_id, auth.uid()))
  WITH CHECK (public.is_association_admin(association_id, auth.uid()));

-- Stamp ledger is association bookkeeping — admins only, both ways.
DROP POLICY IF EXISTS bar_welfare_stamps_admin ON public.bar_welfare_stamps;
CREATE POLICY bar_welfare_stamps_admin ON public.bar_welfare_stamps
  FOR ALL TO authenticated
  USING (public.is_association_admin(association_id, auth.uid()))
  WITH CHECK (public.is_association_admin(association_id, auth.uid()));

DROP POLICY IF EXISTS bar_stipend_read ON public.bar_stipend_declarations;
CREATE POLICY bar_stipend_read ON public.bar_stipend_declarations
  FOR SELECT TO authenticated
  USING (public.is_association_member(association_id, auth.uid()));

DROP POLICY IF EXISTS bar_stipend_write ON public.bar_stipend_declarations;
CREATE POLICY bar_stipend_write ON public.bar_stipend_declarations
  FOR ALL TO authenticated
  USING (public.is_association_admin(association_id, auth.uid()))
  WITH CHECK (public.is_association_admin(association_id, auth.uid()));

-- ─── 9. Realtime ──────────────────────────────────────────
-- What BarDesk publishes has to reach the phone without a pull-to-refresh.
-- Guarded, because adding a table twice to a publication errors.

DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'bar_notices','bar_members','bar_fee_payments','bar_events',
    'bar_condolences','bar_welfare_claims','bar_stipend_declarations'
  ] LOOP
    IF NOT EXISTS (
      SELECT 1 FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = t
    ) THEN
      EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I', t);
    END IF;
  END LOOP;
END $$;
