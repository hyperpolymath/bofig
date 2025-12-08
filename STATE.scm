;;; STATE.scm - Evidence Graph Project Checkpoint
;;; Guile Scheme format for AI conversation continuity
;;; See: https://github.com/hyperpolymath/state.scm

(define state
  '(;; ================================================================
    ;; METADATA
    ;; ================================================================
    (metadata
     (format-version . "2.0")
     (schema-version . "2025-12-08")
     (created-at . "2025-12-08T00:00:00Z")
     (last-updated . "2025-12-08T00:00:00Z")
     (generator . "Claude/STATE-system"))

    ;; ================================================================
    ;; USER CONTEXT
    ;; ================================================================
    (user
     (name . "Hyperpolymath")
     (roles . ("PhD-researcher" "investigative-journalist" "developer"))
     (preferences
      (languages . ("Elixir" "JavaScript" "Julia"))
      (tools . ("Phoenix" "ArangoDB" "Zotero" "Podman" "GitHub"))
      (values . ("FOSS" "EU-data-sovereignty" "pragmatic-epistemology"
                 "coordination-without-consensus" "open-source"))))

    ;; ================================================================
    ;; SESSION CONTEXT
    ;; ================================================================
    (session
     (conversation-id . "bofig-state-init")
     (started-at . "2025-12-08")
     (messages-used . 0)
     (messages-remaining . "unlimited")
     (token-limit-reached . #f))

    ;; ================================================================
    ;; CURRENT FOCUS
    ;; ================================================================
    (focus
     (current-project . "bofig")
     (current-phase . "Phase 1: PoC - Month 1 Foundation")
     (deadline . "Month 3 Decision Point")
     (blocking-projects . ()))

    ;; ================================================================
    ;; PROJECT CATALOG
    ;; ================================================================
    (projects
     ((name . "bofig")
      (full-name . "Evidence Graph for Investigative Journalism")
      (status . "in-progress")
      (completion . 25)
      (category . "infrastructure")
      (phase . "foundation")
      (repository . "https://github.com/Hyperpolymath/bofig")

      ;; What's been done
      (completed
       ("Architecture documentation (ARCHITECTURE.md)"
        "Technology stack selection (Elixir/Phoenix/ArangoDB)"
        "ROADMAP.md 18-month implementation plan"
        "Database evaluation (docs/database-evaluation.md)"
        "Zotero integration design (docs/zotero-integration.md)"
        "Elixir project initialized (mix.exs with all dependencies)"
        "Core data models implemented:"
        "  - Claims context (lib/evidence_graph/claims.ex)"
        "  - Evidence context (lib/evidence_graph/evidence.ex)"
        "  - Relationships context (lib/evidence_graph/relationships.ex)"
        "  - Navigation context (lib/evidence_graph/navigation.ex)"
        "  - PROMPT scoring (lib/evidence_graph/prompt_scores.ex)"
        "ArangoDB client module (lib/evidence_graph/arango.ex)"
        "GraphQL schema with Absinthe (lib/evidence_graph_web/schema.ex)"
        "GraphQL types for all entities"
        "GitHub workflows (CodeQL, Elixir CI, Jekyll pages)"))

      ;; Dependencies
      (dependencies
       ("ArangoDB 3.11+ instance running"
        "Elixir 1.16+ and Erlang/OTP 26+ installed"
        "Node.js 20+ for frontend assets"))

      ;; Current blockers preventing progress
      (blockers
       ("Development environment not verified working"
        "ArangoDB container not confirmed running"
        "No ExUnit tests written yet"
        "Phoenix endpoint/router not fully wired"
        "No LiveView components implemented"))

      ;; Immediate next actions
      (next
       ("Verify mix compile succeeds"
        "Start ArangoDB Podman container"
        "Run mix run priv/repo/setup_arango.exs to create collections"
        "Write first ExUnit test for Claims context"
        "Load UK Inflation 2023 seed data"
        "Verify GraphQL endpoint responds at /api/graphql"))

      ;; Context notes for next session
      (notes
       ("Month 1 goal: Working GraphQL API + sample data loaded"
        "Month 3 = CRITICAL DECISION POINT: User testing feedback"
        "NUJ network for testing (25 participants at Month 6)"
        "PROMPT scoring should be OPTIONAL to reduce adoption friction"
        "Progressive enhancement: works without JavaScript first"))))

    ;; ================================================================
    ;; ROUTE TO MVP v1
    ;; ================================================================
    (mvp-route
     (target . "Proof of Concept with user testing")
     (timeline . "Months 1-6")
     (milestones
      ((month . 1)
       (name . "Foundation")
       (status . "in-progress")
       (goals
        ("Development environment working"
         "GraphQL API responding"
         "ArangoDB schema created"
         "UK Inflation 2023 sample data loaded"))
       (deliverables
        ("mix phx.server runs without errors"
         "GraphQL queries work in GraphiQL"
         "7 claims + 30 evidence items seeded")))

      ((month . 2)
       (name . "Zotero Integration")
       (status . "pending")
       (goals
        ("lib/exporter.js extended to POST to API"
         "API endpoint /api/v1/evidence/import"
         "Roundtrip sync working"))
       (deliverables
        ("30 real Zotero items imported"
         "Metadata preserved in JSON-LD")))

      ((month . 3)
       (name . "Basic UI + DECISION POINT")
       (status . "pending")
       (goals
        ("Phoenix LiveView setup"
         "Evidence list view"
         "Claim creation form"
         "D3.js graph visualization"
         "USER TESTING: 5 NUJ journalists"))
       (deliverables
        ("Working web UI"
         "User testing report"
         "GO/NO-GO decision documented"))
       (decision-point . #t))

      ((month . 4)
       (name . "PROMPT Scoring System")
       (status . "pending")
       (goals
        ("6-slider PROMPT UI"
         "Radar chart visualization"
         "Audience-weighted scoring"))
       (deliverables
        ("PROMPT scoring UI complete"
         "Scoring algorithms tested")))

      ((month . 5)
       (name . "Navigation Paths")
       (status . "pending")
       (goals
        ("Path creation drag-and-drop UI"
         "6 audience types implemented"
         "Path playback mode"))
       (deliverables
        ("3 navigation paths on UK Inflation")))

      ((month . 6)
       (name . "Polish + Full User Testing")
       (status . "pending")
       (goals
        ("Progressive enhancement audit"
         "Performance optimization"
         "25 NUJ participants test full system"))
       (deliverables
        ("Production-ready PoC"
         "User testing report"
         "Phase 1 retrospective")))))

    ;; ================================================================
    ;; KNOWN ISSUES
    ;; ================================================================
    (issues
     ((id . "ISSUE-001")
      (severity . "high")
      (title . "Dev environment unverified")
      (description . "mix compile, ArangoDB connection, and basic endpoints not tested")
      (resolution . "Run full setup sequence and verify each step"))

     ((id . "ISSUE-002")
      (severity . "medium")
      (title . "No test coverage")
      (description . "ExUnit tests not written for any module")
      (resolution . "Write tests for Claims, Evidence, Relationships contexts"))

     ((id . "ISSUE-003")
      (severity . "medium")
      (title . "LiveView UI not started")
      (description . "No Phoenix LiveView components exist yet")
      (resolution . "Month 3 deliverable - create basic list/form views"))

     ((id . "ISSUE-004")
      (severity . "low")
      (title . "Zotero extension outdated")
      (description . "lib/exporter.js is from 2017, needs update")
      (resolution . "Month 2 task - extend for Evidence Graph API"))

     ((id . "ISSUE-005")
      (severity . "low")
      (title . "UK Inflation test data not loaded")
      (description . "priv/repo/seeds.exs exists but not run")
      (resolution . "Requires working ArangoDB first")))

    ;; ================================================================
    ;; QUESTIONS FOR USER
    ;; ================================================================
    (questions
     ((id . "Q-001")
      (topic . "user-testing")
      (question . "Do you have NUJ contacts lined up for Month 3 testing (5 journalists)?")
      (context . "Month 3 is a critical decision point"))

     ((id . "Q-002")
      (topic . "infrastructure")
      (question . "Is ArangoDB Cloud account set up (for production at ~45 EUR/month)?")
      (context . "Month 11 deployment requires managed hosting"))

     ((id . "Q-003")
      (topic . "test-data")
      (question . "Is the UK Inflation 2023 investigation data ready (7 claims, 30 evidence items)?")
      (context . "Needed for seed data and user testing"))

     ((id . "Q-004")
      (topic . "prompt-framework")
      (question . "Is PROMPT framework PhD documentation ready to share for algorithm validation?")
      (context . "Scoring weights need theoretical grounding"))

     ((id . "Q-005")
      (topic . "development")
      (question . "Local dev environment set up? (Elixir 1.16+, Podman, Node.js 20+)")
      (context . "Prerequisite for Month 1 work")))

    ;; ================================================================
    ;; LONG-TERM ROADMAP (18 months)
    ;; ================================================================
    (long-term-roadmap
     ((phase . 1)
      (name . "Proof of Concept")
      (months . "1-6")
      (hours . 480)
      (goal . "One complete investigation with user testing")
      (key-milestone . "25 NUJ participants test system"))

     ((phase . 2)
      (name . "Platform")
      (months . "7-12")
      (hours . 430)
      (goal . "Multi-investigation platform ready for newsrooms")
      (key-features
       ("Multi-user authentication"
        "Advanced graph features"
        "IPFS provenance"
        "Import/Export ecosystem"
        "Production deployment on Hetzner"))
      (key-milestone . "Real investigation published using platform"))

     ((phase . 3)
      (name . "Ecosystem")
      (months . "13-18")
      (hours . 400)
      (goal . "Integration with academic/journalism infrastructure")
      (key-features
       ("Optional Virtuoso/SPARQL (if needed)"
        "Julia statistical analysis"
        "Mobile & accessibility (WCAG 2.1 AA)"
        "Plugin ecosystem"
        "Sustainability plan"))
      (key-milestone . "Plugin ecosystem live, sustainable open-source"))

     (total-effort
      (months . 18)
      (hours . 1310)
      (fte-equivalent . "7.8 months")))

    ;; ================================================================
    ;; DECISION POINTS
    ;; ================================================================
    (decision-points
     ((month . 3)
      (question . "Do journalists find this useful?")
      (data . "User testing qualitative feedback")
      (options
       ("GO: Proceed to Months 4-6"
        "PIVOT: Simplify to Zotero export only"
        "STOP: Document learnings, archive project")))

     ((month . 9)
      (question . "Is ArangoDB still the right choice?")
      (data . "Performance benchmarks, query complexity, cost")
      (options
       ("KEEP: Optimize queries, upgrade tier if needed"
        "MIGRATE: Switch to PostgreSQL + AgensGraph")))

     ((month . 12)
      (question . "Do we need Virtuoso/RDF?")
      (data . "User requests for academic integration")
      (options
       ("ADD: Phase 3 semantic web integration"
        "SKIP: JSON-LD export sufficient"))))

    ;; ================================================================
    ;; CRITICAL NEXT ACTIONS
    ;; ================================================================
    (critical-next
     ("1. Verify development environment (mix compile, ArangoDB container)"
      "2. Run setup scripts (priv/repo/setup_arango.exs)"
      "3. Load UK Inflation seed data"
      "4. Write first ExUnit test for Claims.create_claim/1"
      "5. Verify GraphQL endpoint at localhost:4000/api/graphql"))

    ;; ================================================================
    ;; SESSION FILES
    ;; ================================================================
    (session-files
     (created . ("STATE.scm"))
     (modified . ()))

    ;; ================================================================
    ;; CONTEXT NOTES
    ;; ================================================================
    (context-notes
     ("The philosophical core: 'coordination without consensus' via boundary objects"
      "PROMPT = Provenance, Replicability, Objective, Methodology, Publication, Transparency"
      "Different audiences navigate same evidence differently (researcher vs activist vs skeptic)"
      "Month 3 decision point is CRITICAL - determines if project continues"
      "NUJ (National Union of Journalists) network is the test user base"
      "EU data sovereignty important - Hetzner hosting, GDPR compliance"
      "Keep PROMPT scoring OPTIONAL to reduce adoption friction"))))

;;; ================================================================
;;; Query helpers (for use with Guile REPL)
;;; ================================================================

;; Get current focus
;; (assoc-ref (assoc-ref state 'focus) 'current-project)

;; Get all blockers
;; (assoc-ref (car (assoc-ref state 'projects)) 'blockers)

;; Get critical next actions
;; (assoc-ref state 'critical-next)

;;; ================================================================
;;; END STATE.scm
;;; ================================================================
