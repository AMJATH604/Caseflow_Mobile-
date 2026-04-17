# Contributing to CaseFlow

Thank you for your interest in contributing to CaseFlow! This guide will help you get started.

## 🛠️ Development Setup

### Prerequisites
- **Flutter** 3.27+ with Android SDK
- **Node.js** 20+ (for dashboard and Edge Functions)
- **Supabase CLI** (for deploying Edge Functions)
- **Git** 2.30+

### Getting Started

```bash
# 1. Clone the repository
git clone https://github.com/AMJATH604/Caseflow_Final.git
cd Caseflow_Final

# 2. Install mobile app dependencies
cd apps/mobile
flutter pub get

# 3. Install dashboard dependencies
cd ../dashboard
npm install

# 4. Run the mobile app (requires Supabase credentials)
cd ../mobile
flutter run --dart-define=SUPABASE_URL=<url> --dart-define=SUPABASE_ANON_KEY=<key>

# 5. Run the dashboard
cd ../dashboard
npm run dev
```

## 📁 Project Structure

```
caseflow/
├── apps/
│   ├── mobile/                  # Flutter mobile app
│   │   ├── lib/
│   │   │   ├── models/          # Data models (fromJson/toJson)
│   │   │   ├── services/
│   │   │   │   ├── repositories/ # ⭐ Domain repositories (all DB logic here)
│   │   │   │   ├── supabase_service.dart  # Thin facade (delegates to repos)
│   │   │   │   └── providers.dart         # Riverpod state management
│   │   │   ├── pages/           # UI screens
│   │   │   └── components/      # Reusable widgets
│   │   └── test/                # Unit & widget tests
│   └── dashboard/               # React + Vite web dashboard
├── supabase/functions/          # Edge Functions (Deno)
└── data/                        # Legal reference data
```

## 🏛️ Architecture Principles

### Repository Pattern
All database logic lives in `lib/services/repositories/`. Each domain has its own repository:

| Repository | Responsibility |
|-----------|---------------|
| `BaseRepository` | Auth guards, profile cache, visibility filters, date normalization |
| `CaseRepository` | Cases CRUD, dossier (acts, IAs, orders), search |
| `ClientRepository` | Client CRUD |
| `HearingRepository` | Hearings, adjourn workflow |
| `PaymentRepository` | Payments, ledger, installments |
| `EvidenceRepository` | Evidence checklists, witness notes, photos |
| `FilingRepository` | E-filing records, certified copies |
| `ContentRepository` | Bare acts, templates, documents, tasks |
| `DiscussionRepository` | Case discussions with Realtime |

### Rules
1. **Never add database logic to UI screens** — it belongs in a repository
2. **Never call Supabase directly from a screen** — use `SupabaseService` facade or a repository
3. **Never put API keys in client code** — use Edge Function proxies
4. **Always add `ref.watch(dataRefreshProvider)`** when creating new data providers

## 🧪 Testing

### Running Tests
```bash
cd apps/mobile
flutter test                    # Run all tests
flutter test --coverage         # With coverage report
flutter analyze                 # Static analysis
```

### Writing Tests
- **Model tests** go in `test/models/`
- **Service/Repository tests** go in `test/services/`
- **Widget tests** go in `test/widgets/`
- Test files must end with `_test.dart`

### Test Guidelines
1. Test `fromJson()` with complete and minimal inputs
2. Test edge cases (null fields, empty strings, expired dates)
3. Test business logic getters (`isPro`, `isBusiness`, `isFirmOwner`)
4. For repository tests, mock the Supabase client

## 🔒 Security Guidelines

1. **API Keys**: All third-party keys (Gemini, iLovePDF) must be Supabase Edge Function secrets
2. **Supabase Anon Key**: Safe for client — it's a public key protected by RLS
3. **secrets.dart**: Must ONLY contain Supabase URL and anon key
4. **RLS**: Every new table must have Row Level Security policies

## 🚀 Deployment

### Edge Functions
```bash
supabase functions deploy gemini-proxy
supabase functions deploy pdf-proxy
supabase functions deploy send-hearing-reminders

# Set secrets
supabase secrets set GEMINI_API_KEY=<key>
supabase secrets set ILOVEPDF_PUBLIC_KEY=<key>
supabase secrets set ILOVEPDF_SECRET_KEY=<key>
```

### Mobile APK
```bash
cd apps/mobile
flutter build apk --release \
  --dart-define=SUPABASE_URL=<url> \
  --dart-define=SUPABASE_ANON_KEY=<key>
```

## 📋 Pull Request Process

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Make your changes following the architecture principles above
4. Add tests for any new logic
5. Run `flutter analyze` and `flutter test` — both must pass
6. Submit a PR with a clear description of changes

## 📬 Questions?

Open an issue on GitHub or reach out to the maintainers.
