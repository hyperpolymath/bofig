# Evidence Graph - Justfile
# Task automation for development, testing, and deployment
# Install: https://github.com/casey/just

# Default recipe (list all tasks)
default:
    @just --list

# Setup & Installation
# ====================

# Install all dependencies (Elixir + Node.js)
install:
    mix deps.get
    mix deps.compile
    cd assets && npm install

# Setup development environment from scratch
setup: install
    @echo "Starting databases..."
    docker-compose up -d
    @echo "Waiting for ArangoDB to be ready..."
    sleep 5
    @echo "Setting up ArangoDB collections..."
    mix run -e "EvidenceGraph.ArangoDB.setup_database()"
    @echo "Creating PostgreSQL database..."
    mix ecto.create
    @echo "Loading seed data..."
    mix run priv/repo/seeds.exs
    @echo "✅ Setup complete! Run 'just dev' to start server."

# Development
# ===========

# Start development server
dev:
    mix phx.server

# Start development server with IEx shell
dev-iex:
    iex -S mix phx.server

# Start only the databases
db-start:
    docker-compose up -d

# Stop databases
db-stop:
    docker-compose stop

# Restart databases
db-restart:
    docker-compose restart

# Reset all data (WARNING: destructive!)
db-reset:
    @echo "⚠️  This will delete ALL data. Press Ctrl+C to cancel, Enter to continue."
    @read
    docker-compose down -v
    docker-compose up -d
    sleep 5
    mix run -e "EvidenceGraph.ArangoDB.setup_database()"
    mix run priv/repo/seeds.exs
    @echo "✅ Database reset complete."

# Code Quality
# ============

# Run all code quality checks
check: format lint test security-scan

# Format all Elixir code
format:
    mix format

# Check if code is formatted (CI)
format-check:
    mix format --check-formatted

# Run linter (Credo)
lint:
    mix credo --strict

# Run static analysis (Dialyzer)
dialyzer:
    mix dialyzer

# Run security vulnerability scan
security-scan:
    mix deps.audit
    @echo "✅ Dependency security scan complete."

# Testing
# =======

# Run all tests
test:
    mix test

# Run tests with coverage
test-coverage:
    mix test --cover

# Run tests in watch mode
test-watch:
    mix test.watch

# Run specific test file
test-file FILE:
    mix test {{FILE}}

# GraphQL
# =======

# Start GraphQL Playground (browser will open)
graphiql:
    @echo "Opening GraphQL Playground..."
    @open http://localhost:4000/api/graphiql || xdg-open http://localhost:4000/api/graphiql

# Query GraphQL API with example
graphql-example:
    @echo "Querying all claims..."
    @curl -X POST http://localhost:4000/api/graphql \
      -H "Content-Type: application/json" \
      -d '{"query": "{ claims(investigationId: \"uk_inflation_2023\") { id text promptScores { overall } } }"}'

# Database (ArangoDB)
# ===================

# Open ArangoDB Web UI
arango-ui:
    @echo "Opening ArangoDB Web UI..."
    @open http://localhost:8529 || xdg-open http://localhost:8529
    @echo "Username: root"
    @echo "Password: dev"

# Run AQL query (pass query as argument)
arango-query QUERY:
    @echo "Running AQL query..."
    @mix run -e 'EvidenceGraph.ArangoDB.query("{{QUERY}}") |> IO.inspect()'

# Export investigation to JSON
export-investigation ID:
    @echo "Exporting investigation {{ID}}..."
    @mix run -e 'claims = EvidenceGraph.Claims.list_claims("{{ID}}"); IO.inspect(claims)'

# Seeding
# =======

# Load seed data
seed:
    mix run priv/repo/seeds.exs

# Load seed data and reset database first
seed-fresh: db-reset

# Documentation
# =============

# Generate HTML documentation
docs:
    mix docs
    @echo "✅ Docs generated in doc/index.html"

# Open generated documentation in browser
docs-open: docs
    @open doc/index.html || xdg-open doc/index.html

# Validate documentation links
docs-check:
    @echo "Checking for broken links in documentation..."
    @grep -r "http" docs/ README.md ARCHITECTURE.md ROADMAP.md | grep -v "example.com" | grep -v "TODO" || echo "✅ No obvious broken links"

# Security
# ========

# Generate new Phoenix secret key base
secret:
    mix phx.gen.secret

# Check security.txt compliance (RFC 9116)
security-txt-check:
    @echo "Checking security.txt compliance..."
    @test -f .well-known/security.txt && echo "✅ security.txt exists" || echo "❌ security.txt missing"
    @grep -q "Contact:" .well-known/security.txt && echo "✅ Contact field present" || echo "❌ Contact field missing"
    @grep -q "Expires:" .well-known/security.txt && echo "✅ Expires field present" || echo "❌ Expires field missing"

# Validate all security documentation
security-docs-check: security-txt-check
    @test -f SECURITY.md && echo "✅ SECURITY.md exists" || echo "❌ SECURITY.md missing"
    @test -f .well-known/ai.txt && echo "✅ ai.txt exists" || echo "❌ ai.txt missing"

# RSR Compliance
# ==============

