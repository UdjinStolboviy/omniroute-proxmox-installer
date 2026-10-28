#!/usr/bin/env bash

# GitHub API Helper Module for OmniRoute Proxmox Installer

get_latest_release() {
  local repo="cheaper-inference/OmniRoute"
  local fallback_repo="diegosouzapw/OmniRoute"
  local latest_version=""
  
  msg_info "Checking latest release of OmniRoute..."
  
  # 1. Try GitHub API with redirect follow (-L)
  latest_version=$(curl -fsSL -H "User-Agent: curl" "https://api.github.com/repos/${repo}/releases/latest" 2>/dev/null | grep -oE '"tag_name": *"[^"]+"' | head -n 1 | cut -d'"' -f4 | sed 's/^v//' || true)
  
  # 2. Fallback to redirect URL tracking if API fails or is rate limited
  if [ -z "$latest_version" ]; then
    msg_warn "GitHub API rate limited or failed. Querying releases via redirect header..."
    latest_version=$(curl -fsSIL "https://github.com/${repo}/releases/latest" 2>/dev/null | grep -i "^location:" | tail -n 1 | awk '{print $2}' | tr -d '\r' | grep -oE '[^/]+$' | sed 's/^v//' || true)
  fi

  # 3. Fallback to legacy repository redirect if needed
  if [ -z "$latest_version" ]; then
    latest_version=$(curl -fsSIL "https://github.com/${fallback_repo}/releases/latest" 2>/dev/null | grep -i "^location:" | tail -n 1 | awk '{print $2}' | tr -d '\r' | grep -oE '[^/]+$' | sed 's/^v//' || true)
  fi

  # Final fallback check
  if [[ -n "$latest_version" ]]; then
    msg_ok "Latest stable version identified: $latest_version"
  else
    latest_version="latest"
    msg_warn "Could not resolve latest tag. Defaulting to 'latest' image tag."
  fi
  
  OMNIROUTE_VERSION="$latest_version"
}
