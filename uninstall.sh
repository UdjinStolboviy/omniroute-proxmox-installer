#!/usr/bin/env bash

# OmniRoute Uninstall Script
# Can be run either on the Proxmox Host (deletes LXC) or inside the LXC (deletes Docker containers)
set -euo pipefail

# ANSI Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BOLD='\033[1m'
NC='\033[0m'

confirm_action() {
  local prompt="$1"
  local response
  read -r -p "$prompt [y/N]: " response
  if [[ "$response" =~ ^[Yy]$ ]]; then
    return 0
  else
    return 1
  fi
}

# 1. Check if running on Proxmox VE host
if [ -d "/etc/pve" ]; then
  echo -e "${YELLOW}${BOLD}=== OmniRoute Host Uninstaller ===${NC}"
  
  read -r -p "Enter Container ID (CTID) to uninstall: " CTID
  if [[ ! "$CTID" =~ ^[0-9]+$ ]]; then
    echo -e "${RED}Error: Container ID must be a number.${NC}" >&2
    exit 1
  fi

  if ! pct status "$CTID" >/dev/null 2>&1; then
    echo -e "${RED}Error: LXC container $CTID not found.${NC}" >&2
    exit 1
  fi

  echo -e "${RED}${BOLD}WARNING: This will permanently delete LXC container $CTID and all its data!${NC}"
  if confirm_action "Are you sure you want to destroy container $CTID?"; then
    echo "Stopping container $CTID..."
    pct stop "$CTID" 2>/dev/null || true
    
    echo "Destroying container $CTID..."
    pct destroy "$CTID"
    
    echo -e "${GREEN}✔ LXC container $CTID uninstalled successfully.${NC}"
  else
    echo "Uninstall cancelled."
  fi

# 2. Running inside the LXC container
else
  echo -e "${YELLOW}${BOLD}=== OmniRoute Local Uninstaller ===${NC}"
  APP_DIR="/opt/omniroute"
  
  if [ ! -d "$APP_DIR" ]; then
    echo -e "${RED}Error: OmniRoute installation directory $APP_DIR not found.${NC}" >&2
    exit 1
  fi

  echo -e "${RED}${BOLD}WARNING: This will stop and remove all OmniRoute docker containers, volumes, and configurations!${NC}"
  if confirm_action "Are you sure you want to remove OmniRoute?"; then
    cd "$APP_DIR"
    echo "Stopping and removing docker containers..."
    docker compose down -v || true
    
    echo "Deleting files under $APP_DIR..."
    rm -rf "$APP_DIR"
    
    echo -e "${GREEN}✔ OmniRoute has been uninstalled.${NC}"
    echo "Note: Docker CE and system dependencies were not removed. You can uninstall them via apt-get if desired."
  else
    echo "Uninstall cancelled."
  fi
fi
