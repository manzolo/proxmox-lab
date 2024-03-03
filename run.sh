#!/bin/bash

set -e

VM_PREFIX="pve0"
NUM_VMS=3
TAP_PREFIX="manzolo-tap"

# Assicurati che lo script venga eseguito con i privilegi di root
if [ "$(id -u)" -ne 0 ]; then
    echo "Questo script deve essere eseguito con i privilegi di root" >&2
    exit 1
fi

# Creazione delle macchine virtuali
for ((i = 1; i <= NUM_VMS; i++)); do
    # Creazione della macchina virtuale
    echo "Creazione di VM${i}..."
    sudo qemu-system-x86_64 \
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
