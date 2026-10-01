#!/usr/bin/env bash
# Builds Caddy with the edge plugins for one OS/arch.
# Usage: GOOS=linux GOARCH=amd64 ./xcaddy.sh <output-path>
# Single source of truth for Caddy and plugin versions.
set -euo pipefail

CADDY_VERSION=v2.11.4
PLUGINS=(
  github.com/mholt/caddy-ratelimit@5625512f24f6f59d6f64fb3aafe5eecff0b286db
  github.com/caddyserver/cache-handler@v0.17.0
  github.com/darkweak/storages/otter/caddy@v0.0.20
)

out=${1:?output path}
args=()
for p in "${PLUGINS[@]}"; do args+=(--with "$p"); done
CGO_ENABLED=0 xcaddy build "$CADDY_VERSION" --output "$out" "${args[@]}"
