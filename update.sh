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

# Update OMNIROUTE_VERSION in omniroute.env or set it as an env var
# To ensure Docker Compose has OMNIROUTE_VERSION, we can write/overwrite a .env file containing it
echo "OMNIROUTE_VERSION=$latest_version" > .env

echo "=== Pulling Latest Docker Images ==="
docker compose pull

echo "=== Restarting Services ==="
docker compose up -d --remove-orphans

echo "=== Cleaning Up Old Docker Images ==="
docker image prune -f

echo "=== OmniRoute Update Completed successfully ==="
