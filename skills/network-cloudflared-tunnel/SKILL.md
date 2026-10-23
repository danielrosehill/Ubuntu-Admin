---
name: network-cloudflared-tunnel
description: Check and manage a Cloudflare Tunnel (cloudflared) on Ubuntu — install from Cloudflare's apt repository, service status and logs, locally-managed config.yml ingress rules or token-based remotely-managed tunnels, cloudflared tunnel list/info, validate ingress and test which rule a URL hits, check the origin service answers locally, and restart safely. Use when asked "is the tunnel up", "site behind cloudflared is down", "502 / bad gateway from Cloudflare", "add a hostname to the tunnel", "install cloudflared", "check tunnel status on <host>". Works on the local machine or a remote host over SSH.
---

# Network cloudflared tunnel

## Target

Local by default. Remote: `ssh -t <host> 'sudo …'`. Remotely-managed (token) tunnels are configured in the Cloudflare dashboard; this skill can check them but ingress edits happen there.

## 1. Install (if missing)

```bash
sudo mkdir -p --mode=0755 /usr/share/keyrings
curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | sudo tee /usr/share/keyrings/cloudflare-main.gpg >/dev/null
echo "deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared any main" \
  | sudo tee /etc/apt/sources.list.d/cloudflared.list
sudo apt update && sudo apt install cloudflared
cloudflared --version
```

## 2. Status

```bash
systemctl status cloudflared --no-pager -l | sed -n '1,15p'
systemctl list-units --all --no-pager 'cloudflared*'           # may be several (one per tunnel)
systemctl cat cloudflared | grep ExecStart                      # --config file, or --token (remotely managed)
journalctl -u cloudflared --since "1 hour ago" --no-pager | tail -40
journalctl -u cloudflared --since "24 hours ago" -p err --no-pager | tail -20
```

Healthy logs show `Registered tunnel connection` for (usually) four connections to two Cloudflare locations. Repeated `Unauthorized`/`token` errors → credentials; `dial tcp … connection refused` → the origin service is down; `context deadline exceeded` to Cloudflare → outbound network (port 7844 UDP/TCP, QUIC blocked → set `protocol: http2`).

## 3. Configuration (locally managed tunnels)

```bash
sudo ls -l /etc/cloudflared/ ~/.cloudflared/ 2>/dev/null
sudo cat /etc/cloudflared/config.yml
```

```yaml
tunnel: <tunnel-uuid>
credentials-file: /etc/cloudflared/<tunnel-uuid>.json
ingress:
  - hostname: app.<domain>
    service: http://localhost:8080
  - hostname: ssh.<domain>
    service: ssh://localhost:22
  - service: http_status:404          # required catch-all, must be last
```

```bash
sudo cloudflared tunnel --config /etc/cloudflared/config.yml ingress validate
sudo cloudflared tunnel --config /etc/cloudflared/config.yml ingress rule https://app.<domain>   # which rule matches
cloudflared tunnel list            # needs ~/.cloudflared/cert.pem from `cloudflared tunnel login`
cloudflared tunnel info <name-or-uuid>
```

## 4. Origin check

For each ingress `service:` URL, confirm it answers from this host:

```bash
curl -sS -o /dev/null -w '%{http_code}\n' http://localhost:8080
docker ps --format '{{.Names}}\t{{.Ports}}' | grep 8080          # if the origin is a container
```

A 502 at the edge with a healthy tunnel almost always means this check fails (wrong port, service bound to another interface, container on a network cloudflared can't reach). If cloudflared runs in a container, `localhost` is the container — use the service name on a shared Docker network.

## 5. Add a hostname (locally managed)

1. Back up `config.yml`, add the rule above the catch-all.
2. `ingress validate`.
3. Create the DNS route: `cloudflared tunnel route dns <tunnel> app.<domain>`.
4. `sudo systemctl restart cloudflared`, watch logs, `curl -I https://app.<domain>`.

## 6. Connectivity to Cloudflare

```bash
resolvectl query region1.v2.argotunnel.com
curl -sS -o /dev/null -w '%{http_code}\n' https://api.cloudflare.com/client/v4/ips
```

## Desktop vs server

Almost always a server concern. On a desktop, `cloudflared access` (client side) is more common than a tunnel; that needs no service.

## Confirm before

Installing the package, editing `config.yml`, creating DNS routes (changes public DNS), restarting `cloudflared` (drops every hostname on the tunnel briefly), and deleting tunnels or credential files. Never print the contents of credentials JSON or tokens.

## Report

Service state, connection count, tunnel id/name, ingress table with per-origin check results, errors with evidence lines, and what was changed.

## Related

- `docker-compose-deploy` — the origin services.
- `services-logs`, `services-manage` — the cloudflared unit.
- `network-diagnose` — outbound connectivity.
- `ubuntu-security` plugin — access policies and exposure review.
