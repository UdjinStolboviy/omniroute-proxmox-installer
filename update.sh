#!/usr/bin/env bash

# OmniRoute Update Script (runs inside the LXC container)
set -euo pipefail

APP_DIR="/opt/omniroute"

if [ ! -d "$APP_DIR" ]; then
  echo "Error: OmniRoute installation directory $APP_DIR not found." >&2
  exit 1
fi

cd "$APP_DIR"

# Allow user to specify a version manually (e.g. /opt/omniroute/update.sh 3.8.52 or latest)
TARGET_VERSION="${1:-}"

# Read current version from .env if present
CURRENT_VERSION=""
if [ -f .env ]; then
  CURRENT_VERSION=$(grep -E "^OMNIROUTE_VERSION=" .env 2>/dev/null | cut -d'=' -f2- | tr -d '"' | tr -d "'" || true)
fi

echo "=== OmniRoute Update ==="
if [ -n "$CURRENT_VERSION" ]; then
  echo "Current version: $CURRENT_VERSION"
else
  echo "Current version: not set (using image default)"
fi

if [ -n "$TARGET_VERSION" ]; then
  # Strip leading 'v' if supplied by user (e.g. v3.8.52 -> 3.8.52)
  TARGET_VERSION=$(echo "$TARGET_VERSION" | sed 's/^v//')
  echo "Target version specified: $TARGET_VERSION"
  latest_version="$TARGET_VERSION"
else
  echo "Checking for latest OmniRoute release..."
  repo="cheaper-inference/OmniRoute"
  fallback_repo="diegosouzapw/OmniRoute"

  # 1. Try GitHub API with redirect follow (-L)
  latest_version=$(curl -fsSL -H "User-Agent: curl" "https://api.github.com/repos/${repo}/releases/latest" 2>/dev/null | grep -oE '"tag_name": *"[^"]+"' | head -n 1 | cut -d'"' -f4 | sed 's/^v//' || true)

  # 2. Try Fallback Redirect URL if API is rate limited (60 req/hr unauthenticated limit)
  if [ -z "$latest_version" ]; then
    echo "Warning: GitHub API rate limited or unreachable. Querying release redirect header..."
    latest_version=$(curl -fsSIL "https://github.com/${repo}/releases/latest" 2>/dev/null | grep -i "^location:" | tail -n 1 | awk '{print $2}' | tr -d '\r' | grep -oE '[^/]+$' | sed 's/^v//' || true)
  fi

  # 3. Try legacy repository redirect if primary failed
  if [ -z "$latest_version" ]; then
    latest_version=$(curl -fsSIL "https://github.com/${fallback_repo}/releases/latest" 2>/dev/null | grep -i "^location:" | tail -n 1 | awk '{print $2}' | tr -d '\r' | grep -oE '[^/]+$' | sed 's/^v//' || true)
  fi

  if [ -z "$latest_version" ]; then
    latest_version="latest"
    echo "Could not detect release tag. Defaulting to 'latest' tag."
  else
    echo "Latest version found: $latest_version"
  fi
fi

# Update OMNIROUTE_VERSION in .env without overwriting other persistent configurations
if [ -f .env ]; then
  if grep -q "^OMNIROUTE_VERSION=" .env; then
    sed -i "s/^OMNIROUTE_VERSION=.*/OMNIROUTE_VERSION=$latest_version/" .env
  else
    echo "OMNIROUTE_VERSION=$latest_version" >> .env
  fi
else
  echo "OMNIROUTE_VERSION=$latest_version" > .env
fi

echo "=== Pulling Docker Images (tag: $latest_version) ==="
docker compose pull

echo "=== Restarting Services ==="
docker compose up -d --remove-orphans

echo "=== Cleaning Up Old Docker Images ==="
docker image prune -f

echo "=== OmniRoute Update Completed successfully (Version: $latest_version) ==="
