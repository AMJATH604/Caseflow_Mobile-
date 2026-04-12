-- ============================================================
-- ADVOCATE COMMISSIONER MODULE — Database Schema
-- Phase 1 MVP Tables
-- Run this in Supabase SQL Editor
-- ============================================================

-- 1. COMMISSIONS — Core commission tracking
CREATE TABLE IF NOT EXISTS commissions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  case_id UUID REFERENCES cases(id) ON DELETE CASCADE,
  commissioner_id UUID REFERENCES auth.users(id),
  commission_type TEXT NOT NULL DEFAULT 'local_investigation',
  -- Types: local_investigation, partition, survey, recording_evidence, sale
  warrant_date DATE,
  execution_date DATE,
  deadline_date DATE,
  status TEXT NOT NULL DEFAULT 'pending',
  -- Status: pending, in_progress, visit_completed, report_drafting, submitted, objections, closed
  scope_of_work TEXT,
  property_description TEXT,
  survey_number TEXT,
  village TEXT,
  taluk TEXT,
  district TEXT,
  state TEXT DEFAULT 'Tamil Nadu',
  party_petitioner TEXT,
  party_respondent TEXT,
  court_name TEXT,
  case_number_ref TEXT,
  notes TEXT,
  created_by UUID REFERENCES auth.users(id) NOT NULL,
  firm_id UUID,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. COMMISSION VISITS — GPS check-in/out per visit
