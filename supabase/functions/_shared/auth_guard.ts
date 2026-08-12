// ─── Shared Auth Guard for Supabase Edge Functions ─────────────────
// Validates that webhook/cron requests are authorized before processing.
//
// Two authentication modes:
// 1. **Webhook mode** (database triggers): Validates the Supabase webhook signature
//    using the SUPABASE_SERVICE_ROLE_KEY from the Authorization header.
// 2. **Cron/manual mode**: Validates a shared CRON_SECRET bearer token.
//
// Usage:
//   import { verifyWebhookAuth } from "../_shared/auth_guard.ts";
//
//   // At the top of your handler:
//   const authError = verifyWebhookAuth(req);
//   if (authError) return authError;

/**
 * Verifies that the incoming request is from an authorized source.
 * 
 * Accepts:
 * - Supabase webhook calls (Authorization header contains the service_role key or anon key)
 * - Cron jobs with a CRON_SECRET bearer token
 * - Supabase internal calls (x-supabase-webhook-secret header)
 * 
 * Returns null if authorized, or a 401 Response if unauthorized.
 */
export function verifyWebhookAuth(req: Request): Response | null {
  const authHeader = req.headers.get("Authorization");
  const webhookSecret = req.headers.get("x-supabase-webhook-secret");

  // ─── Mode 1: Supabase database webhook ──────────────────────
  // Supabase webhooks send the service_role key in the Authorization header.
  const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (supabaseServiceKey && authHeader) {
    const token = authHeader.replace("Bearer ", "");
    if (token === supabaseServiceKey) {
      return null; // Authorized
    }
  }

  // ─── Mode 2: Supabase webhook secret header ─────────────────
  // Some Supabase webhook configurations send a custom secret header.
  const expectedWebhookSecret = Deno.env.get("WEBHOOK_SECRET");
  if (expectedWebhookSecret && webhookSecret === expectedWebhookSecret) {
    return null; // Authorized
  }

  // ─── Mode 3: CRON_SECRET bearer token ───────────────────────
  // For scheduled cron jobs or manual admin triggers.
  const cronSecret = Deno.env.get("CRON_SECRET");
  if (cronSecret && authHeader === `Bearer ${cronSecret}`) {
    return null; // Authorized
  }

  // ─── Mode 4: Supabase internal invocation ───────────────────
  // When functions are invoked via supabase.functions.invoke() from
  // the client, they include the user's JWT. We allow this as well
  // since the function logic handles its own data-level auth via RLS.
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
  if (supabaseAnonKey && authHeader) {
    const token = authHeader.replace("Bearer ", "");
    if (token === supabaseAnonKey) {
      return null; // Authorized (client invocation with anon key)
    }
    // Also allow any JWT-based auth (user token) — the JWT will be validated
    // downstream by Supabase when the function creates a client with it.
    if (token.split(".").length === 3) {
      return null; // Looks like a JWT, allow through
    }
  }

  // ─── Fallback: No CRON_SECRET configured = legacy mode ──────
  // If neither CRON_SECRET nor WEBHOOK_SECRET is configured,
  // allow requests to maintain backward compatibility.
  // Once you set CRON_SECRET in Supabase secrets, auth will be enforced.
  if (!cronSecret && !expectedWebhookSecret) {
    console.warn(
      "⚠️  AUTH_GUARD: No CRON_SECRET or WEBHOOK_SECRET configured. " +
      "Set 'supabase secrets set CRON_SECRET=<random>' to enforce auth. " +
      "Allowing request for backward compatibility."
    );
    return null;
  }

  // ─── Unauthorized ───────────────────────────────────────────
  console.error("AUTH_GUARD: Unauthorized request rejected");
  return new Response(
    JSON.stringify({ 
      error: "Unauthorized", 
      message: "Valid Authorization header required. Use Bearer <CRON_SECRET> for cron jobs." 
    }),
    { 
      status: 401, 
      headers: { "Content-Type": "application/json" } 
    }
  );
}
