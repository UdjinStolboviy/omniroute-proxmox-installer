#!/usr/bin/env bash

# Proxmox VE Storage Helper Module

detect_storages() {
  msg_info "Detecting available Proxmox VE storage pools..."
  
  # Check if pvesm is available
  if ! command -v pvesm >/dev/null 2>&1; then
    msg_err "pvesm command not found. Cannot detect storage."
    exit 1
  fi

  # Find storages supporting LXC rootdirs (container volumes)
  # Output of pvesm status -content rootdir:
  # Name             Type     Status           Total            Used       Available        %
  # local             dir     active       100861312        21817728        73872224      21%
  # local-lvm     lvmthin     active       100861312        21817728        73872224      21%
  
  local storage_list=()
  local storage_details=()
  
  # Read pvesm status, skipping the header line
  while read -r name type status total used avail pct; do
    # Skip headers or empty lines
    if [[ "$name" == "Name" || -z "$name" ]]; then
      continue
    fi
    # Only active storages
    if [[ "$status" == "active" ]]; then
      # Convert size to GB for readability (avail is in KB by default)
      local avail_gb=$(( avail / 1024 / 1024 ))
      storage_list+=("$name")
      storage_details+=("$name ($type) - Avail: ${avail_gb}GB")
    fi
  done < <(pvesm status -content rootdir)

  if [ ${#storage_list[@]} -eq 0 ]; then
    msg_err "No active storage pools with 'rootdir' content type found."
    exit 1
  fi

  if [ ${#storage_list[@]} -eq 1 ]; then
    SELECTED_STORAGE="${storage_list[0]}"
    msg_ok "Automatically selected storage: $SELECTED_STORAGE"
  else
    msg_status "Multiple storage pools detected."
    prompt_choice "Select storage pool for LXC container:" "${storage_details[@]}"
    SELECTED_STORAGE="${storage_list[$CHOICE_INDEX]}"
    msg_ok "Selected storage: $SELECTED_STORAGE"
  fi

  # Determine storage type to see if we need special handling (e.g., zfs, dir, lvmthin)
  STORAGE_TYPE=$(pvesm status -content rootdir | grep -E "^${SELECTED_STORAGE}\s" | awk '{print $2}')
  msg_info "Storage Type: $STORAGE_TYPE"
}
