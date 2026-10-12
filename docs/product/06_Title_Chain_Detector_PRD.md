<p align="center">
  <img src="../../apps/mobile/assets/images/logo.png" width="90" alt="CaseFlow Logo" />
</p>

<h1 align="center">CaseFlow — Property Title Chain Inconsistency Detector</h1>

<p align="center">
  <strong>Product Requirement Document · Version 1.0</strong><br/>
  <em>Confidential — For Engineering, Product & Executive Teams</em><br/>
  <em>Author: CaseFlow Product Team · Date: October 2026</em>
</p>

---

## 1. Executive Summary

The **Property Title Chain Inconsistency Detector** is an AI-powered legal due-diligence module within CaseFlow that helps advocates identify gaps, contradictions, and unexplained changes in a property's ownership history before advising a buyer.

### 1.1 Problem Statement

When a client approaches an advocate and says:

> *"I'm going to buy this land. Here are the sale deed, parent documents, patta, encumbrance certificate, and legal-heir documents. Please check whether everything is correct."*

The advocate must:
- Read several documents spanning 10–30+ years
- Compare names, survey numbers, and extents across all of them
- Trace every previous transaction backward to establish a chain of title
- Verify inheritance and partition records for completeness
- Determine whether the current seller has the legal right to convey the property

**The difficulty isn't reading individual documents. It's determining whether all documents, taken together, tell a consistent and legally supportable story of ownership.**

Today, this process is:
- **Manual** — entirely paper-based cross-referencing
- **Error-prone** — a single missed name mismatch or survey number change can mean years of litigation
- **Time-consuming** — a thorough title search takes 2–5 days for a single property
- **Unscalable** — advocates can only handle 2–3 title opinions per week

### 1.2 Solution

An AI-assisted platform that:
1. **Extracts** structured data from uploaded property documents (OCR + LLM)
2. **Cross-references** names, survey numbers, dates, extents, and relationships across all documents
3. **Detects** inconsistencies, gaps, contradictions, and red flags
4. **Generates** a structured Title Health Report that the advocate reviews, edits, and delivers to the client

### 1.3 Core Value Proposition

| For | Value |
|-----|-------|
| **Advocates** | Reduce title search from 2–5 days → 30 minutes. Catch inconsistencies human eyes miss. |
| **Clients** | Higher confidence in purchase decisions. Reduced risk of title disputes. |
| **Banks** | Faster mortgage title verification. Standardized risk assessment. |
| **CaseFlow** | Premium revenue module. Killer feature for property lawyers. |

---

## 2. Target Users & Personas

### 2.1 Primary Persona: Property Advocate

```
Name:        Adv. Karthikeyan, Kadayanallur
Experience:  15 years in civil property matters
Daily Work:  Reviews 1–2 title chains per week
Pain Points: Cross-checking old handwritten deeds with current patta
             Tracing survey number changes after re-surveys
             Verifying legal heir chains (Hindu succession, Muslim law)
             Missing documents in encumbrance certificates
Tech Level:  Comfortable with smartphone, uses CaseFlow daily
```

### 2.2 Secondary Personas

| Persona | Use Case |
|---------|----------|
| **Real Estate Developer** | Bulk title verification for land acquisition |
| **Bank Legal Officer** | Home loan title verification (throughput) |
| **Litigant / Buyer** | Self-service "title health check" before purchase |
| **Revenue / Tahsildar Office** | Patta transfer verification |

---

## 3. Document Universe

### 3.1 Core Documents (Phase 1 — Tamil Nadu)

| # | Document | Source | Format | Key Data Extracted |
|---|----------|--------|--------|--------------------|
| 1 | **Sale Deed** (பத்திரம்) | Sub-Registrar Office / TNREGINET | PDF (typed post-2008) | Buyer, seller, survey no., extent, consideration, document no., date, schedule |
| 2 | **Encumbrance Certificate (EC)** | TNREGINET | PDF / HTML | All transactions in date range: document nos., parties, nature (sale/mortgage/release/gift) |
| 3 | **Patta / Chitta** (பட்டா) | eservices.tn.gov.in | PDF | Current owner name, survey no., classification, extent, patta no. |
| 4 | **Parent Deed** | Sub-Registrar | PDF | Previous sale/gift/partition establishing seller's ownership |
| 5 | **Legal Heir Certificate** | Tahsildar / Revenue | PDF | Deceased, legal heirs, relationship |

### 3.2 Extended Documents (Phase 2+)

