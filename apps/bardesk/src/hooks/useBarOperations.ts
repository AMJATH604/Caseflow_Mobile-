import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { supabase } from '@/lib/supabase';
import type {
  BarCondolence,
  BarMember,
  BarStipendDeclaration,
  BarWelfareClaim,
  BarWelfareStamp,
  RenewalRow,
} from '@/types/bardesk.types';

/** Whole days from today until `date`; negative once it has passed. */
export function daysUntil(date: string | null): number | null {
  if (!date) return null;
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const target = new Date(date);
  target.setHours(0, 0, 0, 0);
  return Math.round((target.getTime() - today.getTime()) / 86_400_000);
}

// ─── Renewals ────────────────────────────────────────
// The lapse watch. A welfare claim is refused when the membership had
// lapsed, so knowing who is about to expire is the difference between a
// family receiving the death benefit and not.

export function useRenewals(associationId: string) {
  return useQuery({
    queryKey: ['renewals', associationId],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('bar_members')
        .select('*')
        .eq('association_id', associationId)
        .eq('is_deceased', false)
        .order('membership_expires_on', { nullsFirst: false });
      if (error) throw error;

      return (data as BarMember[])
        .map((m) => ({ ...m, daysRemaining: daysUntil(m.membership_expires_on) }))
        .sort((a, b) => {
          // Members with no expiry recorded sort last — they are a data gap,
          // not an emergency.
          if (a.daysRemaining === null) return 1;
          if (b.daysRemaining === null) return -1;
          return a.daysRemaining - b.daysRemaining;
        }) as RenewalRow[];
    },
    enabled: !!associationId,
  });
}

export function useRenewMember(associationId: string) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async ({ memberId, until }: { memberId: string; until: string }) => {
      const { error } = await supabase
        .from('bar_members')
        .update({
          membership_expires_on: until,
          fee_paid_until: new Date(until).getFullYear() - 1,
          status: 'active',
          updated_at: new Date().toISOString(),
        })
        .eq('id', memberId);
      if (error) throw error;
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['renewals', associationId] });
      qc.invalidateQueries({ queryKey: ['members', associationId] });
    },
  });
}

// ─── Condolences ─────────────────────────────────────

export function useCondolences(associationId: string) {
  return useQuery({
    queryKey: ['condolences', associationId],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('bar_condolences')
        .select('*')
        .eq('association_id', associationId)
        .order('date_of_death', { ascending: false });
      if (error) throw error;
      return data as BarCondolence[];
    },
    enabled: !!associationId,
  });
}

export function usePublishCondolence(associationId: string) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (payload: Partial<BarCondolence>) => {
      const { data: { user } } = await supabase.auth.getUser();
      const { data, error } = await supabase
        .from('bar_condolences')
        .insert({ ...payload, association_id: associationId, published_by: user?.id })
        .select()
        .single();
      if (error) throw error;

      // Marking the member deceased is what stops renewal reminders being
      // sent to someone who has died — the cruellest possible bug.
      if (payload.member_id) {
        await supabase
          .from('bar_members')
          .update({
            is_deceased: true,
            date_of_death: payload.date_of_death,
            status: 'deceased',
            updated_at: new Date().toISOString(),
          })
          .eq('id', payload.member_id);
      }
      return data as BarCondolence;
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['condolences', associationId] });
      qc.invalidateQueries({ queryKey: ['members', associationId] });
      qc.invalidateQueries({ queryKey: ['renewals', associationId] });
    },
  });
}

// ─── Welfare claims ──────────────────────────────────

export function useWelfareClaims(associationId: string) {
  return useQuery({
    queryKey: ['welfare-claims', associationId],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('bar_welfare_claims')
        .select('*, bar_members(id, name, enrollment_number)')
        .eq('association_id', associationId)
        .order('created_at', { ascending: false });
      if (error) throw error;
      return data as BarWelfareClaim[];
    },
    enabled: !!associationId,
  });
}

