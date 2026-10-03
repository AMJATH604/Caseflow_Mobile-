// Supabase Edge Function: send-invitation-notification
//
// Handles BOTH directions of an invitation, selected by the payload's `event`:
//
//   event = "invite"   → notify the INVITEE that they've been invited
//       • firm_members        ("X invited you to join their firm")
//       • case_collaborations ("X shared \"Case\" with you")
//
//   event = "response" → notify the INVITER of the outcome
//       • firm_members        ("Y joined your firm" / "Y declined …")
//       • case_collaborations ("Y accepted your invitation to \"Case\"" / declined)
//
// An untagged payload is treated as "invite", so anything still posting the
// old shape keeps working.
//
// Triggered by SQL triggers (see migrations 20260912_invitation_notifications
// and 20260915_invitation_responses), which post a webhook-style payload with
// an `x-pg-trigger-secret` header verified by verifyWebhookAuth().
//
// A push only reaches people who already have a CaseFlow account (so we can
// resolve their FCM tokens). Email-only invites to people without an account
// are skipped — they'll see the invitation when they sign up.

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { apnsAlert, getAccessToken, recordNotification } from "../_shared/fcm_utils.ts";
import { verifyWebhookAuth } from "../_shared/auth_guard.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { requireSecretKey } from "../_shared/keys.ts";

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
    const supabaseServiceKey = requireSecretKey();
    const firebaseServiceAccountJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT")!;

    const supabase = createClient(supabaseUrl, supabaseServiceKey);
    const firebaseServiceAccount = JSON.parse(firebaseServiceAccountJson);

    // Which direction is this? `invite` goes to the invitee (the original
    // behaviour); `response` goes back to the inviter when the invitee accepts
    // or declines. The DB triggers tag the payload; anything untagged is an
    // invite, so older callers keep working.
    const event: string = body.event === "response" ? "response" : "invite";

    // ─── Resolve invitation shape per table ──────────────────
    let inviteeId: string | null = null;
    let inviteeEmail: string | null = null;
    let inviterId: string | null = null;
    let caseId: string | null = null;
    const status: string = record.status || "pending";

    if (table === "firm_members") {
      inviteeId = record.member_id ?? null;
      inviteeEmail = record.member_email ?? null;
      inviterId = record.owner_id ?? null;
    } else if (table === "case_collaborations") {
      inviteeId = record.collaborator_id ?? null;
      inviteeEmail = record.collaborator_email ?? null;
      inviterId = record.owner_id ?? null;
      caseId = record.case_id ?? null;
    } else {
      return jsonResponse({ skipped: true, reason: "unsupported_table" });
    }

    // Resolve the invitee's user id from their email if it wasn't pre-linked.
    if (!inviteeId && inviteeEmail) {
      const { data: prof } = await supabase
        .from("profiles")
        .select("id")
        .eq("email", inviteeEmail)
        .maybeSingle();
      inviteeId = prof?.id ?? null;
    }

    // Look up a display name, falling back to the email local part.
    const displayName = async (
      userId: string | null,
      email: string | null,
      fallback: string
    ): Promise<string> => {
      if (userId) {
        const { data } = await supabase
          .from("profiles")
          .select("full_name")
          .eq("id", userId)
          .maybeSingle();
        if (data?.full_name) return data.full_name;
      }
      return email?.split("@")[0] || fallback;
    };

    const caseTitleFor = async (id: string | null): Promise<string> => {
      if (!id) return "a case";
      const { data } = await supabase
        .from("cases")
        .select("case_title")
        .eq("id", id)
        .maybeSingle();
      return data?.case_title || "a case";
    };

    // ─── Decide recipient and content ────────────────────────
    let recipientId: string | null;
    let notifType: "invitation" | "invitation_response";
    let title: string;
    let notifBody: string;
    let route: string;

    if (event === "response") {
      // The invitee answered — tell whoever sent the invite.
      if (status !== "accepted" && status !== "rejected") {
        return jsonResponse({ skipped: true, reason: "not_a_response" });
      }

      recipientId = inviterId;
      if (!recipientId) {
        return jsonResponse({ skipped: true, reason: "no_inviter" });
      }
      if (recipientId === inviteeId) {
        return jsonResponse({ skipped: true, reason: "self_response" });
      }

      const responder = await displayName(inviteeId, inviteeEmail, "Someone");
      const accepted = status === "accepted";
      title = accepted ? "✅ Invitation Accepted" : "🚫 Invitation Declined";

      if (table === "firm_members") {
        notifBody = accepted
          ? `${responder} joined your firm`
          : `${responder} declined your firm invitation`;
        route = "/firm";
      } else {
        const caseTitle = await caseTitleFor(caseId);
        notifBody = accepted
          ? `${responder} accepted your invitation to "${caseTitle}"`
          : `${responder} declined your invitation to "${caseTitle}"`;
        route = caseId ? `/cases/${caseId}` : "/firm";
      }

      notifType = "invitation_response";
    } else {
      // Original path: a fresh (or renewed) invitation for the invitee.
      if (status !== "pending") {
        return jsonResponse({ skipped: true, reason: "not_pending" });
      }

      recipientId = inviteeId;
      if (!recipientId) {
        return jsonResponse({ skipped: true, reason: "recipient_has_no_account" });
      }
      if (recipientId === inviterId) {
        return jsonResponse({ skipped: true, reason: "self_invite" });
      }

      const inviterName = await displayName(inviterId, null, "A colleague");

      if (table === "firm_members") {
        title = "⚖️ Firm Invitation";
        notifBody = `${inviterName} invited you to join their firm`;
      } else {
        const caseTitle = await caseTitleFor(caseId);
        title = "📁 Case Invitation";
        notifBody = `${inviterName} shared "${caseTitle}" with you`;
      }

      notifType = "invitation";
      route = "/collaborator-invitations";
    }

    console.log(
      `[${executionId}] event=${event} table=${table} status=${status} → ${recipientId}`
    );

    // ─── Notification Centre ─────────────────────────────────
    // Ahead of the token lookup, which returns early on `no_tokens`. Someone
    // who declined push permission still needs the in-app record.
    //
    // The dedupe key is scoped to the day so a duplicate webhook delivery is
    // dropped, while a genuine re-invite tomorrow still notifies. Rows are
    // purged after 24 hours, so a stale key never blocks a real notification.
    const dayStamp = new Date().toISOString().split("T")[0];
    await recordNotification(
      supabase,
      {
        user_id: recipientId,
        type: notifType,
        title,
        body: notifBody,
        route,
        payload: {
          source_table: table,
          invitation_id: record.id ?? null,
          inviter_id: inviterId,
          invitee_id: inviteeId,
          case_id: caseId,
          status,
        },
        dedupe_key: record.id
          ? `${notifType}:${table}:${record.id}:${status}:${dayStamp}`
          : undefined,
      },
      executionId
    );

    // ─── Fetch the recipient's FCM tokens ────────────────────
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
                // Data-only: no `notification` block, so the Flutter app
                // renders its own rich notification with deep-link payload.
                data: {
                  type: notifType,
                  title,
                  body: notifBody,
                  route,
                },
                // Priority only — see send-hearing-reminders. A
                // notification block here makes Android draw a second, empty
                // card beside the app's own, and this one even borrowed the
                // hearing-reminder channel.
                android: {
                  priority: "HIGH",
                },
                // iOS shows this text itself; see apnsAlert.
                apns: apnsAlert(title, notifBody, { threadId: "invitations" }),
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
    return jsonResponse({ success: true, event, table, sentCount, failCount });
  } catch (error) {
    console.error(`[${executionId}] Error:`, (error as Error).message);
    return jsonResponse({ error: (error as Error).message }, 500);
  }
});
