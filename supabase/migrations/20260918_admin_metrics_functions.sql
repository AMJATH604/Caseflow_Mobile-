-- ═══════════════════════════════════════════════════════════════
-- Operator console — aggregate reads
--
-- Row-level security scopes every ordinary query to the signed-in user, so the
-- web console could previously see only the administrator's own records: an
-- admin saw 61 of 379 cases and 0 of 380 clients. Widening RLS with
-- `OR is_admin(auth.uid())` across ~30 tables would have fixed the symptom and
-- handed full-database authority to the browser — any XSS in the console would
-- then be total data access.
--
-- These SECURITY DEFINER functions are the alternative. They are called only by
-- the `admin-metrics` edge function, which verifies the caller's JWT and their
-- admin flag before using the service role. EXECUTE is revoked from anon and
-- authenticated because PostgREST otherwise exposes every public function as an
-- RPC at /rest/v1/rpc/<name>.
--
-- They return counts and identity only — never a case title, a client name or a
-- fee figure. CaseFlow holds privileged advocate-client material, and an
-- administrator browsing it is a professional-conduct problem before it is a
-- security one. The response shape makes that impossible rather than merely
-- discouraged.
-- ═══════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.admin_is_admin(p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $fn$
  SELECT coalesce((SELECT is_admin FROM public.profiles WHERE id = p_user_id), false);
$fn$;

REVOKE ALL ON FUNCTION public.admin_is_admin(UUID) FROM PUBLIC, anon, authenticated;


CREATE OR REPLACE FUNCTION public.admin_overview()
RETURNS JSONB
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $fn$
  SELECT jsonb_build_object(
    'users', (
      SELECT jsonb_build_object(
        'total',      count(*),
        'advocates',  count(*) FILTER (WHERE p.user_role = 'advocate'),
        'citizens',   count(*) FILTER (WHERE p.user_role = 'citizen'),
        'admins',     count(*) FILTER (WHERE coalesce(p.is_admin,false)),
        'active_1d',  count(*) FILTER (WHERE u.last_sign_in_at > now() - interval '1 day'),
        'active_7d',  count(*) FILTER (WHERE u.last_sign_in_at > now() - interval '7 days'),
        'active_30d', count(*) FILTER (WHERE u.last_sign_in_at > now() - interval '30 days'),
        'never_signed_in', count(*) FILTER (WHERE u.last_sign_in_at IS NULL)
      )
      FROM auth.users u LEFT JOIN public.profiles p ON p.id = u.id
    ),

    -- 12 weeks of signups, zero-filled so the chart has no gaps.
    'signups', (
      SELECT coalesce(jsonb_agg(jsonb_build_object('week', wk, 'count', n) ORDER BY wk), '[]'::jsonb)
      FROM (
        SELECT w.wk::date AS wk,
               count(u.id) AS n
        FROM generate_series(date_trunc('week', now()) - interval '11 weeks',
                             date_trunc('week', now()), interval '1 week') w(wk)
        LEFT JOIN auth.users u
               ON date_trunc('week', u.created_at) = w.wk
        GROUP BY w.wk
      ) s
    ),

    'records', jsonb_build_object(
      'cases',           (SELECT count(*) FROM public.cases),
      'clients',         (SELECT count(*) FROM public.clients),
      'hearings',        (SELECT count(*) FROM public.hearings),
      'cases_7d',        (SELECT count(*) FROM public.cases    WHERE created_at > now() - interval '7 days'),
      'hearings_7d',     (SELECT count(*) FROM public.hearings WHERE created_at > now() - interval '7 days'),
      'statutes',        (SELECT count(*) FROM public.bare_acts)
    ),

    -- Where adoption is leaking.
    'adoption', jsonb_build_object(
      'inactive_30d', (SELECT count(*) FROM auth.users
                        WHERE last_sign_in_at IS NULL
                           OR last_sign_in_at < now() - interval '30 days'),
      'no_push_token',(SELECT count(*) FROM auth.users u
                        WHERE NOT EXISTS (SELECT 1 FROM public.fcm_tokens f WHERE f.user_id = u.id)),
      'no_cases',     (SELECT count(*) FROM auth.users u
                        WHERE NOT EXISTS (SELECT 1 FROM public.cases c WHERE c.created_by = u.id))
    ),

    'delivery', jsonb_build_object(
      'tokens',            (SELECT count(*) FROM public.fcm_tokens),
      'users_with_token',  (SELECT count(DISTINCT user_id) FROM public.fcm_tokens),
      'notifications_7d',  (SELECT count(*) FROM public.notifications
                             WHERE created_at > now() - interval '7 days')
    ),

    'feedback', jsonb_build_object(
      'total', (SELECT count(*) FROM public.user_feedback),
      'open',  (SELECT count(*) FROM public.user_feedback
                 WHERE coalesce(status,'new') NOT IN ('resolved','closed'))
    ),

    'subscriptions', (
      SELECT coalesce(jsonb_object_agg(tier, n), '{}'::jsonb)
      FROM (SELECT coalesce(subscription_tier,'unknown') AS tier, count(*) AS n
            FROM public.profiles GROUP BY 1) t
    ),

    'generated_at', now()
  );
$fn$;

REVOKE ALL ON FUNCTION public.admin_overview() FROM PUBLIC, anon, authenticated;


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
      (SELECT count(*) FROM public.cases    c WHERE c.created_by = u.id) AS cases,
      (SELECT count(*) FROM public.clients  c WHERE c.created_by = u.id) AS clients,
      (SELECT count(*) FROM public.hearings h WHERE h.created_by = u.id) AS hearings,
      EXISTS (SELECT 1 FROM public.fcm_tokens f WHERE f.user_id = u.id)  AS has_push
    FROM auth.users u
    LEFT JOIN public.profiles p ON p.id = u.id
  ) t;
$fn$;

REVOKE ALL ON FUNCTION public.admin_user_list() FROM PUBLIC, anon, authenticated;
