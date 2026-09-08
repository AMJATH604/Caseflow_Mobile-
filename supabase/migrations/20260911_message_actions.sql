-- ═══════════════════════════════════════════════════════════════
-- Message actions: reactions + edit (WhatsApp parity, Phase 3)
--
-- • edited_at: set when a text message is edited, so the bubble can show an
--   "edited" label. Applies to both 1-on-1 DMs and Chambers messages.
-- • message_reactions: one emoji reaction per user per message. Works for both
--   DMs and Chambers via a `scope` discriminator (the two message types live in
--   different tables, so we don't use a foreign key to either).
-- ═══════════════════════════════════════════════════════════════

ALTER TABLE public.direct_messages
  ADD COLUMN IF NOT EXISTS edited_at TIMESTAMPTZ;

ALTER TABLE public.case_discussions
  ADD COLUMN IF NOT EXISTS edited_at TIMESTAMPTZ;

CREATE TABLE IF NOT EXISTS public.message_reactions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  scope TEXT NOT NULL CHECK (scope IN ('dm', 'chambers')),
  message_id UUID NOT NULL,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  emoji TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  -- One reaction per user per message (changing emoji replaces the old one).
  UNIQUE (scope, message_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_message_reactions_lookup
  ON public.message_reactions (scope, message_id);

ALTER TABLE public.message_reactions ENABLE ROW LEVEL SECURITY;

-- Any authenticated user can read reactions (they're low-sensitivity and the
-- app only queries reactions for messages the user can already see).
DROP POLICY IF EXISTS "Anyone authenticated can read reactions" ON public.message_reactions;
CREATE POLICY "Anyone authenticated can read reactions"
  ON public.message_reactions
  FOR SELECT
  USING (auth.uid() IS NOT NULL);

-- A user can only create/change/remove their own reactions.
DROP POLICY IF EXISTS "Users manage their own reactions" ON public.message_reactions;
CREATE POLICY "Users manage their own reactions"
  ON public.message_reactions
  FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Let Realtime broadcast reaction changes so they appear live.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'message_reactions'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.message_reactions;
  END IF;
END $$;
