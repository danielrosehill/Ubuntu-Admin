---
name: troubleshoot-hardware
description: Diagnose a misbehaving hardware device — audio, display, USB, Bluetooth, network, input. Picks probe variants based on the machine profile (Wayland vs X11, pipewire vs pulseaudio, recorded GPU). Reads $CLAUDE_USER_DATA/desktop-manager/profile.json.
---

Troubleshoot a hardware device on the local desktop.

## Prelude — load profile

```bash
PLUGIN_DATA_DIR="${CLAUDE_USER_DATA:-${XDG_DATA_HOME:-$HOME/.local/share}/claude-plugins}/desktop-manager"
PROFILE_FILE="$PLUGIN_DATA_DIR/profile.json"

if [ ! -f "$PROFILE_FILE" ]; then
  echo "No machine profile found. Run /desktop-manager:onboard first."
  exit 1
fi
```

Read `desktop.session_type`, `desktop.audio_stack`, `hardware.gpu`, `quirks` from the profile. These shape which probes to run.

## Arguments

`$ARGUMENTS` — the device class or symptom: `audio`, `display`, `usb`, `bluetooth`, `network`, `keyboard`, `mouse`, or a free-form description.

## Procedure

1. **Classify the issue**. If ambiguous, ask the user one clarifying question. Cross-reference `quirks` — if any quirk matches the symptom, surface it before running probes.

2. **Run the appropriate probe set**:

   - **Audio**: pick variant by `desktop.audio_stack`:
     - `pipewire` → `wpctl status`, `pactl info` (pipewire-pulse shim), `journalctl --user -u pipewire -u wireplumber -b --no-pager | tail -n 100`.
     - `pulseaudio` → `pactl info`, `pactl list short sinks`, `pactl list short sources`, journal for `pulseaudio`.
     - `alsa` → `aplay -l`, `arecord -l`, `dmesg | grep -i snd`.
   - **Display**: pick variant by `desktop.session_type`:
     - `x11` → `xrandr`, `glxinfo | head -n 20` if available.
     - `wayland` → `wlr-randr` if available, else `kscreen-doctor -o` (KDE) / `gnome-randr` (GNOME).
     - GPU driver: cross-reference `hardware.gpu[].driver_in_use` against current `lspci -k | grep -A2 VGA` — flag drift.
     - Journal: `journalctl -b | grep -iE 'drm|gpu|nvidia|amdgpu|i915'`.
   - **USB**: `lsusb`, `dmesg --since "1 hour ago" | tail -n 100`, recent `journalctl -k`.
   - **Bluetooth**: `bluetoothctl show`, `systemctl status bluetooth`, journal for `bluetoothd`.
   - **Network**: `ip -br addr`, `ip route`, `nmcli device status`, `systemctl status NetworkManager`, journal for `NetworkManager`.
   - **Input**: `libinput list-devices` (sudo), `udevadm info` for the device, journal for kernel input events.

3. **Summarise findings**: device, kernel-visible?, daemon-managed?, error signatures in the log, any quirk matches.

4. **Propose next steps** ranked by invasiveness (restart daemon → reinstall driver → kernel module reload → reboot). Require confirmation before destructive action.

5. **Write report** to `outputs/hw-triage-<class>-YYYY-MM-DD-HHMM.md` (workspace) or `$PLUGIN_DATA_DIR/reports/hw-triage-<class>-YYYY-MM-DD-HHMM.md`.

6. If a recurring quirk is uncovered (something the user will keep tripping on), suggest `/desktop-manager:update-profile quirks +"<short description>"` so it gets recorded.
