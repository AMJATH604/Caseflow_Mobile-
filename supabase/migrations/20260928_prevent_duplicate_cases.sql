-- ─────────────────────────────────────────────────────────
-- Stop the same case being filed twice.
--
-- Nothing guarded this before: createCase validated only the required fields
-- and the title length, and no constraint existed on the table, so the same
-- case could be created any number of times by hand.
--
-- Scope is (firm, case number, court) rather than the case number alone.
-- Case numbers repeat across courts — every district court in Tamil Nadu has
-- an OS/448/2022 — so a number-only rule would falsely block an advocate
-- practising in two courts. The title is deliberately NOT part of the key:
-- the same case is often written "Amjath vs Aadil" and "Amjath Vs. Aadil",
-- and blocking on that would be wrong. The app warns on a title match
-- instead, and lets the user decide.
--
-- Verified before writing: zero rows in the live table violate this key.
-- ─────────────────────────────────────────────────────────

-- ─── Normalisers ──────────────────────────────────────────
-- IMMUTABLE so they can be used in an index expression.

-- "OS/448/2022", "os 448 / 2022" and "OS-448-2022" all collapse to os4482022.
CREATE OR REPLACE FUNCTION public.case_number_key(p_value text)
RETURNS text
LANGUAGE sql
IMMUTABLE
PARALLEL SAFE
AS $fn$
  SELECT regexp_replace(lower(coalesce(p_value, '')), '[^a-z0-9]', '', 'g');
$fn$;

-- Court names keep their word boundaries — only case and runs of whitespace
-- are normalised, so "Sub Court" and "Subordinate Court" stay distinct.
CREATE OR REPLACE FUNCTION public.case_court_key(p_value text)
RETURNS text
LANGUAGE sql
IMMUTABLE
PARALLEL SAFE
AS $fn$
  SELECT regexp_replace(lower(btrim(coalesce(p_value, ''))), '\s+', ' ', 'g');
$fn$;

-- Titles collapse punctuation and whitespace so "Amjath vs Aadil",
-- "Amjath  Vs. Aadil" and "AMJATH VS AADIL" compare equal.
CREATE OR REPLACE FUNCTION public.case_title_key(p_value text)
RETURNS text
LANGUAGE sql
IMMUTABLE
PARALLEL SAFE
AS $fn$
  SELECT regexp_replace(
           regexp_replace(lower(btrim(coalesce(p_value, ''))), '[^a-z0-9]+', ' ', 'g'),
           '\s+', ' ', 'g');
$fn$;

-- ─── The constraint ───────────────────────────────────────
-- Partial: rows without a case number are not constrained (a matter can be
-- entered before it is numbered), and soft-deleted rows are ignored so a
-- deleted case never blocks re-creating it.

DROP INDEX IF EXISTS public.cases_unique_number_per_court;

CREATE UNIQUE INDEX cases_unique_number_per_court
  ON public.cases (
    firm_id,
    public.case_number_key(case_number),
    public.case_court_key(court_name)
  )
  WHERE deleted_at IS NULL
    AND case_number IS NOT NULL
    AND btrim(case_number) <> '';

-- Supports the title-warning lookup below.
CREATE INDEX IF NOT EXISTS cases_title_key_idx
  ON public.cases (firm_id, public.case_title_key(case_title))
  WHERE deleted_at IS NULL;

-- ─── Lookup used by the app before it saves ───────────────
-- SECURITY INVOKER (the default) on purpose: RLS then scopes the search to
-- cases the caller may already see, which is exactly the right scope. A
-- SECURITY DEFINER version would report duplicates inside other firms and
-- leak their case titles.
--
-- match_type is 'number' for a hard conflict — same number in the same court,
-- which the unique index will reject anyway — or 'title' for a soft one the
-- user is asked about.

CREATE OR REPLACE FUNCTION public.find_conflicting_cases(
  p_case_number text,
  p_court_name  text,
  p_case_title  text,
  p_exclude_id  uuid DEFAULT NULL
)
RETURNS TABLE (
  id          uuid,
  case_title  text,
  case_number text,
  court_name  text,
  match_type  text
)
LANGUAGE sql
STABLE
AS $fn$
  SELECT c.id, c.case_title, c.case_number, c.court_name,
         CASE
           WHEN p_case_number IS NOT NULL
            AND btrim(p_case_number) <> ''
            AND public.case_number_key(c.case_number) = public.case_number_key(p_case_number)
            AND public.case_court_key(c.court_name)   = public.case_court_key(p_court_name)
           THEN 'number'
           ELSE 'title'
         END AS match_type
    FROM public.cases c
   WHERE c.deleted_at IS NULL
     AND (p_exclude_id IS NULL OR c.id <> p_exclude_id)
     AND (
           (    p_case_number IS NOT NULL
            AND btrim(p_case_number) <> ''
            AND public.case_number_key(c.case_number) = public.case_number_key(p_case_number)
            AND public.case_court_key(c.court_name)   = public.case_court_key(p_court_name))
        OR (    p_case_title IS NOT NULL
            AND btrim(p_case_title) <> ''
            AND public.case_title_key(c.case_title) = public.case_title_key(p_case_title))
       )
   -- A hard conflict must sort first: the caller shows only the first row
   -- when it blocks.
   ORDER BY match_type ASC
   LIMIT 5;
$fn$;

REVOKE ALL ON FUNCTION public.find_conflicting_cases(text, text, text, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.find_conflicting_cases(text, text, text, uuid) TO authenticated;

REVOKE ALL ON FUNCTION public.case_number_key(text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.case_court_key(text)  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.case_title_key(text)  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.case_number_key(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.case_court_key(text)  TO authenticated;
GRANT EXECUTE ON FUNCTION public.case_title_key(text)  TO authenticated;
