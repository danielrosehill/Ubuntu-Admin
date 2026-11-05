# Command prelude — load profile

Every command in this plugin starts by loading the user's machine profile. Paste this prelude at the top of each command body, before any command-specific logic.

```bash
PLUGIN_DATA_DIR="${CLAUDE_USER_DATA:-${XDG_DATA_HOME:-$HOME/.local/share}/claude-plugins}/desktop-manager"
PROFILE_FILE="$PLUGIN_DATA_DIR/profile.json"

if [ ! -f "$PROFILE_FILE" ]; then
  echo "No machine profile found at $PROFILE_FILE."
  echo "Run /desktop-manager:onboard first — it auto-detects distro, package manager, desktop environment, GPU, and audio stack, then asks the user a few short questions to confirm."
  exit 1
fi
```

After loading, prefer fields from `profile.json` over re-detecting:

- Use `.packaging.native` instead of probing for `apt`/`dnf`/`pacman`/`zypper`.
- Use `.desktop.session_type` to pick `xrandr` vs `wlr-randr`.
- Use `.desktop.audio_stack` to pick `pactl` vs `wpctl`.
- Use `.system.distro_id` for distro-conditional logic.
- Use `.policies.sudo_mode` to decide whether to warn before sudo.

If a field looks stale (e.g. user mentions they switched DEs, upgraded distro), suggest `/desktop-manager:update-profile <field>` mid-command rather than silently re-detecting.

## Reading fields

`jq` is the path of least resistance:

```bash
DISTRO=$(jq -r '.system.distro_id' "$PROFILE_FILE")
PM=$(jq -r '.packaging.native' "$PROFILE_FILE")
SESSION=$(jq -r '.desktop.session_type' "$PROFILE_FILE")
```

If `jq` isn't installed, fall back to `python3 -c 'import json,sys; print(json.load(open("'$PROFILE_FILE'"))[...])'`.
