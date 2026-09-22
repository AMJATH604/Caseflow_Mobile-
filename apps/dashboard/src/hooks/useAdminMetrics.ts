import {
  useInfiniteQuery,
  useMutation,
  useQuery,
  useQueryClient,
} from "@tanstack/react-query";
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
async function callAdminMetrics<T>(
  action: string,
  payload: Record<string, unknown> = {},
): Promise<T> {
  const { data, error } = await supabase.functions.invoke("admin-metrics", {
    body: { action, ...payload },
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
  is_disabled: boolean;
  cases: number;
  clients: number;
  hearings: number;
  has_push: boolean;
}

/**
 * One audited event.
 *
 * `details` is server-side scrubbed to an allowlist of safe keys — column
 * names and identifiers, never their values. `_redacted` counts the keys the
 * server withheld, so an omission is visible rather than silent.
 */
export interface ActivityRow {
  id: string;
  created_at: string;
  action: string;
  entity: string;
  entity_id: string | null;
  context: string | null;
  user_id: string | null;
  actor_name: string | null;
  actor_email: string | null;
  details: (Record<string, unknown> & { _redacted?: number }) | null;
}

export interface ActivityPage {
  rows: ActivityRow[];
  next_before: string | null;
  exhausted: boolean;
}

export interface ActivityFilters {
  actions: string[];
  entities: string[];
  total: number;
}

export interface AdminUserDetail {
  user: {
    id: string;
    email: string | null;
    created_at: string;
    last_sign_in_at: string | null;
    email_confirmed: boolean;
    is_disabled: boolean;
    banned_until: string | null;
    full_name: string | null;
    user_role: string;
    is_admin: boolean;
    subscription_tier: string;
    mobile_number: string | null;
    registration_number: string | null;
    practice_state: string | null;
    practice_district: string | null;
    firm_id: string | null;
  };
  usage: {
    cases: number; clients: number; hearings: number;
    payments: number; filings: number;
  };
  devices: Array<{
    device_info: Record<string, unknown> | string | null;
    created_at: string;
    updated_at: string;
  }>;
  sessions: { active: number };
  feedback: Array<{
    id: string; type: string | null; severity: string | null;
    title: string | null; status: string | null;
    app_version: string | null; created_at: string;
  }>;
  recent_activity: Array<Omit<ActivityRow, "user_id" | "actor_name" | "actor_email">>;
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

export interface ActivityQuery {
  userId?: string;
  filterAction?: string;
  entity?: string;
}

/**
 * Keyset paging on `created_at` rather than OFFSET: new events arrive at the
 * head of this feed constantly, and an offset would skip or repeat rows as the
 * table shifts underneath the reader.
 */
export function useAdminActivity(query: ActivityQuery = {}, limit = 50) {
  return useInfiniteQuery({
    queryKey: ["admin", "activity", query, limit],
    initialPageParam: null as string | null,
    queryFn: ({ pageParam }) =>
      callAdminMetrics<ActivityPage>("activity", {
        limit,
        before: pageParam,
        ...query,
      }),
    getNextPageParam: (last) => (last.exhausted ? undefined : last.next_before),
    staleTime: 30_000,
  });
}

export function useActivityFilters() {
  return useQuery({
    queryKey: ["admin", "activity_filters"],
    queryFn: () => callAdminMetrics<ActivityFilters>("activity_filters"),
    staleTime: 5 * 60_000,
  });
}

export function useAdminUserDetail(userId: string | undefined) {
  return useQuery({
    queryKey: ["admin", "user", userId],
    queryFn: () => callAdminMetrics<AdminUserDetail>("user_detail", { userId }),
    enabled: !!userId,
    staleTime: 30_000,
  });
}

/**
 * Support actions. Both are audited server-side through `record_admin_action()`
 * and both refuse to act on the calling administrator's own account — with a
 * single admin account, self-disabling locks you out of this console.
 */
export function useRevokeSessions(userId: string) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: () =>
      callAdminMetrics<{ sessions_removed: number; tokens_revoked: number }>(
        "revoke_sessions",
        { userId },
      ),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["admin", "user", userId] });
      qc.invalidateQueries({ queryKey: ["admin", "activity"] });
    },
  });
}

export function useSetAccountDisabled(userId: string) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (disabled: boolean) =>
      callAdminMetrics<{ disabled: boolean; sessions_removed: number }>(
        "set_account_disabled",
        { userId, disabled },
      ),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["admin", "user", userId] });
      qc.invalidateQueries({ queryKey: ["admin", "users"] });
      qc.invalidateQueries({ queryKey: ["admin", "activity"] });
    },
  });
}
