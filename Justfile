# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
#
# Evidence Graph (bofig) - Justfile
# Task automation for development, testing, deployment, and compliance
# Install: https://github.com/casey/just

# Default recipe (list all tasks)
default:
    @just --list

# ─────────────────────────────────────────────────────────────────────────────
# SETUP & INSTALLATION
# ─────────────────────────────────────────────────────────────────────────────

# Install Elixir dependencies
deps:
    mix deps.get

# Full setup: deps, databases, seeds
setup: deps
    @echo "Setting up databases..."
    podman-compose up -d
    @echo "Waiting for services to be ready..."
    sleep 5
    mix ecto.create
    mix run -e "EvidenceGraph.ArangoDB.setup_database()"
    mix run priv/repo/seeds.exs
    @echo "Setup complete. Run 'just dev' to start server."

# Start ArangoDB + PostgreSQL containers via podman-compose
setup-db:
    podman-compose up -d

# ─────────────────────────────────────────────────────────────────────────────
# DATABASE
# ─────────────────────────────────────────────────────────────────────────────

# Start database containers
db-start:
    podman-compose up -d

# Stop database containers
db-stop:
    podman-compose stop

# Restart database containers
db-restart:
    podman-compose restart

# Reset all data (ArangoDB + PostgreSQL + reseed)
db-reset:
    mix run -e "EvidenceGraph.ArangoDB.reset_database()"
    mix ecto.reset
    mix run priv/repo/seeds.exs

# Start individual ArangoDB container
arango-start:
    podman run -d --name arangodb -p 8529:8529 -e ARANGO_ROOT_PASSWORD=dev docker.io/arangodb/arangodb:3.11

# Start individual PostgreSQL container
postgres-start:
    podman run -d --name postgres -p 5432:5432 -e POSTGRES_PASSWORD=postgres -e POSTGRES_USER=postgres docker.io/library/postgres:16-alpine

# Load seed data
seed:
    mix run priv/repo/seeds.exs

# ─────────────────────────────────────────────────────────────────────────────
# DEVELOPMENT
# ─────────────────────────────────────────────────────────────────────────────

# Start development server
dev:
    mix phx.server

# Start development server with IEx shell
console:
    iex -S mix phx.server

# Show all Phoenix routes
routes:
    mix phx.routes

# Open ArangoDB Web UI
arango-ui:
    @echo "ArangoDB Web UI: http://localhost:8529"
    @echo "Username: root | Password: dev"
    @xdg-open http://localhost:8529 2>/dev/null || true

# ─────────────────────────────────────────────────────────────────────────────
# BUILD & COMPILE
# ─────────────────────────────────────────────────────────────────────────────

# Compile the project (warnings as errors)
compile:
    mix compile --warnings-as-errors

# Build frontend assets
assets-build:
    mix assets.build

# Build and minify assets for production
assets-deploy:
    mix assets.deploy

# Build OTP release for production
release:
    MIX_ENV=prod mix release

# Clean build artifacts
clean:
    mix clean
    rm -rf _build deps doc

# ─────────────────────────────────────────────────────────────────────────────
# TEST & QUALITY
# ─────────────────────────────────────────────────────────────────────────────

# Run all tests
test:
    mix test

# Run tests with coverage report
test-cover:
    mix test --cover

# Run a specific test file
test-file file:
    mix test {{file}}

# Run linter (Credo strict mode)
lint:
    mix credo --strict

# Run static analysis (Dialyzer)
dialyzer:
    mix dialyzer

# Format all Elixir code
fmt:
    mix format

# Check formatting (CI-friendly, no changes)
fmt-check:
    mix format --check-formatted

# Run CI checks: compile + format + lint + test
ci: compile fmt-check lint test

# Run full quality suite: format + lint + test + dialyzer
quality: fmt-check lint test dialyzer

# ─────────────────────────────────────────────────────────────────────────────
# CONTAINERS
# ─────────────────────────────────────────────────────────────────────────────

# Build OCI container image
container-build tag="latest":
    podman build -t evidence-graph:{{tag}} -f Containerfile .

# Run containerised application
container-run tag="latest":
    podman run -d --name evidence-graph --env-file .env -p 4000:4000 evidence-graph:{{tag}}

