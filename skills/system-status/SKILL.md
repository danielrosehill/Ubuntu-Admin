---
name: system-status
description: One-shot health snapshot of an Ubuntu machine — OS and kernel, uptime and load, memory and swap, disk and inode fill, failed units, recent errors, pending updates and reboot flag, plus Docker and desktop add-ons when present. Read-only. Use when asked "how is this box doing", "status of <host>", "health check", "system checkup", "is anything wrong with the server", or as the first step before any other admin task. Works on the local machine or a remote host over SSH.
---

# System status

A fast, read-only sweep that answers "is this machine healthy, and if not, where should I look next?". It changes nothing.

## Target

Local by default. For a remote host, run the same commands over SSH:

```bash
ssh <host> '<command>'                      # one command
ssh <host> 'bash -s' < script.sh            # a local script, executed remotely
ssh -t <host> 'sudo <command>'              # needs root and a password prompt
```

`<host>` is an alias from `~/.ssh/config` or `user@hostname`. If no host was named and the conversation is about a remote machine, ask which one.

## Fastest path: the bundled script

`scripts/status-snapshot.sh` collects everything below in one pass and prints Markdown sections. It needs no root (sections that do are skipped with a note).

```bash
# Locate the script. ${CLAUDE_PLUGIN_ROOT} is set when the plugin is installed;
# otherwise use a clone of https://github.com/danielrosehill/Ubuntu-Admin
SCRIPT="${CLAUDE_PLUGIN_ROOT:-$HOME/Ubuntu-Admin}/scripts/status-snapshot.sh"
[ -f "$SCRIPT" ] || git clone --depth 1 https://github.com/danielrosehill/Ubuntu-Admin "$HOME/Ubuntu-Admin"

bash "$SCRIPT"                         # local
ssh <host> 'bash -s' < "$SCRIPT"       # remote
```

## Manual sweep (if the script is unavailable)

```bash
# Identity
hostnamectl                                   # hostname, OS, kernel, virtualization, hardware model
. /etc/os-release; echo "$PRETTY_NAME"
uname -r

# Load and uptime
uptime                                        # compare load averages to `nproc`
cat /proc/pressure/{cpu,memory,io} 2>/dev/null # PSI: sustained avg10 > 10 is real pressure

# Memory
free -h
swapon --show
zramctl 2>/dev/null

# Disks (real filesystems only) and inodes
df -hT -x tmpfs -x devtmpfs -x squashfs -x overlay -x efivarfs
df -i -x tmpfs -x devtmpfs -x squashfs -x overlay | awk 'NR==1 || $5+0 >= 80'

# Services
systemctl --failed --no-pager
systemctl --user --failed --no-pager 2>/dev/null   # desktop sessions only
systemctl is-system-running                        # running | degraded | ...

# Recent errors (last hour)
journalctl -p err --since "1 hour ago" --no-pager | tail -30

# Updates and reboot flag
apt list --upgradable 2>/dev/null | tail -n +2 | wc -l
[ -f /var/run/reboot-required ] && cat /var/run/reboot-required /var/run/reboot-required.pkgs 2>/dev/null

# Who and when
who
last -x -n 5 reboot shutdown 2>/dev/null
```

### Add-ons — run only when relevant

```bash
# Docker host
command -v docker >/dev/null && {
  docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}'
  docker ps -a --filter status=exited --filter status=dead --format '{{.Names}}: {{.Status}}'
  docker system df
}

# Snaps (Ubuntu ships several by default)
snap list 2>/dev/null | wc -l; snap changes 2>/dev/null | tail -5

# Temperatures (lm-sensors installed)
command -v sensors >/dev/null && sensors | grep -E '^(Package|Tctl|Composite|edge)' 

# Ubuntu Pro / ESM coverage
pro status 2>/dev/null | head -15
```

## Desktop vs server

- **Desktop**: also check user units (`systemctl --user --failed`), the session type (`echo $XDG_SESSION_TYPE`), and GPU state (see `hardware-gpu`). Snap refresh activity is a common cause of "random" slowdowns.
- **Server**: also note listening services (`ss -tlnp`), logged-in users, and whether the host is a VM (`systemd-detect-virt`). Uptime of many months usually means a pending kernel reboot.

## Thresholds to flag

| Signal | Flag when |
| --- | --- |
| Disk use | ≥ 85% on any real filesystem; ≥ 80% inodes |
| Load average (5 min) | > number of CPUs (`nproc`) |
| Memory | `available` < 10% of total, or swap > 50% used |
| PSI memory `some avg60` | > 10 |
| Failed units | any |
| `reboot-required` | present |
| Errors in the last hour | repeated lines from the same unit |

## Report

Return a short Markdown summary:

1. **Verdict** — healthy / attention / problem, in one line.
2. **Findings** — only what crossed a threshold, each with the evidence line.
3. **Next step** — the specific skill to run next (`services-check`, `system-diagnose`, `storage-reclaim-space`, `packages-updates`, …).

Do not paste the whole raw output back; quote the lines that matter.

## Related

- `system-diagnose` — when something is wrong right now.
- `system-resources` — slowdown, memory pressure, runaway processes.
- `performance-audit` — repeatable resource spot check with a per-host trend log.
- `services-check`, `docker-health`, `storage-drive-health` — drill-downs.
