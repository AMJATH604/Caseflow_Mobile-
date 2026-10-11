<p align="center">
  <img src="../../apps/mobile/assets/images/logo.png" width="100" alt="CaseFlow Logo" />
</p>

<h1 align="center">CaseFlow — Product & Technical Documentation Suite</h1>

<p align="center">
  <strong>Silicon Valley-Grade Architectural & Engineering Reference</strong><br/>
  <em>Version 2.5 · Executive, Product & System Specifications</em>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Documentation-Silicon_Valley_Grade-5851DB?style=for-the-badge&logo=storybook&logoColor=white" alt="Docs Grade" />
  <img src="https://img.shields.io/badge/Architecture-Clean_Repository_Pattern-007ACC?style=for-the-badge&logo=visualstudiocode&logoColor=white" alt="Architecture" />
  <img src="https://img.shields.io/badge/Security-Postgres_RLS_Enforced-3FCF8E?style=for-the-badge&logo=supabase&logoColor=white" alt="Security" />
</p>

---

## 📚 Documentation Index

Welcome to the official **CaseFlow Documentation Suite**. This folder contains the complete, highly detailed specifications for CaseFlow's product requirements, technical architecture, UI/UX experience brief, backend schema definitions, and chronological implementation history.

| # | Document Title | Description | Primary Audience |
|:-:|:---|:---|:---|
| **01** | [**Product Requirement Document (PRD)**](01_Product_Requirement_Document.md) | Executive summary, target personas, core modules (Case Dossier, Court Diary, Evidence Lab, Gemini AI, BarDesk), NFRs, and RICE scoring matrix. | Product Managers, Executive Leadership, Founders |
| **02** | [**Technical Requirement Document (TRD)**](02_Technical_Requirement_Document.md) | System architecture, Flutter/Dart technical stack, Repository pattern, Edge Functions, Cloudflare R2 integration, and performance benchmarks. | System Architects, Lead Engineers, DevOps |
| **03** | [**App Flow & UI/UX Design Brief**](03_App_Flow_and_UI_UX_Design_Brief.md) | Design principles, dark-mode-first color palette, typography tokens, full screen navigation map, 1-thumb ergonomics, and micro-animations. | UI/UX Designers, Frontend Developers |
| **04** | [**Backend Schema Specification**](04_Backend_Schema_Specification.md) | Relational database ERD, 38 table DDL definitions, Postgres Row Level Security (RLS) policies, Realtime triggers, and S3 bucket definitions. | Database Administrators, Backend Engineers |
| **05** | [**Implementation Chronology**](05_Implementation_Chronology.md) | 5-phase engineering roadmap, milestone history, code refactoring logs, and comprehensive module-to-file traceability matrix. | Project Managers, Tech Leads, QA |

---

## 🏛️ System Architecture At A Glance

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        CASEFLOW TECH STACK                              │
├──────────────────┬──────────────────┬──────────────────┬────────────────┤
│ Mobile App       │ Web Applications │ Serverless Edge  │ Managed Cloud  │
├──────────────────┼──────────────────┼──────────────────┼────────────────┤
│ • Flutter 3.29   │ • React 18 / Vite│ • Deno Runtime   │ • Supabase DB  │
│ • Riverpod 2.x   │ • Tailwind CSS   │ • Gemini AI Proxy│ • Cloudflare R2│
│ • GoRouter 14.x  │ • TypeScript     │ • iLovePDF Proxy │ • FCM v1 Push  │
│ • SQLite Cache   │ • Capacitor      │ • FCM Cron Push  │ • Realtime WS  │
└──────────────────┴──────────────────┴──────────────────┴────────────────┘
```

---

<p align="center">
  <em>CaseFlow Legal Tech Platform · Proprietary & Confidential Documentation</em>
</p>
