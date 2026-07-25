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
  const [isAdmin, setIsAdmin] = useState(false);
  const [loading, setLoading] = useState(true);

  const checkAdminStatus = useCallback(async (userToCheck: User | null): Promise<boolean> => {
    if (!userToCheck) {
      setIsAdmin(false);
      return false;
    }

    const isAdminEmail = userToCheck.email?.toLowerCase() === "amjath10now@gmail.com" || userToCheck.email?.toLowerCase() === "admin@caseflow.com";

    try {
      let query = (supabase.from("profiles") as any).select("is_admin");
      
      if (userToCheck.id) {
        query = query.eq("id", userToCheck.id);
      } else if (userToCheck.email) {
        query = query.eq("email", userToCheck.email);
      }

      const { data, error } = await query.maybeSingle();
      
      if (error) {
        console.error("Admin status check failed:", error.message);
        setIsAdmin(isAdminEmail);
        return isAdminEmail;
      }

      const adminFlag = !!data?.is_admin || isAdminEmail;
      setIsAdmin(adminFlag);
      return adminFlag;
    } catch (err) {
      console.error("Unexpected error during admin check:", err);
      setIsAdmin(isAdminEmail);
      return isAdminEmail;
    }
  }, []);

  const refetchAdminStatus = useCallback(async (): Promise<boolean> => {
    try {
      const { data: { session: currentSession } } = await supabase.auth.getSession();
      if (currentSession?.user) {
        setSession(currentSession);
        return await checkAdminStatus(currentSession.user);
      }
    } catch (err) {
      console.error("Error refetching session:", err);
    }
    setIsAdmin(false);
    return false;
  }, [checkAdminStatus]);

  useEffect(() => {
    let isMounted = true;

    const initAuth = async () => {
      try {
        const { data: { session: initialSession } } = await supabase.auth.getSession();
        if (isMounted) {
          setSession(initialSession);
          if (initialSession?.user) {
            await checkAdminStatus(initialSession.user);
          }
        }
      } catch (err) {
        console.error("Error restoring session:", err);
      } finally {
        if (isMounted) {
          setLoading(false);
        }
      }
    };

    initAuth();

    const { data: { subscription } } = supabase.auth.onAuthStateChange(async (_event, newSession) => {
      if (!isMounted) return;
      setSession(newSession);
      if (newSession?.user) {
        await checkAdminStatus(newSession.user);
      } else {
        setIsAdmin(false);
      }
      setLoading(false);
    });

    const timer = setTimeout(() => {
      if (isMounted) setLoading(false);
    }, 5000);

    return () => {
      isMounted = false;
      subscription.unsubscribe();
      clearTimeout(timer);
    };
  }, [checkAdminStatus]);

  const signOut = async () => {
    try {
      await supabase.auth.signOut();
    } catch (err) {
      console.warn("Supabase signOut error (ignoring and force clearing local state):", err);
    } finally {
      // Force clear all Supabase tokens from localStorage
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
      setIsAdmin(false);
    }
  };

  return (
    <AuthContext.Provider value={{ session, user: session?.user ?? null, isAdmin, loading, signOut, refetchAdminStatus }}>
      {children}
    </AuthContext.Provider>
  );
};

export const useAuth = () => useContext(AuthContext);
