---
name: system-diagnose
description: Triage a problem that is happening right now (or just happened) on an Ubuntu machine from fresh evidence — the last few minutes of the journal, kernel messages, failed units, OOM kills, coredumps — and return a diagnosis with the supporting log lines and a fix. Use when the user says "something just broke", "the server is acting up", "X crashed", "app keeps dying", "diagnose this", or describes a live symptom. Works on the local machine or a remote host over SSH.
---

# System diagnose

Live, evidence-first triage. Logs are freshest in the first minutes, so collect before theorising.

## Target

Local by default. Remote: `ssh <host> '<cmd>'`; for the whole collection block use `ssh <host> 'bash -s' <<'EOF' … EOF`. Reading the full journal needs root or membership of `adm`/`systemd-journal`. Without it, use `ssh -t <host> 'sudo journalctl …'`.

## 1. Pin down the symptom

From the user's description, note: what failed (app, unit, whole machine, network), when it started (a timestamp makes the journal query exact), and whether it repeats. If they named an app or unit, keep it as `$APP`.

## 2. Collect

```bash
SINCE="10 minutes ago"          # widen to "1 hour ago" or an exact "2026-01-31 14:05" as needed

journalctl --since "$SINCE" -p warning --no-pager | tail -80
journalctl -k --since "$SINCE" --no-pager | tail -40             # kernel: I/O errors, GPU resets, OOM
systemctl --failed --no-pager
systemctl --user --failed --no-pager 2>/dev/null                 # desktop sessions

# Crashes, kills and dumps
journalctl --since "$SINCE" --no-pager | grep -iE 'segfault|core dump|oom|killed process|watchdog|blocked for more than|i/o error|apparmor="DENIED"'
coredumpctl list --since "$SINCE" 2>/dev/null | tail -10          # needs systemd-coredump
ls -lt /var/crash 2>/dev/null | head                              # apport crash files (desktop)

# If an app or unit was named
journalctl -u "$APP" --since "$SINCE" --no-pager 2>/dev/null | tail -60
systemctl status "$APP" --no-pager 2>/dev/null
journalctl --since "$SINCE" --no-pager | grep -i "$APP" | tail -40
```

Quick context to rule out the obvious:

```bash
uptime; free -h; df -h -x tmpfs -x squashfs -x overlay | awk 'NR==1 || $5+0>=90'
```

## 3. Read the evidence

| Pattern | Likely meaning | Next step |
| --- | --- | --- |
| `Out of memory: Killed process` / `oom-kill` | Memory exhaustion | `system-resources` |
| `segfault at … in libX.so` | Crash in that library; often a version mismatch after an upgrade | Check `/var/log/apt/history.log` for a recent upgrade of the library or app |
| `Main process exited, code=exited, status=…` repeating | Unit crash loop | `services-check`, then `services-logs` |
| `I/O error`, `blk_update_request`, `EXT4-fs error`, `remounting read-only` | Disk or filesystem fault | `storage-drive-health`, `storage-filesystems`. Stop writes. |
| `No space left on device` | Full filesystem | `storage-reclaim-space` |
| `apparmor="DENIED"` | Confinement blocked an action (common with snaps) | `files-permissions` |
| `NVRM: Xid` / `amdgpu: ring … timeout` | GPU driver fault | `hardware-gpu` |
| `link is not ready` / `carrier lost` / DNS timeouts | Network | `network-diagnose` |
| `task … blocked for more than 120 seconds` | Storage or NFS hang | `storage-network-mounts`, `storage-drive-health` |

Check whether it is recurring: `journalctl --since "7 days ago" | grep -c '<distinctive phrase>'`.

For a hard freeze, a reboot with no logs, or kernel panics, the evidence is in previous boots and crash dumps. Hand over to the `linux-debugging` plugin (`investigate-last-crash`, `journal-inspect`, `boot-inspect`).

## Confirm before

This skill only reads. Before applying any fix it proposes, such as restarting a unit, killing a process or reinstalling a package, state the command and get a yes. On a remote server, say what the restart will interrupt.

## Report

1. **Diagnosis**: the most likely cause in one or two sentences, and how confident you are.
2. **Evidence**: the specific log lines, with timestamps.
3. **Fix**: commands to run now.
4. **Prevent**: a permanent fix if it is likely to recur, such as `Restart=on-failure`, memory limits or pinning a package.

If the fix worked and was non-trivial, offer `system-change-log`.

## Related

`system-status`, `system-resources`, `services-logs`, `services-check`. The `linux-debugging` plugin covers deep crash and boot forensics.
