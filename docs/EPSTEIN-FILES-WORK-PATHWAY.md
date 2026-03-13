# Epstein Files — Complete Work Pathway
# Tests & Benchmarks at Every Stage
#
# SPDX-License-Identifier: PMPL-1.0-or-later
# Author: Jonathan D.A. Jewell
# Created: 2026-03-11
#
# This document maps every implementation step needed to process the
# Epstein files (3M+ files, 218GB, 12 data sets, 23K entities) through
# the Docudactyl → Lithoglyph → Bofig pipeline, with test criteria
# and performance benchmarks for each milestone.

---

## Dataset Characteristics

| Attribute | Value |
|-----------|-------|
| Total files | ~3,200,000 |
| Total size | ~218 GB |
| Data sets | 12 (flight logs, court filings, depositions, financial records, photos, communications, ...) |
| Named entities (est.) | 23,000+ unique persons, orgs, locations |
| Primary format | Scanned PDF (96 DPI, many poor quality) |
| Secondary formats | TIFF, JPEG, DOCX, XLS, email (EML/PST) |
| Redaction style | Overlay-only (text stream often intact) |
| Financial transactions (est.) | 16,000+ |
| Languages | English (primary), French, some Spanish |
| Time span | 1990s–2024 |

---

## Phase 1: Docudactyl Extraction Pipeline (Weeks 1–6)

### Step 1.1: Core OCR + Text Extraction (DONE — existing stages 0-8)

Already implemented in `stages.zig`:
- Language detection, readability, keywords, citations
- OCR confidence, perceptual hash, TOC extraction
- Multi-language OCR, subtitle extraction

**Tests:**
- [x] Unit test: each stage function with known input produces expected Cap'n Proto output
- [x] Integration test: 10-document mini-corpus end-to-end
- [ ] Benchmark: single-node throughput for scanned PDFs (target: 2 docs/sec on 8-core)

### Step 1.2: Redaction Detection (DONE — bit 20, `stageRedactionDetect`)

Scans Poppler annotations for Type 12 (POPPLER_ANNOT_REDACT), checks if
text is extractable under overlay-only redactions.

**Tests:**
- [ ] T-RED-1: Synthetic PDF with 5 /Redact annotations → count=5, status="redacted"
- [ ] T-RED-2: PDF with black fill rectangles but no /Redact annots → status="clean" (future: heuristic upgrade)
- [ ] T-RED-3: PDF with overlay redaction + recoverable text → recoverable_count > 0
- [ ] T-RED-4: Non-PDF input (JPEG) → status="not_applicable"
- [ ] T-RED-5: Corrupt/unreadable PDF → status="error"

**Benchmarks:**
- [ ] B-RED-1: 1000 PDFs (mixed redacted/clean) — target: <500ms per document
- [ ] B-RED-2: Memory usage during annotation scan — target: <50MB peak per document

### Step 1.3: Financial Entity Extraction (DONE — bit 21, `stageFinancialExtract`)

Pattern-based detection of currency symbols ($, £, €), ISO codes (USD, GBP, EUR, CHF, JPY, CAD),
account-like digit sequences (8-20 digits).

**Tests:**
- [ ] T-FIN-1: Text "$1,234.56 paid to account 12345678" → amounts=1, accounts=1
- [ ] T-FIN-2: Text "USD 50,000 transferred" → amounts=1
- [ ] T-FIN-3: Text "£2.3 million to HSBC account 1234-5678-9012" → amounts=1, accounts=1
- [ ] T-FIN-4: Phone numbers should NOT match as accounts (7-digit filter)
- [ ] T-FIN-5: Empty text → status="none_found", amounts=0, accounts=0
- [ ] T-FIN-6: Mixed currencies in single document → correct total count

**Benchmarks:**
- [ ] B-FIN-1: 10MB text document scan — target: <200ms
- [ ] B-FIN-2: Accuracy on annotated Epstein financial records sample (50 docs) — target: >80% recall

### Step 1.4: Legal NER (DONE — bit 22, `stageLegalNer`)

