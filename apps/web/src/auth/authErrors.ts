/**
 * Turns a sign-in failure into one of the login page's messages. The phrase
 * lists mirror the mobile login screen, which learned them from what GoTrue
 * actually returns (including on iOS, where the wording differed).
 */
export type AuthErrorKey = "auth.err_invalid" | "auth.err_unconfirmed" | "auth.err_network";

export function classifyAuthError(err: unknown): { key: AuthErrorKey | null; detail: string } {
  const detail = err instanceof Error ? err.message : String(err ?? "");
  const s = detail.toLowerCase();

  const network = ["timed out", "timeout", "failed to fetch", "networkerror", "network request failed", "load failed", "connection"];
  if (network.some((p) => s.includes(p))) return { key: "auth.err_network", detail };

  const invalid = ["invalid login", "invalid credentials", "invalid_credentials", "invalid grant", "invalid_grant", "user not found", "user_not_found", "wrong password", "bad credentials"];
  if (invalid.some((p) => s.includes(p))) return { key: "auth.err_invalid", detail };

  const unconfirmed = ["email not confirmed", "email_not_confirmed", "email not verified", "email_not_verified", "email address not confirmed"];
  if (unconfirmed.some((p) => s.includes(p))) return { key: "auth.err_unconfirmed", detail };

  // Anything else is shown as GoTrue said it — the mobile app's generic
  // "Authentication failed" hid exactly the detail needed to fix iOS sign-in.
  return { key: null, detail };
}
