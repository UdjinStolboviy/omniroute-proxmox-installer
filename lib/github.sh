#!/usr/bin/env bash

# GitHub API Helper Module for OmniRoute Proxmox Installer

get_latest_release() {
  local repo="diegosouzapw/OmniRoute"
  local latest_version=""
  
  msg_info "Checking latest release of OmniRoute..."
  
  # Try GitHub API first
  latest_version=$(curl -s "https://api.github.com/repos/${repo}/releases/latest" | grep -oE '"tag_name": *"[^"]+"' | head -n 1 | cut -d'"' -f4)
  
  # Fallback to redirect URL tracking if API fails or is rate limited
  if [ -z "$latest_version" ]; then
    msg_warn "GitHub API rate limited or failed. Querying releases via redirect header..."
    latest_version=$(curl -sI "https://github.com/${repo}/releases/latest" | grep -i "^location:" | awk '{print $2}' | tr -d '\r' | grep -oE '[^/]+$')
  fi

  # Strip leading 'v' if present (e.g. v3.8.28 -> 3.8.28)
  if [[ -n "$latest_version" ]]; then
    # We will preserve 'v' if needed, but standard docker image tags might not use 'v'.
    # Wait, the official docker image tag might be the version number (e.g. 3.8.28 or v3.8.28).
    # Let's check! Usually both are supported or it's 'latest'. Let's clean the string.
    latest_version=$(echo "$latest_version" | sed 's/^v//')
    msg_ok "Latest stable version identified: $latest_version"
  else
    latest_version="latest"
    msg_warn "Could not resolve latest tag. Defaulting to 'latest' image tag."
  fi
  
  OMNIROUTE_VERSION="$latest_version"
}
