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
  
  if prompt_yes_no "Use DHCP for the container network?" "Y"; then
    NET_CONFIG="name=eth0,bridge=$SELECTED_BRIDGE,ip=dhcp,firewall=1"
    GATEWAY_CONFIG=""
    msg_ok "Network configured for DHCP on $SELECTED_BRIDGE"
  else
    local static_ip=""
    local gateway=""
    
    while true; do
      read -r -p "Enter static IP address in CIDR format (e.g. 192.168.1.150/24): " static_ip
      if validate_cidr "$static_ip"; then
        break
      else
        msg_err "Invalid CIDR format. Please use IP/mask syntax (e.g., 192.168.1.150/24)."
      fi
    done
    
    while true; do
      read -r -p "Enter Gateway IP address (e.g. 192.168.1.1): " gateway
      if validate_ip "$gateway"; then
        break
      else
        msg_err "Invalid IP format. Please try again."
      fi
    done

    NET_CONFIG="name=eth0,bridge=$SELECTED_BRIDGE,ip=$static_ip,firewall=1"
    GATEWAY_CONFIG="gw=$gateway"
    msg_ok "Network configured: IP=$static_ip, Gateway=$gateway on $SELECTED_BRIDGE"
  fi
}
