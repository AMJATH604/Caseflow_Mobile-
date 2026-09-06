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
  <a href="https://github.com/AMJATH604/Caseflow_Final/actions/workflows/build-ipa.yml">
    <img src="https://github.com/AMJATH604/Caseflow_Final/actions/workflows/build-ipa.yml/badge.svg" alt="Build IPA" />
  </a>
  <a href="https://github.com/AMJATH604/Caseflow_Final/actions/workflows/ci.yml">
    <img src="https://github.com/AMJATH604/Caseflow_Final/actions/workflows/ci.yml/badge.svg" alt="CI" />
  </a>
  <img src="https://img.shields.io/badge/Flutter-3.29+-02569B?logo=flutter&logoColor=white" alt="Flutter" />
  <img src="https://img.shields.io/badge/Platforms-Android%20%7C%20iOS-brightgreen" alt="Platforms" />
  <img src="https://img.shields.io/badge/Supabase-Backend-3FCF8E?logo=supabase&logoColor=white" alt="Supabase" />
  <img src="https://img.shields.io/badge/Gemini_AI-Powered-4285F4?logo=google&logoColor=white" alt="Gemini AI" />
  <img src="https://img.shields.io/badge/License-MIT-blue" alt="License" />
</p>

<p align="center">
  <em>Production-grade mobile app powering legal case lifecycle management on Android and iOS — from client onboarding to court hearings, evidence documentation, and AI-driven legal research.</em>
</p>

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
| **PDF Tools** | Compress, merge, convert, OCR — via server-side iLovePDF proxy |
| **Broadcast** | Push notices to all firm members |
| **Certified Copies** | Digital request tracking with status workflow |
| **Legal Pulse** | Curated legal news feed |

---

## 🏗️ Architecture

```
caseflow/
├── apps/
│   └── mobile/                     # Flutter mobile app (Android & iOS)
│       ├── lib/
│       │   ├── models/             # Data models (fromJson / toJson)
│       │   ├── services/
│       │   │   ├── repositories/   # Domain repositories (10 modules)
│       │   │   ├── supabase_service.dart   # Facade pattern
│       │   │   ├── providers.dart          # Riverpod state management
│       │   │   └── fcm_service.dart        # Push notifications (FCM & APNs)
│       │   ├── pages/              # 36+ screens
│       │   ├── components/         # 40+ reusable widgets
│       │   ├── theme/              # App theme system
│       │   └── utils/              # Responsive utilities, config
│       ├── android/                # Android platform config (Gradle, services)
│       └── ios/                    # iOS platform config (Xcode, Podfile, APNs)
├── supabase/
│   └── functions/
│       ├── send-hearing-reminders/ # Cron: automated FCM push
│       ├── gemini-proxy/           # Server-side Gemini API proxy
│       └── pdf-proxy/              # Server-side iLovePDF proxy
├── data/                           # Legal datasets (bare acts JSON)
├── docs/                           # Store listings & setup guides
│   ├── play-store-listing.md       # Google Play Store listing
│   ├── app-store-listing.md        # Apple App Store listing
│   └── ios-firebase-setup.md       # iOS Firebase & APNs guide
├── scripts/                        # DB migrations & admin tools
└── .github/workflows/
    ├── build-apk.yml               # CI/CD: build release APKs
    ├── build-ipa.yml               # CI/CD: build release iOS IPA
    └── ci.yml                      # CI: analyze, test, lint, iOS build check
```

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
- **API key isolation** — Gemini & iLovePDF keys stored as Edge Function secrets, never in client binary
- **Evidence integrity** — SHA-256 hashing for commissioner evidence photos
- **Subscription gating** — Server-validated tier + expiration checks
- **Firm visibility** — OR-filter ensures users see own + firm data only

---

## 🚀 Quick Start

### Prerequisites

| Tool | Version | Notes |
|------|---------|-------|
| Flutter | ≥ 3.29 | Stable channel |
| Dart | ≥ 3.7 | Included with Flutter |
| Android SDK | API 21+ | For Android builds |
| Xcode | ≥ 15.0 | For iOS builds (macOS only) |
| CocoaPods | ≥ 1.14 | `sudo gem install cocoapods` |
| Node.js | ≥ 20 | For scripts & dashboard |
| Supabase CLI | Latest | For Edge Functions |

### Setup

```bash
# Clone the repository
git clone https://github.com/AMJATH604/Caseflow_Final.git
cd Caseflow_Final

# Install Flutter dependencies
cd apps/mobile
flutter pub get

# Install iOS CocoaPods (macOS only)
cd ios && pod install && cd ..

# Run on connected device / simulator (with Supabase config)
flutter run \
  --dart-define=SUPABASE_URL=<your-url> \
  --dart-define=SUPABASE_ANON_KEY=<your-key>
```

### Building Releases

```bash
# ── Android (APKs) ──
flutter build apk --release --split-per-abi \
  --dart-define=SUPABASE_URL=<url> \
  --dart-define=SUPABASE_ANON_KEY=<key>

# ── iOS (Unsigned Release / Simulator / Test) ──
flutter build ios --release --no-codesign \
  --dart-define=SUPABASE_URL=<url> \
  --dart-define=SUPABASE_ANON_KEY=<key>

# ── iOS (Signed Archive / App Store / TestFlight) ──
flutter build ipa --release \
  --dart-define=SUPABASE_URL=<url> \
  --dart-define=SUPABASE_ANON_KEY=<key>
```

### Edge Functions

```bash
# Deploy serverless functions
supabase functions deploy send-hearing-reminders
supabase functions deploy gemini-proxy
supabase functions deploy pdf-proxy

# Set secrets
supabase secrets set GEMINI_API_KEY=<key>
supabase secrets set ILOVEPDF_PUBLIC_KEY=<key>
supabase secrets set ILOVEPDF_SECRET_KEY=<key>
```

---

## 🧪 Testing & CI/CD

```bash
flutter test              # Run unit tests
flutter test --coverage   # With coverage report
flutter analyze           # Static analysis
```

### Automated Pipeline

- **CI Workflow (`ci.yml`)**: Triggered on pull requests and pushes to `main`/`develop`. Runs code analysis, unit tests, web dashboard build, edge function typecheck, security audit, and iOS build verification.
- **Android Release Pipeline (`build-apk.yml`)**: Builds split and fat release APKs, attaches them to GitHub Releases on version tag (`v*`), and publishes to Firebase App Distribution.
- **iOS Release Pipeline (`build-ipa.yml`)**: Builds unsigned/signed iOS app bundle and IPA on macOS runners, and publishes IPA artifacts on version tag (`v*`).

---

## 🛠️ Tech Stack

| Layer | Technology |
|-------|-----------|
| **Mobile** | Flutter 3.29 · Dart 3.7 · Riverpod · GoRouter · ScreenUtil |
| **Backend** | Supabase (PostgreSQL · Auth · Storage · Realtime · Edge Functions) |
| **AI** | Google Gemini 2.0 Flash (server-side proxy) |
| **PDF Engine** | iLovePDF API (server-side proxy) |
| **Notifications** | Firebase Cloud Messaging (FCM v1 HTTP API) |
| **Analytics** | Firebase Analytics · Crashlytics |
| **CI/CD** | GitHub Actions (auto-build APK on push) |
| **Responsive UI** | flutter_screenutil (390×844 baseline) |

---

## 📄 License

This project is licensed under the **MIT License**. See [LICENSE](LICENSE) for details.

---

<p align="center">
  <sub>Built with ❤️ for the Indian legal community</sub>
</p>