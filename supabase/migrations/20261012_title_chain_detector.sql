-- ─── Property Title Chain Inconsistency Detector ──────────────────
-- Migration: 20261012_title_chain_detector.sql
-- Module: Title Search — AI-powered property due-diligence
--
-- Creates four tables:
--   • title_searches        — A property title search session
--   • title_documents       — Uploaded documents (deed, EC, patta, etc.)
--   • title_findings        — Cross-reference check results (critical/warning/passed)
--   • title_chain_links     — Ownership timeline entries
--
-- Storage bucket: title-docs (private, per-user)

-- ─── Table: title_searches ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS title_searches (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  firm_id         UUID,

  -- Property identification
  property_name   TEXT,                      -- Optional friendly name
  district        TEXT NOT NULL,
  taluk           TEXT NOT NULL,
  village         TEXT NOT NULL,
  survey_number   TEXT NOT NULL,
  old_survey_number TEXT,                    -- Pre-resurvey number if known
  extent          DECIMAL,
  extent_unit     TEXT DEFAULT 'acres' CHECK (extent_unit IN ('acres', 'cents', 'hectares', 'sq_feet', 'sq_meters', 'guntas')),
  classification  TEXT,                      -- wet_land, dry_land, house_site, etc.

  -- Proposed transaction
  proposed_seller TEXT,                      -- Name of the person selling
  proposed_buyer  TEXT,                      -- Name of the person buying
  proposed_price  DECIMAL,

  -- Analysis results
  status          TEXT DEFAULT 'draft'
                  CHECK (status IN ('draft', 'uploading', 'extracting', 'analyzing', 'completed', 'error')),
  health_score    INTEGER,                   -- 0–100
  critical_count  INTEGER DEFAULT 0,
  warning_count   INTEGER DEFAULT 0,
  passed_count    INTEGER DEFAULT 0,
  total_checks    INTEGER DEFAULT 0,

  -- Advocate's final opinion
  advocate_opinion TEXT,
  opinion_date    TIMESTAMPTZ,

  -- Error tracking
  error_message   TEXT,

  created_at      TIMESTAMPTZ DEFAULT now(),
  updated_at      TIMESTAMPTZ DEFAULT now()
);

-- ─── Table: title_documents ───────────────────────────────────────
CREATE TABLE IF NOT EXISTS title_documents (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  search_id       UUID REFERENCES title_searches(id) ON DELETE CASCADE NOT NULL,
  user_id         UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,

  -- Document metadata
  document_type   TEXT NOT NULL
                  CHECK (document_type IN (
                    'sale_deed', 'parent_deed', 'grandparent_deed',
                    'encumbrance_certificate', 'patta', 'chitta',
                    'legal_heir_certificate', 'partition_deed',
                    'will', 'gift_deed', 'death_certificate',
                    'fmb_sketch', 'power_of_attorney', 'tax_receipt',
                    'mortgage_deed', 'release_deed', 'court_order',
                    'other'
                  )),
  document_label  TEXT,                      -- User-friendly label like "Parent Deed (2005)"
  file_path       TEXT NOT NULL,             -- Supabase Storage path
  file_name       TEXT,
  file_size       INTEGER,
  mime_type       TEXT,
  page_count      INTEGER,

  -- OCR & extraction
  raw_text        TEXT,                      -- Full OCR text
  extracted_data  JSONB,                     -- Structured extraction (see PRD schema)
  extraction_confidence DECIMAL,             -- 0.0 – 1.0
  extraction_status TEXT DEFAULT 'pending'
                  CHECK (extraction_status IN ('pending', 'processing', 'completed', 'failed', 'needs_review')),
  extraction_error TEXT,

  -- Ordering in the chain
  chain_position  INTEGER,                   -- 1 = oldest document in chain

  created_at      TIMESTAMPTZ DEFAULT now()
);

-- ─── Table: title_findings ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS title_findings (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  search_id       UUID REFERENCES title_searches(id) ON DELETE CASCADE NOT NULL,

  -- Check identification
  check_code      TEXT NOT NULL,             -- e.g. 'SELLER_BUYER_LINKAGE', 'SURVEY_NUMBER_MATCH'
  check_name      TEXT NOT NULL,             -- Human-readable name
  category        TEXT NOT NULL DEFAULT 'chain'
                  CHECK (category IN ('chain', 'identity', 'red_flag', 'completeness')),

  -- Result
  severity        TEXT NOT NULL
                  CHECK (severity IN ('critical', 'warning', 'passed', 'info')),
  status          TEXT DEFAULT 'open'
                  CHECK (status IN ('open', 'acknowledged', 'resolved', 'false_positive')),

  -- Details
  description     TEXT NOT NULL,             -- What was found
  details         JSONB,                     -- Structured comparison data
  recommendation  TEXT,                      -- Suggested action for advocate
  legal_reference TEXT,                      -- Relevant act/section

  -- Document references
  source_doc_ids  UUID[],                    -- Which documents this finding relates to

  -- Advocate can add notes
  advocate_notes  TEXT,

  created_at      TIMESTAMPTZ DEFAULT now()
);

