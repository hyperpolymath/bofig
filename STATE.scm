;;; STATE.scm - Project Checkpoint
;;; bofig
;;; Format: Guile Scheme S-expressions
;;; Purpose: Preserve AI conversation context across sessions
;;; Reference: https://github.com/hyperpolymath/state.scm

;; SPDX-License-Identifier: AGPL-3.0-or-later
;; SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell

;;;============================================================================
;;; METADATA
;;;============================================================================

(define metadata
  '((version . "0.1.0")
    (schema-version . "1.0")
    (created . "2025-12-15")
    (updated . "2025-12-18")
    (project . "bofig")
    (repo . "github.com/hyperpolymath/bofig")))

;;;============================================================================
;;; PROJECT CONTEXT
;;;============================================================================

(define project-context
  '((name . "bofig")
    (tagline . "> Infrastructure for pragmatic epistemology. Combining i-docs navigation, PROMPT epistemological scoring, and boundary objects theory.")
    (version . "0.1.0")
    (license . "AGPL-3.0-or-later")
    (rsr-compliance . "gold-target")

    (tech-stack
     ((primary . "Elixir/Phoenix + ArangoDB")
      (ci-cd . "GitHub Actions + GitLab CI + Bitbucket Pipelines")
      (security . "CodeQL + OSSF Scorecard + SHA-pinned Actions")))))

;;;============================================================================
;;; CURRENT POSITION
;;;============================================================================

(define current-position
  '((phase . "v0.1 - Foundation & RSR Compliance")
    (overall-completion . 35)

    (components
     ((rsr-compliance
       ((status . "complete")
        (completion . 100)
        (notes . "SHA-pinned actions, SPDX headers, multi-platform CI, permissions declarations")))

      (security-hardening
       ((status . "complete")
        (completion . 100)
        (notes . "All 15 GitHub Actions workflows SHA-pinned, SPDX headers added, permissions declared")))

      (documentation
       ((status . "foundation")
        (completion . 40)
        (notes . "README, META/ECOSYSTEM/STATE.scm complete, ARCHITECTURE.md exists")))

      (testing
       ((status . "minimal")
        (completion . 10)
        (notes . "CI/CD scaffolding exists, limited test coverage")))

      (core-functionality
       ((status . "scaffolding")
        (completion . 20)
        (notes . "Phoenix project structure exists, mix.exs configured")))))

    (working-features
     ("RSR-compliant CI/CD pipeline with SHA-pinned actions"
      "Multi-platform mirroring (GitHub, GitLab, Bitbucket)"
      "SPDX license headers on all files"
      "OSSF Scorecard integration"
      "Security policy enforcement (weak crypto, HTTP, secrets detection)"
      "TypeScript/JavaScript blocker for ReScript enforcement"
      "Guix package management with guix.scm"))))

;;;============================================================================
;;; ROUTE TO MVP
;;;============================================================================

(define route-to-mvp
  '((target-version . "1.0.0")
    (definition . "Production platform with real investigation published")

    (milestones
     ((v0.2
       ((name . "Development Environment")
        (status . "in-progress")
        (items
         ("Complete Elixir/Phoenix project setup"
          "ArangoDB local instance running"
          "GraphQL API skeleton"
          "Core data models (Claims, Evidence, Relationships)"))))

      (v0.3
       ((name . "Zotero Integration")
        (status . "pending")
        (items
         ("Zotero extension update"
          "API endpoint for evidence import"
          "Metadata mapping"
          "Two-way sync"))))

      (v0.5
       ((name . "Basic UI + User Testing")
        (status . "pending")
        (items
         ("Phoenix LiveView setup"
          "Evidence list view"
          "Claim creation form"
          "D3.js graph visualization"
          "User testing with 5 NUJ journalists"))))

      (v0.7
       ((name . "PROMPT Scoring")
        (status . "pending")
        (items
         ("PROMPT scoring UI (6 dimensions)"
          "Audience-weighted scoring"
          "Score visualization"))))

      (v1.0
       ((name . "Production Release")
        (status . "pending")
        (items
         ("Multi-user authentication"
          "Real investigation published"
          "Performance optimization"
          "Security audit complete"))))))))

;;;============================================================================
;;; BLOCKERS & ISSUES
;;;============================================================================

(define blockers-and-issues
  '((critical
     ())  ;; No critical blockers

    (high-priority
     ())  ;; No high-priority blockers

    (medium-priority
     ((dev-environment
       ((description . "Development environment not fully set up")
        (impact . "Cannot run application locally")
        (needed . "Complete Phoenix/ArangoDB setup")))))

    (low-priority
     ((test-coverage
       ((description . "Limited test infrastructure")
        (impact . "Risk of regressions")
        (needed . "Comprehensive test suites")))

      (documentation-gaps
       ((description . "Some documentation areas incomplete")
        (impact . "Harder for new contributors")
        (needed . "Expand user documentation")))))))

;;;============================================================================
;;; CRITICAL NEXT ACTIONS
;;;============================================================================

(define critical-next-actions
  '((immediate
     (("Complete Phoenix project initialization" . high)
      ("Set up ArangoDB Podman container" . high)
      ("Create core data models" . medium)))

    (this-week
     (("Implement GraphQL API skeleton" . high)
      ("Load UK Inflation 2023 test data" . medium)))

    (this-month
     (("Reach v0.2 milestone" . high)
      ("Begin Zotero integration" . medium)
      ("First user feedback session" . low)))))

;;;============================================================================
;;; SESSION HISTORY
;;;============================================================================

(define session-history
  '((snapshots
     ((date . "2025-12-15")
      (session . "initial-state-creation")
      (accomplishments
       ("Added META.scm, ECOSYSTEM.scm, STATE.scm"
        "Established RSR compliance"
        "Created initial project checkpoint"))
      (notes . "First STATE.scm checkpoint created via automated script"))

     ((date . "2025-12-18")
      (session . "security-hardening")
      (accomplishments
       ("SHA-pinned all 15 GitHub Actions workflows"
        "Added SPDX headers to all workflow files"
        "Added permissions declarations"
        "Fixed ECOSYSTEM.scm syntax to valid Scheme"
        "Updated Elixir version to 1.16"
        "Updated all action versions to latest secure releases"))
      (notes . "Major security hardening session - all actions now SHA-pinned per RSR requirements")))))

;;;============================================================================
;;; HELPER FUNCTIONS (for Guile evaluation)
;;;============================================================================

(define (get-completion-percentage component)
  "Get completion percentage for a component"
  (let ((comp (assoc component (cdr (assoc 'components current-position)))))
    (if comp
        (cdr (assoc 'completion (cdr comp)))
        #f)))

(define (get-blockers priority)
  "Get blockers by priority level"
  (cdr (assoc priority blockers-and-issues)))

(define (get-milestone version)
  "Get milestone details by version"
  (assoc version (cdr (assoc 'milestones route-to-mvp))))

;;;============================================================================
;;; EXPORT SUMMARY
;;;============================================================================

(define state-summary
  '((project . "bofig")
    (version . "0.1.0")
    (overall-completion . 35)
    (next-milestone . "v0.2 - Development Environment")
    (critical-blockers . 0)
    (high-priority-issues . 0)
    (updated . "2025-12-18")))

;;; End of STATE.scm
