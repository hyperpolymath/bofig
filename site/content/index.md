---
title: Evidence Graph
description: Infrastructure for pragmatic epistemology in investigative journalism
template: default
order: 1
---

# Evidence Graph (bofig)

> Infrastructure for pragmatic epistemology. Combining i-docs navigation, PROMPT epistemological scoring, and boundary objects theory.

## Vision

We didn't fall from Truth to Post-Truth; we evolved to complex epistemology without building infrastructure. This system IS that infrastructure.

## Key Features

- **i-docs Navigation**: Navigation over narration, reader agency
- **PROMPT Framework**: 6-dimensional epistemological scoring
- **Boundary Objects**: Multiple audience perspectives on same evidence
- **Graph-based Evidence**: Connect claims, evidence, and relationships

## Quick Start

```bash
# Clone the repository
git clone https://github.com/Hyperpolymath/bofig.git
cd bofig

# Install dependencies
mix deps.get

# Start ArangoDB (Podman)
podman run -d --name arangodb -p 8529:8529 \
  -e ARANGO_ROOT_PASSWORD=dev arangodb/arangodb:3.11

# Start Phoenix server
mix phx.server
```

Visit [localhost:4000](http://localhost:4000) to see the application.

## Architecture

- **Backend**: Elixir/Phoenix with GraphQL (Absinthe)
- **Database**: ArangoDB (documents + graph)
- **Frontend**: Phoenix LiveView with D3.js visualizations
- **Integration**: Zotero two-way sync

## PROMPT Scoring

The PROMPT framework provides 6 dimensions for epistemological assessment:

- **P**rovenance: Source origin and chain of custody
- **R**eplicability: Can findings be reproduced?
- **O**bjective: Research purpose and goals
- **M**ethodology: Methods used to gather evidence
- **P**ublication: Peer review and publication status
- **T**ransparency: Data and method accessibility

## Contributing

See our [Contributing Guide](https://github.com/Hyperpolymath/bofig/blob/main/CONTRIBUTING.md) for details.

## License

AGPL-3.0-or-later
