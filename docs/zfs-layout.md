# ZFS Layout

> Tested with **Proxmox VE 9.1-1**. ZFS pool layout is stable across minor versions;
> always verify installer behaviour on major version upgrades.

## Disk assignment

Each VM has 4 virtual disks mapped to SCSI targets in this order:

| qcow2 suffix | Guest device | Pool | Size (default) |
|---|---|---|---|
| `a1` | `sda` | root mirror | 20 GB |
| `a2` | `sdb` | root mirror | 20 GB |
| `b1` | `sdc` | VM pool mirror | 40 GB |
| `b2` | `sdd` | VM pool mirror | 40 GB |

The `DISK_LAYOUT` variable controls sizes: `"a1:20G a2:20G b1:40G b2:40G"`.

## Root pool (rpool)

Created automatically by the Proxmox unattended installer using the profile `profiles/zfs-mirror.toml`:

```toml
[disk-setup]
filesystem = "zfs"
zfs.raid = "raid1"
disk-list = ["sda", "sdb"]
```

Pool name is `rpool` (Proxmox default). Holds the OS datasets (`rpool/ROOT`, `rpool/data`, etc.).

## VM storage pool (vmdata)

Created by the cluster bootstrap script after install:

```bash
zpool create -f vmdata mirror /dev/sdc /dev/sdd
pvesm add zfspool vmdata -pool vmdata -content images,rootdir
```

Controlled by `DATA_ZPOOL_NAME`, `DATA_ZPOOL_DEVICES`, `DATA_STORAGE_ID`, and `DATA_STORAGE_CONTENT` in `config.env`.

`make cluster-scaffold` generates `artifacts/bootstrap/bootstrap-cluster.sh` which runs these commands on every node over SSH.

## Expected state after bootstrap

```
NAME      SIZE  ALLOC   FREE
rpool    39.5G  ~4.2G  ~35G    ← OS mirror on sda+sdb
vmdata   74.5G  ~100K  ~74G    ← VM pool mirror on sdc+sdd
```

In the Proxmox UI: **Datacenter → Storage** should show `vmdata` with type `ZFS` and content `Disk image, Container`.

## Resizing

To change disk sizes before creating VMs, edit `DISK_LAYOUT` in `config.env`:

```bash
DISK_LAYOUT="a1:40G a2:40G b1:100G b2:100G"
```

Then run `make create` (or `make clean && make create` to recreate from scratch).
