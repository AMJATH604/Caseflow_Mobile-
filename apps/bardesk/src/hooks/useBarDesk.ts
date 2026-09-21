import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { supabase } from '@/lib/supabase';
import type {
  BarAdmin,
  BarAssociation,
  BarMember,
  BarNotice,
  BarFeePayment,
  BarEvent,
  DashboardStats,
} from '@/types/bardesk.types';

// ─── Auth & Association ──────────────────────────────

/**
 * The signed-in office-bearer and the association they run.
 *
 * Columns are listed rather than selected with `*`. `bar_associations` is
 * locked to a column GRANT list so that `invite_code` cannot be read off the
 * table — joining goes through join_bar_association() — and a `*` includes
 * that column, so PostgREST refused the whole query. The error was then
 * discarded, `admin` came back null, and every page fell back to an empty
 * association id, which reached Postgres as `invalid input syntax for type
 * uuid: ""` on the next write.
 */
export function useCurrentAdmin() {
  return useQuery({
    queryKey: ['current-admin'],
    queryFn: async () => {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) throw new Error('Not authenticated');

      const { data: admin, error } = await supabase
        .from('bar_admins')
        .select(
          'id, association_id, user_id, role, created_at, ' +
            'bar_associations(id, name, district, court, address, logo_url, ' +
            'annual_fee, subscription_plan, subscription_expires_at, ' +
            'president_name, secretary_name, treasurer_name, contact_phone, ' +
            'contact_email, junior_stipend_floor, created_at, updated_at)',
        )
        .eq('user_id', user.id)
        .maybeSingle();

      if (error) throw asError(error);
      if (!admin) {
        throw new Error(
          'This account is not registered as an association office-bearer.',
        );
      }
      // Cast rather than infer: the explicit column list is too long for
      // PostgREST's generic to resolve, and it widens to GenericStringError.
      return admin as unknown as BarAdmin;
    },
  });
}

export function useAssociation(id: string) {
  return useQuery({
    queryKey: ['association', id],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('bar_associations')
        .select('id, name, district, court, address, logo_url, annual_fee, subscription_plan, subscription_expires_at, created_at, updated_at')
        .eq('id', id)
        .single();
      if (error) throw asError(error);
      // invite_code is not selectable directly; association admins read it
      // through a server function. Non-admins simply get no code.
      const { data: inviteCode } = await supabase.rpc('get_association_invite_code', {
        p_association_id: id,
      });
      return { ...data, invite_code: inviteCode ?? '' } as BarAssociation;
    },
    enabled: !!id,
  });
}

// ─── Members ─────────────────────────────────────────

export function useMembers(associationId: string) {
  return useQuery({
    queryKey: ['members', associationId],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('bar_members')
        .select('*')
        .eq('association_id', associationId)
        .order('name');
      if (error) throw asError(error);
      return data as BarMember[];
    },
    enabled: !!associationId,
  });
}

/**
 * Turns a Supabase error into a real `Error`.
 *
 * PostgrestError is a plain object, not an Error instance, so every
 * `err instanceof Error ? err.message : "Please try again."` in the pages
 * fell through to the fallback — the actual reason a write failed was
 * discarded before anyone could read it. Keeping the code and hint makes
 * the toast say what went wrong instead of "please try again".
 */
function asError(error: {
  message?: string;
  details?: string | null;
  hint?: string | null;
  code?: string;
}): Error {
  const parts = [error.message, error.details, error.hint].filter(Boolean);
  const err = new Error(parts.join(' — ') || 'The database rejected this.');
  (err as Error & { code?: string }).code = error.code;
  return err;
}

/** Optional text columns that must be null when blank, never "". */
const NULLABLE_MEMBER_FIELDS = [
  'enrollment_number',
  'email',
  'welfare_fund_number',
  'id_card_number',
  'address',
  'blood_group',
  'notes',
] as const;

/**
 * Turns "" into null on the optional columns.
 *
 * `bar_members` carries a unique index on (association_id,
 * enrollment_number), and the add form defaults that field to an empty
 * string rather than null. Postgres treats two nulls as distinct but two
 * empty strings as equal, so the first member added without an enrolment
 * number stored "" and every one after that failed on a duplicate key —
 * reported in the UI as "Could not add member", which says nothing about
 * enrolment numbers.
 */
