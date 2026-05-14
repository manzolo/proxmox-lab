# Repository Guidelines

## Project Structure & Module Organization
This repository is a small QEMU/Proxmox lab workspace driven by Bash scripts. Top-level scripts manage VM disks and boot flow: `create.sh`, `run.sh`, and `destroy.sh`. The `tap/` directory contains the bridge/TAP-enabled variants of the same workflow. Generated VM disks such as `pve01a1.qcow2` are runtime artifacts, not source files, and should generally stay untracked. `qcowdischi.txt` is reference data only.

## Build, Test, and Development Commands
There is no build system; work is done through shell entrypoints.

- `bash create.sh`: create the QCOW2 disks for three VMs.
- `bash run.sh`: boot the VMs with QEMU using the local `proxmox-ve_8.1-2.iso`.
- `bash destroy.sh`: remove generated VM disks.
- `sudo bash tap/create.sh`: create bridge/TAP networking and the VM disks.
- `sudo bash tap/run.sh`: start the TAP-backed VMs.
- `sudo bash tap/destroy.sh`: tear down bridge/TAP networking and remove disks.

Run `shellcheck *.sh tap/*.sh` before submitting changes if `shellcheck` is available.

## Coding Style & Naming Conventions
Use Bash with 4-space indentation inside loops and conditionals. Keep variable names uppercase for constants and shared settings, for example `NUM_VMS`, `VM_PREFIX`, and `TAP_PREFIX`. Prefer quoted expansions like `"$BRIDGE_NAME"` and keep filenames aligned with the existing action-oriented pattern: `create.sh`, `run.sh`, `destroy.sh`.

## Testing Guidelines
There is no automated test suite yet. Validate changes by running the relevant script in a controlled environment and confirming the expected side effects:

- disk files are created or removed correctly
- QEMU starts with the intended drives and NICs
- TAP scripts bring `manzolo-br0` and `manzolo-tap*` up and back down cleanly

Document manual verification steps in the PR when changing networking or storage behavior.

## Commit & Pull Request Guidelines
Current history uses very short subjects (`Init`), but new commits should be imperative and specific, for example `tap: fix bridge teardown loop`. Keep commits scoped to one change. PRs should include a short summary, the commands used for manual validation, any required host prerequisites such as `bridge-utils`, and screenshots only when GUI/QEMU behavior materially changed.

## Security & Configuration Tips
The TAP scripts require root and modify host networking on `eno2`. Review interface names, bridge names, and ISO paths before running them on a non-lab machine.