| # | Document | Purpose |
|---|----------|---------|
| 6 | **Partition Deed** | Verifies how joint property was divided among heirs |
| 7 | **Will / Registered Will** | Testamentary succession — must cross-check with legal heir cert |
| 8 | **Gift Deed** | Verify donor had title, donee matches current chain |
| 9 | **Death Certificate** | Confirms death date matches legal heir cert and succession |
| 10 | **FMB (Field Measurement Book) Sketch** | Survey boundary verification |
| 11 | **Guideline Value / Market Value Certificate** | Stamp duty validation |
| 12 | **DTCP / CMDA Approval** | Layout approval for plots |
| 13 | **Tax Receipt / Property Tax** | Confirms possession and payment history |
| 14 | **Power of Attorney** | ⚠️ Red flag document — GPA sales are high-risk |

### 3.3 Language Support

| Phase | Languages |
|-------|-----------|
| Phase 1 | English, Tamil (typed/printed only) |
| Phase 2 | Tamil (handwritten), Telugu, Kannada |
| Phase 3 | Hindi, Malayalam, Marathi |

---

## 4. Core Feature Specification

### 4.1 Document Upload & Extraction

#### Upload Flow
```
┌──────────────────────────────────────────────────────┐
│                  NEW TITLE SEARCH                     │
│                                                       │
│  Property Details                                     │
│  ┌─────────────────────────────────────────────────┐  │
│  │ District:     [Tirunelveli        ▼]            │  │
│  │ Taluk:        [Kadayanallur       ▼]            │  │
│  │ Village:      [Meenakshipuram     ▼]            │  │
│  │ Survey No:    [145/2A                ]          │  │
│  │ Extent:       [2 acres 50 cents      ]          │  │
│  └─────────────────────────────────────────────────┘  │
│                                                       │
│  Upload Documents                                     │
│  ┌─────────────────────────────────────────────────┐  │
│  │  📄 Sale Deed (Current)         [+ Upload]      │  │
│  │  📄 Parent Deed                 [+ Upload]      │  │
│  │  📄 Encumbrance Certificate     [+ Upload]      │  │
│  │  📄 Patta / Chitta              [+ Upload]      │  │
│  │  📄 Legal Heir Certificate      [+ Upload]      │  │
│  │  📄 Additional Documents        [+ Upload]      │  │
│  └─────────────────────────────────────────────────┘  │
│                                                       │
│  ┌─────────────────────────────────────────────────┐  │
│  │        🔍  ANALYZE TITLE CHAIN                  │  │
│  └─────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────┘
```

#### Extraction Pipeline

```
Document (PDF/Image)
       │
       ▼
┌──────────────────┐
│  Pre-processing   │  ← Deskew, enhance contrast, denoise
│  (Image Pipeline) │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│  OCR Engine       │  ← Google Cloud Vision API / Tesseract
│  (Text Extraction)│    Bilingual: Tamil + English
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│  LLM Structured   │  ← Gemini 2.0 Flash
│  Extraction        │    Prompt: "Extract the following fields
│                    │    from this Tamil Nadu sale deed..."
│  Output: JSON      │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│  Validation &     │  ← Schema validation
│  Confidence Score  │    Field-level confidence (0–100%)
└──────────────────┘
```

#### Extracted Data Schema (per Document)

```json
{
  "document_type": "sale_deed",
  "document_number": "1234/2020",
  "sub_registrar_office": "Kadayanallur",
  "registration_date": "2020-03-15",
  "execution_date": "2020-03-10",

  "parties": {
    "seller": {
      "name": "S. Ramasamy",
      "father_name": "Shanmugam",
      "address": "Meenakshipuram Village, Kadayanallur",
      "name_variants": ["Ramasamy", "Ramaswami", "ராமசாமி"]
    },
    "buyer": {
      "name": "K. Murugan",
      "father_name": "Karuppasamy",
      "address": "Main Road, Kadayanallur"
    },
    "witnesses": [
      { "name": "P. Velusamy", "id_number": "XXXX" }
    ]
  },

  "property": {
    "survey_number": "145/2A",
    "old_survey_number": "78/1",
    "village": "Meenakshipuram",
    "taluk": "Kadayanallur",
    "district": "Tirunelveli",
    "extent": { "value": 2.5, "unit": "acres" },
    "classification": "wet_land",
    "boundaries": {
      "north": "Survey No. 145/1 - Selvaraj land",
      "south": "Village road",
      "east": "Irrigation canal",
      "west": "Survey No. 146 - Govt poramboke"
    }
  },

  "consideration": {
    "amount": 1500000,
    "currency": "INR",
    "mode": "demand_draft"
  },

  "stamp_duty": {
    "paid": 105000,
    "guideline_value": 1400000
  },

  "parent_document_reference": {
    "document_number": "890/2005",
    "sro": "Kadayanallur",
    "date": "2005-07-22",
    "nature": "sale_deed"
  },

  "extraction_confidence": 0.92,
  "raw_text": "..."
}
```

