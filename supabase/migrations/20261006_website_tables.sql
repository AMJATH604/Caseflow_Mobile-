-- ═══════════════════════════════════════════════════════════════
-- Marketing website (repo caseflow_website): enquiries and editable content
--
-- NOT YET APPLIED. Apply on its own in a transaction with
-- `supabase db query --linked --file`, not `db push` (the remote history uses
-- dashboard timestamps, so push would re-run every local migration).
--
-- website_leads    one row per form sent from the website. Visitors (anon)
--                  may INSERT only — never read, change or delete. Admins
--                  (profiles.is_admin, via public.is_platform_admin()) do
--                  everything else from the website's /admin panel.
-- website_content  one row per editable block (pricing, faqs, testimonials,
--                  announcement, settings). Public to read — it is the
--                  website's own text — and writable only by admins.
--
-- No new SECURITY DEFINER function is exposed as an RPC: the rate limiter
-- returns `trigger`, which PostgREST does not expose, and EXECUTE is revoked
-- from the API roles anyway.
-- ═══════════════════════════════════════════════════════════════

-- ── Enquiries ──────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.website_leads (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  kind          TEXT NOT NULL DEFAULT 'contact'
                CHECK (kind IN ('contact', 'demo', 'pricing', 'bar', 'download')),
  name          TEXT NOT NULL CHECK (char_length(btrim(name)) BETWEEN 1 AND 120),
  email         TEXT NOT NULL CHECK (char_length(email) <= 200 AND email ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$'),
  phone         TEXT CHECK (phone IS NULL OR char_length(phone) <= 30),
  organisation  TEXT CHECK (organisation IS NULL OR char_length(organisation) <= 160),
  city          TEXT CHECK (city IS NULL OR char_length(city) <= 80),
  role          TEXT CHECK (role IS NULL OR char_length(role) <= 60),
  plan          TEXT CHECK (plan IS NULL OR char_length(plan) <= 40),
  message       TEXT CHECK (message IS NULL OR char_length(message) <= 4000),
  source_page   TEXT CHECK (source_page IS NULL OR char_length(source_page) <= 200),
  status        TEXT NOT NULL DEFAULT 'new'
                CHECK (status IN ('new', 'contacted', 'converted', 'closed')),
  admin_notes   TEXT CHECK (admin_notes IS NULL OR char_length(admin_notes) <= 4000)
);

CREATE INDEX IF NOT EXISTS website_leads_created_at_idx ON public.website_leads (created_at DESC);
CREATE INDEX IF NOT EXISTS website_leads_status_idx ON public.website_leads (status);
CREATE INDEX IF NOT EXISTS website_leads_email_recent_idx ON public.website_leads (lower(email), created_at DESC);

ALTER TABLE public.website_leads ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Visitors can send a website enquiry" ON public.website_leads;
CREATE POLICY "Visitors can send a website enquiry" ON public.website_leads
  FOR INSERT TO anon, authenticated
  WITH CHECK (status = 'new' AND admin_notes IS NULL);

DROP POLICY IF EXISTS "Admins read website enquiries" ON public.website_leads;
CREATE POLICY "Admins read website enquiries" ON public.website_leads
  FOR SELECT TO authenticated
  USING (public.is_platform_admin());

DROP POLICY IF EXISTS "Admins update website enquiries" ON public.website_leads;
CREATE POLICY "Admins update website enquiries" ON public.website_leads
  FOR UPDATE TO authenticated
  USING (public.is_platform_admin())
  WITH CHECK (public.is_platform_admin());

DROP POLICY IF EXISTS "Admins delete website enquiries" ON public.website_leads;
CREATE POLICY "Admins delete website enquiries" ON public.website_leads
  FOR DELETE TO authenticated
  USING (public.is_platform_admin());

-- Flood guard. Runs as definer because the visitor cannot read the table it
-- has to count. Five per email per hour, 300 in total per hour.
CREATE OR REPLACE FUNCTION public.website_leads_rate_limit()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF (SELECT count(*) FROM public.website_leads
       WHERE lower(email) = lower(NEW.email)
         AND created_at > now() - interval '1 hour') >= 5 THEN
    RAISE EXCEPTION 'Too many enquiries from this email address; try again later'
      USING ERRCODE = 'check_violation';
  END IF;
  IF (SELECT count(*) FROM public.website_leads
       WHERE created_at > now() - interval '1 hour') >= 300 THEN
    RAISE EXCEPTION 'Too many enquiries right now; try again later'
      USING ERRCODE = 'check_violation';
  END IF;
  -- Whatever the client sent, a new enquiry starts clean.
  NEW.status := 'new';
  NEW.admin_notes := NULL;
  NEW.created_at := now();
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.website_leads_rate_limit() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_website_leads_rate_limit ON public.website_leads;
CREATE TRIGGER trg_website_leads_rate_limit
  BEFORE INSERT ON public.website_leads
  FOR EACH ROW EXECUTE FUNCTION public.website_leads_rate_limit();

-- ── Editable content ───────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.website_content (
  key         TEXT PRIMARY KEY
              CHECK (key IN ('pricing', 'faqs', 'testimonials', 'announcement', 'settings')),
  value       JSONB NOT NULL,
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by  UUID REFERENCES auth.users (id) ON DELETE SET NULL
);

ALTER TABLE public.website_content ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can read website content" ON public.website_content;
CREATE POLICY "Anyone can read website content" ON public.website_content
  FOR SELECT TO anon, authenticated
  USING (true);

DROP POLICY IF EXISTS "Admins insert website content" ON public.website_content;
CREATE POLICY "Admins insert website content" ON public.website_content
  FOR INSERT TO authenticated
  WITH CHECK (public.is_platform_admin());

DROP POLICY IF EXISTS "Admins update website content" ON public.website_content;
CREATE POLICY "Admins update website content" ON public.website_content
  FOR UPDATE TO authenticated
  USING (public.is_platform_admin())
  WITH CHECK (public.is_platform_admin());

DROP POLICY IF EXISTS "Admins delete website content" ON public.website_content;
CREATE POLICY "Admins delete website content" ON public.website_content
  FOR DELETE TO authenticated
  USING (public.is_platform_admin());

-- ── updated_at on edit (both tables) ───────────────────────────
CREATE OR REPLACE FUNCTION public.website_touch_updated_at()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.website_touch_updated_at() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_website_leads_touch ON public.website_leads;
CREATE TRIGGER trg_website_leads_touch
  BEFORE UPDATE ON public.website_leads
  FOR EACH ROW EXECUTE FUNCTION public.website_touch_updated_at();

DROP TRIGGER IF EXISTS trg_website_content_touch ON public.website_content;
CREATE TRIGGER trg_website_content_touch
  BEFORE UPDATE ON public.website_content
  FOR EACH ROW EXECUTE FUNCTION public.website_touch_updated_at();

-- ── Grants (explicit, so the intent survives default-privilege changes) ──
GRANT INSERT ON public.website_leads TO anon, authenticated;
GRANT SELECT, UPDATE, DELETE ON public.website_leads TO authenticated;
GRANT SELECT ON public.website_content TO anon, authenticated;
GRANT INSERT, UPDATE, DELETE ON public.website_content TO authenticated;

-- ── Realtime: new enquiries appear live in the admin panel ─────
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
     WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'website_leads'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.website_leads;
  END IF;
END;
$$;
