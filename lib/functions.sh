#!/usr/bin/env bash

# Common Helper Functions for OmniRoute Proxmox Installer

# Log file path
LOG_FILE="/var/log/omniroute_install.log"

# Initialize logging
init_logging() {
  # Create log file or empty it
  touch "$LOG_FILE"
  chmod 600 "$LOG_FILE"
  echo "--- OmniRoute LXC Installation Log Started: $(date) ---" > "$LOG_FILE"
  msg_info "All logs are saved to $LOG_FILE"
}

# Log message to file
log_to_file() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Generate cryptographically secure base64 secret
generate_secret_base64() {
  local length=${1:-48}
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -base64 "$length" | tr -d '\n\r'
  else
    tr -dc 'A-Za-z0-9' < /dev/urandom | head -c "$length"
  fi
}

# Generate cryptographically secure hex secret
generate_secret_hex() {
  local bytes=${1:-32}
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex "$bytes" | tr -d '\n\r'
  else
    tr -dc 'a-f0-9' < /dev/urandom | head -c "$((bytes * 2))"
  fi
}

# Generate secure random initial password
generate_password() {
  local length=${1:-16}
  # Exclude potentially problematic characters in env files like quotes and backslashes
  tr -dc 'A-Za-z0-9!#%^*' < /dev/urandom | head -c "$length"
}

# Cleanup on exit trap
cleanup() {
  local exit_code=$?
  if [ -d "${TEMP_DIR:-}" ]; then
    rm -rf "$TEMP_DIR"
  fi
  if [ $exit_code -ne 0 ]; then
    echo -e "\n${RED}✖ Installation failed. Check logs at $LOG_FILE for details.${NC}"
  fi
  exit $exit_code
}
