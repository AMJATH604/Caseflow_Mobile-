# CaseFlow Web — parity with the Flutter app

Every screen, tool and in-screen feature of `apps/mobile`, and where it lives
on the web. **Nothing may be dropped silently:** a mobile feature is either
mapped below or listed under *Deliberately not on the web*, with the reason.

Inventory taken from `apps/mobile/lib` — 41 routes, 83 screen files,
37 tool entries, and every dialog, sheet and tab under `components/`.

Legend: ✅ built · 🔨 in progress · ⬜ not started · Phase = build order
(1 Foundation · 2 Daily work · 3 Office · 4 Tools · 5 Team · 6 Rest)

Users: **advocate**, **junior**, **clerk**. Clerk permissions (agreed):
add/edit cases, hearings, clients; adjourn; Court Diary; eCourts import;
upload documents. Clerks do **not** see fees/payments, cannot delete cases,
cannot manage the team.

---

## Phase 1 — Foundation

| Mobile | Web | Status |
| --- | --- | --- |
| `login_screen` — sign in, sign up (advocate fields, state/district, password policy), role gate | `/login`, `/signup` | ✅ |
| `password_reset_sheet` | `/forgot-password`, `/reset-password` | ✅ |
| `app_localizations` — English / Tamil | i18n, same Tamil wording (extracted) | ✅ |
| `settings` → theme (light/dark) | user menu + command bar, plus "system" | ✅ |
| `app_shell`, `app_sidebar`, `mobile_bottom_nav`, `mobile_more_sheet` | sidebar + top bar + drawer | ✅ |
| `global_search_delegate` | command bar (Ctrl/⌘+K) — pages now, cases in Phase 2 | 🔨 |
| `BaseRepository` visibility filter, profile verification | `lib/visibility.ts`, `AuthProvider` | ✅ |
| `password_policy.dart` | `auth/passwordPolicy.ts` | ✅ |
| Legal rules shared with web | `packages/legal-fixtures` (court fee, case number) | ✅ |

## Phase 2 — Daily work

| Mobile | Web | Status |
| --- | --- | --- |
| `dashboard_screen` — greeting, KPI cards (`kpi_card`), Jump To, Quick Actions | `/` | ⬜ |
| `daily_board_widget`, `task_widget` (Daily Tasks) | `/` | ⬜ |
| `dashboard_court_diary` — month calendar, day list, Adjourn, Delete | `/diary` | ⬜ |
| `quick_adjourn_sheet`, `hearing_notes_dialog` | `/diary`, `/hearings` | ⬜ |
| `cases_screen` — server search, status counts, filters, sort, grid/list | `/cases` (table) | ⬜ |
| `case_detail_screen`, `case_header` | `/cases/:id` (split view) | ⬜ |
| ↳ `case_dossier_tab` + `dossier/*` — acts, history, human capital, IAs, interim orders, party intelligence | `/cases/:id` | ⬜ |
| ↳ `case_timeline_tab`, `case_witnesses_tab`, `case_documents_tab` | `/cases/:id` | ⬜ |
| ↳ `case_discussion_tab` | `/cases/:id` | ⬜ |
| ↳ `case_payments_tab` (hidden from clerks) | `/cases/:id` | ⬜ |
| ↳ `case_strategy_tab`, `strategy_task_card/sheet`, `strategy_create_dialog` | `/cases/:id` | ⬜ |
| `new_case_dialog`, `case_conflict_dialog` (duplicate-case rule), `case_picker_field` | New case (Quick Action, `N`) | ⬜ |
| `hearings_screen`, `schedule_hearing_dialog` | `/hearings` | ⬜ |
| `clients_screen`, `add_client_dialog`, `edit_client_dialog`, `client_detail_sheet` | `/clients` | ⬜ |
| `profile_detail_sheet`, `profile_avatar` | user menu → profile | ⬜ |

## Phase 3 — Office

| Mobile | Web | Status |
| --- | --- | --- |
| `case_import_export_screen` — eCourts .txt import, side selection, case-number decoding, export PDF/JSON, backup restore | `/import` (+ bulk select) | ⬜ |
| `payments_screen`, `log_payment_dialog`, `payment_capture_overlay` | `/payments` (not clerks) | ⬜ |
| `caveats_screen`, `caveat_form_sheet` | `/caveats` | ⬜ |
| `certified_copies_screen`, `log_cc_dialog` | `/certified-copies` | ⬜ |
| `portals_screen`, `epay_court_fee_sheet` (eCourts ePay) | `/portals` | ⬜ |
| `notifications_screen`, `notification_badge` (live count) | `/notifications`, bell | ⬜ |

