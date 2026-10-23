---
name: docker-health
description: Health check and troubleshooting for a Docker host on Ubuntu — daemon state, container status (unhealthy, restarting, exited, dead), restart counts, live resource use, recent events, per-container logs, networks and port bindings, volume mounts and permission/UID problems, and disk use. Read-only by default. Use when asked "check docker", "is everything up on the docker host", "container keeps restarting", "container unhealthy", "permission denied in volume", "containers can't reach each other", "what's running on <host>". Works on the local machine or a remote host over SSH.
---

# Docker health

## Target

Local by default. Remote: `ssh <host> 'docker …'` (works without sudo if the SSH user is in `docker`; otherwise `ssh -t <host> 'sudo docker …'`). For many calls, `export DOCKER_HOST=ssh://<host>` and run the local CLI against the remote daemon.

## 1. Daemon

```bash
systemctl is-active docker containerd
docker info --format 'Server {{.ServerVersion}} | Containers {{.Containers}} (running {{.ContainersRunning}}, stopped {{.ContainersStopped}}) | Root {{.DockerRootDir}}'
journalctl -u docker --since "1 hour ago" -p warning --no-pager | tail -20
```

## 2. Container overview

```bash
docker ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}\t{{.Ports}}'
docker ps --filter health=unhealthy --format '{{.Names}}'
docker ps -a --filter status=restarting --filter status=exited --filter status=dead --format '{{.Names}}\t{{.Status}}'
docker ps -q | xargs -r docker inspect --format '{{.RestartCount}} {{.Name}} {{.State.ExitCode}} {{.State.OOMKilled}}' | sort -rn | head
docker compose ls                                   # stacks and their state
docker stats --no-stream --format 'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}'
docker events --since 1h --until "$(date +%s)" --filter type=container --format '{{.Time}} {{.Actor.Attributes.name}} {{.Action}}' | tail -30
```

Flag: anything unhealthy, restart count > 3, `OOMKilled=true`, exit codes 137 (killed / OOM), 139 (segfault), 1 (app error).

## 3. Drill into one container

```bash
C=<container>
docker logs --since 30m --tail 200 "$C" 2>&1
docker inspect "$C" --format '{{json .State}}' | jq
docker inspect "$C" --format '{{json .State.Health}}' | jq '.Log[-3:]'   # last healthcheck results
docker inspect "$C" --format '{{range .Mounts}}{{.Type}} {{.Source}} -> {{.Destination}} rw={{.RW}}{{"\n"}}{{end}}'
docker exec "$C" id                                                       # UID/GID the process runs as
```

## 4. Volume and permission problems

```bash
docker volume ls
docker volume ls -f dangling=true                       # not used by any container
docker system df -v | sed -n '/Local Volumes/,/Build cache/p'
# Compare the container UID with host ownership of a bind mount
stat -c '%u:%g %a %n' <host-path>
```

`Permission denied` inside a container on a bind mount almost always means the container's UID doesn't own the host directory. Fixes, least invasive first: set `user: "<uid>:<gid>"` in compose, use the image's `PUID`/`PGID` env vars if it supports them, or `sudo chown -R <uid>:<gid> <host-path>`. On rootless Docker, UIDs are shifted by `/etc/subuid`.

## 5. Networking

```bash
docker network ls
docker network inspect <network> --format '{{range .Containers}}{{.Name}} {{.IPv4Address}}{{"\n"}}{{end}}'
docker exec <a> getent hosts <b>                       # name resolution between containers (same user-defined network only)
ss -tlnp | grep docker-proxy                            # published ports on the host
```

Containers resolve each other by name only on user-defined networks, not the default `bridge`. Port already in use → `ss -tlnp | grep :<port>` to find the owner.

## 6. Disk

```bash
docker system df
du -sh "$(docker info -f '{{.DockerRootDir}}')" 2>/dev/null
sudo find /var/lib/docker/containers -name '*-json.log' -size +100M -exec ls -lh {} \;
```

## Desktop vs server

Same checks. On a desktop, a stopped daemon is often intentional (socket activation). On a server, the daemon must be enabled and every long-lived container should have a restart policy (`docker inspect -f '{{.HostConfig.RestartPolicy.Name}}' <c>`).

## Confirm before

Read-only. Restarting containers, `chown` on host paths, recreating containers, or restarting the daemon — propose and get approval first.

## Report

1. **Verdict** — daemon up/down, N running / N problem containers.
2. **Problems** — each container: state, restart count, exit code, cause, evidence log line.
3. **Resources** — heaviest containers, disk use.
4. **Recommended actions** — specific commands per problem.

## Related

- `docker-cleanup` — reclaim space.
- `docker-compose-deploy` — redeploy or roll back a stack.
- `docker-setup` — daemon.json, log rotation, data-root.
- `services-logs` — host-side logs.