### 4.2 Cross-Reference Engine — The Brain

This is the core differentiator. The engine runs **18 cross-reference checks** across all uploaded documents:

#### Chain of Title Checks

| # | Check | What It Detects | Severity |
|---|-------|----------------|----------|
| 1 | **Seller→Buyer Linkage** | Current seller must be the buyer (or heir of buyer) in the parent deed | 🔴 Critical |
| 2 | **Unbroken Chain** | Every transaction from the earliest deed to the current must link seamlessly | 🔴 Critical |
| 3 | **EC Coverage** | EC must cover the full period from parent deed to today with no gaps | 🔴 Critical |
| 4 | **Survey Number Consistency** | Survey no. must match across deed, patta, and EC (accounting for re-surveys) | 🔴 Critical |
| 5 | **Extent Consistency** | Area/extent must match across deed, patta, and EC (± tolerance) | 🟡 Warning |

#### Identity & Name Checks

| # | Check | What It Detects | Severity |
|---|-------|----------------|----------|
| 6 | **Fuzzy Name Match** | Same person referenced with different spellings across documents | 🟡 Warning |
| 7 | **Father/Spouse Name Match** | Parentage must be consistent across all documents | 🟡 Warning |
| 8 | **Legal Heir Completeness** | All heirs in LHC must appear in partition/succession deed | 🔴 Critical |
| 9 | **Death→LHC→Succession Chain** | Death certificate date < LHC date < partition/succession deed date | 🟡 Warning |

#### Red Flag Detection

| # | Check | What It Detects | Severity |
|---|-------|----------------|----------|
| 10 | **GPA Sale** | General Power of Attorney used for sale (Supreme Court: not valid for immovable property) | 🔴 Critical |
| 11 | **Undivided Share Sale** | Selling share without partition — risky for buyer | 🟡 Warning |
| 12 | **Government Land** | Schedule describes poramboke, river bed, or reserved forest land | 🔴 Critical |
| 13 | **Pending Mortgage** | EC shows mortgage/charge not yet released | 🔴 Critical |
| 14 | **Litigation Pending** | EC shows lis pendens or court attachment | 🔴 Critical |
| 15 | **Multiple Sales** | Same property sold to multiple buyers (double sale) | 🔴 Critical |
| 16 | **Stamp Duty Undervaluation** | Consideration significantly below guideline value | 🟡 Warning |
| 17 | **Boundary Mismatch** | Schedule boundaries differ between deed and FMB sketch | 🟡 Warning |
| 18 | **Classification Mismatch** | Agricultural land in deed but house-site in patta (or vice versa) | 🟡 Warning |

#### Cross-Reference Algorithm

```
┌─────────────────────────────────────────────────────────┐
│              CROSS-REFERENCE ENGINE                      │
│                                                          │
│  Input: Array of ExtractedDocument objects                │
│                                                          │
│  Step 1: BUILD OWNERSHIP TIMELINE                        │
│  ┌─────────────────────────────────────────────────┐     │
│  │ 1985: Original Grant (Patta) → Shanmugam        │     │
│  │ 1985─2005: No transactions (EC clean)            │     │
│  │ 2005: Sale Deed 890/2005 → Shanmugam → Ramasamy │     │
│  │ 2005─2020: No transactions (EC clean)            │     │
│  │ 2020: Sale Deed 1234/2020 → Ramasamy → Murugan  │     │
│  │ 2020─today: No transactions (EC clean)           │     │
│  └─────────────────────────────────────────────────┘     │
│                                                          │
│  Step 2: VALIDATE EACH LINK                              │
│  For each consecutive pair:                              │
│    - Does seller in deed N+1 = buyer in deed N?          │
│    - Do survey numbers match?                            │
│    - Does extent match?                                  │
│    - Is there a gap between the two transactions?        │
│    - If gap has inheritance: are LHC + partition valid?   │
│                                                          │
│  Step 3: CHECK EC AGAINST TIMELINE                       │
│    - Any transactions in EC not in uploaded deeds?        │
│    - Any mortgages/charges still active?                  │
│    - Any court attachments or lis pendens?                │
│                                                          │
│  Step 4: VALIDATE CURRENT STATE                          │
│    - Does patta holder = current proposed seller?         │
│    - Does patta survey no. = deed survey no.?            │
│    - Does patta extent = deed extent?                    │
│                                                          │
│  Step 5: RED FLAG SCAN                                   │
│    - GPA involvement? Undivided share? Govt land?        │
│    - Stamp duty undervaluation?                          │
│                                                          │
│  Output: TitleHealthReport                               │
└─────────────────────────────────────────────────────────┘
```

