; SPDX-License-Identifier: PMPL-1.0-or-later
; Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>

(state
  (metadata
    (version "1.1.0")
    (last-updated "2026-03-13")
    (format "STATE.scm v1"))

  (project-context
    (name "bofig")
    (full-name "Evidence Graph for Investigative Journalism")
    (phase "phase-2-lithoglyph-migration")
    (status "in-progress"))

  (current-position
    (milestone "Phase 2 - Lithoglyph Migration")
    (completion-percentage 100)
    (phase-2-completion 20)
    (focus "Migrating domain data from ArangoDB to Lithoglyph. NER entity extraction wired into import pipeline. ADR-006 accepted: Lithoglyph replaces ArangoDB."))

  (components
    (component "elixir-backend"
      (status "complete") (completion 100))
    (component "graphql-api"
      (status "complete") (completion 100))
    (component "liveview-frontend"
      (status "complete") (completion 100)
      (notes "5 LiveView pages: Dashboard, Investigation, Graph, PROMPT, Navigation"))
    (component "d3-visualizations"
      (status "complete") (completion 100)
      (notes "Force graph + radar chart hooks implemented"))
    (component "arangodb-integration"
      (status "deprecated") (completion 100)
      (notes "ADR-006: superseded by Lithoglyph. Retained for relationships edge collection only during Phase 2."))
    (component "zotero-integration"
      (status "complete") (completion 100)
      (notes "API client, mapper, sync, REST endpoints (import/export/batch/sync-status)"))
    (component "user-auth"
      (status "complete") (completion 100)
      (notes "phx.gen.auth: registration, login, settings, magic links"))
    (component "production-deploy"
      (status "complete") (completion 100)
      (notes "Containerfile, nginx, systemd, runtime.exs, podman-compose, health endpoint"))
    (component "rsr-compliance"
      (status "complete") (completion 100)
      (notes ".machine_readable/, manifests, TOPOLOGY.md, .well-known/, Justfile, contractiles"))
    (component "nuj-testing"
      (status "complete") (completion 100)
      (notes "Task script, forms, consent form, decision matrix in docs/testing/"))
    (component "code-quality"
      (status "clean") (completion 100)
      (notes "Credo: 0 warnings, 0 errors. 257 tests passing."))
    (component "trustfile"
      (status "complete") (completion 100)
      (notes "A2ML v2.1 Cyberwar-Ready Trustfile with all sections"))
    (component "lithoglyph-integration"
      (status "in-progress") (completion 20)
      (notes "Phase 2: HTTP client, importer GenServer, NER extractor, entity resolution, mentions edges. Next: migrate reads/writes from ArangoDB to Lithoglyph GQL.")
      (files
        "lib/evidence_graph/lithoglyph/client.ex"
        "lib/evidence_graph/lithoglyph/importer.ex"
        "lib/evidence_graph/lithoglyph/ner_extractor.ex")
      (endpoints
        "POST /api/evidence/lithoglyph-import"
        "GET /api/evidence/lithoglyph-import/status")))

  (test-status
    (total-tests 257)
    (passing 257)
    (failing 0)
    (compile-warnings 0))

  (route-to-mvp
    (remaining-tasks
      (task "Migrate evidence reads to Lithoglyph GQL" (priority "high"))
      (task "Migrate evidence writes to Lithoglyph GQL-DT" (priority "high"))
      (task "Deploy to Hetzner Cloud" (priority "high"))
      (task "NUJ participant recruitment" (priority "high"))
      (task "Migrate entity/claim collections to Lithoglyph" (priority "medium"))
      (task "Month 3 decision point" (priority "high"))
      (task "Zotero browser extension" (priority "medium"))))

  (critical-next-actions
    (action "Migrate Evidence.create_evidence to write via Lithoglyph GQL-DT instead of ArangoDB")
    (action "Migrate evidence queries to read from Lithoglyph GQL instead of ArangoDB AQL")
    (action "Deploy v1.0.0 to Hetzner Cloud for NUJ testing")
    (action "Recruit 25 NUJ journalists for user testing")
    (action "Month 3 decision point: continue or pivot"))

  (session-history
    (session "2026-03-13b"
      (completed "Wired NER entity extraction into Lithoglyph importer pipeline")
      (completed "Added NERExtractor module (3 strategies: titles, orgs, capitalised sequences)")
      (completed "Extended Relationship schema with :entity type and :mentions edges")
      (completed "Updated graph traversal helpers for entity nodes")
      (completed "Added 13 NER extractor unit tests (all passing)")
      (completed "Merged PR #32: feature/entity-resolution-wiring")
      (completed "ADR-006: Lithoglyph replaces ArangoDB as primary data store")
      (completed "Updated ROADMAP.adoc with v3 Lithoglyph migration plan")
      (completed "Updated ARCHITECTURE.md with migration architecture diagrams")
      (completed "Updated META.scm, ECOSYSTEM.scm, STATE.scm")
      (completed "Fixed stale references in CLAUDE.md")
      (completed "Created .github/CODEOWNERS"))
    (session "2026-03-13"
      (completed "Phase 2 started: Lithoglyph integration")
      (completed "Added {:req, ~> 0.5} dependency for Lithoglyph HTTP client")
      (completed "Created lib/evidence_graph/lithoglyph/client.ex (Req-based API client)")
      (completed "Created lib/evidence_graph/lithoglyph/importer.ex (GenServer batch import)")
      (completed "Extended evidence schema with sha256_hash field")
      (completed "Added POST /api/evidence/lithoglyph-import endpoint")
      (completed "Added GET /api/evidence/lithoglyph-import/status endpoint")
      (completed "Added sha256_hash index to ArangoDB create_indexes")
      (completed "Updated CLAUDE.md: FormDB/FormBase references -> Lithoglyph/Docudactyl")
      (completed "Cross-repo integration plan docs created"))
    (session "2026-02-21"
      (completed "v1.0.0 release preparation")
      (completed "Deleted duplicate files")
      (completed "Rewrote Justfile with comprehensive Podman-based recipes")
      (completed "Created bofig.trustfile.a2ml, podman-compose.yml, .containerignore")
      (completed "Updated all contractiles and documentation")
      (completed "Phase 1 completion: 257 tests, 0 failures"))))
