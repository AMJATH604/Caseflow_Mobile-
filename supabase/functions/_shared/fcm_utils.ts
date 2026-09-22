// ─── Shared FCM Utility for Supabase Edge Functions ────────────────
// Provides Google OAuth token generation for Firebase Cloud Messaging (FCM) v1 API.
// Used by: send-chat-notification, send-dm-notification, send-caveat-reminders, send-hearing-reminders
//
// Usage:
//   import { getAccessToken, cleanupInvalidToken } from "../_shared/fcm_utils.ts";

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";
import { secretKey } from "./keys.ts";

// ─── Google OAuth for FCM v1 API ─────────────────────────────
// Generates a short-lived OAuth2 access token from a Firebase service account
// using the JWT Bearer grant flow. Token is valid for 1 hour.

// Google's OAuth tokens are valid for an hour, but this was previously
// re-minted (RS256 sign + network round-trip to oauth2.googleapis.com) on
// every single invocation. Cache it in module scope — Deno keeps the isolate
// warm between requests, so a batch of reminders now signs once, not N times.
// Refreshed 5 minutes early to avoid using a token that expires mid-flight.
let cachedToken: { token: string; expiresAt: number } | null = null;
const TOKEN_REFRESH_MARGIN_MS = 5 * 60 * 1000;

export async function getAccessToken(serviceAccount: any): Promise<string> {
  if (cachedToken && Date.now() < cachedToken.expiresAt - TOKEN_REFRESH_MARGIN_MS) {
    return cachedToken.token;
  }

  const now = Math.floor(Date.now() / 1000);

  const base64UrlEncode = (str: string) =>
    btoa(str).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");

  const base64UrlEncodeBytes = (bytes: Uint8Array) =>
    btoa(String.fromCharCode(...bytes))
      .replace(/\+/g, "-")
      .replace(/\//g, "_")
      .replace(/=+$/, "");

  const header = base64UrlEncode(
    JSON.stringify({ alg: "RS256", typ: "JWT" })
  );
  const payload = base64UrlEncode(
    JSON.stringify({
      iss: serviceAccount.client_email,
      scope: "https://www.googleapis.com/auth/firebase.messaging",
      aud: "https://oauth2.googleapis.com/token",
      iat: now,
      exp: now + 3600,
    })
  );

  const pemContents = serviceAccount.private_key
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\n/g, "");
  const binaryKey = Uint8Array.from(atob(pemContents), (c) => c.charCodeAt(0));

  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    binaryKey,
    { name: "RSASSA-PKCS1-v1_5", hash: { name: "SHA-256" } },
    false,
    ["sign"]
  );

  const unsignedToken = `${header}.${payload}`;
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    new TextEncoder().encode(unsignedToken)
  );

  const jwt = `${unsignedToken}.${base64UrlEncodeBytes(
    new Uint8Array(signature)
  )}`;

  const tokenResponse = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  });

  const tokenData = await tokenResponse.json();
  if (!tokenData.access_token) {
    throw new Error(`Failed to get OAuth token: ${JSON.stringify(tokenData)}`);
  }

  // Google returns expires_in as seconds remaining; fall back to 1 hour.
  const expiresInMs = (tokenData.expires_in ?? 3600) * 1000;
  cachedToken = {
    token: tokenData.access_token,
    expiresAt: Date.now() + expiresInMs,
  };

  return tokenData.access_token;
}

// ─── FCM Token Cleanup ──────────────────────────────────────────
// Removes invalid/expired FCM tokens from the database when FCM returns
// NOT_FOUND or UNREGISTERED errors.

export async function cleanupInvalidToken(
  supabase: SupabaseClient,
  token: string,
  executionId: string
): Promise<void> {
  console.log(
    `[${executionId}] Removing invalid token: ${token.substring(0, 10)}...`
  );
  await supabase.from("fcm_tokens").delete().eq("token", token);
}

