#!/usr/bin/env bash

# Proxmox VE Network Helper Module

# Detect available network bridges on PVE host
detect_bridges() {
  local bridges=()
  
  # Scan active interfaces starting with vmbr
  for iface in /sys/class/net/vmbr*; do
    if [ -d "$iface" ]; then
      bridges+=("$(basename "$iface")")
    fi
  done

  # Fallback to vmbr0 if none detected
  if [ ${#bridges[@]} -eq 0 ]; then
    bridges+=("vmbr0")
  fi

  if [ ${#bridges[@]} -eq 1 ]; then
    SELECTED_BRIDGE="${bridges[0]}"
    msg_ok "Automatically selected network bridge: $SELECTED_BRIDGE"
  else
    prompt_choice "Select network bridge:" "${bridges[@]}"
    SELECTED_BRIDGE="${bridges[$CHOICE_INDEX]}"
    msg_ok "Selected network bridge: $SELECTED_BRIDGE"
  fi
}

# Validate IPv4 format
validate_ip() {
  local ip=$1
  local stat=1

  if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    OIFS=$IFS
    IFS='.'
    ip=($ip)
    IFS=$OIFS
    [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
    stat=$?
  fi
  return $stat
}

# Validate CIDR format (IP/subnet, e.g., 192.168.1.100/24)
validate_cidr() {
  local cidr=$1
  if [[ "$cidr" =~ ^([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})/([0-9]{1,2})$ ]]; then
    local ip="${BASH_REMATCH[1]}"
    local mask="${BASH_REMATCH[2]}"
    if validate_ip "$ip" && (( mask >= 8 && mask <= 32 )); then
      return 0
    fi
  fi
  return 1
}

# Configure container network settings (sets global variables: NET_CONFIG, GATEWAY_CONFIG)
configure_network() {
  detect_bridges
  
  # 1. Detect default gateway from host routing table
  local default_gw=""
  default_gw=$(ip route | grep default | awk '{print $3}' | head -n 1 || true)
  if [ -z "$default_gw" ]; then
    # Fallback to bridge dev route
    default_gw=$(ip route show dev "$SELECTED_BRIDGE" | grep -w inet | awk '{print $1}' | cut -d/ -f1 | head -n 1 || true)
  fi
  
  # 2. Detect IP and mask of the bridge interface on host
  local host_ip_cidr=""
  host_ip_cidr=$(ip addr show dev "$SELECTED_BRIDGE" | grep -w inet | awk '{print $2}' | head -n 1 || true)
  
  local ip_prefix=""
  local ip_mask="24"
  local host_last_octet=""
  
  if [ -n "$host_ip_cidr" ]; then
    local host_ip=$(echo "$host_ip_cidr" | cut -d/ -f1)
    ip_mask=$(echo "$host_ip_cidr" | cut -d/ -f2)
    ip_prefix=$(echo "$host_ip" | cut -d. -f1-3)
    host_last_octet=$(echo "$host_ip" | cut -d. -f4)
  else
    # Fallback to standard private subnet range
    ip_prefix="192.168.1"
    ip_mask="24"
    host_last_octet="100"
  fi
  
  # 3. Scan for a free IP address in the detected subnet (starting at .150)
  msg_status "Scanning network for a free IP address..."
  local suggested_ip=""
  local start_scan=150
  
  for ((i=start_scan; i<=250; i++)); do
    # Skip host's own IP and gateway IP
    if [ "$i" -eq "$host_last_octet" ]; then
      continue
    fi
    local test_ip="${ip_prefix}.${i}"
    if [ "$test_ip" = "$default_gw" ]; then
      continue
    fi
    
    # Ping with 1 second timeout. If it fails (no reply), we assume the IP is free.
    if ! ping -c 1 -W 1 "$test_ip" >/dev/null 2>&1; then
      suggested_ip="${test_ip}/${ip_mask}"
      break
    fi
  done
  
  if [ -z "$suggested_ip" ]; then
    # Fallback if no free IP found in the scanned range
    suggested_ip="${ip_prefix}.150/${ip_mask}"
  fi
  
  # 4. Prompt user with defaults
  local static_ip=""
  while true; do
    read -r -p "Enter static IP address in CIDR format [Default: $suggested_ip]: " static_ip
    if [ -z "$static_ip" ]; then
      static_ip="$suggested_ip"
    fi
    if validate_cidr "$static_ip"; then
      break
    else
      msg_err "Invalid CIDR format. Please use IP/mask syntax (e.g., 192.168.1.150/24)."
    fi
  done
  
  local gateway=""
  while true; do
    read -r -p "Enter Gateway IP address [Default: ${default_gw:-192.168.1.1}]: " gateway
    if [ -z "$gateway" ]; then
      gateway="${default_gw:-192.168.1.1}"
    fi
    if validate_ip "$gateway"; then
      break
    else
      msg_err "Invalid IP format. Please try again."
    fi
  done

  NET_CONFIG="name=eth0,bridge=$SELECTED_BRIDGE,ip=$static_ip,firewall=1"
  GATEWAY_CONFIG="gw=$gateway"
  msg_ok "Network configured: IP=$static_ip, Gateway=$gateway on $SELECTED_BRIDGE"
}
