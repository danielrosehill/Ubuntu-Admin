---
name: network-lan-scan
description: Discover the hosts on a local network from an Ubuntu machine — derive the subnet, sweep it with arp-scan or nmap ping scan, read the neighbour table, browse mDNS/Bonjour services with avahi, resolve names, look up vendors from MAC OUIs, and write a raw capture plus a human-readable Markdown LAN map. Use when asked "scan my LAN", "what devices are on my network", "find the IP of <device>", "make a map of the network", "who is at <ip>", "is there a new device on the network". Only for networks the user owns or administers. Works on the local machine or from a remote host over SSH.
---

# Network LAN scan

## Target

Local by default; scans the network the machine is attached to. To map a different LAN, run it on a host inside that LAN: `ssh <host> 'sudo arp-scan --localnet'`. Only scan networks the user owns or is authorised to scan — confirm if unclear.

## 1. Tools

```bash
sudo apt install arp-scan nmap avahi-utils ieee-data   # ieee-data provides the OUI vendor list
```

## 2. Work out the subnet

```bash
ip -br addr | grep -v '^lo'
IFACE=$(ip route show default | awk '{print $5; exit}')
CIDR=$(ip -o -4 addr show "$IFACE" | awk '{print $4; exit}')   # e.g. <lan-cidr>
echo "$IFACE $CIDR"
```

If the machine has several interfaces (Docker bridges, VPN, VLANs), ask which network to scan; never scan Docker bridges or VPN ranges by default.

## 3. Scan

```bash
OUT="lan-scan/$(date +%Y%m%d-%H%M)"; mkdir -p "$OUT"

# ARP — most complete on the local segment, includes devices that ignore ping
sudo arp-scan --interface="$IFACE" --localnet --plain | sort -t. -k4 -n > "$OUT/arp-scan.txt"

# nmap ping sweep with reverse DNS; adds hostnames
sudo nmap -sn "$CIDR" -oG "$OUT/nmap-sn.gnmap" >/dev/null

# Kernel neighbour cache — passive, no packets sent
ip neigh show dev "$IFACE" > "$OUT/neigh.txt"

# mDNS / Bonjour services (printers, Chromecasts, NAS, Home Assistant, …)
timeout 15 avahi-browse -art 2>/dev/null > "$OUT/avahi.txt"
```

Optional, for identified hosts only and with consent: `sudo nmap -sV --top-ports 20 <ip>` to see what a device serves.

## 4. Names and vendors

```bash
while read -r ip mac vendor; do
  name=$(getent hosts "$ip" | awk '{print $2}')
  [ -z "$name" ] && name=$(avahi-resolve -a "$ip" 2>/dev/null | awk '{print $2}')
  printf '%s\t%s\t%s\t%s\n' "$ip" "$mac" "${name:--}" "$vendor"
done < "$OUT/arp-scan.txt" > "$OUT/hosts.tsv"
```

MACs with the locally-administered bit set (second hex digit 2, 6, A or E) are randomised — phones and laptops with private Wi-Fi addresses — so the vendor is unknown, not suspicious.

## 5. LAN map

Write `$OUT/lan-map.md`:

```markdown
# LAN map — <cidr> — <date>

Gateway: <ip> (<vendor>)   Hosts found: <n>

| IP | Hostname | MAC | Vendor | Guess | Services (mDNS) |
| --- | --- | --- | --- | --- | --- |

## Groups
- Infrastructure (router, switches, APs)
- Servers / NAS
- Computers
- Phones / tablets
- IoT / smart home
- Unknown — worth identifying
```

"Guess" is inferred from vendor, hostname and services — label it as a guess. If an earlier scan exists, add a "Changes since <date>" section (new / gone hosts).

## Desktop vs server

Same commands. A desktop on Wi-Fi may not see wired-only devices if the AP isolates clients; a server on the wired LAN gives a fuller picture.

## Confirm before

- Scanning any network other than the machine's own LAN, or one the user hasn't confirmed they control.
- Port/service scans (`-sV`, `-p`) against hosts — those are noisier and can trip IDS.
- Installing packages.

## Report

Path to the output folder, host count, the map table (or its top), unknown devices worth identifying, and changes since the previous scan.

## Related

- `network-diagnose` — connectivity to a specific host.
- `network-ssh-hosts` — turn discovered hosts into SSH aliases.
- `hardware-power` — Wake-on-LAN needs the MACs found here.