Pattern-based detection of case citations ("v."), docket numbers ("No.", "Case"),
statute references ("U.S.C.", "§").

**Tests:**
- [ ] T-LEG-1: "Doe v. Epstein" → case_citations=1
- [ ] T-LEG-2: "No. 08-cv-1234" → docket_refs=1
- [ ] T-LEG-3: "18 U.S.C. § 1591" → statute_refs=1 (both U.S.C. and § counted)
- [ ] T-LEG-4: "vs." variant → case_citations=1
- [ ] T-LEG-5: Real Epstein court filing excerpt → realistic counts
- [ ] T-LEG-6: Non-legal document (flight log) → all counts = 0

**Benchmarks:**
- [ ] B-LEG-1: 5MB legal document — target: <150ms
- [ ] B-LEG-2: Precision on annotated legal corpus (100 docs) — target: >75%

### Step 1.5: Speaker Identification (bit 23, ML dispatch)

ML-based speaker diarization via ONNX Runtime. Dispatches to stage_id=5
(speaker_id.onnx model).

**Tests:**
- [ ] T-SPK-1: With ML handle + model → status="ok", speaker_count > 0
- [ ] T-SPK-2: Without ML handle → status="not_available"
- [ ] T-SPK-3: Non-audio input → graceful fallback
- [ ] T-SPK-4: Deposition audio with 2 speakers → speaker_count=2

**Benchmarks:**
- [ ] B-SPK-1: 30-minute deposition audio — target: <60s inference
- [ ] B-SPK-2: Memory usage during diarization — target: <2GB

### Step 1.6: STAGE_INVESTIGATIVE Preset Validation

The `STAGE_INVESTIGATIVE` preset combines all investigative stages.

**Tests:**
- [ ] T-INV-1: STAGE_INVESTIGATIVE includes bits 20-23
- [ ] T-INV-2: STAGE_ALL includes all 24 stages
- [ ] T-INV-3: runStages with STAGE_INVESTIGATIVE on a legal PDF → all 4 stages produce output
- [ ] T-INV-4: runStages with STAGE_INVESTIGATIVE on audio file → speaker ID runs, redaction skipped

### Step 1.7: Multi-Locale HPC Cluster Test (D1)

Chapel-based parallel processing on GASNet/IBV transport.

**Tests:**
- [ ] T-HPC-1: 4-node cluster processes 100 documents without error
- [ ] T-HPC-2: Load balancing: no single node processes >40% of total
- [ ] T-HPC-3: Node failure recovery: cluster continues if 1 of 4 nodes drops
- [ ] T-HPC-4: Identical results on 1-node vs 4-node runs (determinism)

**Benchmarks:**
- [ ] B-HPC-1: 10,000 scanned PDFs on 4-node cluster — target: <30 minutes
- [ ] B-HPC-2: 100,000 PDFs on 16-node cluster — target: <2 hours
- [ ] B-HPC-3: Linear scaling factor — target: >0.7x per added node
- [ ] B-HPC-4: Full Epstein corpus (3.2M files) on 256 nodes — target: <4 hours

---

## Phase 2: Lithoglyph Ingest & Storage (Weeks 4–10)

### Step 2.1: Zig 0.15.2 HTTP API Migration (L1)

83 call sites need updating for the new Zig HTTP API.

**Tests:**
- [ ] T-ZIG-1: All 83 call sites compile with zig 0.15.2
- [ ] T-ZIG-2: HTTP server starts and responds to GET /health
- [ ] T-ZIG-3: GQL INSERT via HTTP returns 200 + created record ID
- [ ] T-ZIG-4: Concurrent 100-request stress test — no crashes

**Benchmarks:**
- [ ] B-ZIG-1: GQL INSERT latency — target: <5ms p99
- [ ] B-ZIG-2: Batch INSERT (1000 records) — target: <500ms total

### Step 2.2: Evidence Collection Schema (L3)

Collections: `bofig_evidence`, `bofig_claims`, `bofig_relationships`

