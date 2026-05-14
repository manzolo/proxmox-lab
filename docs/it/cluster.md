# Formazione del cluster

> Testato con **Proxmox VE 9.1-1**. I comandi `pvecm` e `pvesm` sono stabili tra versioni minori; verificare la compatibilità su aggiornamenti major (es. 9.x → 10.x).

## Prerequisiti

Prima di eseguire lo script di bootstrap:

- I 3 nodi hanno completato l'installazione unattended (`make install-serial`)
- I nodi sono avviati e in esecuzione (`make boot-headless`)
- Il networking TAP/bridge è attivo (`sudo make network-up`)
- Ogni nodo ha un indirizzo IP sul bridge (verificare tramite `make vm-serial`)
- SSH funziona dall'host verso ogni nodo: `ssh root@192.168.100.101` (o tramite hostname se si sono aggiunte voci a `/etc/hosts` — vedi [networking.md](networking.md))

Lo scambio di chiavi SSH tra nodi (richiesto per `pvecm add -use_ssh 1`) è gestito automaticamente dallo script di bootstrap — non è necessaria alcuna configurazione manuale delle chiavi.

## Generare lo script di bootstrap

```bash
make cluster-scaffold
```

Crea `artifacts/bootstrap/bootstrap-cluster.sh`. Lo script è parametrizzato tramite variabili d'ambiente, quindi è possibile sovrascrivere i nomi senza rigenerarlo:

```bash
CLUSTER_NAME=mycluster FIRST_NODE_FQDN=pvelab1.lab.local bash artifacts/bootstrap/bootstrap-cluster.sh
```

## Cosa fa lo script

1. **Scambio chiavi SSH**: genera una chiave ed25519 su ogni nodo che si unisce (se assente), aggiunge la sua chiave pubblica agli `authorized_keys` del nodo 1, e pre-accetta la chiave host del nodo 1 — in modo che `pvecm add -use_ssh 1` possa procedere senza interazione
2. **Crea il cluster** sul nodo 1: `pvecm create <CLUSTER_NAME>`
3. **Crea il pool vmdata** su ogni nodo usando percorsi stabili `/dev/disk/by-id/scsi-*_b1` (evita sorprese nell'ordine di enumerazione SCSI), con fallback a `DATA_ZPOOL_DEVICES` se i percorsi by-id non vengono trovati
4. **Registra lo storage** su ogni nodo: `pvesm add zfspool vmdata …`
5. **Unisce il cluster** sui nodi 2 e 3: `pvecm add <node1_fqdn> -use_ssh 1`

SSH dall'host usa `StrictHostKeyChecking=accept-new` così l'accettazione della chiave host al primo avvio è automatica.

## Verifica

Sul nodo 1 dopo il bootstrap:

```bash
ssh root@pvelab1.lab.local pvecm status
```

Output atteso:

```
Cluster information
-------------------
Name:             pvelab
Config Version:   3
Transport:        knet
Nodes:            3
```

Controllare anche lo storage:

```bash
ssh root@pvelab1.lab.local pvesm status
```

## Ceph (futuro)

Ceph non è configurato da questo progetto, ma il lab è un buon punto di partenza una volta che il cluster è stabile.

Prima di aggiungere Ceph, assicurarsi:
- Rete affidabile tra nodi (testare con `ping` e `pvecm status`)
- SSH funzionante tra tutti i nodi
- Dischi dedicati per gli OSD Ceph — non riutilizzare `sdc`/`sdd` se fanno già parte di `vmdata`
- Tutti i nodi mostrano `Online` in `pvecm status`

Ceph va trattato come una fase separata dopo il bootstrap del cluster.
