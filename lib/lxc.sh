#!/usr/bin/env bash

# Proxmox VE LXC Lifecycle Helper Module

# Find the next available CTID
find_next_ctid() {
  local next_id
  if command -v pvesh >/dev/null 2>&1; then
    next_id=$(pvesh get /cluster/nextid 2>/dev/null | clean_quotes)
  fi
  # Fallback manual detection if pvesh fails
  if [[ ! "$next_id" =~ ^[0-9]+$ ]]; then
    next_id=100
    while pct status $next_id >/dev/null 2>&1 || [ -f "/etc/pve/lxc/${next_id}.conf" ]; do
      next_id=$((next_id + 1))
    done
  fi
  SUGGESTED_CTID=$next_id
}

# Clean helper to strip quotes
clean_quotes() {
  tr -d '"' | tr -d "'" | xargs
}

# Detect storage for templates (content type: vztmpl)
detect_template_storage() {
  local template_storages=()
  while read -r name type status total used avail pct; do
    if [[ "$name" == "Name" || -z "$name" ]]; then
      continue
    fi
    if [[ "$status" == "active" ]]; then
      template_storages+=("$name")
    fi
  done < <(pvesm status -content vztmpl)

  if [ ${#template_storages[@]} -eq 0 ]; then
    msg_err "No active storage pools with 'vztmpl' content type found."
    exit 1
  fi
  
  # Default to 'local' if it exists and supports templates, otherwise the first one
  TEMPLATE_STORAGE="${template_storages[0]}"
  for s in "${template_storages[@]}"; do
    if [[ "$s" == "local" ]]; then
      TEMPLATE_STORAGE="local"
      break
    fi
  done
  msg_ok "Selected template storage: $TEMPLATE_STORAGE"
}

# Download Debian template if not present
prepare_lxc_template() {
  detect_template_storage
  
  msg_info "Updating Proxmox template database..."
  pveam update >/dev/null 2>&1 || true

  # We use Debian 13 (trixie) as standard for Docker installations
  local search_pattern="debian-13-standard"
  local latest_debian_tmpl=$(pveam available | grep "$search_pattern" | sort -r | head -n 1 | awk '{print $2}')

  if [ -z "$latest_debian_tmpl" ]; then
    msg_err "Could not find a Debian 13 standard template in PVE database."
    exit 1
  fi

  local template_filename=$(basename "$latest_debian_tmpl")
  
  # PVE templates are stored under /var/lib/vz/template/cache/ or custom storage paths
  # Check if template is already downloaded in selected storage
  local storage_path=$(pvesm path "$TEMPLATE_STORAGE" | cut -d':' -f2 | xargs)
  # For dir type storages, it's storage_path/template/cache
  # But the safest way to verify if it's there is running pveam list
  if pveam list "$TEMPLATE_STORAGE" | grep -q "$template_filename"; then
    msg_ok "Template $template_filename is already downloaded."
  else
    msg_info "Downloading template $template_filename to storage $TEMPLATE_STORAGE..."
    pveam download "$TEMPLATE_STORAGE" "$latest_debian_tmpl"
    msg_ok "Template downloaded successfully."
  fi

  LXC_TEMPLATE="$TEMPLATE_STORAGE:vztmpl/$template_filename"
}

# Prompt user for container settings
prompt_lxc_settings() {
  find_next_ctid
  
  # 1. CTID
  while true; do
    read -r -p "Enter Container ID [$SUGGESTED_CTID]: " CTID
    CTID="${CTID:-$SUGGESTED_CTID}"
    if [[ "$CTID" =~ ^[0-9]+$ ]] && (( CTID >= 100 )); then
      if pct status $CTID >/dev/null 2>&1 || [ -f "/etc/pve/lxc/${CTID}.conf" ]; then
        msg_err "Container ID $CTID is already in use. Please select a different one."
      else
        break
      fi
    else
      msg_err "Container ID must be a number greater than or equal to 100."
    fi
  done

  # 2. Hostname
  read -r -p "Enter Hostname [omniroute]: " HOSTNAME
  HOSTNAME="${HOSTNAME:-omniroute}"

  # 3. CPU Cores
  while true; do
    read -r -p "Enter CPU Cores [2]: " CPU_CORES
    CPU_CORES="${CPU_CORES:-2}"
    if [[ "$CPU_CORES" =~ ^[0-9]+$ ]] && (( CPU_CORES >= 1 )); then
      break
    else
      msg_err "CPU cores must be a positive integer."
    fi
  done

  # 4. RAM Size
  while true; do
    read -r -p "Enter RAM Size in MB [2048]: " RAM_SIZE
    RAM_SIZE="${RAM_SIZE:-2048}"
    if [[ "$RAM_SIZE" =~ ^[0-9]+$ ]] && (( RAM_SIZE >= 512 )); then
      break
    else
      msg_err "RAM size must be a number of at least 512."
    fi
  done

  # 5. Disk Size
  while true; do
    read -r -p "Enter Disk Size in GB [8]: " DISK_SIZE
    DISK_SIZE="${DISK_SIZE:-8}"
    if [[ "$DISK_SIZE" =~ ^[0-9]+$ ]] && (( DISK_SIZE >= 4 )); then
      break
    else
      msg_err "Disk size must be a number of at least 4."
    fi
  done

  # 6. LXC Privilege Type
  # Nesting and keyctl are supported inside unprivileged containers in Proxmox 7+
  UNPRIVILEGED=1
}

# Create and configure the LXC container
create_lxc_container() {
  msg_status "Creating LXC container $CTID ($HOSTNAME)..."
  
  local extra_opts=()
  if [ -n "$GATEWAY_CONFIG" ]; then
    extra_opts+=("-$GATEWAY_CONFIG")
  fi

  # Run pct create
  pct create "$CTID" "$LXC_TEMPLATE" \
    -cores "$CPU_CORES" \
    -memory "$RAM_SIZE" \
    -swap 512 \
    -rootfs "$SELECTED_STORAGE:$DISK_SIZE" \
    -net0 "$NET_CONFIG" "${extra_opts[@]}" \
    -ostype debian \
    -hostname "$HOSTNAME" \
    -unprivileged "$UNPRIVILEGED" \
    -onboot 1 \
    -start 0

  msg_ok "LXC Container $CTID created."

  # Configure Docker features: nesting=1, keyctl=1
  msg_info "Configuring Nesting and Keyctl features for Docker support..."
  pct set "$CTID" -features keyctl=1,nesting=1
  
  # Start LXC container
  msg_info "Starting LXC container $CTID..."
  pct start "$CTID"
  
  # Wait for container to get IP/boot (approx 5-10 seconds)
  msg_info "Waiting for container boot and network initialization..."
  local count=0
  while [ $count -lt 15 ]; do
    if pct exec "$CTID" -- ip addr show dev eth0 | grep -q "inet "; then
      break
    fi
    sleep 1
    count=$((count + 1))
  done

  LXC_IP=$(pct exec "$CTID" -- ip -o -4 addr show dev eth0 | awk '{print $4}' | cut -d'/' -f1)
  msg_ok "Container is running. Internal IP address: $LXC_IP"
}
