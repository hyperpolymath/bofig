; SPDX-License-Identifier: PMPL-1.0-or-later
; Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>

(meta
  (metadata
    (version "1.1.0")
    (last-updated "2026-03-13")
    (format "META.scm v1"))

  (architecture-decisions
    (adr "001"
      (title "ArangoDB for primary data store")
      (status "superseded")
      (superseded-by "006")
      (decision "Use ArangoDB 3.11+ with Arangox Elixir driver via MintClient")
      (rationale "Production-proven, multi-model (document + graph), managed hosting available. Superseded: Lithoglyph now provides these capabilities with additional provenance and type safety."))

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
      (rationale "Leverage Ecto's validation without coupling to SQL"))

    (adr "006"
      (title "Lithoglyph replaces ArangoDB as primary data store")
      (status "accepted")
      (date "2026-03-13")
      (supersedes "001")
      (decision "Migrate domain data (evidence, claims, entities) from ArangoDB to Lithoglyph. ArangoDB retained for graph edges only during Phase 2, fully removed in Phase 3.")
      (rationale "Eliminates data duplication (Docudactyl→Lithoglyph→ArangoDB was a copy pipeline). Lithoglyph provides mandatory provenance, WAL audit trail, GQL-DT dependent types for PROMPT scores, and compile-time verification. ArangoDB was correct for Phase 1 prototyping but duplicates what Lithoglyph already stores.")))

  (design-rationale
    (principle "Infrastructure for pragmatic epistemology")
    (principle "Navigation over narration")
    (principle "Coordination without consensus")
    (principle "Query the source, don't copy the data")))