### 4.3 Title Health Report — The Output

The final deliverable is a structured, advocate-reviewable report:

```
┌──────────────────────────────────────────────────────────┐
│              🏠 TITLE HEALTH REPORT                       │
│                                                           │
│  Property: Survey No. 145/2A, Meenakshipuram Village     │
│  District: Tirunelveli · Taluk: Kadayanallur             │
│  Generated: 12-Oct-2026 · By: Adv. Karthikeyan          │
│                                                           │
│  ┌────────────────────────────────────────────────────┐   │
│  │  OVERALL TITLE HEALTH                              │   │
│  │                                                    │   │
│  │  ██████████████░░░░░░  72% — NEEDS ATTENTION       │   │
│  │                                                    │   │
│  │  🔴 2 Critical Issues                              │   │
│  │  🟡 3 Warnings                                     │   │
│  │  ✅ 13 Checks Passed                               │   │
│  └────────────────────────────────────────────────────┘   │
│                                                           │
│  ─── OWNERSHIP CHAIN ────────────────────────────────     │
│                                                           │
│  1985 ──── Shanmugam (Original Pattadhar)                │
│    │        Patta No. 456, Survey 78/1                    │
│    │                                                      │
│    │  ⚠️ Re-survey: 78/1 → 145/2A (2001 resurvey)       │
│    │                                                      │
│  2005 ──── Ramasamy (Sale Deed 890/2005)                 │
│    │        Buyer: "S. Ramasamy S/o Shanmugam"           │
│    │        Extent: 2 acres 50 cents                      │
│    │                                                      │
│    │  ✅ Seller linkage verified                          │
│    │  ✅ Survey number matches (post re-survey)           │
│    │                                                      │
│  2020 ──── Murugan (Sale Deed 1234/2020)                 │
│    │        Buyer: "K. Murugan S/o Karuppasamy"          │
│    │        Extent: 2 acres 50 cents                      │
│    │                                                      │
│    │  ✅ Seller linkage verified                          │
│    │  ✅ Survey number matches                            │
│    │                                                      │
│  TODAY ─── Proposed Seller: K. Murugan                   │
│             ✅ Matches patta holder                       │
│                                                           │
│  ─── CRITICAL ISSUES ────────────────────────────────     │
│                                                           │
│  🔴 ISSUE #1: Pending Mortgage Not Discharged             │
│  EC entry dated 18-Jun-2018 shows a mortgage              │
│  (Doc No. 567/2018) in favour of Indian Bank,             │
│  Kadayanallur Branch. No discharge/release found          │
│  in EC up to present date.                                │
│  ACTION: Obtain mortgage release deed before purchase.    │
│                                                           │
│  🔴 ISSUE #2: Extent Mismatch                            │
│  Sale Deed 1234/2020 states 2 acres 50 cents but         │
│  current Patta shows 2 acres 25 cents.                   │
│  Discrepancy: 25 cents (10%).                            │
│  ACTION: Verify with FMB sketch and Village Office.      │
│                                                           │
│  ─── WARNINGS ───────────────────────────────────────     │
│                                                           │
│  🟡 WARNING #1: Name Spelling Variation                   │
│  "Ramasamy" in Sale Deed 890/2005 vs "Ramaswami"         │
│  in Patta. Likely same person (father name matches).      │
│  SUGGESTION: Obtain affidavit confirming identity.        │
│                                                           │
│  🟡 WARNING #2: EC Gap (2005–2008)                        │
│  EC obtained covers 2008–2026. Three-year gap from        │
│  parent deed (2005) to EC start date.                    │
│  SUGGESTION: Obtain supplementary EC for 2005–2008.      │
│                                                           │
│  🟡 WARNING #3: Boundary Description Vague                │
│  Northern boundary described as "Selvaraj land" without   │
│  survey number. May cause boundary disputes.             │
│  SUGGESTION: Verify with FMB and adjoining patta.        │
│                                                           │
│  ─── ADVOCATE'S OPINION ─────────────────────────────     │
│  [                                                    ]   │
│  [  Editable text field for advocate to type their    ]   │
│  [  final title opinion after reviewing AI findings   ]   │
│  [                                                    ]   │
│                                                           │
│  ┌───────────────┐  ┌───────────────┐                    │
│  │  📄 Export PDF │  │  📤 Share     │                    │
│  └───────────────┘  └───────────────┘                    │
└──────────────────────────────────────────────────────────┘
```

