-- Create carousel_slides table
CREATE TABLE IF NOT EXISTS public.carousel_slides (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  type TEXT NOT NULL,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  gradient_colors TEXT[] NOT NULL,
  icon_name TEXT NOT NULL,
  action TEXT NOT NULL,
  detail_title TEXT NOT NULL,
  detail_body TEXT NOT NULL,
  custom_route_path TEXT NOT NULL,
  tool_id TEXT DEFAULT NULL,
  active BOOLEAN DEFAULT true NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- Index for active slides
CREATE INDEX IF NOT EXISTS idx_carousel_slides_active_created ON public.carousel_slides(active, created_at DESC);

-- Enable RLS
ALTER TABLE public.carousel_slides ENABLE ROW LEVEL SECURITY;

-- Drop policy if exists (to avoid duplicate policy errors if re-run)
DROP POLICY IF EXISTS "Allow public read access to carousel_slides" ON public.carousel_slides;
DROP POLICY IF EXISTS "Allow service_role full write access to carousel_slides" ON public.carousel_slides;

-- Allow read access to anyone (anonymous and authenticated)
CREATE POLICY "Allow public read access to carousel_slides" ON public.carousel_slides
  FOR SELECT TO public
  USING (true);

-- Allow service role full write access
CREATE POLICY "Allow service_role full write access to carousel_slides" ON public.carousel_slides
  FOR ALL TO service_role
  USING (true)
  WITH CHECK (true);

-- Insert the initial static slides (using INSERT INTO ... ON CONFLICT or simply clearing the table first if we want clean state, but since it's a migration let's just insert)
-- To make the migration re-runnable, let's truncate if table exists or only insert if empty.
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.carousel_slides LIMIT 1) THEN
    INSERT INTO public.carousel_slides (
      type, title, body, gradient_colors, icon_name, action, detail_title, detail_body, custom_route_path, tool_id
    ) VALUES 
    (
      '⚖️ LEGAL KNOWLEDGE',
      'Ignorantia Juris Non Excusat',
      'Ignorance of the law is not an excuse. Under Indian law, every citizen is presumed to know the legal rules that apply to them.',
      ARRAY['#4F46E5', '#06B6D4'],
      'balance_rounded',
      'Explore Guides',
      'Ignorantia Juris Non Excusat',
      'Ignorance of the law is not an excuse. Under Indian law, every citizen is presumed to know the legal rules that apply to them.\n\nOur Everyday Legal Encyclopedia breaks down complex laws, civil disputes, criminal procedures, and constitutional provisions into plain, simple language so you are never left in the dark.',
      '/know-your-rights',
      NULL
    ),
    (
      '⚖️ LEGAL WORD OF THE DAY',
      'Habeas Corpus',
      'A court order demanding that a detained person be brought before the court to determine if their detention is lawful.',
      ARRAY['#7C3AED', '#A855F7'],
      'translate_rounded',
      'Learn More',
      'Habeas Corpus (Writ of Liberty)',
      'A Latin term meaning ''to have the body''. It is a constitutional writ that protects individual liberty against unlawful or arbitrary detention.\n\nWhen filed, the High Court or Supreme Court orders the detaining authority to bring the detained person to court to examine the validity of their arrest. If the detention lacks legal basis, the person is set free immediately.',
      '/citizen-tools',
      'legal_dictionary'
    ),
    (
      '📜 CONSTITUTIONAL FACT',
      'Article 21 — Right to Life',
      'No person shall be deprived of life or personal liberty except according to procedure established by law.',
      ARRAY['#B45309', '#D97706'],
      'account_balance_rounded',
      'Read Constitution',
      'Article 21 — Cornerstone of Liberty',
      'Article 21 guarantees that ''No person shall be deprived of his life or personal liberty except according to procedure established by law.''\n\nThe Supreme Court has interpreted this dynamically to include the right to privacy, clean drinking water, pollution-free air, speedy trial, livelihood, and free legal aid for the underprivileged.',
      '/citizen-tools',
      'bare_acts'
    ),
    (
      '💡 LEGAL TIP',
      'Zero FIR — File Anywhere!',
      'You can file an FIR at ANY police station in India regardless of jurisdiction. Police cannot refuse under Section 154 CrPC.',
      ARRAY['#065F46', '#10B981'],
      'tips_and_updates_rounded',
      'Know Your Rights',
      'Zero FIR (First Information Report)',
      'A Zero FIR can be filed at any police station regardless of where the crime took place.\n\nThe station is legally obligated to accept your complaint, mark it as ''Zero FIR'' (without a serial number), and subsequently transfer it to the police station with the appropriate jurisdiction. This ensures critical evidence is collected immediately.',
      '/know-your-rights',
      NULL
    ),
    (
      '⚖️ LEGAL WORD',
      'Caveat',
      'A notice filed in court to prevent any order from being passed without hearing the person who filed the caveat (caveator).',
      ARRAY['#1E40AF', '#6366F1'],
      'spellcheck_rounded',
      'Legal Dictionary',
      'Caveat Petition',
      'Under Section 148A of the Civil Procedure Code, a Caveat is a precautionary petition filed by a person who fears that an ex-parte case may be filed against them.\n\nOnce logged, the Court cannot pass any interim order or injunction without first notifying the Caveator and giving them an opportunity to present their side of the case.',
      '/citizen-tools',
      'legal_dictionary'
    ),
    (
      '🏛️ LANDMARK CASE',
      'Kesavananda Bharati v. Kerala (1973)',
      'The Supreme Court established the Basic Structure Doctrine — Parliament cannot alter the fundamental framework of the Constitution.',
      ARRAY['#991B1B', '#DC2626'],
      'gavel_rounded',
      'Explore Cases',
      'The Basic Structure Doctrine',
      'The most critical judgment in Indian legal history. By a 7:6 majority, a 13-judge Supreme Court bench ruled that while Parliament has the power to amend the Constitution, it cannot alter or destroy its ''Basic Structure'' — including democracy, secularism, rule of law, and judicial independence.',
      '/know-your-rights',
      NULL
    ),
    (
      '💡 KNOW YOUR RIGHT',
      'RTI — Right to Information',
      'Under the RTI Act 2005, every citizen can request information from any public authority. They must respond within 30 days.',
      ARRAY['#0E7490', '#06B6D4'],
      'info_rounded',
      'Learn RTI',
      'Right to Information Act, 2005',
      'The RTI Act empowers citizens to request records, documents, and info from government authorities to ensure transparency.\n\nPublic Information Officers must respond within 30 days. If the query concerns a citizen''s life or personal liberty, the response must be provided within 48 hours.',
      '/know-your-rights',
      NULL
    ),
    (
      '⚖️ LEGAL WORD',
      'Suo Motu',
      'When a court takes cognizance and action on its own motion, without any petition or complaint from a party.',
      ARRAY['#6B21A8', '#9333EA'],
      'record_voice_over_rounded',
      'Legal Dictionary',
      'Suo Motu Cognizance',
      'Meaning ''on its own motion''. This is when a court initiates legal proceedings on its own, without any party filing a petition.\n\nCourts take Suo Motu action based on media reports, letters, or public disasters, demonstrating the proactive role of the judiciary in upholding justice and protecting public interest.',
      '/citizen-tools',
      'legal_dictionary'
    );
  END IF;
END $$;

-- Schedule daily cron job to regenerate carousel slides at 4:00 AM IST (22:30 UTC)
-- The edge function has verify_jwt disabled since it's only called by this internal cron.
-- Timeout is set to 60 seconds to allow for Gemini API response time.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    -- Unschedule if already exists to avoid duplicates
    BEGIN
      PERFORM cron.unschedule('generate-carousel-daily');
    EXCEPTION WHEN OTHERS THEN
      -- Job may not exist yet, ignore
    END;

    PERFORM cron.schedule(
      'generate-carousel-daily',
      '30 22 * * *',
      $cron$
      SELECT net.http_post(
        url := 'https://asrjqsnyezvcakvkokcl.supabase.co/functions/v1/generate-carousel',
        headers := '{"Content-Type": "application/json"}'::jsonb,
        body := '{}'::jsonb,
        timeout_milliseconds := 60000
      );
      $cron$
    );
  END IF;
END $$;
