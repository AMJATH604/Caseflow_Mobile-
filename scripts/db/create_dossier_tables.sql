-- ============================================================
-- eCourt-Style Case Dossier — Database Migration
-- Creates 3 new tables: case_acts, case_ia_applications, case_interim_orders
-- Run this in Supabase SQL Editor (https://supabase.com/dashboard)
-- ============================================================

-- 1. Acts & Sections applicable to a case
CREATE TABLE IF NOT EXISTS case_acts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  case_id UUID NOT NULL REFERENCES cases(id) ON DELETE CASCADE,
  act_name TEXT NOT NULL,
  section_number TEXT,
  created_by UUID NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 2. Interlocutory Applications
CREATE TABLE IF NOT EXISTS case_ia_applications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  case_id UUID NOT NULL REFERENCES cases(id) ON DELETE CASCADE,
  ia_number TEXT NOT NULL,
  classification TEXT,
  party TEXT,
  filing_date DATE,
  next_date DATE,
  ia_status TEXT DEFAULT 'pending',
  created_by UUID NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 3. Interim Orders / Depositions
CREATE TABLE IF NOT EXISTS case_interim_orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  case_id UUID NOT NULL REFERENCES cases(id) ON DELETE CASCADE,
  order_number INT,
  order_date DATE NOT NULL,
  order_type TEXT DEFAULT 'deposition',
  order_summary TEXT,
  document_url TEXT,
  created_by UUID NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================================
-- Row Level Security (RLS) — Enables access control
-- ============================================================

ALTER TABLE case_acts ENABLE ROW LEVEL SECURITY;
ALTER TABLE case_ia_applications ENABLE ROW LEVEL SECURITY;
ALTER TABLE case_interim_orders ENABLE ROW LEVEL SECURITY;

-- Policy: Users can read acts for cases they have access to
CREATE POLICY "Users can read case_acts" ON case_acts
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM cases c
      WHERE c.id = case_acts.case_id
      AND (c.assigned_to = auth.uid() OR c.firm_id = auth.uid()
           OR c.firm_id IN (SELECT firm_id FROM profiles WHERE id = auth.uid() AND firm_id IS NOT NULL))
    )
  );

-- Policy: Users can insert acts for cases they own
CREATE POLICY "Users can insert case_acts" ON case_acts
  FOR INSERT WITH CHECK (auth.uid() = created_by);

-- Policy: Users can delete their own acts
CREATE POLICY "Users can delete case_acts" ON case_acts
  FOR DELETE USING (auth.uid() = created_by);

-- Policy: Users can read IAs for cases they have access to
CREATE POLICY "Users can read case_ia_applications" ON case_ia_applications
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM cases c
      WHERE c.id = case_ia_applications.case_id
      AND (c.assigned_to = auth.uid() OR c.firm_id = auth.uid()
           OR c.firm_id IN (SELECT firm_id FROM profiles WHERE id = auth.uid() AND firm_id IS NOT NULL))
    )
  );

-- Policy: Users can insert IAs
CREATE POLICY "Users can insert case_ia_applications" ON case_ia_applications
  FOR INSERT WITH CHECK (auth.uid() = created_by);

-- Policy: Users can update their own IAs
CREATE POLICY "Users can update case_ia_applications" ON case_ia_applications
  FOR UPDATE USING (auth.uid() = created_by);

-- Policy: Users can delete their own IAs
CREATE POLICY "Users can delete case_ia_applications" ON case_ia_applications
  FOR DELETE USING (auth.uid() = created_by);

-- Policy: Users can read interim orders for cases they have access to
CREATE POLICY "Users can read case_interim_orders" ON case_interim_orders
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM cases c
      WHERE c.id = case_interim_orders.case_id
      AND (c.assigned_to = auth.uid() OR c.firm_id = auth.uid()
           OR c.firm_id IN (SELECT firm_id FROM profiles WHERE id = auth.uid() AND firm_id IS NOT NULL))
    )
  );

-- Policy: Users can insert interim orders
CREATE POLICY "Users can insert case_interim_orders" ON case_interim_orders
  FOR INSERT WITH CHECK (auth.uid() = created_by);

-- Policy: Users can delete their own interim orders
CREATE POLICY "Users can delete case_interim_orders" ON case_interim_orders
  FOR DELETE USING (auth.uid() = created_by);

-- ============================================================
-- Indexes for query performance
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_case_acts_case_id ON case_acts(case_id);
CREATE INDEX IF NOT EXISTS idx_case_ia_case_id ON case_ia_applications(case_id);
CREATE INDEX IF NOT EXISTS idx_case_interim_orders_case_id ON case_interim_orders(case_id);

-- ============================================================
-- Also clean up cascade deletes in the workspace reset
-- ============================================================
-- Note: case_acts, case_ia_applications, and case_interim_orders 
-- will be automatically deleted when a case is deleted (ON DELETE CASCADE).
-- No additional cleanup needed in the application's resetUserWorkspace().
