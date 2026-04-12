import { createContext, useContext, useEffect, useState, ReactNode } from "react";
import { Session, User } from "@supabase/supabase-js";
import { supabase } from "@/integrations/supabase/client";

interface AuthContextType {
  session: Session | null;
  user: User | null;
  isAdmin: boolean;
  loading: boolean;
  signOut: () => Promise<void>;
}

const AuthContext = createContext<AuthContextType>({ session: null, user: null, isAdmin: false, loading: true, signOut: async () => { } });

export const AuthProvider = ({ children }: { children: ReactNode }) => {
  const [session, setSession] = useState<Session | null>(null);
  const [isAdmin, setIsAdmin] = useState(false);
  const [loading, setLoading] = useState(true);

  const checkAdminStatus = async (user: User) => {
    try {
      const userId = user.id;
      const email = user.email;
      
      console.log("DEBUG: Attempting admin check for:", { userId, email });

      // TEMP OVERRIDE: Automatically grant admin access to the owner's email
      if (email === "amjath10now@gmail.com" || email === "admin@caseflow.com") {
        console.log("INFO: Owner override active. Granting Admin access.");
        setIsAdmin(true);
        return;
      }

      const { data, error } = await supabase
        .from("profiles")
        .select("is_admin")
        .eq("id", userId)
        .maybeSingle();
      
      if (error) {
        console.error("Supabase Error checking admin status:", error);
        setIsAdmin(false);
        return;
      }

      if (data) {
        console.log("Admin search result:", data);
        setIsAdmin(!!data.is_admin);
      } else {
        console.warn("Warning: No profile record found for this user in database.");
        setIsAdmin(false);
      }
    } catch (err) {
      console.error("Unexpected Error during admin check:", err);
      setIsAdmin(false);
    }
  };

  useEffect(() => {
    // Restore persisted session FIRST to avoid redirect flash
    supabase.auth.getSession().then(({ data: { session } }) => {
      setSession(session);
      if (session?.user) {
        checkAdminStatus(session.user).then(() => setLoading(false));
      } else {
        setLoading(false);
      }
    }).catch(() => setLoading(false));

    // Then listen for future auth changes (login, logout, token refresh)
    const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, session) => {
      setSession(session);
      if (session?.user) {
        checkAdminStatus(session.user);
      } else {
        setIsAdmin(false);
      }
      setLoading(false);
    });

    // Safety timeout: never hang on loading screen forever (poor network)
    const timer = setTimeout(() => setLoading(false), 5000);

    return () => {
      subscription.unsubscribe();
      clearTimeout(timer);
    };
  }, []);

  const signOut = async () => {
    await supabase.auth.signOut();
  };

  return (
    <AuthContext.Provider value={{ session, user: session?.user ?? null, isAdmin, loading, signOut }}>
      {children}
    </AuthContext.Provider>
  );
};

export const useAuth = () => useContext(AuthContext);
