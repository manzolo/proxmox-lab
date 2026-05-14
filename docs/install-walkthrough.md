# Proxmox Lab — Installazione unattended e bootstrap cluster (passo per passo)

> Testato con **Proxmox VE 9.1-1** su host Linux con KVM. Versioni diverse potrebbero
> richiedere aggiornamenti a `PROXMOX_ISO_VERSION` e ai profili in `profiles/`.

Questa guida parte da zero e porta a 3 nodi Proxmox con:
- root su ZFS mirror (`sda` + `sdb`)
- pool VM su ZFS mirror (`sdc` + `sdd`)
- cluster a 3 nodi via TAP/bridge

## Prerequisiti host

```bash
# QEMU e strumenti disco
sudo apt-get install -y qemu-system-x86 qemu-utils

# TUI interattiva (opzionale)
sudo apt-get install -y dialog

# Docker — serve solo se proxmox-auto-install-assistant non è installato localmente
# (il CLI lo usa automaticamente come fallback)
sudo apt-get install -y docker.io

# Networking TAP/bridge
sudo apt-get install -y iproute2
```

## 1. Configurazione iniziale

```bash
cp config.env.example config.env
```

Modificare almeno questi valori in `config.env`:

| Variabile | Valore consigliato | Note |
|---|---|---|
| `AUTO_ROOT_PASSWORD` | password sicura | password root di ogni nodo |
| `AUTO_DOMAIN` | `lab.local` o dominio reale | FQDN dei nodi |
| `VM_MEMORY_MB` | `4096` o più | minimo 4 GB per nodo |
| `VM_ACCEL` | `kvm` | usare `tcg,thread=multi` se KVM non disponibile |
| `USE_TAP_NETWORK` | `0` per install, `1` per cluster | vedere sotto |
| `BRIDGE_NAME` | es. `pvlab-br0` | nome del bridge Linux |
| `TAP_PREFIX` | es. `pvlab-tap` | prefisso TAP per ogni nodo |
| `CLUSTER_NAME` | `pvelab` | nome del cluster Proxmox |
| `DATA_ZPOOL_NAME` | `vmdata` | nome del pool dati |
| `DATA_ZPOOL_DEVICES` | `sdc sdd` | dischi per il secondo mirror |

```bash
# Creare le directory artifact e linkare la config
make init
```

## 2. Download ISO

```bash
# Scarica la versione indicata in PROXMOX_ISO_VERSION (default: 9.1-1)
make iso-configured
```

L'ISO viene salvato in `artifacts/iso/proxmox-ve_<versione>.iso`.

## 3. Generazione ISO unattended per ogni nodo

```bash
# Genera artifacts/autoinstall/pve01-answer.toml (pve02, pve03)
make autoinstall-scaffold

# Verifica la sintassi dei file (richiede proxmox-auto-install-assistant o Docker)
make autoinstall-validate

# Incorpora gli answer file nell'ISO → genera artifacts/iso/pve0{1,2,3}-auto.iso
make autoinstall-prepare
```

> **Nota**: `make autoinstall-validate` e `make autoinstall-prepare` rilevano automaticamente se
> `proxmox-auto-install-assistant` è installato. Se non lo è, usano Docker (Debian Trixie)
> in modo trasparente. Si può forzare con `./bin/proxmox-lab --docker autoinstall prepare-iso ...`.

## 4. Creazione dischi VM

```bash
make create
```

Crea 4 dischi qcow2 per ogni nodo sotto `artifacts/disks/`:

| Disco | Mount | Uso |
|---|---|---|
| `pve0Xa1` + `pve0Xa2` | `sda` + `sdb` | root ZFS mirror (20 GB ciascuno) |
| `pve0Xb1` + `pve0Xb2` | `sdc` + `sdd` | pool dati ZFS mirror (40 GB ciascuno) |

## 5. Rete TAP/bridge (solo per cluster)

> Saltare questo passo se si vuole solo testare l'install singolo in modalità user-network.
> Il cluster richiede TAP perché i nodi devono raggiungersi via IP.

