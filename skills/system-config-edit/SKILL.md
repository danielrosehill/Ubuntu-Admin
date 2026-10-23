---
name: system-config-edit
description: Safely change a system configuration file on an Ubuntu machine. It backs up the file first, makes the edit, validates it with the owning tool's checker (sshd -t, nginx -t, netplan generate, visudo -c, systemd-analyze verify, docker compose config and others), reloads only if validation passes, and can roll back. It also snapshots config paths for safekeeping. Use when asked to "edit /etc/...", "change this config", "update the nginx/sshd/netplan/fstab config", "back up this config", or "restore the old config". Works on the local machine or a remote host over SSH.
---

# System config edit

Never edit a config without a backup, and never reload one that failed validation.

## Target

Local by default. For a remote host, run the steps over SSH (`ssh -t <host> 'sudo …'`). Keep the backup copy on both sides: on the host next to the file, and locally if you are working from an admin workspace (see `host-workspace`).

## 1. Back up

```bash
F=/etc/path/to/file
TS=$(date +%Y%m%d-%H%M%S)
sudo cp -a "$F" "$F.bak.$TS"                       # on the host, same directory

# Optional: pull a copy into the local workspace
mkdir -p backups && ssh <host> "sudo cat $F" > "backups/$(basename "$F").$TS"

# Whole directory snapshot (e.g. /etc/nginx), remote -> local tarball
ssh <host> "sudo tar -cz -C / ${F#/}" > "backups/$(basename "$F").$TS.tgz"
sha256sum backups/*."$TS"*
```

If `/etc` is tracked by `etckeeper` (`sudo apt install etckeeper`), commit before and after instead (`sudo etckeeper commit "before: <reason>"`). That gives you history for free.

## 2. Edit

- Prefer drop-in directories over editing the main file when the software supports them. They survive package upgrades without dpkg conffile prompts. Examples: `/etc/ssh/sshd_config.d/`, `/etc/systemd/system/<unit>.d/`, `/etc/apt/apt.conf.d/`, `/etc/sysctl.d/`, `/etc/sudoers.d/`, `/etc/nginx/conf.d/`.
- For systemd units, use `sudo systemctl edit <unit>`. Do not edit files in `/lib/systemd/system`.
- For sudoers, always use `sudo visudo -f /etc/sudoers.d/<name>`.
- Make the smallest change that does the job and show the diff: `diff -u "$F.bak.$TS" "$F"`.

## 3. Validate

| File | Validator |
| --- | --- |
| sshd | `sudo sshd -t` |
| nginx | `sudo nginx -t` |
| apache | `sudo apache2ctl configtest` |
| sudoers | `sudo visudo -c` |
| netplan | `sudo netplan generate`, then `sudo netplan try` (auto-reverts in 120 s) |
| fstab | `sudo findmnt --verify --verbose` (and `sudo mount -a` in a test) |
| systemd unit | `systemd-analyze verify /etc/systemd/system/<unit>` |
| docker compose | `docker compose -f <file> config -q` |
| sysctl | `sudo sysctl -p /etc/sysctl.d/<file>.conf` |
| apt sources | `sudo apt update` (look for warnings) |
| logrotate | `sudo logrotate -d /etc/logrotate.d/<file>` |
| YAML / JSON | `python3 -c 'import sys,yaml; yaml.safe_load(open(sys.argv[1]))' <file>` / `jq . <file>` |
| cron | `crontab -l` round-trip; system crontabs need a trailing newline |

If validation fails, restore at once: `sudo cp -a "$F.bak.$TS" "$F"`.

## 4. Apply

Reload in preference to restart (`systemctl reload <svc>` where it is supported). Then verify the service is healthy: `systemctl status`, `journalctl -u <svc> -n 20`, and the actual function, such as a curl or a fresh SSH login.

**Remote safety:** for anything that can cut your own connection (sshd, netplan, firewall, network interfaces), keep the current SSH session open and test with a *second* new connection before closing the first. For netplan, always use `netplan try`.

## Confirm before

Showing the diff and getting a yes before writing any file under `/etc`. The same goes for restarting (not reloading) a service with users on it, and for any change on a remote host that touches SSH or networking.

## Report

The file changed, the backup path, the diff summary, the validator output, and the reload result. Offer `system-change-log` for anything non-trivial.

## Related

`system-change-log`, `services-manage`, `network-config`, `host-workspace`.
