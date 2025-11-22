# Database Evaluation: ArangoDB vs SurrealDB vs Virtuoso

## Executive Summary

**Winner: ArangoDB** for Phase 1-2, with optional Virtuoso addition in Phase 3+

| Criteria | ArangoDB | SurrealDB | Virtuoso |
|----------|----------|-----------|----------|
| **Multi-model** | ✅ Native | ✅ Native | ❌ RDF-only |
| **Graph queries** | ✅ AQL | ✅ SurrealQL | ✅ SPARQL |
| **Elixir support** | ✅ arangox | ⚠️ HTTP only | ⚠️ SPARQL HTTP |
| **Production ready** | ✅ Yes | ⚠️ New (2022) | ✅ Yes |
| **Managed hosting** | ✅ €45/month | ❌ Self-host | ✅ €€€ |
| **JSON storage** | ✅ Native | ✅ Native | ❌ RDF triples |
| **Semantic web** | ⚠️ Via export | ⚠️ Via export | ✅ Native |
| **Learning curve** | Medium | Medium | Steep (RDF) |

---

## ArangoDB

### Strengths
1. **Multi-model done right**: Document + Graph + Key-Value in one database
2. **AQL is intuitive**: SQL-like syntax for graph traversals
3. **Strong Elixir integration**: `arangox` library mature and maintained
4. **Production-proven**: Used by companies like Cisco, Barclays
5. **Managed hosting**: ArangoDB Oasis (€45/month includes backups, monitoring)
6. **JSON-first**: Schema-less documents, perfect for Evidence metadata

### Weaknesses
1. **Cost**: Not free at scale (but €45/month is reasonable)
2. **No native RDF**: Must export to JSON-LD for semantic web
3. **Smaller community**: Than PostgreSQL/Neo4j

### Sample Queries

#### Create Collections
```javascript
// Setup
db._createDocumentCollection("investigations");
db._createDocumentCollection("claims");
db._createDocumentCollection("evidence");
db._createDocumentCollection("navigation_paths");
db._createEdgeCollection("relationships");
```

#### Insert Data
```javascript
// Insert investigation
db.investigations.insert({
  _key: "uk_inflation_2023",
  title: "UK Inflation Crisis 2023",
  status: "published",
  lead_journalist: "Sarah Johnson",
  created_at: "2023-01-15"
});

// Insert claims
db.claims.insert({
  _key: "claim_1",
  investigation_id: "uk_inflation_2023",
  text: "UK inflation reached 40-year high of 11.1% in October 2022",
  claim_type: "primary",
  confidence_level: 0.95,
  prompt_scores: {
    provenance: 95,
    replicability: 100,
    objective: 90,
    methodology: 85,
    publication: 100,
    transparency: 90
  }
});

db.claims.insert({
  _key: "claim_2",
  investigation_id: "uk_inflation_2023",
  text: "Energy price cap increase was primary driver of inflation spike",
  claim_type: "supporting",
  confidence_level: 0.85,
  prompt_scores: {
    provenance: 80,
    replicability: 75,
    objective: 70,
    methodology: 80,
    publication: 85,
    transparency: 75
  }
});

// Insert evidence
db.evidence.insert({
  _key: "ons_cpi_data",
  title: "Consumer Price Index Data - October 2022",
  evidence_type: "dataset",
  source_url: "https://www.ons.gov.uk/economy/inflationandpriceindices",
  zotero_key: "ABC123",
  dublin_core: {
    creator: "Office for National Statistics",
    date: "2022-11-16",
    type: "Dataset",
    format: "CSV"
  },
  prompt_scores: {
    provenance: 100,
    replicability: 100,
    objective: 95,
    methodology: 95,
    publication: 100,
    transparency: 95
  },
  tags: ["inflation", "cpi", "uk", "2022"]
});

db.evidence.insert({
  _key: "ofgem_price_cap",
  title: "Ofgem Energy Price Cap Announcement Q4 2022",
  evidence_type: "document",
  source_url: "https://www.ofgem.gov.uk/price-cap",
  zotero_key: "DEF456",
  dublin_core: {
    creator: "Office of Gas and Electricity Markets",
    date: "2022-08-26",
    type: "Press Release"
  },
  prompt_scores: {
    provenance: 95,
    replicability: 90,
    objective: 85,
    methodology: 80,
    publication: 90,
    transparency: 85
  },
  tags: ["energy", "price-cap", "ofgem", "uk"]
});

// Create relationships
db.relationships.insert({
  _from: "claims/claim_1",
  _to: "evidence/ons_cpi_data",
  relationship_type: "supports",
  weight: 1.0,
  confidence: 0.95,
  reasoning: "ONS CPI data directly confirms the 11.1% figure",
  created_by: "sarah.johnson@example.com"
});

db.relationships.insert({
  _from: "claims/claim_2",
  _to: "evidence/ofgem_price_cap",
  relationship_type: "supports",
  weight: 0.8,
  confidence: 0.85,
  reasoning: "Price cap increase correlates with inflation spike timing",
  created_by: "sarah.johnson@example.com"
});

db.relationships.insert({
  _from: "claims/claim_1",
  _to: "claims/claim_2",
  relationship_type: "contextualizes",
  weight: 0.7,
  confidence: 0.8,
  reasoning: "Energy prices provide context for overall inflation rate",
  created_by: "sarah.johnson@example.com"
});
```

