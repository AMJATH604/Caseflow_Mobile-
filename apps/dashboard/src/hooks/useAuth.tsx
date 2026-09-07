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
 * Resolves whether a user holds the admin role.
 *
 * Two sources exist in this schema, so try both: `has_role` is a
 * security-definer function over `user_roles`, and older rows carry the role
 * on `profiles` instead. A deployment may have only one of them.
 *
 * Fails closed. If neither source can answer, the user is not an admin — the
 * previous implementation defaulted to `true`, which meant anyone who loaded
 * the page passed the admin gate.
 */
async function resolveIsAdmin(userId: string | undefined): Promise<boolean> {
  if (!userId) return false;

  const { data, error } = await supabase.rpc("has_role", {
    _user_id: userId,
    _role: "admin",
  });
  if (!error) return data === true;

  const { data: profile, error: profileError } = await supabase
    .from("profiles")
    .select("role")
    .eq("id", userId)
    .maybeSingle();

  if (profileError) {
    console.error("Could not determine admin status:", profileError.message);
    return false;
  }
  return profile?.role === "admin";
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
