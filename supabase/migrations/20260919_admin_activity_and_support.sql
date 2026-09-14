-- ═══════════════════════════════════════════════════════════════
-- Operator console — activity feed, per-user detail, support actions
--
-- Same rule as 20260918: counts, identity and event metadata only. The activity
-- feed returns entity TYPE and ID, never a case title or a client name.
--
-- The two mutations record who performed them through record_admin_action(),
-- and refuse to act on the calling administrator's own account — with a single
-- admin account, self-disable or self-revoke locks you out of the console.
-- ═══════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────
-- Redaction
--
-- audit_logs.details is NOT uniformly safe to show an administrator.
-- fn_audit_row() (20260917) writes column NAMES only, but rows written earlier
-- by the mobile app itself embed real content: at the time of writing, 362 rows
-- carry `case_title` and 3 carry a strategy-task `title`. Returning details
-- verbatim would put privileged advocate-client material on the console screen.
--
-- Allowlist, not denylist. A denylist leaks the next content key someone adds
-- to an audit call; an allowlist merely hides it until it is reviewed and added
-- here. `_redacted` reports how many keys were withheld, so the operator sees
-- that something was omitted rather than an unexplained empty object.
-- ─────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.admin_scrub_details(p_details JSONB)
RETURNS JSONB
LANGUAGE sql
IMMUTABLE
SET search_path = public
AS $fn$
  SELECT CASE
    WHEN p_details IS NULL OR jsonb_typeof(p_details) <> 'object' THEN NULL
    ELSE (
      SELECT coalesce(jsonb_object_agg(key, value) FILTER (WHERE safe), '{}'::jsonb)
             || CASE WHEN count(*) FILTER (WHERE NOT safe) > 0
                     THEN jsonb_build_object('_redacted', count(*) FILTER (WHERE NOT safe))
                     ELSE '{}'::jsonb END
      FROM (
        SELECT d.key, d.value,
               d.key IN (
                 -- Column names, never their values.
                 'updated_fields', 'changed_columns',
                 -- Identifiers and event metadata.
                 'case_id', 'client_id', 'cascade',
                 -- Written by record_admin_action().
                 'sessions_removed', 'tokens_revoked', 'disabled'
               ) AS safe
        FROM jsonb_each(p_details) d
      ) k
    )
  END;
$fn$;

REVOKE ALL ON FUNCTION public.admin_scrub_details(JSONB) FROM PUBLIC, anon, authenticated;


-- ─────────────────────────────────────────────────────────
-- Activity feed — keyset paginated on created_at
-- ─────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.admin_activity(
  p_limit   INT         DEFAULT 50,
  p_before  TIMESTAMPTZ DEFAULT NULL,
  p_user_id UUID        DEFAULT NULL,
  p_action  TEXT        DEFAULT NULL,
  p_entity  TEXT        DEFAULT NULL
)
RETURNS JSONB
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $fn$
  WITH page AS (
    SELECT
      a.id, a.created_at, a.action, a.entity, a.entity_id, a.context, a.user_id,
      public.admin_scrub_details(a.details) AS details,
      -- Denormalised at write time, so a deleted account stays attributable.
      coalesce(a.actor_name,  p.full_name) AS actor_name,
      coalesce(a.actor_email, u.email)     AS actor_email
    FROM public.audit_logs a
    LEFT JOIN auth.users      u ON u.id = a.user_id
    LEFT JOIN public.profiles p ON p.id = a.user_id
    WHERE (p_before  IS NULL OR a.created_at < p_before)
      AND (p_user_id IS NULL OR a.user_id = p_user_id)
      AND (p_action  IS NULL OR a.action  = p_action)
      AND (p_entity  IS NULL OR a.entity  = p_entity)
    ORDER BY a.created_at DESC
    LIMIT least(greatest(coalesce(p_limit, 50), 1), 200)
  )
  SELECT jsonb_build_object(
    'rows',        coalesce((SELECT jsonb_agg(row_to_json(page) ORDER BY page.created_at DESC) FROM page), '[]'::jsonb),
    -- Keyset cursor: oldest row on this page.
    'next_before', (SELECT min(created_at) FROM page),
    'exhausted',   (SELECT count(*) FROM page) < least(greatest(coalesce(p_limit, 50), 1), 200)
  );
$fn$;

