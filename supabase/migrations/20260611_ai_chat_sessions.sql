-- ═══════════════════════════════════════════════════════════════
-- AI Chat Sessions — ChatGPT-style conversation management
-- ═══════════════════════════════════════════════════════════════

-- 1. Create sessions table
CREATE TABLE IF NOT EXISTS public.ai_chat_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title TEXT NOT NULL DEFAULT 'New Chat',
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- 2. Indexes for fast lookups
CREATE INDEX IF NOT EXISTS idx_chat_sessions_user_updated ON public.ai_chat_sessions(user_id, updated_at DESC);

-- 3. RLS on sessions
ALTER TABLE public.ai_chat_sessions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users read own sessions" ON public.ai_chat_sessions;
CREATE POLICY "Users read own sessions" ON public.ai_chat_sessions
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users insert own sessions" ON public.ai_chat_sessions;
CREATE POLICY "Users insert own sessions" ON public.ai_chat_sessions
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users update own sessions" ON public.ai_chat_sessions;
CREATE POLICY "Users update own sessions" ON public.ai_chat_sessions
  FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users delete own sessions" ON public.ai_chat_sessions;
CREATE POLICY "Users delete own sessions" ON public.ai_chat_sessions
  FOR DELETE USING (auth.uid() = user_id);

-- 4. Add session_id FK to existing ai_chat_history table
ALTER TABLE public.ai_chat_history 
  ADD COLUMN IF NOT EXISTS session_id UUID REFERENCES public.ai_chat_sessions(id) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS idx_chat_history_session ON public.ai_chat_history(session_id, created_at ASC);

-- 5. Migrate existing messages: create one "Previous Chat" session per user
DO $$
DECLARE
  r RECORD;
  new_session_id UUID;
BEGIN
  FOR r IN (
    SELECT DISTINCT user_id, MIN(created_at) as first_msg
    FROM public.ai_chat_history
    WHERE session_id IS NULL
    GROUP BY user_id
  ) LOOP
    new_session_id := gen_random_uuid();
    
    INSERT INTO public.ai_chat_sessions (id, user_id, title, created_at, updated_at)
    VALUES (new_session_id, r.user_id, 'Previous Chat', r.first_msg, now());
    
    UPDATE public.ai_chat_history
    SET session_id = new_session_id
    WHERE user_id = r.user_id AND session_id IS NULL;
  END LOOP;
END $$;

-- 6. Add update trigger for updated_at
CREATE OR REPLACE FUNCTION public.update_chat_session_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE public.ai_chat_sessions 
  SET updated_at = now() 
  WHERE id = NEW.session_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_update_session_on_message ON public.ai_chat_history;
CREATE TRIGGER trg_update_session_on_message
  AFTER INSERT ON public.ai_chat_history
  FOR EACH ROW
  EXECUTE FUNCTION public.update_chat_session_timestamp();
