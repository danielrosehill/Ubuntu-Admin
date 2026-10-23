---
name: desktop-displays
description: Inspect and configure monitors on an Ubuntu desktop — list connected displays and modes, detect Wayland vs X11, arrange multiple monitors, set resolution, refresh rate and (fractional) scaling, and save/restore named layouts such as docked, laptop-only and presentation. Covers GNOME (Ubuntu default), X11 xrandr and wlroots compositors; KDE Plasma is handed to the kde-plasma plugin. Use when asked "list my monitors", "set up dual monitors", "fractional scaling", "HiDPI is blurry", "switch to docked layout", "save my display config", or "second screen not detected". Local desktop sessions only.
---

# Displays

Runs inside the user's graphical session. Over SSH it only works if you target that session's environment (`DISPLAY`/`WAYLAND_DISPLAY`, `XDG_RUNTIME_DIR`) — prefer running locally.

## 1. Detect the session

```bash
echo "$XDG_SESSION_TYPE $XDG_CURRENT_DESKTOP"     # wayland/x11 + GNOME / KDE / sway …
for p in /sys/class/drm/card*-*; do echo "$(basename $p): $(cat $p/status)"; done   # kernel view: connected?
```

- `KDE` → use the `kde-plasma` plugin (`screen-config-save` / `screen-config-apply`, kscreen-doctor). Stop here.
- `GNOME` (Ubuntu default) → section 2.
- X11 anything → section 3. wlroots (sway, Hyprland) → section 4.

## 2. GNOME (Wayland or X11)

```bash
command -v gdctl && gdctl show --modes        # GNOME 48+ (Ubuntu 25.04 and later): built-in display CLI
cat ~/.config/monitors.xml                     # what GNOME persists (all releases)
# Older GNOME (22.04/24.04): no packaged CLI; use Settings → Displays, or the
# third-party gnome-monitor-config built from source.
```

Fractional scaling on Wayland (125 %, 150 %…):

```bash
gsettings set org.gnome.mutter experimental-features "['scale-monitor-framebuffer']"
# On 24.04+ Ubuntu's GNOME may already expose fractional scaling in Settings → Displays.
# X11 session variant: "['x11-randr-fractional-scaling']"
```

Set layout on GNOME 48+: `gdctl set --logical-monitor --primary --monitor <CONN1> --scale 1.25 --logical-monitor --monitor <CONN2> --right-of <CONN1>` (see `gdctl set --help`). On older GNOME use Settings → Displays, then copy `monitors.xml`. Text-only scaling (no blur): `gsettings set org.gnome.desktop.interface text-scaling-factor 1.25`.

## 3. X11 (xrandr)

```bash
xrandr --listmonitors
xrandr -q                                                    # all outputs and modes
xrandr --output <OUT1> --primary --mode 2560x1440 --rate 144 --output <OUT2> --mode 1920x1080 --right-of <OUT1>
xrandr --output <OUT2> --off
# missing mode
cvt 2560 1440 60   # then --newmode / --addmode with the printed modeline
```

Make it persistent with a GNOME/desktop autostart `.desktop` entry running a layout script, or `autorandr` (`sudo apt install autorandr`; `autorandr --save docked`, `autorandr --change`).

## 4. wlroots compositors

```bash
sudo apt install -y wlr-randr && wlr-randr
wlr-randr --output <OUT> --mode 2560x1440@144 --scale 1.25 --pos 0,0
```

`kanshi` provides named profiles that switch automatically on hot-plug.

## 5. Named profiles (docked / laptop / presentation)

Save each layout so it can be restored by name:

```bash
mkdir -p ~/.config/display-profiles
cp ~/.config/monitors.xml ~/.config/display-profiles/docked.monitors.xml   # GNOME: GNOME re-reads on hot-plug/login
xrandr -q > ~/.config/display-profiles/docked.xrandr.txt                    # X11 reference
autorandr --save docked                                                     # X11 with autorandr
```

GNOME keeps one `monitors.xml` containing several configurations keyed by which monitors are connected, so docked/undocked usually switches by itself; `Super+P` cycles mirror/join/single.

## 6. Capture the current config

When asked to "capture the display config", create `./display-config/` with:

- `display-config.json` — machine-readable: session type, each output (connector, make/model from `edid-decode` if available, mode, refresh, scale, position, primary).
- `display-config.md` — the same in prose plus the restore command for this desktop.
- Raw copies: `monitors.xml`, `xrandr -q` / `gdctl show` output.

## Troubleshooting

- Monitor not detected: check `/sys/class/drm/*/status`, try another cable/port, `journalctl -k | grep -i drm`. NVIDIA + Wayland issues → `hardware-gpu`.
- Wrong max resolution: EDID read failure or cable limit (HDMI 1.4 vs 2.0, passive adapters). `sudo apt install edid-decode; edid-decode /sys/class/drm/<card-conn>/edid`.

## Confirm before

- Applying a layout that could leave the only display off (keep a revert: GNOME asks to confirm within 20 s; with xrandr, chain `sleep 15; xrandr --auto` as a fallback).
- Enabling experimental mutter features.

## Report

Session type and desktop, a table of outputs (connector, model, mode, refresh, scale, position, primary), and what was changed or saved (file paths).

## Related

- `hardware-gpu` — drivers behind display problems.
- `kde-plasma` plugin — KDE Plasma (`screen-config-save`, `screen-config-apply`).
