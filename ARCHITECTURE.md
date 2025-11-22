# Evidence Graph Architecture

## Vision

Infrastructure for pragmatic epistemology in investigative journalism. Combines:
- **i-docs navigation principles**: Navigation over narration, reader agency
- **PROMPT framework**: 6-dimensional epistemological scoring
- **Boundary objects theory**: Multiple perspectives on same evidence

## Philosophical Foundation

### The Core Argument

We didn't fall from Truth to Post-Truth; we evolved to complex epistemology without building infrastructure. This system IS that infrastructure.

### Design Principles

1. **Coordination without consensus**: Different audiences navigate same evidence differently
2. **Measurable epistemology**: PROMPT scores make evidence quality explicit
3. **Progressive enhancement**: Works without JavaScript, enhanced with it
4. **Open by default**: Open source, EU data sovereignty, NUJ network adoption

## Data Model

### Core Entities

#### Claims
```elixir
%Claim{
  id: UUID,
  text: String,
  investigation_id: UUID,
  claim_type: :primary | :supporting | :counter,
  confidence_level: 0.0..1.0,
  prompt_scores: %PromptScores{
    provenance: 0..100,      # Source credibility
    replicability: 0..100,   # Can others verify?
    objective: 0..100,       # Operational definitions
    methodology: 0..100,     # Research quality
    publication: 0..100,     # Peer review, venue
    transparency: 0..100     # Open data/methods
  },
  created_by: String,
  created_at: DateTime,
  updated_at: DateTime,
  metadata: Map
}
```

#### Evidence
```elixir
%Evidence{
  id: UUID,
  title: String,
  evidence_type: :document | :dataset | :interview | :media | :other,
  source_url: String,
  local_path: String,
  ipfs_hash: String,        # Provenance via IPFS
  zotero_key: String,       # Two-way sync
  dublin_core: Map,         # Standardized metadata
  schema_org: Map,          # Semantic web compatibility
  extraction_date: DateTime,
  prompt_scores: %PromptScores{},
  tags: [String],
  created_at: DateTime,
  metadata: Map
}
```

#### Relationships (Edges)
```elixir
%Relationship{
  _from: "claims/:uuid",
  _to: "evidence/:uuid",
  relationship_type: :supports | :contradicts | :contextualizes,
  weight: -1.0..1.0,        # -1 = strong contradiction, +1 = strong support
  confidence: 0.0..1.0,     # How certain is this relationship?
  created_by: String,
  reasoning: String,        # Why this relationship exists
  created_at: DateTime,
  metadata: Map
}
```

#### Navigation Paths
```elixir
%NavigationPath{
  id: UUID,
  investigation_id: UUID,
  audience_type: :activist | :policymaker | :researcher | :skeptic | :affected_person | :journalist,
  name: String,
  description: String,
  entry_points: [UUID],     # Starting claims/evidence
  path_nodes: [%PathNode{
    entity_id: UUID,
    entity_type: :claim | :evidence,
    order: Integer,
    context: String,        # Why show this here?
    emphasis: Map           # What to highlight
  }],
  created_at: DateTime
}
```

### Investigations (Container)
```elixir
%Investigation{
  id: UUID,
  title: String,
  description: String,
  status: :draft | :review | :published | :archived,
  lead_journalist: String,
  collaborators: [String],
  publication_date: DateTime,
  tags: [String],
  created_at: DateTime,
  updated_at: DateTime
}
```

## Database Architecture

### Phase 1-2: ArangoDB (Multi-Model)

**Why ArangoDB:**
- Native graph + document database
- Strong Elixir integration via `arangox`
- AQL (query language) supports complex traversals
- Production-ready, €45/month managed hosting
- JSON storage preserves Schema.org/Dublin Core

**Collections:**
- `investigations` (document)
- `claims` (document)
- `evidence` (document)
- `navigation_paths` (document)
- `relationships` (edge collection)

