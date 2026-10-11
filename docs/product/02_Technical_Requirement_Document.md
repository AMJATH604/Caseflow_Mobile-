<p align="center">
  <img src="../../apps/mobile/assets/images/logo.png" width="90" alt="CaseFlow Logo" />
</p>

<h1 align="center">CaseFlow — Technical Requirement Document (TRD)</h1>

<p align="center">
  <strong>Version 2.5 · System Architecture & Engineering Specification</strong><br/>
  <em>Confidential — For Core Development & Infrastructure Engineers</em>
</p>

---

## 1. System Architecture Overview

CaseFlow employs a modern **Distributed Client-Server & Edge Architecture**. The client layer is a reactive Flutter cross-platform mobile application utilizing Riverpod state management and SQLite offline-first storage. The backend layer relies on Supabase (PostgreSQL, Realtime, Auth) combined with Deno-based Edge Functions and Cloudflare R2 object storage.

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        CASEFLOW HIGH-LEVEL ARCHITECTURE                 │
└─────────────────────────────────────────────────────────────────────────┘
                                   │
              ┌────────────────────┴────────────────────┐
              ▼                                         ▼
   ┌──────────────────────┐                  ┌──────────────────────┐
   │ Mobile Client        │                  │ Web Dashboard        │
   │ (Flutter 3.29/Dart)  │                  │ (React 18 / Vite)    │
   └──────────┬───────────┘                  └──────────┬───────────┘
              │                                         │
              ├────────────────────┬────────────────────┤
              │ REST / WebSockets  │ HTTPS / PostgREST  │
              ▼                    ▼                    ▼
   ┌────────────────────────────────────────────────────────────────┐
   │                   SUPABASE BACKEND CLUSTER                     │
   ├────────────────────────┬──────────────────────┬────────────────┤
   │ PostgreSQL 15 Database │ Supabase Auth (PKCE) │ Realtime Engine│
   │ (Row Level Security)   │ JWT / OAuth 2.0      │ WebSockets     │
   └──────────┬─────────────┴──────────┬───────────┴────────────────┘
              │                        │
              ├────────────────────────┴────────────────┐
              ▼                                         ▼
   ┌──────────────────────┐                  ┌──────────────────────┐
   │ Serverless Edge      │                  │ Distributed Storage  │
   │ Functions (Deno)     │                  │ (Cloudflare R2)      │
   ├──────────────────────┤                  ├──────────────────────┤
   │ • gemini-proxy       │                  │ • Case Documents     │
   │ • pdf-proxy          │                  │ • Bare Acts PDFs     │
   │ • hearing-reminders  │                  │ • Chat Attachments   │
   └──────────────────────┘                  └──────────────────────┘
```

---

## 2. Technology Stack & Key Dependencies

### 2.1 Mobile Application Layer (Flutter Engine)
* **Framework:** Flutter 3.29.x / Dart 3.7.x
* **State Management:** Flutter Riverpod (`StateNotifierProvider`, `FutureProvider`)
* **Routing:** `go_router` 14.x with declarative guards
* **Responsive Layout:** `flutter_screenutil` (Design baseline: `390×844dp`, clamping text scale: `0.8x–1.15x`)
* **Local Database:** `sqflite` 2.4.x (SQLite engine)
* **Push Notifications:** Firebase Cloud Messaging (`firebase_messaging` 15.x) & `flutter_local_notifications`
* **Telemetry & Logging:** `firebase_crashlytics` & `firebase_analytics`

### 2.2 Backend & Cloud Infrastructure
* **Database Platform:** Supabase Managed PostgreSQL 15.x
* **Authentication:** Supabase Auth (PKCE flow with Refresh Tokens)
* **Realtime Engine:** Supabase Realtime WebSockets (`supabase_flutter` 2.x)
* **Serverless Runtime:** Deno 1.x (Supabase Edge Functions)
* **Object Storage:** Cloudflare R2 (S3-compatible API, 0 Egress cost model) + Supabase Storage

---

## 3. Client Architecture & Data Flow

### 3.1 Repository Pattern & Layering

```
┌─────────────────────────────────────────────────────────┐
│                    UI LAYER                             │
│       36+ Screens & 40+ Reusable Components             │
└────────────────────────────┬────────────────────────────┘
                             │ calls
┌────────────────────────────▼────────────────────────────┐
│              SUPABASE SERVICE (FACADE)                  │
│       Delegates calls to domain repositories            │
└────────────────────────────┬────────────────────────────┘
                             │ delegates
