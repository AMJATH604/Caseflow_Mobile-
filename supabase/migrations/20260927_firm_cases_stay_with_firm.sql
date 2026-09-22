-- ═══════════════════════════════════════════════════════════════
-- Cases stay with the firm when an associate leaves
--
-- ⚠️ NOT YET APPLIED. Applying it removes creator access to 2 existing cases
-- created by account 9f4deebf under firm ce0a74f5 (no team link between them).
-- Decide who owns those cases before applying.
-- ═══════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────
-- Firm work stays with the firm
-- ─────────────────────────────────────────────────────────
-- Creator access used to be unconditional (created_by = auth.uid()), so an
-- associate kept reading and editing every case they had opened inside a firm
-- after leaving it. Creator access now requires the case to be in your own firm
-- or the firm you currently belong to. The same check stops anyone planting a
-- case into a firm they are not part of.
DROP POLICY IF EXISTS "Users can view cases in their firm" ON public.cases;
CREATE POLICY "Users can view cases in their firm" ON public.cases FOR SELECT TO public
  USING (
    firm_id = auth.uid()
    OR assigned_to = auth.uid()
    OR (created_by = auth.uid() AND firm_id IS NULL)
    OR EXISTS (SELECT 1 FROM public.profiles
                WHERE profiles.id = auth.uid() AND profiles.firm_id = cases.firm_id)
  );

DROP POLICY IF EXISTS "Users can manage cases in their firm" ON public.cases;
CREATE POLICY "Users can manage cases in their firm" ON public.cases FOR ALL TO authenticated
  USING (
    firm_id = auth.uid()
    OR assigned_to = auth.uid()
    OR (created_by = auth.uid()
        AND (firm_id IS NULL
             OR firm_id = (SELECT p.firm_id FROM public.profiles p WHERE p.id = auth.uid())))
  )
  WITH CHECK (
    firm_id = auth.uid()
    OR assigned_to = auth.uid()
    OR (created_by = auth.uid()
        AND (firm_id IS NULL
             OR firm_id = (SELECT p.firm_id FROM public.profiles p WHERE p.id = auth.uid())))
  );


