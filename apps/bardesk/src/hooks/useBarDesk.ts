import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { supabase } from '@/lib/supabase';
import type {
  BarAssociation,
  BarMember,
  BarNotice,
  BarFeePayment,
  BarElection,
  BarElectionPost,
  BarNomination,
  BarEvent,
  DashboardStats,
  VoteCount,
} from '@/types/bardesk.types';

// ─── Auth & Association ──────────────────────────────

export function useCurrentAdmin() {
  return useQuery({
    queryKey: ['current-admin'],
    queryFn: async () => {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) throw new Error('Not authenticated');

      const { data: admin } = await supabase
        .from('bar_admins')
        .select('*, bar_associations(*)')
        .eq('user_id', user.id)
        .single();

      return admin;
    },
  });
}

export function useAssociation(id: string) {
  return useQuery({
    queryKey: ['association', id],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('bar_associations')
        .select('*')
        .eq('id', id)
        .single();
      if (error) throw error;
      return data as BarAssociation;
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
      if (error) throw error;
      return data as BarMember[];
    },
    enabled: !!associationId,
  });
}

export function useAddMember(associationId: string) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (member: Partial<BarMember>) => {
      const { data, error } = await supabase
        .from('bar_members')
        .insert({ ...member, association_id: associationId })
        .select()
        .single();
      if (error) throw error;
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
        .update(updates)
        .eq('id', id);
      if (error) throw error;
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
      if (error) throw error;
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
      if (error) throw error;
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
      if (error) throw error;
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
      if (error) throw error;
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

// ─── Elections ───────────────────────────────────────

export function useElections(associationId: string) {
  return useQuery({
    queryKey: ['elections', associationId],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('bar_elections')
        .select('*')
        .eq('association_id', associationId)
        .order('created_at', { ascending: false });
      if (error) throw error;
      return data as BarElection[];
    },
    enabled: !!associationId,
  });
}

export function useElectionPosts(electionId: string) {
  return useQuery({
    queryKey: ['election-posts', electionId],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('bar_election_posts')
        .select('*')
        .eq('election_id', electionId)
        .order('created_at');
      if (error) throw error;
      return data as BarElectionPost[];
    },
    enabled: !!electionId,
  });
}

export function useNominations(postId: string) {
  return useQuery({
    queryKey: ['nominations', postId],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('bar_nominations')
        .select('*, nominee:nominee_member_id(name, photo_url), proposer:proposer_member_id(name)')
        .eq('post_id', postId)
        .order('created_at');
      if (error) throw error;
      return data as (BarNomination & { nominee?: { name: string; photo_url?: string }; proposer?: { name: string } })[];
    },
    enabled: !!postId,
  });
}

export function useVoteCounts(postId: string) {
  return useQuery({
    queryKey: ['vote-counts', postId],
    queryFn: async () => {
      const { data, error } = await supabase.rpc('get_vote_counts', { p_post_id: postId });
      if (error) throw error;
      return data as VoteCount[];
    },
    enabled: !!postId,
  });
}

export function useCreateElection(associationId: string) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (election: Partial<BarElection>) => {
      const { data, error } = await supabase
        .from('bar_elections')
        .insert({ ...election, association_id: associationId })
        .select()
        .single();
      if (error) throw error;
      return data;
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ['elections', associationId] }),
  });
}

export function useUpdateElection() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async ({ id, ...updates }: Partial<BarElection> & { id: string }) => {
      const { error } = await supabase
        .from('bar_elections')
        .update(updates)
        .eq('id', id);
      if (error) throw error;
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ['elections'] }),
  });
}

export function useDeleteElection() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (id: string) => {
      const { error } = await supabase.from('bar_elections').delete().eq('id', id);
      if (error) throw error;
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ['elections'] }),
  });
}

export function useCreateElectionPost(electionId: string) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (post: { post_name: string; max_winners?: number }) => {
      const { data, error } = await supabase
        .from('bar_election_posts')
        .insert({ ...post, election_id: electionId })
        .select()
        .single();
      if (error) throw error;
      return data;
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ['election-posts', electionId] }),
  });
}

export function useDeleteElectionPost(electionId: string) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (id: string) => {
      const { error } = await supabase.from('bar_election_posts').delete().eq('id', id);
      if (error) throw error;
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ['election-posts', electionId] }),
  });
}

export function useCreateNomination(postId: string) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (nomination: { nominee_member_id: string }) => {
      const { data, error } = await supabase
        .from('bar_nominations')
        .insert({ ...nomination, post_id: postId, status: 'approved' })
        .select('*, nominee:nominee_member_id(name, photo_url)')
        .single();
      if (error) throw error;
      return data;
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ['nominations', postId] }),
  });
}

export function useDeleteNomination(postId: string) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (id: string) => {
      const { error } = await supabase.from('bar_nominations').delete().eq('id', id);
      if (error) throw error;
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ['nominations', postId] }),
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
      if (error) throw error;
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
      if (error) throw error;
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
      if (error) throw error;
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ['events'] }),
  });
}

// ─── Dashboard Stats ─────────────────────────────────

export function useDashboardStats(associationId: string) {
  return useQuery({
    queryKey: ['dashboard-stats', associationId],
    queryFn: async (): Promise<DashboardStats> => {
      const currentYear = new Date().getFullYear();

      const [membersRes, activeRes, paymentsRes, noticesRes, electionsRes] = await Promise.all([
        supabase.from('bar_members').select('id', { count: 'exact' }).eq('association_id', associationId),
        supabase.from('bar_members').select('id', { count: 'exact' }).eq('association_id', associationId).eq('status', 'active'),
        supabase.from('bar_fee_payments').select('amount').eq('association_id', associationId).eq('fee_year', currentYear).eq('status', 'paid'),
        supabase.from('bar_notices').select('id', { count: 'exact' }).eq('association_id', associationId),
        supabase.from('bar_elections').select('id').eq('association_id', associationId).in('status', ['nominations', 'voting']),
      ]);

      const feeCollected = (paymentsRes.data || []).reduce((s, p) => s + p.amount, 0);
      const pendingCount = (activeRes.count || 0) - (paymentsRes.data || []).length;

      return {
        totalMembers: membersRes.count || 0,
        activeMembers: activeRes.count || 0,
        feeCollectedThisYear: feeCollected,
        pendingPayments: Math.max(0, pendingCount),
        totalNotices: noticesRes.count || 0,
        activeElection: (electionsRes.data || []).length > 0,
      };
    },
    enabled: !!associationId,
  });
}
