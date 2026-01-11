# CLAUDE.md

This file contains context and guidelines for Claude (or other AI assistants) working on the **Evidence Graph for Investigative Journalism** project (aka "bofig").

## Project Overview

**Project Name:** bofig (Evidence Graph)
**Repository:** Hyperpolymath/bofig
**Purpose:** Infrastructure for pragmatic epistemology in investigative journalism

### Vision

We didn't fall from Truth to Post-Truth; we evolved to complex epistemology without building infrastructure. This system IS that infrastructure.

Combining:
- **i-docs navigation**: Navigation over narration, reader agency
- **PROMPT framework**: 6-dimensional epistemological scoring (Provenance, Replicability, Objective, Methodology, Publication, Transparency)
- **Boundary objects theory**: Multiple audience perspectives on same evidence

### User's PhD Argument

"Practical infrastructure for pragmatic epistemology" - building tools that acknowledge we coordinate without consensus, using boundary objects that work for different stakeholders (activists, policymakers, researchers, skeptics, affected persons, journalists).

## Project Structure

```
bofig/
├── .git/                      # Git repository
├── CLAUDE.md                  # This file
├── ARCHITECTURE.md            # Core data model, database design, API specs
├── ROADMAP.md                 # 18-month implementation plan
├── docs/
│   ├── database-evaluation.md # ArangoDB vs SurrealDB vs Virtuoso
│   └── zotero-integration.md  # Two-way sync design
├── lib/                       # Legacy Zotero extension (2017, to be updated)
│   └── exporter.js
├── config/                    # Elixir config (to be created)
├── lib/evidence_graph/        # Elixir backend (to be created)
│   ├── claims.ex
│   ├── evidence.ex
│   └── arango.ex
├── lib/evidence_graph_web/    # Phoenix web layer
│   ├── schema.ex              # Absinthe GraphQL schema
│   └── live/                  # LiveView UIs
├── test/                      # ExUnit tests
├── assets/                    # Frontend (D3.js visualizations)
└── priv/
    ├── repo/seeds.exs         # UK Inflation 2023 test data
    └── static/
```

## Development Setup

### Prerequisites

- **Elixir 1.16+** & **Erlang/OTP 26+**
- **Phoenix 1.7+**
- **ArangoDB 3.11+** (Podman container)
- **Node.js 20+** (for frontend assets)
- **Julia 1.10+** (optional, for statistical analysis)

### Initial Setup

```bash
# Clone the repository
git clone https://github.com/Hyperpolymath/bofig.git
cd bofig

# Install Elixir dependencies
mix deps.get
mix deps.compile

# Start ArangoDB (Podman)
podman run -d \
  --name arangodb \
  -p 8529:8529 \
  -e ARANGO_ROOT_PASSWORD=dev \
  arangodb/arangodb:3.11

# Create database and collections
mix ecto.create  # (for user auth only)
mix run priv/repo/setup_arango.exs

# Load test data
mix run priv/repo/seeds.exs

# Start Phoenix server
mix phx.server
# Visit: http://localhost:4000
```

### Environment Configuration

```bash
# .env (not committed)
ARANGO_ENDPOINT=http://localhost:8529
ARANGO_DATABASE=evidence_graph
ARANGO_USERNAME=root
ARANGO_PASSWORD=dev

SECRET_KEY_BASE=<generated via mix phx.gen.secret>
PHX_HOST=localhost
PORT=4000

# Optional
IPFS_API_URL=http://localhost:5001
JULIA_PATH=/usr/local/bin/julia
```

## Architecture

### Key Components

1. **ArangoDB**: Multi-model database (documents + graph)
2. **Phoenix/Elixir**: Web framework, GraphQL API
3. **Absinthe**: GraphQL implementation
4. **LiveView**: Server-rendered real-time UI
5. **D3.js**: Graph visualization
6. **Zotero Extension**: Evidence import/export

See [ARCHITECTURE.md](ARCHITECTURE.md) for full data model.

### Design Patterns

- **Hybrid B (Progressive Enhancement)**: Start simple, add semantic web later
- **Audience-weighted scoring**: Different PROMPT dimension weights per user type
- **Boundary objects**: Same data, multiple navigation paths
- **JSON-LD from day 1**: Preserves migration path to RDF/Virtuoso

### Key Decisions

| Decision | Rationale |
|----------|-----------|
| ArangoDB over SurrealDB | Production-proven, strong Elixir support, managed hosting |
| Elixir over Node/Python | Concurrency, fault tolerance, LiveView for real-time |
| LiveView over React | Progressive enhancement, less JavaScript |
| Optional PROMPT scoring | Reduce adoption friction initially |