**Indexes:**
```javascript
// Full-text search on claims/evidence
db.claims.ensureIndex({ type: "fulltext", fields: ["text"] })
db.evidence.ensureIndex({ type: "fulltext", fields: ["title", "metadata"] })

// PROMPT score queries
db.claims.ensureIndex({ type: "skiplist", fields: ["prompt_scores.provenance"] })
db.evidence.ensureIndex({ type: "skiplist", fields: ["prompt_scores.methodology"] })

// Investigation queries
db.claims.ensureIndex({ type: "hash", fields: ["investigation_id"] })
db.evidence.ensureIndex({ type: "hash", fields: ["investigation_id"] })

// Zotero sync
db.evidence.ensureIndex({ type: "hash", fields: ["zotero_key"] })
```

### Phase 3+: Optional Virtuoso (RDF/SPARQL)

Add only if semantic web integration becomes critical:
- Academic repository linking
- Cross-investigation semantic queries
- Linked Open Data publishing

**Migration path:** JSON-LD stored from day 1 enables easy export to RDF.

## API Design

### GraphQL Schema (Absinthe)

```graphql
type Investigation {
  id: ID!
  title: String!
  description: String
  status: InvestigationStatus!
  claims(limit: Int, offset: Int): [Claim!]!
  evidence(limit: Int, offset: Int): [Evidence!]!
  navigationPaths: [NavigationPath!]!
  createdAt: DateTime!
  updatedAt: DateTime!
}

type Claim {
  id: ID!
  text: String!
  claimType: ClaimType!
  confidenceLevel: Float!
  promptScores: PromptScores!
  supportingEvidence: [Evidence!]!
  contradictingEvidence: [Evidence!]!
  relationships: [Relationship!]!
  createdAt: DateTime!
}

type Evidence {
  id: ID!
  title: String!
  evidenceType: EvidenceType!
  sourceUrl: String
  ipfsHash: String
  zoteroKey: String
  promptScores: PromptScores!
  supportsClaims: [Claim!]!
  contradictsClaims: [Claim!]!
  metadata: JSON
  tags: [String!]!
}

type PromptScores {
  provenance: Int!        # 0-100
  replicability: Int!
  objective: Int!
  methodology: Int!
  publication: Int!
  transparency: Int!
  overall: Float!         # Calculated average
}

type Relationship {
  id: ID!
  from: Node!
  to: Node!
  relationshipType: RelationType!
  weight: Float!          # -1.0 to 1.0
  confidence: Float!      # 0.0 to 1.0
  reasoning: String
}

type NavigationPath {
  id: ID!
  audienceType: AudienceType!
  name: String!
  description: String
  pathNodes: [PathNode!]!
}

type PathNode {
  entity: Node!
  order: Int!
  context: String
  emphasis: JSON
}

union Node = Claim | Evidence

enum ClaimType { PRIMARY, SUPPORTING, COUNTER }
enum EvidenceType { DOCUMENT, DATASET, INTERVIEW, MEDIA, OTHER }
enum RelationType { SUPPORTS, CONTRADICTS, CONTEXTUALIZES }
enum AudienceType { ACTIVIST, POLICYMAKER, RESEARCHER, SKEPTIC, AFFECTED_PERSON, JOURNALIST }
enum InvestigationStatus { DRAFT, REVIEW, PUBLISHED, ARCHIVED }

# Queries
type Query {
  investigation(id: ID!): Investigation
  investigations(limit: Int, offset: Int, status: InvestigationStatus): [Investigation!]!

  claim(id: ID!): Claim
  searchClaims(query: String!, investigationId: ID): [Claim!]!

  evidence(id: ID!): Evidence
  evidenceByZoteroKey(zoteroKey: String!): Evidence
  searchEvidence(query: String!, investigationId: ID): [Evidence!]!

  # Graph traversal
  evidenceChain(claimId: ID!, maxDepth: Int): EvidenceGraph!
  findPath(fromId: ID!, toId: ID!, maxDepth: Int): [PathStep!]!

  # Navigation
  navigationPath(id: ID!): NavigationPath
  navigationPathsFor(investigationId: ID!, audienceType: AudienceType): [NavigationPath!]!
}

type EvidenceGraph {
  rootClaim: Claim!
  nodes: [Node!]!
  edges: [Relationship!]!
  depth: Int!
}

type PathStep {
  node: Node!
  relationship: Relationship
  depth: Int!
}

# Mutations
type Mutation {
  # Investigations
  createInvestigation(input: CreateInvestigationInput!): Investigation!
  updateInvestigation(id: ID!, input: UpdateInvestigationInput!): Investigation!

  # Claims
  createClaim(input: CreateClaimInput!): Claim!
  updateClaim(id: ID!, input: UpdateClaimInput!): Claim!
  updatePromptScores(claimId: ID!, scores: PromptScoresInput!): Claim!

  # Evidence
  createEvidence(input: CreateEvidenceInput!): Evidence!
  updateEvidence(id: ID!, input: UpdateEvidenceInput!): Evidence!
  importFromZotero(zoteroKey: String!, investigationId: ID!): Evidence!

  # Relationships
  createRelationship(input: CreateRelationshipInput!): Relationship!
  updateRelationshipWeight(id: ID!, weight: Float!, confidence: Float!): Relationship!
  deleteRelationship(id: ID!): Boolean!

  # Navigation Paths
  createNavigationPath(input: CreateNavigationPathInput!): NavigationPath!
  updateNavigationPath(id: ID!, input: UpdateNavigationPathInput!): NavigationPath!
}

# Input types (truncated for brevity)
input CreateClaimInput {
  investigationId: ID!
  text: String!
  claimType: ClaimType!
  confidenceLevel: Float
}

input PromptScoresInput {
  provenance: Int!
  replicability: Int!
  objective: Int!
  methodology: Int!
  publication: Int!
  transparency: Int!
}

input CreateRelationshipInput {
  fromId: ID!
  toId: ID!
  relationshipType: RelationType!
  weight: Float!
  confidence: Float!
  reasoning: String
}
```

