---
name: performance-audit
description: Repeatable, read-only performance audit of an Ubuntu machine, desktop or server — load vs cores, pressure stall (PSI), memory and active swapping, OOM kills, disk space and inodes, top processes, Docker containers near their memory limit or restart-looping, temperatures and failed units — ranked into a short report with a JSON block, and logged so trends across audits show. Reuses a saved hardware profile per host instead of re-profiling every time. Use for "audit performance", "how is the machine coping", "performance check", "resource audit", "is the server OK for resources", periodic spot checks, or before and after adding a heavy service. Works locally or over SSH.
---

# Performance audit

A spot check for a machine that is not (yet) known to be broken. For a live slowdown, use `system-resources`; for a fault, `system-diagnose`.

Read-only. Takes about 10 seconds per host.

## Target

Local by default. Remote: pipe `scripts/perf-audit.sh` over SSH (step 1). Without passwordless sudo, the kernel OOM count comes back `null`; say so rather than reporting zero.

## Where profiles live

```
${CLAUDE_USER_DATA:-$HOME/.claude-user-data}/host-profiles/
  <hostname>.md            # hardware profile (written by hardware-profile)
  <hostname>.perf-log.md   # one dated line per audit, newest last
```

`<hostname>` is the short `hostname` output, lowercased. This directory is the user's private data, not this plugin: never write profiles into the plugin repo. If the directory is a git repository, commit and push after writing.

## 0. Profile: load, or create once

1. Read `host-profiles/<hostname>.md`. Its top fenced JSON block holds `cpu_model`, `cores`, `ram_total_gb`, `disks`, `kernel`, `profiled`.
2. **No profile:** run the `hardware-profile` skill for this host and save it there. Do this once per machine, not per audit.
3. **Profile present:** cheap drift check only. Compare against the profile:
   ```bash
   grep -m1 'model name' /proc/cpuinfo; nproc
   awk '/MemTotal/{printf "%.1f GB\n",$2/1048576}' /proc/meminfo
   lsblk -d -n -o NAME,SIZE,MODEL | grep -vE '^(loop|zram)'; uname -r
   ```
   CPU, RAM or disks changed: re-run `hardware-profile` and overwrite. Only the kernel changed: update the `kernel` field and `profiled` date in place. Otherwise leave the file alone.

Use the profile to judge numbers: cores for load, RAM total for headroom, disk type (SD, HDD, NVMe) for I/O wait, and any notes it holds (e.g. "swap on SD card", "runs a VM with 8 GB pinned").

## 1. Collect

```bash
SCRIPT="${CLAUDE_PLUGIN_ROOT:-$HOME/Ubuntu-Admin}/scripts/perf-audit.sh"
bash "$SCRIPT"                        # local
ssh <host> 'bash -s' < "$SCRIPT"      # remote
```

The script prints one JSON object: load and load per core, PSI averages, memory and swap, a 5-second `vmstat` average (swap in/out, I/O wait), filesystems with inode use, disks, top CPU and memory processes, 7-day OOM kills (kernel and systemd-oomd), failed units, max temperature, Docker containers (restarts, OOM-killed, memory against limit) and any history-keeping monitor it can see (Beszel, Netdata, node-exporter, Prometheus, sysstat, …). On a Raspberry Pi it adds `vcgencmd` temperature and throttling flags.

If the script is not to hand, the same facts come from: `uptime; nproc`, `cat /proc/pressure/*`, `free -h`, `vmstat 1 5`, `df -h; df -i`, `ps --sort=-%cpu`, `journalctl -k --since -7d | grep -i oom`, `systemctl --failed`, `sensors`, `docker stats --no-stream`.

## 2. Judge

| Check | Fine | Flag |
| --- | --- | --- |
| Load per core (5 min) | < 0.7 | > 1.0 sustained |
| PSI `memory_some_avg60` / `io_some_avg60` | < 1 | > 5 (tasks waiting) |
| Memory available | > 20 % | < 10 %, or falling across audits |
| **Active** swapping (`swap_in/out_kbps`) | ~0 | > 0 sustained. Swap *used* with zero si/so is idle pages parked, not pressure; say so |
| OOM kills, 7 days | 0 | any: name the victim from `journalctl -k` |
| Filesystem / inodes | < 80 % | > 90 % |
| I/O wait | < 5 % | > 10 %, especially on SD/HDD |
| Containers | no limit hit | ≥ 85 % of memory limit, restarts ≥ 3, `oom_killed` |
| Temperature | < 75 °C | > 85 °C, or any throttling flag |
| Failed units | none | any |

A container at its memory limit that also burns CPU is usually thrashing inside the cap (garbage collection, reclaim). Raising the limit rarely helps if it grows into whatever it gets: look at its own config first (collection interval, retention, caches).

## 3. Trend

Append one line to `host-profiles/<hostname>.perf-log.md` (create it with a header if missing):

```
| 2026-01-31 | load/core 0.13 | mem avail 49% | swap 5.2G used, si/so 0 | / 26% | oom 0 | top: cadvisor 71% cpu | flags: cadvisor at mem limit |
```

Compare with the previous lines and mention what changed. Skip the log only if the user says this is a throwaway check.

## Desktop vs server

- **Desktop / laptop**: browsers, Electron apps, indexers and the compositor dominate; `systemd-oomd` kills whole app scopes. Low `available` while a browser is open is normal; active swapping is not.
- **Server**: per-container usage is the main view. Note containers with **no** memory limit next to a large one, and timers that fire during the audit window (`systemctl list-timers`).
- **History**: if `history_monitoring` is empty or only `sysstat`, say that past spikes cannot be checked; suggest a light agent (e.g. Beszel) only if the user wants history, and only once.

## Confirm before

Nothing here changes the system. Everything it might recommend does, so each needs a yes: killing or restarting a process or container, changing a memory limit, installing a monitoring agent, changing swap or `vm.swappiness`.

## Report

1. **Verdict**: one line (comfortable / tight on X / under pressure).
2. **Flags**, ranked by impact, each with the number and the culprit.
3. **Since last audit**: what moved, from the perf log.
4. **Suggested actions**, each marked as needing confirmation.
5. A fenced JSON block for agents: `{"host", "audited", "verdict", "flags":[{"check","value","culprit"}], "profile": "<path>"}`.

## Related

- `hardware-profile` — creates the host profile this skill reads.
- `system-resources` — drill into a live slowdown the audit found.
- `system-status` — wider health snapshot (updates, reboot flag, errors).
- `docker-health` — a flagged container in detail.
- `storage-reclaim-space` — a full filesystem.
