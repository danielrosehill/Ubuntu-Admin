---
name: storage-reclaim-space
description: Find and free disk space on a full or filling Ubuntu machine — quick hotspot scan, then the usual safe wins (journald vacuum, apt cache and orphaned packages, old kernels, disabled snap revisions, rotated logs, crash dumps, Docker) with a report before anything is deleted. Use when asked "disk is full", "no space left on device", "free up space", "clean up the server", "what is using my disk", "/ is at 95%", or "/var is full". Works on the local machine or a remote host over SSH.
---

# Reclaim disk space

Report first, delete second. Every deletion is chosen by the user from the report.

## Target

Local by default. Remote: `ssh <host> '<cmd>'`; root `ssh -t <host> 'sudo …'`.

## 1. Where is the space going

```bash
df -hT -x tmpfs -x devtmpfs -x squashfs -x overlay
sudo du -xh -d 1 / 2>/dev/null | sort -h | tail -15          # -x stays on one filesystem
sudo du -xh -d 2 /var 2>/dev/null | sort -h | tail -15
du -h -d 1 ~ 2>/dev/null | sort -h | tail -15
command -v ncdu >/dev/null && echo "interactive: sudo ncdu -x /"
sudo find / -xdev -type f -size +1G -printf '%s\t%TY-%Tm-%Td\t%p\n' 2>/dev/null | sort -rn | numfmt --field=1 --to=iec | head -20
```

If `df` says full but `du` doesn't add up: deleted-but-open files — `sudo lsof +L1 | sort -k7 -n | tail` (restart the holding process).

## 2. Measure the safe wins

```bash
journalctl --disk-usage
du -sh /var/cache/apt/archives
apt-get -s autoremove | grep -c '^Remv'
dpkg -l 'linux-image-*' | awk '/^ii/{print $2}'; uname -r
snap list --all | awk '/disabled/{print $1, $3}'
du -sh /var/lib/snapd/snaps
sudo du -ch /var/log/*.gz /var/log/*.[0-9] /var/log/**/*.gz 2>/dev/null | tail -1
sudo du -sh /var/crash /var/lib/systemd/coredump 2>/dev/null
command -v docker >/dev/null && docker system df
du -sh ~/.cache ~/.local/share/Trash 2>/dev/null
```

## 3. Reclaim — only the items the user picked

```bash
sudo journalctl --vacuum-size=500M                 # or --vacuum-time=4weeks
sudo apt-get clean
sudo apt autoremove --purge                        # also removes old kernels marked automatic
# disabled snap revisions
snap list --all | awk '/disabled/{print $1, $3}' | while read n r; do sudo snap remove "$n" --revision="$r"; done
sudo snap set system refresh.retain=2              # keep fewer revisions in future
sudo find /var/log -type f \( -name '*.gz' -o -name '*.[0-9]' \) -mtime +14 -delete
sudo rm -f /var/crash/*.crash
sudo coredumpctl list --no-pager | tail; sudo rm -f /var/lib/systemd/coredump/*
rm -rf ~/.local/share/Trash/*
```

For Docker, hand over to `docker-cleanup` rather than running `docker system prune -a` blindly.

To cap growth permanently: `SystemMaxUse=500M` in `/etc/systemd/journald.conf.d/size.conf`, then `sudo systemctl restart systemd-journald`.

## Desktop vs server

- **Desktop**: biggest wins are usually `~/.cache`, Trash, Flatpak runtimes (`flatpak uninstall --unused`), old snap revisions, downloads and VM images. Deep analysis (BTRFS snapshots, duplicates, dev clutter like `node_modules`/venvs) is the `linux-system-optimisation` plugin.
- **Server**: biggest wins are usually Docker images/logs, journald, application logs without rotation, and old backups stored locally.

## Confirm before

- Every deletion command above — present sizes, then run only what the user chose.
- Removing kernels: never the running one (`uname -r`) and keep at least one fallback.
- Deleting logs that may be needed for an open incident.

## Report

Before/after `df` for the affected filesystem, a table of what was reclaimed (item, size), what was left and why, and any permanent cap configured.

## Related

- `docker-cleanup` — Docker images, volumes and container logs.
- `storage-filesystems` — inode exhaustion, BTRFS allocation.
- `packages-snap-flatpak` — snap/flatpak housekeeping.
- `linux-system-optimisation` plugin — `disk-usage`, `find-duplicates`, `prune-dev-clutter`.
