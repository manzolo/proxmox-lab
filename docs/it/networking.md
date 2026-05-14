# Rete

## Modalità

### User networking (default)

Stack user-mode integrato in QEMU. Non richiede privilegi sull'host, nessuna configurazione aggiuntiva. Ogni VM ottiene una rete NAT privata con DHCP da QEMU. I nodi non possono raggiungersi tra loro né raggiungere l'host — adatto per smoke test a nodo singolo, inutilizzabile per la formazione del cluster.

### Modalità TAP/bridge

Sul host vengono creati un bridge Linux e un'interfaccia TAP per nodo. Le VM si collegano al bridge e sono raggiungibili dall'host e tra di loro. Richiesto per la formazione del cluster.

## Setup TAP

Impostare in `config.env`:

```bash
USE_TAP_NETWORK=1
BRIDGE_NAME=pvlab-br0
TAP_PREFIX=pvlab-tap
# INTERFACE_NAME=eno1   # opzionale: aggiunge una NIC fisica al bridge
# DHCP_ON_BRIDGE=1      # opzionale: ottieni un IP sul bridge via dhclient
```

```bash
sudo make network-up
```

Questo crea:
- bridge `pvlab-br0`
- interfacce TAP `pvlab-tap1`, `pvlab-tap2`, `pvlab-tap3` collegate al bridge

Per verificare:

```bash
ip link show pvlab-br0
bridge link show
```

Per rimuovere:

```bash
sudo make network-down
```

## Indirizzi MAC

Ogni VM riceve un MAC deterministico: `52:54:00:ac:11:<indice>` (es. nodo 1 = `52:54:00:ac:11:01`). Se si esegue un server DHCP sul bridge, è possibile assegnare lease statici tramite MAC.

## Indirizzamento dei nodi

### IP statici (consigliato per lab isolati)

Usare `AUTOINSTALL_PROFILE=zfs-mirror-static` in `config.env`. Impostare:

```bash
AUTOINSTALL_PROFILE=zfs-mirror-static
NODE_FIRST_IP=192.168.100.101   # nodo 1; il nodo N ottiene .101+(N-1)
NODE_PREFIX_LEN=24
NODE_GATEWAY=192.168.100.1
NODE_DNS=1.1.1.1
BRIDGE_ADDRESS=192.168.100.1/24  # assegnato al bridge host da network-up
```

`make autoinstall-scaffold` incorpora un IP statico nel file di risposta di ogni nodo al momento della creazione dell'ISO. `sudo make network-up` assegna `BRIDGE_ADDRESS` al bridge in modo che l'host possa raggiungere tutti i nodi. Non è necessario un server DHCP esterno.

**Come funziona il filtro**: il file di risposta usa `filter.ID_NET_NAME_MAC = "enx<mac-senza-due-punti>"` per identificare l'interfaccia — es. `enx525400ac1101` per il nodo 1 (MAC `52:54:00:ac:11:01`). Questa è la proprietà udev `ID_NET_NAME_MAC`, esposta da tutti i dispositivi virtio-net nelle macchine QEMU q35. `autoinstall-scaffold` la calcola automaticamente per ogni nodo.

**Accesso a internet durante l'installazione**: l'installer automatico di Proxmox configura la rete presto e potrebbe contattare NTP/DNS. Se il bridge non ha un percorso verso internet, aggiungere NAT prima di avviare l'installazione (vedi [Firewall / iptables](#nat--iptables) sotto).

Per raggiungere i nodi tramite hostname, aggiungere voci a `/etc/hosts` (opzionale — gli IP funzionano ovunque):

```
192.168.100.101  pvelab1.lab.local  pvelab1
192.168.100.102  pvelab2.lab.local  pvelab2
192.168.100.103  pvelab3.lab.local  pvelab3
```

Se si salta `/etc/hosts`: `ssh root@192.168.100.101`, `FIRST_NODE_FQDN=192.168.100.101 bash artifacts/bootstrap/bootstrap-cluster.sh`.

### DHCP

Con `AUTOINSTALL_PROFILE=zfs-mirror` (il default), ogni nodo richiede un indirizzo via DHCP durante l'installazione e a ogni avvio. Opzioni:
- Impostare `DHCP_ON_BRIDGE=1` e aggiungere una NIC fisica al bridge per collegarsi a un server DHCP esistente
- Eseguire `dnsmasq` sul bridge con lease statici basati sugli indirizzi MAC deterministici (`52:54:00:ac:11:0N`)

## NAT / iptables

Quando `NODE_FIRST_IP` è impostato (modalità IP statico), `make network-up` automaticamente:

1. Abilita `net.ipv4.ip_forward`
2. Aggiunge una regola `MASQUERADE` per la subnet dei nodi (base `NODE_FIRST_IP` + `/NODE_PREFIX_LEN`) verso l'interfaccia outbound rilevata tramite `ip route get 8.8.8.8`
3. Aggiunge regole `FORWARD ACCEPT` per il bridge

`make network-down` rimuove le stesse regole.

Per gestire il NAT indipendentemente:

```bash
sudo make network-nat-up    # applica solo le regole
sudo make network-nat-down  # rimuove solo le regole
```

Queste regole non sono persistenti dopo il riavvio dell'host. Per renderle permanenti:

```bash
sudo apt-get install -y iptables-persistent
sudo netfilter-persistent save
```
