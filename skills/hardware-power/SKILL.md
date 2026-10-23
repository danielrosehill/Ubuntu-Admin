---
name: hardware-power
description: Configure sleep, hibernation, wake sources and Wake-on-LAN on Ubuntu — check suspend support, set up hibernation (swap size, resume device and offset, initramfs, Secure Boot caveat), stop spurious wake-ups, tune lid and idle behaviour in logind, choose power-profiles-daemon or TLP, and enable Wake-on-LAN persistently. Use when asked "set up hibernation", "computer wakes up by itself", "disable wake from mouse", "enable wake on LAN", "wake my server remotely", "what happens when I close the lid", or "power profiles / battery life settings". Works on the local machine or a remote host over SSH (testing suspend remotely will drop the session).
---

# Power: sleep, hibernate, wake

## Target

Local by default. Remote: `ssh -t <host> 'sudo …'`. Never trigger suspend/hibernate on a remote host without a way to wake it.

## 1. Current state

```bash
cat /sys/power/state                    # freeze mem disk → disk = hibernation possible in principle
cat /sys/power/mem_sleep                # [s2idle] deep — bracketed is in use
cat /sys/power/disk 2>/dev/null
swapon --show; free -h
mokutil --sb-state 2>/dev/null          # Secure Boot on → kernel lockdown blocks hibernation
powerprofilesctl 2>/dev/null; systemctl is-active tlp 2>/dev/null
```

## 2. Hibernation

Requirements: swap ≥ RAM (in practice ≥ used RAM + margin), resume parameters, and **Secure Boot off** (Ubuntu's lockdown disables hibernation when Secure Boot is enabled — say this up front).

```bash
# swap file sized to RAM
sudo swapoff /swap.img
sudo fallocate -l $(free -g | awk '/Mem:/{print $2+2}')G /swap.img
sudo chmod 600 /swap.img && sudo mkswap /swap.img && sudo swapon /swap.img

# resume device and offset (swap file on ext4)
RESUME_UUID=$(findmnt -no UUID -T /swap.img)
OFFSET=$(sudo filefrag -v /swap.img | awk '$1=="0:"{print substr($4,1,length($4)-2)}')
echo "resume=UUID=$RESUME_UUID resume_offset=$OFFSET"
```

Add those to `GRUB_CMDLINE_LINUX_DEFAULT` in `/etc/default/grub`, and:

```bash
echo "RESUME=UUID=$RESUME_UUID resume_offset=$OFFSET" | sudo tee /etc/initramfs-tools/conf.d/resume
sudo update-initramfs -u -k all && sudo update-grub
```

On BTRFS, use `sudo btrfs filesystem mkswapfile` and `btrfs inspect-internal map-swapfile -r` for the offset. Test with `sudo systemctl hibernate` after saving work; check `journalctl -b -1 | grep -i -E 'hibernat|resume'` after.

To expose hibernate in GNOME/KDE menus, a polkit rule may be needed; `systemctl hibernate` works regardless.

## 3. Spurious wake-ups

```bash
cat /proc/acpi/wakeup                                  # *enabled devices
grep . /sys/bus/usb/devices/*/power/wakeup 2>/dev/null | grep enabled
journalctl -b -1 -k | grep -iE 'wake|PM: suspend exit' | tail
```

Common culprits: `XHC` (USB controller — mice), `GPP*`/`GPRW` (PCIe bridges on AMD boards), the NIC. Disable persistently with a udev rule rather than echoing to `/proc/acpi/wakeup` (which resets at boot):

```
# /etc/udev/rules.d/90-no-usb-wake.rules — disable wake for one USB device
ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="<vid>", ATTR{idProduct}=="<pid>", ATTR{power/wakeup}="disabled"
```

For ACPI entries without a stable sysfs device, a oneshot systemd unit running `sh -c 'grep -q "^XHC.*enabled" /proc/acpi/wakeup && echo XHC > /proc/acpi/wakeup'` at boot works.

## 4. Lid, idle and power button (logind)

```bash
sudo mkdir -p /etc/systemd/logind.conf.d
sudoedit /etc/systemd/logind.conf.d/power.conf
```

```ini
[Login]
HandleLidSwitch=suspend
HandleLidSwitchExternalPower=suspend
HandleLidSwitchDocked=ignore
HandlePowerKey=poweroff
```

`sudo systemctl restart systemd-logind` ends graphical sessions — on a desktop, reboot instead. Server laptops: `HandleLidSwitch=ignore`. Desktop environments may override idle/lid actions in their own settings.

## 5. Power profiles vs TLP

Ubuntu desktop ships `power-profiles-daemon` (`powerprofilesctl set balanced|power-saver|performance`). TLP is an alternative for laptops; the two conflict — install one, not both (`sudo apt install tlp` removes power-profiles-daemon). Servers: neither is required.

## 6. Wake-on-LAN

```bash
IFACE=$(ip route show default | awk '{print $5; exit}')
sudo ethtool "$IFACE" | grep -i wake          # Supports Wake-on: g ? / Wake-on: d (disabled)
```

Enable persistently, matching how the interface is managed:

```bash
# NetworkManager (desktops; servers using NM)
nmcli -g NAME,DEVICE con show --active
sudo nmcli connection modify "<connection>" 802-3-ethernet.wake-on-lan magic
# netplan with systemd-networkd (Ubuntu Server) — under the ethernets entry:
#   wakeonlan: true
sudo netplan try
```

Also enable WoL in firmware (BIOS/UEFI "Power On by PCI-E"/"Wake on LAN") and disable "ErP/EuP" deep power-off. Record the MAC: `cat /sys/class/net/$IFACE/address`. Wi-Fi WoL is rarely reliable.

Send from another machine on the same LAN:

```bash
sudo apt install -y wakeonlan && wakeonlan <mac>        # or: etherwake -i <iface> <mac>
```

## Desktop vs server

- **Desktop / laptop**: hibernation, lid behaviour and wake devices are the usual asks; test suspend with a document open.
- **Server**: mostly WoL and "never sleep" — `sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target` on headless boxes that idle-suspend.

## Confirm before

- Resizing or recreating swap, editing GRUB or initramfs config.
- Writing udev rules, logind config, or masking sleep targets.
- Installing TLP (removes power-profiles-daemon).
- Any suspend/hibernate test, especially remotely.

## Report

Current capabilities, what was changed (files and values), how it was tested, and caveats (Secure Boot, firmware settings still to change by hand).

## Related

- `hardware-usb-input` — USB autosuspend.
- `network-config` — netplan/NetworkManager details.
- `system-config-edit` — backup/validate pattern for config edits.
