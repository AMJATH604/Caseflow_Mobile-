-- ═══════════════════════════════════════════════════════════════
-- Notification idempotency: prevent duplicate FCM pushes per message
--
-- send-dm-notification and send-chat-notification are invoked by a
-- Supabase Database Webhook on INSERT. If that webhook is ever fired
-- twice for the same row (a duplicate webhook registration, or a
-- delivery retry after a slow/cold-start response) the edge function
-- had no way to know it had already sent — resulting in two real FCM
-- pushes, and two notifications on the recipient's device, for one
-- message.
--
-- `notified_at` lets each function atomically "claim" a message row
-- before sending: `UPDATE ... SET notified_at = now() WHERE id = $1
-- AND notified_at IS NULL RETURNING id`. Only the invocation that gets
-- a row back proceeds to send; a second invocation for the same row
-- sees `notified_at` already set and skips.
-- ═══════════════════════════════════════════════════════════════

ALTER TABLE public.direct_messages
  ADD COLUMN IF NOT EXISTS notified_at TIMESTAMPTZ;

ALTER TABLE public.case_discussions
  ADD COLUMN IF NOT EXISTS notified_at TIMESTAMPTZ;
