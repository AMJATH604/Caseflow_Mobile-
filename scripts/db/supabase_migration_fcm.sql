-- ============================================================
-- MIGRATION: Create fcm_tokens table for push notifications
-- Run this in Supabase SQL Editor (Dashboard > SQL Editor)
-- ============================================================

-- 1. Create the fcm_tokens table
CREATE TABLE IF NOT EXISTS public.fcm_tokens (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  token TEXT NOT NULL,
  device_info TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, token)
);

-- 2. Enable Row Level Security
ALTER TABLE public.fcm_tokens ENABLE ROW LEVEL SECURITY;

-- 3. RLS Policy: Users can only manage their own tokens
CREATE POLICY "Users can manage their own tokens"
  ON public.fcm_tokens
  FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- 4. Create index for fast lookup by user_id
CREATE INDEX IF NOT EXISTS idx_fcm_tokens_user_id ON public.fcm_tokens(user_id);


-- ============================================================
-- CRON JOBS: Schedule hearing reminder triggers
-- Run this in Supabase SQL Editor
-- Requires pg_cron extension (enabled by default on Supabase)
-- ============================================================

-- Enable pg_cron and pg_net if not already enabled
CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;

-- Grant usage to postgres role
GRANT USAGE ON SCHEMA cron TO postgres;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA cron TO postgres;

-- 7:00 PM IST (1:30 PM UTC) - Day before hearing reminder
SELECT cron.schedule(
  'hearing-reminder-7pm',
  '30 13 * * *',
  $$
  SELECT net.http_post(
    url := 'https://asrjqsnyezvcakvkokcl.supabase.co/functions/v1/send-hearing-reminders',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key')
    ),
    body := '{"reminder_type": "evening_7pm"}'::jsonb
  );
  $$
);

-- 9:00 PM IST (3:30 PM UTC) - Day before hearing reminder
SELECT cron.schedule(
  'hearing-reminder-9pm',
  '30 15 * * *',
  $$
  SELECT net.http_post(
    url := 'https://asrjqsnyezvcakvkokcl.supabase.co/functions/v1/send-hearing-reminders',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key')
    ),
    body := '{"reminder_type": "evening_9pm"}'::jsonb
  );
  $$
);

-- 9:00 AM IST (3:30 AM UTC) - Day of hearing reminder
SELECT cron.schedule(
  'hearing-reminder-9am',
  '30 3 * * *',
  $$
  SELECT net.http_post(
    url := 'https://asrjqsnyezvcakvkokcl.supabase.co/functions/v1/send-hearing-reminders',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key')
    ),
    body := '{"reminder_type": "morning_9am"}'::jsonb
  );
  $$
);
