---
name: docker-setup
description: Check for and install Docker on Ubuntu the right way — Docker Engine plus the compose and buildx plugins from Docker's official apt repository (keyring + deb822 source), with the trade-offs against Ubuntu's docker.io package and the snap; add a user to the docker group; configure /etc/docker/daemon.json (log rotation, data-root); optional rootless mode; verify. Use when asked "install docker", "set up docker on <host>", "docker compose not found", "permission denied on docker.sock", "move docker data to another disk", "docker logs filling the disk". Works on the local machine or a remote host over SSH.
---

# Docker setup

## Target

Local by default. Remote: `ssh -t <host> 'sudo …'`, or pipe a block with `ssh <host> 'sudo bash -s' <<'EOF' … EOF`.

## 1. What's installed

```bash
docker --version 2>/dev/null; docker compose version 2>/dev/null; docker-compose --version 2>/dev/null
dpkg -l | grep -E 'docker|containerd|runc' | awk '{print $2,$3}'
snap list docker 2>/dev/null
systemctl is-active docker containerd 2>/dev/null
id -nG "$USER" | grep -qw docker && echo "in docker group"
```

## 2. Choose the source

| Source | Pros | Cons |
| --- | --- | --- |
| Docker apt repo (`docker-ce`) — **default** | Current Engine, `docker compose` v2 and buildx plugins, matches upstream docs | Third-party repo |
| Ubuntu `docker.io` + `docker-compose-v2` | In the archive, security-patched by Ubuntu | Lags upstream |
| Snap `docker` | Confined, auto-updates | Confinement breaks bind mounts outside `$HOME`, odd paths; avoid on servers |

Never mix them. Remove the others first.

## 3. Install from Docker's repo

```bash
# Remove conflicting packages
for p in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do sudo apt-get remove -y $p 2>/dev/null; done
sudo snap remove docker 2>/dev/null

sudo apt-get update && sudo apt-get install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

. /etc/os-release
sudo tee /etc/apt/sources.list.d/docker.sources >/dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: ${UBUNTU_CODENAME:-$VERSION_CODENAME}
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl enable --now docker
```

If Docker hasn't published packages for a brand-new Ubuntu release yet, `apt update` 404s on the suite; use the previous LTS codename in `Suites:` or `docker.io` until it lands.

## 4. Non-root use

```bash
sudo usermod -aG docker <user>     # takes effect at next login (or: newgrp docker)
```

Membership of `docker` is equivalent to root on that host. For an unprivileged alternative, use rootless mode:

```bash
sudo apt-get install -y uidmap docker-ce-rootless-extras
dockerd-rootless-setuptool.sh install          # as the user, not root
systemctl --user enable --now docker && sudo loginctl enable-linger <user>
```

## 5. daemon.json

```bash
sudo tee /etc/docker/daemon.json >/dev/null <<'EOF'
{
  "log-driver": "json-file",
  "log-opts": { "max-size": "10m", "max-file": "3" },
  "live-restore": true
}
EOF
sudo systemctl restart docker
```

Log rotation only applies to containers created after the change; recreate existing ones (`docker compose up -d --force-recreate`).

Move storage to another disk (`"data-root": "/srv/docker"`): stop Docker, `sudo rsync -aHAX /var/lib/docker/ /srv/docker/`, set `data-root`, start, verify with `docker info | grep 'Docker Root Dir'`, and only then remove the old directory.

## 6. Verify

```bash
docker run --rm hello-world
docker compose version
docker info --format '{{.ServerVersion}} {{.Driver}} {{.DockerRootDir}} {{.LoggingDriver}}'
```

## Desktop vs server

- Desktop: Docker Desktop for Linux exists but runs a VM; plain Engine is lighter. Consider `sudo systemctl disable docker.service` and leaving `docker.socket` enabled so it starts on first use.
- Server: enable at boot, set log rotation before deploying anything, and put `data-root` on the data disk from day one.

## Confirm before

Removing existing Docker packages or the snap (containers and images from the old install may become unreachable), restarting the daemon on a host running containers, adding a user to `docker`, and changing `data-root`.

## Report

Source chosen, versions of Engine/compose/buildx, group membership, daemon.json contents, `hello-world` result.

## Related

- `docker-health`, `docker-cleanup`, `docker-compose-deploy`.
- `packages-repos` — managing the third-party apt source afterwards.