┌────────────────────────────▼────────────────────────────┐
│              DOMAIN REPOSITORIES (10)                   │
│   Case · Client · Hearing · Payment · Evidence · DM     │
└────────────────────────────┬────────────────────────────┘
                             │ extends
┌────────────────────────────▼────────────────────────────┐
│                   BASE REPOSITORY                       │
│ • Profile Cache (5-min TTL) • Auth Guard • RLS Filters  │
└────────────────────────────┬────────────────────────────┘
                             │ syncs with
┌────────────────────────────▼────────────────────────────┐
│               OFFLINE CACHE SERVICE                     │
│               SQLite Engine (sqflite)                   │
└─────────────────────────────────────────────────────────┘
```

### 3.2 Offline-First Cache Design ("Cache-Then-Network")

```
   User Request
        │
        ▼
┌──────────────────┐  Cached Data Exists?
│ Check SQLite DB  ├──────────────────────┐
└───────┬──────────┘                      │
        │ YES                             │ NO
        ▼                                 ▼
┌──────────────────┐             ┌──────────────────┐
│ Render UI        │             │ Show Shimmer     │
│ Immediately      │             │ Loading State    │
└───────┬──────────┘             └────────┬─────────┘
        │                                 │
        └────────────────┬────────────────┘
                         │
                         ▼
             ┌───────────────────────┐
             │ Fetch Fresh Data from │
             │ Supabase API          │
             └───────────┬───────────┘
                         │
        ┌────────────────┴────────────────┐
        │ Success                         │ Error / Offline
        ▼                                 ▼
┌──────────────────┐             ┌──────────────────┐
│ Update SQLite    │             │ Retain SQLite    │
│ & Refresh UI     │             │ Cached View      │
└──────────────────┘             └──────────────────┘
```

The `OfflineCacheService` handles local database operations with table definitions for `cached_cases`, `cached_hearings`, `cached_clients`, `cached_stats`, and generic key-value pairs with configurable TTL.

---

## 4. Backend Service Specifications

### 4.1 Serverless Edge Functions

#### A. `gemini-proxy`
* **Purpose:** Offloads Gemini 2.0 Flash AI API key handling to the server. Accepts legal prompts, injects system prompts for Indian Legal context, and streams text back to client.
* **Security:** Validates Supabase JWT; API key stored in Deno Secret Store (`GEMINI_API_KEY`).

#### B. `pdf-proxy`
* **Purpose:** Handles PDF compression, conversion (Word to PDF), merge, and OCR processing using iLovePDF backend APIs.
* **Security:** Protected by secret key validation (`ILOVEPDF_PUBLIC_KEY`, `ILOVEPDF_SECRET_KEY`).

#### C. `send-hearing-reminders`
* **Purpose:** Cron trigger executing every morning at 08:00 AM IST. Queries hearings scheduled for today, builds personalized FCM v1 HTTP API notification payloads, and dispatches push alerts to registered advocates.

#### D. `r2-storage`
* **Purpose:** Generates signed S3 upload/download URLs for Cloudflare R2 buckets, enabling large file transfers bypassing application server bandwidth limits.

---

## 5. Security & Cryptographic Integrity

### 5.1 Row Level Security (RLS) Paradigm
All database access is guarded by Postgres RLS policies based on `auth.uid()`.

```sql
-- Example RLS Policy for Cases Table
CREATE POLICY "Users can access own or firm cases" ON cases
  FOR ALL USING (
    created_by = auth.uid() 
    OR assigned_to = auth.uid() 
    OR firm_id = (SELECT firm_id FROM profiles WHERE id = auth.uid())
  );
```

### 5.2 Evidence Chain-of-Custody Hashing
When evidence photos are captured via the Evidence Lab or Commissioner module:
1. EXIF metadata is recorded (GPS coordinates, altitude, timestamp).
2. The image byte stream is hashed locally using **SHA-256**.
3. The resulting 64-character hash is saved alongside the image metadata in Supabase DB before storage upload, guaranteeing court admissibility.

---

## 6. Performance Benchmarks & Targets

| Metric | Target Baseline | Measured (Prod Build) |
|:---|:---:|:---:|
| **App Cold Start** | < 2.0s | 1.45s |
| **Dashboard Load (Parallel)** | < 800ms | 320ms (Cache), 610ms (Network) |
| **Offline Fallback Latency** | < 50ms | 18ms |
| **Frame Render Rate** | 60 FPS | 59.4 FPS (Average) |
| **APK Binary Size** | < 45 MB | 38.2 MB (Signed Release) |

---

<p align="center">
  <em>End of Technical Requirement Document · CaseFlow Engineering Group</em>
</p>
