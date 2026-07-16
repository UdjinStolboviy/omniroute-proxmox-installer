#!/usr/bin/env bash

# OmniRoute Update Script (runs inside the LXC container)
set -euo pipefail

APP_DIR="/opt/omniroute"

if [ ! -d "$APP_DIR" ]; then
  echo "Error: OmniRoute installation directory $APP_DIR not found." >&2
  exit 1
fi

cd "$APP_DIR"

echo "=== Checking for OmniRoute Updates ==="
repo="diegosouzapw/OmniRoute"
latest_version=$(curl -s "https://api.github.com/repos/${repo}/releases/latest" | grep -oE '"tag_name": *"[^"]+"' | head -n 1 | cut -d'"' -f4 | sed 's/^v//')

if [ -z "$latest_version" ]; then
  echo "Warning: Could not fetch latest release from GitHub API. Checking redirect URL..."
  latest_version=$(curl -sI "https://github.com/${repo}/releases/latest" | grep -i "^location:" | awk '{print $2}' | tr -d '\r' | grep -oE '[^/]+$' | sed 's/^v//')
fi

if [ -z "$latest_version" ]; then
  latest_version="latest"
  echo "Could not detect version. Defaulting to 'latest' tag."
else
  echo "Latest version found: $latest_version"
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

echo "=== Pulling Latest Docker Images ==="
docker compose pull

echo "=== Restarting Services ==="
docker compose up -d --remove-orphans

echo "=== Cleaning Up Old Docker Images ==="
docker image prune -f

echo "=== OmniRoute Update Completed successfully ==="
