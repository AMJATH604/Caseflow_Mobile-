-- ============================================================
-- ADVOCATE COMMISSIONER MODULE — Phase 2 Migration
-- Run this in Supabase SQL Editor AFTER Phase 1 tables exist
-- ============================================================

-- 1. COMMISSION WITNESSES — Witness statement recording
CREATE TABLE IF NOT EXISTS commission_witnesses (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  visit_id UUID REFERENCES commission_visits(id) ON DELETE CASCADE NOT NULL,
  commission_id UUID REFERENCES commissions(id) ON DELETE CASCADE NOT NULL,
  witness_name TEXT NOT NULL,
  id_type TEXT DEFAULT 'aadhaar',
  -- Types: aadhaar, voter_id, pan, driving_license, passport, other
  id_number TEXT,
  photo_url TEXT,
  statement_text TEXT,
  audio_url TEXT,
  signature_url TEXT,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  created_by UUID REFERENCES auth.users(id) NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. COMMISSION SKETCHES — Digital sketch pad drawings
CREATE TABLE IF NOT EXISTS commission_sketches (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  visit_id UUID REFERENCES commission_visits(id) ON DELETE CASCADE,
  commission_id UUID REFERENCES commissions(id) ON DELETE CASCADE NOT NULL,
  title TEXT DEFAULT 'Untitled Sketch',
  sketch_type TEXT NOT NULL DEFAULT 'general',
  -- Types: property_layout, boundary, measurement, general
  sketch_data JSONB,
  -- Stores stroke data: [{color, width, points: [{x,y}...]}]
  sketch_image_url TEXT,
  -- PNG export saved to storage
  annotations JSONB DEFAULT '[]',
  -- Text annotations: [{text, x, y, fontSize, color}]
  north_angle DOUBLE PRECISION DEFAULT 0,
  -- Rotation of north arrow in degrees
  created_by UUID REFERENCES auth.users(id) NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. COMMISSION NOTIFICATIONS — Deadline/visit reminders
CREATE TABLE IF NOT EXISTS commission_notifications (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  commission_id UUID REFERENCES commissions(id) ON DELETE CASCADE NOT NULL,
  notification_type TEXT NOT NULL DEFAULT 'deadline_reminder',
  -- Types: deadline_reminder, visit_scheduled, report_overdue, general
  title TEXT NOT NULL,
  body TEXT,
  scheduled_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  sent BOOLEAN DEFAULT FALSE,
  created_by UUID REFERENCES auth.users(id) NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);


-- ============================================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================================

ALTER TABLE commission_witnesses ENABLE ROW LEVEL SECURITY;
ALTER TABLE commission_sketches ENABLE ROW LEVEL SECURITY;
ALTER TABLE commission_notifications ENABLE ROW LEVEL SECURITY;

-- Witnesses
CREATE POLICY "witnesses_select" ON commission_witnesses FOR SELECT USING (
  created_by = auth.uid() OR commission_id IN (
    SELECT id FROM commissions WHERE created_by = auth.uid() OR commissioner_id = auth.uid() OR firm_id = auth.uid()
  )
);
CREATE POLICY "witnesses_insert" ON commission_witnesses FOR INSERT WITH CHECK (created_by = auth.uid());
CREATE POLICY "witnesses_update" ON commission_witnesses FOR UPDATE USING (created_by = auth.uid());
CREATE POLICY "witnesses_delete" ON commission_witnesses FOR DELETE USING (created_by = auth.uid());

-- Sketches
CREATE POLICY "sketches_select" ON commission_sketches FOR SELECT USING (
  created_by = auth.uid() OR commission_id IN (
    SELECT id FROM commissions WHERE created_by = auth.uid() OR commissioner_id = auth.uid() OR firm_id = auth.uid()
  )
);
CREATE POLICY "sketches_insert" ON commission_sketches FOR INSERT WITH CHECK (created_by = auth.uid());
CREATE POLICY "sketches_update" ON commission_sketches FOR UPDATE USING (created_by = auth.uid());
CREATE POLICY "sketches_delete" ON commission_sketches FOR DELETE USING (created_by = auth.uid());

-- Notifications
CREATE POLICY "notifications_select" ON commission_notifications FOR SELECT USING (
  created_by = auth.uid() OR commission_id IN (
    SELECT id FROM commissions WHERE created_by = auth.uid() OR commissioner_id = auth.uid() OR firm_id = auth.uid()
  )
);
CREATE POLICY "notifications_insert" ON commission_notifications FOR INSERT WITH CHECK (created_by = auth.uid());
CREATE POLICY "notifications_update" ON commission_notifications FOR UPDATE USING (created_by = auth.uid());
CREATE POLICY "notifications_delete" ON commission_notifications FOR DELETE USING (created_by = auth.uid());

-- ============================================================
-- STORAGE BUCKET for witness audio & sketches
-- ============================================================
INSERT INTO storage.buckets (id, name, public) 
VALUES ('commission-witnesses', 'commission-witnesses', true)
ON CONFLICT (id) DO NOTHING;

INSERT INTO storage.buckets (id, name, public) 
VALUES ('commission-sketches', 'commission-sketches', true)
ON CONFLICT (id) DO NOTHING;

-- Witness storage policies
CREATE POLICY "witness_upload" ON storage.objects FOR INSERT 
WITH CHECK (bucket_id = 'commission-witnesses' AND auth.uid() IS NOT NULL);

CREATE POLICY "witness_select" ON storage.objects FOR SELECT 
USING (bucket_id = 'commission-witnesses');

CREATE POLICY "witness_delete" ON storage.objects FOR DELETE 
USING (bucket_id = 'commission-witnesses' AND auth.uid() IS NOT NULL);

-- Sketch storage policies
CREATE POLICY "sketch_upload" ON storage.objects FOR INSERT 
WITH CHECK (bucket_id = 'commission-sketches' AND auth.uid() IS NOT NULL);

CREATE POLICY "sketch_select" ON storage.objects FOR SELECT 
USING (bucket_id = 'commission-sketches');

CREATE POLICY "sketch_delete" ON storage.objects FOR DELETE 
USING (bucket_id = 'commission-sketches' AND auth.uid() IS NOT NULL);


-- ============================================================
-- INDEXES for performance
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_commission_witnesses_commission_id ON commission_witnesses(commission_id);
CREATE INDEX IF NOT EXISTS idx_commission_witnesses_visit_id ON commission_witnesses(visit_id);
CREATE INDEX IF NOT EXISTS idx_commission_sketches_commission_id ON commission_sketches(commission_id);
CREATE INDEX IF NOT EXISTS idx_commission_notifications_commission_id ON commission_notifications(commission_id);
CREATE INDEX IF NOT EXISTS idx_commission_notifications_scheduled_at ON commission_notifications(scheduled_at);
