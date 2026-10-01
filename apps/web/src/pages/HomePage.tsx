import { Link } from "react-router-dom";
import { useTranslation } from "react-i18next";
import { format } from "date-fns";
import { ta as taLocale } from "date-fns/locale";
import { ArrowUpRight } from "lucide-react";
import { useAuth } from "@/auth/AuthProvider";
import { NAV, visibleTo } from "@/shell/nav";

function greetingKey(d = new Date()) {
  const h = d.getHours();
  return h < 12 ? "home.morning" : h < 17 ? "home.afternoon" : "home.evening";
}

/**
 * Phase 1's home: a greeting and a map of the whole product, grouped exactly
 * like the sidebar. Phase 2 replaces it with the real dashboard — today's
 * hearings, the court diary and the counts.
 */
export function HomePage() {
  const { t, i18n } = useTranslation();
  const { profile, role } = useAuth();
  const today = format(new Date(), "EEEE, d MMMM yyyy", i18n.resolvedLanguage === "ta" ? { locale: taLocale } : undefined);
  const firstName = profile?.full_name?.split(/\s+/)[0] ?? "";

  return (
    <div className="mx-auto max-w-6xl px-6 py-10 lg:px-10">
      <p className="text-sm font-medium text-muted-foreground">{today}</p>
      <h2 className="mt-1 font-display text-3xl font-semibold tracking-tight text-foreground">
        {t(greetingKey())}
        {firstName ? `, ${firstName}` : ""}
      </h2>
      <p className="mt-2 max-w-2xl text-base text-muted-foreground">{t("home.intro")}</p>

      <div className="mt-10 space-y-10">
        {NAV.map((group) => {
          const items = group.items.filter(visibleTo(role));
          if (!items.length) return null;
          return (
            <section key={group.id}>
              <h3 className="mb-3 text-2xs font-semibold uppercase tracking-[0.08em] text-muted-foreground">{t(group.label)}</h3>
              <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
                {items.map((item) => (
                  <Link
                    key={item.id}
                    to={item.path}
                    className="group flex items-start gap-3 rounded-xl border border-border bg-card p-4 shadow-xs transition-all hover:-translate-y-0.5 hover:border-primary/30 hover:shadow-md focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
                  >
                    <span className="grid h-9 w-9 shrink-0 place-items-center rounded-lg bg-accent text-accent-foreground">
                      <item.icon className="h-[18px] w-[18px]" />
                    </span>
                    <span className="min-w-0 flex-1">
                      <span className="flex items-center gap-1 text-sm font-medium text-foreground">
                        {t(item.label)}
                        <ArrowUpRight className="h-3.5 w-3.5 text-muted-foreground opacity-0 transition-opacity group-hover:opacity-100" />
                      </span>
                      <span className="mt-0.5 block text-xs text-muted-foreground">{t("soon.phase", { n: item.phase })}</span>
                    </span>
                  </Link>
                ))}
              </div>
            </section>
          );
        })}
      </div>
    </div>
  );
}