# Check RSR (Rhodium Standard Repository) compliance
rsr-check:
    @echo "🔍 Checking RSR Framework compliance..."
    @test -f LICENSE.txt && echo "✅ LICENSE.txt (dual MIT + Palimpsest v0.8)" || echo "❌ LICENSE.txt missing"
    @test -f SECURITY.md && echo "✅ SECURITY.md" || echo "❌ SECURITY.md missing"
    @test -f CONTRIBUTING.md && echo "✅ CONTRIBUTING.md (TPCF Perimeter 3)" || echo "❌ CONTRIBUTING.md missing"
    @test -f CODE_OF_CONDUCT.md && echo "✅ CODE_OF_CONDUCT.md (CCCP)" || echo "❌ CODE_OF_CONDUCT.md missing"
    @test -f MAINTAINERS.md && echo "✅ MAINTAINERS.md (Governance)" || echo "❌ MAINTAINERS.md missing"
    @test -f CHANGELOG.md && echo "✅ CHANGELOG.md (SemVer)" || echo "❌ CHANGELOG.md missing"
    @test -f .well-known/security.txt && echo "✅ .well-known/security.txt (RFC 9116)" || echo "❌ security.txt missing"
    @test -f .well-known/ai.txt && echo "✅ .well-known/ai.txt (AI policy)" || echo "❌ ai.txt missing"
    @test -f .well-known/humans.txt && echo "✅ .well-known/humans.txt (Attribution)" || echo "❌ humans.txt missing"
    @test -f justfile && echo "✅ justfile (Task automation)" || echo "❌ justfile missing"
    @test -f README.md && echo "✅ README.md (Documentation)" || echo "❌ README.md missing"
    @test -f ARCHITECTURE.md && echo "✅ ARCHITECTURE.md (Technical docs)" || echo "❌ ARCHITECTURE.md missing"
    @echo ""
    @echo "📊 RSR Compliance Score: (count above ✅ / 12)"
    @echo ""
    @echo "🎯 RSR Bronze: 8-9/12 ✓"
    @echo "🥈 RSR Silver: 10-11/12"
    @echo "🥇 RSR Gold: 12/12 + CI/CD + 80% test coverage"

# Build & Release
# ===============

# Build production release
build:
    MIX_ENV=prod mix release

# Build assets for production
build-assets:
    cd assets && npm run deploy
    mix phx.digest

# Clean build artifacts
clean:
    mix clean
    rm -rf _build
    rm -rf deps
    rm -rf doc
    rm -rf priv/static/assets

# Deployment (Phase 2)
# ====================

# Deploy to production (placeholder for Phase 2)
deploy:
    @echo "❌ Production deployment not yet configured (Phase 2)."
    @echo "See ROADMAP.md Month 11 for deployment plan."

# Utility
# =======

# Show project statistics
stats:
    @echo "📊 Evidence Graph Statistics"
    @echo ""
    @echo "Lines of Code:"
    @find lib -name "*.ex" -o -name "*.exs" | xargs wc -l | tail -1
    @echo ""
    @echo "Test Files:"
    @find test -name "*_test.exs" | wc -l
    @echo ""
    @echo "Documentation Words:"
    @wc -w README.md ARCHITECTURE.md ROADMAP.md docs/*.md | tail -1
    @echo ""
    @echo "Dependencies:"
    @mix deps | grep -c "*" || echo "Run 'mix deps' first"
    @echo ""
    @echo "GraphQL Schema:"
    @grep -c "field :" lib/evidence_graph_web/schema.ex
    @echo ""

# Check project health
health:
    @echo "🏥 Project Health Check"
    @echo ""
    @docker-compose ps || echo "⚠️  Databases not running (run 'just db-start')"
    @echo ""
    @curl -s http://localhost:4000/api/graphql -X POST \
      -H "Content-Type: application/json" \
      -d '{"query": "{ __schema { types { name } } }"}' \
      > /dev/null && echo "✅ GraphQL API responding" || echo "❌ GraphQL API down"
    @echo ""
    @curl -s http://localhost:8529 > /dev/null && echo "✅ ArangoDB responding" || echo "❌ ArangoDB down"
    @echo ""

# Show version info
version:
    @echo "Evidence Graph v0.1.0 (Phase 1 Month 1)"
    @echo "Elixir: $(elixir --version | grep Elixir)"
    @echo "Phoenix: $(mix phx.new --version)"
    @echo "Node: $(node --version)"
    @echo "Docker: $(docker --version)"

# Git helpers
# ===========

# Create new feature branch
branch NAME:
    git checkout -b feature/{{NAME}}

# Commit with conventional commit format
commit TYPE MESSAGE:
    git add .
    git commit -m "{{TYPE}}: {{MESSAGE}}"

# Push current branch
push:
    git push -u origin $(git branch --show-current)

# Help
# ====

# Show help for all recipes
help:
    @just --list

# Quick start guide
quick-start:
    @echo "🚀 Evidence Graph - Quick Start"
    @echo ""
    @echo "1. Setup (first time only):"
    @echo "   just setup"
    @echo ""
    @echo "2. Start development server:"
    @echo "   just dev"
    @echo ""
    @echo "3. Open GraphQL Playground:"
    @echo "   just graphiql"
    @echo ""
    @echo "4. Run tests:"
    @echo "   just test"
    @echo ""
    @echo "5. Check code quality:"
    @echo "   just check"
    @echo ""
    @echo "6. Check RSR compliance:"
    @echo "   just rsr-check"
    @echo ""
    @echo "See 'just help' for all available commands."
