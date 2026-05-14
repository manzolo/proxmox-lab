# Riferimento alla configurazione

Tutte le impostazioni si trovano in `config.env` (copia da `config.env.example`). Il file viene sourciato come Bash puro, quindi si applicano le regole di sintassi delle variabili. Qualsiasi valore può essere sovrascritto per singola invocazione con `--set KEY=VALUE`.

## Risorse VM

| Variabile | Default | Descrizione |
|---|---|---|
| `NUM_VMS` | `3` | Numero di VM da gestire |
| `VM_PREFIX` | `pve0` | Prefisso per i nomi VM (`pve01`, `pve02`, …) |
| `VM_MEMORY_MB` | `4096` | RAM per VM in MB |
| `VM_CORES` | `2` | Core vCPU per VM |
| `VM_MACHINE` | `pc-q35-7.0` | Tipo di macchina QEMU |
| `VM_ACCEL` | `kvm` | Acceleratore QEMU — usare `tcg,thread=multi` senza KVM |
| `VM_CPU` | `host,migratable=on` | Modello CPU |
| `VM_DISPLAY` | `gtk` | Display per boot grafico (`gtk`, `sdl`, `none`) |
| `VM_NET_DEVICE` | `virtio-net-pci` | Modello NIC |

## Layout dischi

| Variabile | Default | Descrizione |
|---|---|---|
| `DISK_LAYOUT` | `a1:20G a2:20G b1:40G b2:40G` | Coppie `suffisso:dimensione` separate da spazio per VM. `a1`+`a2` diventano `sda`+`sdb` (mirror root); `b1`+`b2` diventano `sdc`+`sdd` (mirror pool VM) |

## Rete

| Variabile | Default | Descrizione |
|---|---|---|
| `USE_TAP_NETWORK` | `0` | Impostare a `1` per usare TAP/bridge invece del networking utente QEMU |
| `BRIDGE_NAME` | `pvlab-br0` | Nome del bridge Linux |
| `INTERFACE_NAME` | _(vuoto)_ | NIC fisica da aggiungere al bridge (opzionale) |
| `TAP_PREFIX` | `pvlab-tap` | Prefisso interfaccia TAP (`pvlab-tap1`, `pvlab-tap2`, …) |
| `TAP_USER` | utente corrente | Proprietario delle interfacce TAP |
| `DHCP_ON_BRIDGE` | `0` | Esegui `dhclient` sul bridge dopo la creazione |

## Download ISO

| Variabile | Default | Descrizione |
|---|---|---|
| `PROXMOX_ISO_VERSION` | `9.1-1` | Stringa di versione usata da `make iso-configured` |
| `ISO_URL_INDEX` | download.proxmox.com | URL primario dell'indice ISO |
| `ISO_URL_FALLBACKS` | mirror CDN | URL di fallback separati da spazio |
| `ALLOW_INSECURE_TLS` | `0` | Impostare a `1` per saltare la verifica TLS (`-k` in curl) — solo per proxy aziendali problematici |

## Installazione unattended

| Variabile | Default | Descrizione |
|---|---|---|
| `AUTO_HOSTNAME_PREFIX` | `pvelab` | Prefisso hostname — i nodi ottengono `pvelab1`, `pvelab2`, … |
| `AUTO_DOMAIN` | `lab.local` | Dominio DNS — il FQDN è `pvelabN.lab.local` |
| `AUTO_ROOT_PASSWORD` | `CHANGEME` | Password root incorporata nel file di risposta di ogni nodo |
| `AUTO_MAILTO` | `root@localhost` | Email per gli alert nella configurazione Proxmox |
| `AUTOINSTALL_PROFILE` | `zfs-mirror` | Nome del profilo (senza `.toml`) nella directory `profiles/` |

## Cluster e storage

| Variabile | Default | Descrizione |
|---|---|---|
| `CLUSTER_NAME` | `pvelab` | Nome del cluster Proxmox |
| `DATA_ZPOOL_NAME` | `vmdata` | Nome del secondo pool ZFS |
| `DATA_ZPOOL_DEVICES` | `sdc sdd` | Dispositivi a blocchi per il mirror di storage VM |
| `DATA_STORAGE_ID` | `vmdata` | ID storage Proxmox |
| `DATA_STORAGE_CONTENT` | `images,rootdir` | Tipi di contenuto dello storage Proxmox |

## Fallback Docker

| Variabile | Default | Descrizione |
|---|---|---|
| `DOCKER_AUTOINSTALL_IMAGE` | `debian:trixie` | Immagine container usata quando `proxmox-auto-install-assistant` non è installato localmente |
