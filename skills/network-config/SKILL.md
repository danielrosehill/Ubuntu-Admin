---
name: network-config
description: Change network configuration on Ubuntu safely — find the renderer (netplan + systemd-networkd on servers, NetworkManager on desktops), set a static IP, gateway, DNS and routes in /etc/netplan, apply with netplan try for automatic rollback, edit NetworkManager connections with nmcli, set the hostname and /etc/hosts, and tune systemd-resolved DNS. Use when asked "set a static IP", "change DNS servers", "add a route", "rename the host", "switch from DHCP to static", "configure netplan", "set DNS for this connection". Works on the local machine or a remote host over SSH, with rollback protection.
---

# Network config

A wrong network change on a remote host locks you out. Every change here has a rollback.

## Target

Local by default. Remote: `ssh -t <host> 'sudo …'`. Before any remote change: confirm there is console or out-of-band access (hypervisor console, IPMI, physical access), and use `netplan try` so the change reverts itself if you lose the session.

## 1. Discover

```bash
ls -l /etc/netplan/
sudo netplan get                             # merged config
grep -h renderer /etc/netplan/*.yaml         # NetworkManager or networkd (default networkd)
networkctl list 2>/dev/null; nmcli -t con show 2>/dev/null
ip -br addr; ip route show default
resolvectl status | sed -n '1,30p'
hostnamectl
```

Ubuntu Desktop: netplan delegates everything to NetworkManager (on 24.04+ NM writes its connections back into `/etc/netplan/90-NM-*.yaml`). Ubuntu Server and cloud images: netplan → systemd-networkd, often with `50-cloud-init.yaml`.

## 2. Back up

```bash
sudo cp -a /etc/netplan "/root/netplan.bak.$(date +%Y%m%d-%H%M%S)"
```

## 3a. Server: static IP with netplan

```yaml
# /etc/netplan/60-static.yaml   (later files override earlier ones)
network:
  version: 2
  renderer: networkd
  ethernets:
    <iface>:
      dhcp4: false
      addresses: [<ip>/<prefix>]
      routes:
        - to: default
          via: <gateway>
      nameservers:
        addresses: [<dns1>, <dns2>]
        search: [<domain>]
```

```bash
sudo chmod 600 /etc/netplan/*.yaml          # netplan warns on world-readable files
sudo netplan generate                       # syntax check
sudo netplan try --timeout 120              # applies; reverts unless you press Enter in time
sudo netplan apply                          # only after try succeeded (local console)
```

If cloud-init owns `50-cloud-init.yaml`, stop it regenerating: `echo 'network: {config: disabled}' | sudo tee /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg`, and edit that file or override it.

`netplan try` doesn't support every change (e.g. some bond/bridge changes); then use a scheduled revert:

```bash
sudo bash -c 'sleep 300 && cp -a /root/netplan.bak.<ts>/. /etc/netplan/ && netplan apply' &   # cancel with kill if all is well
```

## 3b. Desktop: NetworkManager with nmcli

```bash
nmcli con show
nmcli con mod "<connection>" ipv4.method manual ipv4.addresses <ip>/<prefix> ipv4.gateway <gateway> ipv4.dns "<dns1> <dns2>"
nmcli con mod "<connection>" ipv4.ignore-auto-dns yes        # use only the DNS you set
nmcli con up "<connection>"
nmcli con mod "<connection>" ipv4.method auto ipv4.addresses "" ipv4.gateway "" ipv4.dns ""   # back to DHCP
```

## 4. Extra routes

```bash
sudo ip route add <cidr> via <gw>            # temporary, for testing
```

Persist under `routes:` in netplan, or `nmcli con mod "<connection>" +ipv4.routes "<cidr> <gw>"`.

## 5. DNS (systemd-resolved)

Per-link DNS belongs in netplan/NM as above. Global fallbacks and options:

```ini
# /etc/systemd/resolved.conf.d/dns.conf
[Resolve]
DNS=<dns1> <dns2>
Domains=~.
DNSSEC=no
```

```bash
sudo systemctl restart systemd-resolved && resolvectl status
```

Keep `/etc/resolv.conf` as the symlink to `../run/systemd/resolve/stub-resolv.conf`.

## 6. Hostname

```bash
sudo hostnamectl set-hostname <new-name>
sudo sed -i "s/^127\.0\.1\.1.*/127.0.1.1\t<new-name>/" /etc/hosts     # keep sudo from complaining
grep -q preserve_hostname /etc/cloud/cloud.cfg 2>/dev/null && sudo sed -i 's/^preserve_hostname:.*/preserve_hostname: true/' /etc/cloud/cloud.cfg
```

## 7. Verify

```bash
ip -br addr; ip route; resolvectl query ubuntu.com; ping -c 2 <gateway>
```

Then reconnect over SSH to the new address (if it changed) and update `~/.ssh/config` (`network-ssh-hosts`).

## Confirm before

All of it. Specifically, state before running: the exact file and the diff, whether the current SSH session uses the interface being changed, and the rollback path. Never `netplan apply` remotely without a successful `netplan try` first. Changing the hostname affects sudo, mail, monitoring and SSH known_hosts.

## Report

Renderer, old → new values, files written (with backup path), verification output, and anything the user must update elsewhere (DHCP reservation, DNS records, SSH config).

## Related

- `network-diagnose` — check before and after.
- `network-ssh-hosts` — update aliases after an IP or hostname change.
- `system-config-edit` — general backup-validate-reload pattern.
