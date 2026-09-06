import { useEffect } from "react";
import { useQuery, useQueryClient, UseQueryOptions } from "@tanstack/react-query";
import { supabase } from "@/integrations/supabase/client";

type RealtimeTable = "clients" | "cases" | "hearings" | "efiling_records" | "payments" | "documents" | "tasks" | "certified_copies" | "profiles";

interface UseRealtimeQueryOptions<T> extends Omit<UseQueryOptions<T, Error>, "queryKey" | "queryFn"> {
  queryKey: string[];
  queryFn: () => Promise<T>;
  table: RealtimeTable;
}

/**
 * A drop-in replacement for useQuery that also subscribes to
 * Supabase Realtime changes on the specified table.
 * When any INSERT, UPDATE, or DELETE fires, invalidates the query
 * so React Query refetches automatically.
 */
export function useRealtimeQuery<T>({ queryKey, queryFn, table, ...options }: UseRealtimeQueryOptions<T>) {
  const queryClient = useQueryClient();

  useEffect(() => {
    const channelName = `realtime-${table}-${queryKey.join("-")}`;
    const channel = supabase
      .channel(channelName)
      .on(
        "postgres_changes",
        { event: "*", schema: "public", table },
        () => {
          queryClient.invalidateQueries({ queryKey });
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [table, queryKey.join("-")]);

  return useQuery<T, Error>({
    queryKey,
    queryFn,
    ...options,
  });
}
