// Supabase Edge Function: send-caveat-reminders
// Sends FCM push notifications for upcoming caveat expirations.
//
// Deploy via Supabase CLI:
//   supabase functions deploy send-caveat-reminders

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { getAccessToken } from "../_shared/fcm_utils.ts";
import { verifyWebhookAuth } from "../_shared/auth_guard.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

Deno.serve(async (req: Request) => {
  // ─── Auth Guard: Verify webhook/cron caller ────────────────
  const authError = await verifyWebhookAuth(req);
  if (authError) return authError;

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const firebaseServiceAccountJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT")!;

    const supabase = createClient(supabaseUrl, supabaseServiceKey);
    const firebaseServiceAccount = JSON.parse(firebaseServiceAccountJson);

    // Calculate dates for 30, 15, 7, 3, and 1 day remaining
    const now = new Date();
    const istOffset = 5.5 * 60 * 60 * 1000;
    const istNow = new Date(now.getTime() + istOffset);

    const getTargetDateStr = (daysAhead: number) => {
      const d = new Date(istNow);
      d.setDate(d.getDate() + daysAhead);
      return d.toISOString().split("T")[0];
    };

    const targetDates = [
      getTargetDateStr(30), // Expiring in 30 days
      getTargetDateStr(15), // Expiring in 15 days
      getTargetDateStr(7),  // Expiring in  7 days
      getTargetDateStr(3),  // Expiring in  3 days
      getTargetDateStr(1)   // Expiring in  1 day
    ];

    // Find caveats matching these dates
    const { data: caveats, error: caveatError } = await supabase
      .from("caveats")
      .select("id, user_id, court_name, caveator_name, opponent_name, expiry_date")
      .eq("status", "active")
      .in("expiry_date", targetDates);

    if (caveatError) throw new Error(`Caveat query failed: ${caveatError.message}`);

    if (!caveats || caveats.length === 0) {
      return new Response(JSON.stringify({ message: "No caveats expiring on milestone dates" }), { headers: { "Content-Type": "application/json" } });
    }

    const userIds = [...new Set(caveats.map((c: any) => c.user_id))];

    const { data: tokens, error: tokensError } = await supabase
      .from("fcm_tokens")
      .select("user_id, token")
      .in("user_id", userIds);

    if (tokensError) throw new Error(`Token query failed: ${tokensError.message}`);

    const tokenMap: Record<string, string[]> = {};
    if (tokens) {
      for (const t of tokens) {
        if (!tokenMap[t.user_id]) tokenMap[t.user_id] = [];
        tokenMap[t.user_id].push(t.token);
      }
    }

    const accessToken = await getAccessToken(firebaseServiceAccount);
    const projectId = firebaseServiceAccount.project_id;

    let sentCount = 0;
    let failCount = 0;
    const errors: string[] = [];

    // Also auto-expire ones that have crossed the date
    const todayStr = getTargetDateStr(0);
    await supabase.from("caveats").update({ status: "expired" }).eq("status", "active").lt("expiry_date", todayStr);

    for (const caveat of caveats) {
      const userTokens = tokenMap[caveat.user_id];
      if (!userTokens || userTokens.length === 0) continue;

      // Calculate exact days left to label the notification
      const expDate = new Date(caveat.expiry_date);
      const tDate = new Date(todayStr);
      const timeDiff = expDate.getTime() - tDate.getTime();
      const daysLeft = Math.ceil(timeDiff / (1000 * 3600 * 24));

      const title = `⚠️ Caveat Expiring in ${daysLeft} Day${daysLeft !== 1 ? 's' : ''}`;
      const body = `${caveat.caveator_name} vs ${caveat.opponent_name}\n${caveat.court_name}\nTap to review and renew protection.`;

      for (const token of userTokens) {
        try {
          const fcmResponse = await fetch(`https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`, {
            method: "POST",
            headers: {
              Authorization: `Bearer ${accessToken}`,
              "Content-Type": "application/json",
            },
            body: JSON.stringify({
              message: {
                token: token,
                notification: { title, body },
                data: { caveat_id: caveat.id, route: "/caveats" },
                android: { priority: "high" },
              },
            }),
          });

          if (fcmResponse.ok) {
            sentCount++;
          } else {
            const errorBody = await fcmResponse.text();
            failCount++;
            
            if (fcmResponse.status === 404 || errorBody.includes("NOT_FOUND") || errorBody.includes("UNREGISTERED")) {
              await supabase.from("fcm_tokens").delete().eq("token", token);
            }
          }
        } catch (e) {
          failCount++;
          errors.push(`Token ${token.substring(0, 10)}...: ${(e as any).message}`);
        }
      }
    }

    return new Response(JSON.stringify({ success: true, caveatsFound: caveats.length, sentCount, failCount }), { headers: { "Content-Type": "application/json" } });
  } catch (error) {
    return new Response(JSON.stringify({ error: (error as any).message }), { status: 500, headers: { "Content-Type": "application/json" } });
  }
});
