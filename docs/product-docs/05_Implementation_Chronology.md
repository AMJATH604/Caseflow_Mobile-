<p align="center">
  <img src="../../apps/mobile/assets/images/logo.png" width="90" alt="CaseFlow Logo" />
</p>

<h1 align="center">CaseFlow — Implementation Chronology & Order of Execution</h1>

<p align="center">
  <strong>Version 2.5 · Development Roadmap, Milestone Log & File Traceability</strong><br/>
  <em>Confidential — For Project Managers & Lead Architects</em>
</p>

---

## 1. Execution Overview & Timeline

CaseFlow was built iteratively following a **5-Phase Engineering Roadmap**, evolving from a basic case docket tracking utility into an enterprise legal tech platform.

```
┌────────────────────────────────────────────────────────────────────────┐
│                   CASEFLOW ENGINEERING TIMELINE                        │
├───────────────┬───────────────┬───────────────┬───────────────┬────────┤
│ Phase 1       │ Phase 2       │ Phase 3       │ Phase 4       │ Phase 5│
│ Core CRUD     │ Evidence Lab  │ Architecture  │ Responsive UI │ BarDesk│
│ & eCourts     │ & Calculators │ & Edge AI     │ & Offline     │ & Board│
│ (v1.0.0)      │ (v1.2 - v1.4) │ (v2.0.0)      │ (v2.1.0)      │(v2.5.0)│
├───────────────┼───────────────┼───────────────┼───────────────┼────────┤
│ Mar 2026      │ Apr 2026      │ May 2026      │ Jun 2026      │Jul 2026│
└───────────────┴───────────────┴───────────────┴───────────────┴────────┘
```

---

## 2. Detailed Phase Breakdown & Order of Execution

### Phase 1: Core Foundation & Case Management (`v1.0.0` · March 2026)
* **Goal:** Deliver basic case tracking, client records, and daily hearing reminders.
* **Key Implementation Steps:**
  1. Configured Supabase Auth with PKCE and user role management (`profiles`).
  2. Built `cases`, `clients`, `hearings`, `documents`, and `payments` tables with basic RLS policies.
  3. Developed core Flutter mobile pages: `dashboard_screen.dart`, `cases_screen.dart`, `hearings_screen.dart`, `clients_screen.dart`.
  4. Implemented eCourts scraper and CNR linking pipeline (`ecourt_parser_service.dart`).
  5. Configured Firebase Cloud Messaging for basic push notifications (`fcm_service.dart`).

### Phase 2: Evidence Lab, Commissioner Module & Legal Library (`v1.2.0–v1.4.0` · April 2026)
* **Goal:** Enable digital courtroom evidence gathering and offline legal reference tools.
* **Key Implementation Steps:**
  1. Built Evidence Lab with live EXIF GPS overlay and local SHA-256 image hashing.
  2. Implemented Local Commissioner module: field visit logs, vector canvas sketch tool (`commission_sketch_screen.dart`), and witness audio recordings.
  3. Integrated Bare Acts library (BNS, BNSS, BSA, CPC, Constitution, DVC, NI Act, Motor Vehicles Act, Specific Relief Act).
  4. Built 8 interactive calculators: Court Fee, Stamp Duty, Limitation Period, MACT, Maintenance, Partition, Interest, and Delay.

### Phase 3: Architecture Refactoring, Security & Edge Proxies (`v2.0.0` · May 2026)
* **Goal:** Eliminate technical debt, secure third-party keys, and optimize state management.
* **Key Implementation Steps:**
  1. **Monolith Refactoring:** Decomposed 986-line `SupabaseService` into 10 domain-specific repositories extending `BaseRepository`.
  2. **Security Hardening:** Removed client-side Gemini and iLovePDF keys; routed queries through `gemini-proxy` and `pdf-proxy` Deno Edge Functions.
  3. **Performance Optimization:** Added 5-minute TTL profile caching and `Future.wait()` parallel dashboard queries.
  4. **CI/CD Pipeline:** Configured GitHub Actions workflows (`build-apk.yml`, `ci.yml`).

### Phase 4: Responsive UI Engine & Offline-First Cache (`v2.1.0` · June 2026)
* **Goal:** Guarantee multi-device layout integrity and courtroom offline operation.
* **Key Implementation Steps:**
  1. **ScreenUtil Migration:** Converted 110+ UI widgets to `flutter_screenutil` using `390×844dp` design baseline.
  2. **Text Scaling Guard:** Clamped global text scale factor between `0.8x` and `1.15x`.
  3. **SQLite Offline Cache:** Built `OfflineCacheService` using `sqflite` for offline read capability with automatic network sync.

### Phase 5: Bar Association Module & Case Strategy Board (`v2.5.0` · July 2026)
* **Goal:** Enable bar community governance and collaborative Kanban task management.
* **Key Implementation Steps:**
  1. **BarDesk Platform:** Built digital membership card generator with QR verification, election module, voter hash function, notices, and events.
  2. **Case Strategy Board:** Created `strategy_tasks`, `task_comments`, `task_attachments`, `task_activity_log` tables with full RLS and Realtime subscriptions.

---

## 3. File Traceability Matrix

| Module | Core Logic & Repositories | UI Screens & Dialogs | Database / Edge Assets |
|:---|:---|:---|:---|
| **Case Management** | `case_repository.dart` | `cases_screen.dart`<br/>`case_detail_screen.dart` | `20260211102617_*.sql` |
| **Court Diary** | `hearing_repository.dart` | `hearings_screen.dart`<br/>`dashboard_court_diary.dart` | `send-hearing-reminders/` |
| **Strategy Board** | `strategy_repository.dart` | `case_strategy_tab.dart`<br/>`strategy_task_sheet.dart` | `20260729_strategy_board.sql` |
| **Evidence Lab** | `evidence_repository.dart` | `evidence_lab_screen.dart`<br/>`commission_sketch_screen.dart` | `commission-evidence` bucket |
| **AI Assistant** | `gemini_service.dart` | `ai_chat_screen.dart` | `gemini-proxy/index.ts` |
| **Bar Association** | `bar_association_repository.dart` | `bar_association_home_screen.dart`<br/>`bar_election_screen.dart` | `20260627_bar_association_tables.sql` |

---

## 4. Verification Checklist & Future Roadmap (v3.0.0)

* [x] **100% RLS Coverage:** All 38 database tables protected by Row Level Security policies.
* [x] **Zero Secret Leaks:** Gemini and iLovePDF API keys isolated in Deno secret storage.
* [x] **Responsive Adaptation:** Tested on 320dp to 430dp+ physical devices.
* [ ] **v3.0.0 Objective (Q4 2026):** High Court eFiling direct API integration and automated AI draft generation.

---

<p align="center">
  <em>End of Implementation Chronology · CaseFlow Engineering Group</em>
</p>
