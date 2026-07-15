#!/usr/bin/env bash

# Main entry point for OmniRoute Proxmox VE Helper Installer
set -euo pipefail

# Determine script execution directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd 2>/dev/null || pwd)"
TEMP_DIR=""

# Determine if running locally or remotely
if [ -f "$SCRIPT_DIR/lib/ui.sh" ]; then
  LOCAL_MODE=true
  LIB_DIR="$SCRIPT_DIR/lib"
  CONFIG_DIR="$SCRIPT_DIR/configs"
  SRC_DIR="$SCRIPT_DIR"
else
  LOCAL_MODE=false
  # Create temp directory for remote modules
  TEMP_DIR=$(mktemp -d -t omniroute-installer-XXXXXX)
  LIB_DIR="$TEMP_DIR/lib"
  CONFIG_DIR="$TEMP_DIR/configs"
  SRC_DIR="$TEMP_DIR"
  mkdir -p "$LIB_DIR" "$CONFIG_DIR"

  REPO_URL="https://raw.githubusercontent.com/UdjinStolboviy/omniroute-proxmox-installer/main"
  echo "Downloading installation modules from GitHub..."
  for lib in ui.sh validate.sh storage.sh network.sh lxc.sh docker.sh github.sh functions.sh; do
    curl -fsSL "$REPO_URL/lib/$lib" -o "$LIB_DIR/$lib"
  done
  for conf in docker-compose.yml omniroute.env; do
    curl -fsSL "$REPO_URL/configs/$conf" -o "$CONFIG_DIR/$conf"
  done
  for cmd in update.sh uninstall.sh; do
    curl -fsSL "$REPO_URL/$cmd" -o "$TEMP_DIR/$cmd"
  done
fi

# Source Library Modules
source "$LIB_DIR/ui.sh"
source "$LIB_DIR/validate.sh"
source "$LIB_DIR/storage.sh"
source "$LIB_DIR/network.sh"
source "$LIB_DIR/lxc.sh"
source "$LIB_DIR/github.sh"
source "$LIB_DIR/functions.sh"

# Set up exit hook
trap cleanup EXIT

# 1. Run Host Validations
show_banner
run_host_validations
init_logging

# 2. Check for latest OmniRoute release
get_latest_release

# 3. Interactive Menu Selection
options=("Default Settings (Recommended - Auto configuration)" "Advanced Settings (Custom hardware, storage, and network)")
prompt_choice "Select installation profile:" "${options[@]}"
INSTALL_MODE=$CHOICE_INDEX

if [ "$INSTALL_MODE" -eq 0 ]; then
  # Default installation path
  msg_info "Loading default configuration settings..."
  find_next_ctid
  CTID=$SUGGESTED_CTID
  HOSTNAME="omniroute"
  CPU_CORES=2
  RAM_SIZE=2048
  DISK_SIZE=8
  UNPRIVILEGED=1
  
  # Auto-detect storage pool
  detect_storages # sets SELECTED_STORAGE and STORAGE_TYPE
  
  # Auto-detect network bridge (vmbr0 usually)
  detect_bridges # sets SELECTED_BRIDGE
  NET_CONFIG="name=eth0,bridge=$SELECTED_BRIDGE,ip=dhcp,firewall=1"
  GATEWAY_CONFIG=""
  
  msg_ok "Configured with CTID: $CTID, Hostname: $HOSTNAME, CPU Cores: 2, RAM: 2GB, Disk: 8GB"
else
  # Advanced installation path
  msg_info "Loading advanced interactive setup wizard..."
  prompt_lxc_settings
  detect_storages
  configure_network
fi

# 4. Prepare template and create LXC Container
prepare_lxc_template
create_lxc_container # sets LXC_IP

# 5. Generate secure environment secrets
msg_status "Generating security tokens and environment parameters..."
JWT_SECRET=$(generate_secret_base64 48)
API_KEY_SECRET=$(generate_secret_hex 32)
STORAGE_ENCRYPTION_KEY=$(generate_secret_hex 32)
INITIAL_PASSWORD=$(generate_password 16)

# 6. Copy files to LXC Container
msg_status "Configuring OmniRoute environment files..."
pct exec "$CTID" -- mkdir -p /opt/omniroute

# Read compose file and push it
cat "$CONFIG_DIR/docker-compose.yml" | pct exec "$CTID" -- tee /opt/omniroute/docker-compose.yml >/dev/null

# Format omniroute.env template and push it
LXC_ORIGIN="http://${LXC_IP}:20128"
sed -e "s|__JWT_SECRET__|${JWT_SECRET}|g" \
    -e "s|__API_KEY_SECRET__|${API_KEY_SECRET}|g" \
    -e "s|__STORAGE_ENCRYPTION_KEY__|${STORAGE_ENCRYPTION_KEY}|g" \
    -e "s|__INITIAL_PASSWORD__|${INITIAL_PASSWORD}|g" \
    -e "s|__LXC_ORIGIN__|${LXC_ORIGIN}|g" \
    "$CONFIG_DIR/omniroute.env" | pct exec "$CTID" -- tee /opt/omniroute/omniroute.env >/dev/null
pct exec "$CTID" -- chmod 600 /opt/omniroute/omniroute.env


# 7. Run Docker installation inside container
msg_status "Installing Docker and dependencies inside the container..."
cat "$LIB_DIR/docker.sh" | pct exec "$CTID" -- bash

# 8. Start Docker Compose services inside container
msg_status "Starting OmniRoute via Docker Compose..."
pct exec "$CTID" -- bash -c "cd /opt/omniroute && OMNIROUTE_VERSION=${OMNIROUTE_VERSION} docker compose up -d"

# 9. Install Maintenance Scripts inside the container
msg_info "Installing update and uninstall utility scripts..."
cat "$SRC_DIR/update.sh" | pct exec "$CTID" -- tee /opt/omniroute/update.sh >/dev/null
pct exec "$CTID" -- chmod +x /opt/omniroute/update.sh
cat "$SRC_DIR/uninstall.sh" | pct exec "$CTID" -- tee /opt/omniroute/uninstall.sh >/dev/null
pct exec "$CTID" -- chmod +x /opt/omniroute/uninstall.sh

# Complete Installation
log_to_file "OmniRoute LXC setup completed successfully. CTID: $CTID, IP: $LXC_IP"

echo -e "\n====================================================="
echo -e "      ${GREEN}${BOLD}OmniRoute Installation Completed Successfully!${NC}"
echo -e "====================================================="
echo -e "  Container ID:   ${BOLD}${CTID}${NC}"
echo -e "  IP Address:     ${BOLD}${LXC_IP}${NC}"
echo -e "  Web Dashboard:  ${BLUE}${BOLD}http://${LXC_IP}:20128${NC}"
echo -e "  Initial Admin Passwords/Tokens:"
echo -e "    * Admin Password:      ${YELLOW}${BOLD}${INITIAL_PASSWORD}${NC}"
echo -e "    * DB Encryption Key:   ${CYAN}${STORAGE_ENCRYPTION_KEY}${NC}"
echo -e "====================================================="
echo -e "  To manage the container locally:"
echo -e "    - Update:      pct exec $CTID -- /opt/omniroute/update.sh"
echo -e "    - Uninstall:   pct exec $CTID -- /opt/omniroute/uninstall.sh"
echo -e "=====================================================\n"
