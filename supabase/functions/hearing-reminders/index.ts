// Supabase Edge Function: send-hearing-reminders
// Sends FCM push notifications for upcoming court hearings.
//
// Deploy via Supabase CLI:
//   supabase functions deploy send-hearing-reminders
//
// Or copy the contents to Supabase Dashboard > Edge Functions > New Function

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// Google Auth - get access token from service account
async function getAccessToken(serviceAccount: any): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = btoa(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const payload = btoa(
    JSON.stringify({
      iss: serviceAccount.client_email,
      scope: "https://www.googleapis.com/auth/firebase.messaging",
      aud: "https://oauth2.googleapis.com/token",
      iat: now,
      exp: now + 3600,
    })
  );

  // Import the private key
  const pemContents = serviceAccount.private_key
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\n/g, "");
  const binaryKey = Uint8Array.from(atob(pemContents), (c) => c.charCodeAt(0));

  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    binaryKey,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const unsignedToken = `${header}.${payload}`;
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    new TextEncoder().encode(unsignedToken)
  );

  const jwt = `${unsignedToken}.${btoa(
    String.fromCharCode(...new Uint8Array(signature))
  )}`;

  // Exchange JWT for access token
  const tokenResponse = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  });

  const tokenData = await tokenResponse.json();
  return tokenData.access_token;
}

Deno.serve(async (req: Request) => {
  try {
    const { reminder_type } = await req.json();

    // Initialize Supabase client with service role key
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const firebaseServiceAccountJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT")!;

    const supabase = createClient(supabaseUrl, supabaseServiceKey);
    const firebaseServiceAccount = JSON.parse(firebaseServiceAccountJson);

    // Determine which date to query based on reminder type
    const now = new Date();
    // Convert to IST for date calculation
    const istOffset = 5.5 * 60 * 60 * 1000;
    const istNow = new Date(now.getTime() + istOffset);

    let targetDate: string;

    if (reminder_type === "evening_7pm" || reminder_type === "evening_9pm") {
      // Evening reminders → we notify about TOMORROW's hearings
      const tomorrow = new Date(istNow);
      tomorrow.setDate(tomorrow.getDate() + 1);
      targetDate = tomorrow.toISOString().split("T")[0];
    } else if (reminder_type === "morning_9am") {
      // Morning reminder → we notify about TODAY's hearings
      targetDate = istNow.toISOString().split("T")[0];
    } else {
      return new Response(
        JSON.stringify({ error: "Invalid reminder_type" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    // Query hearings on the target date, joined with case info
    const { data: hearingsData, error: hearingsError } = await supabase
      .from("hearings")
      .select("id, case_id, hearing_date, stage, purpose, created_by, cases(case_title, court_name, case_number)")
      .eq("hearing_date", targetDate);

    const hearings = hearingsData as any;

    if (hearingsError) {
      throw new Error(`Hearings query failed: ${hearingsError.message}`);
    }

    if (!hearings || hearings.length === 0) {
      return new Response(
        JSON.stringify({ message: "No hearings found for target date", targetDate }),
        { headers: { "Content-Type": "application/json" } }
      );
    }

    // Get unique user IDs from hearings
    const userIds = [...new Set(hearings.map((h: any) => h.created_by))];

    // Fetch FCM tokens for those users
    const { data: tokens, error: tokensError } = await supabase
      .from("fcm_tokens")
      .select("user_id, token")
      .in("user_id", userIds);

    if (tokensError) {
      throw new Error(`Token query failed: ${tokensError.message}`);
    }

    if (!tokens || tokens.length === 0) {
      return new Response(
        JSON.stringify({ message: "No FCM tokens found for hearing users" }),
        { headers: { "Content-Type": "application/json" } }
      );
    }

    // Create a map of user_id → [tokens]
    const tokenMap: Record<string, string[]> = {};
    for (const t of tokens) {
      if (!tokenMap[t.user_id]) tokenMap[t.user_id] = [];
      tokenMap[t.user_id].push(t.token);
    }

    // Get FCM access token
    const accessToken = await getAccessToken(firebaseServiceAccount);
    const projectId = firebaseServiceAccount.project_id;

    // Build the reminder message text
    let reminderLabel: string;
    if (reminder_type === "evening_7pm") {
      reminderLabel = "Tomorrow";
    } else if (reminder_type === "evening_9pm") {
      reminderLabel = "Tomorrow";
    } else {
      reminderLabel = "Today";
    }

    let sentCount = 0;
    let failCount = 0;
    const errors: string[] = [];

    // Send notifications
    for (const hearing of hearings) {
      const userId = hearing.created_by;
      const userTokens = tokenMap[userId];
      if (!userTokens || userTokens.length === 0) continue;

      const caseTitle = hearing.cases?.case_title || "Unknown Case";
      const courtName = hearing.cases?.court_name || "";
      const purpose = hearing.purpose || hearing.stage || "Hearing";
      const caseNumber = hearing.cases?.case_number || "";

      const title = `⚖️ Court Hearing ${reminderLabel}`;
      const body = `${caseTitle}${caseNumber ? ` (${caseNumber})` : ""}\n${purpose}${courtName ? ` • ${courtName}` : ""}`;

      for (const token of userTokens) {
        try {
          const fcmResponse = await fetch(
            `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
            {
              method: "POST",
              headers: {
                Authorization: `Bearer ${accessToken}`,
                "Content-Type": "application/json",
              },
              body: JSON.stringify({
                message: {
                  token: token,
                  notification: {
                    title: title,
                    body: body,
                  },
                  data: {
                    case_id: hearing.case_id,
                    hearing_id: hearing.id,
                    reminder_type: reminder_type,
                  },
                  android: {
                    priority: "high",
                    notification: {
                      channel_id: "hearing_reminders",
                      sound: "default",
                      click_action: "FLUTTER_NOTIFICATION_CLICK",
                    },
                  },
                },
              }),
            }
          );

          if (fcmResponse.ok) {
            sentCount++;
          } else {
            const errorBody = await fcmResponse.text();
            failCount++;
            errors.push(`Token ${token.substring(0, 10)}...: ${errorBody}`);

            // If token is invalid/expired, remove it from the database
            if (
              fcmResponse.status === 404 ||
              errorBody.includes("NOT_FOUND") ||
              errorBody.includes("UNREGISTERED")
            ) {
              await supabase
                .from("fcm_tokens")
                .delete()
                .eq("token", token);
            }
          }
        } catch (e) {
          failCount++;
          errors.push(`Token ${token.substring(0, 10)}...: ${(e as any).message}`);
        }
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        reminder_type,
        targetDate,
        hearingsFound: hearings.length,
        notificationsSent: sentCount,
        notificationsFailed: failCount,
        errors: errors.length > 0 ? errors.slice(0, 5) : undefined,
      }),
      { headers: { "Content-Type": "application/json" } }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ error: (error as any).message }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
