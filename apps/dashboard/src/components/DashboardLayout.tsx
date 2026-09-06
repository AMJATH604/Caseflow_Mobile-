import { ReactNode } from "react";
import { SidebarProvider, SidebarTrigger } from "@/components/ui/sidebar";
import { AppSidebar } from "@/components/AppSidebar";
import { GlobalSearch } from "@/components/GlobalSearch";
import { MobileBottomNav } from "./MobileBottomNav";
import { QuickActionFAB } from "./QuickActionFAB";
import { useLocation } from "react-router-dom";

export function DashboardLayout({ children }: { children: ReactNode }) {
  const location = useLocation();

  // Dynamic mobile header title based on route
  const getPageTitle = () => {
    const path = location.pathname;
    if (path === "/") return "CaseFlow";
    if (path.startsWith("/cases")) return "Cases";
    if (path.startsWith("/clients")) return "Clients";
    if (path.startsWith("/hearings")) return "Hearings";
    if (path.startsWith("/efiling")) return "E-Filing";
    if (path.startsWith("/certified-copies")) return "Certified Copies";
    if (path.startsWith("/payments")) return "Payments";
    if (path.startsWith("/tools")) return "Tools";
    if (path.startsWith("/notifications")) return "Updates";
    return "CaseFlow";
  };

  return (
    <SidebarProvider>
      <div className="min-h-screen flex w-full bg-background pb-16 md:pb-0">
        <AppSidebar />
        <main className="flex-1 flex flex-col min-w-0">
          {/* Mobile Header — Material You inspired */}
          <header className="md:hidden h-14 flex items-center px-5 gap-3 sticky top-0 z-40 bg-card/95 backdrop-blur-xl border-b border-border/20 shadow-sm safe-area-top">
            <h1 className="text-lg font-bold text-foreground tracking-tight">{getPageTitle()}</h1>
            <div className="ml-auto flex items-center gap-2">
              <GlobalSearch />
            </div>
          </header>

          {/* Desktop Header */}
          <header className="hidden md:flex h-14 items-center border-b border-border bg-card px-4 gap-4 sticky top-0 z-40">
            <SidebarTrigger />
            <h1 className="text-sm font-medium text-muted-foreground">AI Advocate E-Filing Dashboard</h1>
            <div className="ml-auto flex items-center gap-2">
              <GlobalSearch />
            </div>
          </header>

          <div className="flex-1 p-4 md:p-6 overflow-auto animate-fade-in">
            {children}
          </div>
        </main>

        {/* Mobile Specific Navigation */}
        <QuickActionFAB />
        <MobileBottomNav />
      </div>
    </SidebarProvider>
  );
}
