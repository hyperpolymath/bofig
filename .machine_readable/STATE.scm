;; SPDX-License-Identifier: PMPL-1.0-or-later
;; STATE.scm - Project state for bofig (Evidence Graph)
;; Media-Type: application/vnd.state+scm

(state
  (metadata
    (version "0.3.0")
    (schema-version "1.0")
    (created "2026-01-03")
    (updated "2026-02-22")
    (project "bofig")
    (repo "github.com/hyperpolymath/bofig"))

  (project-context
    (name "bofig")
    (tagline "Evidence Graph for Investigative Journalism")
    (description "Infrastructure for pragmatic epistemology — combining i-docs
     navigation, PROMPT framework scoring, and boundary objects theory to let
     multiple audiences (journalists, researchers, policymakers, activists)
     navigate the same evidence graph from their own perspective.")
    (tech-stack
      ("Elixir 1.16+" "Phoenix 1.8" "Absinthe (GraphQL)" "ArangoDB 3.11+"
       "Oban (background jobs)" "ReScript (D3.js viz)" "Idris2 (ABI proofs)"
       "Zig (FFI)")))

  (current-position
    (phase "implementation")
    (overall-completion 72)

    (components
      (component "elixir-core"
        (description "Claims, Evidence, Navigation, Relationships, PROMPT scoring")
        (status "mostly-complete")
        (completion 85)
        (notes "All context modules with real AQL queries. Graph traversal
         partially implemented. Claims CRUD, full-text search, relationship
         methods all working."))

      (component "graphql-api"
        (description "Absinthe schema — queries, mutations, type definitions")
        (status "complete")
        (completion 95)
        (notes "15 queries, 11 mutations, 5 type definition modules (256 lines).
         Covers claims, evidence, relationships, navigation paths, Zotero import.
         Router serves /api/graphql and /api/graphiql in dev."))

      (component "arangodb-integration"
        (description "Multi-model database client — documents + graph")
        (status "mostly-complete")
        (completion 90)
        (notes "Connection pooling, transaction support, CRUD, collection/index
         setup, full-text search via AQL FULLTEXT(). Production-ready core."))

      (component "configuration"
        (description "Mix config for dev/test/prod + runtime env")
        (status "mostly-complete")
        (completion 85)
        (notes "ArangoDB endpoints, Oban queues, esbuild, tailwind, logger.
         Zotero sync cron commented out (Phase 2)."))

      (component "mix-project"
        (description "Dependencies, aliases, compilation")
        (status "mostly-complete")
        (completion 90)
        (notes "Phoenix 1.8.3, Absinthe 1.7, arangox 0.7.0, Ecto, Oban,
         Tesla, Dataloader. IPFS commented out for Phase 2."))

      (component "tests"
        (description "ExUnit test suite")
        (status "not-started")
        (completion 0)
        (notes "CRITICAL GAP. Zero test files exist despite comprehensive
         testing strategy documented in CLAUDE.md. No test/ directory content."))

      (component "ci-cd"
        (description "GitHub Actions workflows")
        (status "mostly-complete")
        (completion 70)
        (notes "18 workflows: Elixir CI, CodeQL, Hypatia scan, quality checks,
         mirror, RSR enforcement, scorecard. All actions SHA-pinned.
         Some may need tuning for Elixir-specific configuration."))

      (component "abi-ffi"
        (description "Idris2 ABI proofs + Zig FFI implementation")
        (status "mostly-complete")
        (completion 80)
        (notes "Domain types: ClaimType, EvidenceType, RelationshipType,
         AudienceType, PromptScore, CPromptScores, CClaim, CRelationship,
         CPathNode. Layout proofs with field bounds. Zig FFI implements
         PROMPT overall/audience scoring, propagated weight, cycle detection.
         Comptime ABI verification. All Zig tests pass. All Idris2 compiles."))

      (component "documentation"
        (description "README, ARCHITECTURE, ROADMAP, TOPOLOGY, CLAUDE.md")
        (status "mostly-complete")
        (completion 85)
        (notes "Excellent ARCHITECTURE.md (566 lines, full data model).
         ROADMAP.adoc still generic template. TOPOLOGY.md present."))

      (component "rsr-compliance"
        (description "RSR standard files and structure")
        (status "mostly-complete")
        (completion 75)
        (notes "SPDX headers on all files. .machine_readable/ checkpoint files
         present but other SCM files still stubs. .well-known/ missing.
         Justfile present (duplicate justfile/Justfile)."))

      (component "frontend"
        (description "D3.js graph viz, LiveView UI, PROMPT scoring interface")
        (status "prototyping")
        (completion 25)
        (notes "ReScript D3.js module (193 lines) with force-directed graph.
         No LiveView components despite TOPOLOGY claiming 40%. No HTML
         templates, no CSS, no interactive PROMPT scoring UI."))

      (component "zotero-integration"
        (description "Two-way sync with Zotero reference manager")
        (status "mostly-complete")
        (completion 75)
        (notes "Tesla-based Zotero Web API v3 client with pagination, versioning.
         Bidirectional mapper (Zotero JSON ↔ Evidence Graph, Dublin Core,
         Schema.org). Sync coordinator with incremental sync via library
         versioning. Oban worker for 15-min periodic sync. Config in place.
         Remaining: integration tests, error recovery edge cases."))

      (component "seed-data"
        (description "UK Inflation 2023 test dataset")
        (status "complete")
        (completion 90)
        (notes "615-line seeds.exs: 7 claims, 10 evidence items, 10 relationships,
         3 navigation paths. Real investigation with PROMPT scores.
         Covers researcher, policymaker, affected_person audiences."))

      (component "contractiles"
        (description "Operational framework (Mustfile, Trustfile, Dustfile)")
        (status "scaffolded")
        (completion 10)
        (notes "Directory structure exists. README present. No operational
         invariants, crypto verification, or rollback semantics defined.")))

    (working-features
      ("GraphQL API (15 queries, 11 mutations)"
       "Claims CRUD with full-text search"
       "Evidence management with Zotero key lookup"
       "Relationship edge management (supports/contradicts/contextualizes)"
       "PROMPT scoring (6 dimensions, 6 audience weight profiles)"
       "Navigation path auto-generation by audience type"
       "ArangoDB multi-model storage (documents + graph)"
       "UK Inflation 2023 seed dataset"
       "GraphiQL playground at /api/graphiql")))

  (route-to-mvp
    (milestones
      (milestone "v0.1.0" "Foundation"
        (status "complete")
        (items
          ("Elixir/Phoenix project scaffold"
           "ArangoDB integration"
           "Core data model (Claims, Evidence, Relationships)"
           "GraphQL schema")))

      (milestone "v0.2.0" "PROMPT + Navigation"
        (status "complete")
        (items
          ("PROMPT scoring engine (6 dimensions)"
           "Audience-weighted scoring (6 profiles)"
           "Navigation path generation"
           "Seed data (UK Inflation 2023)")))

      (milestone "v0.3.0" "RSR Compliance"
        (status "complete")
        (items
          ("SPDX headers on all files"
           "SHA-pinned workflow actions"
           "ABI/FFI template filled"
           "Checkpoint protocol files"
           "AGPL → PMPL license migration")))

      (milestone "v0.4.0" "Testing + LiveView"
        (status "not-started")
        (items
          ("ExUnit test suite for all context modules"
           "LiveView investigation dashboard"
           "LiveView graph visualization (wiring D3.js)"
           "LiveView PROMPT scoring interface"
           "Integration tests for GraphQL")))

      (milestone "v0.5.0" "Zotero Integration"
        (status "not-started")
        (items
          ("Zotero API client (Tesla)"
           "Two-way sync via Oban"
           "Batch import/export"
           "Browser extension prototype")))

      (milestone "v1.0.0" "Production Release"
        (status "not-started")
        (items
          ("NUJ pilot (25 participants)"
           "ArangoDB performance benchmarks"
           "Deployment to Hetzner"
           "IPFS integration (Phase 2)"
           "Full documentation")))))

  (blockers-and-issues
    (critical
      ("Zero test coverage — no ExUnit tests exist"))
    (high
      ("No LiveView components — frontend entirely missing"
       ".well-known/ directory missing (security.txt, ai.txt, humans.txt)"))
    (medium
      ("ROADMAP.adoc still generic RSR template"
       "Duplicate justfile/Justfile"
       "Other .machine_readable/ SCM files still stubs"
       "Zotero integration needs integration tests"
       "ABI/FFI not yet integrated with Elixir via NIFs"))
    (low
      ("Contractiles directory mostly empty"
       "wiki/ referenced in README but not present")))

  (critical-next-actions
    (immediate
      ("Write ExUnit tests for Claims context"
       "Write ExUnit tests for Evidence context"
       "Write ExUnit tests for PROMPT scoring"))
    (this-week
      ("Create LiveView investigation dashboard"
       "Wire D3.js visualization into Phoenix"
       "Populate .well-known/ directory"))
    (this-month
      ("Implement Zotero API client"
       "Create LiveView PROMPT scoring interface"
       "Customize Idris2 ABI for Evidence Graph types"
       "NUJ pilot preparation")))

  (session-history
    (session "2026-01-03"
      (summary "Initial project setup, RSR template bootstrap"))
    (session "2026-01-25"
      (summary "Created checkpoint protocol files (.machine_readable/)"))
    (session "2026-02-21"
      (summary "RSR compliance pass: filled ABI/FFI templates, fixed AGPL→PMPL
       across all files, added SPDX headers to 30 Elixir files, SHA-pinned
       16 workflow actions, updated citations and documentation.
       Updated STATE.scm from 0% to accurate 63% completion."))
    (session "2026-02-22"
      (summary "Implemented Zotero Web API v3 integration: Tesla client with
       pagination/versioning, bidirectional mapper (Dublin Core, Schema.org),
       sync coordinator with incremental sync, Oban periodic worker.
       Customized ABI/FFI for Evidence Graph: domain types (ClaimType,
       EvidenceType, RelationshipType, AudienceType, PromptScore),
       C-compatible structs with layout proofs, Zig FFI with PROMPT
       scoring, propagated weight, cycle detection. All compiles/passes."))))