### Dependencies

```elixir
# mix.exs
defp deps do
  [
    {:phoenix, "~> 1.7"},
    {:phoenix_live_view, "~> 0.20"},
    {:absinthe, "~> 1.7"},
    {:absinthe_phoenix, "~> 2.0"},
    {:arangox, "~> 0.5"},           # ArangoDB driver
    {:jason, "~> 1.4"},
    {:oban, "~> 2.17"},             # Background jobs (Zotero sync)
    {:ex_ipfs, "~> 0.1"},           # IPFS integration (Phase 2)
    {:mint, "~> 1.5"},              # HTTP client
    {:tesla, "~> 1.8"},             # Zotero API client
  ]
end
```

## Code Patterns & Conventions

### Style Guide

- **Elixir**: Follow [Elixir Style Guide](https://github.com/christopheradams/elixir_style_guide)
- **Phoenix**: Use contexts (e.g., `EvidenceGraph.Claims`, `EvidenceGraph.Evidence`)
- **GraphQL**: One resolver per query/mutation
- **Tests**: Descriptive test names, `describe` blocks for grouping

### File Organization

```
lib/evidence_graph/
├── claims/
│   ├── claim.ex          # Schema
│   └── prompt_scores.ex  # Embedded schema
├── evidence/
│   ├── evidence.ex
│   └── metadata.ex
├── relationships/
│   └── relationship.ex
├── navigation/
│   └── path.ex
└── arango.ex             # Database client

lib/evidence_graph_web/
├── schema/
│   ├── schema.ex         # Root schema
│   ├── claim_types.ex
│   ├── evidence_types.ex
│   └── resolvers/
│       ├── claim_resolver.ex
│       └── evidence_resolver.ex
├── live/
│   ├── investigation_live.ex
│   ├── graph_live.ex     # D3.js visualization
│   └── prompt_live.ex    # PROMPT scoring UI
└── controllers/
    └── evidence_controller.ex  # REST for Zotero
```

### Common Patterns

#### PROMPT Score Calculation
```elixir
defmodule EvidenceGraph.Scoring do
  @weights %{
    provenance: 0.20,
    replicability: 0.15,
    objective: 0.15,
    methodology: 0.20,
    publication: 0.15,
    transparency: 0.15
  }

  def calculate_overall(scores) do
    Enum.reduce(@weights, 0.0, fn {dim, weight}, acc ->
      acc + (Map.get(scores, dim, 0) * weight)
    end)
  end
end
```

#### ArangoDB Query
```elixir
def find_supporting_evidence(claim_id) do
  query = """
  FOR claim IN claims
    FILTER claim._key == @claim_id
    FOR v, e IN 1..1 OUTBOUND claim relationships
      FILTER e.relationship_type == "supports"
      RETURN v
  """

  Arangox.transaction(ArangoDB, fn cursor ->
    cursor
    |> Arangox.cursor(query, %{claim_id: claim_id})
    |> Enum.to_list()
  end)
end
```

## Testing

### Running Tests

```bash
# All tests
mix test

# Specific file
mix test test/evidence_graph/claims_test.exs

# With coverage
mix test --cover

# Watch mode
mix test.watch
```

### Test Structure

```
test/
├── evidence_graph/
│   ├── claims_test.exs
│   ├── evidence_test.exs
│   └── scoring_test.exs
├── evidence_graph_web/
│   ├── schema_test.exs
│   ├── live/
│   │   └── graph_live_test.exs
│   └── controllers/
│       └── evidence_controller_test.exs
└── support/
    ├── fixtures.ex
    └── arango_case.ex
```

### Writing Tests

```elixir
defmodule EvidenceGraph.ClaimsTest do
  use EvidenceGraph.DataCase

  describe "create_claim/1" do
    test "creates claim with valid attributes" do
      attrs = %{
        investigation_id: "inv_123",
        text: "Test claim",
        claim_type: :primary
      }

      assert {:ok, claim} = Claims.create_claim(attrs)
      assert claim.text == "Test claim"
    end

    test "requires investigation_id" do
      attrs = %{text: "Test"}
      assert {:error, changeset} = Claims.create_claim(attrs)
      assert errors_on(changeset).investigation_id
    end
  end
end
```

## Common Tasks

### Adding New Features

1. Create feature branch: `git checkout -b feature/description`
2. Write failing test
3. Implement feature
4. Update documentation
5. Commit with descriptive message
6. Push and create PR

### Debugging

```bash
# Interactive shell with app loaded
iex -S mix phx.server

# Debug ArangoDB queries
iex> EvidenceGraph.ArangoDB.find_claim("claim_1")

# LiveView debugging
# Add: require Logger; Logger.debug("State: #{inspect(socket.assigns)}")

# GraphQL query in browser
# Visit: http://localhost:4000/graphiql
```

### Building/Compiling

```bash
# Compile Elixir
mix compile

# Build frontend assets
npm run build --prefix assets

# Production release
MIX_ENV=prod mix release
```

## Deployment

### Development
- Local Phoenix server: `mix phx.server`
- Local ArangoDB: Podman container

### Production (Phase 2)
- **Hosting**: Hetzner Cloud (EU data sovereignty)
- **ArangoDB**: ArangoDB Oasis (€45/month)
- **Phoenix**: Systemd service on Debian 12
- **Proxy**: Nginx + Let's Encrypt SSL
- **CI/CD**: GitHub Actions

## Important Notes for Claude

### Philosophical Core (CRITICAL!)

This isn't just a database project. It's infrastructure for **coordinating without consensus**. Every design choice should ask:

1. Does this support multiple audience perspectives?
2. Does this make epistemology measurable?
3. Does this enable navigation over narration?

### When Working on This Project

- **PROMPT scoring is optional initially** (reduce adoption friction)
- **Progressive enhancement**: Build for no-JS first, enhance later
- **ArangoDB benchmark early**: Month 3 = decision point
- **NUJ network for testing**: Real journalists, not academics
- **Open source from day 1**: All commits public

### Git Workflow

- Development branches: `claude/*` pattern
- Commit frequently with clear messages
- Always `git push -u origin <branch-name>`
- Month 3, 9, 12 = decision points (see ROADMAP.md)

### Things to Watch Out For

1. **Don't prematurely optimize**: Start simple, ArangoDB is enough for Phase 1
2. **Don't require PROMPT scoring**: Make it optional, users can skip
3. **Security**: No command injection, XSS, SQL injection (even though NoSQL)
4. **EU GDPR**: Anonymize interview subjects, handle sensitive evidence
5. **Performance**: <500ms page loads, <1s graph traversals (depth 5)

### Testing Context

- **Phase 1 goal**: 25 NUJ participants test one investigation
- **Test data**: UK Inflation 2023 (7 claims, 30 evidence items)
- **Decision point**: Month 3 - continue or pivot based on user feedback

## Resources

### Documentation

- [ARCHITECTURE.md](ARCHITECTURE.md) - Full data model
- [ROADMAP.md](ROADMAP.md) - 18-month plan
- [docs/database-evaluation.md](docs/database-evaluation.md) - Database comparison
- [docs/zotero-integration.md](docs/zotero-integration.md) - Sync design

### External Resources

- **ArangoDB Docs**: https://www.arangodb.com/docs/stable/
- **Phoenix Guides**: https://hexdocs.pm/phoenix/overview.html
- **Absinthe**: https://hexdocs.pm/absinthe/
- **PROMPT Framework**: (User's PhD thesis - not public yet)
- **i-docs principles**: [MIT Open Documentary Lab](http://opendoclab.mit.edu/)

### Related Projects

- **Hypothesis**: Web annotation (https://hypothes.is/)
- **Zotero**: Reference management (https://www.zotero.org/)
- **Gephi**: Graph visualization (https://gephi.org/)
- **Voyant Tools**: Text analysis (https://voyant-tools.org/)
- **FormDB Debugger**: Proof-carrying database debugger (https://github.com/hyperpolymath/formdb-debugger)
- **FormBase**: Open-source Airtable alternative (https://github.com/hyperpolymath/formbase)

## Changelog

### 2025-11-22 - Architecture Phase Complete
- Created ARCHITECTURE.md (data model, API design, database comparison)
- Created ROADMAP.md (18-month implementation plan)
- Created docs/database-evaluation.md (ArangoDB benchmarks)
- Created docs/zotero-integration.md (two-way sync design)
- Updated CLAUDE.md with project-specific context

### Future
- Month 1: Elixir/Phoenix project initialized
- Month 2: Zotero integration working
- Month 3: First user testing (25 participants)

---

**Last Updated:** 2025-11-22
**Current Phase:** Phase 1 (PoC) - Month 1
**Maintained By:** @Hyperpolymath
**Status:** Architecture complete, moving to implementation

## Questions or Issues?

- **GitHub Issues**: https://github.com/Hyperpolymath/bofig/issues
- **Project Lead**: @Hyperpolymath
- **NUJ Network**: For user testing (Month 3, 6, 12)