#### Query: Find All Evidence Supporting a Claim
```javascript
FOR claim IN claims
  FILTER claim._key == "claim_1"
  FOR v, e, p IN 1..1 OUTBOUND claim relationships
    FILTER e.relationship_type == "supports"
    FILTER IS_SAME_COLLECTION("evidence", v)
    RETURN {
      claim: claim.text,
      evidence: v.title,
      weight: e.weight,
      confidence: e.confidence,
      reasoning: e.reasoning,
      prompt_overall: (
        v.prompt_scores.provenance * 0.2 +
        v.prompt_scores.replicability * 0.15 +
        v.prompt_scores.objective * 0.15 +
        v.prompt_scores.methodology * 0.2 +
        v.prompt_scores.publication * 0.15 +
        v.prompt_scores.transparency * 0.15
      )
    }
```

**Output:**
```json
{
  "claim": "UK inflation reached 40-year high of 11.1% in October 2022",
  "evidence": "Consumer Price Index Data - October 2022",
  "weight": 1.0,
  "confidence": 0.95,
  "reasoning": "ONS CPI data directly confirms the 11.1% figure",
  "prompt_overall": 97.5
}
```

#### Query: Evidence Chain (Multi-Hop Traversal)
```javascript
// Find all nodes within 3 hops of a claim
FOR claim IN claims
  FILTER claim._key == "claim_1"
  FOR v, e, p IN 1..3 ANY claim relationships
    RETURN DISTINCT {
      node_type: IS_SAME_COLLECTION("claims", v) ? "claim" : "evidence",
      node_id: v._key,
      node_text: v.text || v.title,
      depth: LENGTH(p.edges),
      path_weight: PRODUCT(p.edges[*].weight)
    }
```

**Output:**
```json
[
  {
    "node_type": "evidence",
    "node_id": "ons_cpi_data",
    "node_text": "Consumer Price Index Data - October 2022",
    "depth": 1,
    "path_weight": 1.0
  },
  {
    "node_type": "claim",
    "node_id": "claim_2",
    "node_text": "Energy price cap increase was primary driver",
    "depth": 1,
    "path_weight": 0.7
  },
  {
    "node_type": "evidence",
    "node_id": "ofgem_price_cap",
    "node_text": "Ofgem Energy Price Cap Announcement",
    "depth": 2,
    "path_weight": 0.56
  }
]
```

#### Query: Find Contradictions
```javascript
FOR claim IN claims
  FILTER claim.investigation_id == "uk_inflation_2023"
  LET supporting = (
    FOR v, e IN 1..1 OUTBOUND claim relationships
      FILTER e.relationship_type == "supports"
      RETURN {evidence: v, weight: e.weight}
  )
  LET contradicting = (
    FOR v, e IN 1..1 OUTBOUND claim relationships
      FILTER e.relationship_type == "contradicts"
      RETURN {evidence: v, weight: e.weight}
  )
  FILTER LENGTH(contradicting) > 0
  RETURN {
    claim: claim.text,
    support_count: LENGTH(supporting),
    contradiction_count: LENGTH(contradicting),
    net_support: SUM(supporting[*].weight) - SUM(contradicting[*].weight),
    contradictions: contradicting[*].evidence.title
  }
```

#### Query: Audience-Weighted PROMPT Scores
```javascript
// Researcher perspective (prioritizes methodology, replicability)
LET researcher_weights = {
  provenance: 0.15,
  replicability: 0.30,
  objective: 0.15,
  methodology: 0.35,
  publication: 0.10,
  transparency: 0.20
}

FOR evidence IN evidence
  FILTER evidence.investigation_id == "uk_inflation_2023"
  LET researcher_score = (
    evidence.prompt_scores.provenance * researcher_weights.provenance +
    evidence.prompt_scores.replicability * researcher_weights.replicability +
    evidence.prompt_scores.objective * researcher_weights.objective +
    evidence.prompt_scores.methodology * researcher_weights.methodology +
    evidence.prompt_scores.publication * researcher_weights.publication +
    evidence.prompt_scores.transparency * researcher_weights.transparency
  )
  SORT researcher_score DESC
  RETURN {
    title: evidence.title,
    researcher_score: researcher_score,
    scores: evidence.prompt_scores
  }
```

