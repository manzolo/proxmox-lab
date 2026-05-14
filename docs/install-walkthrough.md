# Proxmox Lab — Unattended install and cluster bootstrap (step by step)

> Tested with **Proxmox VE 9.1-1** on a Linux host with KVM. Different versions may
> require updating `PROXMOX_ISO_VERSION` and the profiles under `profiles/`.

> **Fast path**: `make wizard` (or `make wizard WIZARD_LANG=it`) runs every step of this
> guide interactively with a confirmation pause at each phase. This manual walkthrough is
> useful for understanding the details or running steps individually.

This guide starts from scratch and produces 3 Proxmox nodes with:
- root on ZFS mirror (`sda` + `sdb`)
- VM storage pool on ZFS mirror (`sdc` + `sdd`)
- 3-node cluster over TAP/bridge networking

## Host prerequisites

```bash
# QEMU and disk tools
sudo apt-get install -y qemu-system-x86 qemu-utils

# Interactive TUI (optional)
sudo apt-get install -y dialog

# Docker — only needed if proxmox-auto-install-assistant is not installed locally
# (the CLI uses it automatically as a fallback)
sudo apt-get install -y docker.io

# TAP/bridge networking
sudo apt-get install -y iproute2
```

## 1. Initial configuration

```bash
cp config.env.example config.env
```

Edit at least these values in `config.env`:

| Variable | Recommended value | Notes |
|---|---|---|
| `AUTO_ROOT_PASSWORD` | secure password | root password for every node |
| `AUTO_DOMAIN` | `lab.local` or real domain | node FQDNs |
| `VM_MEMORY_MB` | `4096` or more | minimum 4 GB per node |
| `VM_ACCEL` | `kvm` | use `tcg,thread=multi` if KVM is unavailable |
| `USE_TAP_NETWORK` | `1` for cluster | see below |
| `BRIDGE_NAME` | e.g. `pvlab-br0` | Linux bridge name |
| `TAP_PREFIX` | e.g. `pvlab-tap` | TAP prefix per node |
| `CLUSTER_NAME` | `pvelab` | Proxmox cluster name |
| `DATA_ZPOOL_NAME` | `vmdata` | data pool name |
| `DATA_ZPOOL_DEVICES` | `sdc sdd` | disks for the second mirror |

```bash
# Create artifact directories and link the config
make init
```

## 2. Download ISO

```bash
# Download the version specified by PROXMOX_ISO_VERSION (default: 9.1-1)
make iso-configured
```

The ISO is saved to `artifacts/iso/proxmox-ve_<version>.iso`.

## 3. Generate per-node unattended ISOs

```bash
# Generate artifacts/autoinstall/pve01-answer.toml (pve02, pve03)
make autoinstall-scaffold

# Validate answer file syntax (requires proxmox-auto-install-assistant or Docker)
make autoinstall-validate

# Embed answer files into the ISO → produces artifacts/iso/pve0{1,2,3}-auto.iso
make autoinstall-prepare
```

> **Note**: `make autoinstall-validate` and `make autoinstall-prepare` automatically detect
> whether `proxmox-auto-install-assistant` is installed. If not, they use Docker (Debian Trixie)
> transparently. You can force Docker with `./bin/proxmox-lab --docker autoinstall prepare-iso ...`.

## 4. Create VM disks

```bash
make create
```

Creates 4 qcow2 disks per node under `artifacts/disks/`:

| Disk | Guest device | Purpose |
|---|---|---|
| `pve0Xa1` + `pve0Xa2` | `sda` + `sdb` | root ZFS mirror (20 GB each) |
| `pve0Xb1` + `pve0Xb2` | `sdc` + `sdd` | VM data ZFS mirror (40 GB each) |

## 5. TAP/bridge networking (required for cluster)

> Skip this step if you only want to test a single-node install with user-mode networking.
> The cluster requires TAP because nodes must reach each other over IP.

