-- ═══════════════════════════════════════════════════════════════
-- Bar Association Management System — Database Migration
-- Creates 12 tables with full RLS, indexes, and helper functions
-- ═══════════════════════════════════════════════════════════════

-- 0. Enable pgcrypto for SHA-256 vote hashing
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ═══════════════════════════════════════════════════════════════
-- 1. Create Tables
-- ═══════════════════════════════════════════════════════════════

-- 1.1 Bar Associations
CREATE TABLE IF NOT EXISTS public.bar_associations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  district TEXT NOT NULL,
  court TEXT NOT NULL,
  address TEXT,
  logo_url TEXT,
  annual_fee DECIMAL(10,2) DEFAULT 500.00,
  invite_code TEXT NOT NULL UNIQUE,
  subscription_plan TEXT DEFAULT 'starter',
  subscription_expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- 1.2 Bar Members
CREATE TABLE IF NOT EXISTS public.bar_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  association_id UUID NOT NULL REFERENCES public.bar_associations(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  name TEXT NOT NULL,
  enrollment_number TEXT,
  mobile TEXT NOT NULL,
  email TEXT,
  photo_url TEXT,
  membership_type TEXT DEFAULT 'regular'
    CHECK (membership_type IN ('regular','life','honorary','student')),
  status TEXT DEFAULT 'active'
    CHECK (status IN ('active','suspended','resigned','deceased')),
  joined_year INTEGER,
  fee_paid_until INTEGER,
  is_caseflow_user BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(association_id, enrollment_number)
);

