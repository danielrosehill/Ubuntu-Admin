---
name: storage-drive-health
description: Check the physical health of SATA, SAS, NVMe and USB-attached drives with SMART — overall verdict, the attributes that predict failure, self-tests, and continuous monitoring with smartd. Use when asked "is my disk dying", "check drive health", "SMART status", "NVMe wear", "run a disk self-test", "set up disk failure alerts", or after I/O errors appear in dmesg. Works on the local machine or a remote host over SSH.
---

# Drive health (SMART)

Reads the drive's own health telemetry. Read-only except for starting a self-test (non-destructive) and configuring `smartd`.

## Target

Local by default. Remote: `ssh -t <host> 'sudo smartctl -H /dev/sda'`. Almost every command here needs root.

## 1. Tools and inventory

```bash
command -v smartctl >/dev/null || sudo apt install -y smartmontools
command -v nvme     >/dev/null || sudo apt install -y nvme-cli      # optional, NVMe extras

lsblk -d -o NAME,SIZE,TYPE,TRAN,ROTA,MODEL,SERIAL     # TRAN: sata, nvme, usb; ROTA 1 = spinning
sudo smartctl --scan-open                              # what smartctl can reach, with the right -d type
```

Skip `loop*`, `zram*`, `sr*` and VM virtual disks (`systemd-detect-virt` ≠ `none` usually means no SMART at all — check on the hypervisor instead).

## 2. Quick verdict per drive

```bash
for d in $(lsblk -dno NAME,TYPE | awk '$2=="disk"{print $1}' | grep -vE '^(loop|zram|sr)'); do
  echo "== /dev/$d"; sudo smartctl -H /dev/$d | grep -iE 'result|status'
done
```

`PASSED` only means no attribute has crossed the vendor's failure threshold. Always read the attributes too.

## 3. SATA / SAS details

```bash
sudo smartctl -a /dev/sdX          # identity, attributes, error log, self-test log
sudo smartctl -x /dev/sdX          # extended: device statistics, temperature history
```

Flag these attributes (raw value):

| ID | Attribute | Concern |
| --- | --- | --- |
| 5 | Reallocated_Sector_Ct | any non-zero and rising |
| 187 | Reported_Uncorrect | any non-zero |
| 188 | Command_Timeout | rising |
| 197 | Current_Pending_Sector | any non-zero — failing now |
| 198 | Offline_Uncorrectable | any non-zero |
| 199 | UDMA_CRC_Error_Count | rising = cable/port, not the disk |
| 177/231/233 | Wear_Leveling / SSD_Life_Left / Media_Wearout | SSD life below ~10% |
| 194 | Temperature_Celsius | > 55 °C sustained (HDD), > 70 °C (SSD) |

## 4. NVMe details

```bash
sudo smartctl -a /dev/nvme0
sudo nvme smart-log /dev/nvme0
sudo nvme error-log /dev/nvme0 | head -40
```

Flag: `critical_warning` ≠ 0, `percentage_used` ≥ 90, `available_spare` below `available_spare_threshold`, `media_errors` > 0, rising `num_err_log_entries` together with dmesg errors.

## 5. USB enclosures

Many USB-SATA bridges hide SMART. Try:

```bash
sudo smartctl -d sat -a /dev/sdX
sudo smartctl -d sat,12 -a /dev/sdX     # older bridges
```

If none work, the bridge does not pass SMART through; say so rather than reporting "healthy".

## 6. Self-tests (non-destructive)

```bash
sudo smartctl -t short /dev/sdX        # ~2 min
sudo smartctl -t long  /dev/sdX        # hours on large HDDs; `-c` shows the estimate
sudo smartctl -l selftest /dev/sdX     # results once finished
sudo smartctl -t short /dev/nvme0      # NVMe self-test (drive must support it)
```

## 7. Continuous monitoring with smartd

```bash
systemctl status smartmontools --no-pager      # the smartd service on Ubuntu
sudoedit /etc/smartd.conf
```

A sensible line replacing the default `DEVICESCAN`:

```
DEVICESCAN -a -o on -S on -n standby,q -s (S/../.././02|L/../../6/03) -W 4,45,55 -m <email> -M exec /usr/share/smartmontools/smartd-runner
```

Short test daily at 02:00, long test Saturdays at 03:00, temperature warnings at 45/55 °C, mail to `<email>` (needs a working MTA — see `services-mail-relay`). Then `sudo systemctl restart smartmontools`.

## Desktop vs server

- **Desktop**: GNOME Disks shows the same data graphically; laptops usually have one NVMe — `percentage_used` is the headline.
- **Server**: check every array member; a single pending sector on a RAID member means plan a replacement (see `storage-raid-lvm`).

## Confirm before

- Starting a long self-test on a busy production disk (it competes for I/O).
- Editing `/etc/smartd.conf` and restarting the service.

## Report

Per drive: model, size, transport, verdict, the flagged attributes with raw values, power-on hours, and a recommendation (fine / watch / back up and replace now). Lead with any drive that needs action.

## Related

- `storage-filesystems` — filesystem-level errors.
- `storage-raid-lvm` — replacing a failing array member.
- `storage-backup` — do this first if a drive is failing.
