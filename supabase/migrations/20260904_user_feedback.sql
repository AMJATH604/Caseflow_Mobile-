-- ═══════════════════════════════════════════════════════════════
-- User Feedback System
-- Stores bug reports, feature requests, and general feedback
-- from advocates during alpha/beta testing
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.user_feedback (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  user_name TEXT,
  user_email TEXT,
  
  -- Feedback metadata
  feedback_type TEXT NOT NULL CHECK (feedback_type IN ('bug', 'feature', 'general', 'ui_issue', 'crash')),
  severity TEXT DEFAULT 'medium' CHECK (severity IN ('low', 'medium', 'high', 'critical')),
  
  -- Content
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  
  -- Context (auto-captured)
  screen_name TEXT,                -- Which screen the user was on
  app_version TEXT,                -- e.g., '2.0.0'
  device_info TEXT,                -- e.g., 'Samsung Galaxy S21, Android 14'
  
  -- Admin management
  status TEXT DEFAULT 'new' CHECK (status IN ('new', 'reviewed', 'in_progress', 'resolved', 'wont_fix')),
  admin_notes TEXT,
  resolved_at TIMESTAMPTZ,
  
  created_at TIMESTAMPTZ DEFAULT now()
);

-- RLS: Users can insert their own feedback, read only their own
ALTER TABLE public.user_feedback ENABLE ROW LEVEL SECURITY;

-- Users can create feedback
CREATE POLICY "Users can insert feedback"
  ON public.user_feedback FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- Users can view their own feedback
CREATE POLICY "Users can view own feedback"
  ON public.user_feedback FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- Index for admin queries
CREATE INDEX idx_feedback_status ON public.user_feedback(status);
CREATE INDEX idx_feedback_type ON public.user_feedback(feedback_type);
CREATE INDEX idx_feedback_created ON public.user_feedback(created_at DESC);

-- ═══════════════════════════════════════════════════════════════
-- Admin notification: Trigger function that sends a webhook 
-- when new feedback arrives (can be connected to Discord/Telegram/Email)
-- ═══════════════════════════════════════════════════════════════

-- Notification function (sends to pg_notify channel for edge function to pick up)
CREATE OR REPLACE FUNCTION notify_new_feedback()
RETURNS TRIGGER AS $$
BEGIN
  PERFORM pg_notify(
    'new_feedback',
    json_build_object(
      'id', NEW.id,
      'type', NEW.feedback_type,
      'severity', NEW.severity,
      'title', NEW.title,
      'user_name', NEW.user_name,
      'screen', NEW.screen_name,
      'created_at', NEW.created_at
    )::text
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER on_new_feedback
  AFTER INSERT ON public.user_feedback
  FOR EACH ROW
  EXECUTE FUNCTION notify_new_feedback();
