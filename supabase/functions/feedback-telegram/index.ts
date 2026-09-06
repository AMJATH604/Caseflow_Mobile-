// CaseFlow Feedback → Telegram Notification
// Supabase Edge Function triggered by Database Webhook on user_feedback INSERT
//
// Setup:
// 1. Deploy this edge function
// 2. Go to Supabase Dashboard → Database → Webhooks
// 3. Create webhook: Table = user_feedback, Event = INSERT
// 4. Point to: https://<project-ref>.supabase.co/functions/v1/feedback-telegram

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { verifyWebhookAuth } from "../_shared/auth_guard.ts";

// ─── Secrets ────────────────────────────────────────────────
// Set these before deploying:
//   supabase secrets set TELEGRAM_BOT_TOKEN=<token from BotFather>
//   supabase secrets set TELEGRAM_ADMIN_CHAT_ID=<numeric chat id>
const TELEGRAM_BOT_TOKEN = Deno.env.get("TELEGRAM_BOT_TOKEN");
const ADMIN_CHAT_ID = Deno.env.get("TELEGRAM_ADMIN_CHAT_ID");

// Emoji map for feedback types
const TYPE_EMOJI: Record<string, string> = {
  bug: "🐛",
  feature: "💡",
  general: "💬",
  ui_issue: "🎨",
  crash: "💥",
};

const TYPE_LABEL: Record<string, string> = {
  bug: "BUG REPORT",
  feature: "FEATURE REQUEST",
  general: "GENERAL FEEDBACK",
  ui_issue: "UI/UX ISSUE",
  crash: "APP CRASH",
};

const SEVERITY_EMOJI: Record<string, string> = {
  low: "🟢",
  medium: "🟡",
  high: "🟠",
  critical: "🔴",
};

serve(async (req: Request) => {
  // ─── Auth Guard: this endpoint is a database webhook target ──
  const authError = await verifyWebhookAuth(req);
  if (authError) return authError;

  if (!TELEGRAM_BOT_TOKEN || !ADMIN_CHAT_ID) {
    console.error(
      "feedback-telegram: TELEGRAM_BOT_TOKEN / TELEGRAM_ADMIN_CHAT_ID not configured",
    );
    return new Response(
      JSON.stringify({ success: false, error: "Telegram notifier not configured" }),
      { status: 503, headers: { "Content-Type": "application/json" } },
    );
  }

  try {
    const payload = await req.json();

    // Database webhook sends: { type: 'INSERT', table: 'user_feedback', record: {...} }
    const record = payload.record || payload;

    const type = record.feedback_type || "general";
    const severity = record.severity || "medium";
    const typeEmoji = TYPE_EMOJI[type] || "💬";
    const typeLabel = TYPE_LABEL[type] || "FEEDBACK";
    const sevEmoji = SEVERITY_EMOJI[severity] || "🟡";

    const message = [
      `${typeEmoji} *NEW ${typeLabel}* ${sevEmoji} ${severity.toUpperCase()}`,
      `━━━━━━━━━━━━━━━━━`,
      `👤 *User:* ${record.user_name || "Unknown"}`,
      `📧 *Email:* ${record.user_email || "N/A"}`,
      `📱 *Screen:* ${record.screen_name || "N/A"}`,
      `📋 *Title:* ${escapeMarkdown(record.title || "No title")}`,
      ``,
      `📝 *Description:*`,
      `${escapeMarkdown(record.description || "No description")}`,
      ``,
      `🔧 *App:* v${record.app_version || "?"} | ${record.device_info || "Unknown device"}`,
      `🕐 *Time:* ${new Date(record.created_at).toLocaleString("en-IN", { timeZone: "Asia/Kolkata" })}`,
      `━━━━━━━━━━━━━━━━━`,
      `🆔 \`${record.id || "?"}\``,
    ].join("\n");

    // Send to Telegram
    const telegramUrl = `https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage`;
    const res = await fetch(telegramUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        chat_id: ADMIN_CHAT_ID,
        text: message,
        parse_mode: "Markdown",
        disable_web_page_preview: true,
      }),
    });

    const result = await res.json();

    return new Response(
      JSON.stringify({ success: true, telegram: result.ok }),
      {
        status: 200,
        headers: { "Content-Type": "application/json" },
      }
    );
  } catch (error) {
    console.error("Feedback notification error:", error);
    return new Response(
      JSON.stringify({ success: false, error: String(error) }),
      {
        status: 500,
        headers: { "Content-Type": "application/json" },
      }
    );
  }
});

// Escape special Markdown characters for Telegram
function escapeMarkdown(text: string): string {
  return text
    .replace(/\[/g, "\\[")
    .replace(/\]/g, "\\]")
    .replace(/\(/g, "\\(")
    .replace(/\)/g, "\\)")
    .replace(/~/g, "\\~")
    .replace(/`/g, "\\`")
    .replace(/>/g, "\\>")
    .replace(/#/g, "\\#")
    .replace(/\+/g, "\\+")
    .replace(/-/g, "\\-")
    .replace(/=/g, "\\=")
    .replace(/\|/g, "\\|")
    .replace(/\{/g, "\\{")
    .replace(/\}/g, "\\}")
    .replace(/\./g, "\\.")
    .replace(/!/g, "\\!");
}
