import { useTranslation } from "react-i18next";
import { Smartphone } from "lucide-react";
import type { NavItem } from "@/shell/nav";

/**
 * Stands in for a screen that has not been built for the web yet. Says what
 * it is, which phase brings it, and that the mobile app has it today — so an
 * advocate who clicks it is told where to go, not shown a dead end.
 */
export function ComingSoonPage({ item }: { item: NavItem }) {
  const { t } = useTranslation();
  return (
    <div className="mx-auto flex max-w-xl flex-col items-center px-6 py-24 text-center">
      <div className="grid h-14 w-14 place-items-center rounded-2xl border border-border bg-card shadow-sm">
        <item.icon className="h-6 w-6 text-primary" />
      </div>
      <h2 className="mt-6 font-display text-2xl font-semibold tracking-tight text-foreground">{t(item.label)}</h2>
      <span className="mt-3 inline-flex items-center rounded-full border border-primary/25 bg-accent px-2.5 py-0.5 text-xs font-medium text-accent-foreground">
        {t("soon.title")} · {t("soon.phase", { n: item.phase })}
      </span>
      <p className="mt-5 flex items-start gap-2 text-base text-muted-foreground">
        <Smartphone className="mt-0.5 h-4 w-4 shrink-0" />
        <span>{t("soon.body")}</span>
      </p>
    </div>
  );
}