-- 1.3 Bar Admins
CREATE TABLE IF NOT EXISTS public.bar_admins (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  association_id UUID NOT NULL REFERENCES public.bar_associations(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role TEXT DEFAULT 'secretary'
    CHECK (role IN ('secretary','joint_secretary','treasurer','president')),
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(association_id, user_id)
);

-- 1.4 Bar Notices
CREATE TABLE IF NOT EXISTS public.bar_notices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  association_id UUID NOT NULL REFERENCES public.bar_associations(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  category TEXT DEFAULT 'general'
    CHECK (category IN ('general','urgent','election','event','holiday')),
  is_pinned BOOLEAN DEFAULT false,
  published_by UUID REFERENCES auth.users(id),
  published_at TIMESTAMPTZ DEFAULT now(),
  scheduled_for TIMESTAMPTZ,
  fcm_sent BOOLEAN DEFAULT false,
  read_count INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 1.5 Notice Reads
CREATE TABLE IF NOT EXISTS public.bar_notice_reads (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  notice_id UUID NOT NULL REFERENCES public.bar_notices(id) ON DELETE CASCADE,
  member_id UUID NOT NULL REFERENCES public.bar_members(id) ON DELETE CASCADE,
  read_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(notice_id, member_id)
);

-- 1.6 Fee Payments
CREATE TABLE IF NOT EXISTS public.bar_fee_payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  association_id UUID NOT NULL REFERENCES public.bar_associations(id),
  member_id UUID NOT NULL REFERENCES public.bar_members(id) ON DELETE CASCADE,
  amount DECIMAL(10,2) NOT NULL,
  fee_year INTEGER NOT NULL,
  payment_method TEXT DEFAULT 'razorpay',
  razorpay_order_id TEXT,
  razorpay_payment_id TEXT,
  status TEXT DEFAULT 'pending'
    CHECK (status IN ('pending','paid','failed')),
  receipt_number TEXT UNIQUE,
  paid_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 1.7 Elections
CREATE TABLE IF NOT EXISTS public.bar_elections (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  association_id UUID NOT NULL REFERENCES public.bar_associations(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT,
  nomination_start TIMESTAMPTZ NOT NULL,
  nomination_end TIMESTAMPTZ NOT NULL,
  voting_start TIMESTAMPTZ NOT NULL,
  voting_end TIMESTAMPTZ NOT NULL,
  status TEXT DEFAULT 'draft'
    CHECK (status IN ('draft','nominations','voting','completed','cancelled')),
  results_published BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 1.8 Election Posts
CREATE TABLE IF NOT EXISTS public.bar_election_posts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  election_id UUID NOT NULL REFERENCES public.bar_elections(id) ON DELETE CASCADE,
  post_name TEXT NOT NULL,
  max_winners INTEGER DEFAULT 1,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 1.9 Nominations
CREATE TABLE IF NOT EXISTS public.bar_nominations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID NOT NULL REFERENCES public.bar_election_posts(id) ON DELETE CASCADE,
  nominee_member_id UUID NOT NULL REFERENCES public.bar_members(id),
  proposer_member_id UUID REFERENCES public.bar_members(id),
  seconder_member_id UUID REFERENCES public.bar_members(id),
  status TEXT DEFAULT 'pending'
    CHECK (status IN ('pending','approved','rejected')),
  bio TEXT,
  photo_url TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 1.10 Votes
CREATE TABLE IF NOT EXISTS public.bar_votes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID NOT NULL REFERENCES public.bar_election_posts(id),
  nomination_id UUID NOT NULL REFERENCES public.bar_nominations(id),
  voter_hash TEXT NOT NULL,
  voted_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(post_id, voter_hash)
);

-- 1.11 Voter Participation
CREATE TABLE IF NOT EXISTS public.bar_voter_participation (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  election_id UUID NOT NULL REFERENCES public.bar_elections(id),
  member_id UUID NOT NULL REFERENCES public.bar_members(id),
  voted_at TIMESTAMPTZ DEFAULT now(),
  otp_verified BOOLEAN DEFAULT false,
  UNIQUE(election_id, member_id)
);

-- 1.12 Events
CREATE TABLE IF NOT EXISTS public.bar_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  association_id UUID NOT NULL REFERENCES public.bar_associations(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT,
  event_date DATE NOT NULL,
  start_time TIME,
  end_time TIME,
  location TEXT,
  agenda TEXT,
  category TEXT DEFAULT 'meeting'
    CHECK (category IN ('meeting','holiday','lecture','sports','annual')),
  created_by UUID REFERENCES auth.users(id),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 1.13 Link profiles
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS bar_association_id UUID REFERENCES public.bar_associations(id) ON DELETE SET NULL;


-- ═══════════════════════════════════════════════════════════════
-- 2. Indexes
-- ═══════════════════════════════════════════════════════════════
CREATE INDEX IF NOT EXISTS idx_bar_associations_invite_code ON public.bar_associations(invite_code);
CREATE INDEX IF NOT EXISTS idx_bar_members_association ON public.bar_members(association_id);
CREATE INDEX IF NOT EXISTS idx_bar_members_user ON public.bar_members(user_id);
CREATE INDEX IF NOT EXISTS idx_bar_admins_association ON public.bar_admins(association_id);
CREATE INDEX IF NOT EXISTS idx_bar_admins_user ON public.bar_admins(user_id);
CREATE INDEX IF NOT EXISTS idx_bar_notices_association ON public.bar_notices(association_id, published_at DESC);
CREATE INDEX IF NOT EXISTS idx_bar_notice_reads_notice ON public.bar_notice_reads(notice_id);
CREATE INDEX IF NOT EXISTS idx_bar_notice_reads_member ON public.bar_notice_reads(member_id);
CREATE INDEX IF NOT EXISTS idx_bar_fee_payments_member ON public.bar_fee_payments(member_id, fee_year);
CREATE INDEX IF NOT EXISTS idx_bar_fee_payments_association ON public.bar_fee_payments(association_id, fee_year);
CREATE INDEX IF NOT EXISTS idx_bar_elections_association ON public.bar_elections(association_id);
CREATE INDEX IF NOT EXISTS idx_bar_election_posts_election ON public.bar_election_posts(election_id);
CREATE INDEX IF NOT EXISTS idx_bar_nominations_post ON public.bar_nominations(post_id);
CREATE INDEX IF NOT EXISTS idx_bar_votes_post ON public.bar_votes(post_id);
CREATE INDEX IF NOT EXISTS idx_bar_votes_nomination ON public.bar_votes(nomination_id);
CREATE INDEX IF NOT EXISTS idx_bar_voter_participation_election ON public.bar_voter_participation(election_id);
CREATE INDEX IF NOT EXISTS idx_bar_events_association ON public.bar_events(association_id, event_date);


-- ═══════════════════════════════════════════════════════════════
-- 3. Enable Row Level Security (RLS)
-- ═══════════════════════════════════════════════════════════════
ALTER TABLE public.bar_associations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bar_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bar_admins ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bar_notices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bar_notice_reads ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bar_fee_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bar_elections ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bar_election_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bar_nominations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bar_votes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bar_voter_participation ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bar_events ENABLE ROW LEVEL SECURITY;


-- ═══════════════════════════════════════════════════════════════
-- 4. RLS Policies & Helper Functions
-- ═══════════════════════════════════════════════════════════════

-- 4.0 Helper Functions for RLS (bypasses RLS using SECURITY DEFINER to prevent recursion)
CREATE OR REPLACE FUNCTION public.is_association_member(
  p_association_id UUID,
  p_user_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.bar_members
    WHERE user_id = p_user_id AND association_id = p_association_id
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.is_association_admin(
  p_association_id UUID,
  p_user_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.bar_admins
    WHERE user_id = p_user_id AND association_id = p_association_id
  );
END;
$$;

-- 4.1 Bar Associations
DROP POLICY IF EXISTS "Authenticated users can read associations" ON public.bar_associations;
CREATE POLICY "Authenticated users can read associations" ON public.bar_associations
  FOR SELECT USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Service role manages associations" ON public.bar_associations;
CREATE POLICY "Service role manages associations" ON public.bar_associations
  FOR ALL USING (auth.role() = 'service_role');

-- 4.2 Bar Members
DROP POLICY IF EXISTS "Members read own association" ON public.bar_members;
CREATE POLICY "Members read own association" ON public.bar_members
  FOR SELECT USING (
    public.is_association_member(association_id, auth.uid())
  );

DROP POLICY IF EXISTS "Users read own member record" ON public.bar_members;
CREATE POLICY "Users read own member record" ON public.bar_members
  FOR SELECT USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Admins manage members" ON public.bar_members;
CREATE POLICY "Admins manage members" ON public.bar_members
  FOR ALL USING (
    public.is_association_admin(association_id, auth.uid())
  );

DROP POLICY IF EXISTS "Users can insert their own member record" ON public.bar_members;
CREATE POLICY "Users can insert their own member record" ON public.bar_members
  FOR INSERT WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Users update own member" ON public.bar_members;
CREATE POLICY "Users update own member" ON public.bar_members
  FOR UPDATE USING (user_id = auth.uid());

-- 4.3 Bar Admins
DROP POLICY IF EXISTS "Admins read own records" ON public.bar_admins;
CREATE POLICY "Admins read own records" ON public.bar_admins
  FOR SELECT USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Members see admins" ON public.bar_admins;
CREATE POLICY "Members see admins" ON public.bar_admins
  FOR SELECT USING (
    public.is_association_member(association_id, auth.uid())
  );

DROP POLICY IF EXISTS "Service role manages admins" ON public.bar_admins;
CREATE POLICY "Service role manages admins" ON public.bar_admins
  FOR ALL USING (auth.role() = 'service_role');

-- 4.4 Bar Notices
DROP POLICY IF EXISTS "Members read notices" ON public.bar_notices;
CREATE POLICY "Members read notices" ON public.bar_notices
  FOR SELECT USING (
    public.is_association_member(association_id, auth.uid())
  );

DROP POLICY IF EXISTS "Admins manage notices" ON public.bar_notices;
CREATE POLICY "Admins manage notices" ON public.bar_notices
  FOR ALL USING (
    public.is_association_admin(association_id, auth.uid())
  );

-- 4.5 Notice Reads
DROP POLICY IF EXISTS "Members read own reads" ON public.bar_notice_reads;
CREATE POLICY "Members read own reads" ON public.bar_notice_reads
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.bar_members bm
      WHERE bm.id = bar_notice_reads.member_id AND bm.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Members mark notices read" ON public.bar_notice_reads;
CREATE POLICY "Members mark notices read" ON public.bar_notice_reads
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.bar_members bm
      WHERE bm.id = bar_notice_reads.member_id AND bm.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Admins read notice stats" ON public.bar_notice_reads;
CREATE POLICY "Admins read notice stats" ON public.bar_notice_reads
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.bar_notices bn
      WHERE bn.id = bar_notice_reads.notice_id 
        AND public.is_association_admin(bn.association_id, auth.uid())
    )
  );

-- 4.6 Fee Payments
DROP POLICY IF EXISTS "Members read own payments" ON public.bar_fee_payments;
CREATE POLICY "Members read own payments" ON public.bar_fee_payments
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.bar_members bm
      WHERE bm.id = bar_fee_payments.member_id AND bm.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Members create payments" ON public.bar_fee_payments;
CREATE POLICY "Members create payments" ON public.bar_fee_payments
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.bar_members bm
      WHERE bm.id = bar_fee_payments.member_id AND bm.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Members update own payments" ON public.bar_fee_payments;
CREATE POLICY "Members update own payments" ON public.bar_fee_payments
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM public.bar_members bm
      WHERE bm.id = bar_fee_payments.member_id AND bm.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Admins read all payments" ON public.bar_fee_payments;
CREATE POLICY "Admins read all payments" ON public.bar_fee_payments
  FOR SELECT USING (
    public.is_association_admin(association_id, auth.uid())
  );

DROP POLICY IF EXISTS "Admins manage payments" ON public.bar_fee_payments;
CREATE POLICY "Admins manage payments" ON public.bar_fee_payments
  FOR ALL USING (
    public.is_association_admin(association_id, auth.uid())
  );

-- 4.7 Elections
DROP POLICY IF EXISTS "Members read elections" ON public.bar_elections;
CREATE POLICY "Members read elections" ON public.bar_elections
  FOR SELECT USING (
    public.is_association_member(association_id, auth.uid())
  );

DROP POLICY IF EXISTS "Admins manage elections" ON public.bar_elections;
CREATE POLICY "Admins manage elections" ON public.bar_elections
  FOR ALL USING (
    public.is_association_admin(association_id, auth.uid())
  );

-- 4.8 Election Posts
DROP POLICY IF EXISTS "Members read election posts" ON public.bar_election_posts;
CREATE POLICY "Members read election posts" ON public.bar_election_posts
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.bar_elections be
      WHERE be.id = bar_election_posts.election_id 
        AND public.is_association_member(be.association_id, auth.uid())
    )
  );

DROP POLICY IF EXISTS "Admins manage election posts" ON public.bar_election_posts;
CREATE POLICY "Admins manage election posts" ON public.bar_election_posts
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM public.bar_elections be
      WHERE be.id = bar_election_posts.election_id 
        AND public.is_association_admin(be.association_id, auth.uid())
    )
  );

