#!/bin/bash

set -e

# Verifica che lo script venga eseguito con i privilegi di root
if [ "$(id -u)" -ne 0 ]; then
    echo "Questo script deve essere eseguito con i privilegi di root" >&2
    exit 1
fi

# Installa i pacchetti necessari
apt-get update
apt-get install -y bridge-utils

# Dichiarazione delle variabili
BRIDGE_NAME="manzolo-br0"
INTERFACE_NAME="eno2"
TAP_PREFIX="manzolo-tap"
VM_PREFIX="pve0"
NUM_VMS=3

# Crea il bridge
brctl addbr "$BRIDGE_NAME"

# Rimuove eventuali indirizzi IP dall'interfaccia di rete fisica
ip addr flush dev "$INTERFACE_NAME"

# Collega l'interfaccia di rete fisica al bridge
brctl addif "$BRIDGE_NAME" "$INTERFACE_NAME"

# Attiva il bridge e l'interfaccia di rete fisica
ip link set dev "$BRIDGE_NAME" up
ip link set dev "$INTERFACE_NAME" up

# Crea e configura le interfacce TAP per le macchine virtuali
for ((i = 1; i <= NUM_VMS; i++)); do
    TAP_NAME="${TAP_PREFIX}${i}"
    tunctl -t "$TAP_NAME" -u "$(whoami)"
    ip link set dev "$TAP_NAME" up
done

# Collega le interfacce TAP al bridge
for ((i = 1; i <= NUM_VMS; i++)); do
    TAP_NAME="${TAP_PREFIX}${i}"
    brctl addif "$BRIDGE_NAME" "$TAP_NAME"
done

# Configura il bridge per l'accesso alla rete, ad esempio tramite DHCP
dhclient -v "$BRIDGE_NAME"

# Creazione delle macchine virtuali
for ((i = 1; i <= NUM_VMS; i++)); do
    # Creazione dei dischi per la macchina virtuale
    qemu-img create -f qcow2 -o preallocation=off "${VM_PREFIX}${i}a1.qcow2" 20G
    qemu-img create -f qcow2 -o preallocation=off "${VM_PREFIX}${i}a2.qcow2" 20G
    qemu-img create -f qcow2 -o preallocation=off "${VM_PREFIX}${i}b1.qcow2" 40G
    qemu-img create -f qcow2 -o preallocation=off "${VM_PREFIX}${i}b2.qcow2" 40G
    
    # Creazione della macchina virtuale
    echo "Creazione di VM${i}..."
    qemu-system-x86_64 \
    -name "${VM_PREFIX}${i}" \
    -machine pc-q35-7.0,usb=off,vmport=off,dump-guest-core=off \
    -accel kvm \
    -cpu host,migratable=on \
    -drive file="${VM_PREFIX}${i}a1.qcow2",index=0,media=disk \
    -drive file="${VM_PREFIX}${i}a2.qcow2",index=1,media=disk \
    -drive file="${VM_PREFIX}${i}b1.qcow2",index=2,media=disk \
    -drive file="${VM_PREFIX}${i}b2.qcow2",index=3,media=disk \
    -m 2048 \
    -boot order=cd \
    -drive file=proxmox-ve_8.1-2.iso,format=raw,if=none,id=cdrom \
    -device virtio-scsi-pci \
    -device scsi-cd,drive=cdrom \
    -netdev "tap,id=net${i}",ifname="${TAP_PREFIX}${i}",script=no,downscript=no \
    -device e1000,netdev=net${i},mac=52:55:00:d1:55:0${i} \
    -smp cores=2 \
    -vga std \
    -display gtk &
done

echo "Le VM sono in esecuzione."
