import { Toaster } from "@/components/ui/toaster";
import { Toaster as Sonner } from "@/components/ui/sonner";
import { TooltipProvider } from "@/components/ui/tooltip";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { BrowserRouter, Routes, Route, Navigate } from "react-router-dom";
import { AuthProvider, useAuth } from "@/hooks/useAuth";
import { ThemeProvider } from "@/components/ThemeProvider";
import { DashboardLayout } from "@/components/DashboardLayout";
import { ErrorBoundary } from "@/components/ErrorBoundary";
import Auth from "./pages/Auth";
import Dashboard from "./pages/Dashboard";
import BareActs from "./pages/BareActs";
import StampValuesAdmin from "./pages/StampValuesAdmin";
import LegalTemplates from "./pages/LegalTemplates";
import Advocates from "./pages/Advocates";
import Unauthorized from "./pages/Unauthorized";
import NotFound from "./pages/NotFound";

const queryClient = new QueryClient();

function SplashScreen() {
  return (
    <div className="flex flex-col items-center justify-center min-h-screen bg-background gap-4">
      <div className="w-16 h-16 rounded-2xl bg-primary flex items-center justify-center shadow-lg animate-pulse">
        <svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className="text-primary-foreground">
          <path d="m16 16 3-8 3 8c-.87.65-1.92 1-3 1s-2.13-.35-3-1Z" />
          <path d="m2 16 3-8 3 8c-.87.65-1.92 1-3 1s-2.13-.35-3-1Z" />
          <path d="M7 21h10" />
          <path d="M12 3v18" />
          <path d="M3 7h2c2 0 5-1 7-2 2 1 5 2 7 2h2" />
        </svg>
      </div>
      <div className="text-center">
        <h1 className="text-xl font-bold text-foreground tracking-tight">CaseFlow</h1>
        <p className="text-xs text-muted-foreground mt-1">Loading your workspace...</p>
      </div>
      <div className="w-8 h-8 border-3 border-primary/30 border-t-primary rounded-full animate-spin mt-2" />
    </div>
  );
}

function ProtectedRoute({ children }: { children: React.ReactNode }) {
  const { user, isAdmin, loading } = useAuth();
  if (loading) return <SplashScreen />;
  if (!user) return <Navigate to="/auth" replace />;
  if (!isAdmin) return <Navigate to="/unauthorized" replace />;
  return <ErrorBoundary><DashboardLayout>{children}</DashboardLayout></ErrorBoundary>;
}

function AuthRoute() {
  const { user, loading } = useAuth();
  if (loading) return <SplashScreen />;
  if (user) return <Navigate to="/" replace />;
  return <Auth />;
}

const App = () => (
  <ThemeProvider>
    <QueryClientProvider client={queryClient}>
      <AuthProvider>
        <TooltipProvider>
        <Toaster />
        <Sonner />
        <BrowserRouter>
          <Routes>
            <Route path="/auth" element={<AuthRoute />} />
            <Route path="/" element={<ProtectedRoute><Dashboard /></ProtectedRoute>} />
            <Route path="/advocates" element={<ProtectedRoute><Advocates /></ProtectedRoute>} />
            <Route path="/bare-acts" element={<ProtectedRoute><BareActs /></ProtectedRoute>} />
            <Route path="/stamp-values" element={<ProtectedRoute><StampValuesAdmin /></ProtectedRoute>} />
            <Route path="/legal-templates" element={<ProtectedRoute><LegalTemplates /></ProtectedRoute>} />

            {/* The advocate-facing routes (/cases, /clients, /hearings,
                /payments, /certified-copies, /efiling, /tools, /ai-chat,
                /notifications) were removed. They rendered the administrator's
                own records — RLS scopes every query to the signed-in user — so
                they showed nothing useful for monitoring, and widening them to
                all users would have exposed privileged client material.
                Redirected rather than 404'd so old bookmarks land somewhere. */}
            <Route path="/cases/*" element={<Navigate to="/" replace />} />
            <Route path="/clients" element={<Navigate to="/" replace />} />
            <Route path="/hearings" element={<Navigate to="/" replace />} />
            <Route path="/payments" element={<Navigate to="/" replace />} />
            <Route path="/certified-copies" element={<Navigate to="/" replace />} />
            <Route path="/efiling" element={<Navigate to="/" replace />} />
            <Route path="/tools" element={<Navigate to="/" replace />} />
            <Route path="/ai-chat" element={<Navigate to="/" replace />} />
            <Route path="/notifications" element={<Navigate to="/" replace />} />

            <Route path="/unauthorized" element={<Unauthorized />} />
            <Route path="*" element={<NotFound />} />
          </Routes>
        </BrowserRouter>
        </TooltipProvider>
      </AuthProvider>
    </QueryClientProvider>
  </ThemeProvider>
);

export default App;
