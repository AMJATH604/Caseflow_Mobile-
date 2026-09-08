-- ═══════════════════════════════════════════════════════════════
-- Direct message delivery receipts (3-state ticks)
--
-- direct_messages already tracks is_read. To show WhatsApp's three tick
-- states we also need "delivered": the recipient's device has received the
-- message but hasn't opened the chat yet.
--
--   sent      → delivered_at NULL, is_read false   → single grey ✓
--   delivered → delivered_at set,  is_read false   → double grey ✓✓
--   read      → is_read true                       → double blue ✓✓
--
-- The recipient's app stamps delivered_at when it receives the message
-- (foreground push or when it loads the chat list).
-- ═══════════════════════════════════════════════════════════════

ALTER TABLE public.direct_messages
  ADD COLUMN IF NOT EXISTS delivered_at TIMESTAMPTZ;

-- ── Chambers group read receipts ───────────────────────────────
-- Chambers group receipts reuse the chambers_reads table from the previous
-- migration, but that migration's policy only let a user read their OWN row.
-- To show "read by all", a member must be able to READ the last_read_at of the
-- other members of the same firm. Add a SELECT policy scoped to fellow firm
-- members (owner, direct members, and accepted invited members). Writes stay
-- own-row-only via the existing "Users manage their own chambers reads" policy;
-- multiple permissive policies are OR'd, so this only widens SELECT.
DROP POLICY IF EXISTS "Firm members can view firm read markers" ON public.chambers_reads;
CREATE POLICY "Firm members can view firm read markers"
  ON public.chambers_reads
  FOR SELECT
  USING (
    -- I am the firm owner (owner's id == firm_id)
    firm_id = auth.uid()
    -- I am a direct member of this firm
    OR firm_id = (SELECT firm_id FROM public.profiles WHERE id = auth.uid())
    -- I am an accepted invited member of this firm
    OR EXISTS (
      SELECT 1 FROM public.firm_members fm
      WHERE fm.owner_id = chambers_reads.firm_id
        AND fm.member_id = auth.uid()
        AND fm.status = 'accepted'
    )
  );
