---
name: hardware-usb-input
description: List and troubleshoot USB devices and input hardware on Ubuntu — the USB tree, identifying an unknown device, watching hot-plug events, autosuspend and power problems, reading keyboard/mouse scancodes with evtest or libinput, and remapping keys persistently with hwdb, keyd or input-remapper. Use when asked "list USB devices", "what is this USB device", "my USB device keeps disconnecting", "find the scancode of this key", "remap a key", "macro keyboard/foot pedal setup", or "install input remapper". Listing works on the local machine or a remote host over SSH; input capture needs local access.
---

# USB devices and input

## Target

Listing: local or `ssh <host> 'lsusb -t'`. Event capture (evtest, libinput) needs the physical device on the machine you are running on, and root.

## 1. What is connected

```bash
lsusb                                   # vendor:product IDs and names
lsusb -t                                # tree: bus, port, driver, speed (480M = USB2, 5000M+ = USB3)
usb-devices | grep -E '^(T|P|S|C|I):' | head -80   # per-device descriptors, drivers bound per interface
lsusb -v -d <vid>:<pid> 2>/dev/null | head -60
cat /proc/bus/input/devices | grep -E 'N: Name|H: Handlers'   # input devices and their event nodes
```

Unknown device: look up `<vid>:<pid>` in `/usr/share/misc/usb.ids` (`grep -i '^<vid>' -A50 /usr/share/misc/usb.ids`) or online.

## 2. Hot-plug and disconnect problems

```bash
sudo dmesg -wT                           # plug/unplug and watch; Ctrl+C to stop
udevadm monitor --kernel --udev --property   # full udev view of the event
journalctl -k --since '-30 min' | grep -iE 'usb .*(disconnect|reset|over-current|error)'
```

- `over-current` / repeated `reset high-speed USB device` → power or cable: try a powered hub, a different port, a shorter cable.
- Disconnects after idle → USB autosuspend:

```bash
cat /sys/bus/usb/devices/*/power/control | sort | uniq -c        # auto = autosuspend on
# disable for one device, persistently (udev rule):
echo 'ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="<vid>", ATTR{idProduct}=="<pid>", TEST=="power/control", ATTR{power/control}="on"' | sudo tee /etc/udev/rules.d/50-usb-<name>-no-autosuspend.rules
sudo udevadm control --reload && sudo udevadm trigger
```

If TLP is installed, its `USB_DENYLIST`/`USB_AUTOSUSPEND` settings may override this.

## 3. Scancodes and key events

```bash
sudo apt install -y evtest libinput-tools
sudo evtest                              # pick the device number, press keys
sudo libinput debug-events --show-keycodes
```

Note both the `MSC_SCAN` value (scancode, e.g. `70068`) and the `KEY_*` code. A key that produces no event at all is not seen by the kernel; one with a scancode but `KEY_RESERVED`/unknown needs a hwdb mapping.

## 4. Remapping options (pick the lightest that works)

| Need | Tool |
| --- | --- |
| Fix/override one key on one device, system-wide, all sessions | **hwdb** |
| Layered remaps, tap/hold, chords, works on Wayland and TTY | **keyd** |
| GUI, per-device presets, macros | **input-remapper** |

### hwdb (built in)

`/etc/udev/hwdb.d/70-<name>.hwdb`:

```
evdev:input:b0003v<VID>p<PID>*
 KEYBOARD_KEY_70068=f13
```

VID/PID in uppercase hex, 4 digits. Then:

```bash
sudo systemd-hwdb update && sudo udevadm trigger
```

### keyd

```bash
sudo apt install -y keyd        # in universe on 24.04+; otherwise build from upstream
sudoedit /etc/keyd/default.conf
sudo systemctl enable --now keyd && sudo keyd reload
```

### input-remapper

```bash
sudo apt install -y input-remapper
sudo systemctl enable --now input-remapper
input-remapper-gtk               # create a preset per device, enable "autoload"
```

## Desktop vs server

- **Desktop**: GNOME/KDE also expose some remaps (Caps→Ctrl) in settings — prefer those for simple cases. Shortcuts themselves belong to the desktop environment (see the `kde-plasma` plugin for KDE).
- **Server**: mostly relevant for USB storage, UPS units (`nut`), serial adapters (`/dev/ttyUSB*`, add the user to `dialout`), and Zigbee/Z-Wave sticks — give them stable names with a udev `SYMLINK+=` rule.

## Confirm before

- Writing udev rules or hwdb files and reloading udev.
- Installing and enabling a remapping daemon.
- Adding a user to `input`/`dialout`/`plugdev` groups.

## Report

The device(s) identified (vendor:product, driver, bus speed), the problem found, scancodes captured, and the exact rule/config written.

## Related

- `hardware-profile` — full inventory.
- `hardware-power` — USB wake sources.
- `linux-bt` plugin — Bluetooth input devices.