-- 4.9 Nominations
DROP POLICY IF EXISTS "Members read nominations" ON public.bar_nominations;
CREATE POLICY "Members read nominations" ON public.bar_nominations
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.bar_election_posts bp
      JOIN public.bar_elections be ON be.id = bp.election_id
      WHERE bp.id = bar_nominations.post_id 
        AND public.is_association_member(be.association_id, auth.uid())
    )
  );

DROP POLICY IF EXISTS "Admins manage nominations" ON public.bar_nominations;
CREATE POLICY "Admins manage nominations" ON public.bar_nominations
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM public.bar_election_posts bp
      JOIN public.bar_elections be ON be.id = bp.election_id
      WHERE bp.id = bar_nominations.post_id 
        AND public.is_association_admin(be.association_id, auth.uid())
    )
  );

-- 4.10 Votes
DROP POLICY IF EXISTS "Authenticated users cast votes" ON public.bar_votes;
CREATE POLICY "Authenticated users cast votes" ON public.bar_votes
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Members read vote counts" ON public.bar_votes;
CREATE POLICY "Members read vote counts" ON public.bar_votes
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.bar_election_posts bp
      JOIN public.bar_elections be ON be.id = bp.election_id
      WHERE bp.id = bar_votes.post_id 
        AND public.is_association_member(be.association_id, auth.uid())
    )
  );