// ─── FCM Send Helper ────────────────────────────────────────────
// Sends a single FCM message and handles token cleanup on failure.

export async function sendFcmMessage(
  projectId: string,
  accessToken: string,
  payload: any,
  supabase: SupabaseClient,
  token: string,
  executionId: string
): Promise<{ success: boolean; error?: string }> {
  try {
    const fcmResponse = await fetch(
      `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(payload),
      }
    );

    if (fcmResponse.ok) {
      return { success: true };
    }

    const errorBody = await fcmResponse.text();

    // Auto-cleanup invalid tokens
    if (
      fcmResponse.status === 404 ||
      errorBody.includes("NOT_FOUND") ||
      errorBody.includes("UNREGISTERED")
    ) {
      await cleanupInvalidToken(supabase, token, executionId);
    }

    return {
      success: false,
      error: `Token ${token.substring(0, 10)}...: ${errorBody.substring(0, 100)}`,
    };
  } catch (e) {
    return {
      success: false,
      error: `Token ${token.substring(0, 10)}...: ${(e as any).message}`,
    };
  }
}

// ─── Notification Centre Record ─────────────────────────────────
// Persists a notification so it also appears in the in-app Notification
// Centre (public.notifications), not just as a transient push.
//
// Call this BEFORE looking up fcm_tokens. A user who declined notification
// permission has no token at all, and several senders return early on
// `no_tokens` — but they should still get the in-app record.
//
// Never throws: failing to record must not stop a push that would otherwise
// go out. Rows are purged after 24 hours by the purge-expired-notifications
// cron job, so this table stays small.

export type NotificationRecord = {
  user_id: string;
  type:
    | "hearing_reminder"
    | "caveat_reminder"
    | "invitation"
    | "invitation_response"
    | "case_status"
    | "task_assigned"
    | "task_due"
    | "payment"
    | "bar_notice";
  title: string;
  body?: string;
  /** go_router path pushed when the row is tapped, e.g. `/cases/<uuid>`. */
  route?: string;
  payload?: Record<string, unknown>;
  /**
   * Stable key for one logical event, e.g. `hearing:<id>:morning_9am:<date>`.
   * A retried cron run reuses it and the duplicate insert is dropped by the
   * partial unique index on the column.
   */
  dedupe_key?: string;
};

export async function recordNotification(
  supabase: SupabaseClient,
  record: NotificationRecord,
  executionId: string
): Promise<void> {
  try {
    const { error } = await supabase.from("notifications").insert({
      user_id: record.user_id,
      type: record.type,
      title: record.title,
      body: record.body ?? "",
      route: record.route ?? null,
      payload: record.payload ?? {},
      dedupe_key: record.dedupe_key ?? null,
    });

    // 23505 = unique_violation, i.e. the dedupe_key already exists. Expected
    // on a retry, not an error worth logging loudly.
    if (error && error.code !== "23505") {
      console.log(
        `[${executionId}] recordNotification failed for ${record.user_id}: ${error.message}`
      );
    }
  } catch (e) {
    console.log(
      `[${executionId}] recordNotification threw: ${(e as any).message}`
    );
  }
}

// ─── Supabase + Firebase Init Helper ────────────────────────────
// Common initialization pattern used by all notification functions.

export function initClients(): {
  supabase: SupabaseClient;
  firebaseServiceAccount: any;
  projectId: string;
} {
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseServiceKey = secretKey();
  const firebaseServiceAccountJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT");

  if (!supabaseUrl || !supabaseServiceKey) {
    throw new Error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY");
  }
  if (!firebaseServiceAccountJson) {
    throw new Error("Missing FIREBASE_SERVICE_ACCOUNT secret");
  }

  const supabase = createClient(supabaseUrl, supabaseServiceKey);
  const firebaseServiceAccount = JSON.parse(firebaseServiceAccountJson);

  return {
    supabase,
    firebaseServiceAccount,
    projectId: firebaseServiceAccount.project_id,
  };
}
