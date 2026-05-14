# Proxmox Lab

`proxmox-lab` is a small QEMU-based lab for spinning up repeatable Proxmox VE installer VMs, preparing unattended installation media, and testing host-side install workflows without managing the full setup by hand.

Repository: `https://github.com/manzolo/proxmox-lab`

## What it does

- Creates and manages multi-disk VM layouts for Proxmox VE test nodes.
- Downloads Proxmox VE ISOs with fallback CDN handling when the primary endpoint is misconfigured.
- Builds unattended install media with `proxmox-auto-install-assistant`.
- Starts VMs in GTK or headless mode for smoke testing and serial inspection.
- Keeps all generated state under `artifacts/` instead of cluttering the repo root.

The current unattended install profile is set up for:
- Proxmox VE `9.1-1`
- ZFS root
- RAID-1 mirror on `sda` and `sdb`
- DHCP networking

That profile lives in `profiles/zfs-mirror.toml` and is the default source used by `autoinstall scaffold`.

## Repository layout

- `bin/proxmox-lab`: main CLI and TUI entrypoint
- `config.env.example`: host-side configuration template
- `templates/answer.toml.example`: autoinstall answer template
- `profiles/zfs-mirror.toml`: default unattended install profile
- `tap/`: compatibility wrappers for the TAP networking workflow
- `artifacts/`: generated ISOs, disks, logs, pid files, monitor sockets, autoinstall files
- `.github/workflows/ci.yml`: shell lint and autoinstall media verification

## Quick start

```bash
cp config.env.example config.env
make init
make status
make iso-latest
make create
make start
```

For the interactive terminal UI:

```bash
make tui
```

## Common commands

```bash
make help
make start
make start-headless
make stop
make vm-inspect
make vm-serial
make clean-all
make autoinstall-scaffold
make autoinstall-validate
```

## Unattended install flow

Generate and validate the answer file:

```bash
make autoinstall-scaffold
make autoinstall-validate
```

Prepare an unattended ISO:

```bash
./bin/proxmox-lab autoinstall prepare-iso artifacts/iso/proxmox-ve_9.1-1.iso artifacts/autoinstall/answer.toml
```

Smoke test it headlessly:

```bash
./bin/proxmox-lab vm start-headless 1
./bin/proxmox-lab vm inspect 1
./bin/proxmox-lab vm serial 1
```

## Configuration

Copy `config.env.example` to `config.env` and tune:

- `NUM_VMS`, `VM_MEMORY_MB`, `VM_CORES`
- `DISK_LAYOUT`
- `USE_TAP_NETWORK`, `BRIDGE_NAME`, `INTERFACE_NAME`, `TAP_PREFIX`
- `PROXMOX_ISO_VERSION`
- `ISO_URL_INDEX` and `ISO_URL_FALLBACKS`
- `AUTOINSTALL_PROFILE`

`ALLOW_INSECURE_TLS=1` exists only as a lab fallback for broken TLS interception or hostname mismatch scenarios. Prefer fixing DNS, proxying, or trust configuration first.

## TAP networking

If you want bridge/TAP networking instead of user-mode networking, set `INTERFACE_NAME` in `config.env` and use:

```bash
make network-up
./bin/proxmox-lab --set USE_TAP_NETWORK=1 vm start
```

These commands require root because they modify host networking.

## GitHub Actions

CI currently verifies two things:

- shell linting with `shellcheck`
- unattended media generation in a temporary Debian Trixie container using the official Proxmox `pve-no-subscription` repository

That gives a useful signal that:
- the answer file parses
- the assistant tool installs correctly
- the ISO can be rebuilt for automated installation

## Notes

- The project prefers `artifacts/` for runtime state; legacy root-level QCOW2 files are no longer part of the workflow.
- The current answer template intentionally targets a simple ZFS mirror install profile for VM-based Proxmox lab nodes.
- If `download.proxmox.com` presents a bad certificate for the requested hostname, the tool retries configured fallback CDN hosts automatically.

## References

- Proxmox Automated Installation: `https://pve.proxmox.com/wiki/Automated_Installation`
- Proxmox VE downloads: `https://www.proxmox.com/en/downloads/proxmox-virtual-environment`
- Proxmox ISO index: `https://download.proxmox.com/iso/`
