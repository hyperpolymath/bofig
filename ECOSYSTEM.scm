;; SPDX-License-Identifier: AGPL-3.0-or-later
;; SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell

;;; ECOSYSTEM.scm - Project Ecosystem Relationships
;;; bofig
;;; Reference: https://github.com/hyperpolymath/ECOSYSTEM.scm

(define-module (bofig ecosystem)
  #:export (ecosystem-info
            related-projects
            what-this-is
            what-this-is-not))

;;;============================================================================
;;; ECOSYSTEM METADATA
;;;============================================================================

(define ecosystem-info
  '((version . "1.0.0")
    (name . "bofig")
    (type . "project")
    (purpose . "> Infrastructure for pragmatic epistemology. Combining i-docs navigation, PROMPT epistemological scoring, and boundary objects theory.")
    (position-in-ecosystem . "Part of the hyperpolymath ecosystem of tools, libraries, and specifications. Follows RSR (Rhodium Standard Repositories) guidelines for consistency, security, and maintainability. Integrated with multi-platform CI/CD (GitHub, GitLab, Bitbucket) and OpenSSF Scorecard compliance.")))

;;;============================================================================
;;; RELATED PROJECTS
;;;============================================================================

(define related-projects
  '((hyperpolymath-ecosystem
     ((name . "hyperpolymath-ecosystem")
      (url . "https://github.com/hyperpolymath")
      (relationship . "ecosystem")
      (description . "Part of the hyperpolymath project ecosystem")
      (differentiation . "Individual project within a larger cohesive ecosystem")))

    (rhodium-standard-repositories
     ((name . "rhodium-standard-repositories")
      (url . "https://github.com/hyperpolymath/rhodium-standard-repositories")
      (relationship . "standard")
      (description . "RSR compliance guidelines this project follows")
      (differentiation . "RSR = Standards and templates. This project = Implementation following those standards")))

    (meta-scm
     ((name . "META.scm")
      (url . "https://github.com/hyperpolymath/META.scm")
      (relationship . "sibling-standard")
      (description . "Machine-readable Engineering and Technical Architecture format")
      (differentiation . "META.scm = Architecture decisions format. ECOSYSTEM.scm = Project relationship format")))

    (state-scm
     ((name . "state.scm")
      (url . "https://github.com/hyperpolymath/state.scm")
      (relationship . "sibling-standard")
      (description . "Stateful Context Tracking Engine for AI Conversation Continuity")
      (differentiation . "STATE.scm = Session/conversation persistence format. ECOSYSTEM.scm = Project relationship format")))))

;;;============================================================================
;;; PROJECT IDENTITY
;;;============================================================================

(define what-this-is
  '((summary . "> Infrastructure for pragmatic epistemology. Combining i-docs navigation, PROMPT epistemological scoring, and boundary objects theory.")
    (design-principles
     ("RSR Gold compliance target"
      "Multi-platform CI/CD (GitHub, GitLab, Bitbucket)"
      "SHA-pinned GitHub Actions for security"
      "SPDX license headers on all files"
      "OpenSSF Scorecard compliance"))))

(define what-this-is-not
  '((exclusions
     ("NOT a standalone tool without ecosystem integration"
      "NOT exempt from RSR compliance requirements"
      "NOT designed for incompatible license frameworks"
      "NOT maintained outside the hyperpolymath ecosystem"))))

;;; End of ECOSYSTEM.scm