-- 4.11 Voter Participation
DROP POLICY IF EXISTS "Members check own participation" ON public.bar_voter_participation;
CREATE POLICY "Members check own participation" ON public.bar_voter_participation
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.bar_members bm
      WHERE bm.id = bar_voter_participation.member_id AND bm.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Members record participation" ON public.bar_voter_participation;
CREATE POLICY "Members record participation" ON public.bar_voter_participation
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.bar_members bm
      WHERE bm.id = bar_voter_participation.member_id AND bm.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Admins read participation" ON public.bar_voter_participation;
CREATE POLICY "Admins read participation" ON public.bar_voter_participation
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.bar_elections be
      WHERE be.id = bar_voter_participation.election_id 
        AND public.is_association_admin(be.association_id, auth.uid())
    )
  );

-- 4.12 Events
DROP POLICY IF EXISTS "Members read events" ON public.bar_events;
CREATE POLICY "Members read events" ON public.bar_events
  FOR SELECT USING (
    public.is_association_member(association_id, auth.uid())
  );

DROP POLICY IF EXISTS "Admins manage events" ON public.bar_events;
CREATE POLICY "Admins manage events" ON public.bar_events
  FOR ALL USING (
    public.is_association_admin(association_id, auth.uid())
  );


-- ═══════════════════════════════════════════════════════════════
-- 5. Functions & Triggers
-- ═══════════════════════════════════════════════════════════════

