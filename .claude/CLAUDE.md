## Machine-Readable Artefacts

The following files in `.machine_readable/` contain structured project metadata:

- `.machine_readable/6a2/STATE.a2ml` - Current project state and progress
- `.machine_readable/6a2/META.a2ml` - Architecture decisions and development practices
- `.machine_readable/6a2/ECOSYSTEM.a2ml` - Position in the ecosystem and related projects
- `.machine_readable/6a2/AGENTIC.a2ml` - AI agent interaction patterns
- `.machine_readable/6a2/NEUROSYM.a2ml` - Neurosymbolic integration config
- `.machine_readable/6a2/PLAYBOOK.a2ml` - Operational runbook

---

# CLAUDE.md - Bofig Project Instructions

## Current Phase: Phase 2 — Lithoglyph Migration

**ADR-006 (2026-03-13):** Lithoglyph replaces ArangoDB as primary data store.

### Pipeline
```
Docudactyl (extraction) → Lithoglyph (storage + provenance) ← bofig (queries + visualisation)
```

### Migration Status
- Evidence reads/writes: **migrating** from ArangoDB → Lithoglyph GQL
- Entities: **migrating** from ArangoDB → Lithoglyph
- Claims: **pending** migration to Lithoglyph
- Relationships (graph edges): **ArangoDB** (kept until Lithoglyph Factor GQL gets graph traversals)
- User auth: **PostgreSQL** (permanent, phx.gen.auth)

### Critical Architecture Rules
1. **New domain data features MUST target Lithoglyph**, not ArangoDB
2. **ArangoDB is deprecated for domain data** — only `relationships` edge collection remains
3. **PostgreSQL is for user auth ONLY** — never store domain data there
4. **PROMPT scores** have exactly 6 dimensions (Provenance, Replicability, Objective, Methodology, Publication, Transparency)
5. **Audience types** are: researcher, policymaker, skeptic, activist, affected_person, journalist

## Build & Test

```bash
# Compile (0 warnings required)
mix compile --warnings-as-errors

# Tests (require PostgreSQL + ArangoDB running)
mix test                    # 257 tests

# NER extractor tests only (no DB needed)
MIX_ENV=test mix run --no-start -e '
  ExUnit.start(autorun: false)
  Code.require_file("test/evidence_graph/lithoglyph/ner_extractor_test.exs")
  ExUnit.run()
'

# Credo lint
mix credo --strict

# Start dev server
mix phx.server
```

## Key Modules

| Module | Purpose | DB |
|--------|---------|-----|
| `EvidenceGraph.Lithoglyph.Client` | Req HTTP client for Lithoglyph API | Lithoglyph |
| `EvidenceGraph.Lithoglyph.Importer` | GenServer batch import with NER | Lithoglyph → ArangoDB |
| `EvidenceGraph.Lithoglyph.NERExtractor` | Regex NER extraction from content | None (pure) |
| `EvidenceGraph.Entities` | Entity resolution, fuzzy match, merge | ArangoDB (migrating) |
| `EvidenceGraph.Claims` | Claim CRUD + PROMPT scoring | ArangoDB (migrating) |
| `EvidenceGraph.Evidence` | Evidence CRUD + metadata | ArangoDB (migrating) |
| `EvidenceGraph.Relationships` | Graph edges, traversals, contradictions | ArangoDB (kept Phase 2) |
| `EvidenceGraph.ArangoDB` | ArangoDB driver wrapper | ArangoDB |

## ArangoDB Query Patterns

```elixir
# Read query (no write transaction)
ArangoDB.query_read(aql, %{bind_var: value})

# Write query (transactional)
ArangoDB.query(aql, %{bind_var: value})

# Insert document
ArangoDB.insert("collection_name", %{field: value})

# Edge document format
%{
  _from: "evidence/evidence_123",
  _to: "entities/entity_456",
  relationship_type: "mentions",
  weight: 1.0,
  confidence: 0.9
}
```

## Lithoglyph Client Patterns

```elixir
# Query evidence from Lithoglyph
LithClient.query("SELECT * FROM evidence WHERE investigation_id = @id", %{id: inv_id})

# Insert with provenance (mandatory)
LithClient.insert("evidence", document, actor: "user:123", rationale: "Import from Docudactyl")

# Dedup check
LithClient.exists_by_hash?("evidence", sha256_hash)
```

## Language Policy (Hyperpolymath Standard)

### ALLOWED Languages & Tools

| Language/Tool | Use Case | Notes |
|---------------|----------|-------|
| **Elixir** | This project's primary language | Phoenix, LiveView, Absinthe |
| **AffineScript** | Primary application code | Affine-typed, compiles to typed-wasm or Deno-ESM |
| **Deno** | Runtime & package management | Replaces Node/npm/bun |
| **Rust** | Performance-critical, systems, WASM | Preferred for CLI tools |
| **Gleam** | Backend services | Runs on BEAM or compiles to JS |
| **Bash/POSIX Shell** | Scripts, automation | Keep minimal |
| **JavaScript** | Only where AffineScript cannot | D3.js hooks in this project |
| **Guile Scheme** | State/meta files | .machine_readable/6a2/STATE.a2ml, .machine_readable/6a2/META.a2ml, .machine_readable/6a2/ECOSYSTEM.a2ml |

### BANNED - Do Not Use

| Banned | Replacement |
|--------|-------------|
| TypeScript | AffineScript |
| Node.js | Deno |
| npm/Bun/pnpm/yarn | Deno |
| Go | Rust |
| Python | Julia/Rust/ReScript |
| Java/Kotlin | Rust |

### Security Requirements

- No MD5/SHA1 for security (use SHA256+)
- HTTPS only (no HTTP URLs)
- No hardcoded secrets
- SHA-pinned dependencies in workflows
- SPDX license headers on all files (`MPL-2.0`)
