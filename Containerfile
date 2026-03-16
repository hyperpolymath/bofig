# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
#
# Multi-stage Containerfile for Evidence Graph (bofig)
# Build: podman build -t evidence-graph -f Containerfile .
# Run:   podman run -d --name evidence-graph --env-file .env -p 4000:4000 evidence-graph

# =============================================================================
# Stage 1: Build
# =============================================================================
FROM docker.io/hexpm/elixir:1.18.3-erlang-27.3.3-debian-bookworm-20250428-slim AS build

# Install build dependencies
RUN apt-get update -y && \
    apt-get install -y --no-install-recommends \
      build-essential \
      git \
      curl \
      ca-certificates && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Set build environment
ENV MIX_ENV=prod
ENV LANG=C.UTF-8

WORKDIR /app

# Install hex and rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Copy dependency manifests first (layer caching)
COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV

# Copy compile-time config
RUN mkdir -p config
COPY config/config.exs config/prod.exs config/runtime.exs config/

# Compile dependencies (separate layer from app code)
RUN mix deps.compile

# Copy application source
COPY lib lib
COPY priv priv
COPY assets assets

# Build assets (tailwind, esbuild, vendor copy, digest)
RUN mix assets.deploy

# Compile the application
RUN mix compile

# Build the OTP release
RUN mix release

# =============================================================================
# Stage 2: Runtime
# =============================================================================
FROM docker.io/library/debian:bookworm-slim AS runtime

# Install runtime dependencies only
RUN apt-get update -y && \
    apt-get install -y --no-install-recommends \
      libstdc++6 \
      openssl \
      libncurses5 \
      locales \
      ca-certificates \
      curl && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Set locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

# Create non-root user
RUN groupadd --gid 1000 evidence_graph && \
    useradd --uid 1000 --gid evidence_graph --shell /bin/bash --create-home evidence_graph

WORKDIR /app

# Copy the release from the build stage
COPY --from=build --chown=evidence_graph:evidence_graph /app/_build/prod/rel/evidence_graph ./

# Switch to non-root user
USER evidence_graph

# Expose the Phoenix port
EXPOSE 4000

# Health check (HTTP endpoint)
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD curl -f http://localhost:4000/api/health || exit 1

# Start the release
ENTRYPOINT ["bin/evidence_graph"]
CMD ["start"]
