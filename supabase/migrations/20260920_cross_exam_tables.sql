-- Cross-Examination Preparation Tables
-- Privacy-first: All data stored locally. No AI, no external APIs.

-- ─── Sessions ──────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.cross_exam_sessions (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  case_id       UUID NOT NULL REFERENCES public.cases(id) ON DELETE CASCADE,
  witness_id    UUID,  -- Optional link to witness_notes
  user_id       UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  firm_id       UUID,

  -- Witness info (denormalized — works even without witness_notes link)
  witness_name  TEXT NOT NULL,
  witness_tag   TEXT DEFAULT 'PW1',

  -- Session metadata
  status        TEXT DEFAULT 'draft' CHECK (status IN ('draft','preparing','ready','completed')),
  hearing_date  DATE,
  notes         TEXT,

  created_at    TIMESTAMPTZ DEFAULT now(),
  updated_at    TIMESTAMPTZ DEFAULT now(),
  deleted_at    TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_cross_exam_sessions_case
  ON public.cross_exam_sessions(case_id);
CREATE INDEX IF NOT EXISTS idx_cross_exam_sessions_user
  ON public.cross_exam_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_cross_exam_sessions_firm
  ON public.cross_exam_sessions(firm_id);

ALTER TABLE public.cross_exam_sessions ENABLE ROW LEVEL SECURITY;

-- Standard firm visibility pattern (same as cases, hearings, etc.)
DROP POLICY IF EXISTS "cross_exam_session_select" ON public.cross_exam_sessions;
CREATE POLICY "cross_exam_session_select" ON public.cross_exam_sessions
  FOR SELECT USING (
    user_id = auth.uid()
    OR firm_id = auth.uid()
    OR firm_id = (SELECT firm_id FROM public.profiles WHERE id = auth.uid())
    OR EXISTS (
      SELECT 1 FROM public.firm_members fm
      WHERE fm.owner_id = cross_exam_sessions.firm_id
        AND fm.member_id = auth.uid()
        AND fm.status = 'accepted'
    )
  );

DROP POLICY IF EXISTS "cross_exam_session_insert" ON public.cross_exam_sessions;
CREATE POLICY "cross_exam_session_insert" ON public.cross_exam_sessions
  FOR INSERT WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "cross_exam_session_update" ON public.cross_exam_sessions;
CREATE POLICY "cross_exam_session_update" ON public.cross_exam_sessions
  FOR UPDATE USING (
    user_id = auth.uid()
    OR firm_id = auth.uid()
    OR firm_id = (SELECT firm_id FROM public.profiles WHERE id = auth.uid())
    OR EXISTS (
      SELECT 1 FROM public.firm_members fm
      WHERE fm.owner_id = cross_exam_sessions.firm_id
        AND fm.member_id = auth.uid()
        AND fm.status = 'accepted'
    )
  );

DROP POLICY IF EXISTS "cross_exam_session_delete" ON public.cross_exam_sessions;
CREATE POLICY "cross_exam_session_delete" ON public.cross_exam_sessions
  FOR DELETE USING (user_id = auth.uid());

-- ─── Questions ─────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.cross_exam_questions (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id      UUID NOT NULL REFERENCES public.cross_exam_sessions(id) ON DELETE CASCADE,

  -- Question content
  question_text   TEXT NOT NULL,
  category        TEXT DEFAULT 'fact_establishment'
    CHECK (category IN (
      'fact_establishment','contradiction','credibility','timeline',
      'motive','character','document_confrontation'
    )),

  -- Ordering & markers
  position        INT DEFAULT 0,
  priority        TEXT DEFAULT 'medium'
    CHECK (priority IN ('low','medium','high','critical')),
  is_key_question BOOLEAN DEFAULT false,

  -- Advocate's prep notes (all optional)
  expected_answer   TEXT,
  follow_up_if_yes  TEXT,
  follow_up_if_no   TEXT,
  advocate_notes    TEXT,

  created_at      TIMESTAMPTZ DEFAULT now(),
  updated_at      TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_cross_exam_q_session
  ON public.cross_exam_questions(session_id);

ALTER TABLE public.cross_exam_questions ENABLE ROW LEVEL SECURITY;

-- Inherit access through parent session
DROP POLICY IF EXISTS "cross_exam_q_select" ON public.cross_exam_questions;
CREATE POLICY "cross_exam_q_select" ON public.cross_exam_questions
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.cross_exam_sessions s
      WHERE s.id = cross_exam_questions.session_id
        AND (
          s.user_id = auth.uid()
          OR s.firm_id = auth.uid()
          OR s.firm_id = (SELECT firm_id FROM public.profiles WHERE id = auth.uid())
          OR EXISTS (
            SELECT 1 FROM public.firm_members fm
            WHERE fm.owner_id = s.firm_id
              AND fm.member_id = auth.uid()
              AND fm.status = 'accepted'
          )
        )
    )
  );

DROP POLICY IF EXISTS "cross_exam_q_insert" ON public.cross_exam_questions;
CREATE POLICY "cross_exam_q_insert" ON public.cross_exam_questions
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.cross_exam_sessions s
      WHERE s.id = cross_exam_questions.session_id
        AND (
          s.user_id = auth.uid()
          OR s.firm_id = auth.uid()
          OR s.firm_id = (SELECT firm_id FROM public.profiles WHERE id = auth.uid())
          OR EXISTS (
            SELECT 1 FROM public.firm_members fm
            WHERE fm.owner_id = s.firm_id
              AND fm.member_id = auth.uid()
              AND fm.status = 'accepted'
          )
        )
    )
  );

DROP POLICY IF EXISTS "cross_exam_q_update" ON public.cross_exam_questions;
CREATE POLICY "cross_exam_q_update" ON public.cross_exam_questions
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM public.cross_exam_sessions s
      WHERE s.id = cross_exam_questions.session_id
        AND (
          s.user_id = auth.uid()
          OR s.firm_id = auth.uid()
          OR s.firm_id = (SELECT firm_id FROM public.profiles WHERE id = auth.uid())
          OR EXISTS (
            SELECT 1 FROM public.firm_members fm
            WHERE fm.owner_id = s.firm_id
              AND fm.member_id = auth.uid()
              AND fm.status = 'accepted'
          )
        )
    )
  );

DROP POLICY IF EXISTS "cross_exam_q_delete" ON public.cross_exam_questions;
CREATE POLICY "cross_exam_q_delete" ON public.cross_exam_questions
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM public.cross_exam_sessions s
      WHERE s.id = cross_exam_questions.session_id
        AND (
          s.user_id = auth.uid()
          OR s.firm_id = auth.uid()
          OR s.firm_id = (SELECT firm_id FROM public.profiles WHERE id = auth.uid())
          OR EXISTS (
            SELECT 1 FROM public.firm_members fm
            WHERE fm.owner_id = s.firm_id
              AND fm.member_id = auth.uid()
              AND fm.status = 'accepted'
          )
        )
    )
  );
