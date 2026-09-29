# Changelog

All notable changes to the CaseFlow project are documented here.

## [Unreleased]

### ☁️ Convert & OCR (mobile, via the CaseFlow document server)
- New **Convert & OCR** tools, shown when the build has `DOC_TOOLS_API_URL` (CI: repository variable `DOC_TOOLS_API_URL`):
  - **Word, Excel, PowerPoint to PDF** (Tamil and Hindi text kept), **OCR** (English, Tamil, Hindi; straightens scans), **Compress** (shows the saving)
  - **PDF to Word**, **PDF to Excel**, **Protect**, **Unlock**, **Repair**
- **Prepare for e-Filing** can now OCR its scanned documents and rebuild, so the filing is searchable. OCR runs on the documents, not the numbered filing, whose page numbers would hide scanned pages.
- Jobs send the user's sign-in token (per-user limits on the server) and are deleted from the server as soon as the result is downloaded; upload/processing/download progress with Cancel
- Results can be Word or Excel files as well as PDFs: open, share, save, rename and save-to-case keep the right type
- Removed the placeholder Word to PDF screen (it only waited 3 seconds) and the unused on-device OCR screen, together with the `google_mlkit_text_recognition` package and its bundled models

- Guided flow from a case's **Documents** tab (saves straight into that case) or the **Prepare e-Filing** tile in Tools
- Collect documents in filing order from PDFs, the camera scanner, photos or the case's existing files; name each (Plaint, Vakalatnama, Affidavit…)
- **Tamil Nadu District Courts** preset (eCourts eFiling 3.0): A4, 3.5 cm left / 2.5 cm other margins, page numbers bottom centre
- Builds one court-ready PDF: pages fitted to A4 (optionally shrunk into the court margins, correct on rotated pages), an **index page** in Times New Roman with each document's page range, page numbers matching the index, and a **bookmark** per document
- Stays under the portal's size limit (20 MB by default, editable) by splitting into as few files as possible, each with its own index
- **e-Filing check**: A4, file size, scanned pages without searchable text (OCR arrives with the server tools), numbering, bookmarks, digitally signed inputs, margins
- Shows the rows for the portal's **Pleadings › Indexing** form (Index Title / From / To) per file, with Copy

- New **Document Tools** section in the Tools tab, free for every plan, running on the device (files leave the phone only when saved to a case or shared):
  - **Scan to PDF**: camera scanner with automatic edge detection (ML Kit on Android, VisionKit on iOS)
  - **Images to PDF**: photos and WhatsApp images, one per page; orientation fixed, 200/300 DPI, grey or colour, A4 or image size
  - **Merge**, **Split** (pick pages, one file per range, every N pages), **Organize** (reorder, delete, rotate), **Rotate**
  - **Page Numbers** in Times New Roman: bottom centre/right or top right, skip cover pages, custom start
- Every result can be opened, shared, saved to the phone, renamed or **saved to a case's Documents** (never overwrites an existing document)
- PDF engine: `syncfusion_flutter_pdf` (Community Licence) behind `lib/services/document_tools/`, run in background isolates; thumbnails via `printing`

## [1.6.0] — 2026-07-05

### 🎨 Responsive UI
- **BREAKING**: Added `flutter_screenutil` with 390×844 design baseline
- Converted all 110 UI files to use `.sp` / `.w` / `.h` / `.r` responsive scaling
- Created `R` utility class (`utils/responsive.dart`) for consistent scaling helpers
- Added global `textScaler` clamp (0.8×–1.15×) to prevent accessibility font overflow
- Wrapped `MaterialApp.router` in `ScreenUtilInit` for automatic device adaptation
- UI now renders correctly on all phones: 320dp budget → 430dp+ flagships

### 🐛 Bug Fixes
- **Fixed**: `ParentData` cast crash on Dashboard (`StatChip` returning `Expanded` incorrectly)
- **Fixed**: Grey dashboard screen caused by layout crash fallback
- **Identified**: Signup `429 over_email_send_rate_limit` — Supabase free tier email rate limit

### 🧹 Repository Hygiene
- Removed 27+ orphaned debug/fetch scripts from root directory
- Removed personal files (resume, revenue strategy PDF)
- Removed stale `deno.json`, `package.json` from root
- Cleaned `scratch/` directory (13 temporary SQL/JS files)
- Updated `.gitignore` to block `scratch/`, `temp/`, `releases/`, `*.apk`
- Rewrote README to Silicon Valley-grade with badges, architecture diagrams, feature tables


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
