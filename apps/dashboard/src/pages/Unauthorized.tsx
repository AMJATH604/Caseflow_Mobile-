import { useEffect, useState } from "react";
import { ShieldAlert, LogOut, ArrowRight, RefreshCw, Loader2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { useAuth } from "@/hooks/useAuth";
import { useNavigate } from "react-router-dom";
import { toast } from "sonner";

const Unauthorized = () => {
  const { signOut, user, isAdmin, loading, refetchAdminStatus } = useAuth();
  const navigate = useNavigate();
  const [checking, setChecking] = useState(false);

  useEffect(() => {
    if (!loading && isAdmin) {
      navigate("/", { replace: true });
    }
  }, [isAdmin, loading, navigate]);

  const handleLogout = async () => {
    try {
      await signOut();
    } catch (e) {
      console.error(e);
    }
    // Hard navigate to /auth to guarantee clean state reload
    window.location.href = "/auth";
  };

  const handleCheckAccess = async () => {
    setChecking(true);
    try {
      const isNowAdmin = await refetchAdminStatus();
      if (isNowAdmin) {
        toast.success("Admin access verified! Redirecting to Dashboard...");
        navigate("/", { replace: true });
      } else {
        toast.error("Account not recognized as admin. Try signing out and back in.");
      }
    } catch (err: any) {
      toast.error("Error checking access: " + err.message);
    } finally {
      setChecking(false);
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-slate-50 px-4">
      <div className="max-w-md w-full text-center space-y-6 p-8 bg-white rounded-3xl shadow-xl shadow-slate-200/50">
        <div className="inline-flex items-center justify-center w-20 h-20 rounded-full bg-red-50 text-red-500 mb-2 border-4 border-white shadow-sm animate-in zoom-in duration-500">
          <ShieldAlert className="w-10 h-10" />
        </div>
        
        <div className="space-y-2">
          <h1 className="text-2xl font-bold text-slate-900 tracking-tight">Access Denied</h1>
          <p className="text-slate-500 text-sm leading-relaxed">
            Your account <span className="font-medium text-slate-800">({user?.email || "unknown"})</span> 
            does not have administrative privileges required to access this dashboard.
          </p>
        </div>

        <div className="pt-4 flex flex-col gap-3">
          {isAdmin ? (
            <Button 
              onClick={() => navigate("/", { replace: true })}
              className="w-full h-12 rounded-xl bg-primary hover:bg-primary/90 text-white font-medium"
            >
              Go to Dashboard
              <ArrowRight className="w-4 h-4 ml-2" />
            </Button>
          ) : (
            <Button 
              onClick={handleCheckAccess}
              disabled={checking}
              className="w-full h-12 rounded-xl bg-primary hover:bg-primary/90 text-white font-medium"
            >
              {checking ? (
                <>
                  <Loader2 className="w-4 h-4 mr-2 animate-spin" />
                  Verifying Admin Access...
                </>
              ) : (
                <>
                  <RefreshCw className="w-4 h-4 mr-2" />
                  Check Admin Access Again
                </>
              )}
            </Button>
          )}

          <Button 
            onClick={handleLogout}
            variant="outline"
            className="w-full h-12 rounded-xl group transition-all duration-300 hover:bg-slate-50"
          >
            <LogOut className="w-4 h-4 mr-2 text-slate-400 group-hover:text-red-500 transition-colors" />
            Sign Out / Switch Account
          </Button>
          
          <p className="text-xs text-slate-400">
            If you believe this is an error, please contact your system administrator.
          </p>
        </div>
      </div>
    </div>
  );
};

export default Unauthorized;
