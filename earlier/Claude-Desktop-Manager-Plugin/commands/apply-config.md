---
name: apply-config
description: Apply a configuration change (dotfile edit, desktop-environment setting, systemd unit, etc.) with a rollback path. Picks DE-specific tooling based on the machine profile (gsettings/dconf for GNOME, kwriteconfig for KDE). Reads $CLAUDE_USER_DATA/desktop-manager/profile.json.
---

Apply a configuration change to the local desktop and keep a rollback path.

## Prelude — load profile

```bash
PLUGIN_DATA_DIR="${CLAUDE_USER_DATA:-${XDG_DATA_HOME:-$HOME/.local/share}/claude-plugins}/desktop-manager"
PROFILE_FILE="$PLUGIN_DATA_DIR/profile.json"

if [ ! -f "$PROFILE_FILE" ]; then
  echo "No machine profile found. Run /desktop-manager:onboard first."
  exit 1
fi
```

Read `desktop.environment`, `policies.default_editor`, `policies.sudo_mode`, `user.home`.

## Arguments

`$ARGUMENTS` — describe the config change, either free-form or as `<target-file> <change-description>`.

## Procedure

1. **Identify the target**:
   - User dotfile (e.g. `~/.bashrc`, `~/.config/foo/config.toml`)
   - System config (e.g. `/etc/systemd/...`, `/etc/default/...`) — requires sudo. If `policies.sudo_mode == "password"`, warn before invoking.
   - Desktop-environment setting — pick the right tool by `desktop.environment`:
     - `KDE` → `kwriteconfig5` / `kwriteconfig6` / `kreadconfig*`
     - `GNOME` / `Cinnamon` / `Unity` → `gsettings` / `dconf`
     - `XFCE` → `xfconf-query`
     - `MATE` → `dconf`
     - other → fall back to direct file edit on the relevant config file.

2. **Back up** the original before modifying:
   - File: copy to `<workspace>/logs/backups/<basename>.<timestamp>.bak` if a workspace exists, else `$PLUGIN_DATA_DIR/backups/`.
   - gsettings/dconf/kwriteconfig: capture the current value via the matching read tool and record it in the log.

3. **Show the diff** of the intended change and wait for explicit user confirmation.

4. **Apply** the change.

5. **Verify** the change took effect (re-read the file, or run the matching read tool — `gsettings get`, `kreadconfig`, `xfconf-query -l`).

6. **Log** to `logs/config-log.md` (workspace) or `$PLUGIN_DATA_DIR/logs/config-log.md`: timestamp, target, old value (or backup path), new value, verification result, exact rollback command.

7. If the change requires restarting a service, signing out, or rebooting the session to take effect, flag that explicitly. For systemd units, suggest `systemctl daemon-reload` plus the relevant service restart.
