# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repo shape

A polyglot **folder** monorepo — there is no root `package.json`, no workspaces, no Turborepo/Nx. Each app installs and builds independently.

| Path | Stack | Role |
|---|---|---|
| `apps/mobile` | **Flutter / Dart** — Riverpod, go_router, `supabase_flutter` | The primary product. Not React Native. |
| `apps/dashboard` | React 18 + Vite + TS + Tailwind + shadcn/ui | Admin web dashboard (all routes require `isAdmin`) |
| `apps/bardesk` | React 18 + Vite + TS | Bar association admin |
| `apps/docs` | static HTML/CSS/JS | Marketing site |
| `packages/design-system` | `tokens.css` + `tailwind.preset.ts` | Web only; the Flutter app does not use it |
| `supabase/` | migrations + Deno edge functions | Shared backend |

## Commands

**Mobile** (from `apps/mobile`):
```bash
flutter pub get
flutter run                       # see the EnvConfig warning below
flutter analyze                   # CI uses --no-fatal-infos --no-fatal-warnings
flutter test                      # all tests
flutter test test/services/base_repository_test.dart      # one file
flutter test test/models/models_test.dart -n "fromJson"    # one test by name substring
flutter build apk --release --dart-define=SUPABASE_URL=<url> --dart-define=SUPABASE_ANON_KEY=<key>
```

**Dashboard** (from `apps/dashboard`, dev server on port 8080):
```bash
npm install && npm run dev
npm run build && npm run lint
npm test                          # vitest run
npx vitest run src/test/example.test.ts    # one file
npx tsc --noEmit                  # CI type-check
```
`apps/bardesk` has only `dev` / `build` / `preview` and no tests.

**Backend** — both are manual; CI never deploys:
```bash
supabase db push                          # apply migrations
supabase functions deploy <name>          # deploy one edge function
supabase secrets set KEY=value
```

## Mobile data flow

Screen → Riverpod provider (`lib/services/providers.dart`) → `SupabaseService` facade → domain repository → `BaseRepository.client`.

`SupabaseService` is a thin delegation layer; the real logic is in `lib/services/repositories/*.dart`. Repositories are static classes holding `static final _client = BaseRepository.client` and calling `BaseRepository.requireAuth()` explicitly — most do **not** `extend BaseRepository`, because Dart forbids unqualified references to a supertype's static members.

Rules that are enforced by convention, from `CONTRIBUTING.md`:
1. No database logic in UI screens — it belongs in a repository.
2. Never call Supabase directly from a screen; go through the facade or a repository.
3. New data providers must `ref.watch(dataRefreshProvider)` — a global `StateProvider<int>`; bumping it refetches every provider that watches it.
4. Third-party API keys never reach the client; they are edge-function secrets.

`BaseRepository` carries the shared pieces worth knowing before writing a query: a 5-minute profile cache (`getCachedProfile`, fixing an N+1 where every fetch re-read the profile), `buildVisibilityFilter`, `softDelete`/`restoreSoftDeleted`, `normalizeDateStr`, and `sanitizeFilterValue` (a PostgREST injection guard — use it on any user string that reaches `.or()` / `.ilike()`).

## Firm visibility model

The one thing you cannot infer from a single file: **`firm_id = auth.uid()` means "I am the firm owner."** A solo advocate's records carry their own user id as `firm_id`. `BaseRepository.getTargetFirmId` returns `profile.firmId ?? userId` for the same reason.

The matching RLS predicate, repeated across migrations:
```sql
firm_id = auth.uid()
OR firm_id = (SELECT firm_id FROM public.profiles WHERE id = auth.uid())
OR EXISTS (SELECT 1 FROM public.firm_members fm
           WHERE fm.owner_id = <t>.firm_id AND fm.member_id = auth.uid()
             AND fm.status = 'accepted')
```
To avoid RLS recursion, bar-association tables use `SECURITY DEFINER` helpers (`public.is_association_member`, `public.is_association_admin`).

## Notifications

Pipeline: **DB trigger → `pg_net` HTTP POST → Deno edge function → FCM v1**. Cron-driven senders use `pg_cron` on the same path. Times in `cron.schedule` are UTC with IST noted in comments.