---

## 5. Technical Architecture

### 5.1 System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        CASEFLOW MOBILE APP                       │
│  ┌──────────────┐  ┌──────────────────┐  ┌──────────────────┐  │
│  │ Title Search  │  │ Document Upload   │  │ Report Viewer    │  │
│  │ Dashboard     │  │ & Camera Capture  │  │ & PDF Export     │  │
│  └──────┬───────┘  └────────┬─────────┘  └────────┬─────────┘  │
│         │                    │                      │             │
│         └────────────────────┼──────────────────────┘             │
│                              │                                    │
│                    ┌─────────▼─────────┐                         │
│                    │ TitleSearchService │ ← New Riverpod Provider │
│                    │ (Repository)       │                         │
│                    └─────────┬─────────┘                         │
└──────────────────────────────┼───────────────────────────────────┘
                               │ HTTPS
                    ┌──────────▼──────────┐
                    │  Supabase Edge       │
                    │  Functions           │
                    │                      │
                    │  ┌────────────────┐  │
                    │  │ title-extract  │  │ ← Document extraction
                    │  │                │  │   (OCR + Gemini)
                    │  └───────┬────────┘  │
                    │          │           │
                    │  ┌───────▼────────┐  │
                    │  │ title-analyze  │  │ ← Cross-reference engine
                    │  │                │  │   (18 checks)
                    │  └───────┬────────┘  │
                    │          │           │
                    │  ┌───────▼────────┐  │
                    │  │ title-report   │  │ ← Report generation
                    │  │                │  │   (PDF + structured JSON)
                    │  └────────────────┘  │
                    └──────────┬──────────┘
                               │
                    ┌──────────▼──────────┐
                    │  External APIs       │
                    │                      │
                    │  • Google Cloud      │
                    │    Vision (OCR)      │
                    │  • Gemini 2.0 Flash  │
                    │    (Extraction +     │
                    │     Analysis)        │
                    │  • Supabase Storage  │
                    │    (Document files)  │
                    └─────────────────────┘
```

### 5.2 Database Schema

```sql
-- ─── Title Searches ──────────────────────────────────────
CREATE TABLE title_searches (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID REFERENCES auth.users(id) NOT NULL,
  firm_id         UUID REFERENCES firms(id),

  -- Property identification
  district        TEXT NOT NULL,
  taluk           TEXT NOT NULL,
  village         TEXT NOT NULL,
  survey_number   TEXT NOT NULL,
  extent          DECIMAL,
  extent_unit     TEXT DEFAULT 'acres',

  -- Status tracking
  status          TEXT DEFAULT 'draft'
                  CHECK (status IN ('draft','extracting','analyzing','completed','error')),
  health_score    INTEGER,              -- 0–100%
  critical_count  INTEGER DEFAULT 0,
  warning_count   INTEGER DEFAULT 0,
  passed_count    INTEGER DEFAULT 0,

  -- Advocate's final opinion
  advocate_opinion TEXT,

  created_at      TIMESTAMPTZ DEFAULT now(),
  updated_at      TIMESTAMPTZ DEFAULT now()
);

-- ─── Uploaded Documents ──────────────────────────────────
CREATE TABLE title_documents (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  search_id       UUID REFERENCES title_searches(id) ON DELETE CASCADE,
  user_id         UUID REFERENCES auth.users(id) NOT NULL,

  document_type   TEXT NOT NULL
                  CHECK (document_type IN (
                    'sale_deed','parent_deed','grandparent_deed',
                    'encumbrance_certificate','patta','chitta',
                    'legal_heir_certificate','partition_deed',
                    'will','gift_deed','death_certificate',
                    'fmb_sketch','power_of_attorney','tax_receipt',
                    'other'
                  )),
  file_path       TEXT NOT NULL,           -- Supabase Storage path
  file_name       TEXT,
  file_size       INTEGER,
  mime_type       TEXT,

  -- Extraction results
  extracted_data  JSONB,                   -- Full structured extraction
  raw_text        TEXT,                     -- OCR text output
  extraction_confidence DECIMAL,           -- 0.0 – 1.0
  extraction_status TEXT DEFAULT 'pending'
                  CHECK (extraction_status IN ('pending','processing','completed','failed')),

  created_at      TIMESTAMPTZ DEFAULT now()
);

