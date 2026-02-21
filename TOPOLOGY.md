# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>

# TOPOLOGY.md - Evidence Graph (bofig)

## System Architecture

```
                          +-------------------+
                          |    Web Browser     |
                          |  (D3.js + LiveView)|
                          +--------+----------+
                                   |
                          HTTPS / WebSocket
                                   |
                          +--------v----------+
                          |    Nginx Proxy     |
                          |  (TLS termination) |
                          +--------+----------+
                                   |
                 +-----------------+------------------+
                 |                                    |
        +--------v----------+             +-----------v---------+
        |   Phoenix 1.8     |             |   REST API          |
        |   LiveView 1.1    |             |   /api/evidence/*   |
        |                   |             |   /api/graphql       |
        |  - InvestigationLive            |                     |
        |  - GraphLive (D3) |             |  Absinthe GraphQL   |
        |  - PromptLive     |             |  EvidenceApiCtrl    |
        |  - NavigationLive |             +----------+----------+
        +--------+----------+                        |
                 |                                   |
                 +---------------+-------------------+
                                 |
              +------------------v-------------------+
              |          EvidenceGraph Core           |
              |                                      |
              |  Claims    Evidence    Relationships  |
              |  Navigation    PromptScores           |
              |  Accounts (User Auth)                 |
              +--------+-----------+-----------------+
                       |           |
             +---------v---+   +---v-----------+
             |  ArangoDB   |   |   PostgreSQL   |
             |  3.11       |   |                |
             |             |   |  Users/tokens  |
             |  Claims     |   |  Oban jobs     |
             |  Evidence   |   +----------------+
             |  Relations  |
             |  Navigation |
             |  Zotero sync|
             +------+------+
                    |
           +--------v---------+
           |  Zotero API      |
           |  (Tesla HTTP)    |
           |  Oban background |
           +------------------+
```

## Component Overview

| Component | Technology | Purpose |
|-----------|-----------|---------|
| Web UI | Phoenix LiveView + D3.js | Real-time investigation dashboard, graph viz, PROMPT radar |
| GraphQL API | Absinthe 1.7 | Typed query/mutation interface for claims, evidence, navigation |
| REST API | Phoenix Controllers | Zotero import/export, sync status |
| Auth | phx.gen.auth + bcrypt | Session-based user authentication |
| Graph DB | ArangoDB 3.11 (Arangox) | Claims, evidence, relationships, navigation paths |
| Relational DB | PostgreSQL (Ecto) | User accounts, tokens, Oban jobs |
| Background jobs | Oban 2.17 | Zotero incremental sync polling |
| Email | Swoosh | Magic link auth, password reset |
| HTTP client | Tesla + Mint | Zotero API communication |

## Completion Dashboard

```
Phoenix Backend
  Core contexts     ██████████ 100%  Claims, Evidence, Relationships, Navigation, PromptScores
  GraphQL schema    ██████████ 100%  Queries + mutations for all entities
  REST API          ██████████ 100%  Import, export, batch-import, sync-status
  User auth         ██████████ 100%  Registration, login, settings, magic links
  ArangoDB layer    ██████████ 100%  CRUD, queries, setup, migrations
  Oban workers      ████████░░  80%  ZoteroSync worker (needs production polling config)

LiveView Frontend
  Investigation UI  ██████████ 100%  Dashboard (index) + detail (show)
  Graph viz         █████████░  90%  D3.js force-directed (needs browser verification)
  PROMPT radar      █████████░  90%  D3.js radar chart (needs browser verification)
  Navigation paths  ██████████ 100%  Step-by-step with audience switching
  Layouts + nav     ██████████ 100%  Root layout, auth nav, flash messages

Zotero Integration
  API client        ██████████ 100%  Tesla-based Zotero API v3 client
  Mapper            ██████████ 100%  Bidirectional Zotero <-> Evidence mapping
  Sync coordinator  ██████████ 100%  Incremental sync, conflict resolution
  REST endpoints    ██████████ 100%  Import, batch-import, export, sync-status

Infrastructure
  Containerfile     ██████████ 100%  Multi-stage Podman build
  Nginx config      ██████████ 100%  Reverse proxy + WebSocket + static
  Systemd service   ██████████ 100%  Hardened service unit
  Runtime config    ██████████ 100%  Environment-based production config

Testing
  Unit tests        ██████████ 100%  257 tests, 0 failures
  NUJ protocols     ██████████ 100%  Task script, feedback form, consent, decision matrix
  Browser testing   ░░░░░░░░░░   0%  Manual verification needed

Documentation
  ARCHITECTURE.md   ██████████ 100%  Data model, API specs, database design
  ROADMAP.md        ██████████ 100%  18-month implementation plan
  CLAUDE.md         ██████████ 100%  AI assistant context
  TOPOLOGY.md       ██████████ 100%  This file
  Zotero design     ██████████ 100%  Two-way sync design doc
  DB evaluation     ██████████ 100%  ArangoDB vs SurrealDB vs Virtuoso

RSR Compliance
  SPDX headers      ██████████ 100%  PMPL-1.0-or-later on all source files
  .well-known/      ██████████ 100%  security.txt, ai.txt, humans.txt
  AI manifest       ██████████ 100%  0-AI-MANIFEST.a2ml
  .machine_readable ██████████ 100%  STATE.scm, META.scm, ECOSYSTEM.scm
```

## Key Dependencies

| Dependency | Version | Purpose |
|-----------|---------|---------|
| Elixir | ~> 1.16 | Language runtime |
| Phoenix | ~> 1.8.3 | Web framework |
| Phoenix LiveView | ~> 1.1.19 | Real-time UI |
| Absinthe | ~> 1.7 | GraphQL |
| Arangox | ~> 0.7.0 | ArangoDB driver |
| Ecto SQL | ~> 3.11 | PostgreSQL (auth only) |
| Oban | ~> 2.17 | Background jobs |
| Tesla | ~> 1.8 | HTTP client |
| bcrypt_elixir | ~> 3.0 | Password hashing |
| Swoosh | ~> 1.4 | Email delivery |
| D3.js | v7 | Graph + radar visualisation |
| Tailwind CSS | ~> 0.2 | Styling |

## File Structure Summary

| Directory | Files | Description |
|-----------|-------|-------------|
| `lib/evidence_graph/` | 28 .ex | Core business logic (contexts, schemas, workers) |
| `lib/evidence_graph_web/` | 25 .ex | Web layer (router, controllers, LiveView, GraphQL) |
| `lib/evidence_graph_web/` | 7 .heex | HTML templates |
| `test/` | 17 .exs | ExUnit tests (257 tests) |
| `assets/js/` | 7 .js | LiveView client, D3.js hooks |
| `assets/css/` | 1 .css | Tailwind entry point |
| `config/` | 4 .exs | Environment configs |
| `docs/` | 8 files | Architecture, testing, integration docs |
| `deploy/` | 3 files | Nginx, systemd, env template |
| `priv/static/.well-known/` | 3 files | security.txt, ai.txt, humans.txt |