#### Query: Full-Text Search
```javascript
// Requires fulltext index:
db.evidence.ensureIndex({ type: "fulltext", fields: ["title", "tags"] });

FOR doc IN FULLTEXT(evidence, "title,tags", "inflation,energy")
  RETURN {
    title: doc.title,
    tags: doc.tags,
    score: BM25(doc)  // Built-in relevance scoring
  }
```

### Elixir Integration (arangox)

```elixir
# mix.exs
{:arangox, "~> 0.5.2"}

# config/dev.exs
config :evidence_graph, EvidenceGraph.ArangoDB,
  endpoints: "http://localhost:8529",
  database: "evidence_graph",
  username: "root",
  password: "dev"

# lib/evidence_graph/arango.ex
defmodule EvidenceGraph.ArangoDB do
  use Arangox

  def start_link(opts) do
    Arangox.start_link(
      endpoints: opts[:endpoints],
      database: opts[:database],
      username: opts[:username],
      password: opts[:password]
    )
  end

  def find_claim(claim_id) do
    query = """
    FOR claim IN claims
      FILTER claim._key == @claim_id
      RETURN claim
    """

    Arangox.transaction(
      __MODULE__,
      fn cursor ->
        cursor
        |> Arangox.cursor(query, %{claim_id: claim_id})
        |> Enum.to_list()
      end
    )
  end

  def evidence_chain(claim_id, max_depth \\ 3) do
    query = """
    FOR claim IN claims
      FILTER claim._key == @claim_id
      FOR v, e, p IN 1..@max_depth ANY claim relationships
        RETURN {
          node: v,
          edge: e,
          depth: LENGTH(p.edges)
        }
    """

    Arangox.transaction(
      __MODULE__,
      fn cursor ->
        cursor
        |> Arangox.cursor(query, %{claim_id: claim_id, max_depth: max_depth})
        |> Enum.to_list()
      end
    )
  end
end
```

---

## SurrealDB

### Strengths
1. **Modern architecture**: Built with Rust, async-first
2. **Multi-model**: Documents + Graph + Realtime
3. **GraphQL-like syntax**: Familiar to web developers
4. **Embedded mode**: Can run in-process (great for testing)
5. **Permissions system**: Fine-grained access control built-in

### Weaknesses
1. **New/immature**: Only released in 2022, smaller ecosystem
2. **No managed hosting**: Must self-host (more ops burden)
3. **Elixir support lacking**: No native driver, must use HTTP API
4. **Limited production deployments**: Unproven at scale
5. **Smaller community**: Fewer Stack Overflow answers

### Sample Query (SurrealQL)
```sql
-- Create claim with relationship
CREATE claims:claim_1 SET
  text = "UK inflation reached 11.1%",
  investigation = investigations:uk_inflation_2023,
  prompt_scores = {
    provenance: 95,
    methodology: 85
  };

-- Create relationship
RELATE claims:claim_1->supports->evidence:ons_cpi_data SET
  weight = 1.0,
  confidence = 0.95;

-- Traverse graph
SELECT ->supports->evidence.* FROM claims:claim_1;
```

### Verdict
**Wait and see.** Exciting tech, but too risky for Phase 1. Revisit in 2026 if community grows.

---

## Virtuoso

### Strengths
1. **RDF native**: Best-in-class SPARQL performance
2. **Semantic web integration**: Direct compatibility with academic repositories
3. **Mature**: 20+ years of development
4. **Federated queries**: Can query across multiple SPARQL endpoints
5. **Linked Open Data**: Natural fit for cross-investigation linking

### Weaknesses
1. **RDF-only**: Documents must be converted to triples (awkward for JSON)
2. **Steep learning curve**: SPARQL + ontologies require semantic web knowledge
3. **Overkill for Phase 1**: Don't need semantic web until Phase 3
4. **Schema rigidity**: RDF schemas less flexible than JSON documents
5. **Elixir support**: HTTP SPARQL only, no native driver

### Sample Query (SPARQL)
```sparql
PREFIX eg: <http://evidencegraph.org/ontology#>
PREFIX dc: <http://purl.org/dc/elements/1.1/>

SELECT ?claim ?evidence ?weight
WHERE {
  ?claim a eg:Claim ;
         eg:text "UK inflation reached 11.1%" ;
         eg:supports ?rel .
  ?rel eg:to ?evidence ;
       eg:weight ?weight .
  ?evidence dc:title ?evidenceTitle .
}
ORDER BY DESC(?weight)
```

