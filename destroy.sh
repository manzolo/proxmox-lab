#!/bin/bash

# Assicurati che lo script venga eseguito con i privilegi di root
if [ "$(id -u)" -ne 0 ]; then
    echo "Questo script deve essere eseguito con i privilegi di root" >&2
    exit 1
fi

# Disattiva il bridge e rimuovi le interfacce associate
echo "Disattivazione del bridge e rimozione delle interfacce associate..."
sudo ip link set manzolo-br0 down || true
sudo brctl delif manzolo-br0 manzolo-tap0 || true
sudo brctl delif manzolo-br0 eno2 || true
sudo brctl delbr manzolo-br0 || true

# Rimuovi l'interfaccia TAP
echo "Rimozione delle interfacce TAP..."
for i in {1..3}; do
    sudo ip tuntap del mode tap name "manzolo-tap${i}" || true
done

# Riattiva l'interfaccia di rete eno2
echo "Riattivazione dell'interfaccia di rete eno2..."
sudo ip link set eno2 up

# Configura eno2 per l'accesso alla rete tramite DHCP
echo "Configurazione di eno2 per l'accesso alla rete tramite DHCP..."
sudo dhclient -v eno2

# Rimozione dei dischi delle VM
echo "Rimozione dei dischi delle VM..."
for i in {1..3}; do
    if [ -f "pve0${i}a1.qcow2" ]; then
        rm "pve0${i}a1.qcow2"
    fi
    if [ -f "pve0${i}a2.qcow2" ]; then
        rm "pve0${i}a2.qcow2"
    fi
    if [ -f "pve0${i}b1.qcow2" ]; then
        rm "pve0${i}b1.qcow2"
    fi
    if [ -f "pve0${i}b2.qcow2" ]; then
        rm "pve0${i}b2.qcow2"
    fi
done

echo "Le VM sono state eliminate e i dischi rimossi."
