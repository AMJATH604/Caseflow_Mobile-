import { useTranslation } from "react-i18next";
import { LANGUAGES, setLanguage, type Language } from "@/lib/i18n";
import { cn } from "@/lib/utils";

/** A two-way segmented switch: English | தமிழ். Always visible, one click. */
export function LanguageToggle({ className }: { className?: string }) {
  const { i18n } = useTranslation();
  const current = i18n.resolvedLanguage as Language;
  return (
    <div role="radiogroup" aria-label="Language" className={cn("inline-flex rounded-lg border border-border bg-muted/50 p-0.5", className)}>
      {LANGUAGES.map((l) => (
        <button
          key={l.code}
          type="button"
          role="radio"
          aria-checked={current === l.code}
          onClick={() => setLanguage(l.code)}
          className={cn(
            "rounded-md px-2.5 py-1 text-xs font-medium transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring",
            current === l.code ? "bg-card text-foreground shadow-xs" : "text-muted-foreground hover:text-foreground",
          )}
        >
          {l.label}
        </button>
      ))}
    </div>
  );
}
