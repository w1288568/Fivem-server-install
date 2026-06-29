> [中文](README.md) | English

# FiveM Server Install

Three scripts to deploy a FiveM server on different platforms:

| File | Platform | Architecture | Notes |
|------|----------|-------------|-------|
| `FiveM-server-install-Linux-ARM.sh` | Ubuntu 20.04/22.04/24.04 | aarch64 | Via FEX-Emu (x86 emulation) |
| `FiveM-server-install-Linux-x86.sh` | Ubuntu / Debian / CentOS / Rocky / Alma / Fedora / Arch | x86_64 | Native Linux |
| `FiveM-server-install-Windows.ps1` | Windows Server 2016+ / Win10+ | AMD64 | PowerShell 5.1+ |

## Features

- **10-option interactive menu**: install, start, status/logs, edit config, firewall check, update core, uninstall, txAdmin setup
- **txAdmin support**: MariaDB/MySQL database installation, port 40120, web panel access
- **Update with rollback**: core update backs up old version, restores on failure
- **Firewall management**: detect and add missing rules for ports 30120 (game) and 40120 (txAdmin)
- **Cross-distro support** (Linux x86): auto-detects package manager and firewall tool

## Usage

```bash
# Linux
chmod +x FiveM-server-install-Linux-x86.sh
./FiveM-server-install-Linux-x86.sh

# Windows (run as Administrator)
.\FiveM-server-install-Windows.ps1
```

## Requirements

- A [Cfx.re License Key](https://keymaster.fivem.net/)
- Public IP with ports 30120 (TCP+UDP) accessible
- GTA V Legacy game files (Enhanced Edition not supported)

## Reference

- [Cfx.re Forum: Deploying a FiveM server in Ubuntu on aarch64/ARM64 machine](https://forum.cfx.re/t/deploying-a-fivem-server-in-ubuntu-on-aarch64-arm64-machine/5185384)