-- ─── Cross-Reference Findings ────────────────────────────
CREATE TABLE title_findings (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  search_id       UUID REFERENCES title_searches(id) ON DELETE CASCADE,

  check_code      TEXT NOT NULL,           -- e.g. 'SELLER_BUYER_LINKAGE'
  check_name      TEXT NOT NULL,           -- e.g. 'Seller→Buyer Linkage'
  severity        TEXT NOT NULL
                  CHECK (severity IN ('critical','warning','passed','info')),
  status          TEXT DEFAULT 'open'
                  CHECK (status IN ('open','acknowledged','resolved','false_positive')),

  description     TEXT NOT NULL,           -- Human-readable finding
  details         JSONB,                   -- Structured details (doc refs, field comparisons)
  recommendation  TEXT,                    -- Suggested action

  -- Which documents this finding relates to
  source_doc_ids  UUID[],                  -- Array of title_document IDs
  
  created_at      TIMESTAMPTZ DEFAULT now()
);

-- ─── Ownership Timeline ──────────────────────────────────
CREATE TABLE title_chain_links (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  search_id       UUID REFERENCES title_searches(id) ON DELETE CASCADE,
  source_doc_id   UUID REFERENCES title_documents(id),

  link_order      INTEGER NOT NULL,        -- Position in the chain (1 = oldest)
  transaction_type TEXT NOT NULL,          -- 'sale', 'gift', 'inheritance', 'partition', 'original_grant'
  transaction_date DATE,
  document_number TEXT,
  sro             TEXT,                    -- Sub-Registrar Office

  -- Parties
  from_party      JSONB,                   -- { name, father_name, variants }
  to_party        JSONB,

  -- Property state at this point
  survey_number   TEXT,
  extent          DECIMAL,
  extent_unit     TEXT,
  classification  TEXT,

  created_at      TIMESTAMPTZ DEFAULT now()
);

-- ─── RLS Policies ────────────────────────────────────────
ALTER TABLE title_searches ENABLE ROW LEVEL SECURITY;
ALTER TABLE title_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE title_findings ENABLE ROW LEVEL SECURITY;
ALTER TABLE title_chain_links ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users see own searches"
  ON title_searches FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "Users see own documents"
  ON title_documents FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "Users see own findings"
  ON title_findings FOR ALL
  USING (search_id IN (SELECT id FROM title_searches WHERE user_id = auth.uid()));

CREATE POLICY "Users see own chain"
  ON title_chain_links FOR ALL
  USING (search_id IN (SELECT id FROM title_searches WHERE user_id = auth.uid()));
```

### 5.3 Edge Function: `title-extract`

```
POST /functions/v1/title-extract

Request:
{
  "search_id": "uuid",
  "document_id": "uuid",
  "document_type": "sale_deed",
  "file_path": "title-docs/uuid/sale_deed.pdf"
}

Processing:
1. Download file from Supabase Storage
2. If PDF → extract images per page
3. Send to Google Cloud Vision API for OCR
4. Send OCR text + document_type to Gemini with structured extraction prompt
5. Validate extracted JSON against schema
6. Store in title_documents.extracted_data
7. Return extraction with confidence score

Response:
{
  "success": true,
  "document_id": "uuid",
  "extracted_data": { ... },
  "confidence": 0.92,
  "warnings": ["Page 3 had low OCR confidence (0.65)"]
}
```

### 5.4 Edge Function: `title-analyze`

```
POST /functions/v1/title-analyze

Request:
{
  "search_id": "uuid"
}

Processing:
1. Fetch all extracted documents for this search
2. Build ownership timeline (title_chain_links)
3. Run 18 cross-reference checks
4. For ambiguous cases, use Gemini to reason about inconsistencies
5. Generate findings with severity ratings
6. Calculate overall health score
7. Store findings in title_findings

