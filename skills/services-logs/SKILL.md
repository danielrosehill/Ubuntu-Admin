---
name: services-logs
description: Fetch, save and summarise logs on an Ubuntu machine — journal by unit, priority and time window, a dated copy saved locally, repeating messages grouped, a "noteworthy, not just errors" review (restarts, OOM kills, kernel warnings, auth events), live following, classic /var/log files, Docker container logs, and journald disk usage. Use when asked "show me the logs", "what happened on <host> last night", "anything noteworthy in the logs", "tail the logs", "errors from <service>", "why is the journal so big". Works on the local machine or a remote host over SSH.
---

# Services logs

Pull a log window, keep a copy, and say what matters in it.

## Target

Local by default. Remote: `ssh <host> 'journalctl …' > local-file`. Reading the full system journal needs root or membership of `adm`/`systemd-journal`; otherwise use `ssh -t <host> 'sudo journalctl …'`.

## 1. Pick the window

Defaults: last hour, all units. Narrow with:

```bash
journalctl --since "1 hour ago" --no-pager                   # or "2026-01-31 22:00" / "yesterday"
journalctl -u <unit> --since today --no-pager                # one unit (repeat -u for several)
journalctl -p warning --since "1 hour ago" --no-pager        # warning and worse
journalctl -b -p err --no-pager                              # errors this boot
journalctl -k --since "1 hour ago" --no-pager                # kernel only
journalctl _COMM=<binary> --since today                      # by process name
journalctl -u <unit> -o json --since "1 hour ago"            # structured, for parsing
```

## 2. Save a dated copy

```bash
mkdir -p outputs/logs
F="outputs/logs/journal-${HOST:-$(hostname)}-$(date +%Y%m%d-%H%M).log"
ssh <host> 'journalctl --since "1 hour ago" --no-pager' > "$F"     # remote
journalctl --since "1 hour ago" --no-pager > "$F"                  # local
wc -l "$F"
```

Use the workspace's `outputs/logs/` if one exists, else a scratch directory. Tell the user the path.

## 3. Summarise

```bash
# Messages per unit
journalctl --since "1 hour ago" -o json --no-pager | jq -r '._SYSTEMD_UNIT // .SYSLOG_IDENTIFIER' | sort | uniq -c | sort -rn | head
# Repeating messages, numbers stripped so similar lines group together
journalctl --since "1 hour ago" -o cat --no-pager | sed -E 's/[0-9]+/N/g' | sort | uniq -c | sort -rn | head -20
# Priority counts
for p in crit err warning; do printf '%s ' $p; journalctl --since "1 hour ago" -p $p..$p -q --no-pager | wc -l; done
```

## 4. Noteworthy, not just errors

```bash
journalctl --since "24 hours ago" --no-pager -o cat | grep -E 'Scheduled restart job|Main process exited|Start request repeated' | sort | uniq -c
journalctl -k --since "24 hours ago" --no-pager | grep -iE 'oom|killed process|segfault|i/o error|call trace|hung task|link is (up|down)'
journalctl --since "24 hours ago" -u ssh -u systemd-logind --no-pager | grep -E 'Accepted|session opened|New session' | tail
journalctl --list-boots --no-pager | tail -5          # unexpected reboots
grep -h 'upgrade\|install ' /var/log/dpkg.log | tail   # what changed recently
```

Package changes, reboots and restarts are context for errors that follow them.

## 5. Follow live

```bash
journalctl -f                       # everything
journalctl -f -u <unit> -p warning  # one unit
ssh <host> 'journalctl -f -u <unit>'
```

## 6. Non-journal sources

```bash
ls -lhS /var/log | head                         # largest log files
sudo tail -n 100 /var/log/syslog                # rsyslog copy (if rsyslog installed)
sudo tail -n 100 /var/log/auth.log
sudo tail -n 100 /var/log/apt/history.log
sudo tail -n 100 /var/log/nginx/error.log       # app-specific
docker logs --since 1h --timestamps <container> 2>&1 | tail -100
docker compose logs --since 1h <service>
```

## 7. Journal disk usage

```bash
journalctl --disk-usage
cat /etc/systemd/journald.conf.d/*.conf 2>/dev/null; grep -E '^\s*SystemMaxUse' /etc/systemd/journald.conf
```

To cap: drop-in `/etc/systemd/journald.conf.d/size.conf` with `[Journal]` / `SystemMaxUse=500M`, then `sudo systemctl restart systemd-journald`. One-off trim: `sudo journalctl --vacuum-size=500M` or `--vacuum-time=2weeks`.

## Desktop vs server

- Desktop: the user session logs (`journalctl --user`, `~/.xsession-errors` on X11) hold most app noise.
- Server: Docker and reverse-proxy logs are often more telling than the journal.

## Confirm before

Vacuuming the journal, changing journald limits, or truncating any file in `/var/log` — those delete evidence.

## Report

Saved file path, window and filter used, counts by priority, top repeating messages, the noteworthy events (restarts, OOM, kernel, logins, reboots, package changes) with timestamps, and a one-line read of what it means.

## Related

- `services-check` — which units are failing.
- `system-diagnose` — a live problem happening right now.
- `linux-debugging` plugin — persistent journal setup, boot analysis, crash and freeze forensics.
