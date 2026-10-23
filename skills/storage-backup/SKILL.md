---
name: storage-backup
description: Assess, audit and set up backups on an Ubuntu machine — decide what needs backing up, find existing backup jobs (restic, borg, rclone, Timeshift, Déjà Dup, cron or systemd timers), check when each last succeeded, list restore points, prove a restore works, and create a simple restic or rclone job on a systemd timer. Use when asked "are my backups working", "backup status", "what should I back up", "list restore points", "test a restore", "set up backups for this server", or before any risky change. Works on the local machine or a remote host over SSH.
---

# Backups

## Target

Local by default. Remote: `ssh <host> '<cmd>'`; root `ssh -t <host> 'sudo …'`. Placeholders: `<repo>` (backup repository: path, `sftp:`, `s3:`, `rclone:` URL), `<remote>` (rclone remote name).

## 1. What should be backed up

```bash
du -xsh /home/* /etc /var/lib /srv /opt 2>/dev/null | sort -h
apt-mark showmanual > /tmp/manual-packages.txt        # reinstall list, tiny and valuable
snap list; flatpak list --app 2>/dev/null
sudo crontab -l; crontab -l; ls /etc/cron.d
command -v docker >/dev/null && docker volume ls && docker ps --format '{{.Names}} {{.Mounts}}'
sudo ls /var/lib/{postgresql,mysql} 2>/dev/null        # databases need a dump, not a file copy
```

Usual set: `/home` (minus caches), `/etc`, service data under `/srv`, `/opt`, `/var/lib/<app>`, Docker named volumes and compose files, database dumps, the package list. Usual excludes: `~/.cache`, `node_modules`, `.venv`, `~/Downloads`, `/var/lib/docker/overlay2`, VM images unless wanted.

## 2. Find existing jobs

```bash
systemctl list-timers --all --no-pager | grep -iE 'backup|restic|borg|rclone|timeshift|snap|dup'
grep -rlE 'restic|borg|rclone|rsync|duplicity|tar ' /etc/cron* /var/spool/cron 2>/dev/null
command -v restic borg rclone timeshift deja-dup 2>/dev/null
ls ~/.config/rclone/rclone.conf 2>/dev/null && rclone listremotes
```

## 3. When did each last succeed

```bash
journalctl -u '<backup-unit>' --since '-7d' --no-pager | grep -iE 'error|fail|finished|snapshot .* saved' | tail
systemctl show <backup-unit>.service -p Result -p ExecMainExitTimestamp
restic -r <repo> snapshots --latest 3              # needs RESTIC_PASSWORD(_FILE)
borg list <repo> --last 3
sudo timeshift --list
```

Flag: no success in > 2× the schedule interval, a timer that is `n/a` (never runs), repository size not changing, or errors in the last run.

## 4. Repository integrity and restore test

```bash
restic -r <repo> check --read-data-subset=5%
borg check --verify-data <repo>                    # slow; omit --verify-data for a quick check
# Restore a sample into a scratch dir and compare
restic -r <repo> restore latest --target /tmp/restore-test --include /etc/hostname
diff /etc/hostname /tmp/restore-test/etc/hostname && echo RESTORE-OK
```

A backup that has never been restored is unverified. Always do at least one sample restore.

## 5. Set up a simple job (restic + systemd timer)

```bash
sudo apt install -y restic
sudo install -m 600 /dev/null /etc/restic.env
sudoedit /etc/restic.env      # RESTIC_REPOSITORY=<repo>  RESTIC_PASSWORD_FILE=/etc/restic.pass  (+ cloud keys)
sudo bash -c 'set -a; . /etc/restic.env; restic init'   # once
```

`/etc/systemd/system/restic-backup.service`:

```ini
[Unit]
Description=restic backup
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
EnvironmentFile=/etc/restic.env
ExecStart=/usr/bin/restic backup /etc /home /srv --exclude-caches --exclude /home/*/.cache
ExecStartPost=/usr/bin/restic forget --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune
Nice=10
IOSchedulingClass=idle
```

`/etc/systemd/system/restic-backup.timer`:

```ini
[Timer]
OnCalendar=*-*-* 03:00
RandomizedDelaySec=30m
Persistent=true

[Install]
WantedBy=timers.target
```

```bash
sudo systemctl daemon-reload && sudo systemctl enable --now restic-backup.timer
sudo systemctl start restic-backup.service && journalctl -u restic-backup -n 30 --no-pager
```

For a plain file mirror to cloud storage, swap `ExecStart` for `rclone sync <path> <remote>:<bucket>/<path> --backup-dir <remote>:<bucket>/old/$(date +%%F)` (note `%%` escaping in units). A mirror is not a backup unless deletions are kept.

## Desktop vs server

- **Desktop**: Déjà Dup (GNOME "Backups") or Timeshift are fine for home/system respectively; Timeshift snapshots on the same disk are not a backup.
- **Server**: dump databases first (`pg_dumpall`, `mysqldump --single-transaction`) in an `ExecStartPre`; back up compose files and `.env` alongside volumes.

## Confirm before

- Initialising a repository, writing credentials files, enabling timers.
- `forget --prune` / `borg prune` (deletes old snapshots).
- Restoring anywhere other than a scratch directory.

## Report

Table of jobs: tool, what it covers, destination, schedule, last success, last restore test. Then gaps (unbacked data, stale jobs) and what was set up.

## Related

- `storage-reclaim-space` — when backups are filling a disk.
- `docker-health` — locating volume data.
- `system-config-edit` — backing up a single config before editing.