Response:
{
  "success": true,
  "health_score": 72,
  "critical_count": 2,
  "warning_count": 3,
  "passed_count": 13,
  "chain": [ ... ],
  "findings": [ ... ]
}
```

### 5.5 Fuzzy Name Matching Algorithm

```
┌──────────────────────────────────────────────────────────┐
│              NAME MATCHING PIPELINE                       │
│                                                           │
│  Input: "S. Ramasamy" vs "Ramaswami S/o Shanmugam"      │
│                                                           │
│  Step 1: NORMALIZE                                        │
│    - Remove titles (Sri, Thiru, Mr., Mrs.)               │
│    - Remove S/o, D/o, W/o prefixes                       │
│    - Expand initials ("S." → compare with father name)   │
│    - Lowercase, trim, remove extra spaces                │
│                                                           │
│  Step 2: TRANSLITERATE                                    │
│    - Tamil → English phonetic mapping                     │
│    - "ராமசாமி" → "Ramasamy" / "Ramaswami"               │
│    - Handle common variations: samy/swami, an/am, etc.   │
│                                                           │
│  Step 3: FUZZY MATCH                                      │
│    - Jaro-Winkler distance (threshold: 0.85)             │
│    - Soundex/Metaphone for phonetic matching             │
│    - Token sort ratio (handles word order differences)   │
│                                                           │
│  Step 4: CONTEXTUAL CONFIRMATION                          │
│    - If name similarity > 0.85 AND father name matches   │
│      → SAME PERSON (high confidence)                     │
│    - If name similarity > 0.85 but father name differs   │
│      → FLAG for advocate review                          │
│    - If name similarity < 0.70                           │
│      → DIFFERENT PERSON                                  │
│                                                           │
│  Output: { match: true, confidence: 0.91,                │
│            reason: "Phonetic match + father name match"} │
└──────────────────────────────────────────────────────────┘
```

---

## 6. User Experience Flow

### 6.1 End-to-End Journey

```
┌──────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐
│  CREATE   │────▶│  UPLOAD  │────▶│ EXTRACT  │────▶│ ANALYZE  │────▶│  REPORT  │
│  Search   │     │  Docs    │     │  Data    │     │  Chain   │     │  Review  │
└──────────┘     └──────────┘     └──────────┘     └──────────┘     └──────────┘
     │                │                │                │                │
  Advocate         Advocate          AI runs          AI runs         Advocate
  enters           uploads          OCR +            18 cross-       reviews,
  property         PDF/photos       Gemini           reference       edits, adds
  details          of documents     extraction       checks          opinion,
                                                                     exports PDF