**Tests:**
- [ ] T-EVD-1: CREATE bofig_evidence collection succeeds
- [ ] T-EVD-2: INSERT evidence record with all PROMPT dimensions
- [ ] T-EVD-3: QUERY evidence by SHA-256 hash (dedup lookup)
- [ ] T-EVD-4: QUERY evidence by entity name (cross-reference)
- [ ] T-EVD-5: All mutations have actor + rationale (Lithoglyph invariant)

### Step 2.3: Financial Transaction Collection (L4)

Schema: source, destination, amount, currency, date, instrument, intermediary

**Tests:**
- [ ] T-FTX-1: INSERT transaction record with full fields
- [ ] T-FTX-2: QUERY transaction chain (A→B→C) via GQL path traversal
- [ ] T-FTX-3: Aggregate: total flow between two entities
- [ ] T-FTX-4: Temporal: transactions within date range
- [ ] T-FTX-5: Anomaly: detect round-number patterns (e.g., exactly $10,000)

**Benchmarks:**
- [ ] B-FTX-1: 16,000 transaction inserts — target: <10 seconds
- [ ] B-FTX-2: Transaction chain query (depth 5) — target: <100ms

### Step 2.4: Entity Collection + Co-Reference Resolution (L5)

Alias tracking: "Jeffrey Epstein" = "J. Epstein" = "Epstein, Jeffrey"

**Tests:**
- [ ] T-ENT-1: CREATE entity with primary name
- [ ] T-ENT-2: ADD alias to existing entity
- [ ] T-ENT-3: MERGE two entities (logged in journal with rationale)
- [ ] T-ENT-4: REVERSE merge (undo co-reference error)
- [ ] T-ENT-5: QUERY all documents mentioning entity (across aliases)
- [ ] T-ENT-6: No orphaned aliases after merge/unmerge cycle

**Benchmarks:**
- [ ] B-ENT-1: 23,000 entity inserts with alias resolution — target: <60 seconds
- [ ] B-ENT-2: Entity lookup by any alias — target: <10ms

### Step 2.5: Docudactyl → Lithoglyph Ingest Bridge (D2 + L6)

Cap'n Proto → GQL INSERT with auto-PROMPT scoring.

**Tests:**
- [ ] T-BRG-1: Single Cap'n Proto StageResults → Lithoglyph evidence record
- [ ] T-BRG-2: PROMPT auto-scoring from extraction metadata:
  - OCR confidence 90+ → Provenance score 0.8+
  - Multiple corroborating documents → Replicability score increases
  - Court filing (official source) → Publication score 0.9+
- [ ] T-BRG-3: SHA-256 dedup: duplicate document skipped with log
- [ ] T-BRG-4: Batch import 1000 records — all arrive with provenance
- [ ] T-BRG-5: Actor="docudactyl-pipeline", Rationale includes run ID

**Benchmarks:**
- [ ] B-BRG-1: 10,000 records batch import — target: <30 seconds
- [ ] B-BRG-2: 3.2M records full import — target: <6 hours

---

## Phase 3: Bofig Evidence Graph (Weeks 8–14)

### Step 3.1: Entity Resolution Module (B1)

NER output → co-reference → unified entity graph in ArangoDB.

**Tests:**
- [ ] T-ER-1: "J. Epstein" and "Jeffrey Epstein" merge to one vertex
- [ ] T-ER-2: "Ghislaine Maxwell" and "G. Maxwell" merge
- [ ] T-ER-3: "Bill Clinton" and "William J. Clinton" merge
- [ ] T-ER-4: "John Smith" NOT auto-merged with different "John Smith" (ambiguity threshold)
- [ ] T-ER-5: Merge decision logged in Lithoglyph journal
- [ ] T-ER-6: Undo merge restores two separate entities

**Benchmarks:**
- [ ] B-ER-1: 23,000 entities resolved in — target: <5 minutes
- [ ] B-ER-2: Co-reference accuracy on annotated subset — target: >85%

### Step 3.2: Financial Transaction Graph + GraphQL (B2)

New GraphQL queries for transaction analysis.

