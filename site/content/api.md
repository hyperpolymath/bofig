---
title: API Reference
description: GraphQL API reference for Evidence Graph
template: default
order: 3
---

# API Reference

The Evidence Graph platform provides a GraphQL API for all operations.

## Endpoint

```
POST /api/graphql
```

Content-Type: `application/json`

## Authentication

Currently in Phase 1 (PoC), the API is unauthenticated. Phase 2 will add JWT-based authentication.

## Types

### Investigation

```graphql
type Investigation {
  id: ID!
  title: String!
  description: String
  status: InvestigationStatus!
  claims: [Claim!]!
  navigationPaths: [NavigationPath!]!
  createdAt: DateTime!
  updatedAt: DateTime!
}

enum InvestigationStatus {
  DRAFT
  ACTIVE
  PUBLISHED
  ARCHIVED
}
```

### Claim

```graphql
type Claim {
  id: ID!
  investigationId: ID!
  text: String!
  claimType: ClaimType!
  promptScores: PromptScores
  evidence: [Evidence!]!
  relationships: [Relationship!]!
  createdAt: DateTime!
}

enum ClaimType {
  PRIMARY
  SECONDARY
  HYPOTHETICAL
}
```

### Evidence

```graphql
type Evidence {
  id: ID!
  title: String!
  evidenceType: EvidenceType!
  sourceUrl: String
  metadata: JSON
  ipfsHash: String
  createdAt: DateTime!
}

enum EvidenceType {
  DOCUMENT
  MEDIA
  DATA
  TESTIMONY
}
```

### PromptScores

```graphql
type PromptScores {
  provenance: Float!
  replicability: Float!
  objective: Float!
  methodology: Float!
  publication: Float!
  transparency: Float!
  overall: Float!
}
```

### Relationship

```graphql
type Relationship {
  id: ID!
  fromId: ID!
  toId: ID!
  relationshipType: RelationshipType!
  confidence: Float
  notes: String
}

enum RelationshipType {
  SUPPORTS
  CONTRADICTS
  CONTEXTUALIZES
}
```

## Queries

### Get Investigation

```graphql
query GetInvestigation($id: ID!) {
  investigation(id: $id) {
    id
    title
    description
    status
    claims {
      id
      text
      claimType
    }
  }
}
```

### List Investigations

```graphql
query ListInvestigations($status: InvestigationStatus) {
  investigations(status: $status) {
    id
    title
    status
    createdAt
  }
}
```

### Get Claim with Evidence

```graphql
query GetClaimWithEvidence($id: ID!) {
  claim(id: $id) {
    id
    text
    promptScores {
      overall
      provenance
      methodology
    }
    evidence {
      id
      title
      evidenceType
    }
  }
}
```

### Evidence Chain Traversal

```graphql
query TraverseEvidenceChain($claimId: ID!, $depth: Int!) {
  evidenceChain(claimId: $claimId, depth: $depth) {
    nodes {
      ... on Claim {
        id
        text
      }
      ... on Evidence {
        id
        title
      }
    }
    edges {
      from
      to
      type
    }
  }
}
```

## Mutations

### Create Investigation

```graphql
mutation CreateInvestigation($input: CreateInvestigationInput!) {
  createInvestigation(input: $input) {
    id
    title
    status
  }
}

input CreateInvestigationInput {
  title: String!
  description: String
}
```

### Create Claim

```graphql
mutation CreateClaim($input: CreateClaimInput!) {
  createClaim(input: $input) {
    id
    text
    claimType
  }
}

input CreateClaimInput {
  investigationId: ID!
  text: String!
  claimType: ClaimType!
}
```

### Add Evidence

```graphql
mutation AddEvidence($input: AddEvidenceInput!) {
  addEvidence(input: $input) {
    id
    title
    evidenceType
  }
}

input AddEvidenceInput {
  title: String!
  evidenceType: EvidenceType!
  sourceUrl: String
  metadata: JSON
}
```

### Create Relationship

```graphql
mutation CreateRelationship($input: CreateRelationshipInput!) {
  createRelationship(input: $input) {
    id
    relationshipType
  }
}

input CreateRelationshipInput {
  fromId: ID!
  toId: ID!
  relationshipType: RelationshipType!
  confidence: Float
  notes: String
}
```

### Update PROMPT Scores

```graphql
mutation UpdatePromptScores($claimId: ID!, $scores: PromptScoresInput!) {
  updatePromptScores(claimId: $claimId, scores: $scores) {
    id
    promptScores {
      overall
    }
  }
}

input PromptScoresInput {
  provenance: Float!
  replicability: Float!
  objective: Float!
  methodology: Float!
  publication: Float!
  transparency: Float!
}
```

## Error Handling

Errors are returned in the standard GraphQL format:

```json
{
  "errors": [
    {
      "message": "Claim not found",
      "path": ["claim"],
      "extensions": {
        "code": "NOT_FOUND"
      }
    }
  ]
}
```

## Rate Limiting

Phase 1 has no rate limiting. Phase 2 will implement:

- 100 requests/minute for anonymous users
- 1000 requests/minute for authenticated users

## GraphQL Playground

Visit `/graphiql` for an interactive GraphQL explorer.
