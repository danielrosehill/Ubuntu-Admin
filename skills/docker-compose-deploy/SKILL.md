---
name: docker-compose-deploy
description: Deploy, update and roll back Docker Compose stacks on an Ubuntu host — list stacks, keep one directory (optionally one git repo) per stack, validate with docker compose config, pull, bring up, verify health, and roll back to the previous image or git revision; handle .env files and secrets without committing them. Use when asked "deploy <service>", "update the <stack> containers", "pull new images and restart", "roll back <stack>", "set up a new compose stack", "list deployments on <host>". Works on the local machine or a remote host over SSH.
---

# Docker Compose deploy

## Target

Local by default. Remote: run in the stack directory over SSH, `ssh <host> 'cd <stack-dir> && docker compose …'`, or set `DOCKER_HOST=ssh://<host>` (compose then uses local files against the remote daemon — bind-mount paths are resolved on the remote host).

## Convention (suggested, adapt to what the host already does)

```
<stacks-root>/                 e.g. /srv/stacks or ~/stacks
  <stack>/
    compose.yaml
    .env                       # secrets and host-specific values, git-ignored
    .env.example               # documented template, committed
    README.md                  # what it is, ports, data paths, how to restore
    config/                    # mounted config files
```

- One directory per stack; optionally one git repo per stack, so each deploy is a commit.
- Persistent data lives outside the stack directory (e.g. `/srv/data/<stack>`) or in named volumes, and is documented in the README.
- Pin image tags (`image: nginx:1.27`, not `latest`) so rollback means something.
- Every long-running service has `restart: unless-stopped` and, where possible, a `healthcheck:`.

## 1. Inventory

```bash
docker compose ls -a
docker ps --format 'table {{.Label "com.docker.compose.project"}}\t{{.Names}}\t{{.Status}}\t{{.Image}}'
for d in <stacks-root>/*/; do echo "== $d"; git -C "$d" status --short 2>/dev/null; git -C "$d" log -1 --format='%h %cr %s' 2>/dev/null; done
```

## 2. Validate

```bash
cd <stack-dir>
docker compose config --quiet && echo "compose OK"
docker compose config | less          # rendered, with .env substituted — check before deploying
grep -q '^\.env$' .gitignore 2>/dev/null || echo "WARNING: .env not git-ignored"
```

## 3. Record the rollback point

```bash
docker compose images --format json | jq -r '.[] | "\(.ContainerName) \(.Repository):\(.Tag) \(.ID)"' > .last-deploy-images
git rev-parse HEAD 2>/dev/null > .last-deploy-rev
```

## 4. Deploy / update

```bash
docker compose pull
docker compose up -d --remove-orphans
docker compose ps
```

For a config-only change: `docker compose up -d` recreates only changed services. Force: `--force-recreate <service>`.

## 5. Verify

```bash
sleep 10; docker compose ps --format 'table {{.Service}}\t{{.State}}\t{{.Health}}'
docker compose logs --since 2m --tail 50
curl -fsS -o /dev/null -w '%{http_code}\n' http://localhost:<port>/<health-path>
```

Deploy is done when every service is `running` and `healthy` (or has no healthcheck and the endpoint answers).

## 6. Roll back

```bash
# Git-tracked stack
git checkout <previous-rev> -- compose.yaml && docker compose up -d
# Image-only change: pin the previous tag or digest from .last-deploy-images in compose.yaml, then
docker compose up -d
```

Database migrations run by the new version may not be reversible — check the app's release notes before rolling back data-bearing services.

## 7. New stack

Create the directory with `compose.yaml`, `.env.example`, `.gitignore` (`.env`, data dirs), `README.md`; `git init`; validate; deploy; commit. If the user wants a remote repo, create it private by default since compose files reveal internal topology.

## Desktop vs server

Same workflow. On a desktop, `restart: unless-stopped` will start the stack at every boot — use `restart: "no"` for dev stacks.

## Confirm before

- `docker compose down` (and never `down -v` without naming the volumes it deletes).
- `--remove-orphans` when the orphan list is non-empty.
- Pulling new images for data-bearing services (databases) — check the major version.
- Rollbacks that cross a schema migration.
- Creating a remote git repo.

## Report

Stack, previous → new image tags or git revision, service states and health after deploy, endpoint check result, rollback command.

## Related

- `docker-health` — diagnose a failing service after deploy.
- `docker-setup` — install Engine and compose plugin.
- `system-config-edit` — backup-before-edit for mounted config files.
- `network-cloudflared-tunnel` — exposing a stack publicly.
