<p align="center">
  <img src="apps/mobile/assets/images/logo.png" width="80" alt="CaseFlow Logo" />
</p>

<h1 align="center">CaseFlow</h1>

<p align="center">
  <strong>Intelligent Legal Practice Management for Indian Advocates</strong>
</p>

<p align="center">
  <a href="https://github.com/AMJATH604/Caseflow_Final/actions/workflows/build-apk.yml">
    <img src="https://github.com/AMJATH604/Caseflow_Final/actions/workflows/build-apk.yml/badge.svg" alt="Build APK" />
  </a>
  <a href="https://github.com/AMJATH604/Caseflow_Final/actions/workflows/ci.yml">
    <img src="https://github.com/AMJATH604/Caseflow_Final/actions/workflows/ci.yml/badge.svg" alt="CI" />
  </a>
  <img src="https://img.shields.io/badge/Flutter-3.29+-02569B?logo=flutter&logoColor=white" alt="Flutter" />
  <img src="https://img.shields.io/badge/React-Vite-61DAFB?logo=react&logoColor=black" alt="React" />
  <img src="https://img.shields.io/badge/Supabase-Backend-3FCF8E?logo=supabase&logoColor=white" alt="Supabase" />
  <img src="https://img.shields.io/badge/Gemini_AI-Powered-4285F4?logo=google&logoColor=white" alt="Gemini AI" />
  <img src="https://img.shields.io/badge/License-MIT-blue" alt="License" />
</p>

<p align="center">
  <em>Production-grade monorepo powering legal case lifecycle management — from client onboarding to court hearings, evidence documentation, and AI-driven legal research.</em>
</p>

---

## Overview

CaseFlow is a **monorepo** containing a mobile app, web dashboard, and shared packages — all backed by Supabase and designed specifically for the Indian legal ecosystem.

---

## ✨ Features

<table>
<tr>
<td width="50%">

### 📋 Case Management
- Full CRUD with CNR linking & stage tracking
- Case collaboration across firm members
- eCourts integration with hearing history sync
- Smart case dossier (acts, IAs, interim orders)

### 📅 Hearing Calendar
- Smart scheduling with court-aware date picker
- Adjourn workflow with reason tracking
- Today's-hearings dashboard with quick actions
- Automated FCM push reminders (cron-based)

### 💰 Financial Ledger
- Revenue & expense tracking per case
- Installment management with due dates
- ePay court fee integration
- Payment receipt generation (PDF)

</td>
<td width="50%">

### 🔬 Evidence Lab
- Witness examination notes
- GPS-tagged evidence photos with SHA-256 hashing
- Commissioner reports with sketch tool
- Bulk evidence download & export

### 🤖 AI Legal Assistant
- Gemini 2.0 Flash powered research
- Server-side proxy (API keys never on device)
- Context-aware legal Q&A

### 📚 Legal Library
- Full bare acts: BNS, BNSS, BSA, CPC, Constitution, DVC, NI Act, Motor Vehicles Act, Specific Relief Act
- Stamp duty & court fee calculators
- Legal templates & dictionaries
- Know Your Rights citizen guide

</td>
</tr>
</table>

### Additional Capabilities

| Module | Description |
|--------|-------------|
| **Firm Management** | Multi-advocate firms, member invitations, shared data visibility |
| **Chambers Chat** | Real-time firm-wide messaging with Supabase Realtime |
| **Direct Messages** | WhatsApp-style advocate-to-advocate chat with attachments |
| **Bar Association** | Membership cards, elections, notices, events, fee payments |
| **Citizen Portal** | Case tracking, legal tools, and Know Your Rights for citizens |
| **Broadcast** | Push notices to all firm members |
| **Certified Copies** | Digital request tracking with status workflow |
| **Legal Pulse** | Curated legal news feed |

---

## 🏗️ Monorepo Structure

```
caseflow/
├── apps/
│   ├── mobile/                  # Flutter mobile app (Android + iOS)
│   │   ├── lib/
│   │   │   ├── models/          # Data models (fromJson / toJson)
│   │   │   ├── services/
│   │   │   │   ├── repositories/  # Domain repositories (10 modules)
│   │   │   │   ├── supabase_service.dart
│   │   │   │   ├── providers.dart
│   │   │   │   └── fcm_service.dart
│   │   │   ├── pages/           # 36+ screens
│   │   │   ├── components/      # 40+ reusable widgets
│   │   │   ├── theme/           # App theme system
│   │   │   └── utils/           # Responsive utilities, config
│   │   └── android/             # Android platform config
│   │
│   ├── dashboard/               # Vite + React web dashboard
│   │   ├── src/
│   │   └── tests/
│   │
│   └── bardesk/                 # BarDesk web app (Vite + React)
│       └── src/
│
├── packages/
│   ├── design-system/           # Shared UI tokens & Tailwind preset
│   │   ├── tokens.css
│   │   └── tailwind.preset.ts
│   │
│   └── legal-fixtures/          # Shared legal data & JSON fixtures
│       ├── data/
│       │   ├── legal/           # Bare acts (BNS, BSA, CPC, etc.)
│       │   └── aggregates/      # Pre-processed dashboard data
│       ├── ecourts_case_number.json
│       └── ni_act_court_fee.json
│
├── supabase/
│   ├── migrations/              # Database migrations
│   └── functions/
│       ├── send-hearing-reminders/  # Cron: automated FCM push
│       └── gemini-proxy/            # Server-side Gemini API proxy
│
├── scripts/                     # DB migrations & admin tools
│   ├── db/                      # SQL migration scripts
│   └── tools/                   # Utility scripts
│
├── docs/
│   ├── product/                 # PRD, TRD, design briefs
│   ├── store-listings/          # App Store & Play Store copy
│   └── legal/                   # Privacy policy, terms
│
└── .github/workflows/
    ├── build-apk.yml            # CI/CD: auto-build release APK
    └── ci.yml                   # CI: analyze, test, lint
```

