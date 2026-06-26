// BarDesk — Bar Association Management Types

export interface BarAssociation {
  id: string;
  name: string;
  district: string;
  court: string;
  address?: string;
  logo_url?: string;
  annual_fee: number;
  invite_code: string;
  subscription_plan: string;
  subscription_expires_at?: string;
  created_at: string;
  updated_at: string;
}

export interface BarMember {
  id: string;
  association_id: string;
  user_id?: string;
  name: string;
  enrollment_number?: string;
  mobile: string;
  email?: string;
  photo_url?: string;
  membership_type: 'regular' | 'life' | 'honorary' | 'student';
  status: 'active' | 'suspended' | 'resigned' | 'deceased';
  joined_year?: number;
  fee_paid_until?: number;
  is_caseflow_user: boolean;
  created_at: string;
}

export interface BarAdmin {
  id: string;
  association_id: string;
  user_id: string;
  role: 'secretary' | 'joint_secretary' | 'treasurer' | 'president';
  created_at: string;
}

export interface BarNotice {
  id: string;
  association_id: string;
  title: string;
  body: string;
  category: 'general' | 'urgent' | 'election' | 'event' | 'holiday';
  is_pinned: boolean;
  published_by?: string;
  published_at: string;
  scheduled_for?: string;
  fcm_sent: boolean;
  read_count: number;
  created_at: string;
}

export interface BarFeePayment {
  id: string;
  association_id: string;
  member_id: string;
  amount: number;
  fee_year: number;
  payment_method: string;
  razorpay_order_id?: string;
  razorpay_payment_id?: string;
  status: 'pending' | 'paid' | 'failed';
  receipt_number?: string;
  paid_at?: string;
  created_at: string;
  // Joined
  member?: BarMember;
}

export interface BarElection {
  id: string;
  association_id: string;
  title: string;
  description?: string;
  nomination_start: string;
  nomination_end: string;
  voting_start: string;
  voting_end: string;
  status: 'draft' | 'nominations' | 'voting' | 'completed' | 'cancelled';
  results_published: boolean;
  created_at: string;
}

export interface BarElectionPost {
  id: string;
  election_id: string;
  post_name: string;
  max_winners: number;
  created_at: string;
}

export interface BarNomination {
  id: string;
  post_id: string;
  nominee_member_id: string;
  proposer_member_id?: string;
  seconder_member_id?: string;
  status: 'pending' | 'approved' | 'rejected';
  bio?: string;
  photo_url?: string;
  created_at: string;
  // Joined
  nominee?: BarMember;
  proposer?: BarMember;
}

export interface BarEvent {
  id: string;
  association_id: string;
  title: string;
  description?: string;
  event_date: string;
  start_time?: string;
  end_time?: string;
  location?: string;
  agenda?: string;
  category: 'meeting' | 'holiday' | 'lecture' | 'sports' | 'annual';
  created_by?: string;
  created_at: string;
}

export interface VoteCount {
  nomination_id: string;
  vote_count: number;
}

export interface DashboardStats {
  totalMembers: number;
  activeMembers: number;
  feeCollectedThisYear: number;
  pendingPayments: number;
  totalNotices: number;
  activeElection: boolean;
}
