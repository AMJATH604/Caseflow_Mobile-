import { createContext, useCallback, useContext, useEffect, useState, type ReactNode } from "react";
import type { Session, User } from "@supabase/supabase-js";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { supabase, type Tables } from "@/lib/supabase";

export type Profile = Tables<"profiles">;

/**
 * Who the signed-in person is *to this firm*:
 *   advocate — owns their practice (no firm_id on their profile)
 *   junior   — accepted into another advocate's firm
 *   clerk    — accepted into a firm with the clerk role (arrives in Phase 5)
 *
 * The database role (profiles.user_role) is 'advocate' for all three; the
 * firm relationship is what decides it, exactly as on mobile.
 */
export type FirmRole = "advocate" | "junior" | "clerk";

export class AccessDenied extends Error {
  constructor(public reason: "admin" | "citizen") {
    super(reason);
  }
}

/**
 * Loads the profile the way the mobile app does
 * (BaseRepository._fetchAndVerifyProfile):
 *   1. through the get_my_profile function — other users' contact fields are
 *      not directly selectable, but your own profile needs every column;
 *   2. creating a minimal profile if none exists yet;
 *   3. dropping a stale firm link: if the profile names a firm the user is no
 *      longer an accepted member of, the link is cleared rather than trusted.
 */
async function loadProfile(user: User): Promise<{ profile: Profile; role: FirmRole }> {
  const { data, error } = await supabase.rpc("get_my_profile").maybeSingle();
  if (error) throw error;

  if (!data) {
    const fresh = {
      id: user.id,
      full_name: user.email?.split("@")[0] ?? "User",
      subscription_tier: "free",
      updated_at: new Date().toISOString(),
    };
    const { error: insertError } = await supabase.from("profiles").insert(fresh);
    if (insertError) throw insertError;
    return { profile: { ...(fresh as unknown as Profile), firm_id: null, user_role: "advocate" }, role: "advocate" };
  }

  const profile = data as Profile;
  if (profile.user_role === "admin") throw new AccessDenied("admin");
  if (profile.user_role === "citizen") throw new AccessDenied("citizen");

  if (!profile.firm_id) return { profile, role: "advocate" };

  const { data: membership, error: mError } = await supabase
    .from("firm_members")
    .select("role")
    .eq("member_id", user.id)
    .eq("owner_id", profile.firm_id)
    .eq("status", "accepted")
    .maybeSingle();
  if (mError) throw mError;

  if (!membership) {
    await supabase.from("profiles").update({ firm_id: null }).eq("id", user.id);
    return { profile: { ...profile, firm_id: null }, role: "advocate" };
  }
  return { profile, role: membership.role === "clerk" ? "clerk" : "junior" };
}

interface AuthState {
  session: Session | null;
  user: User | null;
  profile: Profile | null;
  role: FirmRole | null;
  /** True until the stored session has been read on first load. */
  initialising: boolean;
  profileLoading: boolean;
  profileError: unknown;
  /** Set when a citizen or admin account tried to sign in here. It outlives
   *  the automatic sign-out, so the login page can still say why. */
  denied: AccessDenied["reason"] | null;
  signOut: () => Promise<void>;
}

const AuthContext = createContext<AuthState | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [session, setSession] = useState<Session | null>(null);
  const [initialising, setInitialising] = useState(true);
  const [denied, setDenied] = useState<AccessDenied["reason"] | null>(null);
  const qc = useQueryClient();

  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => {
      setSession(data.session);
      setInitialising(false);
    });
    const { data: sub } = supabase.auth.onAuthStateChange((_event, s) => setSession(s));
    return () => sub.subscription.unsubscribe();
  }, []);

  const user = session?.user ?? null;

  const profileQuery = useQuery({
    queryKey: ["me", user?.id],
    queryFn: () => loadProfile(user!),
    enabled: !!user,
    staleTime: 5 * 60 * 1000, // mobile caches the profile for 5 minutes too
    retry: (count, err) => !(err instanceof AccessDenied) && count < 2,
  });

  // A citizen or admin who signs in here is signed straight back out; the
  // login page shows why (see LoginPage).
  useEffect(() => {
    if (profileQuery.error instanceof AccessDenied) {
      setDenied(profileQuery.error.reason);
      void supabase.auth.signOut();
    }
  }, [profileQuery.error]);
  useEffect(() => {
    if (profileQuery.data) setDenied(null);
  }, [profileQuery.data]);

  const signOut = useCallback(async () => {
    await supabase.auth.signOut();
    qc.clear(); // nothing from one account may survive into the next
  }, [qc]);

  return (
    <AuthContext.Provider
      value={{
        session,
        user,
        profile: profileQuery.data?.profile ?? null,
        role: profileQuery.data?.role ?? null,
        initialising,
        profileLoading: profileQuery.isLoading,
        profileError: profileQuery.error,
        denied,
        signOut,
      }}
    >
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error("useAuth must be used inside AuthProvider");
  return ctx;
}
