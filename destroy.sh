#!/bin/bash


# Disattiva il bridge e rimuovi le interfacce associate
sudo ip link set manzolo-br0 down
sudo brctl delif manzolo-br0 manzolo-tap0
sudo brctl delif manzolo-br0 eno2
sudo brctl delbr manzolo-br0

# Rimuovi l'interfaccia TAP
for i in {1..3}
do
    sudo ip tuntap del mode tap name manzolo-tap${i}
done

# Riattiva l'interfaccia di rete eno2
sudo ip link set eno2 up

# Configura eno2 per l'accesso alla rete tramite DHCP
sudo dhclient -v eno2

# Arresto delle VM
echo "Arresto delle VM..."
for i in {1..3}
do
    qm stop 100${i}
done

# Rimozione delle VM
echo "Rimozione delle VM..."
for i in {1..3}
do
    qm destroy 100${i}
done

# Rimozione dei dischi delle VM
echo "Rimozione dei dischi delle VM..."

# Rimozione delle VM
echo "Rimozione delle VM..."
for i in {1..3}
do
    rm pve0${i}a1.qcow2 pve0${i}a2.qcow2 pve0${i}b1.qcow2 pve0${i}b2.qcow2
done

echo "Le VM sono state eliminate e i dischi rimossi."
