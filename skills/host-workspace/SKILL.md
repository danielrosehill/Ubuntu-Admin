---
name: host-workspace
description: Create a working directory (optionally a private git repo) for administering one Ubuntu host or a small fleet over SSH. It holds a CLAUDE.md/AGENTS.md describing the host (SSH alias, role, desktop or server, key paths, services), context/ for profiles, backups/ for config copies and outputs/ for logs and reports, so later sessions start with the facts instead of rediscovering them. Use when the user says "set up a workspace for <host>", "I want to start managing <server>", "create a machine profile", or "new admin repo for my homelab box".
---

# Host workspace

An admin workspace is plain data: a folder that describes a machine and collects what you learn about it. The skills in this plugin read it when present. For example, `system-change-log` writes to `outputs/` and `system-config-edit` writes to `backups/`.

## Inputs

Ask only for what you cannot detect:

- **Workspace name**: kebab-case, such as `web-01-admin`.
- **Parent directory**: default to the current directory.
- **Host**: an SSH alias or `user@hostname` (or `local`). For several hosts, a list.
- **Role**: one line, such as "Docker host for home services", "family desktop" or "backup target".
- **Git**: local repo only (default), or also create a remote. If a remote, make it **private** by default, because workspaces collect hostnames, paths and layouts.

## Procedure

1. **Check reachability** (remote hosts):
   ```bash
   ssh -o BatchMode=yes -o ConnectTimeout=5 <host> true && echo ok
   ```
   If this fails, set up access first with `network-ssh-hosts`.

2. **Create the layout**:
   ```bash
   W=<parent>/<name>
   mkdir -p "$W"/{context,backups,outputs,docs}
   touch "$W"/backups/.gitkeep "$W"/outputs/.gitkeep
   ```

3. **Profile the host** with the `system-preflight` detector (JSON into `context/preflight.json`) and the `system-status` snapshot (into `outputs/status-<date>.md`). Optionally add `hardware-profile` output (into `context/hardware.md`).

4. **Write `CLAUDE.md`** from the template below, filling in what preflight found. If the user's agent reads `AGENTS.md` instead, write the same content there, or symlink one to the other.

5. **Git** (unless declined):
   ```bash
   cd "$W" && git init -b main && git add . && git commit -m "Workspace for <host>"
   # only if a remote was requested:
   gh repo create <name> --private --source=. --push
   ```

## CLAUDE.md template

```markdown
# <name> — admin workspace for <host>

You are administering the Ubuntu machine(s) below on the user's behalf.

## Host
| Field | Value |
| --- | --- |
| SSH alias | `<host>` |
| Role | <role> |
| OS | <Ubuntu version> (<desktop/server>) |
| Virtualization | <none/kvm/...> |
| Network | <NetworkManager/networkd> |
| Sudo | <passwordless / needs password → use ssh -t> |

Run remote commands as `ssh <host> '<cmd>'`. Refer to hosts by alias, never by hard-coded IP.

## Services that matter
<filled in after the first status sweep>

## Key paths
- App data / deployments: <path>
- Backups: <path>
- Logs of interest: <path>

## Rules
1. Back up before editing (`backups/`), validate before reloading.
2. Confirm before anything destructive or anything that can cut SSH access.
3. Log non-trivial changes to `outputs/` (one dated file per change).
4. Keep secrets out of this repo.
```

## Fleets

For several hosts, put one row per host in the Host table and one `context/<host>-preflight.json` per host. Loop read-only checks over them like this:

```bash
for h in host-a host-b; do echo "== $h"; ssh -o ConnectTimeout=5 "$h" 'uptime; systemctl --failed --no-legend'; done
```

## Confirm before

Creating a remote repository (and its visibility), and writing outside the chosen parent directory.

## Report

The workspace path, what was detected, and the git status. Suggest `system-status` or `services-check` as the next step.

## Related

`system-preflight`, `system-status`, `network-ssh-hosts`, `system-change-log`, `system-config-edit`.
