;; SPDX-License-Identifier: AGPL-3.0-or-later
;; SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
;; ECOSYSTEM.scm — bofig

(ecosystem
  (version "1.0.0")
  (name "bofig")
  (type "project")
  (purpose "> Infrastructure for pragmatic epistemology. Combining i-docs navigation, PROMPT epistemological scoring, and boundary objects theory.")

  (position-in-ecosystem
    "Part of hyperpolymath ecosystem. Follows RSR guidelines.")

  (related-projects
    (project (name "rhodium-standard-repositories")
             (url "https://github.com/hyperpolymath/rhodium-standard-repositories")
             (relationship "standard")))

  (what-this-is "> Infrastructure for pragmatic epistemology. Combining i-docs navigation, PROMPT epistemological scoring, and boundary objects theory.")
  (what-this-is-not "- NOT exempt from RSR compliance"))
