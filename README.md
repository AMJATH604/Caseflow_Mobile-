# ⚖️ CaseFlow

> Production-grade legal practice management for Tamil Nadu district court advocates.

[![CI](https://github.com/AMJATH604/caseflow-flutter/actions/workflows/ci.yml/badge.svg)](https://github.com/AMJATH604/caseflow-flutter/actions)

## Overview

CaseFlow is a full-stack legal-tech platform designed specifically for Indian advocates practicing in Tamil Nadu district courts. It provides end-to-end case lifecycle management — from client onboarding and hearing scheduling to fee tracking, evidence documentation, and automated eCourts integration.

### Key Features

| Category | Features |
|----------|----------|
| **Case Management** | Full CRUD, CNR linking, stage tracking, case collaboration |
| **Hearing Calendar** | Smart scheduling, adjourn workflow, today's-hearings dashboard |
| **Financial Ledger** | Revenue/expense tracking, installments, case-level fee summary |
| **Evidence Lab** | Checklists, witness examination notes, GPS-tagged photos with SHA-256 hashing |
| **Commissioner Module** | Court-compliant commissioner reports with sketch tool, GPS evidence, bulk download |
| **eCourts Integration** | CNR scraping, hearing history sync, dossier (acts, IAs, interim orders) |
| **Legal Library** | Bare acts (BNS, BNSS, CPC, Constitution), stamp duty calculator, legal templates |
| **AI Assistant** | Gemini-powered legal research via server-side proxy |
| **PDF Tools** | Compress, merge, convert — via server-side iLovePDF proxy |
| **Firm Management** | Multi-advocate firms, member invitations, shared data visibility |
| **Notifications** | FCM push notifications for upcoming hearings (automated cron) |
| **Dashboard** | Real-time web dashboard with analytics and case overview |

## Architecture

```
caseflow/
├── apps/
│   ├── mobile/                  # Flutter mobile app (Android)
│   │   ├── lib/
│   │   │   ├── models/          # Data models with fromJson/toJson
│   │   │   ├── services/
│   │   │   │   ├── repositories/ # Domain-specific repositories ⭐
│   │   │   │   │   ├── base_repository.dart      # Profile cache, auth, visibility
│   │   │   │   │   ├── case_repository.dart       # Cases, dossier, search
│   │   │   │   │   ├── client_repository.dart     # Clients CRUD
│   │   │   │   │   ├── hearing_repository.dart    # Hearings, adjourn
│   │   │   │   │   ├── payment_repository.dart    # Payments, ledger
│   │   │   │   │   ├── evidence_repository.dart   # Evidence lab
│   │   │   │   │   ├── filing_repository.dart     # E-filing, certified copies
│   │   │   │   │   ├── content_repository.dart    # Acts, templates, tasks
│   │   │   │   │   ├── discussion_repository.dart # Realtime chat
│   │   │   │   │   └── repositories.dart          # Barrel export
│   │   │   │   ├── supabase_service.dart  # Thin facade (backward compat)
│   │   │   │   ├── providers.dart         # Riverpod state management
│   │   │   │   ├── retry_helper.dart      # Exponential backoff
│   │   │   │   └── fcm_service.dart       # Push notifications
│   │   │   ├── screens/          # UI screens
│   │   │   ├── components/       # Reusable widgets
│   │   │   └── utils/            # Helpers, env config, theme
│   │   └── test/                 # Unit tests
│   └── dashboard/               # React + Vite web dashboard
│       └── src/
│           ├── pages/           # Dashboard, Analytics, Settings
│           ├── components/      # Shadcn UI components
│           └── lib/             # Supabase client, utilities
├── supabase/
│   └── functions/
│       ├── send-hearing-reminders/  # Cron: FCM push for hearings
│       ├── gemini-proxy/            # Server-side Gemini API proxy ⭐
│       └── pdf-proxy/               # Server-side iLovePDF proxy ⭐
├── data/                        # Legal data (BNS, BNSS, CPC, etc.)
├── scripts/                     # Data migration & admin tools
└── .github/workflows/ci.yml    # CI pipeline ⭐
```

### Repository Pattern

The service layer follows the **Repository Pattern** with a **Facade**:

```
┌─────────────────────────────────┐
│      UI Screens / Providers     │
│  (unchanged — zero migration)   │
└──────────────┬──────────────────┘
               │ calls
┌──────────────▼──────────────────┐
│    SupabaseService (Facade)     │
│    ~270 lines, pure delegation  │
└──────────────┬──────────────────┘
               │ delegates to
┌──────────────▼──────────────────┐
│    Domain Repositories (9)      │
│    Single Responsibility each   │
└──────────────┬──────────────────┘
               │ uses
┌──────────────▼──────────────────┐
│    BaseRepository (Shared)      │
│    - Profile cache (5-min TTL)  │
│    - Auth guards                │
│    - Visibility filter builder  │
│    - Date normalization         │
└─────────────────────────────────┘
```

### Performance Optimizations

- **Profile caching**: `fetchProfile()` is cached with 5-minute TTL, eliminating the N+1 problem where it was called inside every data-fetching method
- **Parallel dashboard queries**: `fetchDashboardStats()` uses `Future.wait()` instead of serial await chains
- **Realtime discussions**: Replaced 2-second polling loop with Supabase Realtime WebSocket stream

### Security Model

- **Row Level Security (RLS)**: All tables protected by Supabase RLS policies
- **Firm visibility**: Users see their own data + firm data via OR-filter
- **Subscription gating**: `isPro`/`isBusiness` check actual tier + expiration date
- **API key isolation**: Gemini and iLovePDF keys stored as Supabase Edge Function secrets (never in client binary)
- **Evidence integrity**: SHA-256 hashing for commissioner evidence photos

## Quick Start

### Prerequisites

- Flutter 3.27+ with Android SDK
- Node.js 20+
- Supabase CLI (for Edge Functions)

### Mobile App

```bash
cd apps/mobile
flutter pub get
flutter run --dart-define=SUPABASE_URL=<url> --dart-define=SUPABASE_ANON_KEY=<key>
```

### Web Dashboard

```bash
cd apps/dashboard
npm install
npm run dev
```

### Edge Functions

```bash
# Deploy all functions
supabase functions deploy send-hearing-reminders
supabase functions deploy gemini-proxy
supabase functions deploy pdf-proxy

# Set secrets
supabase secrets set GEMINI_API_KEY=<key>
supabase secrets set ILOVEPDF_PUBLIC_KEY=<key>
supabase secrets set ILOVEPDF_SECRET_KEY=<key>
```

### NPM Scripts (from root)

```bash
npm run dashboard:dev     # Start dashboard dev server
npm run mobile:get        # Install Flutter deps
npm run upload-bnss       # Sync legal data to Supabase
npm run list-admins       # Check admin status
```

## Testing

```bash
cd apps/mobile
flutter test                    # Run all tests
flutter test --coverage         # With coverage report
flutter analyze                 # Static analysis
```

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Mobile | Flutter 3.27, Dart 3.7, Riverpod, GoRouter |
| Dashboard | React 18, TypeScript, Vite, Shadcn/UI, React Query |
| Backend | Supabase (PostgreSQL, Auth, Storage, Realtime, Edge Functions) |
| AI | Google Gemini 2.0 Flash (via Edge Function proxy) |
| PDF | iLovePDF API (via Edge Function proxy) |
| CI/CD | GitHub Actions |
| Notifications | Firebase Cloud Messaging (FCM v1 API) |

## License

This project is licensed under the MIT License. See the `LICENSE` file for details.