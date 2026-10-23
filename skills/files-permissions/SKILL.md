---
name: files-permissions
description: Diagnose and fix "permission denied" on Ubuntu — walk the path with namei, read ownership, modes and ACLs, check group membership (and the re-login trap after usermod), umask, setgid/sticky shared folders, mount options like noexec or CIFS uid mapping, and AppArmor or snap confinement denials — then apply the narrowest fix. Use when asked "permission denied", "can't write to this folder", "why can't the service read this file", "set up a shared folder for a group", "fix ownership", "docker volume permission error", or "snap app can't open my file". Works on the local machine or a remote host over SSH.
---

# Permissions

Diagnose first, then make the smallest change that fixes it. Never `chmod -R 777`.

## Target

Local by default. Remote: `ssh <host> '<cmd>'`; root `ssh -t <host> 'sudo …'`. Reproduce as the affected identity: `sudo -u <user> <cmd>` (a service's user is in `systemctl show -p User <unit>`).

## 1. Reproduce and walk the path

```bash
sudo -u <user> ls -la <path>          # or: sudo -u <user> touch <path>/test
namei -l <path>                        # owner/mode of every component — a missing x on any parent dir blocks access
stat -c '%A %U:%G %n' <path>
id <user>                              # uid, gid, groups
```

## 2. Common causes, in order

| Cause | Check | Fix |
| --- | --- | --- |
| Parent dir lacks `x` for the user | `namei -l` | `chmod o+x` (or `g+x`) on that one directory |
| Wrong owner after `sudo cp`/extract | `stat` | `sudo chown -R <user>:<group> <path>` — scoped to the app's data dir |
| User added to a group but still denied | `id <user>` vs `id` in the current shell | log out/in, `newgrp <group>`, or restart the service |
| ACL overriding mode bits | `getfacl <path>` (a `+` in `ls -l`) | `setfacl -m u:<user>:rwX <path>` / `setfacl -b` to remove |
| Shared folder: new files get the wrong group | `ls -ld` lacks `s` | setgid + default ACL (below) |
| `noexec`/`ro`/`nosuid` mount | `findmnt -T <path> -o OPTIONS` | run from elsewhere or change the mount (see `storage-network-mounts`) |
| CIFS/NTFS/exFAT ignore chmod | `findmnt -T <path>` FSTYPE | set `uid=`,`gid=`,`file_mode=`,`dir_mode=` mount options |
| AppArmor denial | `sudo journalctl -k -g 'apparmor="DENIED"' --since -1h` | adjust the profile/local override, don't disable AppArmor |
| Snap confinement | `snap connections <snap>` | `sudo snap connect <snap>:removable-media`; snaps can't read hidden dirs in `$HOME` |
| Docker bind mount | container UID vs host owner (`docker exec <c> id`) | `chown` host dir to that UID, or run the container with `--user` |
| systemd hardening | `systemctl cat <unit>` shows `ProtectHome=`/`ProtectSystem=strict`/`ReadWritePaths=` | add the path to `ReadWritePaths=` in a drop-in |
| Restrictive umask | `umask`, `grep -r UMASK /etc/login.defs` | per service: `UMask=0002` in the unit |

## 3. Shared folder for a group (the right way)

```bash
sudo groupadd -f <team>
sudo usermod -aG <team> <user>                 # each user; re-login required
sudo chown -R root:<team> <dir>
sudo chmod 2775 <dir>                          # setgid: new files inherit the group
sudo find <dir> -type d -exec chmod 2775 {} +; sudo find <dir> -type f -exec chmod 664 {} +
sudo setfacl -d -m g:<team>:rwX <dir>           # default ACL so new files stay group-writable
```

Add `+t` (sticky, `chmod 3775`) if users must not delete each other's files.

## 4. System directories

If a system path (`/tmp`, `/var/tmp`, `/etc`, `/usr`) has wrong modes, compare to the package's expectation: `dpkg -S <path>` then `ls -ld`; `/tmp` must be `1777`. Avoid recursive changes under `/etc` or `/usr`; reinstalling the owning package (`sudo apt install --reinstall <pkg>`) restores its files.

## Desktop vs server

- **Desktop**: usually files copied with `sudo`, external drives (exFAT/NTFS uid), or snap confinement.
- **Server**: usually service users, systemd sandboxing, Docker UIDs, and NFS UID mismatches.

## Confirm before

- Any `chown`/`chmod`/`setfacl`, especially recursive ones — state the exact path and scope first.
- Adding users to groups (`docker`, `sudo`, `adm` grant significant power — say so).
- Editing AppArmor profiles or unit sandboxing.

## Report

Root cause in one sentence, the evidence (namei/stat/log line), the exact fix applied, and a re-test as the affected user.

## Related

- `storage-network-mounts` — mount-level ownership.
- `services-manage` — unit drop-ins.
- `docker-health` — volume permission issues.
- `ubuntu-security` plugin — permission audits and hardening.
