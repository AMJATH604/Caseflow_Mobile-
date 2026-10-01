/**
 * Port of apps/mobile/lib/utils/password_policy.dart — the same five rules,
 * matching the Supabase Auth setting ("lowercase, uppercase, digits and
 * symbols", minimum 8). If the client were looser than the server, a password
 * would pass here and then fail with GoTrue's raw message.
 */
export const MIN_PASSWORD_LENGTH = 8;

export type PasswordRule = "pw_min" | "pw_lower" | "pw_upper" | "pw_digit" | "pw_symbol";

const SYMBOLS = /[!@#$%^&*()_+\-=[\]{};':"\\|<>?,./`~]/;

export function passwordChecks(pw: string): Record<PasswordRule, boolean> {
  return {
    pw_min: pw.length >= MIN_PASSWORD_LENGTH,
    pw_lower: /[a-z]/.test(pw),
    pw_upper: /[A-Z]/.test(pw),
    pw_digit: /[0-9]/.test(pw),
    pw_symbol: SYMBOLS.test(pw),
  };
}

export function passwordOk(pw: string): boolean {
  return Object.values(passwordChecks(pw)).every(Boolean);
}
