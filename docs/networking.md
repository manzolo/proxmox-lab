# Networking

## Modes

### User networking (default)

QEMU's built-in user-mode stack. No host privileges required, no extra setup. Each VM gets a private NAT'd network with DHCP from QEMU. Nodes cannot reach each other or the host — fine for single-node smoke tests, unusable for cluster formation.

### TAP/bridge mode

A Linux bridge and one TAP interface per node are created on the host. VMs attach to the bridge and are reachable from the host and from each other. Required for cluster formation.

## TAP setup

Set in `config.env`:

```bash
USE_TAP_NETWORK=1
BRIDGE_NAME=pvlab-br0
TAP_PREFIX=pvlab-tap
# INTERFACE_NAME=eno1   # optional: enslave a physical NIC to the bridge
# DHCP_ON_BRIDGE=1      # optional: get an IP on the bridge via dhclient
```

```bash
sudo make network-up
```

This creates:
- bridge `pvlab-br0`
- TAP interfaces `pvlab-tap1`, `pvlab-tap2`, `pvlab-tap3` attached to the bridge

To verify:

```bash
ip link show pvlab-br0
bridge link show
```

To tear down:

```bash
sudo make network-down
```

## MAC addresses

Each VM gets a deterministic MAC: `52:54:00:ac:11:<index>` (e.g. node 1 = `52:54:00:ac:11:01`). If you run a DHCP server on the bridge, you can assign static leases by MAC.

## Node addressing

### Static IPs (recommended for standalone labs)

Use `AUTOINSTALL_PROFILE=zfs-mirror-static` in `config.env`. Set:

```bash
AUTOINSTALL_PROFILE=zfs-mirror-static
NODE_FIRST_IP=192.168.100.101   # node 1; node N gets .101+(N-1)
NODE_PREFIX_LEN=24
NODE_GATEWAY=192.168.100.1
NODE_DNS=1.1.1.1
BRIDGE_ADDRESS=192.168.100.1/24  # assigned to host bridge by network-up
```

`make autoinstall-scaffold` bakes a static IP into each node's answer file at ISO build time. `sudo make network-up` assigns `BRIDGE_ADDRESS` to the bridge so the host can reach all nodes. No external DHCP server required.

**How the filter works**: the answer file uses `filter.ID_NET_NAME_MAC = "enx<mac-without-colons>"` to identify the interface — e.g. `enx525400ac1101` for node 1 (MAC `52:54:00:ac:11:01`). This is the udev `ID_NET_NAME_MAC` property, which all virtio-net devices in QEMU q35 machines expose. `autoinstall-scaffold` computes it automatically per node.

**Internet access during install**: the Proxmox automated installer configures the network early and may contact NTP/DNS. If your bridge has no internet route, add NAT before running the install (see [Firewall / iptables](#firewall--iptables) below).

To reach nodes by hostname, add entries to `/etc/hosts` (optional — IPs work everywhere):

```
192.168.100.101  pvelab1.lab.local  pvelab1
192.168.100.102  pvelab2.lab.local  pvelab2
192.168.100.103  pvelab3.lab.local  pvelab3
```

If you skip `/etc/hosts`: `ssh root@192.168.100.101`, `FIRST_NODE_FQDN=192.168.100.101 bash artifacts/bootstrap/bootstrap-cluster.sh`.

### DHCP

With `AUTOINSTALL_PROFILE=zfs-mirror` (the default), each node requests an address via DHCP during install and on every boot. Options:
- Set `DHCP_ON_BRIDGE=1` and enslave a physical NIC to let the bridge uplink to an existing DHCP server
- Run `dnsmasq` on the bridge with static leases keyed on the deterministic MAC addresses (`52:54:00:ac:11:0N`)

## NAT / iptables

When `NODE_FIRST_IP` is set (static-IP mode), `make network-up` automatically:

1. Enables `net.ipv4.ip_forward`
2. Adds a `MASQUERADE` rule for the node subnet (`NODE_FIRST_IP` base + `/NODE_PREFIX_LEN`) to the outbound interface detected via `ip route get 8.8.8.8`
3. Adds `FORWARD ACCEPT` rules for the bridge

`make network-down` removes the same rules.

To manage NAT independently:

```bash
sudo make network-nat-up    # apply rules only
sudo make network-nat-down  # remove rules only
```

These rules are not persistent across host reboots. To make them permanent:

```bash
sudo apt-get install -y iptables-persistent
sudo netfilter-persistent save
```