Per IP statici (consigliato, nessun DHCP server necessario), assicurarsi che `config.env` contenga:

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

Crea il bridge, i TAP e assegna `BRIDGE_ADDRESS` al bridge.

Per verificare:

```bash
ip addr show pvlab-br0   # deve mostrare 192.168.100.1/24
```

### NAT per accesso internet durante l'install

L'installer automatico di Proxmox configura la rete e contatta NTP/DNS. Senza una rotta verso internet l'install si completa comunque, ma aggiungere il NAT evita ritardi:

```bash
# Trovare l'interfaccia di uscita: ip route get 8.8.8.8
sudo sysctl -w net.ipv4.ip_forward=1
sudo iptables -t nat -A POSTROUTING -s 192.168.100.0/24 -o <iface> -j MASQUERADE
sudo iptables -A FORWARD -i <bridge> -j ACCEPT
sudo iptables -A FORWARD -o <bridge> -j ACCEPT
```

Sostituire `<iface>` con l'interfaccia di uscita (es. `eth0`, `tun0`) e `<bridge>` con `BRIDGE_NAME`.

## 6. Installazione unattended

```bash
# Tutte le VM in parallelo (richiede host con RAM/I/O sufficienti)
make install-headless

# Una VM alla volta — consigliato su host con risorse limitate
make install-serial
```

`install-serial` avvia ogni VM, attende che QEMU esca (segnale di install completato),
poi passa alla successiva. Più lento ma immune da contention su disco e RAM.

Il progresso si monitora via dimensione dei dischi:

```bash
watch -n 5 'ls -lh artifacts/disks/*.qcow2'
```

L'install è completo quando i dischi `pve0Xa1` e `pve0Xa2` raggiungono ~2–3 GB.

## 7. Boot dei nodi installati

```bash
make boot-headless
```

I nodi si avviano dal disco. Seguire l'output seriale per verificare che SSH sia up:

```bash
make vm-serial          # serial log di pve01
./bin/proxmox-lab vm serial 2   # serial log di pve02
```

## 8. Bootstrap del cluster

```bash
# Genera artifacts/bootstrap/bootstrap-cluster.sh
make cluster-scaffold
```

Il script generato esegue sul primo nodo via SSH:

1. `pvecm create <CLUSTER_NAME>` su pve01
2. `zpool create vmdata mirror /dev/sdc /dev/sdd` + registrazione storage su ogni nodo
3. `pvecm add pvelab1.lab.local -use_ssh 1` su pve02 e pve03

Eseguire dal host (richiede SSH raggiungibile tra host e nodi, tipicamente via bridge):

```bash
bash artifacts/bootstrap/bootstrap-cluster.sh
```

> **Nota**: Il bootstrap usa gli FQDN dei nodi (es. `pvelab1.lab.local`). Se non si
> vogliono aggiungere voci a `/etc/hosts`, si possono passare gli IP direttamente:
> ```bash
> FIRST_NODE_FQDN=192.168.100.101 bash artifacts/bootstrap/bootstrap-cluster.sh
> ```
> Oppure aggiungere le voci a `/etc/hosts` (opzionale, vedi [networking.md](networking.md)).

## 9. Verifica cluster

Collegarsi a pve01:

```bash
ssh root@pvelab1.lab.local
pvecm status
zpool list
pvesm status
```

Output atteso:

```
Cluster information
-------------------
Name:             pvelab
Config Version:   3
Transport:        knet
Nodes:            3
...
```

## Teardown completo

```bash
make stop
sudo make network-down   # solo se TAP era attivo
make clean-all
```

## Struttura ZFS risultante

Ogni nodo avrà:

```
NAME        SIZE  ALLOC   FREE  CKPOINT
rpool      39.5G  4.20G  35.3G    -       ← root mirror sda+sdb
vmdata     74.5G   100K  74.5G    -       ← VM pool mirror sdc+sdd
```

Il pool `vmdata` è registrato in Proxmox storage come `zfspool` con contenuto `images,rootdir`,
quindi visibile nella UI sotto Datacenter → Storage.