### Verdict
**Phase 3 addition.** Store JSON-LD from day 1 in ArangoDB. Export to Virtuoso only if semantic web features become critical.

---

## Hybrid Approach: The Winner

### Architecture B (Progressive Enhancement)

```
Phase 1-2: ArangoDB only
├── Store documents as JSON (flexible schema)
├── Store JSON-LD context for future RDF export
├── Use AQL for graph queries
└── €45/month ArangoDB Oasis

Phase 3+: Add Virtuoso (optional)
├── Export investigations to RDF triples
├── Add SPARQL endpoint for academic integration
├── Keep ArangoDB as primary database
└── Virtuoso as read-only semantic web layer
```

### Data Format (JSON-LD Ready)
```json
{
  "@context": "https://schema.org",
  "@type": "Claim",
  "@id": "http://evidencegraph.org/claims/claim_1",
  "text": "UK inflation reached 11.1%",
  "dateCreated": "2023-01-15",
  "author": {
    "@type": "Person",
    "name": "Sarah Johnson"
  },
  "evidence": {
    "@type": "Dataset",
    "@id": "http://evidencegraph.org/evidence/ons_cpi_data",
    "name": "Consumer Price Index Data"
  },
  "prompt_scores": {
    "provenance": 95,
    "replicability": 100
  }
}
```

**Benefits:**
- Start simple (ArangoDB)
- Preserve migration path (JSON-LD)
- Add semantic web when needed
- No vendor lock-in

---

## Local Testing Guide

### Setup ArangoDB (Podman)

```bash
# Pull image
podman pull arangodb/arangodb:3.11

# Run container
podman run -d \
  --name arangodb \
  -p 8529:8529 \
  -e ARANGO_ROOT_PASSWORD=dev \
  arangodb/arangodb:3.11

# Access web UI
open http://localhost:8529
# Username: root
# Password: dev
```

### Load Test Data

```bash
# Create database
curl -X POST http://localhost:8529/_db/_system/_api/database \
  -u root:dev \
  -H "Content-Type: application/json" \
  -d '{"name": "evidence_graph"}'

# Create collections (see queries above)
# Use ArangoDB web UI > Collections > New Collection
```

### Benchmark Queries

```javascript
// In ArangoDB web UI > Queries tab

// Test 1: Simple claim lookup (should be <10ms)
FOR claim IN claims
  FILTER claim._key == "claim_1"
  RETURN claim

// Test 2: 3-hop traversal (should be <100ms for 100 nodes)
FOR claim IN claims
  FILTER claim._key == "claim_1"
  FOR v, e, p IN 1..3 ANY claim relationships
    RETURN v

// Test 3: Full-text search (should be <200ms)
FOR doc IN FULLTEXT(evidence, "title,tags", "inflation")
  RETURN doc

// Test 4: Aggregation (PROMPT score average)
FOR evidence IN evidence
  COLLECT investigation = evidence.investigation_id
  AGGREGATE avg_provenance = AVG(evidence.prompt_scores.provenance)
  RETURN {investigation, avg_provenance}
```

### Expected Performance (Local)
- Simple lookup: ~5ms
- 3-hop traversal (100 nodes): ~50ms
- Full-text search: ~100ms
- Aggregations: ~30ms

---

## Decision Matrix

| Use Case | ArangoDB | SurrealDB | Virtuoso |
|----------|----------|-----------|----------|
| Flexible JSON storage | ✅ Perfect | ✅ Good | ❌ Poor (triples) |
| Graph traversals | ✅ AQL excellent | ✅ Good | ✅ SPARQL excellent |
| Elixir integration | ✅ arangox mature | ⚠️ HTTP only | ⚠️ SPARQL HTTP |
| Production hosting | ✅ Managed €45 | ❌ Self-host | ✅ Managed €€€ |
| Learning curve | ✅ Medium | ✅ Medium | ❌ Steep |
| Academic integration | ⚠️ Export needed | ⚠️ Export needed | ✅ Native RDF |
| Cost | ✅ €540/year | ✅ Free (self-host) | ❌ €€€ |
| Risk | ✅ Low | ⚠️ High (new) | ✅ Low (mature) |

**Final Decision:** ArangoDB for Phase 1-2, evaluate Virtuoso in Phase 3.

---

## References

- ArangoDB Docs: https://www.arangodb.com/docs/stable/
- SurrealDB Docs: https://surrealdb.com/docs
- Virtuoso Docs: http://virtuoso.openlinksw.com/
- JSON-LD: https://json-ld.org/
- arangox GitHub: https://github.com/ArangoDB-Community/arangox

---

**Last Updated:** 2025-11-22
**Next Review:** Month 3 (benchmark decision point)
