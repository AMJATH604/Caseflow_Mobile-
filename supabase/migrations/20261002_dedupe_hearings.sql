-- public.hearings carried no unique key beyond its primary key, so re-running
-- an eCourts import inserted a second row for a date the case was already
-- listed on. By the time this was written, 25 cases held a duplicate pair --
-- mostly "Imported from eCourts" sitting beside "Synced from eCourts Update"
-- on the same date. The import caught and counted the failure it was never
-- actually given, so nothing surfaced: the advocate simply saw the same
-- hearing twice in the Court Diary.
--
-- Two halves: retire the surplus rows, then make the duplicate
-- unrepresentable so the import path cannot recreate them.
--
-- The constraint is deliberately NOT partial on deleted_at. PostgREST's
-- upsert emits ON CONFLICT (cols) with no index predicate, and Postgres
-- cannot infer a partial index from that, so the upsert the import now relies
-- on would fail outright. Nothing is lost by this: hearings.deleted_at is
-- unused -- every delete path on the table is a hard delete, and there were
-- zero soft-deleted rows when this ran.

-- ── 1. Keep the surplus rows before removing them ────────────────────────
-- Reversible by hand, and cheap. Drop this table once the Court Diary has
-- been eyeballed and the rows are confirmed unwanted.
CREATE TABLE IF NOT EXISTS public.hearings_dedupe_backup (
  LIKE public.hearings INCLUDING DEFAULTS,
  backed_up_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.hearings_dedupe_backup IS
  'Duplicate hearings removed by 20261002_dedupe_hearings. Operator artefact, '
  'not app data. Safe to drop once the Court Diary has been verified.';

-- Service-role only: RLS on, no policies.
ALTER TABLE public.hearings_dedupe_backup ENABLE ROW LEVEL SECURITY;

-- ── 2. Choose which row of each duplicate group survives ─────────────────
-- Ranking, in order:
--   1. a row carrying notes the advocate typed always wins over an import
--      marker -- user content is never the row we drop;
--   2. then whichever row describes the listing most fully;
--   3. then the earliest, which is the original rather than the re-sync;
--   4. then id, purely so the result is deterministic.
CREATE OR REPLACE VIEW public.hearings_dedupe_ranked AS
SELECT
  id,
  row_number() OVER (
    PARTITION BY case_id, hearing_date
    ORDER BY
      CASE
        WHEN coalesce(btrim(notes), '') <> ''
         AND notes NOT IN ('Imported from eCourts', 'Synced from eCourts Update')
        THEN 0 ELSE 1
      END,
      (CASE WHEN purpose IS NULL THEN 0 ELSE 1 END)
        + (CASE WHEN stage IS NULL THEN 0 ELSE 1 END)
        + (CASE WHEN coalesce(btrim(notes), '') = '' THEN 0 ELSE 1 END) DESC,
      created_at ASC,
      id ASC
  ) AS rn
FROM public.hearings
WHERE case_id IS NOT NULL;

INSERT INTO public.hearings_dedupe_backup (
  id, case_id, hearing_date, purpose, stage, status, notes,
  created_by, created_at, updated_at, deleted_at
)
SELECT
  h.id, h.case_id, h.hearing_date, h.purpose, h.stage, h.status, h.notes,
  h.created_by, h.created_at, h.updated_at, h.deleted_at
FROM public.hearings h
JOIN public.hearings_dedupe_ranked r ON r.id = h.id
WHERE r.rn > 1
  AND NOT EXISTS (
    SELECT 1 FROM public.hearings_dedupe_backup b WHERE b.id = h.id
  );

DELETE FROM public.hearings h
USING public.hearings_dedupe_ranked r
WHERE h.id = r.id AND r.rn > 1;

DROP VIEW IF EXISTS public.hearings_dedupe_ranked;

-- ── 3. Make the duplicate unrepresentable ────────────────────────────────
-- A case is listed once on a given date. Two rows for one case on one date
-- is a duplicate, never two sittings.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.hearings'::regclass
      AND conname  = 'hearings_unique_date_per_case'
  ) THEN
    ALTER TABLE public.hearings
      ADD CONSTRAINT hearings_unique_date_per_case
      UNIQUE (case_id, hearing_date);
  END IF;
END $$;
