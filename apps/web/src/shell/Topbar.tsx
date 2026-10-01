import { Link, useLocation } from "react-router-dom";
import { useTranslation } from "react-i18next";
import { Bell, Menu, Search } from "lucide-react";
import { Button } from "@/components/ui/button";
import { ALL_ITEMS } from "./nav";
import { LanguageToggle } from "./LanguageToggle";
import { modKey } from "./useHotkeys";

export function Topbar({ onOpenPalette, onOpenMobileNav }: { onOpenPalette: () => void; onOpenMobileNav: () => void }) {
  const { t } = useTranslation();
  const { pathname } = useLocation();
  // The most specific nav entry that owns this path ("/cases/123" → Cases).
  const current = [...ALL_ITEMS]
    .sort((a, b) => b.path.length - a.path.length)
    .find((i) => (i.path === "/" ? pathname === "/" : pathname === i.path || pathname.startsWith(i.path + "/")));

  return (
    <header className="sticky top-0 z-20 flex h-14 shrink-0 items-center gap-3 border-b border-border bg-background/85 px-4 backdrop-blur supports-[backdrop-filter]:bg-background/70 lg:px-6">
      <Button variant="ghost" size="icon" className="lg:hidden" onClick={onOpenMobileNav} aria-label="Menu">
        <Menu className="h-5 w-5" />
      </Button>

      <h1 className="min-w-0 flex-1 truncate font-display text-base font-semibold tracking-tight text-foreground sm:flex-none">
        {current ? t(current.label) : "CaseFlow"}
      </h1>

      {/* On a phone the search is an icon, so the page title keeps its room. */}
      <button
        onClick={onOpenPalette}
        aria-label={t("shell.search")}
        className="flex h-9 shrink-0 items-center gap-2 rounded-lg border border-border bg-muted/40 px-2.5 text-sm text-muted-foreground shadow-xs transition-colors hover:bg-muted focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring sm:ml-auto sm:w-full sm:max-w-sm sm:px-3"
      >
        <Search className="h-4 w-4 shrink-0" />
        <span className="hidden truncate sm:inline">{t("shell.search")}</span>
        <kbd className="ml-auto hidden rounded border border-border bg-card px-1.5 py-0.5 font-sans text-2xs font-medium sm:inline">
          {modKey} K
        </kbd>
      </button>

      <div className="flex items-center gap-1.5">
        <Button variant="ghost" size="icon" asChild aria-label={t("nav.notifications")}>
          <Link to="/notifications">
            <Bell className="h-[18px] w-[18px]" />
          </Link>
        </Button>
        <LanguageToggle className="hidden md:inline-flex" />
      </div>
    </header>
  );
}
