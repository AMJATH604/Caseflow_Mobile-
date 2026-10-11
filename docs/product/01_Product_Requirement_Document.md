<p align="center">
  <img src="../../apps/mobile/assets/images/logo.png" width="90" alt="CaseFlow Logo" />
</p>

<h1 align="center">CaseFlow — Product Requirement Document (PRD)</h1>

<p align="center">
  <strong>Version 2.5 · Enterprise Legal Operations Platform</strong><br/>
  <em>Confidential — For Engineering, Product & Executive Teams</em>
</p>

---

## 1. Executive Summary

**CaseFlow** is an intelligent, offline-first legal practice management ecosystem designed specifically for Indian Advocates, Law Firms, and Bar Associations. It bridges the gap between traditional litigation practices and digital legal tech by unifying case management, courtroom scheduling, financial ledgers, evidence documentation, AI-assisted legal research, and bar community governance into a seamless mobile and web experience.

### 1.1 Problem Statement
Indian legal practitioners face unique challenges:
* **High Hearing Volume & Frequent Adjournments:** Managing dozens of daily court appearances across multiple judicial forums without centralized tracking leads to missed hearings and default orders.
* **Network Instability in Courtrooms:** Advocates operate in low-connectivity environments (basements, thick court structures) where traditional web applications fail.
* **Disparate Legal Tools:** Information is scattered across paper dockets, eCourts portals, messaging apps, and standalone calculators.
* **Evidentiary Integrity:** Preserving digital evidence (photos, witness statements, commissioner sketches) with chain-of-custody verification is complex without digital hashing.

### 1.2 Vision & Core Value Proposition
To serve as the **Operating System for Indian Legal Practice**, delivering:
1. **Instant Offline Availability:** 100% access to case records, hearing schedules, and client contact information without internet dependency.
2. **AI-Powered Legal Intelligence:** Contextual law analysis and draft generation powered by Google Gemini 2.0 Flash via server-side secure proxies.
3. **Institutional Trust:** Tamper-evident evidence hashing (SHA-256), strict Row Level Security (RLS), and verifiable audit logging.

---

