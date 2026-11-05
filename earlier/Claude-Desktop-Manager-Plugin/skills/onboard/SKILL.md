---
name: onboard
description: First-run onboarding for the desktop-manager plugin. Auto-profiles the local Linux desktop (distro, kernel, desktop environment, session type, package managers, audio stack, GPU, hardware summary), then interviews the user for the small handful of things that can't be auto-detected (sudo policy, GUI-app packaging preference, hardware quirks, services of interest), and persists the result to `$CLAUDE_USER_DATA/desktop-manager/profile.json`. Run this before any other skill in this plugin, or whenever the machine changes (distro upgrade, new GPU, switched DE, etc.). Triggers on phrases like "set up desktop manager", "onboard desktop", "profile this machine".
---

# desktop-manager: onboard

Establish the persistent **machine profile** for the local Linux desktop. Every other command in this plugin reads from `profile.json` and refuses to run without it. Keeping the profile out of the plugin tree (in `$CLAUDE_USER_DATA`) means it survives plugin upgrades and never gets committed to git.

The same plugin install can serve different machines — the profile is per-machine, not per-plugin.

## Workspace resolution

```bash
PLUGIN_DATA_DIR="${CLAUDE_USER_DATA:-${XDG_DATA_HOME:-$HOME/.local/share}/claude-plugins}/desktop-manager"
mkdir -p "$PLUGIN_DATA_DIR"
PROFILE_FILE="$PLUGIN_DATA_DIR/profile.json"
```

Never write to `~/.claude/plugins/desktop-manager/` — that path is clobbered on plugin update. Canonical convention: see `rudder:plugin-data-storage`.

## When to use

- User says "set up desktop manager", "onboard desktop", "profile this machine", "configure desktop-manager".
- Any other desktop-manager command finds no `profile.json` at the resolved path — refuse to run and offer to onboard first.
- The user did a distro upgrade, swapped GPU, switched display server, or moved to a new machine.

For surgical edits to a single field, prefer `/desktop-manager:update-profile <field>` rather than re-running the full onboarding.

## Procedure

### 1. Existing profile?

If `$PROFILE_FILE` exists, read it and show the current values back. Offer:

- **Update** — re-run auto-detection, diff against current values, ask about each diff.
- **Replace** — discard the old profile entirely and start fresh.
- **Cancel** — bail out.

If no existing profile, proceed to step 2.

### 2. Auto-detect (no questions)

Run the probes below and capture each value. Treat any failed probe as `null` and move on — don't error out.

| Field | Probe |
|---|---|
| `system.distro_id` / `version` / `codename` | `. /etc/os-release; echo "$ID $VERSION_ID $VERSION_CODENAME"` |
| `system.kernel` | `uname -r` |
| `system.arch` | `uname -m` |
| `system.init_system` | Check `/run/systemd/system` exists → `systemd`; else inspect `ps -p 1 -o comm=`. |
| `system.hostname` | `hostnamectl --static 2>/dev/null \|\| hostname` |
| `desktop.environment` | `$XDG_CURRENT_DESKTOP` (split on `:`, take last meaningful entry — e.g. `KDE`, `GNOME`, `XFCE`). |
| `desktop.session_type` | `$XDG_SESSION_TYPE` (`x11` / `wayland` / `tty`). |
| `desktop.audio_stack` | `pgrep -x pipewire >/dev/null && echo pipewire \|\| (pgrep -x pulseaudio >/dev/null && echo pulseaudio \|\| echo alsa)` |
| `packaging.native` | First match: `command -v apt` → `apt`; `dnf` → `dnf`; `pacman` → `pacman`; `zypper` → `zypper`; else `null`. |
| `packaging.supplementary` | Build a list — `command -v flatpak`, `command -v snap`. |
| `hardware.cpu_model` / `cpu_cores` | `lscpu` (parse "Model name", "CPU(s)"). |
| `hardware.ram_gb` | `awk '/MemTotal/ {printf "%.0f", $2/1024/1024}' /proc/meminfo` |
| `hardware.gpu` | `lspci -mm \| grep -iE 'vga\|3d\|display'` parsed into `{vendor, model}`; driver via `lspci -k -s <slot>` "Kernel driver in use". |
| `hardware.storage` | `df -h -x tmpfs -x devtmpfs --output=target,fstype,size,pcent` for real mounts. |
| `user.name` | `whoami` |
| `user.home` | `echo "$HOME"` |

Show the user the auto-detected values in a compact table before moving on. Flag any `null` fields explicitly.

### 3. Interview (only what can't be auto-detected)

Ask each question. Default sensibly when the user just hits enter:

| Field | Prompt | Default | Notes |
|---|---|---|---|
| `packaging.preferred_for_gui_apps` | "When a GUI app is available from both your native package manager and Flatpak, which do you prefer?" | `flatpak` if installed, else native | Skip the question if `flatpak` and `snap` aren't present. |
| `packaging.ask_when_ambiguous` | "Should I always ask before picking a backend, or just default to your preferred one?" | `true` (ask) | |
| `policies.sudo_mode` | "Sudo policy on this machine? (`passwordless` / `timestamp` / `password`)" | `timestamp` | Affects whether commands warn before invoking sudo. |
| `policies.auto_reboot_after_update` | "After a system update flags reboot-required, may I reboot without re-asking?" | `false` | |
| `policies.default_editor` | "Default editor for config edits?" | `$EDITOR` if set, else `nano` | |
| `services_of_interest` | "Any systemd services you'd like surfaced by default in `review-logs`? (comma-separated)" | `["NetworkManager"]` | Append-only list. |
| `quirks` | "Any hardware or distro quirks I should know about? (free text — leave blank if none)" | `[]` | Multi-line. |

### 4. Confirm and write

Show the assembled profile back to the user, prompt for one final confirmation, then write `$PROFILE_FILE`:

```bash
chmod 600 "$PROFILE_FILE"
```

Set `version: 1` and `last_profiled` to ISO-8601 UTC.

### 5. Tell the user what's ready

Print the resolved path and list the now-ready commands:

- `/desktop-manager:check-system` — broader snapshot built on top of the profile
- `/desktop-manager:install-package`, `/desktop-manager:remove-package`, `/desktop-manager:update-system`
- `/desktop-manager:apply-config`
- `/desktop-manager:inspect-service`, `/desktop-manager:review-logs`
- `/desktop-manager:troubleshoot-hardware`

Mention that `update-profile` exists for surgical edits.

## Schema reference

See `lib/PROFILE.md` in this plugin for the full schema, field semantics, and migration notes.
