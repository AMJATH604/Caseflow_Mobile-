import { cn } from "@/lib/utils";

/**
 * The CaseFlow mark: a case's timeline with the dot where it stands — the
 * same line-and-dot the showreel is built on. The dot sits ON the line, right
 * of centre; stacked above it, the two shapes read as a person icon.
 * Colours come from tokens only, so it works on any surface, including a
 * `dark`-scoped panel on a light page.
 */
export function Logo({ className, compact = false }: { className?: string; compact?: boolean }) {
  return (
    <div className={cn("flex items-center gap-2.5", className)}>
      <span className="grid h-8 w-8 shrink-0 place-items-center rounded-lg bg-primary text-primary-foreground shadow-sm">
        <svg viewBox="0 0 32 32" className="h-5 w-5" aria-hidden>
          <path d="M6 16h20" stroke="currentColor" strokeWidth="2.6" strokeLinecap="round" opacity="0.55" />
          <path d="M6 16h13" stroke="currentColor" strokeWidth="2.6" strokeLinecap="round" />
          <circle cx="20" cy="16" r="4.4" fill="currentColor" />
        </svg>
      </span>
      {compact ? null : (
        <span className="font-display text-lg font-bold tracking-tight text-foreground">
          Case<span className="text-primary">Flow</span>
        </span>
      )}
    </div>
  );
}
