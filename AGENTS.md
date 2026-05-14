# Repository Guidelines

## Project Structure

This repository is a Bash-based tooling project for building a 3-node Proxmox VE lab on QEMU. All logic lives in `bin/proxmox-lab` (a single ~1500-line Bash script). The `Makefile` wraps every subcommand. Generated runtime state (disks, ISOs, logs, pid files, bootstrap scripts) lives under `artifacts/` and is never committed.

- `bin/proxmox-lab` — main CLI and TUI
- `config.env.example` — authoritative reference for all configuration variables
- `profiles/` — TOML templates for autoinstall profiles (`zfs-mirror.toml` is the default)
- `templates/` — base answer file template used when no profile matches
- `tap/` — thin compatibility wrappers that delegate to `bin/proxmox-lab`
- `artifacts/` — runtime-only: disks, ISOs, logs, pid files, bootstrap scripts

## Common Commands

```bash
make lint                   # shellcheck on all shell scripts
make tui                    # interactive TUI (requires dialog or whiptail)
make init                   # create config.env and artifact directories
make iso-configured         # download the ISO pinned in config.env
make autoinstall-scaffold   # render per-node answer files from the active profile
make autoinstall-validate   # validate answer files with proxmox-auto-install-assistant
make autoinstall-prepare    # embed answer files into per-node ISOs
make create                 # create qcow2 disks
sudo make network-up        # create bridge + TAP interfaces (TAP mode only)
make install-headless       # unattended install; QEMU exits when installer reboots
make boot-headless          # boot from disk, daemonized, serial log to artifacts/logs/
make cluster-scaffold       # generate artifacts/bootstrap/bootstrap-cluster.sh
```

Direct CLI usage (bypassing Make):

```bash
./bin/proxmox-lab --config ./config.env <subcommand>
./bin/proxmox-lab --set KEY=VALUE <subcommand>   # per-invocation config override
```

## Coding Style

- Bash with `set -euo pipefail` throughout
- 4-space indentation inside loops and conditionals
- `UPPER_CASE` for all config variables and constants
- Quoted expansions everywhere: `"${VAR}"` not `$VAR`
- New functionality goes into `bin/proxmox-lab`, not into the legacy wrapper scripts

## Linting

Run `shellcheck` before submitting changes:

```bash
shellcheck bin/proxmox-lab create.sh run.sh destroy.sh tap/create.sh tap/run.sh tap/destroy.sh
```

CI runs this automatically on every push and pull request.

## Pull Request Guidelines

- Imperative subject line, scoped to one change: `autoinstall: fix validate path for single-node selector`
- Include commands used for manual verification
- List any host prerequisites (e.g. `proxmox-auto-install-assistant`, `xorriso`, `dialog`)
- Screenshots only when QEMU or TUI behavior visually changed
