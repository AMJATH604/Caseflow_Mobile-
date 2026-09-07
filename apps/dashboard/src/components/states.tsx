import type { ReactNode } from "react";
import type { LucideIcon } from "lucide-react";
import { AlertTriangle, Inbox, RefreshCw } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";
import { cn } from "@/lib/utils";

/**
 * Shared empty / error / loading states.
 *
 * Pages previously rendered `<p>Loading...</p>` and `<p>No cases yet.</p>`
 * as bare text, and `ui/skeleton.tsx` shipped unused. These give every list
 * the same three states, so a page never looks broken while it is merely
 * waiting or genuinely empty.
 */

interface EmptyStateProps {
  icon?: LucideIcon;
  title: string;
  /** One line on what this list holds and how it gets filled. */
  description?: string;
  action?: ReactNode;
  className?: string;
}

export function EmptyState({
  icon: Icon = Inbox,
  title,
  description,
  action,
  className,
}: EmptyStateProps) {
  return (
    <div
      className={cn(
        "flex flex-col items-center justify-center rounded-xl border border-dashed border-border px-6 py-14 text-center",
        className,
      )}
    >
      <div className="mb-4 flex h-11 w-11 items-center justify-center rounded-full bg-muted">
        <Icon className="h-5 w-5 text-muted-foreground" />
      </div>
      <p className="font-display text-md font-semibold text-foreground">{title}</p>
      {description && (
        <p className="mt-1.5 max-w-sm text-sm text-muted-foreground">{description}</p>
      )}
      {action && <div className="mt-5">{action}</div>}
    </div>
  );
}

interface ErrorStateProps {
  title?: string;
  /** The raw error. Shown as supporting detail, never as the headline —
      a PostgrestException string means nothing to an advocate. */
  error?: unknown;
  onRetry?: () => void;
  className?: string;
}

export function ErrorState({
  title = "Could not load this",
  error,
  onRetry,
  className,
}: ErrorStateProps) {
  const detail =
    error instanceof Error
      ? error.message
      : typeof error === "string"
        ? error
        : undefined;

  return (
    <div
      className={cn(
        "flex flex-col items-center justify-center rounded-xl border border-destructive/25 bg-destructive/5 px-6 py-12 text-center",
        className,
      )}
    >
      <div className="mb-4 flex h-11 w-11 items-center justify-center rounded-full bg-destructive/10">
        <AlertTriangle className="h-5 w-5 text-destructive" />
      </div>
      <p className="font-display text-md font-semibold text-foreground">{title}</p>
      <p className="mt-1.5 max-w-sm text-sm text-muted-foreground">
        Something went wrong fetching this data. Retrying often fixes it.
      </p>
      {detail && (
        <p className="mt-3 max-w-lg break-words font-mono text-2xs text-muted-foreground/80">
          {detail}
        </p>
      )}
      {onRetry && (
        <Button variant="outline" size="sm" className="mt-5 gap-2" onClick={onRetry}>
          <RefreshCw className="h-3.5 w-3.5" />
          Try again
        </Button>
      )}
    </div>
  );
}

/** Row placeholders matching the table's shape, so layout does not jump. */
export function TableSkeleton({
  rows = 6,
  columns = 5,
}: {
  rows?: number;
  columns?: number;
}) {
  return (
    <div className="divide-y divide-border" aria-busy="true" aria-live="polite">
      <span className="sr-only">Loading…</span>
      {Array.from({ length: rows }).map((_, rowIndex) => (
        <div key={rowIndex} className="flex items-center gap-4 px-4 py-3.5">
          {Array.from({ length: columns }).map((_, colIndex) => (
            <Skeleton
              key={colIndex}
              className={cn(
                "h-4",
                colIndex === 0 ? "w-[22%]" : colIndex === columns - 1 ? "w-[10%]" : "w-[15%]",
              )}
            />
          ))}
        </div>
      ))}
    </div>
  );
}

/** Placeholder for a KPI row. */
export function StatSkeleton({ count = 4 }: { count?: number }) {
  return (
    <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4" aria-busy="true">
      {Array.from({ length: count }).map((_, i) => (
        <div key={i} className="rounded-2xl border border-border/50 bg-card p-6">
          <Skeleton className="h-3.5 w-20" />
          <Skeleton className="mt-3 h-8 w-16" />
          <Skeleton className="mt-3 h-3 w-24" />
        </div>
      ))}
    </div>
  );
}