---

## 🧩 Architecture

### Service Layer — Repository Pattern

```
┌─────────────────────────────────┐
│      UI Screens / Providers     │
│     (36 screens, 40+ widgets)   │
└──────────────┬──────────────────┘
               │ calls
┌──────────────▼──────────────────┐
│    SupabaseService (Facade)     │
│     Thin delegation layer       │
└──────────────┬──────────────────┘
               │ delegates to
┌──────────────▼──────────────────┐
│  Domain Repositories (10)       │
│  Cases · Clients · Hearings     │
│  Payments · Evidence · Filing   │
│  Content · Discussion · DM      │
│  Profile · Bar Association      │
└──────────────┬──────────────────┘
               │ extends
┌──────────────▼──────────────────┐
│    BaseRepository (Shared)      │
│  • Profile cache (5-min TTL)    │
│  • Auth guards & RLS filters    │
│  • Firm visibility builder      │
└─────────────────────────────────┘
```

### Responsive UI System

All screens use `flutter_screenutil` with a `390×844` design baseline:

- **Font sizes** → `.sp` (scale to screen width)
- **Widths** → `.w` / **Heights** → `.h` (proportional scaling)
- **Border radius** → `.r` (proportional scaling)
- **Text scaling** → Clamped to `0.8×–1.15×` globally

Tested across screen widths from 320dp (budget phones) to 430dp+ (flagships).

---

## ⚡ Performance

| Optimization | Impact |
|-------------|--------|
| **Profile caching** | 5-min TTL eliminates N+1 query problem |
| **Parallel dashboard** | `Future.wait()` loads stats ~3× faster |
| **Realtime chat** | WebSocket stream replaces 2s polling loop |
| **Pagination** | Limit/offset on all list screens |
| **Offline cache** | SQLite-backed offline data access |
| **Image optimization** | Cached network images with placeholder shimmer |

---

## 🔒 Security

- **Row Level Security (RLS)** on all Supabase tables
- **API key isolation** — the Gemini key is stored as an Edge Function secret, never in client binary
- **Evidence integrity** — SHA-256 hashing for commissioner evidence photos
- **Subscription gating** — Server-validated tier + expiration checks
- **Firm visibility** — OR-filter ensures users see own + firm data only

---

## 🚀 Quick Start

### Prerequisites

| Tool | Version |
|------|---------|
| Flutter | ≥ 3.29 |
| Dart | ≥ 3.7 |
| Node.js | ≥ 20 |
| Android SDK | API 21+ |
| Supabase CLI | Latest |

### Setup

```bash
# Clone the repository
git clone https://github.com/AMJATH604/Caseflow_Final.git
cd Caseflow_Final

# ─── Mobile App ───────────────────────────
cd apps/mobile
flutter pub get
flutter run \
  --dart-define=SUPABASE_URL=<your-url> \
  --dart-define=SUPABASE_ANON_KEY=<your-key>

# ─── Web Dashboard ───────────────────────
cd apps/dashboard
npm install
npm run dev

# ─── Edge Functions ───────────────────────
supabase functions deploy send-hearing-reminders
supabase functions deploy gemini-proxy
supabase secrets set GEMINI_API_KEY=<key>
```

---

## 🧪 Testing & CI/CD

```bash
# Mobile
cd apps/mobile
flutter test
flutter test --coverage
flutter analyze

# Dashboard
cd apps/dashboard
npm run test
npx playwright test
```

### Automated Pipeline

Every push to `main` triggers:
1. **Code Analysis** — `flutter analyze`
2. **Release APK Build** — Signed, optimized production binary
3. **Artifact Upload** — Downloadable from GitHub Actions (30-day retention)
4. **Firebase Distribution** — Auto-deploy to testers (when configured)

---

## 🛠️ Tech Stack

| Layer | Technology |
|-------|-----------|
| **Mobile** | Flutter 3.29 · Dart 3.7 · Riverpod · GoRouter · ScreenUtil |
| **Web** | React · Vite · TypeScript · Tailwind CSS · Capacitor |
| **Backend** | Supabase (PostgreSQL · Auth · Storage · Realtime · Edge Functions) |
| **AI** | Google Gemini 2.0 Flash (server-side proxy) |
| **Notifications** | Firebase Cloud Messaging (FCM v1 HTTP API) |
| **Analytics** | Firebase Analytics · Crashlytics |
| **CI/CD** | GitHub Actions (auto-build APK on push) |
| **Design System** | Shared tokens + Tailwind preset across web apps |

---

## 📄 License

This project is licensed under the **MIT License**. See [LICENSE](LICENSE) for details.

---

<p align="center">
  <sub>Built with ❤️ for the Indian legal community</sub>
</p>