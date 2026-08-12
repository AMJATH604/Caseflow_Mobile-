<p align="center">
  <img src="../../apps/mobile/assets/images/logo.png" width="90" alt="CaseFlow Logo" />
</p>

<h1 align="center">CaseFlow — App Flow & UI/UX Design Brief</h1>

<p align="center">
  <strong>Version 2.5 · Design System, User Flows & Experience Architecture</strong><br/>
  <em>Confidential — For Product Designers & UI Engineers</em>
</p>

---

## 1. Design Philosophy

CaseFlow adopts a **"Legal-First, Mobile-Native"** design language tailored for fast-paced court environments, client meetings, and late-night office work.

### Core Design Principles

| Principle | Design Execution | Business Rationale |
|:---|:---|:---|
| **Speed Over Ornamentation** | Immediate offline render from SQLite cache; shimmer placeholders | Lawyers cannot wait in courtroom basements for loading spinners |
| **One-Thumb Ergonomics** | Critical action sheets & FABs pinned to bottom 40% of screen | Courtroom usage requires single-hand operation while holding physical files |
| **Information Density** | Compact data cards, color-coded stage badges, expandable accordions | Legal practitioners need maximum context at a glance |
| **Dark-Mode First** | High contrast dark palette (`#0F172A` Slate background) | Reduces battery drain and minimizes eye strain during extended work hours |
| **Vernacular Inclusion** | Multi-lingual support (English, Tamil, Hindi, Telugu) | Serves advocates across diverse state High Courts and District Benches |

---

## 2. Color Palette & Typography Tokens

### 2.1 Color Tokens (Dark & Light Theme Tokens)

```
┌────────────────────────────────────────────────────────────────────────┐
│                        CASEFLOW COLOR SYSTEM                           │
├───────────────────┬───────────────────┬───────────────────┬────────────┤
│ Deep Navy / Slate │ Judiciary Gold    │ Legal Emerald     │ Crimson    │
│ Primary Dark      │ Secondary Accent  │ Success / Active  │ Urgent     │
│ #0F172A / #1E293B │ #D97706 / #F59E0B │ #059669 / #10B981 │ #DC2626    │
└───────────────────┴───────────────────┴───────────────────┴────────────┘
```

* **Surface Background (Dark):** `#0F172A` (Slate 900)
* **Container Card Surface:** `#1E293B` (Slate 800) with 1px border `#334155`
* **Judiciary Gold (Accent):** `#F59E0B` (Amber 500) — Used for hearing tags, highlights, and primary CTA accents
* **Status Badges:**
  * Active / Filed: `#10B981` (Emerald 500)
  * Pending / Review: `#3B82F6` (Blue 500)
  * Urgent / Defect: `#EF4444` (Red 500)
  * Adjourned / Closed: `#6B7280` (Gray 500)

### 2.2 Responsive Typography Engine
All typography is built on `flutter_screenutil` using the **Inter** & **Outfit** font families:
* **Display Titles:** `24.sp` (Bold, 1.2 line height)
* **Screen Headers:** `18.sp` (SemiBold, 1.3 line height)
* **Body Text:** `14.sp` (Regular, 1.4 line height)
* **Metadata & Captions:** `11.sp` (Medium, 1.2 line height)
* **Accessibility Clamp:** Globally bounded between `0.8x` and `1.15x` text scaling factor to prevent layout distortion on accessibility-enabled devices.

---

## 3. Comprehensive Application User Flows

```
                               ┌─────────────────┐
                               │  Splash Screen  │
                               └────────┬────────┘
                                        │
                             Authenticated User?
                             ┌──────────┴──────────┐
                             │ YES                 │ NO
                             ▼                     ▼
                  ┌────────────────────┐ ┌────────────────────┐
                  │  App Shell Nav     │ │  Role Selection    │
                  └──────────┬─────────┘ └──────────┬─────────┘
                             │                      │
                             │                      ▼
                             │           ┌────────────────────┐
                             │           │  Login / Sign Up   │
                             │           └──────────┬─────────┘
                             │                      │
                             └──────────────────────┘
                                        │
           ┌────────────────────────────┼────────────────────────────┐
           ▼                            ▼                            ▼
┌────────────────────┐       ┌────────────────────┐       ┌────────────────────┐
│ Advocate Dashboard │       │  Citizen Portal    │       │  Bar Association   │
├────────────────────┤       ├────────────────────┤       ├────────────────────┤
│ • Daily Hearing    │       │ • Case Tracker     │       │ • Digital ID Card  │
│   Board            │       │ • Legal Tools      │       │ • Elections & Voting│
│ • Quick Adjourn    │       │ • Know Your Rights │       │ • Fee Payments     │
│ • Strategy Board   │       └────────────────────┘       │ • Bar Notices      │
│ • Evidence Lab     │                                    └────────────────────┘
│ • AI Assistant     │
└────────────────────┘
```

---

## 4. Key Screen Layout & Interaction Architecture

### 4.1 Dashboard & Daily Court Diary (`dashboard_screen.dart`)
* **Header Bar:** Profile avatar, Firm selector dropdown, Global Search, and Notifications bell.
* **Hero KPI Row:** 4 interactive metric cards (Total Cases, Today's Hearings, Pending Fees, Active Commissions).
* **Court Diary Widget:** Tabs for `Today`, `Tomorrow`, and `This Week`, grouped by Court Forum (e.g., *Sub Court Tenkasi*, *Madurai Bench of Madras High Court*).
* **1-Tap Quick Action Sheet:** Floating Action Button (FAB) opens bottom sheet offering: *Add Case*, *Log Hearing*, *Add Task*, *New Client*, *Capture Evidence*.

### 4.2 Case File Dossier (`case_detail_screen.dart`)
Tabbed layout with 6 specialized dockets:
1. **Dossier Tab:** CNR link, stage progression, interim applications, interim orders PDF viewer.
2. **Strategy Tab (Kanban):** Drag-and-drop task cards (`To Do`, `In Progress`, `Review`, `Filed`, `Done`).
3. **Documents Tab:** PDF view, iLovePDF tool triggers (Compress, Merge, OCR).
4. **Timeline Tab:** Chronological history of all past hearings and order sheets.
5. **Witnesses & Evidence Tab:** Examination notes, GPS evidence photos with SHA-256 hash stamp.
6. **Financials Tab:** Fee installments, ePay court fee calculator, and receipt generator.

### 4.3 Evidence Lab & Field Visit Interface (`commission_field_visit_screen.dart`)
* **Live Camera Stream:** Overlaid with live GPS coordinates, altitude, and timestamp.
* **Canvas Sketch Tool:** Interactive vector canvas for drawing locus standi / property site maps.
* **Witness Voice Recorder:** Audio capture widget with waveform visualization and local storage.

---

## 5. UI Micro-Animations & Design Tokens

* **Page Transitions:** Cupertino-style slide and fade (`300ms` cubic curve).
* **Haptic Feedback:** Subtle vibration triggers on quick-adjourn actions, task stage updates, and vote submissions.
* **Shimmer Effects:** Linear gradient shimmer placeholders (`#1E293B` to `#334155`) for asynchronous data fetching.

---

<p align="center">
  <em>End of App Flow & UI/UX Design Brief · CaseFlow Engineering Group</em>
</p>
