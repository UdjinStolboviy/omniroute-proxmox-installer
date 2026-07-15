#!/usr/bin/env bash

# ANSI Color Codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Message Helpers
msg_info() {
  echo -e "${BLUE}ℹ${NC} $1"
}

msg_ok() {
  echo -e "${GREEN}✔${NC} $1"
}

msg_warn() {
  echo -e "${YELLOW}⚠${NC} $1"
}

msg_err() {
  echo -e "${RED}✖${NC} $1"
}

msg_status() {
  echo -e "${MAGENTA}➜${NC} $1"
}

# Header Banner
show_banner() {
  clear
  echo -e "${CYAN}${BOLD}"
  echo '   ____                 _ ____               _       '
  echo '  / __ \____ ___  ____ (_) __ \____  __  ___/ /____  '
  echo ' / / / / __ `__ \/ __  / / /_/ / __ \/ / / / __/ _ \ '
  echo '/ /_/ / / / / / / / / / / _, _/ /_/ / /_/ / /_/  __/ '
  echo '\____/_/ /_/ /_/_/ /_/_/_/ |_|\____/\__,_/\__/\___/  '
  echo -e "         Proxmox VE Helper Installer${NC}"
  echo -e "====================================================="
  echo -e "  This script will setup OmniRoute inside an LXC"
  echo -e "=====================================================\n"
}

# Yes/No Prompt Helper (Default: Yes)
prompt_yes_no() {
  local prompt="$1"
  local default="${2:-Y}"
  local response

  if [[ "$default" =~ ^[Yy]$ ]]; then
    prompt="$prompt [Y/n]: "
  else
    prompt="$prompt [y/N]: "
  fi

  read -r -p "$prompt" response
  response="${response:-$default}"

  if [[ "$response" =~ ^[Yy]$ ]]; then
    return 0
  else
    return 1
  fi
}

# Choice Prompt Helper
# Arguments: prompt_string, options_array...
# Returns selected index in global variable CHOICE_INDEX
prompt_choice() {
  local prompt="$1"
  shift
  local options=("$@")
  local choice

  echo -e "\n${BOLD}$prompt${NC}"
  for i in "${!options[@]}"; do
    echo -e "  $((i+1))) ${options[$i]}"
  done

  while true; do
    read -r -p "Enter option [1-${#options[@]}]: " choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#options[@]} )); then
      CHOICE_INDEX=$((choice - 1))
      break
    else
      echo -e "${RED}Invalid selection. Please try again.${NC}"
    fi
  done
}
