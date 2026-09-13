import { useQuery } from "@tanstack/react-query";
import { supabase } from "@/integrations/supabase/client";

/**
 * Reads platform-wide data through the `admin-metrics` edge function.
 *
 * Nothing in this console queries across users directly. RLS scopes every
 * ordinary query to the signed-in user, and widening it for admins would hand
 * full-database authority to the browser. The function verifies the caller's
 * JWT, confirms they are an administrator, and only then reads with the
 * service role — returning counts and identity, never record contents.
 *
 * `functions.invoke` attaches the current session's access token, which is
 * what the function checks.
 */
async function callAdminMetrics<T>(action: string): Promise<T> {
  const { data, error } = await supabase.functions.invoke("admin-metrics", {
    body: { action },
  });

  if (error) {
    // A 403 here means the account is signed in but not an administrator —
    // worth saying plainly rather than surfacing a generic failure.
    throw new Error(
      error.message?.includes("403") || error.message?.includes("Administrator")
        ? "This account does not have administrator access."
        : error.message || "Could not reach the admin service.",
    );
  }
  if (data?.error) throw new Error(data.error);
  return data?.data as T;
}

export interface AdminOverview {
  users: {
    total: number; advocates: number; citizens: number; admins: number;
    active_1d: number; active_7d: number; active_30d: number; never_signed_in: number;
  };
  signups: Array<{ week: string; count: number }>;
  records: {
    cases: number; clients: number; hearings: number;
    cases_7d: number; hearings_7d: number; statutes: number;
  };
  adoption: { inactive_30d: number; no_push_token: number; no_cases: number };
  delivery: { tokens: number; users_with_token: number; notifications_7d: number };
  feedback: { total: number; open: number };
  subscriptions: Record<string, number>;
  generated_at: string;
}

export interface AdminUser {
  id: string;
  email: string | null;
  full_name: string | null;
  user_role: string;
  is_admin: boolean;
  subscription_tier: string;
  practice_district: string | null;
  created_at: string;
  last_sign_in_at: string | null;
  email_confirmed: boolean;
  cases: number;
  clients: number;
  hearings: number;
  has_push: boolean;
}

export function useAdminOverview() {
  return useQuery({
    queryKey: ["admin", "overview"],
    queryFn: () => callAdminMetrics<AdminOverview>("overview"),
    staleTime: 60_000,
  });
}

export function useAdminUsers() {
  return useQuery({
    queryKey: ["admin", "users"],
    queryFn: () => callAdminMetrics<AdminUser[]>("users"),
    staleTime: 60_000,
  });
}
