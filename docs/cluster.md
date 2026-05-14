# Cluster Formation

> Testato con **Proxmox VE 9.1-1**. I comandi `pvecm` e `pvesm` sono stabili tra versioni
> minor; verificare la compatibilità su upgrade major (es. 9.x → 10.x).

## Prerequisites

Before running the bootstrap script:

- All 3 nodes have completed the unattended install (`make install-serial`)
- Nodes are booted and running (`make boot-headless`)
- TAP/bridge networking is up (`sudo make network-up`)
- Each node has an IP address on the bridge (verify via `make vm-serial`)
- SSH works from host to each node: `ssh root@192.168.100.101` (or by hostname
  if you added entries to `/etc/hosts` — see [networking.md](networking.md))

## Generate the bootstrap script

```bash
make cluster-scaffold
```

Creates `artifacts/bootstrap/bootstrap-cluster.sh`. The script is parameterised via environment variables so you can override names without regenerating:

```bash
CLUSTER_NAME=mycluster FIRST_NODE_FQDN=pvelab1.lab.local bash artifacts/bootstrap/bootstrap-cluster.sh
```

## What the script does

1. **Create cluster** on node 1: `pvecm create <CLUSTER_NAME>`
2. **Create vmdata pool** on every node: `zpool create -f vmdata mirror /dev/sdc /dev/sdd`
3. **Register storage** on every node: `pvesm add zfspool vmdata …`
4. **Join cluster** on nodes 2 and 3: `pvecm add <node1_fqdn> -use_ssh 1`

SSH uses `StrictHostKeyChecking=accept-new` so first-run host key acceptance is automatic.

## Verify

On node 1 after bootstrap:

```bash
ssh root@pvelab1.lab.local pvecm status
```

Expected output:

```
Cluster information
-------------------
Name:             pvelab
Config Version:   3
Transport:        knet
Nodes:            3
```

Also check storage:

```bash
ssh root@pvelab1.lab.local pvesm status
```

## Ceph (future)

Ceph is not configured by this project, but the lab is a reasonable starting point once the cluster is stable.

Before adding Ceph, ensure:
- Reliable node-to-node networking (test with `ping` and `pvecm status`)
- Working SSH between all nodes
- Dedicated disks for Ceph OSD — do not reuse `sdc`/`sdd` if they are already part of `vmdata`
- All nodes show `Online` in `pvecm status`

Ceph should be treated as a separate phase after cluster bootstrap.
