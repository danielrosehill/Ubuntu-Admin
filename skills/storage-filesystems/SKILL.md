---
name: storage-filesystems
description: Check filesystem health on Ubuntu — mounts and fstab sanity, ext4/XFS/BTRFS integrity checks, inode exhaustion, kernel I/O errors, read-only remounts, and Snapper/Timeshift snapshot health. Use when asked "check the filesystem", "fsck", "is my fstab ok", "disk went read-only", "btrfs scrub", "xfs check", "snapper snapshots", "no space left but df shows space", or after an unclean shutdown. Works on the local machine or a remote host over SSH.
---

# Filesystem health

Mostly read-only. Repairs are only ever run on unmounted filesystems and only after confirmation.

## Target

Local by default. Remote: `ssh <host> '<cmd>'`; root commands `ssh -t <host> 'sudo …'`.

## 1. What is mounted, and is fstab valid

```bash
findmnt -t ext4,xfs,btrfs,vfat,ntfs3,zfs -o TARGET,SOURCE,FSTYPE,OPTIONS
df -hT -x tmpfs -x devtmpfs -x squashfs -x overlay
sudo findmnt --verify --verbose          # checks /etc/fstab syntax, missing devices, unknown types
lsblk -f                                  # UUIDs to cross-check against fstab
```

Anything listed in fstab without `nofail` that is missing will drop the boot into emergency mode.

## 2. Errors and read-only remounts

```bash
sudo dmesg -T | grep -iE 'I/O error|EXT4-fs error|XFS .*(error|corrupt)|BTRFS (error|warning)|remount.*read-only' | tail -30
findmnt -O ro -t ext4,xfs,btrfs          # real filesystems currently mounted read-only
journalctl -k -p err -b --no-pager | tail -30
```

A filesystem that flipped to read-only did so to protect itself. Check the drive next (`storage-drive-health`) before repairing.

## 3. Inodes

```bash
df -i -x tmpfs -x devtmpfs -x squashfs -x overlay
# find the directory holding millions of small files
sudo du --inodes -x -d 3 / 2>/dev/null | sort -n | tail -15
```

"No space left on device" with free blocks = inodes exhausted (common with mail queues, caches, session files).

## 4. ext4

```bash
sudo tune2fs -l /dev/<part> | grep -E 'state|Mount count|Maximum mount|Last checked|Errors behavior|Lifetime writes'
```

`Filesystem state: clean with errors` or `not clean` means it needs `fsck`. Root can't be checked while mounted; schedule it for the next boot:

```bash
sudo touch /forcefsck                        # older releases
# or, on all current releases, add to the kernel command line once:
#   fsck.mode=force fsck.repair=yes   (via GRUB edit at boot, or a one-shot grub-reboot entry)
sudo umount /dev/<part> && sudo e2fsck -f /dev/<part>   # non-root filesystems
```

## 5. XFS

```bash
xfs_info <mountpoint>
sudo xfs_db -r -c 'freesp -s' /dev/<part>    # free-space fragmentation, read-only
# Integrity check — ONLY on an unmounted filesystem; -n = no modify
sudo umount <mountpoint> && sudo xfs_repair -n /dev/<part>
```

Never run `xfs_repair` without `-n` until the result is reviewed; `-L` (zero the log) loses data and is a last resort.

## 6. BTRFS

```bash
sudo btrfs filesystem show
sudo btrfs filesystem usage <mountpoint>      # real allocation; df is misleading on btrfs
sudo btrfs device stats <mountpoint>          # any non-zero counter = investigate
sudo btrfs scrub start -B <mountpoint>        # verifies checksums; -B waits; can take hours
sudo btrfs scrub status <mountpoint>
```

"Unallocated" near zero with free space inside chunks → a filtered balance: `sudo btrfs balance start -dusage=50 <mountpoint>` (I/O heavy).

### Snapshots (Snapper / Timeshift)

```bash
sudo snapper list-configs && sudo snapper -c root list | tail -15
systemctl list-timers 'snapper-*' --no-pager
sudo timeshift --list 2>/dev/null
sudo btrfs subvolume list / | wc -l          # thousands of subvolumes slow everything down
```

Check: timers enabled, cleanup algorithm (`NUMBER_LIMIT`, `TIMELINE_LIMIT_*` in `/etc/snapper/configs/root`) actually prunes, snapshots are not filling the disk.

## Desktop vs server

- **Desktop**: Ubuntu installs ext4 by default; BTRFS + Snapper/Timeshift is a user choice. Removable drives (exFAT/NTFS) show up here too — ignore them unless asked.
- **Server**: XFS and LVM are common on data volumes. Inode exhaustion and read-only remounts are the usual incidents.

## Confirm before

- Unmounting anything, or scheduling a forced fsck on reboot.
- Any repair (`e2fsck` without `-n`, `xfs_repair` without `-n`, `btrfs check --repair` — the latter is almost never right).
- Starting a scrub or balance on a busy server.
- Editing `/etc/fstab` (back it up; validate with `findmnt --verify` before reboot).

## Report

Per filesystem: mount, type, use %, inode %, state, errors found, snapshot status; then recommended actions in priority order.

## Related

- `storage-drive-health` — hardware behind the errors.
- `storage-raid-lvm` — arrays and logical volumes.
- `storage-reclaim-space` — when the problem is simply full.
- `linux-system-optimisation` plugin (`disk-usage`) — deep BTRFS-aware usage analysis.
