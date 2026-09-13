import { ReactNode } from "react";
import { SidebarProvider, SidebarTrigger } from "@/components/ui/sidebar";
import { AppSidebar } from "@/components/AppSidebar";
import { GlobalSearch } from "@/components/GlobalSearch";
import { ThemeToggle } from "@/components/ThemeToggle";
import { UserMenu } from "@/components/UserMenu";
import { MobileBottomNav } from "./MobileBottomNav";
import { QuickActionFAB } from "./QuickActionFAB";
import { useLocation } from "react-router-dom";

export function DashboardLayout({ children }: { children: ReactNode }) {
  const location = useLocation();

  // Longest-prefix wins. Only the routes this console still serves — the
  // advocate-facing entries were removed along with their pages.
  const PAGE_TITLES: ReadonlyArray<[string, string]> = [
    ["/legal-templates", "Legal Templates"],
    ["/stamp-values", "Stamp Values"],
    ["/users", "Users"],
    ["/bare-acts", "Bare Acts"],
  ];

  const getPageTitle = () => {
    const path = location.pathname;
    if (path === "/") return "Overview";
    return PAGE_TITLES.find(([prefix]) => path.startsWith(prefix))?.[1] ?? "CaseFlow";
  };

  return (
    <SidebarProvider>
      <div className="min-h-screen flex w-full bg-background pb-16 md:pb-0">
        <AppSidebar />
        <main className="flex-1 flex flex-col min-w-0">
          {/* Mobile Header — Material You inspired */}
          <header className="md:hidden h-14 flex items-center px-5 gap-3 sticky top-0 z-40 bg-card/95 backdrop-blur-xl border-b border-border/20 shadow-sm safe-area-top">
            <h1 className="font-display text-lg font-semibold tracking-tight text-foreground">
              {getPageTitle()}
            </h1>
            <div className="ml-auto flex items-center gap-1">
              <GlobalSearch />
              <ThemeToggle />
              <UserMenu />
            </div>
          </header>

          {/* Desktop Header — names the page you are actually on. This
              previously showed one static muted string on every route. */}
          <header className="hidden md:flex h-14 items-center border-b border-border bg-card px-4 gap-3 sticky top-0 z-40">
            <SidebarTrigger />
            <h1 className="font-display text-md font-semibold tracking-tight text-foreground">
              {getPageTitle()}
            </h1>
            <div className="ml-auto flex items-center gap-1">
              <GlobalSearch />
              <div className="mx-1 h-5 w-px bg-border" aria-hidden />
              <ThemeToggle />
              <UserMenu />
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