## 2. Target Persona & User Roles

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           CASEFLOW USER ROLES                           │
├──────────────────┬──────────────────┬─────────────────┬─────────────────┤
│ Senior Advocate  │ Associate /      │ Court Clerk /   │ Citizen /       │
│ / Firm Partner   │ Junior Advocate  │ Legal Assistant │ Litigant        │
├──────────────────┼──────────────────┼─────────────────┼─────────────────┤
│ • Full firm access│ • Case handling  │ • Filing dockets│ • Track own     │
│ • Financials     │ • Hearing notes  │ • Document upload│   case status   │
│ • Strategy board │ • Daily board    │ • Reminders     │ • Legal advice  │
│ • Bar admin      │ • Research AI    │ • ePay fees     │   tools         │
└──────────────────┴──────────────────┴─────────────────┴─────────────────┘
```

| Role | Key Pain Points | Core Feature Set | Success Metrics |
|:---|:---|:---|:---|
| **Senior Advocate** | Managing multiple junior teams, tracking firm revenue, high-level strategy | Strategy Board, Financial Ledger, Firm Management, Bar Association Admin | <2s daily oversight time per case |
| **Junior Advocate** | Courtroom note-taking, legal research, drafting petitions | Offline Court Diary, Gemini AI Assistant, Legal Library & Calculators | 50% faster research & drafting |
| **Court Clerk** | Document uploads, tracking eFiling status, court fee payments | eFiling Tracker, ePay Integration, Certified Copy Status | 0 missed filing deadlines |
| **Citizen Litigant** | Lack of case visibility, understanding legal rights | Citizen Portal, Case Tracker, Know Your Rights Guide | Transparent case updates |

---

## 3. Product Module Specifications

### 3.1 Case & Dossier Management
* **CNR & Manual Linking:** Supports 16-digit eCourts CNR auto-link and custom manual case creation.
* **Stage Tracking:** Lifecycle stages (`filing` → `evidence` → `argument` → `judgment`).
* **Case Dossier:** Sub-modules for Bare Acts linked, Interim Applications (IA), and Interim Orders with full PDF preview.
* **Case Collaboration:** Soft-delete mechanisms with audit trails and firm-level data sharing.

### 3.2 Court Hearing Calendar & Adjournment Workflow
* **Court Diary:** Date-aware calendar grouped by judicial forum (High Court, District Court, Tribunals).
* **Quick Adjourn Sheet:** 1-tap adjournment log recording reason, next date, and opposing counsel remarks.
* **Daily Board Widget:** Real-time summary of today's hearings with status flags (`active`, `passed-over`, `adjourned`, `completed`).

### 3.3 Financial Ledger & ePay Engine
* **Case Ledger:** Itemized fee agreements, payment installments, and expense logs per case.
* **Receipt Generator:** Auto-generates branded PDF receipts with QR payment verification.
* **Smart Payment Capture:** Detects returning users from ePay portals and prompts instant receipt logging.

### 3.4 Evidence Lab & Local Commissioner Module
* **Tamper-Evident Photos:** GPS geotagging, timestamping, and SHA-256 cryptographic hash creation for evidence photos.
* **Commissioner Module:** Field visit logging, interactive canvas sketch tool, witness audio recording, and report generator.

### 3.5 AI Legal Assistant (Gemini 2.0 Flash)
* **Natural Language Q&A:** Answers queries on BNS, BNSS, BSA, CPC, and Constitution.
* **Secure Server Proxy:** Zero client-side API key exposure; calls routed through Supabase Edge Functions.

### 3.6 Legal Library & Interactive Calculators
* **Bare Acts Repository:** Full searchable text of Indian Codes (BNS, BNSS, BSA, CPC, Constitution, DVC, NI Act, Motor Vehicles Act, Specific Relief Act).
* **Calculators:** Court Fee, Stamp Duty, Limitation Period, MACT Compensation, Maintenance, Partition, Interest, and Delay.

### 3.7 Bar Association Platform (BarDesk)
* **Bar Governance:** Digital Membership Cards with QR verification, Election Nominee voting, Public Notices, and Fee Collection.

---

## 4. Non-Functional Requirements (NFRs)

```
┌────────────────────────────────────────────────────────────────────────┐
│                        NON-FUNCTIONAL STANDARDS                        │
├───────────────────┬───────────────────┬───────────────────┬────────────┤
│ Performance       │ Offline Caching   │ Security & Privacy│ Availability
├───────────────────┼───────────────────┼───────────────────┼────────────┤
│ • <100ms UI response│ • SQLite Cache  │ • Supabase RLS    │ • 99.9%    |
│ • <2s cold start  │ • Auto BG Sync    │ • SHA-256 Hash    │   Uptime   │
│ • 60 FPS scroll   │ • TTL Cache invalid│ • PKCE Auth      │ • Cloudflare
└───────────────────┴───────────────────┴───────────────────┴────────────┘
```

1. **Performance Target:** Cold app start under 2.0 seconds. Screen navigation under 100ms via Riverpod state caching.
2. **Offline Durability:** Complete read capabilities offline for all cached cases, hearings, and clients via SQLite.
3. **Security Standards:** ISO/IEC 27001 compliant architecture, Row Level Security (RLS) on 100% of tables, encrypted storage at rest.
4. **Accessibility:** Text scaling support (0.8x to 1.15x clamp) for all high-contrast and font size preferences.

---

## 5. Feature Priority Matrix (RICE Score)

| Feature | Reach | Impact | Confidence | Effort | RICE Score | Priority |
|:---|:---:|:---:|:---:|:---:|:---:|:---:|
| Offline Court Diary & Adjourn | 10 | 3 | 100% | 2 | **150** | P0 (Critical) |
| Case Dossier & RLS Security | 9 | 3 | 90% | 2 | **121** | P0 (Critical) |
| Gemini AI Legal Assistant | 8 | 3 | 80% | 2 | **96** | P1 (High) |
| Evidence Lab (SHA-256) | 7 | 3 | 90% | 2 | **94.5** | P1 (High) |
| Financial Ledger & ePay | 8 | 2 | 90% | 2 | **72** | P1 (High) |
| Bar Association Module | 6 | 2 | 80% | 3 | **32** | P2 (Medium) |

---

<p align="center">
  <em>End of Product Requirement Document · CaseFlow Engineering Group</em>
</p>
