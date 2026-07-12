import { useState, useCallback, useMemo } from "react";
import { useQuery, useQueryClient, keepPreviousData } from "@tanstack/react-query";
import { useEffect } from "react";
import { supabase } from "@/integrations/supabase/client";

type RealtimeTable = "clients" | "cases" | "hearings" | "efiling_records" | "payments" | "documents" | "tasks" | "certified_copies" | "profiles";

interface PaginatedResult<T> {
  data: T[];
  count: number;
}

interface UsePaginatedQueryOptions<T> {
  queryKey: string[];
  queryFn: (options: { page: number; pageSize: number }) => Promise<PaginatedResult<T>>;
  pageSize?: number;
  table?: RealtimeTable;
}

/**
 * Custom hook for paginated queries with React Query.
 * Supports page-based navigation with total count, smooth transitions
 * via keepPreviousData, and optional Supabase Realtime subscriptions.
 *
 * @example
 * ```tsx
 * const { data, page, totalPages, nextPage, prevPage, isLoading } = usePaginatedQuery({
 *   queryKey: ["cases"],
 *   queryFn: ({ page, pageSize }) => fetchCases({ page, pageSize }),
 *   pageSize: 25,
 *   table: "cases",
 * });
 * ```
 */
export function usePaginatedQuery<T>({
  queryKey,
  queryFn,
  pageSize = 25,
  table,
}: UsePaginatedQueryOptions<T>) {
  const [page, setPage] = useState(1);
  const queryClient = useQueryClient();

  const paginatedQueryKey = useMemo(
    () => [...queryKey, "paginated", page, pageSize],
    [queryKey.join("-"), page, pageSize]
  );

  const { data, isLoading, isPlaceholderData, error } = useQuery<PaginatedResult<T>, Error>({
    queryKey: paginatedQueryKey,
    queryFn: () => queryFn({ page, pageSize }),
    placeholderData: keepPreviousData,
  });

  // Subscribe to Supabase Realtime changes for auto-invalidation
  useEffect(() => {
    if (!table) return;

    const channelName = `paginated-${table}-${queryKey.join("-")}`;
    const channel = supabase
      .channel(channelName)
      .on(
        "postgres_changes",
        { event: "*", schema: "public", table },
        () => {
          // Invalidate all pages for this query
          queryClient.invalidateQueries({
            queryKey: [...queryKey, "paginated"],
          });
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [table, queryKey.join("-")]);

  const totalCount = data?.count ?? 0;
  const totalPages = Math.max(1, Math.ceil(totalCount / pageSize));
  const items = data?.data ?? [];

  const nextPage = useCallback(() => {
    if (page < totalPages) setPage((p) => p + 1);
  }, [page, totalPages]);

  const prevPage = useCallback(() => {
    if (page > 1) setPage((p) => p - 1);
  }, [page]);

  const goToPage = useCallback(
    (p: number) => {
      const clamped = Math.max(1, Math.min(p, totalPages));
      setPage(clamped);
    },
    [totalPages]
  );

  const resetPage = useCallback(() => setPage(1), []);

  return {
    data: items,
    page,
    pageSize,
    totalPages,
    totalCount,
    isLoading,
    isTransitioning: isPlaceholderData,
    error,
    nextPage,
    prevPage,
    goToPage,
    resetPage,
  };
}