**Tests:**
- [ ] T-FGQL-1: `transactionChain(entityId, depth: 3)` returns connected flows
- [ ] T-FGQL-2: `totalFlow(from, to, dateRange)` returns aggregate
- [ ] T-FGQL-3: `anomalies(entityId)` flags round numbers, structuring patterns
- [ ] T-FGQL-4: Sankey diagram data format correct for D3.js
- [ ] T-FGQL-5: Empty result for entity with no transactions

**Benchmarks:**
- [ ] B-FGQL-1: Transaction chain depth 5 with 16K transactions — target: <200ms
- [ ] B-FGQL-2: Full Sankey data for top 20 entities — target: <1s

### Step 3.3: Timeline D3 Visualization (B3)

Event reconstruction from extracted dates across documents.

**Tests:**
- [ ] T-TL-1: Timeline renders with 100+ events
- [ ] T-TL-2: Zoom to month/week/day granularity
- [ ] T-TL-3: Click event → source document link
- [ ] T-TL-4: Filter by entity (e.g., show only events involving "Epstein")
- [ ] T-TL-5: Temporal credibility overlay (L7 data)

**Benchmarks:**
- [ ] B-TL-1: Render 10,000 events — target: <2s initial load
- [ ] B-TL-2: Filter/zoom response — target: <200ms

### Step 3.4: Witness Testimony Module (B4)

Speaker ID + claim extraction + corroboration scoring.

**Tests:**
- [ ] T-WIT-1: Deposition text → extracted claims with speaker attribution
- [ ] T-WIT-2: Corroboration: claim in deposition A matches claim in deposition B → score increases
- [ ] T-WIT-3: Contradiction: claim A contradicts claim B → flagged with both sources
- [ ] T-WIT-4: Impeachment detection: witness statement contradicts own prior statement
- [ ] T-WIT-5: PROMPT scores for testimony weighted by speaker credibility

### Step 3.5: Contradiction Dashboard (B6)

Automated surfacing of conflicting accounts.

**Tests:**
- [ ] T-CTR-1: Two documents with contradictory claims → contradiction record created
- [ ] T-CTR-2: UI displays both sources with PROMPT scores
- [ ] T-CTR-3: Resolution: user can mark contradiction as "resolved" with rationale
- [ ] T-CTR-4: Filter contradictions by entity, date, topic
- [ ] T-CTR-5: Priority ranking by evidence quality (higher PROMPT = more serious contradiction)

### Step 3.6: Batch Evidence Import (B5)

GenServer consuming Docudactyl output.

**Tests:**
- [ ] T-BEI-1: GenServer starts and connects to Lithoglyph
- [ ] T-BEI-2: Process 100 records → all visible in Bofig UI
- [ ] T-BEI-3: Duplicate handling: same SHA-256 → skip with log
- [ ] T-BEI-4: Error recovery: malformed record → skip, continue, report
- [ ] T-BEI-5: Progress reporting: "Imported 5000/10000 records"

**Benchmarks:**
- [ ] B-BEI-1: 10,000 records import → visible in UI — target: <2 minutes
- [ ] B-BEI-2: Memory usage during import — target: <500MB

---

## Phase 4: Investigation Features (Weeks 12–18)

### Step 4.1: Redaction Audit Trail (B11 + D6)

Track what was redacted, by whom, whether text was recovered.

**Tests:**
- [ ] T-RAT-1: Docudactyl flags redacted document → Bofig shows redaction badge
- [ ] T-RAT-2: Recovered text (overlay-only) → available but marked as "recovered from redaction"
- [ ] T-RAT-3: Timeline: document first released redacted (2020), unredacted version released (2023)
- [ ] T-RAT-4: Audit: who accessed recovered text, when, for what purpose
- [ ] T-RAT-5: Integration with Lithoglyph journal — reversible access grants

### Step 4.2: RBAC + Sensitivity (B10)

Graduated access for sensitive evidence.

