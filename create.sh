#!/bin/bash

# Installa i pacchetti necessari
sudo apt install bridge-utils

# Crea il bridge manzolo-br0
sudo brctl addbr manzolo-br0

# Rimuove eventuali indirizzi IP da eno2
sudo ip addr flush dev eno2

# Collega eno2 al bridge manzolo-br0
sudo brctl addif manzolo-br0 eno2

# Crea un'interfaccia TAP
#sudo ip tuntap add mode tap name manzolo-tap0
# Crea le interfacce TAP per le macchine virtuali
for i in {1..3}
do
    sudo tunctl -t manzolo-tap$i -u $(whoami)
    sudo ip link set dev manzolo-tap$i up
done

# Attendi un po' per dare il tempo a tutte le interfacce di essere configurate
sleep 2

# Collega l'interfaccia TAP al bridge manzolo-br0
#sudo brctl addif manzolo-br0 manzolo-tap0
# Collega le interfacce TAP al bridge manzolo-br0
for i in {1..3}
do
    sudo brctl addif manzolo-br0 manzolo-tap${i}
done

# Attiva il bridge manzolo-br0
sudo ip link set dev manzolo-br0 up

# Attiva l'interfaccia di rete eno2
sudo ip link set dev eno2 up

# Attiva l'interfaccia TAP
for i in {1..3}
do
    sudo ip link set dev manzolo-tap${i} up
done

# Ora puoi configurare il bridge per l'accesso alla rete, ad esempio tramite DHCP
sudo dhclient -v manzolo-br0

VM_PREFIX=pve0
# Creazione dei dischi per la prima VM
for i in {1..3}
do
    qemu-img create -f qcow2 -o preallocation=off ${VM_PREFIX}${i}a1.qcow2 20G
    qemu-img create -f qcow2 -o preallocation=off ${VM_PREFIX}${i}a2.qcow2 20G
    qemu-img create -f qcow2 -o preallocation=off ${VM_PREFIX}${i}b1.qcow2 40G
    qemu-img create -f qcow2 -o preallocation=off ${VM_PREFIX}${i}b2.qcow2 40G
    #-drive file=${VM_PREFIX}${i}a1.qcow2,format=qcow2,index=1 \
    #-drive file=${VM_PREFIX}${i}a2.qcow2,format=qcow2,index=2 \
    #-drive file=${VM_PREFIX}${i}b2.qcow2,format=qcow2 \
    #-drive file=${VM_PREFIX}${i}b1.qcow2,format=qcow2,index=3 \

    # Creazione della prima VM
    echo "Creazione di VM1..."
    #qemu-system-x86_64 -name ${VM_PREFIX}${i} -hda ${VM_PREFIX}1a1.qcow2 -hdb ${VM_PREFIX}1a2.qcow2 -hdc ${VM_PREFIX}1b1.qcow2 -hdd ${VM_PREFIX}1b2.qcow2 -m 2048 -boot d -cdrom proxmox-ve_8.1-2.iso
    qemu-system-x86_64 \
    -name ${VM_PREFIX}${i} \
    -machine pc-q35-7.0,usb=off,vmport=off,dump-guest-core=off \
    -accel kvm \
    -cpu host,migratable=on \
    -drive file=${VM_PREFIX}${i}a1.qcow2,index=0,media=disk \
    -drive file=${VM_PREFIX}${i}a2.qcow2,index=1,media=disk \
    -drive file=${VM_PREFIX}${i}b1.qcow2,index=2,media=disk \
    -drive file=${VM_PREFIX}${i}b2.qcow2,index=3,media=disk \
    -m 2048 \
    -boot order=cd \
    -drive file=proxmox-ve_8.1-2.iso,format=raw,if=none,id=cdrom \
    -device virtio-scsi-pci \
    -device scsi-cd,drive=cdrom \
    -netdev tap,id=net${i},ifname=manzolo-tap${i},script=no,downscript=no \
    -device e1000,netdev=net${i},mac=52:55:00:d1:55:0${i} \
    -smp cores=2 \
    -vga std \
    -display gtk &

done


# Replica della configurazione per le altre VM
#for i in {1..3}
#do
#    echo "Clonazione di VM1 per creare VM$((i+1))..."
#    qm clone 1000 $((1000+i)) --name "VM$((i+1))"
#    #qm start $((1000+i))
#done

echo "Le VM sono in esecuzione."
