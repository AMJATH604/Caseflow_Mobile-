// Supabase Edge Function: admin-metrics
//
// The operator console's only route to cross-user data.
//
// Row-level security scopes every ordinary query to the signed-in user, so the
// web console could previously see only the administrator's own records — an
// admin saw 61 of 379 cases and 0 of 380 clients. The tempting fix is to widen
// RLS with `OR is_admin(auth.uid())` across ~30 tables, but that hands
// full-database authority to the browser: any XSS in the console would become
// total data access.
//
// So the privileged reads live here instead. This function:
//   1. verifies the caller's JWT against Supabase Auth,
//   2. confirms that user is an administrator,
//   3. only then queries with the service role.
//
// The SQL functions it calls return counts and identity — never case titles,
// client names or fee records. CaseFlow holds privileged advocate-client
// material, and an administrator browsing it is a professional-conduct problem
// before it is a security one. The response shape makes that impossible rather
// than merely discouraged.

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, content-type, apikey, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Max-Age": "86400",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req: Request) => {
  // 204 carries no body by definition — constructing one with a body throws,
  // which returned 500 to the preflight and made every browser call fail with
  // "Failed to send a request to the Edge Function".
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: CORS });
  }

  const executionId = crypto.randomUUID().substring(0, 8);

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;

    // ── 1. Who is calling? ──────────────────────────────────
    const authHeader = req.headers.get("Authorization") ?? "";
    const token = /^Bearer\s+(.+)$/i.exec(authHeader.trim())?.[1];
    if (!token) return json({ error: "Missing bearer token" }, 401);

    // Verified against Supabase Auth with the anon key — a signature check,
    // not a decode. A forged or expired token fails here.
    const asCaller = createClient(supabaseUrl, anonKey);
    const { data: userData, error: userErr } = await asCaller.auth.getUser(token);
    if (userErr || !userData?.user) {
      console.log(`[${executionId}] token rejected: ${userErr?.message}`);
      return json({ error: "Invalid session" }, 401);
    }
    const caller = userData.user;

    // ── 2. Are they an administrator? ───────────────────────
    // Checked against profiles.is_admin server-side. The browser claiming to
    // be an admin counts for nothing.
    const admin = createClient(supabaseUrl, serviceKey);
    const { data: isAdmin, error: adminErr } = await admin.rpc("admin_is_admin", {
      p_user_id: caller.id,
    });
    if (adminErr) throw new Error(`Admin check failed: ${adminErr.message}`);
    if (isAdmin !== true) {
      console.log(`[${executionId}] ${caller.email} is not an administrator`);
      return json({ error: "Administrator access required" }, 403);
    }

    // ── 3. Serve the request ────────────────────────────────
    const body = req.method === "POST" ? await req.json().catch(() => ({})) : {};
    const action: string = body.action ?? "overview";

    switch (action) {
      case "overview": {
        const { data, error } = await admin.rpc("admin_overview");
        if (error) throw new Error(error.message);
        return json({ action, data });
      }

      case "users": {
        const { data, error } = await admin.rpc("admin_user_list");
        if (error) throw new Error(error.message);
        return json({ action, data });
      }

      case "activity": {
        const { data, error } = await admin.rpc("admin_activity", {
          p_limit: typeof body.limit === "number" ? body.limit : 50,
          p_before: body.before ?? null,
          p_user_id: body.userId ?? null,
          p_action: body.filterAction ?? null,
          p_entity: body.entity ?? null,
        });
        if (error) throw new Error(error.message);
        return json({ action, data });
      }

      case "activity_filters": {
        const { data, error } = await admin.rpc("admin_activity_filters");
        if (error) throw new Error(error.message);
        return json({ action, data });
      }

      case "user_detail": {
        if (!body.userId) return json({ error: "userId is required" }, 400);
        const { data, error } = await admin.rpc("admin_user_detail", {
          p_user_id: body.userId,
        });
        if (error) throw new Error(error.message);
        if (!data?.user) return json({ error: "No such user" }, 404);
        return json({ action, data });
      }

      // ── Mutations ───────────────────────────────────────
      // The self-action guard also lives in SQL. It is repeated here so the
      // console gets a clear 400 instead of a raised Postgres exception, and so
      // the rule survives if these functions ever gain another caller.

      case "revoke_sessions": {
        if (!body.userId) return json({ error: "userId is required" }, 400);
        if (body.userId === caller.id) {
          return json(
            { error: "You cannot revoke your own sessions from the console." },
            400,
          );
        }
        const { data, error } = await admin.rpc("admin_revoke_sessions", {
          p_admin_id: caller.id,
          p_user_id: body.userId,
        });
        if (error) throw new Error(error.message);
        console.log(`[${executionId}] ${caller.email} revoked sessions for ${body.userId}`);
        return json({ action, data });
      }

      case "set_account_disabled": {
        if (!body.userId) return json({ error: "userId is required" }, 400);
        if (typeof body.disabled !== "boolean") {
          return json({ error: "disabled must be true or false" }, 400);
        }
        if (body.userId === caller.id) {
          return json(
            { error: "You cannot disable your own account from the console." },
            400,
          );
        }
        const { data, error } = await admin.rpc("admin_set_account_disabled", {
          p_admin_id: caller.id,
          p_user_id: body.userId,
          p_disabled: body.disabled,
        });
        if (error) throw new Error(error.message);
        console.log(
          `[${executionId}] ${caller.email} ${body.disabled ? "disabled" : "enabled"} ${body.userId}`,
        );
        return json({ action, data });
      }

      default:
        return json({ error: `Unknown action "${action}"` }, 400);
    }
  } catch (e) {
    console.error(`[${executionId}] ${(e as Error).message}`);
    return json({ error: (e as Error).message }, 500);
  }
});