-- ─── Table: title_chain_links ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS title_chain_links (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  search_id       UUID REFERENCES title_searches(id) ON DELETE CASCADE NOT NULL,
  source_doc_id   UUID REFERENCES title_documents(id) ON DELETE SET NULL,

  -- Position in the ownership timeline
  link_order      INTEGER NOT NULL,          -- 1 = earliest owner
  transaction_type TEXT NOT NULL             -- sale, gift, inheritance, partition, original_grant, mortgage, release
                  CHECK (transaction_type IN (
                    'original_grant', 'sale', 'gift', 'inheritance',
                    'partition', 'will', 'mortgage', 'release',
                    'court_decree', 'government_assignment', 'other'
                  )),
  transaction_date DATE,
  document_number TEXT,
  sub_registrar_office TEXT,

  -- Parties
  from_party      JSONB,                     -- { name, father_name, address, name_variants[] }
  to_party        JSONB,

  -- Property state at this point in time
  survey_number   TEXT,
  extent          DECIMAL,
  extent_unit     TEXT,
  classification  TEXT,
  boundaries      JSONB,                     -- { north, south, east, west }

  -- Financial
  consideration   DECIMAL,
  stamp_duty_paid DECIMAL,
  guideline_value DECIMAL,

  -- Validation
  is_verified     BOOLEAN DEFAULT false,     -- Advocate manually verified this link
  notes           TEXT,

  created_at      TIMESTAMPTZ DEFAULT now()
);

-- ─── Indexes ──────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_title_searches_user_id ON title_searches(user_id);
CREATE INDEX IF NOT EXISTS idx_title_searches_status ON title_searches(status);
CREATE INDEX IF NOT EXISTS idx_title_documents_search_id ON title_documents(search_id);
CREATE INDEX IF NOT EXISTS idx_title_findings_search_id ON title_findings(search_id);
CREATE INDEX IF NOT EXISTS idx_title_findings_severity ON title_findings(severity);
CREATE INDEX IF NOT EXISTS idx_title_chain_links_search_id ON title_chain_links(search_id);
CREATE INDEX IF NOT EXISTS idx_title_chain_links_order ON title_chain_links(search_id, link_order);

-- ─── RLS Policies ─────────────────────────────────────────────────
ALTER TABLE title_searches ENABLE ROW LEVEL SECURITY;
ALTER TABLE title_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE title_findings ENABLE ROW LEVEL SECURITY;
ALTER TABLE title_chain_links ENABLE ROW LEVEL SECURITY;

-- title_searches: users see own + firm searches
CREATE POLICY "title_searches_select" ON title_searches
  FOR SELECT USING (
    auth.uid() = user_id
    OR firm_id IN (SELECT firm_id FROM profiles WHERE id = auth.uid() AND firm_id IS NOT NULL)
  );

CREATE POLICY "title_searches_insert" ON title_searches
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "title_searches_update" ON title_searches
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "title_searches_delete" ON title_searches
  FOR DELETE USING (auth.uid() = user_id);

-- title_documents: access via search ownership
CREATE POLICY "title_documents_select" ON title_documents
  FOR SELECT USING (
    search_id IN (SELECT id FROM title_searches WHERE user_id = auth.uid()
      OR firm_id IN (SELECT firm_id FROM profiles WHERE id = auth.uid() AND firm_id IS NOT NULL))
  );

CREATE POLICY "title_documents_insert" ON title_documents
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "title_documents_update" ON title_documents
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "title_documents_delete" ON title_documents
  FOR DELETE USING (auth.uid() = user_id);

-- title_findings: access via search ownership
CREATE POLICY "title_findings_select" ON title_findings
  FOR SELECT USING (
    search_id IN (SELECT id FROM title_searches WHERE user_id = auth.uid()
      OR firm_id IN (SELECT firm_id FROM profiles WHERE id = auth.uid() AND firm_id IS NOT NULL))
  );

CREATE POLICY "title_findings_all" ON title_findings
  FOR ALL USING (
    search_id IN (SELECT id FROM title_searches WHERE user_id = auth.uid())
  );

-- title_chain_links: access via search ownership
CREATE POLICY "title_chain_links_select" ON title_chain_links
  FOR SELECT USING (
    search_id IN (SELECT id FROM title_searches WHERE user_id = auth.uid()
      OR firm_id IN (SELECT firm_id FROM profiles WHERE id = auth.uid() AND firm_id IS NOT NULL))
  );

CREATE POLICY "title_chain_links_all" ON title_chain_links
  FOR ALL USING (
    search_id IN (SELECT id FROM title_searches WHERE user_id = auth.uid())
  );

-- ─── Storage Bucket ───────────────────────────────────────────────
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'title-docs',
  'title-docs',
  false,
  52428800,  -- 50 MB max per file
  ARRAY['application/pdf', 'image/jpeg', 'image/png', 'image/webp', 'image/tiff']
)
ON CONFLICT (id) DO NOTHING;

-- Storage RLS: users can manage their own title docs
CREATE POLICY "title_docs_upload" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'title-docs'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "title_docs_read" ON storage.objects
  FOR SELECT USING (
    bucket_id = 'title-docs'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "title_docs_delete" ON storage.objects
  FOR DELETE USING (
    bucket_id = 'title-docs'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- ─── Updated-at trigger ──────────────────────────────────────────
CREATE OR REPLACE FUNCTION update_title_search_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER title_searches_updated_at
  BEFORE UPDATE ON title_searches
  FOR EACH ROW EXECUTE FUNCTION update_title_search_updated_at();
