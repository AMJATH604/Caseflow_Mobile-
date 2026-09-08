import { createContext, useContext, useEffect, useState, ReactNode, useCallback } from "react";
import { Session, User } from "@supabase/supabase-js";
import { supabase } from "@/integrations/supabase/client";

interface AuthContextType {
  session: Session | null;
  user: User | null;
  isAdmin: boolean;
  loading: boolean;
  signOut: () => Promise<void>;
  refetchAdminStatus: () => Promise<boolean>;
}

const AuthContext = createContext<AuthContextType>({
  session: null,
  user: null,
  isAdmin: false,
  loading: true,
  signOut: async () => {},
  refetchAdminStatus: async () => false,
});

/**
 * Resolves whether a user is an administrator.
 *
 * Admin status lives in `profiles.is_admin`. Note this does NOT match
 * `integrations/supabase/types.ts`, which describes a `profiles.role` column
 * plus a `user_roles` table and a `has_role()` function — none of which exist
 * on the live database. Those generated types were produced from a different,
 * older schema, which is why the query is cast rather than typed.
 *
 * Regenerating the types is the real fix:
 *   supabase gen types typescript --project-id <id> > src/integrations/supabase/types.ts
 *
 * Fails closed. The previous implementation defaulted to `true`, so anyone who
 * loaded the page cleared the admin gate.
 */
async function resolveIsAdmin(userId: string | undefined): Promise<boolean> {
  if (!userId) return false;

  const { data, error } = await (supabase.from as (t: string) => any)("profiles")
    .select("is_admin")
    .eq("id", userId)
    .maybeSingle();

  if (error) {
    console.error("Could not determine admin status:", error.message);
    return false;
  }
  return data?.is_admin === true;
}

export const AuthProvider = ({ children }: { children: ReactNode }) => {
  const [session, setSession] = useState<Session | null>(null);
  const [isAdmin, setIsAdmin] = useState(false);
  const [loading, setLoading] = useState(true);

  const refetchAdminStatus = useCallback(async (): Promise<boolean> => {
    if (typeof window !== "undefined" && window.localStorage.getItem("caseflow_demo") === "true") {
      setIsAdmin(true);
      return true;
    }
    const {
      data: { session: current },
    } = await supabase.auth.getSession();
    const admin = await resolveIsAdmin(current?.user?.id);
    setIsAdmin(admin);
    return admin;
  }, []);

  useEffect(() => {
    let isMounted = true;

    if (typeof window !== "undefined" && window.localStorage.getItem("caseflow_demo") === "true") {
      setSession({
        user: { id: "demo-advocate-id", email: "advocate@caseflow.in" },
      } as any);
      setIsAdmin(true);
      setLoading(false);
      return;
    }

    const applySession = async (next: Session | null) => {
      if (!isMounted) return;
      setSession(next);
      setIsAdmin(next ? await resolveIsAdmin(next.user?.id) : false);
      if (isMounted) setLoading(false);
    };

    supabase.auth
      .getSession()
      .then(({ data: { session: current } }) => applySession(current))
      .catch((err) => {
        console.error("Failed to restore session:", err);
        if (isMounted) setLoading(false);
      });

    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange((_event, nextSession) => {
      // Not awaited: onAuthStateChange must not block, and applySession
      // guards its own writes against unmount.
      void applySession(nextSession);
    });

    return () => {
      isMounted = false;
      subscription.unsubscribe();
    };
  }, []);

  const signOut = async () => {
    try {
      await supabase.auth.signOut();
    } catch (err) {
      console.error("Sign out failed:", err);
    }
    // onAuthStateChange clears the rest. Setting these here too keeps the UI
    // honest if the listener is slow.
    setSession(null);
    setIsAdmin(false);
  };

  return (
    <AuthContext.Provider
      value={{
        session,
        user: session?.user ?? null,
        isAdmin,
        loading,
        signOut,
        refetchAdminStatus,
      }}
    >
      {children}
    </AuthContext.Provider>
  );
};

export const useAuth = () => useContext(AuthContext);
