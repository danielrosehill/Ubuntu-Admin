---
name: services-check
description: Sweep systemd service state on an Ubuntu machine — failed units (system and user), degraded state, flapping services with high restart counts, what is enabled at boot, leftover units pointing at removed software, and the last errors of each problem unit. Read-only. Use when asked "check services", "any failed units?", "what's failing at boot", "why is the system degraded", "review startup services", "is <service> flapping", or after an upgrade or reboot. Optional unit glob filter. Works on the local machine or a remote host over SSH.
---

# Services check

Answers "which units are broken, unstable, or shouldn't be there?" without changing anything.

## Target

Local by default. Remote: `ssh <host> '<cmd>'`; for root-only commands `ssh -t <host> 'sudo <cmd>'`. User units only exist inside a login session, so on a remote server they usually only matter for accounts with `loginctl enable-linger`.

## 1. Overall state

```bash
systemctl is-system-running            # running | degraded | starting | maintenance
systemctl --failed --no-pager          # failed system units
systemctl --user --failed --no-pager 2>/dev/null   # failed user units (desktop / lingering users)
```

`degraded` means at least one unit failed. That is the headline.

## 2. Filter by glob (optional)

```bash
GLOB='nginx*'          # or 'docker*', '*.timer', …
systemctl list-units --all --no-pager "$GLOB"
systemctl list-unit-files --no-pager "$GLOB"
```

## 3. Last errors of each failed unit

```bash
for u in $(systemctl --failed --plain --no-legend | awk '{print $1}'); do
  echo "=== $u"
  systemctl status "$u" --no-pager -l | sed -n '1,12p'
  journalctl -u "$u" -b -n 20 --no-pager -p warning
done
```

Look for `code=exited, status=…` (the exit code), `Start request repeated too quickly` (crash loop hit the start limit), missing binaries or config files (`No such file or directory`), and permission errors.

## 4. Flapping / restart counts

```bash
# Units that restarted since boot (NRestarts is per unit since its last manual start)
for u in $(systemctl list-units --type=service --state=active --plain --no-legend | awk '{print $1}'); do
  n=$(systemctl show -p NRestarts --value "$u")
  [ "${n:-0}" -gt 0 ] && echo "$n $u"
done | sort -rn | head

# Start/stop churn in the last hour
journalctl --since "1 hour ago" --no-pager -o cat \
  | grep -E '^(Started|Stopped|Failed|.*Scheduled restart job)' | sort | uniq -c | sort -rn | head -20
```

More than 2 restarts in an hour = flapping.

## 5. What starts at boot

```bash
systemctl list-unit-files --type=service --state=enabled --no-pager
systemctl list-timers --all --no-pager
systemd-analyze blame --no-pager | head -15     # slowest units this boot
```

Review enabled services against the machine's role:

- **Server**: desktop-oriented services (`cups`, `bluetooth`, `ModemManager`, `avahi-daemon`, `whoopsie`/`apport` on headless boxes) are candidates to disable.
- **Desktop**: server daemons someone installed once to try (`apache2`, `mysql`, `postgresql`, `nginx`, `docker` on a machine that rarely uses it) slow boot and hold ports.

## 6. Leftover / broken units

```bash
systemctl list-units --all --no-pager --state=not-found      # referenced but unit file gone
systemctl list-unit-files --no-pager --state=masked          # masked — intentional?
ls /etc/systemd/system/*.service 2>/dev/null                 # admin-written units; check ExecStart exists:
for f in /etc/systemd/system/*.service; do
  bin=$(grep -m1 '^ExecStart=' "$f" | sed 's/^ExecStart=[-@!+]*//' | awk '{print $1}')
  [ -n "$bin" ] && [ ! -e "$bin" ] && echo "MISSING $bin <- $f"
done
dpkg -l | awk '/^rc/{print $2}'                              # removed packages with config (and units) left behind
```

## Desktop vs server

- Desktop: always include `systemctl --user --failed`; PipeWire, portals and tray apps fail there, not in the system manager.
- Server: pay attention to `*.mount` and `*.timer` failures (backups and network mounts fail silently otherwise).

## Confirm before

This skill is read-only. If the user wants fixes (restart, disable, mask, `systemctl reset-failed`, deleting stale unit files, purging `rc` packages), list the exact commands and get a yes first, then hand over to `services-manage`.

## Report

1. **State** — `running` / `degraded`, counts of failed system and user units.
2. **Failed** — each unit, exit status, one-line likely cause, quoted evidence line.
3. **Flapping** — units with restart counts.
4. **Boot review** — enabled services that look wrong for the role, slowest units.
5. **Leftovers** — not-found units, units with missing binaries, `rc` packages.
6. **Recommended actions** — per unit: restart / fix config / disable / mask / investigate.

## Related

- `services-manage` — apply the fixes.
- `services-logs` — longer log windows for a unit.
- `system-status` — whole-machine snapshot.
- `linux-debugging` plugin — boot-time failures and crash forensics in depth.
