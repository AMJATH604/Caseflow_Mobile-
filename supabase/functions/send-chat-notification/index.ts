// Supabase Edge Function: send-chat-notification
// Sends FCM push notifications when a new message is posted in Digital Chambers.
// Triggered by a database webhook on INSERT into case_discussions.
//
// Flow:
// 1. New message inserted into case_discussions
// 2. Database webhook calls this function with the new row
// 3. Function looks up all firm members (except the sender)
// 4. Fetches their FCM tokens
// 5. Sends push notification with sender name + message preview

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { apnsAlert, getAccessToken, cleanupInvalidToken } from "../_shared/fcm_utils.ts";
import { verifyWebhookAuth } from "../_shared/auth_guard.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { requireSecretKey } from "../_shared/keys.ts";

// ─── Main Handler ────────────────────────────────────────────
Deno.serve(async (req: Request) => {
  // ─── Auth Guard: Verify webhook caller ─────────────────────
  const authError = await verifyWebhookAuth(req);
  if (authError) return authError;

  const executionId = crypto.randomUUID().substring(0, 8);
  console.log(`[${executionId}] Chat notification triggered`);

  try {
    // Parse the webhook payload
    const body = await req.json();

    // The webhook sends: { type: "INSERT", table: "case_discussions", record: {...}, ... }
    const record = body.record || body;

    const discussionId: string | null = record.id;
    const senderId: string | null = record.sender_id;
    const firmId: string | null = record.firm_id;
    const caseId: string | null = record.case_id;
    const message: string = record.message || "";
    const senderName: string = record.sender_name || "Team Member";
    const attachmentType: string | null = record.attachment_type;
    const isSystem: boolean = record.is_system || false;

    // Don't send notifications for system messages
    if (isSystem) {
      console.log(`[${executionId}] System message — skipping notification`);
      return new Response(
        JSON.stringify({ skipped: true, reason: "system_message" }),
        { headers: { "Content-Type": "application/json" } }
      );
    }

    // We need a firm_id to know who to notify
    if (!firmId) {
      console.log(`[${executionId}] No firm_id — skipping (personal case)`);
      return new Response(
        JSON.stringify({ skipped: true, reason: "no_firm_id" }),
        { headers: { "Content-Type": "application/json" } }
      );
    }

    console.log(
      `[${executionId}] Message from ${senderName} (${senderId}) in firm ${firmId}`
    );

    // Initialize Supabase with service role
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = requireSecretKey();
    const firebaseServiceAccountJson = Deno.env.get(
      "FIREBASE_SERVICE_ACCOUNT"
    )!;

    const supabase = createClient(supabaseUrl, supabaseServiceKey);
    const firebaseServiceAccount = JSON.parse(firebaseServiceAccountJson);

    // ─── Idempotency guard ───────────────────────────────────────
    // Atomically claim this discussion row before sending. If the webhook
    // fires twice for the same insert (duplicate registration, or a
    // retried delivery), only the invocation that wins the race sends —
    // the other sees notified_at already set and skips, so recipients
    // never get two pushes for one message.
    if (discussionId) {
      const { data: claimed, error: claimError } = await supabase
        .from("case_discussions")
        .update({ notified_at: new Date().toISOString() })
        .eq("id", discussionId)
        .is("notified_at", null)
        .select("id");

      if (claimError) {
        console.log(`[${executionId}] Idempotency claim failed (continuing): ${claimError.message}`);
      } else if (!claimed || claimed.length === 0) {
        console.log(`[${executionId}] Discussion ${discussionId} already notified — skipping`);
        return new Response(
          JSON.stringify({ skipped: true, reason: "already_notified" }),
          { headers: { "Content-Type": "application/json" } }
        );
      }
    }

    // ─── Step 1: Find all users in this firm (excluding sender) ───
    // A. Direct firm members (profile.firm_id matches)
    const { data: directMembers } = await supabase
      .from("profiles")
      .select("id")
      .eq("firm_id", firmId)
      .neq("id", senderId);

    // B. Invited firm members (from firm_members table)
    const { data: invitedMembers } = await supabase
      .from("firm_members")
      .select("member_id")
      .eq("owner_id", firmId)
      .eq("status", "accepted")
      .neq("member_id", senderId);

    // C. Firm owner: the user whose ID equals the firm_id
    const { data: firmOwner } = await supabase
      .from("profiles")
      .select("id")
      .eq("id", firmId);

    // Combine all recipient user IDs (excluding the sender)
    const recipientIds = new Set<string>();

    directMembers?.forEach((m: any) => recipientIds.add(m.id));
    invitedMembers?.forEach((m: any) => {
      if (m.member_id) recipientIds.add(m.member_id);
    });
    firmOwner?.forEach((o: any) => {
      if (o.id !== senderId) recipientIds.add(o.id);
    });

    // D. If it's a case-specific discussion, notify collaborators
    if (caseId) {
      // Fetch case owner/assignee
      const { data: caseData } = await supabase
        .from("cases")
        .select("created_by, assigned_to")
        .eq("id", caseId)
        .single();

      if (caseData) {
        if (caseData.created_by && caseData.created_by !== senderId) {
          recipientIds.add(caseData.created_by);
        }
        if (caseData.assigned_to && caseData.assigned_to !== senderId) {
          recipientIds.add(caseData.assigned_to);
        }
      }

      // Fetch case collaborators
      const { data: collaborators } = await supabase
        .from("case_collaborations")
        .select("collaborator_id")
        .eq("case_id", caseId)
        .eq("status", "accepted")
        .neq("collaborator_id", senderId);

      collaborators?.forEach((c: any) => {
        if (c.collaborator_id) recipientIds.add(c.collaborator_id);
      });
    }

    const targetUserIds = Array.from(recipientIds);
    console.log(
      `[${executionId}] Recipients (excluding sender): ${targetUserIds.length}`
    );

    if (targetUserIds.length === 0) {
      return new Response(
        JSON.stringify({ skipped: true, reason: "no_recipients" }),
        { headers: { "Content-Type": "application/json" } }
      );
    }

    // ─── Step 2: Fetch FCM tokens for all recipients ─────────
    const { data: tokens, error: tokensError } = await supabase
      .from("fcm_tokens")
      .select("user_id, token, device_info")
      .in("user_id", targetUserIds);

    if (tokensError) {
      throw new Error(`Token query failed: ${tokensError.message}`);
    }

    if (!tokens || tokens.length === 0) {
      console.log(`[${executionId}] No FCM tokens found for recipients`);
      return new Response(
        JSON.stringify({
          skipped: true,
          reason: "no_tokens",
          recipientCount: targetUserIds.length,
        }),
        { headers: { "Content-Type": "application/json" } }
      );
    }

    console.log(`[${executionId}] FCM tokens found: ${tokens.length}`);

    // ─── Step 3: Build notification content ──────────────────
    // Title: Sender name (like WhatsApp)
    const title = `💬 ${senderName}`;

    // Body: Message preview (truncated to 150 chars)
    let notificationBody: string;
    if (attachmentType === "image") {
      notificationBody = "📷 Photo";
    } else if (attachmentType === "document") {
      notificationBody = "📄 Document";
    } else if (attachmentType === "file") {
      notificationBody = "📎 File";
    } else {
      notificationBody =
        message.length > 150 ? message.substring(0, 147) + "..." : message;
    }

    // Add context: is it a case discussion or firm notice?
    const channelContext = caseId ? "Case Discussion" : "Firm Notice Board";

    // ─── Step 4: Send FCM notifications ──────────────────────
    const accessToken = await getAccessToken(firebaseServiceAccount);
    const projectId = firebaseServiceAccount.project_id;

    let sentCount = 0;
    let failCount = 0;
    const errors: string[] = [];

    for (const t of tokens) {
      try {
        const isAndroid = t.device_info === "TargetPlatform.android";

        // Data-only message. Our Flutter background handler renders the rich
        // WhatsApp-style notification with inline Reply + Mark Read buttons and
        // the deep-link payload; delivery is ensured via android.priority.
        //
        // This means NO notification block anywhere — not at the top level and
        // NOT under `android` either. An `android.notification` block also makes
        // Android auto-display, and since it carries no title/body it renders as
        // a blank duplicate card next to the real one. Sound and vibration are
        // set by the Flutter side (playSound/enableVibration in
        // FcmService.showRichNotification), so nothing is lost by omitting it.
        const fcmPayload: any = {
          message: {
            token: t.token,
            data: {
              type: "chat_message",
              title: title,
              body: notificationBody,
              firm_id: firmId,
              case_id: caseId || "",
              sender_id: senderId || "",
              sender_name: senderName,
              channel: channelContext,
            },
            android: {
              priority: "HIGH",
            },
            // iOS shows this text itself; see apnsAlert. One thread per
            // conversation, so a busy chat groups instead of stacking.
            apns: apnsAlert(title, notificationBody, {
              threadId: caseId ? `case-${caseId}` : `chambers-${firmId}`,
            }),
          }
        };

        const fcmResponse = await fetch(
          `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
          {
            method: "POST",
            headers: {
              Authorization: `Bearer ${accessToken}`,
              "Content-Type": "application/json",
            },
            body: JSON.stringify(fcmPayload),
          }
        );

        if (fcmResponse.ok) {
          sentCount++;
        } else {
          const errorBody = await fcmResponse.text();
          failCount++;
          errors.push(
            `Token ${t.token.substring(0, 10)}...: ${errorBody.substring(0, 100)}`
          );

          // Clean up invalid tokens
          if (
            fcmResponse.status === 404 ||
            errorBody.includes("NOT_FOUND") ||
            errorBody.includes("UNREGISTERED")
          ) {
            console.log(
              `[${executionId}] Removing invalid token: ${t.token.substring(0, 10)}...`
            );
            await supabase.from("fcm_tokens").delete().eq("token", t.token);
          }
        }
      } catch (e) {
        failCount++;
        errors.push(`Token ${t.token.substring(0, 10)}...: ${(e as any).message}`);
      }
    }

    console.log(
      `[${executionId}] ✅ Complete. Sent: ${sentCount}, Failed: ${failCount}`
    );

    return new Response(
      JSON.stringify({
        success: true,
        sender: senderName,
        recipientCount: targetUserIds.length,
        notificationsSent: sentCount,
        notificationsFailed: failCount,
        errors: errors.length > 0 ? errors.slice(0, 3) : undefined,
      }),
      { headers: { "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error(`[${executionId}] Error:`, (error as any).message);
    return new Response(JSON.stringify({ error: (error as any).message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
