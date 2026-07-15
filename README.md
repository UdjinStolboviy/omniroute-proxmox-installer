# OmniRoute Proxmox VE Helper Installer

This repository contains a professional, interactive installer for deploying **OmniRoute** on **Proxmox VE (PVE) 9.x+** in the style of the popular *Proxmox VE Helper Scripts* (tteck-level).

The installer fully automates the creation of a Debian 13 LXC container, configures the virtualization features (`nesting=1`, `keyctl=1`), installs Docker CE, and runs OmniRoute alongside a Redis instance for caching and rate-limiting.

---

## ⚡ Features
- **Proxmox VE Helper Scripts Style:** A clean interactive console menu for choosing installation profiles.
- **Two Installation Modes:**
  - *Default Settings (Recommended):* Auto-detects next free Container ID, assigns standard resources (2 vCPUs, 2GB RAM, 8GB Disk), auto-selects storage pool, and configures DHCP.
  - *Advanced Settings:* Customizable CTID, hostname, resource allocations (RAM/CPU/Disk), target storage pool (ZFS, LVM-Thin, Directory, Ceph, etc.), and static IP configuration.
- **Docker CE Integration:** Automates official Docker APT repository setup, installs Docker Engine, CLI, Buildx, and Docker Compose inside the LXC container.
- **Automatic Secrets Generation:** Cryptographically generates unique secrets for `JWT_SECRET`, `API_KEY_SECRET`, `STORAGE_ENCRYPTION_KEY`, and a randomized initial admin password (`INITIAL_PASSWORD`).
- **Strict Security Permissions:** Restricts access to host installer logs (`/var/log/omniroute_install.log`) and the container env file (`/opt/omniroute/omniroute.env`) with secure `600` permissions.
- **Modular Structure:** Modular codebase split into files under `lib/` for easier maintainability.

---

## 📂 Project Structure

```
omniroute-proxmox-installer/
├── install.sh              ← Main installer entrypoint (run on PVE host)
├── update.sh               ← Updates OmniRoute (run inside LXC container)
├── uninstall.sh            ← Uninstaller (deletes LXC on host, deletes services inside LXC)
├── lib/
│   ├── ui.sh               ← UI functions, colors, and prompt choices
│   ├── validate.sh         ← Host environment and PVE compatibility checks
│   ├── storage.sh          ← Storage pool auto-detection and selection
│   ├── network.sh          ← Network bridges, DHCP, and static IP setup
│   ├── lxc.sh              ← LXC container lifecycle and creation
│   ├── docker.sh           ← Docker installation script (runs inside LXC)
│   ├── github.sh           ← OmniRoute release tag fetcher
│   └── functions.sh        ← Shared helpers (secret generators, logging)
└── configs/
    ├── docker-compose.yml  ← OmniRoute and Redis service compositions
    └── omniroute.env       ← Configuration environment template
```

---

## 🚀 Step-by-Step Remote Proxmox VE Execution Guide

You can run the installer on a remote Proxmox server either via a direct HTTPS stream or by cloning the repository.

### Step 1: Connect to Proxmox VE via SSH
Open your terminal and connect to your remote Proxmox host as the `root` user:
```bash
ssh root@YOUR_PROXMOX_IP
```
*(Replace `YOUR_PROXMOX_IP` with the actual IP address of your Proxmox VE server).*

---

### Step 2: Open a Screen/Tmux Session (Highly Recommended)
Network interruptions can abort the installation process halfway. Using `tmux` ensures that the script runs locally on the host even if you disconnect:
```bash
# Install and run tmux
apt-get update && apt-get install -y tmux
tmux
```
*If your SSH session drops, reconnect and run `tmux attach` to resume.*

---

### Step 3: Run the Installer Script
Choose one of the two options below:

#### Option A (One-liner Stream - Recommended):
Run the installer directly from the GitHub repository:
```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/UdjinStolboviy/omniroute-proxmox-installer/main/install.sh)"
```

#### Option B (Local Clone for Customization):
Clone the repository and run the script locally if you wish to inspect or modify configuration templates:
```bash
git clone https://github.com/UdjinStolboviy/omniroute-proxmox-installer.git
cd omniroute-proxmox-installer
chmod +x install.sh
./install.sh
```

---

### Step 4: Interact with the Menu
Once the installer launches, choose your installation mode:
* Select **Default Settings** (type `1` and press `Enter`) for automatic installation.
* Select **Advanced Settings** (type `2` and press `Enter`) to custom configure resources (RAM, CPU, storage, or static IP details).

---

### Step 5: First Login and Dashboard Access
Once finished, the terminal will display the final summary:
- **Web Dashboard:** `http://<LXC_IP>:20128`
- **Initial Password:** Provided in the output summary.
- **DB Encryption Key:** Provided in the output summary.

> [!IMPORTANT]
> **Required Security Action:**
> Log in to the web panel at `http://<LXC_IP>:20128` using the initial password and **immediately change your password** in the admin profile settings.

---

### Step 6: Network Firewall (Optional Security)
Since the container is created with the Proxmox firewall enabled (`firewall=1`), you can restrict traffic to the Dashboard port (`20128`) and API port (`20129`) directly via the Proxmox VE Web UI (Container -> Firewall -> Rules) to limit access to your trusted local subnets.

---

## ⚙️ Post-Install Management

### Updating OmniRoute
To update OmniRoute to the latest stable release, run this command on your Proxmox host:
```bash
pct exec <CTID> -- /opt/omniroute/update.sh
```
*(Replace `<CTID>` with your Container ID, e.g. `100`).*

Alternatively, enter the container's shell and run:
```bash
/opt/omniroute/update.sh
```

### Uninstalling OmniRoute
You can choose to delete either the entire LXC container or only the Docker services:

1. **Delete the entire LXC container (run on Proxmox Host):**
   ```bash
   bash -c "$(curl -fsSL https://raw.githubusercontent.com/UdjinStolboviy/omniroute-proxmox-installer/main/uninstall.sh)"
   ```
   *The script will ask for the CTID and permanently destroy the container and all its stored data.*

2. **Remove only Docker services and files (run inside LXC Container):**
   ```bash
   /opt/omniroute/uninstall.sh
   ```
   *This stops and deletes the Docker containers, networks, volumes, and files under `/opt/omniroute`, leaving the base OS intact.*
