; SPDX-License-Identifier: PMPL-1.0-or-later
; Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>

(ecosystem
  (metadata
    (version "1.1.0")
    (last-updated "2026-03-13")
    (format "ECOSYSTEM.scm v1"))

  (project
    (name "bofig")
    (full-name "Evidence Graph for Investigative Journalism")
    (type "application")
    (purpose "Infrastructure for pragmatic epistemology in investigative journalism")
    (license "PMPL-1.0-or-later"))

  (position-in-ecosystem
    (domain "investigative-journalism-tools")
    (novelty "First system combining PROMPT scoring, boundary objects, and i-docs navigation")
    (academic-context "PhD thesis: practical infrastructure for pragmatic epistemology")
    (pipeline-position "Docudactyl (extraction) -> Lithoglyph (storage+provenance) -> bofig (navigation+visualisation)"))

  (related-projects
    (project "lithoglyph"
      (relationship "primary-dependency")
      (role "Evidence store, provenance layer, GQL/GQL-DT query engine")
      (notes "Phase 2: migrating all domain data from ArangoDB to Lithoglyph"))
    (project "docudactyl"
      (relationship "upstream-dependency")
      (role "Multi-format HPC document extraction, feeds evidence into Lithoglyph"))
    (project "verisimdb"
      (relationship "sibling-standard")
      (role "Octad database with VQL, shares GQL patterns with Lithoglyph"))
    (project "zotero"
      (relationship "integration-target")
      (url "https://www.zotero.org/")
      (role "Reference management, two-way sync for evidence import/export"))
    (project "hypothesis"
      (relationship "inspiration")
      (url "https://hypothes.is/")
      (role "Web annotation model")))

  (technology-stack
    (runtime "BEAM/OTP 27")
    (language "Elixir 1.18+")
    (framework "Phoenix 1.8+ with LiveView")
    (evidence-store "Lithoglyph (GQL/GQL-DT, Phase 2+)")
    (graph-db "ArangoDB 3.11+ (relationships only, Phase 2; removed Phase 3)")
    (auth-db "PostgreSQL 16")
    (api "Absinthe GraphQL + REST")
    (visualization "D3.js v7")))
