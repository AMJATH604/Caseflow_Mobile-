import { ShieldAlert, LogOut } from "lucide-react";
import { Button } from "@/components/ui/button";
import { useAuth } from "@/hooks/useAuth";
import { useNavigate } from "react-router-dom";

const Unauthorized = () => {
  const { signOut, user } = useAuth();
  const navigate = useNavigate();

  const handleLogout = async () => {
    await signOut();
    navigate("/auth");
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
            Your account <span className="font-medium text-slate-800">({user?.email})</span> 
            does not have administrative privileges required to access this dashboard.
          </p>
        </div>

        <div className="pt-4 flex flex-col gap-3">
          <Button 
            onClick={handleLogout}
            variant="outline"
            className="w-full h-12 rounded-xl group transition-all duration-300 hover:bg-slate-50"
          >
            <LogOut className="w-4 h-4 mr-2 text-slate-400 group-hover:text-red-500 transition-colors" />
            Sign into Admin Account
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