- Every edge function's first two lines are `verifyWebhookAuth(req)` from `_shared/auth_guard.ts`, which **fails closed** and accepts a service-role bearer, `CRON_SECRET`, `x-supabase-webhook-secret`, or `x-pg-trigger-secret` (read from Supabase vault by `public.get_pg_trigger_secret()`). These functions must stay deployed with `verify_jwt: false` — the DB triggers send no `Authorization` header.
- **FCM payloads are data-only on purpose.** There is no top-level `notification` block; the Flutter app renders its own rich notification in `FcmService.showRichNotification`. Adding a `notification` block back causes duplicate notifications and breaks inline reply and deep-links — it was added in `1a5e626` and reverted in `9e0903d`.
- Tap routing is `FcmService._performNavigation`, switching on `data['type']` with a generic `data['route']` fallback.
- `public.notifications` is the in-app Notification Centre: one row per recipient, written only by triggers and by `recordNotification()` in `_shared/fcm_utils.ts`, and purged after 24 hours by the `purge-expired-notifications` cron job. Chat (DMs, Chambers) is deliberately excluded from it.
- Live badges use `StreamProvider.autoDispose<int>` + a named Supabase channel with `onPostgresChanges` — see `unreadNotificationsCountProvider` and `pendingInvitationsCountProvider` in `providers.dart`. The table must be in the `supabase_realtime` publication or the badge only updates on manual refresh.

## Migrations

Canonical location is **`supabase/migrations/`**, named `YYYYMMDD_snake_case_feature.sql` (date only, no time component). Dates run ahead of real time; take the newest file and increment.

Every migration must be **re-runnable**: `CREATE TABLE IF NOT EXISTS`, `CREATE INDEX IF NOT EXISTS`, and `DROP POLICY IF EXISTS` before each `CREATE POLICY` (Postgres has no `CREATE POLICY IF NOT EXISTS`). Realtime opt-in goes behind a `pg_publication_tables` guard; `cron.schedule` goes behind `cron.unschedule` in a swallowing `BEGIN/EXCEPTION` block. Trigger bodies end with `EXCEPTION WHEN OTHERS THEN RAISE WARNING …; RETURN NEW;` so a notification failure can never block the business write.

**A new `SECURITY DEFINER` function in `public` is automatically exposed as a PostgREST RPC** at `/rest/v1/rpc/<name>` with EXECUTE granted to `anon` and `authenticated`. If it takes a user id as an argument, that is a forgery hole — `REVOKE ALL ON FUNCTION … FROM PUBLIC, anon, authenticated;` in the same migration. Run the Supabase security advisor after any DDL.

Three **non-canonical** SQL directories exist and must not be added to: `apps/dashboard/supabase/migrations/` (old Lovable output), `scripts/db/` (ad-hoc imports, plus a duplicate set of cron schedules that conflict with `supabase/migrations/20260908_notification_triggers.sql`), and `apps/mobile/migrations/`.

## Config and secrets

`EnvConfig` (`apps/mobile/lib/utils/env_config.dart`) reads `String.fromEnvironment` **with hardcoded production defaults**. Running `flutter run` without `--dart-define` therefore connects to the live Supabase project against real client data. Pass dart-defines deliberately.

Only the Supabase URL and anon key are client-side (the anon key is public and protected by RLS). The Gemini key lives as an edge-function secret and is reached through `gemini-proxy`.

## Web dashboard gotchas

`apps/dashboard/src/integrations/supabase/types.ts` is **stale** — it declares only 8 of ~68 tables, which is why helpers use `as any`. Do not trust it as the schema of record; the migrations are. `useRealtimeQuery.ts` and `usePaginatedQuery.ts` each take a closed union of table names that must be widened before subscribing to a new table.

## UI conventions

Mobile sizes everything through `flutter_screenutil` against a **390×844** baseline: `.sp` fonts, `.w`/`.h` dimensions, `.r` radii; global text scaling is clamped to 0.8×–1.15×. Colors come from `lib/theme/app_theme.dart` (`AppTheme.accent`, `.success`, `.warning`, `.error`, `shadowSm/Md/Lg`); typography is `GoogleFonts.outfit` for headings and `GoogleFonts.inter` for body, applied per call site rather than through a central `TextTheme`. Reuse `EmptyStateWidget`, `ErrorStateWidget`, `StatusBadge`, `ProfileAvatar`, and `NotificationBadge` rather than rebuilding them. `AppShell` adds no padding on mobile, so each screen supplies its own (16.w is typical).

The web design system is separate and deliberately different — `packages/design-system/tokens.css` is the single source of truth there, and its README forbids hardcoding palette colors (`text-success`, not `text-emerald-600`).

## CI

`.github/workflows/ci.yml` runs Flutter analyze + `flutter test`, a dashboard type-check and build, a Deno `deno check` of every edge function, and a hardcoded-API-key scan. Note that several steps swallow failures with `|| echo "::warning::…"` — formatting, dashboard ESLint, and the edge-function check cannot fail the build; `flutter test`, `npx tsc --noEmit`, the dashboard build, and the key scan can.

`build-apk.yml` builds the release APK on pushes to `main` only. All four workflows also expose `workflow_dispatch`. **Neither migrations nor edge functions are deployed by CI.**

Commits follow Conventional Commits with a scope: `feat(mobile):`, `fix(notifications):`, `ci:`, `chore:`.
