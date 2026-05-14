# Layout ZFS

> Testato con **Proxmox VE 9.1-1**. Il layout dei pool ZFS è stabile tra versioni minori; verificare sempre il comportamento dell'installer su aggiornamenti major.

## Assegnazione dei dischi

Ogni VM ha 4 dischi virtuali mappati su target SCSI in quest'ordine:

| suffisso qcow2 | Dispositivo guest | Pool | Dimensione (default) |
|---|---|---|---|
| `a1` | `sda` | mirror root | 20 GB |
| `a2` | `sdb` | mirror root | 20 GB |
| `b1` | `sdc` | mirror pool VM | 40 GB |
| `b2` | `sdd` | mirror pool VM | 40 GB |

La variabile `DISK_LAYOUT` controlla le dimensioni: `"a1:20G a2:20G b1:40G b2:40G"`.

## Pool root (rpool)

Creato automaticamente dall'installer unattended di Proxmox usando il profilo `profiles/zfs-mirror.toml`:

```toml
[disk-setup]
filesystem = "zfs"
zfs.raid = "raid1"
disk-list = ["sda", "sdb"]
```

Il nome del pool è `rpool` (default Proxmox). Contiene i dataset del sistema operativo (`rpool/ROOT`, `rpool/data`, ecc.).

## Pool storage VM (vmdata)

Creato dallo script di bootstrap del cluster dopo l'installazione:

```bash
zpool create -f vmdata mirror /dev/sdc /dev/sdd
pvesm add zfspool vmdata -pool vmdata -content images,rootdir
```

Controllato da `DATA_ZPOOL_NAME`, `DATA_ZPOOL_DEVICES`, `DATA_STORAGE_ID` e `DATA_STORAGE_CONTENT` in `config.env`.

`make cluster-scaffold` genera `artifacts/bootstrap/bootstrap-cluster.sh` che esegue questi comandi su ogni nodo tramite SSH.

## Stato atteso dopo il bootstrap

```
NAME      SIZE  ALLOC   FREE
rpool    39.5G  ~4.2G  ~35G    ← mirror OS su sda+sdb
vmdata   74.5G  ~100K  ~74G    ← mirror pool VM su sdc+sdd
```

Nella UI Proxmox: **Datacenter → Storage** dovrebbe mostrare `vmdata` con tipo `ZFS` e contenuto `Disk image, Container`.

## Ridimensionamento

Per modificare le dimensioni dei dischi prima di creare le VM, modificare `DISK_LAYOUT` in `config.env`:

```bash
DISK_LAYOUT="a1:40G a2:40G b1:100G b2:100G"
```

Poi eseguire `make create` (o `make clean && make create` per ricreare da zero).
