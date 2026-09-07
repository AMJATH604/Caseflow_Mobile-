import { LucideIcon, TrendingUp, TrendingDown, Minus } from "lucide-react";
import { cn } from "@/lib/utils";

type Tone = "default" | "accent" | "success" | "warning" | "destructive" | "info";

interface KpiCardProps {
  title: string;
  value: string | number;
  icon: LucideIcon;
  color?: Tone;
  /** Period-over-period change. Positive is not assumed to be good — see `invertDelta`. */
  delta?: number;
  /** Label for what the delta is measured against, e.g. "vs last month". */
  deltaLabel?: string;
  /** Set when a rise is bad (pending dues, defects) so the colour flips. */
  invertDelta?: boolean;
  /** Secondary line under the value. */
  hint?: string;
  className?: string;
}

const toneMap: Record<Tone, string> = {
  default: "bg-primary/10 text-primary",
  accent: "bg-accent/10 text-accent",
  success: "bg-success/10 text-success",
  warning: "bg-warning/10 text-warning",
  destructive: "bg-destructive/10 text-destructive",
  info: "bg-info/10 text-info",
};

export function KpiCard({
  title,
  value,
  icon: Icon,
  color = "default",
  delta,
  deltaLabel,
  invertDelta = false,
  hint,
  className,
}: KpiCardProps) {
  const hasDelta = typeof delta === "number" && Number.isFinite(delta);
  const rising = hasDelta && delta > 0;
  const flat = hasDelta && delta === 0;
  const good = invertDelta ? !rising : rising;

  const DeltaIcon = flat ? Minus : rising ? TrendingUp : TrendingDown;
  const deltaTone = flat
    ? "text-muted-foreground"
    : good
      ? "text-success"
      : "text-destructive";

  return (
    <div
      className={cn(
        // Styles are inline rather than using the .kpi-card utility so this
        // component can be shared between apps without carrying a CSS
        // dependency along with it.
        "rounded-2xl border border-border/50 bg-card p-6 shadow-sm transition-all duration-300",
        "hover:-translate-y-0.5 hover:border-accent/40 hover:shadow-lg",
        className,
      )}
    >
      <div className="flex items-start justify-between gap-3">
        <div className="min-w-0">
          <p className="truncate text-sm text-muted-foreground">{title}</p>

          <p
            data-numeric
            className="mt-1 font-display text-3xl font-semibold tracking-tight text-foreground"
          >
            {value}
          </p>

          {(hasDelta || hint) && (
            <div className="mt-2 flex flex-wrap items-center gap-x-2 gap-y-1">
              {hasDelta && (
                <span
                  data-numeric
                  className={cn(
                    "inline-flex items-center gap-1 text-xs font-medium",
                    deltaTone,
                  )}
                >
                  <DeltaIcon className="h-3.5 w-3.5" />
                  {rising ? "+" : ""}
                  {delta}%
                </span>
              )}
              {deltaLabel && (
                <span className="text-xs text-muted-foreground">{deltaLabel}</span>
              )}
              {hint && !deltaLabel && (
                <span className="text-xs text-muted-foreground">{hint}</span>
              )}
            </div>
          )}
        </div>

        <div
          className={cn(
            "flex h-11 w-11 shrink-0 items-center justify-center rounded-lg",
            toneMap[color],
          )}
        >
          <Icon className="h-5 w-5" />
        </div>
      </div>
    </div>
  );
}