-- Generate voter hash: SHA-256(member_id || election_id || salt)
-- Salt is read from Supabase app config: ALTER DATABASE postgres SET app.settings.election_salt = 'your-secret-salt';
CREATE OR REPLACE FUNCTION public.generate_voter_hash(
  p_member_id UUID,
  p_election_id UUID
)
RETURNS TEXT
LANGUAGE sql STABLE
AS $$
  SELECT encode(
    digest(
      p_member_id::text || p_election_id::text || coalesce(
        current_setting('app.settings.election_salt', true),
        'caseflow_bar_election_default_salt'
      ),
      'sha256'
    ),
    'hex'
  );
$$;

-- Get vote counts per nomination for a post
CREATE OR REPLACE FUNCTION public.get_vote_counts(p_post_id UUID)
RETURNS TABLE (
  nomination_id UUID,
  vote_count BIGINT
)
LANGUAGE sql STABLE
AS $$
  SELECT nomination_id, COUNT(*) as vote_count
  FROM public.bar_votes
  WHERE post_id = p_post_id
  GROUP BY nomination_id
  ORDER BY vote_count DESC;
$$;

-- Generate next receipt number for an association
CREATE OR REPLACE FUNCTION public.generate_bar_receipt_number(p_association_id UUID)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
  current_year INTEGER;
  next_seq INTEGER;
BEGIN
  current_year := EXTRACT(YEAR FROM now());
  SELECT COALESCE(MAX(
    CAST(SUBSTRING(receipt_number FROM 10) AS INTEGER)
  ), 0) + 1
  INTO next_seq
  FROM public.bar_fee_payments
  WHERE association_id = p_association_id
    AND receipt_number LIKE 'BAR/' || current_year || '/%';
  RETURN 'BAR/' || current_year || '/' || LPAD(next_seq::text, 4, '0');
END;
$$;

-- Auto-update member fee_paid_until when payment is marked as paid
CREATE OR REPLACE FUNCTION public.update_member_fee_status()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
  IF NEW.status = 'paid' AND (OLD.status IS NULL OR OLD.status != 'paid') THEN
    UPDATE public.bar_members
    SET fee_paid_until = NEW.fee_year
    WHERE id = NEW.member_id;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_update_fee_status ON public.bar_fee_payments;
CREATE TRIGGER trg_update_fee_status
  AFTER INSERT OR UPDATE ON public.bar_fee_payments
  FOR EACH ROW
  EXECUTE FUNCTION public.update_member_fee_status();

-- Auto-increment read_count on bar_notices when a read is recorded
CREATE OR REPLACE FUNCTION public.increment_notice_read_count()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.bar_notices
  SET read_count = read_count + 1
  WHERE id = NEW.notice_id;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_increment_notice_read ON public.bar_notice_reads;
CREATE TRIGGER trg_increment_notice_read
  AFTER INSERT ON public.bar_notice_reads
  FOR EACH ROW
  EXECUTE FUNCTION public.increment_notice_read_count();
