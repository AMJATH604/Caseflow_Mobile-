import { useEffect, useState } from "react";
import { NavLink, Outlet, useLocation, useNavigate } from "react-router-dom";
import {
  LayoutDashboard,
  Users,
  Receipt,
  Megaphone,
  CalendarDays,
  Settings,
  LogOut,
  Scale,
  Menu,
  X,
  BellRing,
  HeartHandshake,
  Flower2,
  IdCard,
  Briefcase,
  IndianRupee,
} from "lucide-react";
import { supabase } from "@/lib/supabase";
import { cn } from "@/lib/utils";
import { Button } from "@/components/ui/button";
import { ThemeToggle } from "@/components/ThemeToggle";
import { useCurrentAdmin } from "@/hooks/useBarDesk";
import { useRealtimeBar } from "@/hooks/useRealtimeBar";

// Grouped the way a secretary thinks about the work rather than by table:
// who is on the roll, what the association owes them, and what it tells
// them. Elections were removed entirely.
const navGroups = [
  {
    heading: null,
    items: [{ to: "/", icon: LayoutDashboard, label: "Dashboard" }],
  },
  {
    heading: "Roll",
    items: [
      { to: "/members", icon: Users, label: "Members" },
      { to: "/renewals", icon: BellRing, label: "Renewals" },
      { to: "/clerks", icon: Briefcase, label: "Clerks" },
      { to: "/id-cards", icon: IdCard, label: "ID Cards" },
    ],
  },
  {
    heading: "Welfare & money",
    items: [
      { to: "/fees", icon: Receipt, label: "Fees" },
      { to: "/welfare", icon: HeartHandshake, label: "Welfare" },
      { to: "/stipend", icon: IndianRupee, label: "Stipend" },
    ],
  },
  {
    heading: "Communications",
    items: [
      { to: "/notices", icon: Megaphone, label: "Notices" },
      { to: "/condolences", icon: Flower2, label: "Condolences" },
      { to: "/events", icon: CalendarDays, label: "Events" },
    ],
  },
  {
    heading: null,
    items: [{ to: "/settings", icon: Settings, label: "Settings" }],
  },
];

const navItems = navGroups.flatMap((g) => g.items);

export default function Layout() {
  const navigate = useNavigate();
  const location = useLocation();
  const [mobileOpen, setMobileOpen] = useState(false);

  // Subscribes once for every page under the shell, so a write anywhere in
  // BarDesk refreshes every open view — and the same publication drives the
  // mobile app, so advocates see it without pulling to refresh.
  const { data: admin } = useCurrentAdmin();
  useRealtimeBar(admin?.association_id);

  // Close the drawer on navigation, or it stays over the page you just opened.
  useEffect(() => setMobileOpen(false), [location.pathname]);

  const handleSignOut = async () => {
    await supabase.auth.signOut();
    navigate("/login");
  };

  const currentLabel =
    navItems.find((item) =>
      item.to === "/" ? location.pathname === "/" : location.pathname.startsWith(item.to),
    )?.label ?? "BarDesk";

  const sidebar = (
    <>
      <div className="flex items-center gap-3 border-b border-sidebar-border px-5 py-5">
        <div className="flex h-10 w-10 items-center justify-center rounded-xl border border-sidebar-primary/20 bg-sidebar-primary/10">
          <Scale className="h-5 w-5 text-sidebar-primary" />
        </div>
        <div className="min-w-0">
          <p className="font-display text-lg font-semibold tracking-tight text-sidebar-accent-foreground">
            BarDesk
          </p>
          <p className="text-2xs font-semibold uppercase tracking-wider text-sidebar-primary">
            Association Admin
          </p>
        </div>
      </div>

      <nav className="flex-1 overflow-y-auto p-3">
        {navGroups.map((group, gi) => (
          <div key={group.heading ?? `group-${gi}`} className={gi > 0 ? "mt-5" : ""}>
            {group.heading && (
              <p className="px-3 pb-1.5 text-2xs font-semibold uppercase tracking-wider text-sidebar-foreground/40">
                {group.heading}
              </p>
            )}
            <div className="space-y-0.5">
        {group.items.map((item) => (
          <NavLink
            key={item.to}
            to={item.to}
            end={item.to === "/"}
            className={({ isActive }) =>
              cn(
                "flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm transition-colors",
                isActive
                  ? "bg-sidebar-accent font-semibold text-sidebar-accent-foreground"
                  : "text-sidebar-foreground/70 hover:bg-sidebar-accent/60 hover:text-sidebar-accent-foreground",
              )
            }
          >
            {({ isActive }) => (
              <>
                {/* The icon carries the active state too. Previously every
                    icon was gold regardless, so active and inactive rows
                    differed only by a faint background. */}
                <item.icon
                  className={cn(
                    "h-[18px] w-[18px] shrink-0",
                    isActive ? "text-sidebar-primary" : "text-sidebar-foreground/50",
                  )}
                />
                {item.label}
              </>
            )}
          </NavLink>
        ))}
            </div>
          </div>
        ))}
      </nav>

      <div className="border-t border-sidebar-border p-3">
        <button
          onClick={handleSignOut}
          className="flex w-full items-center gap-3 rounded-lg px-3 py-2.5 text-sm text-sidebar-foreground/70 transition-colors hover:bg-destructive/10 hover:text-destructive"
        >
          <LogOut className="h-[18px] w-[18px]" />
          Sign out
        </button>
      </div>
    </>
  );

  return (
    <div className="flex h-screen overflow-hidden bg-background">
      {/* ── Desktop sidebar ─────────────────────────────────── */}
      <aside className="hidden w-64 shrink-0 flex-col border-r border-sidebar-border bg-sidebar md:flex">
        {sidebar}
      </aside>

      {/* ── Mobile drawer ───────────────────────────────────────
          The sidebar was previously hardcoded to 256px at every
          breakpoint with no way to dismiss it, so the app was unusable
          on a phone. */}
      {mobileOpen && (
        <div className="fixed inset-0 z-50 md:hidden">
          <div
            className="absolute inset-0 bg-foreground/40 backdrop-blur-sm"
            onClick={() => setMobileOpen(false)}
            aria-hidden
          />
          <aside className="absolute inset-y-0 left-0 flex w-64 flex-col border-r border-sidebar-border bg-sidebar shadow-lg">
            <button
              onClick={() => setMobileOpen(false)}
              className="absolute right-3 top-5 rounded-md p-1 text-sidebar-foreground/60 hover:text-sidebar-accent-foreground"
              aria-label="Close menu"
            >
              <X className="h-4 w-4" />
            </button>
            {sidebar}
          </aside>
        </div>
      )}

      {/* ── Main ────────────────────────────────────────────── */}
      <div className="flex min-w-0 flex-1 flex-col">
        <header className="sticky top-0 z-40 flex h-14 shrink-0 items-center gap-3 border-b border-border bg-card px-4">
          <Button
            variant="ghost"
            size="icon"
            className="h-8 w-8 md:hidden"
            onClick={() => setMobileOpen(true)}
            aria-label="Open menu"
          >
            <Menu className="h-4 w-4" />
          </Button>

          <h1 className="font-display text-md font-semibold tracking-tight text-foreground">
            {currentLabel}
          </h1>

          <div className="ml-auto flex items-center gap-1">
            <ThemeToggle />
          </div>
        </header>

        <main className="flex-1 overflow-y-auto p-4 md:p-6">
          <div className="mx-auto max-w-7xl">
            <Outlet />
          </div>
        </main>
      </div>
    </div>
  );
}