export function useSaveWelfareClaim(associationId: string) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (claim: Partial<BarWelfareClaim> & { id?: string }) => {
      const body = { ...claim, association_id: associationId, updated_at: new Date().toISOString() };
      if (claim.id) {
        const { error } = await supabase.from('bar_welfare_claims').update(body).eq('id', claim.id);
        if (error) throw error;
      } else {
        const { data: { user } } = await supabase.auth.getUser();
        const { error } = await supabase
          .from('bar_welfare_claims')
          .insert({ ...body, created_by: user?.id });
        if (error) throw error;
      }
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ['welfare-claims', associationId] }),
  });
}

// ─── Welfare stamps ──────────────────────────────────
// Stock in, stock sold. The balance is derived rather than stored so it can
// never drift from the ledger that produced it.

export function useWelfareStamps(associationId: string) {
  return useQuery({
    queryKey: ['welfare-stamps', associationId],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('bar_welfare_stamps')
        .select('*, bar_members(id, name)')
        .eq('association_id', associationId)
        .order('recorded_at', { ascending: false });
      if (error) throw error;
      return data as BarWelfareStamp[];
    },
    enabled: !!associationId,
  });
}

export function stampBalance(rows: BarWelfareStamp[] | undefined): number {
  if (!rows) return 0;
  return rows.reduce((n, r) => {
    if (r.txn_type === 'received') return n + r.quantity;
    if (r.txn_type === 'sold') return n - r.quantity;
    return n + r.quantity; // returned to stock
  }, 0);
}

export function useRecordStamps(associationId: string) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (txn: Partial<BarWelfareStamp>) => {
      const { data: { user } } = await supabase.auth.getUser();
      const { error } = await supabase
        .from('bar_welfare_stamps')
        .insert({ ...txn, association_id: associationId, recorded_by: user?.id });
      if (error) throw error;
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ['welfare-stamps', associationId] }),
  });
}

// ─── Stipend register ────────────────────────────────

export function useStipends(associationId: string) {
  return useQuery({
    queryKey: ['stipends', associationId],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('bar_stipend_declarations')
        .select('*, senior:bar_members!bar_stipend_declarations_senior_member_id_fkey(id, name, enrollment_number)')
        .eq('association_id', associationId)
        .order('effective_from', { ascending: false });
      if (error) throw error;
      return data as BarStipendDeclaration[];
    },
    enabled: !!associationId,
  });
}

export function useSaveStipend(associationId: string) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (row: Partial<BarStipendDeclaration> & { id?: string }) => {
      const body = { ...row, association_id: associationId, updated_at: new Date().toISOString() };
      if (row.id) {
        const { error } = await supabase.from('bar_stipend_declarations').update(body).eq('id', row.id);
        if (error) throw error;
      } else {
        const { data: { user } } = await supabase.auth.getUser();
        const { error } = await supabase
          .from('bar_stipend_declarations')
          .insert({ ...body, declared_by: user?.id });
        if (error) throw error;
      }
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ['stipends', associationId] }),
  });
}

// ─── ID cards ────────────────────────────────────────

export function useIssueIdCard(associationId: string) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async ({
      memberId,
      cardNumber,
      validUntil,
    }: { memberId: string; cardNumber: string; validUntil: string }) => {
      const { error } = await supabase
        .from('bar_members')
        .update({
          id_card_number: cardNumber,
          id_card_issued_on: new Date().toISOString().slice(0, 10),
          id_card_valid_until: validUntil,
          updated_at: new Date().toISOString(),
        })
        .eq('id', memberId);
      if (error) throw error;
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['members', associationId] });
      qc.invalidateQueries({ queryKey: ['id-cards', associationId] });
    },
  });
}

// ─── Clerks ──────────────────────────────────────────

export function useClerks(associationId: string) {
  return useQuery({
    queryKey: ['clerks', associationId],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('bar_members')
        .select('*')
        .eq('association_id', associationId)
        .eq('member_class', 'clerk')
        .order('name');
      if (error) throw error;
      return data as BarMember[];
    },
    enabled: !!associationId,
  });
}
