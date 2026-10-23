---
name: network-diagnose
description: Live network triage on Ubuntu — interfaces, link state and errors, addresses and DHCP, routes and default gateway, DNS through systemd-resolved, reachability of gateway, internet and named LAN hosts, MTU problems, Wi-Fi signal and association, listening services and port conflicts, and the NetworkManager / systemd-networkd / resolved journal. Read-only. Use when asked "no internet", "network is down", "DNS not resolving", "can't reach <host>", "Wi-Fi keeps dropping", "slow network", "what's listening on port X", "port already in use", "check network health". Works on the local machine or a remote host over SSH.
---

# Network diagnose

Work up the stack: link → address → route → DNS → reachability → service. Stop at the first layer that fails.

## Target

Local by default. Remote: `ssh <host> '<cmd>'` — if the remote host's network is the problem, you may only have a console; ask the user to paste output. Run reachability tests from both ends when a LAN path is broken.

## 1. Which stack manages networking

```bash
networkctl list 2>/dev/null                 # systemd-networkd (Ubuntu Server default)
nmcli -t -f RUNNING,STATE general 2>/dev/null   # NetworkManager (Ubuntu Desktop default)
ls /etc/netplan/ && sudo netplan get 2>/dev/null | head -30
```

## 2. Link and address

```bash
ip -br link
ip -br addr
ip -s link show <iface>                     # RX/TX errors, drops
ethtool <iface> 2>/dev/null | grep -E 'Speed|Duplex|Link detected'
journalctl -k --since "1 hour ago" --no-pager | grep -iE 'link is (up|down)|carrier|renamed|firmware' | tail
```

No carrier → cable/port/driver. Address `169.254.x.x` or none → DHCP failed:

```bash
journalctl -u systemd-networkd -u NetworkManager --since "30 min ago" --no-pager | grep -iE 'dhcp|lease|timeout' | tail -20
```

## 3. Routes

```bash
ip route
ip -6 route | head
GW=$(ip route show default | awk '/default/{print $3; exit}'); echo "gateway: $GW"
ping -c 3 -W 2 "$GW"
```

## 4. DNS

```bash
resolvectl status | sed -n '1,40p'          # per-link DNS servers and search domains
resolvectl query ubuntu.com
resolvectl query <lan-hostname>
getent hosts <name>                         # what applications actually get (includes /etc/hosts)
ls -l /etc/resolv.conf                      # should link to /run/systemd/resolve/stub-resolv.conf
resolvectl statistics | grep -iE 'cache|transactions'
```

IP works but names don't → DNS. Names fail only for `.local` → mDNS/avahi. Flush: `sudo resolvectl flush-caches`.

## 5. Reachability

```bash
ping -c 3 -W 2 1.1.1.1                     # internet by IP
ping -c 3 -W 2 ubuntu.com                  # internet by name
ping -c 3 -W 2 <lan-host>                  # named LAN hosts the user cares about
tracepath -n 1.1.1.1                        # path and path-MTU
curl -sS -o /dev/null -w '%{http_code} %{time_total}s\n' https://ubuntu.com
```

MTU: if small pings work and large transfers hang (VPNs, PPPoE), test `ping -M do -s 1472 <gw>` and lower until it passes.

## 6. Wi-Fi (desktop / laptops)

```bash
nmcli dev wifi list
nmcli -f GENERAL.CONNECTION,WIFI-PROPERTIES,IP4 dev show <wlan-iface> | head -20
iw dev <wlan-iface> link                   # signal (dBm) and bitrate; worse than -70 dBm is weak
rfkill list
journalctl -u NetworkManager -u wpa_supplicant --since "1 hour ago" --no-pager | grep -iE 'disconnect|deauth|reason' | tail
```

Frequent drops on Intel cards: check `iwlwifi` firmware messages in `dmesg`; power saving (`iw dev <iface> get power_save`) is a common cause.

## 7. Listening services and port conflicts

```bash
sudo ss -tulpn                             # who listens where
sudo ss -tlnp 'sport = :<port>'            # owner of one port
ss -s                                      # socket totals
docker ps --format '{{.Names}}\t{{.Ports}}' 2>/dev/null
```

A service bound to `127.0.0.1` is unreachable from the LAN by design; `0.0.0.0`/`[::]` listens on all interfaces. For whether the firewall allows a port, see the `ubuntu-security` plugin.

## Desktop vs server

- Desktop: NetworkManager owns interfaces; use `nmcli`. VPN clients often override DNS — check `resolvectl status` per link.
- Server: networkd + netplan; a bad netplan file is the usual cause after a change — `sudo netplan get`, `journalctl -u systemd-networkd`.

## Confirm before

Read-only. Restarting `NetworkManager`/`systemd-networkd`, bouncing an interface, or changing DNS on a remote host can cut your session — propose with the rollback plan and use `network-config`.

## Report

1. **Failing layer** and one-line diagnosis.
2. **Evidence** — the output lines that show it.
3. **Fix** — commands, flagged if they risk disconnecting a remote session.
4. **Follow-up** — permanent config change if needed.

## Related

- `network-config` — change addresses, DNS, routes, hostname.
- `network-lan-scan` — what's on the LAN.
- `network-ssh-hosts` — SSH reachability and aliases.
- `ubuntu-security` plugin — firewall rules and port exposure.
