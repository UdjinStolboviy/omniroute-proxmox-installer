#!/usr/bin/env bash

# This script runs INSIDE the LXC container to install Docker and Docker Compose.
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

echo "=== Installing Prerequisites ==="
apt-get update -y
apt-get install -y --no-install-recommends \
  ca-certificates \
  curl \
  gnupg \
  lsb-release \
  systemd

echo "=== Setting Up Docker APT Repository ==="
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

echo "=== Installing Docker CE ==="
apt-get update -y
apt-get install -y --no-install-recommends \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin

echo "=== Configuring and Starting Docker ==="
systemctl daemon-reload
systemctl enable docker
systemctl start docker

echo "=== Verifying Docker Installation ==="
if docker --version >/dev/null 2>&1; then
  echo "Docker version: $(docker --version)"
else
  echo "Docker installation failed!" >&2
  exit 1
fi

if docker compose version >/dev/null 2>&1; then
  echo "Docker Compose version: $(docker compose version)"
else
  echo "Docker Compose installation failed!" >&2
  exit 1
fi

echo "Docker setup complete."
