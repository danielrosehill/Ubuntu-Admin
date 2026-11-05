---
name: update-system
description: Run a full system update using the package managers recorded in the machine profile (native + flatpak/snap). Honours `policies.auto_reboot_after_update`. Reads $CLAUDE_USER_DATA/desktop-manager/profile.json.
---

Update the local desktop.

## Prelude — load profile

```bash
PLUGIN_DATA_DIR="${CLAUDE_USER_DATA:-${XDG_DATA_HOME:-$HOME/.local/share}/claude-plugins}/desktop-manager"
PROFILE_FILE="$PLUGIN_DATA_DIR/profile.json"

if [ ! -f "$PROFILE_FILE" ]; then
  echo "No machine profile found. Run /desktop-manager:onboard first."
  exit 1
fi
```

Read `packaging.native`, `packaging.supplementary`, `policies.auto_reboot_after_update`, `policies.sudo_mode`, `system.distro_id`.

## Arguments

`$ARGUMENTS` — optional flags:
- `--dry-run` — show what would be updated without applying
- `--native-only` — skip flatpak/snap
- `--yes` — skip the confirmation prompt (still shows the plan)

## Procedure

1. **Refresh metadata** based on `packaging.native`:
   - apt: `sudo apt update`
   - dnf: `sudo dnf check-update` (exit 100 = updates available — treat as non-error)
   - pacman: `sudo pacman -Sy`
   - zypper: `sudo zypper refresh`

2. **List pending updates** per source and show a combined summary (package count, total download size where available).

3. **If `--dry-run`**: stop here.

4. **Confirm** with the user (skip if `--yes`). If `policies.sudo_mode == "password"`, warn that a sudo prompt is coming.

5. **Apply**:
   - Native PM upgrade based on `packaging.native` (`apt upgrade`, `dnf upgrade`, `pacman -Su`, `zypper update`).
   - For each entry in `packaging.supplementary` (unless `--native-only`):
     - `flatpak`: `flatpak update -y`
     - `snap`: `sudo snap refresh`

6. **Post-update reboot check**:
   - Debian family (`distro_id` ∈ `ubuntu`, `debian`, `linuxmint`, `pop`): `[ -f /var/run/reboot-required ]`
   - RPM family (`fedora`, `rhel`, `centos`): `dnf needs-restarting -r; echo $?`
   - Arch: check installed kernel vs running (`pacman -Q linux | awk '{print $2}'` vs `uname -r`).
   - If reboot is needed:
     - `policies.auto_reboot_after_update == true` → execute `systemctl reboot` after warning the user.
     - Else → tell the user and stop. Do not reboot.

7. **Log** to `logs/update-log.md` (workspace) or `$PLUGIN_DATA_DIR/logs/update-log.md`: timestamp, counts per source, reboot-required flag, whether reboot was triggered.
