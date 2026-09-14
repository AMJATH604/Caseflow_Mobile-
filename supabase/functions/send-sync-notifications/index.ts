// Supabase Edge Function: send-sync-notifications
//
// Pushes a case-sync update to one user. Called by the
// tr_sync_notification_created trigger on public.sync_notifications.
//
// This function was deployed without being in the repository and had NO
// authentication: it took user_id, title and message straight from the request
// body and pushed them with the service role. Anyone holding the app's public
// key could send any text to any CaseFlow user — an ideal phishing channel.
// It is now guarded like every other trigger-driven function.
//
// It also never delivered reliably. Its private copy of the Google OAuth code
// encoded the signed JWT with plain base64 instead of base64url, which Google
// rejects, and it ignored every FCM response, so it reported {"success":true}
// while nothing arrived. It now uses the shared FCM helpers, which the working
// senders use, and reports the real per-device outcome.

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { verifyWebhookAuth } from "../_shared/auth_guard.ts";
import { getAccessToken, initClients, sendFcmMessage } from "../_shared/fcm_utils.ts";

Deno.serve(async (req: Request) => {
  const authError = await verifyWebhookAuth(req);
  if (authError) return authError;

  const executionId = crypto.randomUUID().substring(0, 8);
  const json = (body: unknown, status = 200) =>
    new Response(JSON.stringify(body), {
      status,
      headers: { "Content-Type": "application/json" },
    });

  try {
    const { user_id, title, message, case_id } = await req.json();
    if (!user_id) return json({ error: "user_id is required" }, 400);

    const { supabase, firebaseServiceAccount, projectId } = initClients();

    const { data: tokens, error: tokensError } = await supabase
      .from("fcm_tokens")
      .select("token")
      .eq("user_id", user_id);

    if (tokensError) throw tokensError;
    if (!tokens || tokens.length === 0) {
      return json({ message: "No tokens found", sent: 0 });
    }

    // Throws with Google's own error if the service-account key is rejected,
    // instead of carrying on with an undefined access token.
    const accessToken = await getAccessToken(firebaseServiceAccount);

    const results = [];
    for (const t of tokens) {
      results.push(
        await sendFcmMessage(
          projectId,
          accessToken,
          {
            message: {
              token: t.token,
              // Data-only: the app renders the notification itself in
              // FcmService.showRichNotification. A `notification` block would
              // make Android show a second, duplicate one.
              data: {
                type: "case_status",
                title: String(title ?? "Case update"),
                body: String(message ?? ""),
                route: case_id ? `/cases/${case_id}` : "/cases",
              },
              android: { priority: "HIGH" },
              apns: {
                payload: { aps: { "content-available": 1, sound: "default" } },
              },
            },
          },
          supabase,
          t.token,
          executionId,
        ),
      );
    }

    const sent = results.filter((r) => r.success).length;
    const errors = results.filter((r) => !r.success).map((r) => r.error);
    if (errors.length) console.error(`[${executionId}] FCM failures: ${errors.join(" | ")}`);

    return json({ success: sent > 0, sent, failed: errors.length, errors }, sent > 0 ? 200 : 502);
  } catch (error) {
    console.error(`[${executionId}] ${(error as Error).message}`);
    return json({ error: (error as Error).message }, 500);
  }
});
