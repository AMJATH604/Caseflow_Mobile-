// Supabase Edge Function: send-hearing-reminders
// Sends FCM push notifications for upcoming court hearings.
//
// Deploy via Supabase CLI:
//   supabase functions deploy send-hearing-reminders
//
// Or copy the contents to Supabase Dashboard > Edge Functions > New Function

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { getAccessToken } from "../_shared/fcm_utils.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

Deno.serve(async (req: Request) => {
  const url = new URL(req.url);
  const executionId = crypto.randomUUID().substring(0, 8);
  console.log(`[${executionId}] Request received: ${req.method} ${url.pathname}${url.search}`);

  try {
    // Read body carefully
    let body: any = {};
    const contentType = req.headers.get("content-type") || "";
    
    if (req.method === "POST") {
      try {
        const text = await req.text();
        if (text) {
          try {
            body = JSON.parse(text);
          } catch (e) {
            console.warn(`[${executionId}] Failed to parse body as JSON:`, text.substring(0, 100));
            // Try to handle cases where pg_net might send it wrapped or double-escaped
          }
        }
      } catch (e) {
        console.warn(`[${executionId}] Failed to read request text:`, (e as any).message);
      }
    }

    // Determine reminder_type (Highest priority: Query Param -> Body -> Fallback)
    let reminder_type: string | null = url.searchParams.get("type") || url.searchParams.get("reminder_type");
    
    if (!reminder_type && body) {
      reminder_type = body.reminder_type || body.type;
    }

    // Map legacy names to internal constants
    if (reminder_type === "morning") reminder_type = "morning_9am";
    if (reminder_type === "evening") reminder_type = "evening_7pm";
    if (reminder_type === "night") reminder_type = "evening_9pm";

    console.log(`[${executionId}] Effective reminder_type: ${reminder_type}`);

    if (!reminder_type) {
      console.error(`[${executionId}] Missing reminder_type. Body was:`, JSON.stringify(body));
      return new Response(
        JSON.stringify({ error: "Missing reminder_type in body or query param", body_received: body }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    // Initialize Supabase client with service role key
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const firebaseServiceAccountJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT");

    // Validate required environment variables
    if (!supabaseUrl || !supabaseServiceKey) {
      console.error(`[${executionId}] Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY`);
      return new Response(
        JSON.stringify({ error: "Server misconfigured: missing Supabase credentials" }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }
    if (!firebaseServiceAccountJson) {
      console.error(`[${executionId}] Missing FIREBASE_SERVICE_ACCOUNT secret`);
      return new Response(
        JSON.stringify({ error: "Server misconfigured: missing Firebase credentials" }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey);
    let firebaseServiceAccount: any;
    try {
      firebaseServiceAccount = JSON.parse(firebaseServiceAccountJson);
    } catch (parseError) {
      console.error(`[${executionId}] Invalid FIREBASE_SERVICE_ACCOUNT JSON:`, (parseError as any).message);
      return new Response(
        JSON.stringify({ error: "Server misconfigured: invalid Firebase service account format" }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }

    // Determine which date to query based on reminder type
    const now = new Date();
    // Convert to IST for date calculation (UTC + 5:30)
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
    } else if (reminder_type === "test") {
      // Test reminder → sends a static message immediately
      targetDate = istNow.toISOString().split("T")[0];
    } else {
      return new Response(
        JSON.stringify({ error: `Invalid reminder_type: ${reminder_type}. Supported: morning_9am, evening_7pm, evening_9pm (or legacy morning, evening, night)` }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    console.log(`[${executionId}] Target date for query: ${targetDate}`);

    // Query hearings on the target date, joined with case info
    const { data: hearingsData, error: hearingsError } = await supabase
      .from("hearings")
      .select("id, case_id, hearing_date, stage, purpose, created_by, cases(case_title, court_name, case_number, created_by, assigned_to, firm_id)")
      .eq("hearing_date", targetDate);

    const hearings = hearingsData as any;
    console.log(`[${executionId}] Hearings found in DB: ${hearings?.length || 0}`);

    if (hearingsError) {
      throw new Error(`Hearings query failed: ${hearingsError.message}`);
    }

    if (!hearings || hearings.length === 0) {
      return new Response(
        JSON.stringify({ message: "No hearings found for target date", targetDate }),
        { headers: { "Content-Type": "application/json" } }
      );
    }

    // Gather all related IDs to fetch access
    const firmIds = [...new Set(hearings.map((h: any) => h.cases?.firm_id).filter(Boolean))];
    const caseIds = [...new Set(hearings.map((h: any) => h.case_id))];

    // Fetch all profiles in those firms
    const { data: firmProfiles } = await supabase.from("profiles").select("id, firm_id").in("firm_id", firmIds);
    // Also include firm owners (id = firm_id)
    const { data: firmOwners } = await supabase.from("profiles").select("id").in("id", firmIds);
    // Fetch all accepted collaborations
    const { data: collaborations } = await supabase.from("case_collaborations")
      .select("case_id, collaborator_id")
      .in("case_id", caseIds)
      .eq("status", "accepted");

    // Fetch all invited firm members (accepted status)
    const { data: invitedFirmMembers } = await supabase.from("firm_members")
      .select("member_id, owner_id")
      .in("owner_id", firmIds)
      .eq("status", "accepted");

    // Build map of hearing_id -> array of user_ids who should get notified
    const hearingUserMap: Record<string, string[]> = {};
    const allUniqueUsers = new Set<string>();

    for (const h of hearings) {
      const uSet = new Set<string>();
      if (h.created_by) uSet.add(h.created_by);
      if (h.cases) {
        if (h.cases.created_by) uSet.add(h.cases.created_by);
        if (h.cases.assigned_to) uSet.add(h.cases.assigned_to);
        if (h.cases.firm_id) {
          firmProfiles?.forEach((p: any) => { if (p.firm_id === h.cases.firm_id) uSet.add(p.id); });
          firmOwners?.forEach((p: any) => { if (p.id === h.cases.firm_id) uSet.add(p.id); });
        }
      }
      collaborations?.forEach((col: any) => {
        if (col.case_id === h.case_id && col.collaborator_id) uSet.add(col.collaborator_id);
      });

      // Add invited firm members
      if (h.cases?.firm_id) {
        invitedFirmMembers?.forEach((m: any) => {
          if (m.owner_id === h.cases.firm_id && m.member_id) uSet.add(m.member_id);
        });
      }
      
      const usersForThisHearing = Array.from(uSet);
      hearingUserMap[h.id] = usersForThisHearing;
      usersForThisHearing.forEach(uid => allUniqueUsers.add(uid));
    }

    const userIds = Array.from(allUniqueUsers);

    // Fetch FCM tokens for those users
    // Note: 'body' was already parsed above; don't re-read req.json() as it can only be consumed once
    const queryUserId = reminder_type === "test" ? (body.userId ? [body.userId] : userIds) : userIds;
    
    const { data: tokens, error: tokensError } = await supabase
      .from("fcm_tokens")
      .select("user_id, token")
      .in("user_id", Array.isArray(queryUserId) ? queryUserId : [queryUserId]);

    if (tokensError) {
      throw new Error(`Token query failed: ${tokensError.message}`);
    }

    console.log(`[${executionId}] Tokens found in DB: ${tokens?.length || 0}`);

    if (!tokens || tokens.length === 0) {
      console.log(`[${executionId}] No active FCM tokens. Exiting.`);
      return new Response(
        JSON.stringify({ 
          message: "No FCM tokens found for hearing users", 
          usersSearched: Array.isArray(queryUserId) ? queryUserId.length : 1,
          hearingsProcessed: hearings.length 
        }),
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

    console.log(`[${executionId}] Starting delivery for ${hearings.length} hearings to ${userIds.length} users...`);
    for (const hearing of hearings) {
      const targetUserIds = hearingUserMap[hearing.id] || [];
      
      const caseTitle = hearing.cases?.case_title || "Unknown Case";
      const courtName = hearing.cases?.court_name || "";
      const purpose = hearing.purpose || hearing.stage || "Hearing";
      const caseNumber = hearing.cases?.case_number || "";

      const title = `⚖️ Court Hearing ${reminderLabel}`;
      const motivation = reminder_type === 'morning_9am' 
        ? "☕ Good Morning! Safe travels to the court." 
        : "🌙 Good Evening! Preparation is the key to success.";

      const body = `📁 Case: ${caseTitle}\n🔢 No: ${caseNumber || 'N/A'}\n⚖️ Stage: ${purpose}\n🏛️ Court: ${courtName || 'District Court'}\n🚀 Action: Prepare for ${reminderLabel.toLowerCase()}'s hearing\n${motivation}`;

      for (const userId of targetUserIds) {
        const userTokens = tokenMap[userId];
        if (!userTokens || userTokens.length === 0) continue;

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
                      type: "hearing_reminder",
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
