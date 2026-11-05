---
name: check-system
description: Snapshot the local desktop — refreshes hardware/storage/uptime against the persisted machine profile and writes a timestamped report. Reads $CLAUDE_USER_DATA/desktop-manager/profile.json.
---

Gather a current health snapshot, anchored against the persisted machine profile.

## Prelude — load profile

```bash
PLUGIN_DATA_DIR="${CLAUDE_USER_DATA:-${XDG_DATA_HOME:-$HOME/.local/share}/claude-plugins}/desktop-manager"
PROFILE_FILE="$PLUGIN_DATA_DIR/profile.json"

if [ ! -f "$PROFILE_FILE" ]; then
  echo "No machine profile found. Run /desktop-manager:onboard first."
  exit 1
fi
```

Read `system.distro_id`, `desktop.environment`, `desktop.session_type`, `packaging.native`, `hardware.gpu` from the profile. Treat these as the source of truth for *what the machine is*; this command only refreshes *what's currently happening on it*.

## 1. Static identity (from profile)

Echo back distro, kernel (current vs profile-recorded), DE, session type, audio stack, native PM. Flag any drift — e.g. profile says kernel 6.17.0-22 but `uname -r` is 6.17.0-25 → suggest the profile may be stale, mention `/desktop-manager:update-profile system.kernel`.

## 2. Live readings

- `uptime -p`
- RAM: `free -h`
- Disk: `df -h -x tmpfs -x devtmpfs` and flag any mount > 85% used
- Load average: `cat /proc/loadavg`
- Swap usage: `free -h | awk '/Swap/'`

## 3. Package-manager state

Using `packaging.native` from profile, run a non-mutating "are there pending updates?" check:

- apt: `apt list --upgradable 2>/dev/null | wc -l`
- dnf: `dnf check-update -q | wc -l` (exit 100 = updates available)
- pacman: `checkupdates 2>/dev/null | wc -l`
- zypper: `zypper -q list-updates | wc -l`

Also count flatpak / snap pending if those are in `packaging.supplementary`.

## 4. Report

If `$ARGUMENTS` includes `--quiet`, print a one-screen summary only.

Otherwise, write `outputs/system-check-YYYY-MM-DD-HHMM.md` (workspace-relative if `/desktop-manager:new-workspace` was run; else `$PLUGIN_DATA_DIR/reports/`). Include both the static profile values and the live readings, plus any drift warnings.

Flag anything unusual: disk > 85%, kernel older than distro current, RAM/swap pressure, a package manager that the profile says exists but isn't on `$PATH` anymore.