CREATE TABLE IF NOT EXISTS commission_visits (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  commission_id UUID REFERENCES commissions(id) ON DELETE CASCADE NOT NULL,
  visit_date DATE NOT NULL DEFAULT CURRENT_DATE,
  checkin_time TIMESTAMPTZ,
  checkout_time TIMESTAMPTZ,
  checkin_lat DOUBLE PRECISION,
  checkin_lng DOUBLE PRECISION,
  checkout_lat DOUBLE PRECISION,
  checkout_lng DOUBLE PRECISION,
  checkin_address TEXT,
  checkout_address TEXT,
  visit_status TEXT NOT NULL DEFAULT 'planned',
  -- Status: planned, checked_in, completed, obstructed
  obstruction_details TEXT,
  weather_conditions TEXT,
  persons_present TEXT,
  created_by UUID REFERENCES auth.users(id) NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. COMMISSION OBSERVATIONS — Digital notepad entries
CREATE TABLE IF NOT EXISTS commission_observations (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  visit_id UUID REFERENCES commission_visits(id) ON DELETE CASCADE NOT NULL,
  commission_id UUID REFERENCES commissions(id) ON DELETE CASCADE NOT NULL,
  observation_type TEXT NOT NULL DEFAULT 'general',
  -- Types: general, boundary, encroachment, construction, measurement, condition, access
  content TEXT NOT NULL,
  voice_note_url TEXT,
  sequence_order INT DEFAULT 0,
  tags TEXT[] DEFAULT '{}',
  created_by UUID REFERENCES auth.users(id) NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. COMMISSION EVIDENCE — Photos/Videos with GPS metadata
CREATE TABLE IF NOT EXISTS commission_evidence (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  visit_id UUID REFERENCES commission_visits(id) ON DELETE CASCADE NOT NULL,
  commission_id UUID REFERENCES commissions(id) ON DELETE CASCADE NOT NULL,
  file_type TEXT NOT NULL DEFAULT 'photo',
  -- Types: photo, video, panorama
  file_url TEXT NOT NULL,
  thumbnail_url TEXT,
  caption TEXT,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  direction TEXT,
  sha256_hash TEXT,
  sequence_number INT DEFAULT 0,
  created_by UUID REFERENCES auth.users(id) NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. COMMISSION EXPENSES — Expense tracking
CREATE TABLE IF NOT EXISTS commission_expenses (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  commission_id UUID REFERENCES commissions(id) ON DELETE CASCADE NOT NULL,
  expense_type TEXT NOT NULL DEFAULT 'travel',
  -- Types: travel, clerical, photography, stamp_paper, printing, miscellaneous
  amount DOUBLE PRECISION NOT NULL DEFAULT 0,
  description TEXT,
  expense_date DATE DEFAULT CURRENT_DATE,
  receipt_url TEXT,
  created_by UUID REFERENCES auth.users(id) NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 6. COMMISSION REPORTS — Generated PDF reports
CREATE TABLE IF NOT EXISTS commission_reports (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  commission_id UUID REFERENCES commissions(id) ON DELETE CASCADE NOT NULL,
  version INT DEFAULT 1,
  report_content TEXT,
  pdf_url TEXT,
  submitted_date DATE,
  status TEXT NOT NULL DEFAULT 'draft',
  -- Status: draft, finalized, submitted, accepted, rejected
  created_by UUID REFERENCES auth.users(id) NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);


-- ============================================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================================

ALTER TABLE commissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE commission_visits ENABLE ROW LEVEL SECURITY;
ALTER TABLE commission_observations ENABLE ROW LEVEL SECURITY;
ALTER TABLE commission_evidence ENABLE ROW LEVEL SECURITY;
ALTER TABLE commission_expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE commission_reports ENABLE ROW LEVEL SECURITY;

-- Commissions: Users can manage their own or firm's commissions
CREATE POLICY "commissions_select" ON commissions FOR SELECT USING (
  created_by = auth.uid() OR firm_id = auth.uid() OR commissioner_id = auth.uid()
);
CREATE POLICY "commissions_insert" ON commissions FOR INSERT WITH CHECK (
  created_by = auth.uid()
);
CREATE POLICY "commissions_update" ON commissions FOR UPDATE USING (
  created_by = auth.uid() OR commissioner_id = auth.uid()
);
CREATE POLICY "commissions_delete" ON commissions FOR DELETE USING (
  created_by = auth.uid()
);

-- Visits: Access through commission ownership
CREATE POLICY "visits_select" ON commission_visits FOR SELECT USING (
  created_by = auth.uid() OR commission_id IN (
    SELECT id FROM commissions WHERE created_by = auth.uid() OR commissioner_id = auth.uid() OR firm_id = auth.uid()
  )
);
CREATE POLICY "visits_insert" ON commission_visits FOR INSERT WITH CHECK (created_by = auth.uid());
CREATE POLICY "visits_update" ON commission_visits FOR UPDATE USING (created_by = auth.uid());
CREATE POLICY "visits_delete" ON commission_visits FOR DELETE USING (created_by = auth.uid());

-- Observations
CREATE POLICY "observations_select" ON commission_observations FOR SELECT USING (
  created_by = auth.uid() OR commission_id IN (
    SELECT id FROM commissions WHERE created_by = auth.uid() OR commissioner_id = auth.uid() OR firm_id = auth.uid()
  )
);
CREATE POLICY "observations_insert" ON commission_observations FOR INSERT WITH CHECK (created_by = auth.uid());
CREATE POLICY "observations_update" ON commission_observations FOR UPDATE USING (created_by = auth.uid());
CREATE POLICY "observations_delete" ON commission_observations FOR DELETE USING (created_by = auth.uid());

-- Evidence
CREATE POLICY "evidence_select" ON commission_evidence FOR SELECT USING (
  created_by = auth.uid() OR commission_id IN (
    SELECT id FROM commissions WHERE created_by = auth.uid() OR commissioner_id = auth.uid() OR firm_id = auth.uid()
  )
);
CREATE POLICY "evidence_insert" ON commission_evidence FOR INSERT WITH CHECK (created_by = auth.uid());
CREATE POLICY "evidence_delete" ON commission_evidence FOR DELETE USING (created_by = auth.uid());

-- Expenses
CREATE POLICY "expenses_select" ON commission_expenses FOR SELECT USING (
  created_by = auth.uid() OR commission_id IN (
    SELECT id FROM commissions WHERE created_by = auth.uid() OR commissioner_id = auth.uid() OR firm_id = auth.uid()
  )
);
CREATE POLICY "expenses_insert" ON commission_expenses FOR INSERT WITH CHECK (created_by = auth.uid());
CREATE POLICY "expenses_update" ON commission_expenses FOR UPDATE USING (created_by = auth.uid());
CREATE POLICY "expenses_delete" ON commission_expenses FOR DELETE USING (created_by = auth.uid());

-- Reports
CREATE POLICY "reports_select" ON commission_reports FOR SELECT USING (
  created_by = auth.uid() OR commission_id IN (
    SELECT id FROM commissions WHERE created_by = auth.uid() OR commissioner_id = auth.uid() OR firm_id = auth.uid()
  )
);
CREATE POLICY "reports_insert" ON commission_reports FOR INSERT WITH CHECK (created_by = auth.uid());
CREATE POLICY "reports_update" ON commission_reports FOR UPDATE USING (created_by = auth.uid());
CREATE POLICY "reports_delete" ON commission_reports FOR DELETE USING (created_by = auth.uid());

-- ============================================================
-- STORAGE BUCKET for commission evidence files
-- ============================================================
INSERT INTO storage.buckets (id, name, public) 
VALUES ('commission-evidence', 'commission-evidence', true)
ON CONFLICT (id) DO NOTHING;

-- Storage policies
CREATE POLICY "commission_evidence_upload" ON storage.objects FOR INSERT 
WITH CHECK (bucket_id = 'commission-evidence' AND auth.uid() IS NOT NULL);

CREATE POLICY "commission_evidence_select" ON storage.objects FOR SELECT 
USING (bucket_id = 'commission-evidence');

CREATE POLICY "commission_evidence_delete" ON storage.objects FOR DELETE 
USING (bucket_id = 'commission-evidence' AND auth.uid() IS NOT NULL);

-- ============================================================
-- INDEXES for performance
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_commissions_created_by ON commissions(created_by);
CREATE INDEX IF NOT EXISTS idx_commissions_case_id ON commissions(case_id);
CREATE INDEX IF NOT EXISTS idx_commissions_status ON commissions(status);
CREATE INDEX IF NOT EXISTS idx_commission_visits_commission_id ON commission_visits(commission_id);
CREATE INDEX IF NOT EXISTS idx_commission_evidence_visit_id ON commission_evidence(visit_id);
CREATE INDEX IF NOT EXISTS idx_commission_expenses_commission_id ON commission_expenses(commission_id);
