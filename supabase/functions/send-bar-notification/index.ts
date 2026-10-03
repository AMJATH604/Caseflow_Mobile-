import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import {
  apnsAlert,
  getAccessToken,
  initClients,
  sendFcmMessage,
} from "../_shared/fcm_utils.ts";
import { verifyWebhookAuth } from "../_shared/auth_guard.ts";

// Pushes what a bar association publishes to its members' phones.
//
// Bar notices already wrote a row into the Notification Centre through
// record_notification(), but nothing ever called FCM — so a court-closure
// circular reached an advocate only when they next opened the app. That is
// no use for the two things a bar publishes urgently: a court not sitting
// tomorrow, and a death.
//
// Condolences are sent at high priority and worded differently. By
// convention the bar does not take up work that day, so an advocate leaving
// a taluk at 8am needs it before they set out, not from someone at the
// court gate.

type Kind = "notice" | "condolence";

Deno.serve(async (req: Request) => {
  const authError = await verifyWebhookAuth(req);
  if (authError) return authError;

  const executionId = crypto.randomUUID().substring(0, 8);

  try {
    const body = await req.json();
    const record = body.record ?? body;
    const kind: Kind = body.kind ?? "notice";

    const associationId: string | null = record.association_id ?? null;
    if (!associationId) {
      return json({ error: "association_id missing" }, 400);
    }

    const { supabase, firebaseServiceAccount, projectId } = initClients();

    // The association's name is what makes the notification make sense on a
    // lock screen: "Tenkasi District Court Bar Association", not "Notice".
    const { data: association } = await supabase
      .from("bar_associations")
      .select("name")
      .eq("id", associationId)
      .maybeSingle();

    const associationName = association?.name ?? "Your bar association";

    // Everyone on the roll who uses CaseFlow, except whoever published it.
    const { data: members, error: membersError } = await supabase
      .from("bar_members")
      .select("user_id")
      .eq("association_id", associationId)
      .eq("status", "active")
      .not("user_id", "is", null);

    if (membersError) throw membersError;

    const publisher: string | null = record.published_by ?? null;
    const userIds = (members ?? [])
      .map((m: { user_id: string }) => m.user_id)
      .filter((id: string) => id && id !== publisher);

    if (userIds.length === 0) {
      console.log(`[${executionId}] no recipients for ${associationId}`);
      return json({ sent: 0, reason: "no_recipients" });
    }

    const { data: tokenRows } = await supabase
      .from("fcm_tokens")
      .select("token, user_id")
      .in("user_id", userIds);

    const tokens = (tokenRows ?? []) as { token: string; user_id: string }[];
    if (tokens.length === 0) {
      console.log(`[${executionId}] recipients have no devices registered`);
      return json({ sent: 0, reason: "no_tokens" });
    }

    const { title, body: message, route, type } = compose(
      kind,
      record,
      associationName,
    );

    const accessToken = await getAccessToken(firebaseServiceAccount);
    let sent = 0;
    let failed = 0;

    for (const { token } of tokens) {
      // Data-only, as every sender in this project is: the Flutter app
      // renders its own notification. A `notification` block here would
      // produce duplicates and break the tap routing.
      const payload = {
        message: {
          token,
          data: {
            type,
            title,
            body: message,
            route,
            association_id: associationId,
            record_id: String(record.id ?? ""),
          },
          android: {
            priority: kind === "condolence" ? "HIGH" : "NORMAL",
          },
          // iOS shows this text itself; see apnsAlert. Bulletins go at
          // normal priority (iOS may batch them); a condolence goes now.
          apns: apnsAlert(title, message, {
            threadId: `bar-${associationId}`,
            priority: kind === "condolence" ? "10" : "5",
          }),
        },
      };

      const result = await sendFcmMessage(
        projectId,
        accessToken,
        payload,
        supabase,
        token,
        executionId,
      );
      result.success ? sent++ : failed++;
    }

    // Marking it sent is what stops a retry double-notifying the whole bar.
    const table = kind === "condolence" ? "bar_condolences" : "bar_notices";
    if (record.id) {
      await supabase.from(table).update({ fcm_sent: true }).eq("id", record.id);
    }

    console.log(`[${executionId}] ${kind}: sent ${sent}, failed ${failed}`);
    return json({ sent, failed, recipients: userIds.length });
  } catch (error) {
    console.error(`[${executionId}] failed:`, error);
    return json({ error: String(error) }, 500);
  }
});

function compose(kind: Kind, record: Record<string, unknown>, association: string) {
  if (kind === "condolence") {
    const name = String(record.deceased_name ?? "A member");
    const meetingAt = record.meeting_at ? new Date(String(record.meeting_at)) : null;
    const noWork = record.no_work_resolution === true;

    const parts: string[] = [];
    if (noWork) parts.push("The bar will not take up work.");
    if (meetingAt) {
      parts.push(
        `Condolence meeting ${meetingAt.toLocaleString("en-IN", {
          day: "2-digit",
          month: "short",
          hour: "2-digit",
          minute: "2-digit",
          timeZone: "Asia/Kolkata",
        })}.`,
      );
    }
    if (record.meeting_venue) parts.push(String(record.meeting_venue));

    return {
      type: "bar_condolence",
      title: `${name} — condolence`,
      body: parts.length > 0 ? parts.join(" ") : association,
      route: "/bar-association",
    };
  }

  return {
    type: "bar_notice",
    title: String(record.title ?? "Bar notice"),
    body: truncate(String(record.body ?? association), 180),
    route: "/bar-notices",
  };
}

function truncate(value: string, max: number) {
  return value.length <= max ? value : `${value.slice(0, max - 1)}…`;
}

function json(payload: unknown, status = 200) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