function normaliseMember(member: Partial<BarMember>): Partial<BarMember> {
  const out: Record<string, unknown> = { ...member };
  for (const field of NULLABLE_MEMBER_FIELDS) {
    const value = out[field];
    if (typeof value === 'string' && value.trim() === '') out[field] = null;
  }
  return out as Partial<BarMember>;
}

export function useAddMember(associationId: string) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (member: Partial<BarMember>) => {
      const { data, error } = await supabase
        .from('bar_members')
        .insert({ ...normaliseMember(member), association_id: associationId })
        .select()
        .single();
      if (error) {
        // 23505 on that index means the enrolment number is already on the
        // roll. The raw Postgres text names an index, not a person.
        if (error.code === '23505' && error.message.includes('enrollment_number')) {
          throw new Error(
            'That enrolment number is already on the roll for this association.',
          );
        }
        throw asError(error);
      }
      return data;
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ['members', associationId] }),
  });
}

export function useUpdateMember() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async ({ id, ...updates }: Partial<BarMember> & { id: string }) => {
      const { error } = await supabase
        .from('bar_members')
        // Same normalisation as the insert: clearing an enrolment number in
        // the edit form would otherwise store "" and collide with the next
        // member cleared the same way.
        .update({ ...normaliseMember(updates), updated_at: new Date().toISOString() })
        .eq('id', id);
      if (error) {
        if (error.code === '23505' && error.message.includes('enrollment_number')) {
          throw new Error(
            'That enrolment number is already on the roll for this association.',
          );
        }
        throw asError(error);
      }
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ['members'] }),
  });
}

// ─── Notices ─────────────────────────────────────────

export function useNotices(associationId: string) {
  return useQuery({
    queryKey: ['notices', associationId],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('bar_notices')
        .select('*')
        .eq('association_id', associationId)
        .order('is_pinned', { ascending: false })
        .order('published_at', { ascending: false });
      if (error) throw asError(error);
      return data as BarNotice[];
    },
    enabled: !!associationId,
  });
}

export function useCreateNotice(associationId: string) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (notice: Partial<BarNotice>) => {
      const { data: { user } } = await supabase.auth.getUser();
      const { data, error } = await supabase
        .from('bar_notices')
        .insert({
          ...notice,
          association_id: associationId,
          published_by: user?.id,
        })
        .select()
        .single();
      if (error) throw asError(error);
      return data;
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ['notices', associationId] }),
  });
}

export function useDeleteNotice() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (id: string) => {
      const { error } = await supabase.from('bar_notices').delete().eq('id', id);
      if (error) throw asError(error);
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ['notices'] }),
  });
}

// ─── Fee Payments ────────────────────────────────────

export function useFeePayments(associationId: string) {
  return useQuery({
    queryKey: ['fee-payments', associationId],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('bar_fee_payments')
        .select('*, member:member_id(name, enrollment_number, mobile)')
        .eq('association_id', associationId)
        .order('created_at', { ascending: false });
      if (error) throw asError(error);
      return data as (BarFeePayment & { member: Pick<BarMember, 'name' | 'enrollment_number' | 'mobile'> })[];
    },
    enabled: !!associationId,
  });
}

export function useFeeStats(associationId: string) {
  const currentYear = new Date().getFullYear();
  return useQuery({
    queryKey: ['fee-stats', associationId, currentYear],
    queryFn: async () => {
      const { data: paid } = await supabase
        .from('bar_fee_payments')
        .select('amount')
        .eq('association_id', associationId)
        .eq('fee_year', currentYear)
        .eq('status', 'paid');

      const { data: members } = await supabase
        .from('bar_members')
        .select('id')
        .eq('association_id', associationId)
        .eq('status', 'active');

      const { data: assoc } = await supabase
        .from('bar_associations')
        .select('annual_fee')
        .eq('id', associationId)
        .single();

      const totalCollected = (paid || []).reduce((s, p) => s + p.amount, 0);
      const totalMembers = (members || []).length;
      const annualFee = assoc?.annual_fee || 500;
      const totalExpected = totalMembers * annualFee;
      const paidCount = (paid || []).length;

      return {
        totalCollected,
        totalExpected,
        totalMembers,
        paidCount,
        pendingCount: totalMembers - paidCount,
        collectionRate: totalMembers > 0 ? (paidCount / totalMembers) * 100 : 0,
      };
    },
    enabled: !!associationId,
  });
}

