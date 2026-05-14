# Configuration Reference

All settings live in `config.env` (copy from `config.env.example`). The file is sourced as plain Bash, so variable syntax rules apply. Any value can also be overridden per-invocation with `--set KEY=VALUE`.

## VM resources

| Variable | Default | Description |
|---|---|---|
| `NUM_VMS` | `3` | Number of VMs to manage |
| `VM_PREFIX` | `pve0` | Prefix for VM names (`pve01`, `pve02`, …) |
| `VM_MEMORY_MB` | `4096` | RAM per VM in MB |
| `VM_CORES` | `2` | vCPU cores per VM |
| `VM_MACHINE` | `pc-q35-7.0` | QEMU machine type |
| `VM_ACCEL` | `kvm` | QEMU accelerator — use `tcg,thread=multi` without KVM |
| `VM_CPU` | `host,migratable=on` | CPU model |
| `VM_DISPLAY` | `gtk` | Display for graphical boot (`gtk`, `sdl`, `none`) |
| `VM_NET_DEVICE` | `virtio-net-pci` | NIC model |

## Disk layout

| Variable | Default | Description |
|---|---|---|
| `DISK_LAYOUT` | `a1:20G a2:20G b1:40G b2:40G` | Space-separated `suffix:size` pairs per VM. `a1`+`a2` become `sda`+`sdb` (root mirror); `b1`+`b2` become `sdc`+`sdd` (VM pool mirror) |

## Networking

| Variable | Default | Description |
|---|---|---|
| `USE_TAP_NETWORK` | `0` | Set to `1` to use TAP/bridge instead of QEMU user networking |
| `BRIDGE_NAME` | `pvlab-br0` | Linux bridge name |
| `INTERFACE_NAME` | _(empty)_ | Physical NIC to enslave to the bridge (optional) |
| `TAP_PREFIX` | `pvlab-tap` | TAP interface prefix (`pvlab-tap1`, `pvlab-tap2`, …) |
| `TAP_USER` | current user | Owner of the TAP interfaces |
| `DHCP_ON_BRIDGE` | `0` | Run `dhclient` on the bridge after creation |

## ISO download

| Variable | Default | Description |
|---|---|---|
| `PROXMOX_ISO_VERSION` | `9.1-1` | Version string used for `make iso-configured` |
| `ISO_URL_INDEX` | download.proxmox.com | Primary ISO index URL |
| `ISO_URL_FALLBACKS` | CDN mirrors | Space-separated fallback URLs |
| `ALLOW_INSECURE_TLS` | `0` | Set to `1` to skip TLS verification (`-k` in curl) — only for broken corporate proxies |

## Unattended install

| Variable | Default | Description |
|---|---|---|
| `AUTO_HOSTNAME_PREFIX` | `pvelab` | Hostname prefix — nodes get `pvelab1`, `pvelab2`, … |
| `AUTO_DOMAIN` | `lab.local` | DNS domain — FQDN is `pvelabN.lab.local` |
| `AUTO_ROOT_PASSWORD` | `CHANGEME` | Root password baked into each node's answer file |
| `AUTO_MAILTO` | `root@localhost` | Alert email in the Proxmox config |
| `AUTOINSTALL_PROFILE` | `zfs-mirror` | Profile filename (without `.toml`) under `profiles/` |

## Cluster and storage

| Variable | Default | Description |
|---|---|---|
| `CLUSTER_NAME` | `pvelab` | Proxmox cluster name |
| `DATA_ZPOOL_NAME` | `vmdata` | Name for the second ZFS pool |
| `DATA_ZPOOL_DEVICES` | `sdc sdd` | Block devices for the VM-storage mirror |
| `DATA_STORAGE_ID` | `vmdata` | Proxmox storage ID |
| `DATA_STORAGE_CONTENT` | `images,rootdir` | Proxmox storage content types |

## Docker fallback

| Variable | Default | Description |
|---|---|---|
| `DOCKER_AUTOINSTALL_IMAGE` | `debian:trixie` | Container image used when `proxmox-auto-install-assistant` is not installed locally |