```

### 6.2 Mobile App Screens

| # | Screen | Purpose |
|---|--------|---------|
| 1 | **Title Search List** | Dashboard showing all past and ongoing title searches |
| 2 | **New Title Search** | Property details form + document upload |
| 3 | **Document Preview** | View uploaded document with extracted data overlay |
| 4 | **Extraction Review** | Review AI-extracted fields, correct if needed |
| 5 | **Analysis Progress** | Real-time progress as checks run |
| 6 | **Title Health Report** | Full report with chain visualization, findings, and health score |
| 7 | **Finding Detail** | Detailed view of a single finding with source documents side-by-side |
| 8 | **Advocate Opinion** | Text editor for final title opinion |
| 9 | **PDF Preview** | Preview of the final exportable report |

---

## 7. Tamil Nadu–Specific Intelligence

### 7.1 Re-Survey Mapping

Tamil Nadu underwent district-wide land re-surveys that changed survey numbers. The system must maintain a mapping:

| District | Re-Survey Year | Old → New Format |
|----------|---------------|-----------------|
| Tirunelveli | 2001 | Old S.No → New S.No/subdivision |
| Madurai | 1998 | Old S.No → New S.No |
| Coimbatore | 2005 | Old S.No → New S.No |

### 7.2 Known Fraud Patterns

| Pattern | Detection Rule |
|---------|---------------|
| **GPA + Agreement + Will** | If documents include GPA + unregistered agreement + Will → flag "Benami Transaction" risk |
| **Patta Transfer Without Deed** | Patta in buyer's name but no registered sale deed → flag "Invalid Transfer" |
| **Natham Land Sold as Panchayat** | Natham land (village settlement) claimed as agricultural → flag classification discrepancy |
| **Temple/Waqf Land Sale** | Any reference to temple trust or waqf board in chain → flag "Inalienable Property" risk |
| **Women's Property Rights** | Pre-2005 Hindu Succession Act transactions involving daughter's share → flag for amendment compliance |

### 7.3 Legal Act References

The system should cite relevant sections when flagging issues:

| Issue | Relevant Law |
|-------|-------------|
| Chain break | Transfer of Property Act, 1882, Section 54 |
| GPA sale | Supreme Court in Suraj Lamp & Industries v. State of Haryana (2012) |
| Limitation | Limitation Act, 1963, Article 65 (12-year adverse possession) |
| Stamp duty | Indian Stamp Act, 1899 / TN Stamp Act |
| Mortgage | Transfer of Property Act, Section 58 |
| Partition | Hindu Succession Act, 1956, Section 6 (amended 2005) |
| Will | Indian Succession Act, 1925 / Hindu Succession Act |
| Minor's property | Guardians and Wards Act, 1890 |

---

## 8. Monetization Strategy

### 8.1 Pricing Model

| Tier | Price | Includes |
|------|-------|----------|
| **CaseFlow Free** | ₹0/month | 0 title searches (feature locked) |
| **CaseFlow Pro** | ₹999/month | 5 title searches/month |
| **CaseFlow Pro+** | ₹2,499/month | 20 title searches/month |
| **CaseFlow Enterprise** | Custom | Unlimited + API access + bank integration |
| **Pay-Per-Search** | ₹299/search | For non-subscribers |

### 8.2 Revenue Projections

| Metric | Year 1 | Year 2 | Year 3 |
|--------|--------|--------|--------|
| Active Pro+ subscribers | 200 | 1,000 | 5,000 |
| Searches/month | 2,000 | 15,000 | 80,000 |
| MRR | ₹5L | ₹30L | ₹1.5Cr |
| API cost/search (Cloud Vision + Gemini) | ~₹15 | ~₹10 | ~₹7 |
| Gross margin | ~70% | ~80% | ~85% |

---

## 9. Implementation Roadmap

### Phase 1: MVP (8 weeks)

| Week | Milestone |
|------|-----------|
| 1–2 | Database schema + Supabase migrations + Storage bucket setup |
| 3–4 | Edge Function: `title-extract` (OCR + Gemini structured extraction for sale deed, EC, patta) |
| 5–6 | Edge Function: `title-analyze` (5 core checks: chain linkage, survey match, extent match, name match, EC coverage) |
| 7 | Mobile UI: Upload flow + Report viewer |
| 8 | Testing with 10 real title chains from Tirunelveli district |

**MVP Scope:**
- 3 document types only: Sale Deed, EC, Patta (typed/printed, English + Tamil)
- 5 cross-reference checks
- Basic Title Health Report (no PDF export yet)
- Tamil Nadu only

### Phase 2: Full Product (Weeks 9–16)

| Deliverable | Details |
|-------------|---------|
| Full 18 checks | All cross-reference checks operational |
| Parent deed + LHC support | Complete chain of title |
| Fuzzy name matching | Transliteration-aware |
| PDF report export | Professional branded report |
| Re-survey mapping | TN district-wise |
| Red flag detection | GPA, undivided share, govt land |

### Phase 3: Scale (Weeks 17–24)

| Deliverable | Details |
|-------------|---------|
| Multi-state support | Karnataka, Kerala, AP/Telangana |
| Handwritten document OCR | Enhanced models for older deeds |
| Bank API integration | Title verification API for mortgage lenders |
| Batch processing | Upload 10+ properties at once |
| Title insurance partnership | Risk scoring for insurers |

---

## 10. Success Metrics

| KPI | Target (6 months) |
|-----|-------------------|
| Title searches completed | 5,000+ |
| Average time to report | < 15 minutes (vs 2–5 days manual) |
| Inconsistency detection accuracy | > 90% (validated by advocates) |
| False positive rate | < 15% |
| User retention (title search users) | > 60% monthly |
| NPS from property advocates | > 50 |
| Revenue from title module | ₹5L MRR |

---

## 11. Risks & Mitigations

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| OCR accuracy on old documents | High | High | Start with typed docs only. Add confidence scores. Let advocates correct extractions. |
| Name matching false positives | Medium | Medium | Multi-signal approach (name + father name + address). Always flag, never auto-resolve. |
| Legal liability if AI misses issue | High | Critical | **NEVER position as replacing advocate judgment.** Always present as "assistant" with mandatory advocate review. |
| Gemini API cost at scale | Medium | Medium | Cache common extraction patterns. Batch processing. Negotiate enterprise pricing. |
| State-specific document format variations | High | Medium | Start Tamil Nadu only. Template per state. Community-contributed templates. |
| Competitor launches similar product | Medium | Medium | First-mover advantage. Deep CaseFlow integration. TN-specific intelligence as moat. |

---

## 12. Competitive Landscape

| Competitor | Approach | CaseFlow Advantage |
|------------|----------|--------------------|
| **Manual (Status Quo)** | Paper-based cross-referencing | 10x faster, catches more inconsistencies |
| **Teal (teal.co.in)** | Property document management | We do analysis, not just storage |
| **SahiPropDeal** | Title verification marketplace | We're embedded in the advocate's daily workflow (CaseFlow) |
| **Bank internal tools** | Custom title check systems | We serve advocates directly; banks are Phase 3 customers |
| **Generic AI (ChatGPT/Gemini)** | Upload docs and ask questions | No structured cross-referencing, no domain-specific checks, no report format |

**CaseFlow's Moat:**
1. Already on the advocate's phone (existing user base)
2. Deep Tamil Nadu legal intelligence (re-surveys, fraud patterns, local laws)
3. Structured cross-referencing engine (not just chat-based)
4. Professional report output (PDF that advocates can hand to clients)

---

<p align="center">
  <strong>Document End</strong><br/>
  <em>CaseFlow — The Intelligent Operating System for Indian Legal Practice</em>
</p>
