import type { ReactNode } from "react";
import { cn } from "@/lib/utils";

interface PageHeaderProps {
  title: string;
  /** One line on what this page is for. Skip it rather than pad it. */
  description?: string;
  /** Primary and secondary actions, right-aligned on wide screens. */
  actions?: ReactNode;
  /** Optional strip beneath the header — filters, tabs, segmented controls. */
  children?: ReactNode;
  className?: string;
}

/**
 * The single page-title treatment.
 *
 * Pages previously each rolled their own header, and on the list pages the
 * title carried `hidden md:block` — so on a phone the page had no heading at
 * all while the app bar showed one static string on every route.
 */
export function PageHeader({
  title,
  description,
  actions,
  children,
  className,
}: PageHeaderProps) {
  return (
    <div className={cn("mb-6", className)}>
      <div className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
        <div className="min-w-0">
          <h1 className="font-display text-2xl font-semibold tracking-tight text-foreground">
            {title}
          </h1>
          {description && (
            <p className="mt-1 max-w-2xl text-sm text-muted-foreground">{description}</p>
          )}
        </div>

        {actions && (
          <div className="flex shrink-0 items-center gap-2">{actions}</div>
        )}
      </div>

      {children && <div className="mt-4">{children}</div>}
    </div>
  );
}
