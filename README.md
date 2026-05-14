# Proxmox Lab

[![CI](https://github.com/manzolo/proxmox-lab/actions/workflows/ci.yml/badge.svg)](https://github.com/manzolo/proxmox-lab/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Repeatable QEMU-based tooling to build a 3-node Proxmox VE lab on one host.

The project is opinionated on purpose:

- 3 Proxmox nodes
- unattended install media per node
- ZFS root mirror on `sda` + `sdb`
- extra mirrored data pool on `sdc` + `sdd`
- post-install cluster bootstrap

Repository: `https://github.com/manzolo/proxmox-lab`

## Overview

`proxmox-lab` helps with four phases:

1. create the VM disks
2. generate node-specific unattended install ISOs
3. run the installation until the guest exits at first reboot
4. boot the installed nodes and form the cluster

Generated runtime state stays under `artifacts/`.

## Quick Start

```bash
cp config.env.example config.env
make init
make iso-configured
make autoinstall-scaffold
make autoinstall-prepare
make network-up
make create
make install-headless
make boot-headless
make cluster-scaffold
```

Use `make tui` for the interactive terminal UI.

## Repository Layout

- `bin/proxmox-lab`: main CLI and TUI
- `config.env.example`: host-side defaults
- `profiles/zfs-mirror.toml`: default unattended install profile
- `templates/`: answer file templates
- `tap/`: compatibility wrappers for TAP networking
- `artifacts/`: disks, ISOs, logs, pid files, bootstrap scripts
- `.github/workflows/ci.yml`: linting and unattended-install verification

## Installation Flow

Generate answer files and per-node media:

```bash
make autoinstall-scaffold
make autoinstall-validate
make autoinstall-prepare
```

This creates:

- `artifacts/autoinstall/pve01-answer.toml`
- `artifacts/autoinstall/pve02-answer.toml`
- `artifacts/autoinstall/pve03-answer.toml`
- `artifacts/iso/pve01-auto.iso`
- `artifacts/iso/pve02-auto.iso`
- `artifacts/iso/pve03-auto.iso`

Run the installation phase:

```bash
make install-headless
```

That mode:

- boots once from the unattended ISO
- uses `-no-reboot`
- exits automatically when the guest finishes installation and tries to reboot

Then boot the installed systems from disk:

```bash
make boot-headless
```

## Networking

For a real cluster run, prefer TAP/bridge mode. QEMU `user networking` is fine for single-node smoke tests, but it is the wrong model for cluster formation.

Typical flow:

```bash
make network-up
make install-headless
make boot-headless
```

With TAP enabled, the nodes can get addresses on the bridge and become reachable for:

- SSH bootstrap
- `pvecm create`
- `pvecm add`
- later Ceph experiments

## ZFS Mirror Layout

The default unattended profile installs Proxmox root on a ZFS mirror using the first two disks:

```toml
[disk-setup]
filesystem = "zfs"
zfs.raid = "raid1"
disk-list = ["sda", "sdb"]
```

The second mirror is intentionally left for post-install guest storage:

- `sda` + `sdb`: Proxmox root pool
- `sdc` + `sdd`: `vmdata` pool for VMs and LXCs

Equivalent shell commands on a Proxmox or Debian system:

```bash
zpool create -f vmdata mirror /dev/sdc /dev/sdd
pvesm add zfspool vmdata -pool vmdata -content images,rootdir
```

Adjust device names if your guest enumerates disks differently.

## Cluster Join

The unattended install only lays down the nodes. Cluster creation is a second phase.

Generate the helper:

```bash
make cluster-scaffold
```

The resulting script is `artifacts/bootstrap/bootstrap-cluster.sh`.

The underlying Proxmox steps are the standard ones:

```bash
# node 1
pvecm create pvelab

# node 2
pvecm add pvelab1.lab.local -use_ssh 1

# node 3
pvecm add pvelab1.lab.local -use_ssh 1
```

The generated helper also creates the `vmdata` ZFS pool on every node and registers it in Proxmox storage.

## Ceph Notes

Ceph is not configured by this project yet, but the lab is a reasonable base for it once the TAP-backed cluster is stable.

Before adding Ceph, make sure you already have:

- reliable node-to-node networking
- working SSH reachability
- predictable node names
- disks reserved for Ceph, not reused by root or `vmdata`

Treat Ceph as a separate phase after cluster bootstrap, not as part of the first unattended install pass.

## Configuration

Copy `config.env.example` to `config.env` and tune at least:

- `NUM_VMS`, `VM_MEMORY_MB`, `VM_CORES`
- `VM_ACCEL`, `VM_CPU`
- `DISK_LAYOUT`
- `PROXMOX_ISO_VERSION`
- `AUTO_ROOT_PASSWORD`, `AUTO_MAILTO`, `AUTO_DOMAIN`
- `CLUSTER_NAME`
- `DATA_ZPOOL_NAME`, `DATA_ZPOOL_DEVICES`, `DATA_STORAGE_ID`

For TAP mode also set:

- `USE_TAP_NETWORK=1`
- `BRIDGE_NAME`
- `INTERFACE_NAME` if you want to enslave a physical NIC
- `TAP_PREFIX`

`ALLOW_INSECURE_TLS=1` exists only as a fallback for broken TLS interception or hostname mismatch while downloading ISOs.

## Common Commands

```bash
make help
make status
make create
make install-headless
make boot
make boot-headless
make stop
make vm-inspect
make vm-serial
make clean-all
```

## CI

GitHub Actions currently checks:

- shell linting with `shellcheck`
- unattended media generation for all 3 nodes
- QEMU headless boot smoke in CI-friendly `tcg` mode

## References

- Proxmox Automated Installation: `https://pve.proxmox.com/wiki/Automated_Installation`
- Proxmox VE downloads: `https://www.proxmox.com/en/downloads/proxmox-virtual-environment`
- Proxmox ISO index: `https://download.proxmox.com/iso/`