**Tests:**
- [ ] T-RBAC-1: Sealed material visible only to authorized users
- [ ] T-RBAC-2: Source protection: informant identity hidden from non-editors
- [ ] T-RBAC-3: Export restrictions: sensitive evidence not included in public reports
- [ ] T-RBAC-4: Audit log: all access to sensitive material recorded
- [ ] T-RBAC-5: Role hierarchy: admin > editor > viewer > public

### Step 4.3: Full-Text Search + Faceted Filters (B9)

ArangoDB fulltext indexes with faceted navigation.

**Tests:**
- [ ] T-FTS-1: Search "Lolita Express" → relevant flight log documents
- [ ] T-FTS-2: Facet by document type (court filing, deposition, financial record)
- [ ] T-FTS-3: Facet by date range
- [ ] T-FTS-4: Facet by entity involvement
- [ ] T-FTS-5: Highlight search terms in results

**Benchmarks:**
- [ ] B-FTS-1: Full-text search across 3.2M documents — target: <500ms
- [ ] B-FTS-2: Faceted filter application — target: <200ms

### Step 4.4: Temporal Credibility Model (L7)

Source reputation evolving over time.

**Tests:**
- [ ] T-TCR-1: New source starts at neutral credibility
- [ ] T-TCR-2: Source's claim independently verified → credibility increases
- [ ] T-TCR-3: Source caught in contradiction → credibility decreases
- [ ] T-TCR-4: Source retraction → credibility impact + retraction logged
- [ ] T-TCR-5: Time-travel: "What was this source's credibility on 2023-01-15?"
- [ ] T-TCR-6: Credibility affects PROMPT scores of all evidence from that source

---

## Phase 5: Scale & Production (Weeks 16–22)

### Step 5.1: Full Corpus Run

Process all 3.2M Epstein files through the complete pipeline.

**Tests:**
- [ ] T-FCR-1: All files processed without pipeline crash
- [ ] T-FCR-2: <0.1% error rate (files that failed extraction)
- [ ] T-FCR-3: Dedup: identify exact duplicates across data sets
- [ ] T-FCR-4: Near-dedup: identify visually similar images (perceptual hash)
- [ ] T-FCR-5: Entity graph fully connected (no isolated entity clusters that should be linked)

**Benchmarks:**
- [ ] B-FCR-1: Full extraction (256 nodes) — target: <4 hours
- [ ] B-FCR-2: Full Lithoglyph import — target: <8 hours
- [ ] B-FCR-3: Full entity resolution — target: <2 hours
- [ ] B-FCR-4: Total pipeline cold start to searchable — target: <24 hours
- [ ] B-FCR-5: Storage: Lithoglyph database size — target: <100GB for metadata (excl. raw files)

### Step 5.2: Cross-Investigation Linking (L8)

Shared evidence across investigations (Epstein ↔ Maxwell ↔ related cases).

**Tests:**
- [ ] T-XIL-1: Evidence in investigation A also relevant to investigation B → linked
- [ ] T-XIL-2: Entity appearing in both investigations → surfaced automatically
- [ ] T-XIL-3: New investigation inherits relevant evidence from existing investigations
- [ ] T-XIL-4: Access controls per investigation (B10)

### Step 5.3: IPFS Provenance (B12)

Tamper-proof evidence archival.

**Tests:**
- [ ] T-IPFS-1: Evidence pinned to IPFS with CID stored in Lithoglyph
- [ ] T-IPFS-2: Retrieve evidence by CID → matches SHA-256 in Lithoglyph
- [ ] T-IPFS-3: Evidence tampering detected (hash mismatch)
- [ ] T-IPFS-4: Offline operation: evidence accessible from local cache when IPFS unavailable

### Step 5.4: Audience-Specific Navigation (All 6 Audience Types)

Each audience type sees the same evidence graph with different weighting.

**Tests:**
- [ ] T-AUD-1: Journalist view: balanced credibility, source protection, story threads
- [ ] T-AUD-2: Researcher view: methodology scores prominent, reproducibility highlighted
- [ ] T-AUD-3: Policymaker view: authoritative sources first, regulatory implications
- [ ] T-AUD-4: Affected person view: personal impact, clear language, trigger warnings
- [ ] T-AUD-5: Skeptic view: transparency scores, verification steps, weakest links highlighted
- [ ] T-AUD-6: Activist view: evidence quality, actionable findings, campaign-relevant
- [ ] T-AUD-7: Same evidence, different PROMPT dimension weights per audience → different ordering

