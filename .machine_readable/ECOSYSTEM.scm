; SPDX-License-Identifier: PMPL-1.0-or-later
; Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>

(ecosystem
  (metadata
    (version "1.0.0")
    (last-updated "2026-02-21")
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
    (academic-context "PhD thesis: practical infrastructure for pragmatic epistemology"))

  (related-projects
    (project "formdb-debugger" (relationship "sibling-standard"))
    (project "formbase" (relationship "sibling-standard"))
    (project "hypothesis" (relationship "inspiration") (url "https://hypothes.is/"))
    (project "zotero" (relationship "integration-target") (url "https://www.zotero.org/")))

  (technology-stack
    (runtime "BEAM/OTP 26+")
    (language "Elixir 1.16+")
    (framework "Phoenix 1.7+ with LiveView")
    (database "ArangoDB 3.11+")
    (api "Absinthe GraphQL")
    (visualization "D3.js v7")))
