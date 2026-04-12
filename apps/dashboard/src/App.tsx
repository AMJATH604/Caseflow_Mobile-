import { Toaster } from "@/components/ui/toaster";
import { Toaster as Sonner } from "@/components/ui/sonner";
import { TooltipProvider } from "@/components/ui/tooltip";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { BrowserRouter, Routes, Route, Navigate } from "react-router-dom";
import { AuthProvider, useAuth } from "@/hooks/useAuth";
import { DashboardLayout } from "@/components/DashboardLayout";
import { ErrorBoundary } from "@/components/ErrorBoundary";
import Auth from "./pages/Auth";
import Dashboard from "./pages/Dashboard";
import Clients from "./pages/Clients";
import Cases from "./pages/Cases";
import CaseDetail from "./pages/CaseDetail";
import EFiling from "./pages/EFiling";
import Hearings from "./pages/Hearings";
import CertifiedCopies from "./pages/CertifiedCopies";
import Payments from "./pages/Payments";
import Tools from "./pages/Tools";
import BareActs from "./pages/BareActs";
import StampValuesAdmin from "./pages/StampValuesAdmin";
import LegalTemplates from "./pages/LegalTemplates";
import Advocates from "./pages/Advocates";
import Notifications from "./pages/Notifications";
import Unauthorized from "./pages/Unauthorized";
import NotFound from "./pages/NotFound";
import AIChat from "./pages/AIChat";

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
  <QueryClientProvider client={queryClient}>
    <AuthProvider>
      <TooltipProvider>
        <Toaster />
        <Sonner />
        <BrowserRouter>
          <Routes>
            <Route path="/auth" element={<AuthRoute />} />
            <Route path="/" element={<ProtectedRoute><Dashboard /></ProtectedRoute>} />
            <Route path="/clients" element={<ProtectedRoute><Clients /></ProtectedRoute>} />
            <Route path="/cases" element={<ProtectedRoute><Cases /></ProtectedRoute>} />
            <Route path="/cases/:id" element={<ProtectedRoute><CaseDetail /></ProtectedRoute>} />
            <Route path="/efiling" element={<ProtectedRoute><EFiling /></ProtectedRoute>} />
            <Route path="/hearings" element={<ProtectedRoute><Hearings /></ProtectedRoute>} />
            <Route path="/certified-copies" element={<ProtectedRoute><CertifiedCopies /></ProtectedRoute>} />
            <Route path="/payments" element={<ProtectedRoute><Payments /></ProtectedRoute>} />
            <Route path="/bare-acts" element={<ProtectedRoute><BareActs /></ProtectedRoute>} />
            <Route path="/stamp-values" element={<ProtectedRoute><StampValuesAdmin /></ProtectedRoute>} />
            <Route path="/legal-templates" element={<ProtectedRoute><LegalTemplates /></ProtectedRoute>} />
            <Route path="/advocates" element={<ProtectedRoute><Advocates /></ProtectedRoute>} />
            <Route path="/tools" element={<ProtectedRoute><Tools /></ProtectedRoute>} />
            <Route path="/ai-chat" element={<ProtectedRoute><AIChat /></ProtectedRoute>} />
            <Route path="/notifications" element={<ProtectedRoute><Notifications /></ProtectedRoute>} />
            <Route path="/unauthorized" element={<Unauthorized />} />
            <Route path="*" element={<NotFound />} />
          </Routes>
        </BrowserRouter>
      </TooltipProvider>
    </AuthProvider>
  </QueryClientProvider>
);

export default App;
