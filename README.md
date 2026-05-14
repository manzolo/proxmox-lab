# Proxmox Lab

Repository: `https://github.com/manzolo/proxmox-lab`

Small local lab tooling to spin up multiple Proxmox VE installers under QEMU, manage disk artifacts, and optionally prepare TAP-based networking and automated-install media.

## What this repo does
- Creates QCOW2 disk layouts for a configurable number of VMs.
- Boots Proxmox VE installer VMs with either user-mode or TAP networking.
- Keeps runtime artifacts under `artifacts/` instead of polluting the repo root.
- Scaffolds an answer file for Proxmox automated installation.
- Exposes both a CLI and a text UI.

## Layout
- `bin/proxmox-lab`: main CLI and TUI entrypoint.
- `config.env.example`: host-specific configuration template.
- `templates/answer.toml.example`: starter template for unattended install.
- `tap/`: compatibility wrappers for the old TAP workflow.
- `artifacts/`: generated ISO links, disks, logs, pid files, autoinstall files.

## Quick start
```bash
cp config.env.example config.env
make init
make status
make iso-latest
make create
make start
```

To use the interactive text UI:
```bash
make tui
```

## Main commands
```bash
make help
make status
make tui
make iso-configured
make create
make start
make start-headless
make stop
make vm-inspect
make vm-serial
make clean-all
make autoinstall-scaffold
make autoinstall-validate
```

For TAP networking, first set `INTERFACE_NAME` in `config.env`, then run:
```bash
make network-up
./bin/proxmox-lab --set USE_TAP_NETWORK=1 vm start
```

`make network-up` and `make network-down` require root because they modify the host bridge and TAP interfaces.

## Configuration
Copy `config.env.example` to `config.env` and adjust:
- `NUM_VMS`, `VM_MEMORY_MB`, `VM_CORES`
- `DISK_LAYOUT`
- `USE_TAP_NETWORK`, `BRIDGE_NAME`, `INTERFACE_NAME`, `TAP_PREFIX`
- `PROXMOX_ISO_VERSION`
- `ISO_URL_INDEX` and `ISO_URL_FALLBACKS` if you want to pin or override the download endpoints
- `ALLOW_INSECURE_TLS=1` only if your network intercepts TLS or `download.proxmox.com` resolves to a host with the wrong certificate

`iso fetch latest` resolves the current latest Proxmox VE ISO from the official download index. As of May 14, 2026, the official listing shows `proxmox-ve_9.1-1.iso` as the latest release and `proxmox-ve_8.4-1.iso` as the latest 8.x release:
- https://download.proxmox.com/iso/
- https://www.proxmox.com/en/downloads/proxmox-virtual-environment

If the official endpoint presents a certificate mismatch, the tool automatically retries the configured CDN fallback hosts before failing.

## Automated install
The repo includes a scaffold for `answer.toml` and supports `proxmox-auto-install-assistant` if that tool is installed on the host.

Typical flow:
```bash
make autoinstall-scaffold
make autoinstall-validate
./bin/proxmox-lab autoinstall prepare-iso artifacts/iso/current.iso artifacts/autoinstall/answer.toml
```

For host-side smoke testing without a GTK window:
```bash
./bin/proxmox-lab vm start-headless 1
./bin/proxmox-lab vm inspect 1
./bin/proxmox-lab vm serial 1
```

Useful references:
- https://pve.proxmox.com/wiki/Automated_Installation
- https://pve.proxmox.com/pve-docs/pve-installation-plain.html

## Notes
- Existing `*.qcow2` files in the repo root are older artifacts; the current workflow writes new ones under `artifacts/disks/`.
- If `curl` reports a hostname or certificate mismatch for `download.proxmox.com`, fix DNS/proxy/certificate trust first. `ALLOW_INSECURE_TLS=1` exists only as a lab fallback and weakens transport security.
- QEMU launch, TAP bridge setup, ISO download, and automated install preparation depend on host packages and were not fully exercised in CI because this repo has no automated test harness yet.
- GitHub Actions runs shell linting and an autoinstall media verification job in a temporary Debian Trixie container with the official Proxmox `pve-no-subscription` repository.
