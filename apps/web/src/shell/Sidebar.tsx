import { NavLink } from "react-router-dom";
import { useTranslation } from "react-i18next";
import { PanelLeftClose, PanelLeftOpen } from "lucide-react";
import { Tooltip, TooltipContent, TooltipTrigger } from "@/components/ui/tooltip";
import { ScrollArea } from "@/components/ui/scroll-area";
import { Logo } from "@/components/Logo";
import { useAuth } from "@/auth/AuthProvider";
import { cn } from "@/lib/utils";
import { BUILT_PHASE, NAV, visibleTo, type NavItem } from "./nav";
import { UserMenu } from "./UserMenu";

interface Props {
  collapsed: boolean;
  onToggle?: () => void;
  onNavigate?: () => void;
  onShowShortcuts: () => void;
}

/**
 * The navigation rail. Grouped by how an advocate's day divides — practice,
 * office, toolkit, team, bar — and collapsible to icons for more room on a
 * laptop. Items not built yet stay visible, marked "soon", so the whole
 * product is discoverable from the first release.
 */
export function Sidebar({ collapsed, onToggle, onNavigate, onShowShortcuts }: Props) {
  const { t } = useTranslation();
  const { role } = useAuth();

  return (
    <div className="flex h-full flex-col bg-sidebar text-sidebar-foreground">
      <div className={cn("flex h-14 shrink-0 items-center px-3", collapsed ? "justify-center" : "justify-between")}>
        <Logo compact={collapsed} />
        {onToggle && !collapsed ? (
          <button
            onClick={onToggle}
            aria-label={t("shell.collapse")}
            className="rounded-md p-1.5 text-sidebar-foreground hover:bg-sidebar-accent hover:text-sidebar-accent-foreground"
          >
            <PanelLeftClose className="h-4 w-4" />
          </button>
        ) : null}
      </div>

      <ScrollArea className="flex-1 px-2">
        <nav className="space-y-5 pb-4 pt-2">
          {NAV.map((group) => {
            const items = group.items.filter(visibleTo(role));
            if (!items.length) return null;
            return (
              <div key={group.id}>
                {collapsed ? (
                  <div className="mx-auto mb-1 h-px w-5 bg-sidebar-border" />
                ) : (
                  <div className="mb-1 px-2 text-2xs font-semibold uppercase tracking-[0.08em] text-sidebar-foreground/70">
                    {t(group.label)}
                  </div>
                )}
                <ul className="space-y-0.5">
                  {items.map((item) => (
                    <li key={item.id}>
                      <SidebarLink item={item} collapsed={collapsed} onNavigate={onNavigate} />
                    </li>
                  ))}
                </ul>
              </div>
            );
          })}
        </nav>
      </ScrollArea>

      <div className="shrink-0 border-t border-sidebar-border p-2">
        {onToggle && collapsed ? (
          <button
            onClick={onToggle}
            aria-label={t("shell.expand")}
            className="mb-1 flex w-full justify-center rounded-md p-2 text-sidebar-foreground hover:bg-sidebar-accent hover:text-sidebar-accent-foreground"
          >
            <PanelLeftOpen className="h-4 w-4" />
          </button>
        ) : null}
        <UserMenu collapsed={collapsed} onShowShortcuts={onShowShortcuts} />
      </div>
    </div>
  );
}

function SidebarLink({ item, collapsed, onNavigate }: { item: NavItem; collapsed: boolean; onNavigate?: () => void }) {
  const { t } = useTranslation();
  const soon = item.phase > BUILT_PHASE;
  const link = (
    <NavLink
      to={item.path}
      end={item.path === "/"}
      onClick={onNavigate}
      className={({ isActive }) =>
        cn(
          "group flex h-8 items-center gap-2.5 rounded-md px-2 text-sm transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-sidebar-ring",
          collapsed && "justify-center px-0",
          isActive
            ? "bg-sidebar-accent font-medium text-sidebar-accent-foreground"
            : "text-sidebar-foreground hover:bg-sidebar-accent/70 hover:text-sidebar-accent-foreground",
        )
      }
    >
      {({ isActive }) => (
        <>
          <item.icon className={cn("h-4 w-4 shrink-0", isActive ? "text-sidebar-primary" : "")} />
          {collapsed ? null : (
            <>
              <span className="truncate">{t(item.label)}</span>
              {/* A quiet dot, not "Phase 4": in Tamil the phase label is long
                  enough to be clipped to a stray mark at the rail's edge, and
                  a column of phase numbers makes the app read as a roadmap.
                  The phase is in the hover title and on the page itself. */}
              {soon ? (
                <span
                  title={`${t("soon.title")} · ${t("soon.phase", { n: item.phase })}`}
                  className="ml-auto h-1.5 w-1.5 shrink-0 rounded-full bg-sidebar-foreground/30"
                />
              ) : null}
            </>
          )}
        </>
      )}
    </NavLink>
  );
  if (!collapsed) return link;
  return (
    <Tooltip delayDuration={0}>
      <TooltipTrigger asChild>{link}</TooltipTrigger>
      <TooltipContent side="right">{t(item.label)}</TooltipContent>
    </Tooltip>
  );
}