### REST Endpoints (Phoenix)

For Zotero integration and simple operations:

```
POST   /api/v1/evidence/import          # Zotero → Evidence
GET    /api/v1/evidence/:id/export      # Evidence → Zotero JSON
POST   /api/v1/investigations/:id/export # Export investigation
GET    /api/v1/health                   # System health
```

## Technology Stack

### Backend
- **Elixir 1.16+** - Functional, concurrent, fault-tolerant
- **Phoenix 1.7+** - Web framework
- **Absinthe 1.7+** - GraphQL implementation
- **ArangoDB 3.11+** - Multi-model database
- **arangox** - Elixir ArangoDB driver

### Frontend
- **Phoenix LiveView** - Server-rendered, real-time UI (progressive enhancement)
- **D3.js** - Graph visualization
- **Alpine.js** (minimal) - Progressive JavaScript enhancement
- **Tailwind CSS** - Styling

### Integration
- **Julia 1.10+** - Statistical analysis, PROMPT scoring algorithms
- **IPFS** - Evidence provenance and archival
- **Zotero API** - Two-way sync

### Infrastructure
- **Podman/Docker** - Containerization
- **Hetzner Cloud** - EU hosting (data sovereignty)
- **GitHub Actions** - CI/CD

## Key Algorithms

### PROMPT Overall Score Calculation

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
    Enum.reduce(@weights, 0.0, fn {dimension, weight}, acc ->
      acc + (Map.get(scores, dimension, 0) * weight)
    end)
  end
end
```

### Relationship Weight Propagation

For evidence chains: `claim₁ → evidence₁ → claim₂ → evidence₂`

```elixir
defmodule EvidenceGraph.Traversal do
  def propagated_weight(path) do
    path
    |> Enum.map(& &1.weight)
    |> Enum.reduce(1.0, &(&1 * &2))  # Multiplicative decay
  end

  def confidence_adjusted_weight(relationship) do
    relationship.weight * relationship.confidence
  end
