import { useMemo, useState } from "react";
import { Outlet, useLocation } from "react-router-dom";
import { Sheet, SheetContent } from "@/components/ui/sheet";
import { TooltipProvider } from "@/components/ui/tooltip";
import { cn } from "@/lib/utils";
import { Sidebar } from "./Sidebar";
import { Topbar } from "./Topbar";
import { CommandPalette } from "./CommandPalette";
import { ShortcutsDialog } from "./ShortcutsDialog";
import { useHotkeys } from "./useHotkeys";

const COLLAPSE_KEY = "cf-sidebar-collapsed";
const readCollapsed = () => {
  try {
    return localStorage.getItem(COLLAPSE_KEY) === "1";
  } catch {
    return false;
  }
};

/**
 * The signed-in frame: sidebar + top bar + page. On `lg` and wider the
 * sidebar is a fixed rail; below that it becomes a drawer, so the app stays
 * usable on a tablet at the court.
 */
export function AppShell() {
  const [collapsed, setCollapsed] = useState(readCollapsed);
  const [mobileNav, setMobileNav] = useState(false);
  const [palette, setPalette] = useState(false);
  const [shortcuts, setShortcuts] = useState(false);
  const { pathname } = useLocation();

  const toggle = () =>
    setCollapsed((c) => {
      try {
        localStorage.setItem(COLLAPSE_KEY, c ? "0" : "1");
      } catch {
        /* ignore */
      }
      return !c;
    });

  const keys = useMemo(
    () => ({
      "mod+k": () => setPalette((o) => !o),
      "/": () => setPalette(true),
      "[": toggle,
      "?": () => setShortcuts(true),
    }),
    [], // toggle only uses a functional state update, so it is stable

  );
  useHotkeys(keys);

  return (
    <TooltipProvider>
      <div className="flex h-screen overflow-hidden bg-background">
        <aside
          className={cn(
            "hidden shrink-0 border-r border-sidebar-border transition-[width] duration-200 lg:block",
            collapsed ? "w-[60px]" : "w-[248px]",
          )}
        >
          <Sidebar collapsed={collapsed} onToggle={toggle} onShowShortcuts={() => setShortcuts(true)} />
        </aside>

        <Sheet open={mobileNav} onOpenChange={setMobileNav}>
          <SheetContent side="left" className="w-[272px] border-sidebar-border p-0">
            <Sidebar collapsed={false} onNavigate={() => setMobileNav(false)} onShowShortcuts={() => setShortcuts(true)} />
          </SheetContent>
        </Sheet>

        <div className="flex min-w-0 flex-1 flex-col">
          <Topbar onOpenPalette={() => setPalette(true)} onOpenMobileNav={() => setMobileNav(true)} />
          <main key={pathname} className="flex-1 overflow-y-auto animate-fade-in">
            <Outlet />
          </main>
        </div>

        <CommandPalette open={palette} onOpenChange={setPalette} />
        <ShortcutsDialog open={shortcuts} onOpenChange={setShortcuts} />
      </div>
    </TooltipProvider>
  );
}