REVOKE ALL ON FUNCTION public.admin_activity(INT, TIMESTAMPTZ, UUID, TEXT, TEXT)
  FROM PUBLIC, anon, authenticated;


-- Distinct values, so the UI's filters describe what is actually there.
CREATE OR REPLACE FUNCTION public.admin_activity_filters()
RETURNS JSONB
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $fn$
  SELECT jsonb_build_object(
    'actions',  (SELECT coalesce(jsonb_agg(DISTINCT action ORDER BY action), '[]'::jsonb) FROM public.audit_logs),
    'entities', (SELECT coalesce(jsonb_agg(DISTINCT entity ORDER BY entity), '[]'::jsonb) FROM public.audit_logs),
    'total',    (SELECT count(*) FROM public.audit_logs)
  );
$fn$;

REVOKE ALL ON FUNCTION public.admin_activity_filters() FROM PUBLIC, anon, authenticated;


-- ─────────────────────────────────────────────────────────
-- One user: identity, reachability, usage, recent activity
-- ─────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.admin_user_detail(p_user_id UUID)
RETURNS JSONB
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $fn$
  SELECT jsonb_build_object(
    'user', (
      SELECT row_to_json(x) FROM (
        SELECT
          u.id, u.email, u.created_at, u.last_sign_in_at,
          u.email_confirmed_at IS NOT NULL                        AS email_confirmed,
          (u.banned_until IS NOT NULL AND u.banned_until > now()) AS is_disabled,
          u.banned_until,
          p.full_name, coalesce(p.user_role,'advocate') AS user_role,
          coalesce(p.is_admin,false) AS is_admin,
          coalesce(p.subscription_tier,'free') AS subscription_tier,
          p.mobile_number, p.registration_number,
          p.practice_state, p.practice_district, p.firm_id
        FROM auth.users u
        LEFT JOIN public.profiles p ON p.id = u.id
        WHERE u.id = p_user_id
      ) x
    ),
    'usage', jsonb_build_object(
      'cases',    (SELECT count(*) FROM public.cases            WHERE created_by = p_user_id),
      'clients',  (SELECT count(*) FROM public.clients          WHERE created_by = p_user_id),
      'hearings', (SELECT count(*) FROM public.hearings         WHERE created_by = p_user_id),
      'payments', (SELECT count(*) FROM public.payments         WHERE created_by = p_user_id),
      'filings',  (SELECT count(*) FROM public.efiling_records  WHERE created_by = p_user_id)
    ),
    'devices', (
      SELECT coalesce(jsonb_agg(jsonb_build_object(
               'device_info', f.device_info,
               'created_at',  f.created_at,
               'updated_at',  f.updated_at) ORDER BY f.updated_at DESC), '[]'::jsonb)
      FROM public.fcm_tokens f WHERE f.user_id = p_user_id
    ),
    'sessions', jsonb_build_object(
      'active', (SELECT count(*) FROM auth.sessions
                  WHERE user_id = p_user_id AND (not_after IS NULL OR not_after > now()))
    ),
    -- Feedback is addressed to the operator by the user, so its title is theirs
    -- to read — unlike a case title, which is their client's.
    'feedback', (
      SELECT coalesce(jsonb_agg(jsonb_build_object(
               'id', fb.id, 'type', fb.feedback_type, 'severity', fb.severity,
               'title', fb.title, 'status', fb.status, 'app_version', fb.app_version,
               'created_at', fb.created_at) ORDER BY fb.created_at DESC), '[]'::jsonb)
      FROM public.user_feedback fb WHERE fb.user_id = p_user_id
    ),
    'recent_activity', (
      SELECT coalesce(jsonb_agg(row_to_json(a) ORDER BY a.created_at DESC), '[]'::jsonb)
      FROM (
        SELECT id, created_at, action, entity, entity_id, context,
               public.admin_scrub_details(details) AS details
        FROM public.audit_logs
        WHERE user_id = p_user_id
        ORDER BY created_at DESC
        LIMIT 25
      ) a
    )
  );
$fn$;

REVOKE ALL ON FUNCTION public.admin_user_detail(UUID) FROM PUBLIC, anon, authenticated;


