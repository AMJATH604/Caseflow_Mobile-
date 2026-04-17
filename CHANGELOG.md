# Changelog

All notable changes to the CaseFlow project are documented here.

## [2.0.0] — 2026-04-17

### 🏗️ Architecture
- **BREAKING**: Refactored monolithic `SupabaseService` (986 lines) into 10 domain-specific repositories
- Added Repository Pattern with Facade layer — zero UI breaking changes
- Created `BaseRepository` with shared auth guards, visibility filters, and profile caching
- Added barrel export file (`repositories.dart`) for clean imports

### ⚡ Performance
- **Profile Caching**: Implemented 5-minute TTL cache, eliminating N+1 query problem
- **Parallel Dashboard**: `fetchDashboardStats()` now uses `Future.wait()` (~3x faster)
- **Realtime Discussions**: Replaced 2-second polling with Supabase Realtime WebSockets
- **Pagination**: Added `limit`/`offset` support to Cases, Clients, Hearings repositories
- **Batch Operations**: Added batch upsert methods for eCourt dossier items

### 🔒 Security
- **CRITICAL**: Removed all third-party API keys from client binary
- Routed Gemini AI calls through `gemini-proxy` Edge Function
- Routed iLovePDF calls through `pdf-proxy` Edge Function
- Fixed `isPro`/`isBusiness` — now validates subscription tier + expiration from DB
- Removed hardcoded secrets from `secrets.dart` (only Supabase anon key remains)

### 🧪 Testing
- Added comprehensive model unit tests (7 model classes, 15+ test cases)
- Added `RetryHelper` unit tests
- Added `BaseRepository` unit tests (date normalization, visibility filters, cache)
- Added `EcourtParserService` fallback extraction tests

### 📝 Documentation
- Complete README rewrite with architecture diagrams and deployment guide
- Added CONTRIBUTING.md with developer onboarding guide
- Added CHANGELOG.md
- DartDoc comments on all repository classes

### 🛠️ DevOps
- Added GitHub Actions CI pipeline (`ci.yml`)
- Flutter analyze + test + format check
- Dashboard TypeScript check + build
- Deno check for all Edge Functions

## [1.0.0] — 2026-03-15

### Initial Release
- Full case lifecycle management
- eCourts CNR integration with scraping pipeline
- Commissioner report module with GPS evidence
- Hearing calendar with adjourn workflow
- Financial ledger with installment tracking
- Evidence Lab with SHA-256 photo hashing
- Legal Library (BNS, BNSS, CPC, Constitution)
- AI Legal Assistant (Gemini-powered)
- PDF Tools (compress, merge, convert)
- Firm management with member invitations
- FCM push notifications for hearing reminders
- React web dashboard with analytics
