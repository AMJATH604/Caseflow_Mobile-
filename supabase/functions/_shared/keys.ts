// ─── Supabase API keys for Edge Functions ──────────────────────────
//
// Supabase is moving from the JWT-based legacy keys (`anon`, `service_role`)
// to opaque `sb_publishable_…` / `sb_secret_…` keys. Edge Functions receive
// both generations:
//
//   legacy  SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY          (plain strings)
//   new     SUPABASE_PUBLISHABLE_KEYS, SUPABASE_SECRET_KEYS       (JSON: { name: key })
//
// Every function reads its keys through here, preferring the new keys and
// falling back to the legacy ones. That makes a deploy safe on either side of
// the migration: the functions keep working while legacy keys are enabled, and
// keep working after they are disabled.
//
// Why this matters for CaseFlow: a legacy service_role key was committed to
// the repository (apps/mobile/logs/sr.txt). The only way to kill it is to
// disable the legacy keys, which must not take the notification pipeline down
// with it.

function fromKeyMap(envName: string, keyName: string): string | undefined {
  const raw = Deno.env.get(envName);
  if (!raw) return undefined;
  try {
    const map = JSON.parse(raw) as Record<string, string>;
    return map[keyName] || Object.values(map)[0] || undefined;
  } catch {
    return undefined;
  }
}

/** Privileged key — bypasses RLS. Server-side only, never returned to a client. */
export function secretKey(): string | undefined {
  return fromKeyMap("SUPABASE_SECRET_KEYS", "default") ??
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
    undefined;
}

/** Public key — safe for clients, subject to RLS. */
export function publishableKey(): string | undefined {
  return fromKeyMap("SUPABASE_PUBLISHABLE_KEYS", "default") ??
    Deno.env.get("SUPABASE_ANON_KEY") ??
    undefined;
}

/** Every key that grants service-level access, for credential comparison. */
export function allSecretKeys(): string[] {
  const keys: string[] = [];
  const raw = Deno.env.get("SUPABASE_SECRET_KEYS");
  if (raw) {
    try {
      keys.push(...Object.values(JSON.parse(raw) as Record<string, string>));
    } catch { /* ignore malformed */ }
  }
  const legacy = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (legacy) keys.push(legacy);
  return keys.filter(Boolean);
}

export function requireSecretKey(): string {
  const key = secretKey();
  if (!key) throw new Error("Missing SUPABASE_SECRET_KEYS / SUPABASE_SERVICE_ROLE_KEY");
  return key;
}

export function requirePublishableKey(): string {
  const key = publishableKey();
  if (!key) throw new Error("Missing SUPABASE_PUBLISHABLE_KEYS / SUPABASE_ANON_KEY");
  return key;
}