-- The user list gains the disabled flag, so a suspended account is visible in
-- the table rather than only on its detail page.
CREATE OR REPLACE FUNCTION public.admin_user_list()
RETURNS JSONB
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $fn$
  SELECT coalesce(jsonb_agg(row_to_json(t) ORDER BY t.last_sign_in_at DESC NULLS LAST), '[]'::jsonb)
  FROM (
    SELECT
      u.id,
      u.email,
      p.full_name,
      coalesce(p.user_role,'advocate')        AS user_role,
      coalesce(p.is_admin,false)              AS is_admin,
      coalesce(p.subscription_tier,'free')    AS subscription_tier,
      p.practice_district,
      u.created_at,
      u.last_sign_in_at,
      u.email_confirmed_at IS NOT NULL        AS email_confirmed,
      (u.banned_until IS NOT NULL AND u.banned_until > now()) AS is_disabled,
      (SELECT count(*) FROM public.cases    c WHERE c.created_by = u.id) AS cases,
      (SELECT count(*) FROM public.clients  c WHERE c.created_by = u.id) AS clients,
      (SELECT count(*) FROM public.hearings h WHERE h.created_by = u.id) AS hearings,
      EXISTS (SELECT 1 FROM public.fcm_tokens f WHERE f.user_id = u.id)  AS has_push
    FROM auth.users u
    LEFT JOIN public.profiles p ON p.id = u.id
  ) t;
$fn$;

REVOKE ALL ON FUNCTION public.admin_user_list() FROM PUBLIC, anon, authenticated;


-- ─────────────────────────────────────────────────────────
-- Support action: sign a user out everywhere
-- ─────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.admin_revoke_sessions(
  p_admin_id UUID,
  p_user_id  UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE v_sessions INT; v_tokens INT;
BEGIN
  IF p_admin_id = p_user_id THEN
    RAISE EXCEPTION 'An administrator cannot revoke their own sessions from the console.';
  END IF;

  WITH r AS (
    UPDATE auth.refresh_tokens SET revoked = true, updated_at = now()
     WHERE user_id::uuid = p_user_id AND revoked = false
    RETURNING 1
  ) SELECT count(*) INTO v_tokens FROM r;

  WITH s AS (DELETE FROM auth.sessions WHERE user_id = p_user_id RETURNING 1)
  SELECT count(*) INTO v_sessions FROM s;

  PERFORM public.record_admin_action(
    p_admin_id, 'revoke_sessions', 'auth.users', p_user_id,
    jsonb_build_object('sessions_removed', v_sessions, 'tokens_revoked', v_tokens));

  RETURN jsonb_build_object('sessions_removed', v_sessions, 'tokens_revoked', v_tokens);
END;
$fn$;

REVOKE ALL ON FUNCTION public.admin_revoke_sessions(UUID, UUID) FROM PUBLIC, anon, authenticated;


-- ─────────────────────────────────────────────────────────
-- Support action: disable / re-enable an account
--
-- Uses auth.users.banned_until, which GoTrue checks at sign-in. Disabling also
-- clears live sessions — otherwise an already-signed-in user keeps working
-- until their access token expires.
-- ─────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.admin_set_account_disabled(
  p_admin_id UUID,
  p_user_id  UUID,
  p_disabled BOOLEAN
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE v_sessions INT := 0;
BEGIN
  IF p_admin_id = p_user_id THEN
    RAISE EXCEPTION 'An administrator cannot disable their own account from the console.';
  END IF;

  IF p_disabled THEN
    UPDATE auth.users SET banned_until = now() + interval '100 years' WHERE id = p_user_id;

    UPDATE auth.refresh_tokens SET revoked = true, updated_at = now()
     WHERE user_id::uuid = p_user_id AND revoked = false;

    WITH s AS (DELETE FROM auth.sessions WHERE user_id = p_user_id RETURNING 1)
    SELECT count(*) INTO v_sessions FROM s;
  ELSE
    UPDATE auth.users SET banned_until = NULL WHERE id = p_user_id;
  END IF;

  PERFORM public.record_admin_action(
    p_admin_id,
    CASE WHEN p_disabled THEN 'disable_account' ELSE 'enable_account' END,
    'auth.users', p_user_id,
    jsonb_build_object('sessions_removed', v_sessions));

  RETURN jsonb_build_object('disabled', p_disabled, 'sessions_removed', v_sessions);
END;
$fn$;

REVOKE ALL ON FUNCTION public.admin_set_account_disabled(UUID, UUID, BOOLEAN)
  FROM PUBLIC, anon, authenticated;
