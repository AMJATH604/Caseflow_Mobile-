import { useEffect } from 'react';
import { useQueryClient } from '@tanstack/react-query';
import { supabase } from '@/lib/supabase';

/** Tables BarDesk both writes and watches. */
const WATCHED = [
  'bar_notices',
  'bar_members',
  'bar_fee_payments',
  'bar_events',
  'bar_condolences',
  'bar_welfare_claims',
  'bar_stipend_declarations',
] as const;

/** Which cached queries a change in each table invalidates. */
const INVALIDATES: Record<string, string[]> = {
  bar_notices: ['notices', 'stats'],
  bar_members: ['members', 'renewals', 'clerks', 'id-cards', 'stats'],
  bar_fee_payments: ['fees', 'stats'],
  bar_events: ['events', 'stats'],
  bar_condolences: ['condolences', 'stats'],
  bar_welfare_claims: ['welfare-claims', 'stats'],
  bar_stipend_declarations: ['stipends', 'stats'],
};

/**
 * Keeps BarDesk live against the same tables the mobile app reads.
 *
 * The panel had no subscriptions at all — the only `subscribe` in the
 * codebase was the auth listener — so a treasurer recording a payment on one
 * machine and a secretary looking at the roll on another saw different
 * numbers until someone reloaded. The phones had the same problem in
 * reverse: a notice published here reached an advocate only when they next
 * pulled to refresh.
 *
 * Postgres changes now invalidate the matching React Query keys, and the
 * mobile app subscribes to the same publication, so a write here reaches
 * both surfaces without anyone refreshing anything.
 */
export function useRealtimeBar(associationId: string | undefined) {
  const qc = useQueryClient();

  useEffect(() => {
    if (!associationId) return;

    const channel = supabase.channel(`bardesk:${associationId}`);

    for (const table of WATCHED) {
      channel.on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table,
          // Scoped server-side: an association only ever hears its own rows.
          filter: `association_id=eq.${associationId}`,
        },
        () => {
          for (const key of INVALIDATES[table] ?? []) {
            qc.invalidateQueries({ queryKey: [key] });
          }
        },
      );
    }

    channel.subscribe();
    return () => {
      supabase.removeChannel(channel);
    };
  }, [associationId, qc]);
}
