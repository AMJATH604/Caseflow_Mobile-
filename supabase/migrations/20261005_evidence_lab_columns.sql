-- ═══════════════════════════════════════════════════════════════
-- Evidence Lab: the columns the apps write
--
-- ⚠️ NOT YET APPLIED. Review, then `supabase db push`.
--
-- The Evidence Lab tables predate tracked migrations. Their live columns
-- (from the generated types) are:
--   evidence_checklists  item_name, notes, status
--   evidence_photos      photo_url, caption
-- but mobile writes item_type + is_completed to the checklist, and
-- description (+ reads tags) on photos. PostgREST rejects an insert naming a
-- column that does not exist, so adding a checklist item and saving a photo
-- fail on mobile today. This adds those columns — additive only, nothing is
-- dropped or rewritten — and the web uses the same shape.
-- ═══════════════════════════════════════════════════════════════

ALTER TABLE public.evidence_checklists ADD COLUMN IF NOT EXISTS item_type TEXT NOT NULL DEFAULT 'document';
ALTER TABLE public.evidence_checklists ADD COLUMN IF NOT EXISTS is_completed BOOLEAN NOT NULL DEFAULT false;

ALTER TABLE public.evidence_checklists DROP CONSTRAINT IF EXISTS evidence_checklists_item_type_check;
ALTER TABLE public.evidence_checklists
  ADD CONSTRAINT evidence_checklists_item_type_check
  CHECK (item_type IN ('document', 'witness', 'exhibit', 'pending'));

ALTER TABLE public.evidence_photos ADD COLUMN IF NOT EXISTS description TEXT;
ALTER TABLE public.evidence_photos ADD COLUMN IF NOT EXISTS tags TEXT[] NOT NULL DEFAULT '{}';

-- Older rows kept their text in `caption`; show it as the description.
UPDATE public.evidence_photos SET description = caption WHERE description IS NULL AND caption IS NOT NULL;
