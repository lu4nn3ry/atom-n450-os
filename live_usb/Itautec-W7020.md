# Itautec W7020 - Documentation

## Overview

The **Itautec W7020** is a Brazilian-made netbook (approximately 2010-era) based on the Intel Atom N450 processor (codename "Bonnell"/"Diamondville"). This device was commonly used in educational programs and as a low-cost computing solution in Brazil.

The repository contains scripts and configuration to build a minimal Alpine Linux live USB environment specifically for this hardware.

## Hardware Specifications

- **CPU**: Intel Atom N450 (1 core, 2 threads via Hyper-Threading)
- **Architecture**: x86-32 with EM64T support
- **Chipset**: Intel NM10 Express
- **Graphics**: Intel GMA 3150 integrated
- **Memory**: DDR2/DDR3 (typically 1GB-2GB)
- **Storage**: typically 8GB-16GB eMMC or SSD
- **Network**: Integrated Ethernet (Realtek RTL8101/8111) and WiFi
- **Display**: 1024x600 resolution typical of netbooks
- **Ports**: USB 2.0, VGA, Audio jacks, Card reader

## Repository Structure

```
live_usb/
├── build_apkovl.sh          # Build script for Alpine apkovl overlay
├── itautec-w7020.apkovl.tar.gz  # Pre-built overlay archive
└── remote_control.ps1       # PowerShell remote diagnostic tool
```

## Scripts Documentation

### 1. `build_apkovl.sh`

A bash script that builds an Alpine Linux `apkovl` (overlay) tarball for the Itautec W7020. This creates a customized Alpine Linux image with:

**Configuration performed:**
- **Hostname**: `itautec-w7020`
- **Root password**: `atom` (configurable via `ROOT_PASS` env var)
- **SSH**: Enabled with root login on port 22
- **WiFi**: WPA supplicant configuration (country BR)
- **Network**: DHCP for both eth0 (wired) and wlan0 (wireless)
- **Beacon script**: Broadcasts system status (IP, CPU, RAM, uptime) to remote server
- **Packages**: alpine-base, openssh, wpa_supplicant, wireless-tools, pciutils, usbutils, kexec-tools

**Output**: `itautec-w7020.apkovl.tar.gz` containing the `etc/` directory structure

**Key environment variables (from `.env` file):**
- `WIFI_SSID` - WiFi network name (default: WIFI_NETWORK)
- `WIFI_PSK` - WiFi password (default: WIFI_PASSWORD)
- `ROOT_PASS` - Root password (default: atom)
- `TARGET_HOST_IP` - Target IP for beacon (default: 192.168.0.16)
- `TARGET_HOST_PORT` - Target port for beacon (default: 9090)

### 2. `remote_control.ps1`

A PowerShell remote CLI and diagnostic tool for the Itautec W7020:

**Features:**
- **Automatic discovery**: Scans subnet 192.168.0.0/24 for active hosts
- **SSH detection**: Checks port 22 to identify potential Itautec W7020 units
- **Command execution**: Connects via SSH and runs specified commands
- **Default credentials**: Uses root/atom (configurable via .env)

**Usage:**
```powershell
# Auto-discover and connect
.\remote_control.ps1

# Specify target IP
.\remote_control.ps1 -TargetIP 192.168.0.15

# Run custom commands
.\remote_control.ps1 -TargetIP 192.168.0.15 -Command "uname -a; df -h"
```

**Default command**: `lscpu; ip a; lspci` (displays CPU info, network interfaces, and PCI devices)

## Building the Live USB

1. Ensure `.env` file exists with desired configuration
2. Run the build script:
   ```bash
   bash build_apkovl.sh
   ```
3. The script generates `itautec-w7020.apkovl.tar.gz` in the live_usb directory
4. Flash this overlay onto an Alpine Linux USB stick

## Post-Installation

After booting the live USB:

1. **SSH access**: `ssh root@<IP_ADDRESS>` (password: `atom`)
2. **Network configuration**: Automatically configured (DHCP)
3. **WiFi**: If wlan0 is present, wpa_supplicant connects using configured SSID/PSK
4. **System beacon**: On first boot, sends system info to remote server

## Customization

- Modify `.env` file to change defaults
- Edit `build_apkovl.sh` to add/remove packages
- Customize the beacon script in `/etc/local.d/beacon.start`
- Adjust WiFi settings in `/etc/wpa_supplicant/wpa_supplicant.conf`

## Related Projects

This work is closely related to the Intel Atom N450 operating system development in this repository, specifically:
- The `TODO.html` roadmap for OS development
- Kernel boot code in `src/boot/boot.asm`
- Hardware drivers for the Intel NM10 chipset