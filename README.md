# Proxmox Lab

[![CI](https://github.com/manzolo/proxmox-lab/actions/workflows/ci.yml/badge.svg)](https://github.com/manzolo/proxmox-lab/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

<img width="662" height="389" alt="immagine" src="https://github.com/user-attachments/assets/631d0b85-8780-4db0-a5d6-77ddd8beea5c" />


Repeatable QEMU-based tooling to build a 3-node Proxmox VE lab on one host.

Each node gets:
- Proxmox VE installed unattended via per-node answer file
- ZFS root mirror on `sda` + `sdb`
- ZFS VM-storage pool on `sdc` + `sdd`
- Cluster membership via automated bootstrap script

## Prerequisites

| Tool | Purpose |
|---|---|
| `qemu-system-x86_64`, `qemu-img` | Run and manage VMs |
| `bash` 4+ | CLI interpreter |
| `docker` **or** `proxmox-auto-install-assistant` | Build unattended ISOs — Docker is used automatically when the Proxmox tool is not installed |
| `iproute2` | TAP/bridge networking (cluster mode) |
| `dialog` or `whiptail` | Optional — enables the graphical TUI |

KVM acceleration (`VM_ACCEL=kvm`) is strongly recommended. Software emulation (`tcg`) works but is much slower.

```bash
# Debian / Ubuntu
sudo apt-get install -y qemu-system-x86 qemu-utils docker.io iproute2 dialog
```

## Quick Start

### Guided wizard (recommended)

```bash
cp config.env.example config.env   # set AUTO_ROOT_PASSWORD, network settings
make wizard                        # step-by-step guided setup in English
make wizard WIZARD_LANG=it         # stesso wizard in italiano
```

The wizard walks through every phase, shows the command it is about to run, pauses for confirmation, and prints a summary with URLs and credentials at the end.

### Manual step-by-step

```bash
cp config.env.example config.env   # edit AUTO_ROOT_PASSWORD at minimum
make init
make iso-configured
make autoinstall-scaffold
make autoinstall-prepare           # uses Docker automatically if needed
sudo make network-up               # TAP mode; skip for user-mode networking
make create
make install-serial                # one node at a time — safe on any host
make boot-headless
make cluster-scaffold
```

Use `make tui` for an interactive terminal menu.

See [docs/install-walkthrough.md](docs/install-walkthrough.md) for the full step-by-step guide including TAP networking and cluster bootstrap.

## Common Commands

```bash
make help
make status
make wizard                 # guided end-to-end setup (English)
make wizard WIZARD_LANG=it  # same wizard in Italian
make tui                    # interactive terminal menu

make install-serial         # recommended: one node at a time
make install-headless       # all nodes in parallel (faster, needs more RAM/I/O)

make boot-headless
make stop
make vm-serial              # tail serial log of node 1
make vm-inspect             # show pid/log paths for all nodes
make clean-all
```

## Documentation

| Document | Contents |
|---|---|
| [docs/install-walkthrough.md](docs/install-walkthrough.md) | Full install and cluster bootstrap, step by step |
| [docs/configuration.md](docs/configuration.md) | All `config.env` variables with descriptions |
| [docs/networking.md](docs/networking.md) | TAP/bridge setup for cluster networking |
| [docs/zfs-layout.md](docs/zfs-layout.md) | ZFS mirror layout and post-install pool setup |
| [docs/cluster.md](docs/cluster.md) | Cluster formation and Ceph notes |

## CI

GitHub Actions runs on every push:

- shell linting with `shellcheck`
- unattended ISO generation for all 3 nodes (Debian Trixie container, `proxmox-auto-install-assistant`)
- QEMU headless boot smoke test for all 3 nodes in `tcg` mode

## References

- [Proxmox Automated Installation](https://pve.proxmox.com/wiki/Automated_Installation)
- [Proxmox VE downloads](https://www.proxmox.com/en/downloads/proxmox-virtual-environment)
- [Proxmox ISO index](https://download.proxmox.com/iso/)
