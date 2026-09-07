import { useMemo, useState, type ReactNode } from "react";
import { ArrowDown, ArrowUp, ChevronsUpDown } from "lucide-react";
import { cn } from "@/lib/utils";
import { EmptyState, ErrorState, TableSkeleton } from "@/components/states";

export interface Column<T> {
  /** Stable key. Also the sort key. */
  key: string;
  header: string;
  /** Cell content. Defaults to the raw value at `key`. */
  render?: (row: T) => ReactNode;
  /** Return a comparable for sorting. Omit to make the column unsortable. */
  sortValue?: (row: T) => string | number | null | undefined;
  align?: "left" | "right";
  /** Extra classes on both the header cell and body cells. */
  className?: string;
  /**
   * Marks the column that titles the row when collapsed to a card on
   * narrow screens. Exactly one column should set this.
   */
  primary?: boolean;
  /** Hide this column in the card layout — for redundant or noisy fields. */
  hideOnCard?: boolean;
}

interface DataTableProps<T> {
  data: T[] | undefined;
  columns: Column<T>[];
  rowKey: (row: T) => string;
  isLoading?: boolean;
  error?: unknown;
  onRetry?: () => void;
  onRowClick?: (row: T) => void;
  empty?: { title: string; description?: string; action?: ReactNode };
  className?: string;
}

type SortState = { key: string; dir: "asc" | "desc" } | null;

/**
 * One responsive table for every list page.
 *
 * The list pages previously rendered two entirely separate trees — a
 * `hidden md:block` table and an `md:hidden` stack of cards — which meant
 * every column change had to be made twice, and the desktop half was the one
 * that got neglected. This renders a table on wide screens and collapses the
 * same column definitions into cards on narrow ones.
 */
export function DataTable<T>({
  data,
  columns,
  rowKey,
  isLoading,
  error,
  onRetry,
  onRowClick,
  empty,
  className,
}: DataTableProps<T>) {
  const [sort, setSort] = useState<SortState>(null);

  const sorted = useMemo(() => {
    if (!data) return [];
    if (!sort) return data;

    const column = columns.find((c) => c.key === sort.key);
    if (!column?.sortValue) return data;

    // Copy first: Array.prototype.sort mutates, and `data` is query cache.
    return [...data].sort((a, b) => {
      const av = column.sortValue!(a);
      const bv = column.sortValue!(b);

      // Missing values sort last regardless of direction, so a blank column
      // never pushes real rows off the top.
      if (av == null && bv == null) return 0;
      if (av == null) return 1;
      if (bv == null) return -1;

      const result =
        typeof av === "number" && typeof bv === "number"
          ? av - bv
          : String(av).localeCompare(String(bv), undefined, { numeric: true });

      return sort.dir === "asc" ? result : -result;
    });
  }, [data, sort, columns]);

  const toggleSort = (key: string) => {
    setSort((current) =>
      current?.key !== key
        ? { key, dir: "asc" }
        : current.dir === "asc"
          ? { key, dir: "desc" }
          : null,
    );
  };

  if (error) return <ErrorState error={error} onRetry={onRetry} />;

  if (isLoading) {
    return (
      <div className={cn("overflow-hidden rounded-xl border border-border bg-card", className)}>
        <TableSkeleton columns={columns.length} />
      </div>
    );
  }

  if (!sorted.length) {
    return (
      <EmptyState
        title={empty?.title ?? "Nothing here yet"}
        description={empty?.description}
        action={empty?.action}
      />
    );
  }

  const primaryColumn = columns.find((c) => c.primary) ?? columns[0];

  return (
    <div className={className}>
      {/* ── Table: wide screens ─────────────────────────────── */}
      <div className="hidden overflow-hidden rounded-xl border border-border bg-card shadow-xs md:block">
        <div className="overflow-x-auto">
          <table className="w-full caption-bottom">
            <thead className="sticky top-0 z-10 bg-muted/60 backdrop-blur-sm">
              <tr className="border-b border-border">
                {columns.map((column) => {
                  const isSorted = sort?.key === column.key;
                  const SortIcon = !isSorted
                    ? ChevronsUpDown
                    : sort.dir === "asc"
                      ? ArrowUp
                      : ArrowDown;

                  return (
                    <th
                      key={column.key}
                      scope="col"
                      aria-sort={
                        isSorted ? (sort.dir === "asc" ? "ascending" : "descending") : undefined
                      }
                      className={cn(
                        "px-4 py-2.5 text-2xs font-semibold uppercase tracking-wider text-muted-foreground",
                        column.align === "right" ? "text-right" : "text-left",
                        column.className,
                      )}
                    >
                      {column.sortValue ? (
                        <button
                          type="button"
                          onClick={() => toggleSort(column.key)}
                          className={cn(
                            "inline-flex items-center gap-1.5 rounded transition-colors hover:text-foreground",
                            column.align === "right" && "flex-row-reverse",
                            isSorted && "text-foreground",
                          )}
                        >
                          {column.header}
                          <SortIcon className="h-3 w-3 opacity-60" />
                        </button>
                      ) : (
                        column.header
                      )}
                    </th>
                  );
                })}
              </tr>
            </thead>

            <tbody className="divide-y divide-border">
              {sorted.map((row) => (
                <tr
                  key={rowKey(row)}
                  onClick={onRowClick ? () => onRowClick(row) : undefined}
                  className={cn(
                    "transition-colors",
                    onRowClick && "cursor-pointer hover:bg-muted/50",
                  )}
                >
                  {columns.map((column) => (
                    <td
                      key={column.key}
                      className={cn(
                        "px-4 py-3 text-sm text-foreground",
                        column.align === "right" && "text-right",
                        column.className,
                      )}
                    >
                      {column.render
                        ? column.render(row)
                        : String((row as Record<string, unknown>)[column.key] ?? "—")}
                    </td>
                  ))}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* ── Cards: narrow screens ───────────────────────────── */}
      <div className="space-y-2.5 md:hidden">
        {sorted.map((row) => (
          <div
            key={rowKey(row)}
            onClick={onRowClick ? () => onRowClick(row) : undefined}
            className={cn(
              "rounded-xl border border-border bg-card p-4 shadow-xs transition-colors",
              onRowClick && "cursor-pointer active:bg-muted/50",
            )}
          >
            <div className="mb-2.5 font-medium text-foreground">
              {primaryColumn.render
                ? primaryColumn.render(row)
                : String((row as Record<string, unknown>)[primaryColumn.key] ?? "—")}
            </div>

            <dl className="grid grid-cols-2 gap-x-4 gap-y-2">
              {columns
                .filter((c) => c !== primaryColumn && !c.hideOnCard)
                .map((column) => (
                  <div key={column.key} className="min-w-0">
                    <dt className="text-2xs uppercase tracking-wider text-muted-foreground">
                      {column.header}
                    </dt>
                    <dd className="mt-0.5 truncate text-sm text-foreground">
                      {column.render
                        ? column.render(row)
                        : String((row as Record<string, unknown>)[column.key] ?? "—")}
                    </dd>
                  </div>
                ))}
            </dl>
          </div>
        ))}
      </div>
    </div>
  );
}
