// ─── Shared Auth Guard for Supabase Edge Functions ─────────────────
// Validates that webhook/cron requests are authorized before processing.
//
// These functions all construct a SERVICE-ROLE Supabase client, which
// bypasses RLS entirely. This guard is the only thing standing between an
// anonymous caller and that client, so it fails CLOSED: if no shared secret
// is configured, every request is rejected.
//
// Accepted credentials (in order of preference):
//   1. A Supabase secret key — the legacy service_role JWT as
//      `Authorization: Bearer`, or a new `sb_secret_…` key on `apikey`.
//   2. `Authorization: Bearer <CRON_SECRET>` — external schedulers, manual
//      admin triggers.
//   3. `x-supabase-webhook-secret: <WEBHOOK_SECRET>` — custom webhook configs.
//  3b. `x-pg-trigger-secret: <PG_TRIGGER_SECRET>` — SQL triggers using pg_net
//      that read the shared secret from Supabase vault.
//   4. A verified end-user JWT — ONLY when the caller passes
//      `{ allowUserJwt: true }`, and only after the token is actually

//      validated against Supabase Auth.
//
// Usage:
//   import { verifyWebhookAuth } from "../_shared/auth_guard.ts";
//
//   const authError = await verifyWebhookAuth(req);
//   if (authError) return authError;

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { allSecretKeys, publishableKey } from "./keys.ts";

/**
 * Length-safe, constant-time string comparison.
 *
 * A plain `a === b` on a secret leaks length and prefix information through
 * timing. This compares every byte regardless of where the first mismatch is.
 */
function timingSafeEqual(a: string | null | undefined, b: string | null | undefined): boolean {
  if (!a || !b) return false;

  const encoder = new TextEncoder();
  const aBytes = encoder.encode(a);
  const bBytes = encoder.encode(b);

  // Mismatched lengths can never be equal, but keep comparing so the
  // duration does not depend on where the difference is.
  let diff = aBytes.length ^ bBytes.length;
  const max = Math.max(aBytes.length, bBytes.length);
  for (let i = 0; i < max; i++) {
    diff |= (aBytes[i] ?? 0) ^ (bBytes[i] ?? 0);
  }
  return diff === 0;
}

function bearerToken(authHeader: string | null): string | null {
  if (!authHeader) return null;
  const match = /^Bearer\s+(.+)$/i.exec(authHeader.trim());
  return match ? match[1].trim() : null;
}

function unauthorized(reason: string): Response {
  console.error(`AUTH_GUARD: rejected — ${reason}`);
  return new Response(
    JSON.stringify({
      error: "Unauthorized",
      message:
        "This endpoint requires a valid service-role key, CRON_SECRET bearer token, or webhook secret.",
    }),
    { status: 401, headers: { "Content-Type": "application/json" } },
  );
}

export interface AuthGuardOptions {
  /**
   * Allow a verified end-user JWT to pass the guard.
   *
   * Defaults to `false`. Only enable this for functions that are genuinely
   * meant to be invoked by the app on a user's behalf AND that scope every
   * query to `user.id`. Cron/webhook functions must leave this off — they run
   * with the service-role key and have no per-user scoping.
   */
  allowUserJwt?: boolean;
}

/**
 * Verifies that the incoming request is from an authorized source.
 *
 * Returns `null` if authorized, or a `Response` (401/503) to return directly.
 */
export async function verifyWebhookAuth(
  req: Request,
  options: AuthGuardOptions = {},
): Promise<Response | null> {
  const { allowUserJwt = false } = options;

  const authHeader = req.headers.get("Authorization");
  const token = bearerToken(authHeader);
  const webhookSecretHeader = req.headers.get("x-supabase-webhook-secret");

  const serviceKeys = allSecretKeys();
  const cronSecret = Deno.env.get("CRON_SECRET");
  const webhookSecret = Deno.env.get("WEBHOOK_SECRET");

  // ─── Fail closed: refuse to run without a configured credential ─────
  // Previously this branch allowed the request through "for backward
  // compatibility", which meant an unconfigured deployment was fully open.
  if (serviceKeys.length === 0 && !cronSecret && !webhookSecret) {
    console.error(
      "AUTH_GUARD: no Supabase secret key, CRON_SECRET, or WEBHOOK_SECRET " +
        "is configured. Refusing all requests. Set one with: " +
        "supabase secrets set CRON_SECRET=<random>",
    );
    return new Response(
      JSON.stringify({
        error: "Service misconfigured",
        message: "No authentication secret is configured for this function.",
      }),
      { status: 503, headers: { "Content-Type": "application/json" } },
    );
  }

  // ─── Mode 1: Supabase secret key ────────────────────────────────────
  // Legacy service_role JWTs arrive as a Bearer token. The new sb_secret_…
  // keys cannot travel in Authorization (the gateway parses it as a JWT), so
  // they arrive on the `apikey` header instead.
  const apikeyHeader = req.headers.get("apikey");
  for (const key of serviceKeys) {
    if (timingSafeEqual(token, key) || timingSafeEqual(apikeyHeader, key)) return null;
  }

  // ─── Mode 2: CRON_SECRET bearer token ───────────────────────────────
  if (timingSafeEqual(token, cronSecret)) return null;

  // ─── Mode 3: Custom webhook secret header ───────────────────────────
  if (timingSafeEqual(webhookSecretHeader, webhookSecret)) return null;

  // ─── Mode 3b: pg_net trigger secret ────────────────────────────────
  // SQL triggers (pg_net) from the database send this header. The shared
  // secret is set once via: supabase secrets set PG_TRIGGER_SECRET=<random>
  // and stored in vault for the trigger functions to read.
  const pgTriggerHeader = req.headers.get("x-pg-trigger-secret");
  const pgTriggerSecret = Deno.env.get("PG_TRIGGER_SECRET");
  if (timingSafeEqual(pgTriggerHeader, pgTriggerSecret)) return null;

  // ─── Mode 4: Verified end-user JWT (opt-in only) ────────────────────
  // The old guard accepted anything shaped like `a.b.c` here without ever
  // checking a signature. We now validate the token against Supabase Auth.
  if (allowUserJwt && token) {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseAnonKey = publishableKey();

    if (!supabaseUrl || !supabaseAnonKey) {
      return unauthorized("allowUserJwt set but SUPABASE_URL/publishable key missing");
    }

    try {
      const supabase = createClient(supabaseUrl, supabaseAnonKey);
      const { data, error } = await supabase.auth.getUser(token);
      if (!error && data?.user) return null;
      return unauthorized("user JWT failed verification");
    } catch (e) {
      return unauthorized(`user JWT verification threw: ${(e as Error).message}`);
    }
  }

  return unauthorized("no matching credential");
}
