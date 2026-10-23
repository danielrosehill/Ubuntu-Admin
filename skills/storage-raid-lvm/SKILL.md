---
name: storage-raid-lvm
description: Inspect and maintain software RAID (mdadm), LVM, ZFS pools and hardware RAID on Ubuntu — array state, degraded or rebuilding arrays, replacing a failed member, keeping mdadm.conf and the initramfs in sync, and growing a logical volume plus its filesystem. Use when asked "RAID status", "is my array degraded", "replace a failed disk in the array", "mdstat", "extend the LVM volume", "add space to /", "zpool status", or "do I even have RAID". Works on the local machine or a remote host over SSH.
---

# RAID, LVM and pools

Read-only inspection first; changes (replace, grow) only with explicit confirmation.

## Target

Local by default. Remote: `ssh -t <host> 'sudo <cmd>'` — nearly everything here needs root.

## 1. What storage stack is in use

```bash
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS          # TYPE raid1/raid5/lvm/part/disk
cat /proc/mdstat                                    # software RAID present?
sudo pvs; sudo vgs; sudo lvs -a -o +devices         # LVM present?
command -v zpool >/dev/null && sudo zpool status -x  # ZFS present?
lspci | grep -iE 'raid|megaraid|smart array|adaptec' # hardware RAID controller?
```

## 2. mdadm (software RAID)

```bash
cat /proc/mdstat                      # [UU] healthy, [U_] degraded, "recovery =" rebuilding
sudo mdadm --detail /dev/md0          # State, Failed Devices, per-member state
sudo mdadm --examine /dev/sdX1        # member superblock
systemctl status mdmonitor --no-pager # alerting daemon; MAILADDR in /etc/mdadm/mdadm.conf
```

### Replace a failed member (RAID1/5/6/10)

```bash
sudo mdadm --manage /dev/md0 --fail /dev/sdX1 --remove /dev/sdX1
# physically swap the disk, then copy the partition table from a healthy member:
sudo sfdisk -d /dev/sdY | sudo sfdisk /dev/sdX          # MBR/GPT; for GPT then: sudo sgdisk -G /dev/sdX
sudo mdadm --manage /dev/md0 --add /dev/sdX1
watch -n 10 cat /proc/mdstat
```

If the array holds `/boot` or the ESP, reinstall the bootloader onto the new disk (`sudo grub-install /dev/sdX`).

### Keep config in sync after any array change

```bash
sudo mdadm --detail --scan | sudo tee -a /etc/mdadm/mdadm.conf   # then remove duplicate ARRAY lines
sudo update-initramfs -u
```

## 3. LVM

```bash
sudo vgs -o +vg_free                   # free extents available in the volume group
sudo lvs -o lv_name,vg_name,lv_size,data_percent,snap_percent   # thin pools / snapshots filling up
```

### Grow a logical volume and its filesystem

Ubuntu Server's default installer leaves free space in `ubuntu-vg` — a very common fix for "/ is full":

```bash
sudo lvextend -r -L +20G /dev/ubuntu-vg/ubuntu-lv     # -r resizes ext4/XFS in the same step
sudo lvextend -r -l +100%FREE /dev/ubuntu-vg/ubuntu-lv
```

Add a new disk to the VG first if there's no free space: `sudo pvcreate /dev/sdX && sudo vgextend <vg> /dev/sdX`.
XFS can only grow, never shrink; shrinking ext4 requires unmounting.

## 4. ZFS (if installed — `zfsutils-linux`)

```bash
sudo zpool status                       # look for DEGRADED, FAULTED, checksum errors
sudo zpool list
sudo zpool scrub <pool>                 # verifies all data; check `zpool status` later
systemctl list-timers 'zfs-scrub*' --no-pager
```

## 5. Hardware RAID

Ubuntu sees only the logical volume; health is in the controller's tool (`storcli`/`perccli` for LSI/Dell, `ssacli` for HPE). SMART on members needs e.g. `smartctl -d megaraid,N -a /dev/sda`. If no vendor tool is installed, say so and don't infer health from `lsblk`.

## Desktop vs server

- **Desktop**: RAID is rare; LVM appears when full-disk encryption was chosen (`vgubuntu`/`ubuntu-vg` on LUKS).
- **Server**: check `mdmonitor`/ZED alerting is actually configured to reach someone.

## Confirm before

- Failing/removing any array member, adding a disk, repartitioning.
- `lvextend`/`lvreduce`/`pvmove`, any `zpool` change other than status/scrub.
- Editing `mdadm.conf` and regenerating the initramfs.

## Report

Stack summary (md / LVM / ZFS / HW), each array or pool with state and members, free space in each VG, and the action needed (none / monitor / replace disk X now).

## Related

- `storage-drive-health` — SMART on each member.
- `storage-filesystems` — the filesystem on top.
- `storage-backup` — before any rebuild.