---

## Summary: Work Completion Tracker

| # | Step | Repo | Status | Tests | Benchmarks |
|---|------|------|--------|-------|------------|
| 1.1 | Core OCR + Text | Docudactyl | DONE | Partial | 0/1 |
| 1.2 | Redaction Detection | Docudactyl | DONE (code) | 0/5 | 0/2 |
| 1.3 | Financial Extraction | Docudactyl | DONE (code) | 0/6 | 0/2 |
| 1.4 | Legal NER | Docudactyl | DONE (code) | 0/6 | 0/2 |
| 1.5 | Speaker ID | Docudactyl | DONE (dispatch) | 0/4 | 0/2 |
| 1.6 | Investigative Preset | Docudactyl | DONE | 0/4 | — |
| 1.7 | HPC Cluster Test | Docudactyl | TODO | 0/4 | 0/4 |
| 2.1 | Zig API Migration | Lithoglyph | **DONE** | 0/4 | 0/2 |
| 2.2 | Evidence Schema | Lithoglyph | **DONE** | 0/5 | — |
| 2.3 | Financial Txn Collection | Lithoglyph | TODO | 0/5 | 0/2 |
| 2.4 | Entity + Co-Ref | Lithoglyph | TODO | 0/6 | 0/2 |
| 2.5 | Ingest Bridge | Both | TODO | 0/5 | 0/2 |
| 3.1 | Entity Resolution | Bofig | TODO | 0/6 | 0/2 |
| 3.2 | Financial GraphQL | Bofig | TODO | 0/5 | 0/2 |
| 3.3 | Timeline Viz | Bofig | TODO | 0/5 | 0/2 |
| 3.4 | Witness Testimony | Bofig | TODO | 0/5 | — |
| 3.5 | Contradiction Dashboard | Bofig | TODO | 0/5 | — |
| 3.6 | Batch Import | Bofig | TODO | 0/5 | 0/2 |
| 4.1 | Redaction Audit | Bofig | TODO | 0/5 | — |
| 4.2 | RBAC | Bofig | TODO | 0/5 | — |
| 4.3 | Full-Text Search | Bofig | TODO | 0/5 | 0/2 |
| 4.4 | Temporal Credibility | Lithoglyph | TODO | 0/6 | — |
| 5.1 | Full Corpus Run | All | TODO | 0/5 | 0/5 |
| 5.2 | Cross-Investigation | Lithoglyph | TODO | 0/4 | — |
| 5.3 | IPFS Provenance | Bofig | TODO | 0/4 | — |
| 5.4 | Audience Navigation | Bofig | TODO | 0/7 | — |

**Totals: 130 tests, 35 benchmarks across 26 steps**
**Current: 4 steps code-complete, 0 tests written, 0 benchmarks run**

---

## Critical Path

```
D1 (HPC cluster) ──────────┐
L1 (Zig migration) ────┐   │
L2 (Rename) ────────────┤   │
                        ▼   ▼
                    L3 (Schema)
                        │
                    L6 (Bridge) ←── D2 (Adapter)
                        │
                    B5 (Import)
                        │
              ┌─────────┼─────────┐
              ▼         ▼         ▼
          B1 (Entity) B2 (Fin)  B3 (Timeline)
              │         │         │
              └─────────┼─────────┘
                        ▼
              B4 (Testimony) + B6 (Contradictions)
                        │
              B10 (RBAC) + B9 (Search)
                        │
                   5.1 (Full Run)
                        │
                   5.4 (Audiences)
```

**Longest path: D1 → L3 → L6 → B5 → B1 → B4 → B10 → 5.1 → 5.4 = 9 sequential dependencies**
**Estimated calendar: ~22 weeks with parallelism across repos**
