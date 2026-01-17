# Changelog

All notable changes to the Evidence Graph project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Planned (Phase 1 Month 2-6)
- Zotero browser extension (two-way sync)
- Phoenix LiveView UI pages
- PROMPT scoring interface
- User authentication (Phase 2)
- Comprehensive test suite
- IPFS provenance integration (Phase 2)

## [0.1.0] - 2025-11-22 - "Foundation" (Phase 1 Month 1)

### Added

#### Core Infrastructure
- **Elixir/Phoenix application** initialized with Phoenix 1.7.10
- **ArangoDB integration** via `arangox` for multi-model database (document + graph)
- **GraphQL API** with Absinthe 1.7 (15 queries, 11 mutations)
- **Docker Compose** setup for local development (ArangoDB + PostgreSQL)
- **Podman** alternative configuration documented

#### Data Models
- **Claims** schema with Ecto validation and ArangoDB integration
- **Evidence** schema with Zotero metadata (Dublin Core, Schema.org)
- **Relationships** (graph edges) with weighted support/contradiction
- **Navigation Paths** for audience-based exploration (6 audience types)
- **PROMPT Scores** framework (6-dimensional epistemological scoring)

#### GraphQL API
- Queries: `claim`, `claims`, `searchClaims`, `evidence`, `evidenceByZoteroKey`, `evidenceList`, `searchEvidence`, `evidenceChain`, `navigationPath`, `navigationPaths`
- Mutations: `createClaim`, `updateClaim`, `deleteClaim`, `createEvidence`, `updateEvidence`, `importFromZotero`, `createRelationship`, `updateRelationship`, `deleteRelationship`, `createNavigationPath`, `autoGeneratePath`
- Custom types: `PromptScores`, `Claim`, `Evidence`, `Relationship`, `NavigationPath`
- Union types: `graph_node` (Claim | Evidence)

#### Algorithms
- **Evidence chain traversal** (multi-hop graph traversal, depth-limited)
- **Shortest path** algorithm (ArangoDB native SHORTEST_PATH)
- **Propagated weight calculation** (multiplicative decay along paths)
- **Contradiction detection** (claims with conflicting evidence)
- **Audience-weighted PROMPT scoring** (different priorities per user type)
- **Auto-generate navigation paths** (ML-free heuristic based on PROMPT scores)

#### Test Data
- **UK Inflation 2023 investigation** seed dataset:
  - 7 claims (primary, supporting, counter) with confidence levels
  - 10 evidence items (official statistics, academic, think tanks, interviews)
  - 10 relationships (supports, contradicts, contextualizes)
  - 3 navigation paths (researcher, policymaker, affected person)

#### Documentation
- **README.md** with quick start guide and GraphQL examples
- **ARCHITECTURE.md** (~4,000 words): data model, database design, API specs, algorithms
- **ROADMAP.md** (~3,500 words): 18-month plan, 3 phases, decision points, success metrics
- **CLAUDE.md** (~2,500 words): AI assistant context, philosophical core, dev patterns
- **docs/database-evaluation.md**: ArangoDB vs SurrealDB vs Virtuoso comparison
- **docs/zotero-integration.md**: Two-way sync design, extension code templates

#### Visualization
- **D3.js graph visualization** (force-directed layout):
  - Color-coded by PROMPT scores (red→yellow→green gradient)
  - Interactive: drag nodes, zoom, pan, tooltips
  - Relationship types: supports (green), contradicts (red), contextualizes (gray)
  - PROMPT score badges on nodes

#### RSR Compliance (Rhodium Standard Repository)
- **LICENSE.txt**: Dual license (MIT + Palimpsest v0.8) for emotional safety
- **SECURITY.md**: Comprehensive security policy, vulnerability disclosure, GDPR compliance
- **CONTRIBUTING.md**: TPCF Perimeter 3 model, 90-day reversibility, contribution guidelines
- **CODE_OF_CONDUCT.md**: CCCP (Community-Centric Code of Practice), emotional safety
- **MAINTAINERS.md**: Governance model, emotional temperature metrics, decision framework
- **CHANGELOG.md**: This file (SemVer + Keep a Changelog format)

#### Configuration
- **mix.exs** with all dependencies (Phoenix, Absinthe, Arangox, Oban)
- **config/*.exs** for dev/test/prod/runtime environments
- **.env.example** with documented environment variables
- **.gitignore** comprehensive Elixir/Phoenix rules

### Changed
- N/A (initial release)

### Deprecated
- N/A

### Removed
- N/A

### Fixed
- N/A

### Security
- **Parameterized AQL queries** to prevent injection attacks
- **Ecto changesets** for input validation
- **GraphQL schema validation** at API boundary
- **No unsafe Elixir patterns** (no `String.to_existing_atom/1` on user input)
- **GDPR compliance** design: anonymizable interview subjects, soft deletes

## Project Metadata

**Repository**: https://github.com/Hyperpolymath/bofig
**Branch**: `claude/create-claude-md-01CXemscniZhkZyW9ZqZLAfS`
**Contributors**: @Hyperpolymath, Claude (AI assistant)
**License**: MIT + Palimpsest v0.8
**Status**: Phase 1 PoC (Month 1/18 complete)

## Version Numbering

We use **Semantic Versioning** (SemVer):

- **MAJOR**: Breaking API changes, architectural rewrites
- **MINOR**: New features, backwards-compatible
- **PATCH**: Bug fixes, documentation, security patches

**Phase Mapping:**
- 0.1.x = Phase 1 (PoC, Months 1-6)
- 0.2.x = Phase 2 (Platform, Months 7-12)
- 1.0.0 = Phase 3 launch (Ecosystem, Month 18)

## Contribution Credits

### 0.1.0 Contributors

- **@Hyperpolymath**: Project concept, architecture, PhD research integration
- **Claude (Anthropic)**: Code implementation, documentation, RSR compliance

*All contributors are listed in .well-known/humans.txt*

## Upgrade Guide

### From: Nothing → 0.1.0

**Initial Installation:**

1. Clone repository
2. Install dependencies: `mix deps.get`
3. Start databases: `docker-compose up -d`
4. Setup ArangoDB: `iex -S mix` → `EvidenceGraph.ArangoDB.setup_database()`
5. Load seed data: `mix run priv/repo/seeds.exs`
6. Start server: `mix phx.server`

See README.md for detailed instructions.

### Breaking Changes

- N/A (initial release)

## Deprecation Warnings

- None currently

## Roadmap Preview

**Next Release (0.2.0) - Phase 1 Month 2-3:**
- Zotero browser extension working prototype
- Phoenix LiveView pages (investigation list, claim editor)
- Test suite (ExUnit + GraphQL integration tests)
- User testing preparation (25 NUJ participants)

**Future (0.3.0+) - Phase 1 Month 4-6:**
- PROMPT scoring UI (6 sliders with radar chart)
- Navigation path playback interface
- Month 3 decision point: Continue or pivot

**Future (1.0.0) - Phase 3:**
- User authentication & authorization
- Real-time collaboration
- IPFS provenance
- Production deployment

See ROADMAP.md for full 18-month plan.

## Contact & Support

- **Issues**: https://github.com/Hyperpolymath/bofig/issues
- **Discussions**: https://github.com/Hyperpolymath/bofig/discussions
- **Security**: security@evidencegraph.org (see SECURITY.md)
- **Governance**: See MAINTAINERS.md

---

**Changelog Maintenance**: This file is updated with every release. For unreleased changes, see Git commit history.

*Format: [Keep a Changelog](https://keepachangelog.com/)*
*Versioning: [Semantic Versioning](https://semver.org/)*
*Last Updated: 2025-11-22*
