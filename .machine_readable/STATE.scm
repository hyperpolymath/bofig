; SPDX-License-Identifier: PMPL-1.0-or-later
; Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>

(state
  (metadata
    (version "1.0.0")
    (last-updated "2026-02-21")
    (format "STATE.scm v1"))

  (project-context
    (name "bofig")
    (full-name "Evidence Graph for Investigative Journalism")
    (phase "phase-1-poc")
    (status "released"))

  (current-position
    (milestone "Phase 1 - Proof of Concept")
    (completion-percentage 100)
    (focus "v1.0.0 released. NUJ testing and Hetzner deployment next."))

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
      (status "complete") (completion 100)
      (notes "7 claims, 30 evidence, 38 relationships, 6 nav paths seeded"))
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
      (notes "A2ML v2.1 Cyberwar-Ready Trustfile with all sections")))

  (test-status
    (total-tests 257)
    (passing 257)
    (failing 0)
    (compile-warnings 0))

  (route-to-mvp
    (remaining-tasks
      (task "Deploy to Hetzner Cloud" (priority "high"))
      (task "NUJ participant recruitment" (priority "high"))
      (task "Month 3 decision point" (priority "high"))
      (task "Zotero browser extension" (priority "medium"))))

  (critical-next-actions
    (action "Deploy v1.0.0 to Hetzner Cloud for NUJ testing")
    (action "Recruit 25 NUJ journalists for user testing")
    (action "Month 3 decision point: continue or pivot"))

  (session-history
    (session "2026-02-21"
      (completed "v1.0.0 release preparation")
      (completed "Deleted duplicate files: CHANGELOG.adoc, CONTRIBUTING.md, MAINTAINERS.adoc, LICENSE.txt, rescript.json, Podmanfile.md, docker-compose.yml")
      (completed "Rewrote Justfile with comprehensive Podman-based recipes")
      (completed "Expanded Mustfile to 6 mandatory checks")
      (completed "Created bofig.trustfile.a2ml (full A2ML v2.1)")
      (completed "Created podman-compose.yml with health checks")
      (completed "Created .containerignore for build efficiency")
      (completed "Added /api/health endpoint (HealthController)")
      (completed "Updated Containerfile to Elixir 1.18/OTP 27")
      (completed "Updated all contractiles (Mustfile, Dustfile, Intentfile, Trustfile)")
      (completed "Updated ROADMAP.adoc with actual 18-month plan")
      (completed "Updated SECURITY.md (auth implemented, resolved gaps)")
      (completed "Updated README.adoc for v1.0.0")
      (completed "Updated CHANGELOG.md with v1.0.0 entry")
      (completed "Updated STATE.scm to 100% Phase 1")
      (completed "Bumped mix.exs version to 1.0.0")
      (completed "Created .github/workflows/trustfile.yml"))))