// ─── Events ──────────────────────────────────────────

export function useEvents(associationId: string) {
  return useQuery({
    queryKey: ['events', associationId],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('bar_events')
        .select('*')
        .eq('association_id', associationId)
        .order('event_date', { ascending: true });
      if (error) throw asError(error);
      return data as BarEvent[];
    },
    enabled: !!associationId,
  });
}

export function useCreateEvent(associationId: string) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (event: Partial<BarEvent>) => {
      const { data: { user } } = await supabase.auth.getUser();
      const { data, error } = await supabase
        .from('bar_events')
        .insert({ ...event, association_id: associationId, created_by: user?.id })
        .select()
        .single();
      if (error) throw asError(error);
      return data;
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ['events', associationId] }),
  });
}

export function useDeleteEvent() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (id: string) => {
      const { error } = await supabase.from('bar_events').delete().eq('id', id);
      if (error) throw asError(error);
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ['events'] }),
  });
}

// ─── Dashboard Stats ─────────────────────────────────
// Counts a secretary is actually asked for at a general body meeting:
// how many on the roll, how many about to lapse, how much collected, how
// many welfare claims are stuck, and how many stamps are left in the
// drawer. Membership expiry drives the first two — the lapse watch is the
// reason the panel exists.

export function useDashboardStats(associationId: string) {
  return useQuery({
    queryKey: ['stats', associationId],
    queryFn: async (): Promise<DashboardStats> => {
      const currentYear = new Date().getFullYear();
      const today = new Date().toISOString().slice(0, 10);
      const in60 = new Date(Date.now() + 60 * 86_400_000).toISOString().slice(0, 10);

      const [members, payments, claims, stamps, events] = await Promise.all([
        supabase
          .from('bar_members')
          .select('id, status, member_class, is_caseflow_user, membership_expires_on, is_deceased')
          .eq('association_id', associationId),
        supabase
          .from('bar_fee_payments')
          .select('amount')
          .eq('association_id', associationId)
          .eq('fee_year', currentYear)
          .eq('status', 'paid'),
        supabase
          .from('bar_welfare_claims')
          .select('id')
          .eq('association_id', associationId)
          .in('status', ['submitted', 'defect', 'resubmitted']),
        supabase
          .from('bar_welfare_stamps')
          .select('txn_type, quantity')
          .eq('association_id', associationId),
        supabase
          .from('bar_events')
          .select('id')
          .eq('association_id', associationId)
          .gte('event_date', today),
      ]);

      const rows = members.data ?? [];
      const living = rows.filter((m) => !m.is_deceased);
      const advocates = living.filter((m) => m.member_class !== 'clerk');

      const collected = (payments.data ?? []).reduce((n, p) => n + Number(p.amount), 0);
      const annualFee = 0; // resolved by the Fees page, which knows the tariff

      const balance = (stamps.data ?? []).reduce((n, r) => {
        if (r.txn_type === 'sold') return n - r.quantity;
        return n + r.quantity;
      }, 0);

      return {
        totalMembers: living.length,
        activeMembers: living.filter((m) => m.status === 'active').length,
        clerks: living.filter((m) => m.member_class === 'clerk').length,
        onCaseFlow: living.filter((m) => m.is_caseflow_user).length,
        // Not yet lapsed, but inside the window where a reminder still helps.
        expiringSoon: advocates.filter(
          (m) => m.membership_expires_on && m.membership_expires_on >= today && m.membership_expires_on <= in60,
        ).length,
        lapsed: advocates.filter(
          (m) => m.membership_expires_on && m.membership_expires_on < today,
        ).length,
        feesCollected: collected,
        feesOutstanding: Math.max(0, advocates.length - (payments.data ?? []).length) * annualFee,
        openClaims: (claims.data ?? []).length,
        stampBalance: balance,
        upcomingEvents: (events.data ?? []).length,
      };
    },
    enabled: !!associationId,
  });
}
