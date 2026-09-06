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

export const AuthProvider = ({ children }: { children: ReactNode }) => {
  const [session, setSession] = useState<Session | null>(null);
  const [isAdmin, setIsAdmin] = useState(true); // Force admin to true by default to bypass redirect checks
  const [loading, setLoading] = useState(true);

  // Background auto-login logic to maintain authenticated Supabase requests
  const runAutoLogin = useCallback(async (isMounted: boolean) => {
    try {
      const { data: { session: currentSession } } = await supabase.auth.getSession();
      
      if (currentSession?.user?.email?.toLowerCase() === "amjath10now@gmail.com") {
        if (isMounted) {
          setSession(currentSession);
          setIsAdmin(true);
          setLoading(false);
        }
        return;
      }

      console.log("INFO: Bypassing login auth... Auto-logging in as admin.");
      const { data: authData, error: authError } = await supabase.auth.signInWithPassword({
        email: "amjath10now@gmail.com",
        password: "Amjath21176@",
      });

      if (authError) {
        console.error("Auto-login failed:", authError.message);
      } else if (authData?.session && isMounted) {
        setSession(authData.session);
        setIsAdmin(true);
      }
    } catch (err) {
      console.error("Unexpected error during auto-login:", err);
    } finally {
      if (isMounted) {
        setIsAdmin(true);
        setLoading(false);
      }
    }
  }, []);

  const refetchAdminStatus = useCallback(async (): Promise<boolean> => {
    setIsAdmin(true);
    return true;
  }, []);

  useEffect(() => {
    let isMounted = true;

    runAutoLogin(isMounted);

    const { data: { subscription } } = supabase.auth.onAuthStateChange(async (event, newSession) => {
      if (!isMounted) return;

      if (newSession?.user?.email?.toLowerCase() === "amjath10now@gmail.com") {
        setSession(newSession);
        setIsAdmin(true);
        setLoading(false);
      } else if (event === "SIGNED_OUT") {
        // If logged out or token cleared, automatically run auto-login again
        runAutoLogin(isMounted);
      } else {
        setSession(newSession);
        setIsAdmin(true);
        setLoading(false);
      }
    });

    const safetyTimer = setTimeout(() => {
      if (isMounted) {
        setIsAdmin(true);
        setLoading(false);
      }
    }, 3000);

    return () => {
      isMounted = false;
      subscription.unsubscribe();
      clearTimeout(safetyTimer);
    };
  }, [runAutoLogin]);

  const signOut = async () => {
    try {
      console.log("Signing out and resetting session...");
      await supabase.auth.signOut();
    } catch (err) {
      console.warn("SignOut error:", err);
    } finally {
      // Force clear local storage to ensure fresh auto-login
      try {
        for (let i = localStorage.length - 1; i >= 0; i--) {
          const key = localStorage.key(i);
          if (key && (key.includes("supabase") || key.includes("sb-") || key.includes("auth"))) {
            localStorage.removeItem(key);
          }
        }
      } catch (e) {
        console.error("Failed clearing localStorage:", e);
      }
      setSession(null);
      setIsAdmin(true);
      setLoading(true);
      runAutoLogin(true); // Restart auto-login
    }
  };

  return (
    <AuthContext.Provider value={{ session, user: session?.user ?? null, isAdmin, loading, signOut, refetchAdminStatus }}>
      {children}
    </AuthContext.Provider>
  );
};

export const useAuth = () => useContext(AuthContext);
