// Shapes mirror the tables in 20260929_bardesk_bar_operations.sql.
// Elections were removed from that migration and from here.

export interface BarAssociation {
  id: string;
  name: string;
  district: string;
  court: string;
  address: string | null;
  logo_url: string | null;
  annual_fee: number | null;
  invite_code: string;
  subscription_plan: string | null;
  subscription_expires_at: string | null;
  president_name: string | null;
  secretary_name: string | null;
  treasurer_name: string | null;
  contact_phone: string | null;
  contact_email: string | null;
  /** Madras HC floor: ₹20,000 in Chennai/Coimbatore/Madurai, ₹15,000 elsewhere. */
  junior_stipend_floor: number;
  created_at: string;
  updated_at: string | null;
}

export type MemberClass = 'advocate' | 'clerk';

export type WelfareFundStatus =
  | 'unknown'
  | 'active'
  | 'arrears'
  | 'not_enrolled'
  | 'retired'
  | 'claimed';

export interface BarMember {
  id: string;
  association_id: string;
  user_id: string | null;
  name: string;
  enrollment_number: string | null;
  mobile: string;
  email: string | null;
  photo_url: string | null;
  membership_type: string | null;
  status: string | null;
  joined_year: number | null;
  fee_paid_until: number | null;
  is_caseflow_user: boolean | null;

  /** Enrolment with the Bar Council — what welfare eligibility runs from. */
  enrolment_date: string | null;
  date_of_birth: string | null;
  address: string | null;
  blood_group: string | null;
  member_class: MemberClass;
  /** Set on a clerk: the advocate they work under. */
  works_under_member_id: string | null;
  /** A real date, so the lapse watch can count down to it. */
  membership_expires_on: string | null;
  welfare_fund_number: string | null;
  welfare_fund_status: WelfareFundStatus;
  id_card_number: string | null;
  id_card_issued_on: string | null;
  id_card_valid_until: string | null;
  is_deceased: boolean;
  date_of_death: string | null;
  notes: string | null;
  created_at: string;
  updated_at: string | null;
}

export interface BarAdmin {
  id: string;
  association_id: string;
  user_id: string;
  role: string | null;
  created_at: string;
  bar_associations?: BarAssociation;
}

export interface BarNotice {
  id: string;
  association_id: string;
  title: string;
  body: string;
  category: string | null;
  is_pinned: boolean | null;
  published_by: string | null;
  published_at: string | null;
  scheduled_for: string | null;
  fcm_sent: boolean | null;
  read_count: number | null;
  created_at: string;
}

export interface BarFeePayment {
  id: string;
  association_id: string;
  member_id: string;
  amount: number;
  fee_year: number;
  payment_method: string | null;
  razorpay_order_id: string | null;
  razorpay_payment_id: string | null;
  status: string | null;
  receipt_number: string | null;
  paid_at: string | null;
  created_at: string;
  bar_members?: Pick<BarMember, 'id' | 'name' | 'enrollment_number'>;
}

export interface BarEvent {
  id: string;
  association_id: string;
  title: string;
  description: string | null;
  event_date: string;
  start_time: string | null;
  end_time: string | null;
  location: string | null;
  agenda: string | null;
  category: string | null;
  created_by: string | null;
  created_at: string;
}

export interface BarCondolence {
  id: string;
  association_id: string;
  member_id: string | null;
  deceased_name: string;
  enrolment_number: string | null;
  date_of_death: string;
  age: number | null;
  message: string | null;
  meeting_at: string | null;
  meeting_venue: string | null;
  /** The bar resolving not to take up work that day. */
  no_work_resolution: boolean;
  published_by: string | null;
  published_at: string;
  fcm_sent: boolean;
  created_at: string;
}

export type WelfareClaimType =
  | 'death'
  | 'retirement'
  | 'medical'
  | 'disability'
  | 'other';

/** Mirrors how the Bar Council actually moves an application along. */
export type WelfareClaimStatus =
  | 'draft'
  | 'submitted'
  | 'defect'
  | 'resubmitted'
  | 'sanctioned'
  | 'rejected';

export interface BarWelfareClaim {
  id: string;
  association_id: string;
  member_id: string | null;
  claim_type: WelfareClaimType;
  claimant_name: string | null;
  claimant_relation: string | null;
  claimant_mobile: string | null;
  amount: number | null;
  reference_number: string | null;
  status: WelfareClaimStatus;
  /** What the Bar Council returned it for. */
  defect_notes: string | null;
  submitted_on: string | null;
  sanctioned_on: string | null;
  created_by: string | null;
  created_at: string;
  updated_at: string;
  bar_members?: Pick<BarMember, 'id' | 'name' | 'enrollment_number'>;
}

export interface BarWelfareStamp {
  id: string;
  association_id: string;
  txn_type: 'received' | 'sold' | 'returned';
  quantity: number;
  denomination: number;
  member_id: string | null;
  notes: string | null;
  recorded_by: string | null;
  recorded_at: string;
  bar_members?: Pick<BarMember, 'id' | 'name'>;
}

export interface BarStipendDeclaration {
  id: string;
  association_id: string;
  senior_member_id: string;
  junior_member_id: string | null;
  junior_name: string;
  junior_mobile: string | null;
  monthly_stipend: number;
  effective_from: string;
  effective_to: string | null;
  confirmed_by_junior: boolean;
  confirmed_at: string | null;
  declared_by: string | null;
  created_at: string;
  updated_at: string;
  senior?: Pick<BarMember, 'id' | 'name' | 'enrollment_number'>;
}

export interface DashboardStats {
  totalMembers: number;
  activeMembers: number;
  clerks: number;
  onCaseFlow: number;
  /** Not yet lapsed, but inside the warning window. */
  expiringSoon: number;
  lapsed: number;
  feesCollected: number;
  feesOutstanding: number;
  openClaims: number;
  stampBalance: number;
  upcomingEvents: number;
}

/** A member whose membership is about to lapse, or already has. */
export interface RenewalRow extends BarMember {
  daysRemaining: number | null;
}
