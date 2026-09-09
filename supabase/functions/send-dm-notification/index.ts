// Supabase Edge Function: send-dm-notification
// Sends FCM push notifications when a new direct message is sent.
// Triggered by a database webhook on INSERT into direct_messages.
//
// Flow:
// 1. New message inserted into direct_messages
// 2. Database webhook calls this function with the new row
// 3. Function looks up the conversation to find the recipient
// 4. Fetches their FCM tokens
// 5. Sends WhatsApp-style push notification with sender name + message preview

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { getAccessToken, cleanupInvalidToken } from "../_shared/fcm_utils.ts";
import { verifyWebhookAuth } from "../_shared/auth_guard.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// ─── Main Handler ────────────────────────────────────────────
Deno.serve(async (req: Request) => {
  // ─── Auth Guard: Verify webhook caller ─────────────────────
  const authError = await verifyWebhookAuth(req);
  if (authError) return authError;

  const executionId = crypto.randomUUID().substring(0, 8);
  console.log(`[${executionId}] DM notification triggered`);

  try {
    const body = await req.json();
    const record = body.record || body;

    const messageId: string | null = record.id;
    const senderId: string | null = record.sender_id;
    const conversationId: string | null = record.conversation_id;
    const message: string = record.message || "";
    const attachmentType: string | null = record.attachment_type;
    const attachmentUrl: string | null = record.attachment_url;

    if (!senderId || !conversationId) {
      console.log(`[${executionId}] Missing sender_id or conversation_id — skipping`);
      return new Response(
        JSON.stringify({ skipped: true, reason: "missing_fields" }),
        { headers: { "Content-Type": "application/json" } }
      );
    }

    // Initialize Supabase with service role
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const firebaseServiceAccountJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT")!;

    const supabase = createClient(supabaseUrl, supabaseServiceKey);
    const firebaseServiceAccount = JSON.parse(firebaseServiceAccountJson);

    // ─── Idempotency guard ───────────────────────────────────────
    // Atomically claim this message row before sending. If the webhook
    // fires twice for the same insert (duplicate registration, or a
    // retried delivery), only the invocation that wins the race sends —
    // the other sees notified_at already set and skips, so the recipient
    // never gets two pushes for one message.
    if (messageId) {
      const { data: claimed, error: claimError } = await supabase
        .from("direct_messages")
        .update({ notified_at: new Date().toISOString() })
        .eq("id", messageId)
        .is("notified_at", null)
        .select("id");

      if (claimError) {
        console.log(`[${executionId}] Idempotency claim failed (continuing): ${claimError.message}`);
      } else if (!claimed || claimed.length === 0) {
        console.log(`[${executionId}] Message ${messageId} already notified — skipping`);
        return new Response(
          JSON.stringify({ skipped: true, reason: "already_notified" }),
          { headers: { "Content-Type": "application/json" } }
        );
      }
    }

    // ─── Step 1: Find the conversation and determine recipient ───
    const { data: conversation, error: convError } = await supabase
      .from("direct_conversations")
      .select("participant_1, participant_2")
      .eq("id", conversationId)
      .single();

    if (convError || !conversation) {
      console.log(`[${executionId}] Conversation not found: ${convError?.message}`);
      return new Response(
        JSON.stringify({ skipped: true, reason: "conversation_not_found" }),
        { headers: { "Content-Type": "application/json" } }
      );
    }

    // The recipient is the other participant
    const recipientId =
      conversation.participant_1 === senderId
        ? conversation.participant_2
        : conversation.participant_1;

    if (!recipientId) {
      return new Response(
        JSON.stringify({ skipped: true, reason: "no_recipient" }),
        { headers: { "Content-Type": "application/json" } }
      );
    }

    console.log(`[${executionId}] Sender: ${senderId}, Recipient: ${recipientId}`);

    // ─── Step 2: Get sender's name ──────────────────────────────
    const { data: senderProfile } = await supabase
      .from("profiles")
      .select("full_name, avatar_url")
      .eq("id", senderId)
      .single();

    const senderName = senderProfile?.full_name || "Someone";
    const senderAvatar = senderProfile?.avatar_url || "";

    // ─── Step 3: Fetch recipient's FCM tokens ───────────────────
    const { data: tokens, error: tokensError } = await supabase
      .from("fcm_tokens")
      .select("token, device_info")
      .eq("user_id", recipientId);

    if (tokensError) {
      throw new Error(`Token query failed: ${tokensError.message}`);
    }

    if (!tokens || tokens.length === 0) {
      console.log(`[${executionId}] No FCM tokens for recipient ${recipientId}`);
      return new Response(
        JSON.stringify({ skipped: true, reason: "no_tokens" }),
        { headers: { "Content-Type": "application/json" } }
      );
    }

    console.log(`[${executionId}] FCM tokens found: ${tokens.length}`);

    // ─── Step 4: Build notification content ─────────────────────
    const title = senderName;

    let notificationBody: string;
    if (attachmentType === "image") {
      notificationBody = "📷 Photo";
    } else if (attachmentType === "video") {
      notificationBody = "🎥 Video";
    } else if (attachmentType === "audio") {
      notificationBody = "🎤 Voice message";
    } else if (attachmentType === "document" || attachmentType === "file") {
      notificationBody = "📄 Document";
    } else {
      notificationBody =
        message.length > 150 ? message.substring(0, 147) + "..." : message;
    }

    // ─── Step 5: Send FCM notifications ─────────────────────────
    const accessToken = await getAccessToken(firebaseServiceAccount);
    const projectId = firebaseServiceAccount.project_id;

    let sentCount = 0;
    let failCount = 0;
    const errors: string[] = [];

    for (const t of tokens) {
      try {
        const isAndroid = t.device_info === "TargetPlatform.android";

        // Data-only message: no top-level `notification` block so Android OS
        // won't auto-display a plain system notification. Instead, our Flutter
        // background handler renders a rich WhatsApp-style notification with
        // inline Reply + Mark Read action buttons and deep-link payload.
        // Delivery is ensured via android.priority = "HIGH".
        const fcmPayload: any = {
          message: {
            token: t.token,
            data: {
              type: "dm_message",
              title: title,
              body: notificationBody,
              conversation_id: conversationId,
              sender_id: senderId,
              sender_name: senderName,
              sender_avatar: senderAvatar,
              channel: "Direct Message",
            },
            android: {
              priority: "HIGH",
              notification: {
                channel_id: "dm_messages_v2",
                sound: "default",
                default_vibrate_timings: true,
              },
            },
            apns: {
              payload: {
                aps: {
                  sound: "default",
                  badge: 1,
                },
              },
            },
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
        recipient: recipientId,
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
