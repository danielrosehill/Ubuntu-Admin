---
name: services-manage
description: Control and author systemd units on Ubuntu — start, stop, restart, reload, enable, disable, mask; override a packaged unit with a drop-in via systemctl edit; write a new service or a systemd timer (system or user, with lingering); set Restart= policies and resource limits (MemoryMax, CPUQuota); validate with systemd-analyze verify; choose timers over cron. Use when asked "restart <service>", "make this run at boot", "create a systemd service for X", "schedule this script", "replace this cron job with a timer", "limit memory of <service>", "stop <service> starting". Works on the local machine or a remote host over SSH.
---

# Services manage

Change what systemd runs, and how.

## Target

Local by default. Remote: `ssh -t <host> 'sudo systemctl …'`. To write a unit file remotely: `ssh <host> 'sudo tee /etc/systemd/system/<name>.service' < local.service`. Never restart `ssh`/`sshd` or networking units remotely without a second session open.

## Everyday control

```bash
sudo systemctl status <unit> --no-pager -l
sudo systemctl start|stop|restart <unit>
sudo systemctl reload <unit>            # only if the unit supports it (check: systemctl show -p CanReload <unit>)
sudo systemctl reload-or-restart <unit>
sudo systemctl enable --now <unit>      # start now and at boot
sudo systemctl disable --now <unit>
sudo systemctl mask <unit>              # cannot be started at all, even as a dependency
sudo systemctl unmask <unit>
sudo systemctl reset-failed [<unit>]    # clear failed state after fixing
```

On Ubuntu 24.04+ `ssh` is socket-activated (`ssh.socket`); port changes go through the socket unit, not `sshd_config` alone.

## Override a packaged unit — never edit /lib/systemd/system

```bash
sudo systemctl edit <unit>              # creates /etc/systemd/system/<unit>.d/override.conf
sudo systemctl cat <unit>               # shows the merged result
sudo systemctl revert <unit>            # drop all overrides
```

Typical override:

```ini
[Service]
Restart=on-failure
RestartSec=5s
MemoryMax=1G
CPUQuota=50%
Environment=LOG_LEVEL=info
```

To *replace* a list setting such as `ExecStart`, clear it first with an empty `ExecStart=` line.

## Write a new service

```ini
# /etc/systemd/system/<name>.service
[Unit]
Description=<what it does>
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=<user>
WorkingDirectory=/opt/<name>
ExecStart=/opt/<name>/run.sh
Restart=on-failure
RestartSec=5s
# Optional limits and hardening
MemoryMax=512M
NoNewPrivileges=yes

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemd-analyze verify /etc/systemd/system/<name>.service
sudo systemctl daemon-reload
sudo systemctl enable --now <name>
journalctl -u <name> -f
```

Restart policies: `no` (default), `on-failure` (most services), `always` (daemons that must stay up, including clean exits). Add `StartLimitIntervalSec=` / `StartLimitBurst=` under `[Unit]` to stop endless crash loops.

## Timers (preferred over cron)

```ini
# /etc/systemd/system/<job>.service
[Unit]
Description=<job>
[Service]
Type=oneshot
ExecStart=/usr/local/bin/<job>.sh

# /etc/systemd/system/<job>.timer
[Unit]
Description=Run <job> daily
[Timer]
OnCalendar=*-*-* 03:30
RandomizedDelaySec=15m
Persistent=true            # run on next boot if the machine was off
[Install]
WantedBy=timers.target
```

```bash
systemd-analyze calendar '*-*-* 03:30'      # check the schedule expression
sudo systemctl daemon-reload && sudo systemctl enable --now <job>.timer
systemctl list-timers --no-pager
sudo systemctl start <job>.service          # run once now to test
```

Timers beat cron for logging (journal per unit), catch-up after downtime (`Persistent=`), dependencies and resource limits. Keep cron (`crontab -e`, `/etc/cron.d/`) where it already works and nothing above is needed.

## User units

```bash
mkdir -p ~/.config/systemd/user
# put <name>.service / .timer there, with WantedBy=default.target
systemctl --user daemon-reload
systemctl --user enable --now <name>
sudo loginctl enable-linger <user>          # keep user units running without a login (servers)
```

Desktop: user units are the right home for per-user agents (sync clients, tray helpers). Server: prefer system units with `User=` unless the user must manage it themselves.

## Confirm before

- Stopping, disabling or masking any unit — name it and its dependants (`systemctl list-dependencies --reverse <unit>`).
- Restarting network, SSH, Docker or database services, especially remotely.
- Writing or overwriting files under `/etc/systemd/system/`.
- `systemctl revert` (discards the user's overrides).
- Enabling lingering for a user.

## Report

What changed (unit, file paths written, before/after `systemctl is-enabled` and `is-active`), validation output, and the command to roll back.

## Related

- `services-check` — find what's broken first.
- `services-logs` — follow the unit after a change.
- `system-config-edit` — backup-validate-reload discipline for the service's own config files.
