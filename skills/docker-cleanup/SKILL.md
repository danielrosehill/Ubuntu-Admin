---
name: docker-cleanup
description: Reclaim disk space on a Docker host — report what's using space, then prune selectively (dangling and unused images, stopped containers, unused networks, build cache), trim oversized container json logs, find abandoned compose projects, and remove orphaned volumes only with explicit per-volume confirmation. Use when asked "clean up docker", "docker is using too much space", "prune docker", "remove old containers/images", "/var/lib/docker is full", "what can I delete from docker". Works on the local machine or a remote host over SSH.
---

# Docker cleanup

Report first, delete second, volumes last and only by name.

## Target

Local by default. Remote: `ssh <host> 'docker …'` or `DOCKER_HOST=ssh://<host> docker …`.

## 1. Space report

```bash
docker system df
docker system df -v > /tmp/docker-df.txt; sed -n '1,40p' /tmp/docker-df.txt
docker images --format '{{.Size}}\t{{.Repository}}:{{.Tag}}\t{{.CreatedSince}}' | sort -hr | head -20
docker images -f dangling=true -q | wc -l
docker ps -a --filter status=exited --filter status=created --format '{{.Names}}\t{{.Status}}\t{{.Image}}'
docker volume ls -f dangling=true
docker builder du 2>/dev/null | tail -3
sudo du -sh /var/lib/docker/containers/*/*-json.log 2>/dev/null | sort -hr | head
```

## 2. Abandoned stacks

```bash
docker compose ls -a                                 # stacks with state "exited"
# Containers whose compose working dir no longer exists
docker ps -a --format '{{.Names}}\t{{.Label "com.docker.compose.project.working_dir"}}' | while IFS=$'\t' read n d; do
  [ -n "$d" ] && [ ! -d "$d" ] && echo "orphaned: $n (was $d)"; done
```

If the host uses a convention such as `active/` and `inactive/` stack directories, stacks under `inactive/` with stopped containers are candidates. Ask before removing them.

## 3. Prune — safe tier (no data loss)

```bash
docker container prune -f --filter "until=168h"    # stopped > 7 days
docker image prune -f                              # dangling only
docker network prune -f
docker builder prune -f --filter "until=168h"
```

## 4. Prune — wider tier

```bash
docker image prune -a --filter "until=720h"        # any image not used by a container, older than 30 days
```

Images will be re-pulled when needed; on slow links or for images no longer published, this costs something.

## 5. Volumes — explicit only

Never run `docker volume prune` or `docker system prune --volumes` wholesale. A stopped stack's database volume is "dangling" too.

```bash
for v in $(docker volume ls -qf dangling=true); do
  echo "== $v"; docker volume inspect "$v" --format 'created {{.CreatedAt}} labels {{json .Labels}}'
  sudo du -sh "$(docker volume inspect -f '{{.Mountpoint}}' "$v")"
done
# After the user picks: docker volume rm <name> [<name>…]
```

The `com.docker.compose.project` label tells you which stack a volume belonged to.

## 6. Oversized logs

```bash
sudo truncate -s 0 /var/lib/docker/containers/<id>/<id>-json.log     # immediate relief, loses that log
```

Fix the cause with log rotation in `/etc/docker/daemon.json` (see `docker-setup`) or per-service `logging:` options in compose.

## Confirm before

- Every prune command — show what it would remove first (the space report above).
- `docker image prune -a`.
- Each volume, by name. Offer a backup first: `docker run --rm -v <vol>:/v -v "$PWD":/b alpine tar czf /b/<vol>.tgz -C /v .`
- Truncating any log.
- Removing a stack directory.

## Report

Space before and after (`docker system df`), what was removed per category, volumes kept vs removed, and any recommended config change (log rotation, scheduled `docker image prune` timer).

## Related

- `docker-health` — check before cleaning.
- `docker-setup` — log rotation and data-root.
- `storage-reclaim-space` — non-Docker space on the same host.
