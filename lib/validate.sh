#!/usr/bin/env bash

# Validation helper functions for OmniRoute Proxmox Installer

# Ensure script is running as root
validate_root() {
  if [[ $EUID -ne 0 ]]; then
    msg_err "This script must be run as root. Please run with sudo or as root user."
    exit 1
  fi
  msg_ok "Running as root user."
}

# Ensure running on Proxmox VE
validate_pve() {
  if [ ! -d "/etc/pve" ]; then
    msg_err "Proxmox VE directory (/etc/pve) not found. This script must run directly on the PVE host."
    exit 1
  fi
  msg_ok "Proxmox VE host detected."

  # Check PVE version
  if command -v pveversion >/dev/null 2>&1; then
    local pve_ver=$(pveversion | cut -d'/' -f2 | cut -d'-' -f1)
    msg_info "PVE Version: $pve_ver"
    local major_ver=$(echo "$pve_ver" | cut -d'.' -f1)
    if (( major_ver < 9 )); then
      msg_warn "This script is optimized for PVE 9+. You are running PVE $major_ver. Proceed at your own risk."
    fi
  else
    msg_warn "Could not determine PVE version via pveversion command."
  fi
}

# Validate Internet connectivity
validate_internet() {
  msg_info "Checking internet connectivity..."
  if ! ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1 && ! ping -c 1 -W 3 1.1.1.1 >/dev/null 2>&1; then
    msg_err "No internet access detected. Please check your network and DNS configurations."
    exit 1
  fi
  msg_ok "Internet connectivity verified."
}

# Validate System Architecture
validate_arch() {
  local arch=$(uname -m)
  if [[ "$arch" != "x86_64" && "$arch" != "aarch64" ]]; then
    msg_err "Unsupported CPU architecture: $arch. Only x86_64 and aarch64 are supported."
    exit 1
  fi
  msg_ok "CPU Architecture: $arch"
}

# Perform all host validations
run_host_validations() {
  msg_status "Running environment validations..."
  validate_root
  validate_pve
  validate_arch
  validate_internet
  msg_ok "All environment validations passed."
}
