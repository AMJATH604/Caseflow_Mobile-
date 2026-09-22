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

  // A server function, because profiles.is_admin is not selectable by ordinary
  // roles. It only ever answers for the signed-in user; userId above is just
  // the "someone is signed in" guard.
  const { data: isAdmin, error } = await (supabase.rpc as (fn: string) => any)(
    "is_platform_admin",
  );

  if (error) {
    console.error("Could not determine admin status:", error.message);
    return false;
  }
  return isAdmin === true;
}

export const AuthProvider = ({ children }: { children: ReactNode }) => {
  const [session, setSession] = useState<Session | null>(null);
  const [isAdmin, setIsAdmin] = useState(false);
  const [loading, setLoading] = useState(true);

  const refetchAdminStatus = useCallback(async (): Promise<boolean> => {
    const {
      data: { session: current },
    } = await supabase.auth.getSession();
    const admin = await resolveIsAdmin(current?.user?.id);
    setIsAdmin(admin);
    return admin;
  }, []);

  useEffect(() => {
    let isMounted = true;

    // A `caseflow_demo` localStorage flag used to be honoured here and in
    // refetchAdminStatus: setting it fabricated a session and forced
    // isAdmin = true, which cleared every ProtectedRoute gate in the app.
    // Anyone could type one line in the browser console to reach the admin
    // UI. It is removed rather than gated on an env flag, because a build
    // toggle is one misconfiguration away from shipping the same hole.
    // Session and admin status now come only from Supabase.

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
