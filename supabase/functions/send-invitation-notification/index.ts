// Supabase Edge Function: send-invitation-notification
// Sends an FCM push when someone is invited:
//   • firm_members       → firm recruitment ("X invited you to join their firm")
//   • case_collaborations → case sharing     ("X shared \"Case\" with you")
//
// Triggered by a SQL trigger on INSERT (see migration
// 20260912_invitation_notifications.sql), which posts a webhook-style payload
// with an `x-pg-trigger-secret` header verified by verifyWebhookAuth().
//
// The push only reaches invitees who already have a CaseFlow account (so we can
// resolve their FCM tokens). Email-only invites to people without an account
// are skipped — they'll see the invitation when they sign up.

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { getAccessToken } from "../_shared/fcm_utils.ts";
import { verifyWebhookAuth } from "../_shared/auth_guard.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

function jsonResponse(obj: unknown, status = 200): Response {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

Deno.serve(async (req: Request) => {
  const authError = await verifyWebhookAuth(req);
  if (authError) return authError;

  const executionId = crypto.randomUUID().substring(0, 8);
  console.log(`[${executionId}] Invitation notification triggered`);

  try {
    const body = await req.json();
    const table: string = body.table || "";
    const record = body.record || body;

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const firebaseServiceAccountJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT")!;

    const supabase = createClient(supabaseUrl, supabaseServiceKey);
    const firebaseServiceAccount = JSON.parse(firebaseServiceAccountJson);

    // ─── Resolve invitation shape per table ──────────────────
    let recipientId: string | null = null;
    let recipientEmail: string | null = null;
    let inviterId: string | null = null;
    let caseId: string | null = null;
    const status: string = record.status || "pending";

    if (table === "firm_members") {
      recipientId = record.member_id ?? null;
      recipientEmail = record.member_email ?? null;
      inviterId = record.owner_id ?? null;
    } else if (table === "case_collaborations") {
      recipientId = record.collaborator_id ?? null;
      recipientEmail = record.collaborator_email ?? null;
      inviterId = record.owner_id ?? null;
      caseId = record.case_id ?? null;
    } else {
      return jsonResponse({ skipped: true, reason: "unsupported_table" });
    }

    // Only notify for pending invitations (ignore accepted/rejected rows).
    if (status !== "pending") {
      return jsonResponse({ skipped: true, reason: "not_pending" });
    }

    // Resolve the invitee's user id from their email if it wasn't pre-linked.
    if (!recipientId && recipientEmail) {
      const { data: prof } = await supabase
        .from("profiles")
        .select("id")
        .eq("email", recipientEmail)
        .maybeSingle();
      recipientId = prof?.id ?? null;
    }

    // The inviter can't invite themselves; also guard against a null recipient.
    if (!recipientId) {
      return jsonResponse({ skipped: true, reason: "recipient_has_no_account" });
    }
    if (recipientId === inviterId) {
      return jsonResponse({ skipped: true, reason: "self_invite" });
    }

    // Inviter's display name.
    let inviterName = "A colleague";
    if (inviterId) {
      const { data: inv } = await supabase
        .from("profiles")
        .select("full_name")
        .eq("id", inviterId)
        .maybeSingle();
      inviterName = inv?.full_name || inviterName;
    }

    // ─── Build the notification content ──────────────────────
    let title: string;
    let notifBody: string;
    if (table === "firm_members") {
      title = "⚖️ Firm Invitation";
      notifBody = `${inviterName} invited you to join their firm`;
    } else {
      let caseTitle = "a case";
      if (caseId) {
        const { data: c } = await supabase
          .from("cases")
          .select("case_title")
          .eq("id", caseId)
          .maybeSingle();
        caseTitle = c?.case_title || caseTitle;
      }
      title = "📁 Case Invitation";
      notifBody = `${inviterName} shared "${caseTitle}" with you`;
    }

    // ─── Fetch the invitee's FCM tokens ──────────────────────
    const { data: tokens, error: tokensError } = await supabase
      .from("fcm_tokens")
      .select("token")
      .eq("user_id", recipientId);

    if (tokensError) throw new Error(`Token query failed: ${tokensError.message}`);

    if (!tokens || tokens.length === 0) {
      console.log(`[${executionId}] No FCM tokens for recipient ${recipientId}`);
      return jsonResponse({ skipped: true, reason: "no_tokens" });
    }

    // ─── Send data-only pushes (app renders the notification) ─
    const accessToken = await getAccessToken(firebaseServiceAccount);
    const projectId = firebaseServiceAccount.project_id;

    let sentCount = 0;
    let failCount = 0;

    for (const t of tokens) {
      try {
        const resp = await fetch(
          `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
          {
            method: "POST",
            headers: {
              Authorization: `Bearer ${accessToken}`,
              "Content-Type": "application/json",
            },
            body: JSON.stringify({
              message: {
                token: t.token,
                // Data-only: no `notification` block, so the app renders exactly
                // one notification (no OS auto-display duplicate).
                data: {
                  type: "invitation",
                  title,
                  body: notifBody,
                  route: "/collaborator-invitations",
                },
                android: { priority: "HIGH" },
                apns: {
                  payload: {
                    aps: {
                      "content-available": 1,
                      sound: "default",
                      badge: 1,
                    },
                  },
                },
              },
            }),
          },
        );

        if (resp.ok) {
          sentCount++;
        } else {
          failCount++;
          const errBody = await resp.text();
          if (
            resp.status === 404 ||
            errBody.includes("NOT_FOUND") ||
            errBody.includes("UNREGISTERED")
          ) {
            await supabase.from("fcm_tokens").delete().eq("token", t.token);
          }
        }
      } catch (e) {
        failCount++;
        console.log(`[${executionId}] Send error: ${(e as Error).message}`);
      }
    }

    console.log(`[${executionId}] ✅ Sent: ${sentCount}, Failed: ${failCount}`);
    return jsonResponse({ success: true, table, sentCount, failCount });
  } catch (error) {
    console.error(`[${executionId}] Error:`, (error as Error).message);
    return jsonResponse({ error: (error as Error).message }, 500);
  }
});