For static IPs (recommended — no DHCP server needed), set in `config.env`:

```bash
USE_TAP_NETWORK=1
AUTOINSTALL_PROFILE=zfs-mirror-static
BRIDGE_ADDRESS=192.168.100.1/24
NODE_FIRST_IP=192.168.100.101
NODE_PREFIX_LEN=24
NODE_GATEWAY=192.168.100.1
NODE_DNS=1.1.1.1
```

```bash
sudo make network-up
```

Creates the bridge, TAP interfaces, assigns `BRIDGE_ADDRESS` to the bridge, and automatically
adds NAT/MASQUERADE iptables rules so nodes can reach the internet during the install.

To verify:

```bash
ip addr show manzolo-br0   # should show 192.168.100.1/24
```

NAT rules are removed automatically by `sudo make network-down`. To manage them independently:

```bash
sudo make network-nat-up    # add NAT rules only
sudo make network-nat-down  # remove NAT rules only
```

## 6. Unattended install

```bash
# All VMs in parallel (requires a host with sufficient RAM/I/O)
make install-headless

# One VM at a time — recommended on memory- or I/O-constrained hosts
make install-serial
```

`install-serial` launches each VM, waits for QEMU to exit (the reboot that signals install
completion), then moves to the next. Slower but avoids disk and RAM contention.

Monitor progress via disk size growth:

```bash
watch -n 5 'ls -lh artifacts/disks/*.qcow2'
```

The install is complete when `pve0Xa1` and `pve0Xa2` reach ~2–3 GB.

## 7. Boot the installed nodes

```bash
make boot-headless
```

Nodes boot from disk. Follow the serial output to verify SSH is up:

```bash
make vm-serial                        # serial log of pve01
./bin/proxmox-lab vm serial 2         # serial log of pve02
```

## 8. Bootstrap the cluster

```bash
# Generate artifacts/bootstrap/bootstrap-cluster.sh
make cluster-scaffold
```

The generated script runs over SSH and:

1. **SSH key exchange**: generates an ed25519 key on pve02 and pve03 (if absent), adds their public keys to pve01's `authorized_keys`, and pre-accepts pve01's host fingerprint — required for `pvecm add -use_ssh 1`
2. `pvecm create <CLUSTER_NAME>` on pve01
3. `zpool create vmdata mirror <by-id/scsi-*_b1> <by-id/scsi-*_b2>` + storage registration on every node (uses stable `by-id` paths to avoid SCSI enumeration-order issues)
4. `pvecm add pvelab1.lab.local -use_ssh 1` on pve02 and pve03

Run from the host (requires SSH access to all nodes, typically via the bridge):

```bash
bash artifacts/bootstrap/bootstrap-cluster.sh
```

> **Note**: the bootstrap uses node FQDNs (e.g. `pvelab1.lab.local`). If you don't want to
> add `/etc/hosts` entries, pass IPs directly:
> ```bash
> FIRST_NODE_FQDN=192.168.100.101 bash artifacts/bootstrap/bootstrap-cluster.sh
> ```
> Or add entries to `/etc/hosts` (optional, see [networking.md](networking.md)).

## 9. Verify the cluster

Connect to pve01:

```bash
ssh root@pvelab1.lab.local
pvecm status
zpool list
pvesm status
```

Expected output:

```
Cluster information
-------------------
Name:             pvelab
Config Version:   3
Transport:        knet
Nodes:            3
...
```

## Teardown

```bash
make stop
sudo make network-down   # removes TAP interfaces and NAT rules
make clean-all
```

## Resulting ZFS layout

Each node will have:

```
NAME        SIZE  ALLOC   FREE
rpool      39.5G  4.20G  35.3G    ← root mirror sda+sdb
vmdata     74.5G   100K  74.5G    ← VM pool mirror sdc+sdd
```

The `vmdata` pool is registered in Proxmox storage as a `zfspool` with content
`images,rootdir`, visible in the UI under Datacenter → Storage.
