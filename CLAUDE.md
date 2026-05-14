# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this project is

QEMU-based tooling to build a repeatable 3-node Proxmox VE lab on a single host. The project covers four phases: create VM disks, generate per-node unattended install ISOs, run unattended installs, and boot+cluster the nodes.

## Commands

```bash
# Lint shell scripts (requires shellcheck)
make lint
# or directly:
shellcheck bin/proxmox-lab create.sh run.sh destroy.sh tap/create.sh tap/run.sh tap/destroy.sh

# Interactive TUI (requires dialog or whiptail)
make tui

# Full first-run sequence
cp config.env.example config.env   # edit at minimum AUTO_ROOT_PASSWORD and network settings
make init
make iso-configured
make autoinstall-scaffold
make autoinstall-validate          # requires proxmox-auto-install-assistant
make autoinstall-prepare
sudo make network-up               # TAP mode; skip for user-mode networking
make create
make install-headless
make boot-headless
make cluster-scaffold              # generates artifacts/bootstrap/bootstrap-cluster.sh
```

There is no build step and no test suite. The CI lints with `shellcheck` and verifies unattended ISO generation inside a Debian Trixie Docker container (because `proxmox-auto-install-assistant` is only available from the Proxmox apt repo).

For CI-like smoke testing locally, override `VM_ACCEL=tcg,thread=multi` and `VM_CPU=max` since KVM is unavailable in most CI environments.

## Architecture

The entire project is driven by a single script, `bin/proxmox-lab`, which is ~1500 lines of Bash with `set -euo pipefail`. All Make targets call through to it with `./bin/proxmox-lab --config $(CONFIG) <subcommand>`.

**Global options** (must come before the subcommand):
- `--config PATH` — load a different config file (default: `config.env`)
- `--set KEY=VALUE` — override any config variable for this invocation only

**Subcommand groups**: `init`, `status`, `iso`, `network`, `vm`, `clean`, `autoinstall`, `cluster`, `tui`, `menu`

### Configuration

`config.env` is sourced as plain Bash. `config.env.example` is the authoritative reference. Key variables:

| Variable | Default | Purpose |
|---|---|---|
| `NUM_VMS` | 3 | How many VMs to manage |
| `VM_PREFIX` | `pve0` | VM name prefix (VMs are `pve01`, `pve02`, `pve03`) |
| `DISK_LAYOUT` | `a1:20G a2:20G b1:40G b2:40G` | Space-separated `suffix:size` pairs per VM |
| `VM_ACCEL` | `kvm` | QEMU accelerator; use `tcg,thread=multi` without KVM |
| `USE_TAP_NETWORK` | `0` | `1` for bridge/TAP (required for cluster formation) |
| `PROXMOX_ISO_VERSION` | `9.1-1` | Version string used for ISO filename and download |
| `AUTOINSTALL_PROFILE` | `zfs-mirror` | Filename (without `.toml`) under `profiles/` |
| `AUTO_ROOT_PASSWORD` | `CHANGEME` | Root password baked into generated answer files |
| `CLUSTER_NAME` | `pvelab` | Proxmox cluster name for the bootstrap script |
| `DATA_ZPOOL_NAME` | `vmdata` | Second ZFS pool (sdc+sdd) for VM storage |

### Directory layout at runtime

Everything generated goes under `artifacts/` — never commit these:
- `artifacts/disks/` — qcow2 files named `pve0{N}{suffix}.qcow2`
- `artifacts/iso/` — downloaded ISO, `current.iso` symlink, per-node `pve0{N}-auto.iso`
- `artifacts/autoinstall/` — per-node `pve0{N}-answer.toml` files
- `artifacts/logs/` — `pve0{N}.log` and `pve0{N}-serial.log` for headless VMs
- `artifacts/run/` — `pve0{N}.pid` and `pve0{N}.mon` (QEMU monitor socket)
- `artifacts/bootstrap/` — generated `bootstrap-cluster.sh`

Source directories:
- `profiles/` — TOML templates for autoinstall profiles; `zfs-mirror.toml` is the default
- `templates/` — `answer.toml.example` used when no matching profile exists

### VM naming and addressing

- VM names: `pve0{N}` (QEMU `-name` flag)
- Node hostnames: `${AUTO_HOSTNAME_PREFIX}{N}` (default: `pvelab1`, `pvelab2`, `pvelab3`)
- FQDNs: `pvelab{N}.lab.local`
- MAC addresses: deterministically `52:54:00:ac:11:{N:02x}`

### Autoinstall ISO flow

`autoinstall scaffold` renders `profiles/zfs-mirror.toml` (or `templates/answer.toml.example`) as a template, substituting `{{FQDN}}`, `{{ROOT_PASSWORD}}`, and `{{MAILTO}}` for each node. `autoinstall prepare-iso` calls `proxmox-auto-install-assistant prepare-iso` once per node, embedding the answer file in a copy of the base ISO.

### Headless install vs. headless boot

- **install-headless**: boots from CD with `-no-reboot`; QEMU exits when the installer reboots, leaving a fully installed disk
- **boot-headless**: boots from disk with `-no-shutdown`; daemonizes via `-daemonize -pidfile`; serial output goes to `artifacts/logs/pve0{N}-serial.log`

### TUI

`tui` detects `dialog`/`whiptail` and uses `dialog_menu_loop` if available, falling back to `tui_basic` (plain `read`). Both call the same underlying functions.

### TAP networking

`network up`/`network down` require root and create/destroy a Linux bridge (`BRIDGE_NAME`) and one TAP interface per VM (`${TAP_PREFIX}{N}`). An optional physical NIC (`INTERFACE_NAME`) can be enslaved to the bridge. Cluster formation requires TAP mode so nodes can reach each other over the bridge.

### Legacy scripts

`create.sh`, `run.sh`, `destroy.sh`, and the `tap/` variants are legacy wrappers kept for compatibility. New development goes into `bin/proxmox-lab`.