## Phase 4 — Legal tools (`/tools`)

Each calculator joins `packages/legal-fixtures` before it ships.

| Mobile tool | Status |
| --- | --- |
| Court fee (`court_fee_calculator`) — incl. §138 current/legacy columns, writ 226/227 | ⬜ |
| Limitation (`limitation_calculator`) | ⬜ |
| Delay condonation (`delay_calculator`) | ⬜ |
| Interest (`interest_calculator`) | ⬜ |
| Partition shares + family tree (`partition_calculator`, `partition_tree`) — Hindu, Hanafi | ⬜ |
| Stamp duty (`stamp_duty_calculator`) | ⬜ |
| Stamp values (`stamp_value_screen`) | ⬜ |
| MACT compensation (`mact_calculator`) | ⬜ |
| Maintenance (`maintenance_calculator`) | ⬜ |
| Bare Acts (`bare_acts_screen`) | ⬜ |
| Legal dictionary, English dictionary | ⬜ |
| Legal templates (`legal_templates_screen`) | ⬜ |
| Court holiday list (`court_holiday_list`) | ⬜ |

## Phase 5 — Team & practice tools

| Mobile | Web | Status |
| --- | --- | --- |
| `firm_management_screen` — juniors; **new: clerk role** (backend + RLS) | `/firm` (advocates) | ⬜ |
| `collaborator_invitations_screen` (firm + case invitations) | `/invitations` | ⬜ |
| `associate_hub` (Recruit Associate) | `/recruit` (advocates) | ⬜ |
| `broadcast_node`, `chambers_chat_screen`, `chambers_members_sheet` (Digital Chambers) | `/chambers` | ⬜ |
| `chat_hub_screen`, `dm_chat_screen`, `chat/*` (replies, forward, attachments, voice, images, video, typing) | `/messages` | ⬜ |
| `advocate_directory_screen` | `/directory` | ⬜ |
| `cross_exam_sessions_screen`, `cross_exam_detail_screen` | `/cross-exam` | ⬜ |
| `evidence_lab_screen` | `/evidence` | ⬜ |
| `commissions_screen`, `commission_detail/field_visit/report/sketch/witness_screen`, `commission/*` tabs | `/commissions` | ⬜ |

## Phase 6 — The rest

| Mobile | Web | Status |
| --- | --- | --- |
| `ai_chat_screen`, `ai_chat/*` (drawer, GenUI cards, markdown, file preview) | `/ai` | ⬜ |
| `legal_pulse_screen` | `/legal-pulse` | ⬜ |
| Document tools — prepare e-filing, scan, images→PDF, merge, split, organize, rotate, page numbers, sign, edit, watermark, compare, compress, protect, unlock, repair, PDF→JPG; server: Word→PDF, OCR, PDF→Word/Excel, Excel/PPT→PDF; `save_to_case_sheet` | `/documents` | ⬜ |
| `bar_association/*` — home, notices, events, fee payment, membership card | `/bar` | ⬜ |
| `settings_screen` — notifications prefs, data & storage, privacy, help, feedback (`feedback_sheet`), `reset_workspace_dialog` | `/settings` | ⬜ |
| `upgrade_screen`, `upgrade_plan_dialog` (plans) | `/settings` → plan | ⬜ |
| Push notifications (FCM) | browser notifications (needs Firebase web config) | ⬜ |

---

## Deliberately not on the web

| Mobile | Why |
| --- | --- |
| `splash_screen`, `onboarding_screen` | Phone launch flow. The web opens straight to sign-in. |
| `role_selection_screen` | Chooses advocate vs citizen. The web is for advocates and their teams only; `/signup` registers an advocate. |
| Citizen portal — `citizen_home_screen`, `citizen_tools_screen`, `citizen_bottom_nav`, `track_case_screen`, `know_your_rights_screen`, guest routes (`/guest-*`, `/citizen-*`, `/track-case`, `/know-your-rights`) | Citizens are not web users (agreed users: advocate, junior, clerk). A citizen signing in on the web is told to use the mobile app. **Note for Phase 6:** AI GenUI cards link to `/track-case` and `/know-your-rights`; those links must be handled on the web. |
| `quick_action_fab` | A phone pattern; the web has Quick Actions on the dashboard and keyboard shortcuts. |
| `screen_back_button`, `pinned_header_delegate`, `paginated_list_view` | Phone navigation/layout mechanics; the browser and web tables cover them. |
| Camera document scanner (`doc_scan`) | Already hidden on mobile web (`kIsWeb`); desktop upload replaces it. |
| Offline cache (`offline_cache_service`) | Phone-specific; revisit if offline web use is needed. |
