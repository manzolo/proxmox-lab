# Proxmox Lab

`proxmox-lab` is a small QEMU-based lab for spinning up repeatable Proxmox VE installer VMs, preparing unattended installation media, and rehearsing a full 3-node Proxmox cluster build on one host.

Repository: `https://github.com/manzolo/proxmox-lab`

## What it does

- Creates and manages multi-disk VM layouts for Proxmox VE test nodes.
- Downloads Proxmox VE ISOs with fallback CDN handling when the primary endpoint is misconfigured.
- Builds per-node unattended install media with `proxmox-auto-install-assistant`.
- Scaffolds host-side bootstrap scripts for cluster creation and ZFS data-pool setup.
- Starts VMs in GTK or headless mode for smoke testing and serial inspection.
- Keeps all generated state under `artifacts/` instead of cluttering the repo root.

The default unattended profile is set up for:
- Proxmox VE `9.1-1`
- three lab nodes
- ZFS root on a mirror of `sda` and `sdb`
- a second mirror candidate on `sdc` and `sdd` for VM/LXC storage after install
- DHCP networking

That profile lives in `profiles/zfs-mirror.toml` and is the default source used by `autoinstall scaffold`.

## Repository layout

- `bin/proxmox-lab`: main CLI and TUI entrypoint
- `config.env.example`: host-side configuration template
- `templates/answer.toml.example`: autoinstall answer template
- `profiles/zfs-mirror.toml`: default unattended install profile
- `artifacts/bootstrap/`: generated host-side scripts for cluster and storage bootstrap
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
make autoinstall-scaffold
make autoinstall-validate
make autoinstall-prepare
make start-headless
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
make autoinstall-prepare
make cluster-scaffold
```

## Unattended install flow

Generate and validate the per-node answer files:

```bash
make autoinstall-scaffold
make autoinstall-validate
```

Prepare unattended ISOs for all nodes:

```bash
make autoinstall-prepare
```

This creates:

- `artifacts/autoinstall/pve01-answer.toml`
- `artifacts/autoinstall/pve02-answer.toml`
- `artifacts/autoinstall/pve03-answer.toml`
- `artifacts/iso/pve01-auto.iso`
- `artifacts/iso/pve02-auto.iso`
- `artifacts/iso/pve03-auto.iso`

Each VM automatically prefers its own `pve0N-auto.iso` when present.

Smoke test node 1 headlessly:

```bash
./bin/proxmox-lab vm start-headless 1
./bin/proxmox-lab vm inspect 1
./bin/proxmox-lab vm serial 1
```

The launcher uses `boot once=d`, so the installer boots from ISO only on the first boot. After the guest reboots, QEMU should continue from the installed disks instead of looping back into the installer.

## Cluster bootstrap

The unattended install only lays down the nodes. The cluster and extra storage pool are a second phase.

Generate the helper script:

```bash
make cluster-scaffold
```

That produces `artifacts/bootstrap/bootstrap-cluster.sh`, which assumes:

- all 3 nodes finished installation
- the host can reach `root@pvelab1.lab.local`, `root@pvelab2.lab.local`, `root@pvelab3.lab.local`
- SSH authentication is available

The script then:

- creates the Proxmox cluster on node 1
- joins nodes 2 and 3
- creates `vmdata` as a mirror on `sdc` and `sdd` on each node
- registers that pool in Proxmox as storage for `images,rootdir`

## Configuration

Copy `config.env.example` to `config.env` and tune:

- `NUM_VMS`, `VM_MEMORY_MB`, `VM_CORES`
- `DISK_LAYOUT`
- `USE_TAP_NETWORK`, `BRIDGE_NAME`, `INTERFACE_NAME`, `TAP_PREFIX`
- `PROXMOX_ISO_VERSION`
- `ISO_URL_INDEX` and `ISO_URL_FALLBACKS`
- `AUTOINSTALL_PROFILE`
- `AUTO_ROOT_PASSWORD`, `AUTO_MAILTO`
- `CLUSTER_NAME`
- `DATA_ZPOOL_NAME`, `DATA_ZPOOL_DEVICES`, `DATA_STORAGE_ID`

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
