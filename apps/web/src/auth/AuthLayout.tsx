import type { ReactNode } from "react";
import { useTranslation } from "react-i18next";
import { LanguageToggle } from "@/shell/LanguageToggle";
import { Logo } from "@/components/Logo";

/**
 * Split layout for every signed-out screen: a brand panel on the left, the
 * form on the right. Below `lg` the panel is dropped and the form stands alone.
 *
 * The panel carries the showreel's motif — one blue line, the life of a case —
 * so the web app, the video and the phone read as one product.
 */
export function AuthLayout({ title, subtitle, children }: { title: string; subtitle?: string; children: ReactNode }) {
  const { t } = useTranslation();
  return (
    <div className="grid min-h-screen bg-background lg:grid-cols-[minmax(0,5fr)_minmax(0,6fr)]">
      {/* `dark` scopes the dark token values to this panel, so it stays a
          dark brand surface in both themes without a single literal colour. */}
      <aside className="dark relative hidden overflow-hidden bg-background p-12 text-foreground lg:flex lg:flex-col">
        <div aria-hidden className="pointer-events-none absolute inset-0">
          <div className="absolute -left-24 top-1/3 h-[420px] w-[420px] rounded-full bg-primary/25 blur-3xl" />
          <div className="absolute bottom-[-120px] right-[-80px] h-[360px] w-[360px] rounded-full bg-primary/15 blur-3xl" />
        </div>
        <Logo className="relative" />
        <div className="relative mt-auto max-w-md space-y-8">
          <div className="h-1 w-24 rounded-full bg-primary" />
          <p className="font-display text-3xl font-semibold leading-tight tracking-tight">
            {t("auth.panel_headline")}
          </p>
          <ul className="space-y-3 text-sm text-muted-foreground">
            <li>{t("auth.panel_1")}</li>
            <li>{t("auth.panel_2")}</li>
            <li>{t("auth.panel_3")}</li>
          </ul>
        </div>
        <p className="relative mt-12 text-2xs uppercase tracking-[0.2em] text-muted-foreground/70">
          {t("auth.panel_footer")}
        </p>
      </aside>

      <main className="flex flex-col">
        <div className="flex items-center justify-between p-6">
          <Logo className="lg:invisible" />
          <LanguageToggle />
        </div>
        <div className="flex flex-1 items-center justify-center px-6 pb-16">
          <div className="w-full max-w-[400px]">
            <h1 className="font-display text-2xl font-semibold tracking-tight text-foreground">{title}</h1>
            {subtitle ? <p className="mt-1.5 text-base text-muted-foreground">{subtitle}</p> : null}
            <div className="mt-8">{children}</div>
          </div>
        </div>
        <p className="px-6 pb-6 text-center text-xs text-muted-foreground">{t("app_version")} · web 0.1</p>
      </main>
    </div>
  );
}
