---
title: Documentation
description: Complete documentation for the Evidence Graph platform
template: default
order: 2
---

# Documentation

Welcome to the Evidence Graph documentation. This guide covers everything you need to know to use and contribute to the platform.

## Getting Started

### Prerequisites

- Elixir 1.16+ and Erlang/OTP 26+
- Phoenix 1.7+
- ArangoDB 3.11+
- Node.js 20+ (for frontend assets)

### Installation

1. Clone the repository
2. Install Elixir dependencies: `mix deps.get`
3. Start ArangoDB container
4. Run database setup: `mix run priv/repo/setup_arango.exs`
5. Start the server: `mix phx.server`

## Core Concepts

### Investigations

An investigation is the top-level container for evidence and claims. Each investigation has:

- Title and description
- Status (draft, active, published)
- Navigation paths for different audiences
- Associated claims and evidence

### Claims

Claims are statements that can be supported or refuted by evidence:

- Primary claims: Main assertions
- Secondary claims: Supporting statements
- Hypothetical claims: Exploratory ideas

### Evidence

Evidence items support or contradict claims:

- Documents (PDFs, articles, reports)
- Media (images, video, audio)
- Data (datasets, statistics)
- Testimony (interviews, statements)

### Relationships

Relationships connect evidence to claims:

- Supports: Evidence strengthens claim
- Contradicts: Evidence weakens claim
- Contextualizes: Evidence provides context

## GraphQL API

The platform exposes a GraphQL API at `/api/graphql`.

### Example Queries

```graphql
query GetInvestigation($id: ID!) {
  investigation(id: $id) {
    title
    claims {
      text
      promptScores {
        overall
        provenance
        methodology
      }
      evidence {
        title
        type
      }
    }
  }
}
```

### Mutations

```graphql
mutation CreateClaim($input: CreateClaimInput!) {
  createClaim(input: $input) {
    id
    text
    createdAt
  }
}
```

## Configuration

### Environment Variables

```bash
ARANGO_ENDPOINT=http://localhost:8529
ARANGO_DATABASE=evidence_graph
ARANGO_USERNAME=root
ARANGO_PASSWORD=dev
SECRET_KEY_BASE=<generated>
```

### Database Setup

The platform uses ArangoDB for both document and graph storage. Collections:

- `investigations`: Investigation documents
- `claims`: Claim documents
- `evidence`: Evidence documents
- `relationships`: Graph edges connecting claims and evidence

## Development

### Running Tests

```bash
mix test              # All tests
mix test --cover      # With coverage
mix credo --strict    # Linting
mix dialyzer          # Type checking
```

### Code Style

- Follow the Elixir Style Guide
- Use contexts for domain logic
- One resolver per GraphQL operation

## Deployment

### Production Setup

1. Set up Hetzner Cloud VPS
2. Configure ArangoDB Oasis
3. Set up Nginx reverse proxy
4. Configure SSL with Let's Encrypt
5. Deploy Phoenix release

See [ROADMAP.md](https://github.com/Hyperpolymath/bofig/blob/main/ROADMAP.md) for the full deployment plan.
