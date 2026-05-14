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

With `[network] source = "from-dhcp"` in the answer file (the default), each node requests an address via DHCP during install and on every boot. If there is no DHCP server on the bridge, the install will stall waiting for a lease.

Options:
- Set `DHCP_ON_BRIDGE=1` and enslave a NIC to let the bridge act as an uplink to an existing DHCP server
- Run `dnsmasq` or another DHCP server on the bridge
- Change the answer file to use a static address (`source = "from-answer"` with `[network.if-defaults]`)

## Firewall / iptables

`network-up` does not set up masquerading or forwarding rules. Add them manually if you want the lab nodes to reach the internet:

```bash
# example — adjust interface names
sysctl -w net.ipv4.ip_forward=1
iptables -t nat -A POSTROUTING -s 192.168.100.0/24 -o eth0 -j MASQUERADE
iptables -A FORWARD -i pvlab-br0 -j ACCEPT
iptables -A FORWARD -o pvlab-br0 -j ACCEPT
```