# Push container image to registry
container-push registry tag:
    podman push evidence-graph:{{tag}} {{registry}}/evidence-graph:{{tag}}

# ─────────────────────────────────────────────────────────────────────────────
# SECURITY
# ─────────────────────────────────────────────────────────────────────────────

# Run dependency security audits
security:
    mix deps.audit
    mix hex.audit

# Generate Phoenix secret key base
secret:
    mix phx.gen.secret

# Check security.txt compliance (RFC 9116)
security-txt-check:
    @test -f .well-known/security.txt && echo "security.txt exists" || echo "security.txt missing"
    @grep -q "Contact:" .well-known/security.txt && echo "Contact field present" || echo "Contact field missing"
    @grep -q "Expires:" .well-known/security.txt && echo "Expires field present" || echo "Expires field missing"

# ─────────────────────────────────────────────────────────────────────────────
# DOCUMENTATION
# ─────────────────────────────────────────────────────────────────────────────

# Generate HTML documentation
docs:
    mix docs

# List all available recipes with descriptions
cookbook:
    @just --list

# ─────────────────────────────────────────────────────────────────────────────
# VALIDATION & COMPLIANCE
# ─────────────────────────────────────────────────────────────────────────────

# Check RSR compliance
validate-rsr:
    @echo "RSR Compliance Check"
    @test -f LICENSE && echo "  LICENSE" || echo "  MISSING: LICENSE"
    @test -f SECURITY.md && echo "  SECURITY.md" || echo "  MISSING: SECURITY.md"
    @test -f CONTRIBUTING.adoc && echo "  CONTRIBUTING.adoc" || echo "  MISSING: CONTRIBUTING.adoc"
    @test -f CODE_OF_CONDUCT.md && echo "  CODE_OF_CONDUCT.md" || echo "  MISSING: CODE_OF_CONDUCT.md"
    @test -f MAINTAINERS.md && echo "  MAINTAINERS.md" || echo "  MISSING: MAINTAINERS.md"
    @test -f CHANGELOG.md && echo "  CHANGELOG.md" || echo "  MISSING: CHANGELOG.md"
    @test -f .well-known/security.txt && echo "  .well-known/security.txt" || echo "  MISSING: security.txt"
    @test -f .well-known/ai.txt && echo "  .well-known/ai.txt" || echo "  MISSING: ai.txt"
    @test -f 0-AI-MANIFEST.a2ml && echo "  0-AI-MANIFEST.a2ml" || echo "  MISSING: 0-AI-MANIFEST.a2ml"
    @test -f TOPOLOGY.md && echo "  TOPOLOGY.md" || echo "  MISSING: TOPOLOGY.md"
    @test -d .machine_readable && echo "  .machine_readable/" || echo "  MISSING: .machine_readable/"
    @test -f ARCHITECTURE.md && echo "  ARCHITECTURE.md" || echo "  MISSING: ARCHITECTURE.md"

# Validate STATE.scm syntax
validate-state:
    @test -f .machine_readable/STATE.scm && echo "STATE.scm exists" || echo "STATE.scm missing"

# Full validation suite
validate: validate-rsr validate-state compile test

# ─────────────────────────────────────────────────────────────────────────────
# VERSION CONTROL
# ─────────────────────────────────────────────────────────────────────────────

# Create annotated release tag
release-tag version:
    git tag -a v{{version}} -m "Release v{{version}}"

# Show current version info
version:
    @echo "Evidence Graph v1.0.0 (Phase 1 PoC)"
    @echo "Elixir: $(elixir --version | grep Elixir)"

# ─────────────────────────────────────────────────────────────────────────────
# GRAPHQL
# ─────────────────────────────────────────────────────────────────────────────

# Open GraphQL Playground
graphiql:
    @echo "GraphQL Playground: http://localhost:4000/api/graphiql"
    @xdg-open http://localhost:4000/api/graphiql 2>/dev/null || true

# Run example GraphQL query
graphql-example:
    @curl -s -X POST http://localhost:4000/api/graphql \
      -H "Content-Type: application/json" \
      -d '{"query": "{ claims(investigationId: \"uk_inflation_2023\") { id text promptScores { overall } } }"}' | mix run -e "IO.puts(Jason.Formatter.pretty_print(IO.read(:stdio, :eof)))"
