# Podman Setup (Alternative to Docker)

## Install Podman

### macOS
```bash
brew install podman
podman machine init
podman machine start
```

### Linux (Debian/Ubuntu)
```bash
sudo apt-get install podman
```

## Run ArangoDB

```bash
# Create pod
podman pod create --name evidence-graph -p 8529:8529 -p 5432:5432

# Run ArangoDB
podman run -d \
  --pod evidence-graph \
  --name arangodb \
  -e ARANGO_ROOT_PASSWORD=dev \
  -v evidence_graph_arango:/var/lib/arangodb3 \
  arangodb/arangodb:3.11

# Run PostgreSQL (for user auth only)
podman run -d \
  --pod evidence-graph \
  --name postgres \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=evidence_graph_dev \
  -v evidence_graph_postgres:/var/lib/postgresql/data \
  postgres:16-alpine
```

## Access Services

- ArangoDB Web UI: http://localhost:8529
  - Username: `root`
  - Password: `dev`

- PostgreSQL: `localhost:5432`
  - User: `postgres`
  - Password: `postgres`
  - Database: `evidence_graph_dev`

## Stop/Start

```bash
podman pod stop evidence-graph
podman pod start evidence-graph
```

## Remove

```bash
podman pod rm -f evidence-graph
podman volume rm evidence_graph_arango evidence_graph_postgres
```
