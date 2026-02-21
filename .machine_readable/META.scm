; SPDX-License-Identifier: PMPL-1.0-or-later
; Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>

(meta
  (metadata
    (version "1.0.0")
    (last-updated "2026-02-21")
    (format "META.scm v1"))

  (architecture-decisions
    (adr "001"
      (title "ArangoDB for primary data store")
      (status "accepted")
      (decision "Use ArangoDB 3.11+ with Arangox Elixir driver via MintClient")
      (rationale "Production-proven, multi-model (document + graph), managed hosting available"))

    (adr "002"
      (title "Phoenix LiveView over React SPA")
      (status "accepted")
      (decision "Server-rendered LiveView with D3.js hooks for visualizations")
      (rationale "Progressive enhancement, less client complexity, boundary object navigation"))

    (adr "003"
      (title "PROMPT scoring as embedded schema")
      (status "accepted")
      (decision "Ecto embedded_schema for validation, stored as nested JSON in ArangoDB")
      (rationale "Validation at application layer, flexible storage, audience weight calculation"))

    (adr "004"
      (title "Absinthe GraphQL API")
      (status "accepted")
      (decision "Absinthe with schema-first approach")
      (rationale "Elixir-native, strong typing, fits PROMPT framework query patterns"))

    (adr "005"
      (title "Ecto without SQL for domain models")
      (status "accepted")
      (decision "Use Ecto schemas and changesets for validation only, not persistence")
      (rationale "Leverage Ecto's validation without coupling to SQL")))

  (design-rationale
    (principle "Infrastructure for pragmatic epistemology")
    (principle "Navigation over narration")
    (principle "Coordination without consensus")))