end
```

### Navigation Path Scoring

Different audiences prioritize different PROMPT dimensions:

```elixir
@audience_weights %{
  researcher: %{methodology: 0.35, replicability: 0.30, transparency: 0.20},
  policymaker: %{provenance: 0.30, publication: 0.25, objective: 0.25},
  skeptic: %{transparency: 0.35, replicability: 0.30, methodology: 0.20},
  activist: %{provenance: 0.30, objective: 0.25, publication: 0.20},
  affected_person: %{objective: 0.35, provenance: 0.30, transparency: 0.20},
  journalist: %{provenance: 0.25, transparency: 0.25, replicability: 0.20}
}
```

## Security & Privacy

### Authentication
- JWT tokens for API access
- Role-based access: `admin`, `journalist`, `reviewer`, `reader`
- Optional DIDs (Decentralized Identifiers) for blockchain integration

### Data Protection
- EU GDPR compliant
- Interview subjects can be anonymized
- Evidence can be marked as `sensitive` (restricted access)
- Audit logs for all mutations

### IPFS Integration
```elixir
defmodule EvidenceGraph.IPFS do
  def store_evidence(file_path) do
    {:ok, hash} = Kubo.add(file_path)
    # Store hash in Evidence record
    # Original file + hash = tamper-proof provenance
  end

  def verify_evidence(evidence) do
    current_hash = Kubo.add(evidence.local_path)
    current_hash == evidence.ipfs_hash
  end
end
```

## Performance Considerations

### Query Optimization

**Problem:** Deep evidence chains (10+ hops) can be slow

**Solution:** Pre-computed materialized paths

```javascript
// ArangoDB: Store paths up to depth 3
FOR claim IN claims
  LET paths = (
    FOR v, e, p IN 1..3 OUTBOUND claim relationships
      RETURN p
  )
  UPDATE claim WITH { materialized_paths: paths } IN claims
```

### Caching Strategy

- **GraphQL:** DataLoader for N+1 query prevention
- **LiveView:** ETS cache for PROMPT score calculations
- **ArangoDB:** Query result cache (built-in)

### Benchmarks (Target)

- Single investigation load: < 500ms
- Evidence chain (depth 5): < 1s
- Full-text search: < 200ms
- GraphQL mutation: < 100ms

## Testing Strategy

### Unit Tests (ExUnit)
- Data model validations
- PROMPT score calculations
- Relationship weight propagation

### Integration Tests
- GraphQL query/mutation flows
- Zotero import/export
- ArangoDB CRUD operations

### E2E Tests (Wallaby)
- Complete investigation workflow
- Navigation path creation
- Graph visualization interaction

### User Testing (Phase 1 Goal)
- 25 participants from NUJ network
- One complete investigation (7 claims, 30 evidence items)
- 3 navigation paths tested
- Qualitative feedback on PROMPT UI

## Migration & Deployment

### Development
```bash
# Local ArangoDB
podman run -p 8529:8529 -e ARANGO_ROOT_PASSWORD=dev arangodb/arangodb:3.11

# Elixir/Phoenix
mix phx.new evidence_graph --database postgres  # For user auth only
mix deps.get
mix ecto.setup
iex -S mix phx.server
```

### Production (Hetzner)
- ArangoDB Cloud: €45/month managed instance
- Phoenix: Debian 12, systemd service
- Nginx reverse proxy, Let's Encrypt SSL
- Automated backups via ArangoDB Cloud

### Data Migration Path

**Phase 1 → Phase 2:** Schema evolution within ArangoDB
**Phase 2 → Phase 3:** If adding Virtuoso:

```elixir
# Export to JSON-LD
evidence |> Jason.encode!() |> JSONLD.expand()

# Import to Virtuoso
Virtuoso.import_turtle(jsonld_to_turtle(data))
```

## Open Questions

1. **PROMPT scoring UI**: Sliders vs. dropdowns vs. questionnaire?
2. **Real-time collaboration**: Conflict resolution for concurrent edits?
3. **Evidence versioning**: Full history or snapshots?
4. **Mobile experience**: Responsive web or native app (future)?

## References

- ArangoDB Multi-Model: https://www.arangodb.com/docs/stable/
- Absinthe GraphQL: https://hexdocs.pm/absinthe/
- IPFS Docs: https://docs.ipfs.tech/
- Dublin Core: https://www.dublincore.org/specifications/dublin-core/
- Schema.org: https://schema.org/

---

**Last Updated:** 2025-11-22
**Status:** Phase 0 (Architecture) → Phase 1 (PoC) beginning
