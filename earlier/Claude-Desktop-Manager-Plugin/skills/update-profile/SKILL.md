---
name: update-profile
description: Surgical edits to the desktop-manager machine profile without re-running full onboarding. Use when a single field changed — e.g. user upgraded distro, switched from X11 to Wayland, swapped GPU, changed sudo policy, added a service to watch, recorded a new hardware quirk. Reads and writes `$CLAUDE_USER_DATA/desktop-manager/profile.json`. Triggers on phrases like "update desktop profile", "I switched to wayland", "add a quirk", "change sudo mode".
---

# desktop-manager: update-profile

For one-off field changes against an existing profile. If the user wants a wholesale re-profile, run `/desktop-manager:onboard` instead.

## Workspace resolution

```bash
PLUGIN_DATA_DIR="${CLAUDE_USER_DATA:-${XDG_DATA_HOME:-$HOME/.local/share}/claude-plugins}/desktop-manager"
PROFILE_FILE="$PLUGIN_DATA_DIR/profile.json"
```

If `$PROFILE_FILE` doesn't exist, point the user at `/desktop-manager:onboard` and stop. Don't bootstrap a partial profile from this skill.

## Arguments

`$ARGUMENTS` is parsed as `<field-path> [new-value]`. Examples:

- `desktop.session_type wayland`
- `policies.sudo_mode passwordless`
- `packaging.preferred_for_gui_apps flatpak`
- `services_of_interest +bluetooth` (append)
- `services_of_interest -bluetooth` (remove)
- `quirks +"AMDGPU resets randomly under heavy load"` (append free-form)
- `hardware.gpu` (no value → re-detect just this field via `lspci -k`)

If no arguments, show the user the current profile and ask which field they want to change.

## Procedure

1. **Load** `$PROFILE_FILE`. If `version` doesn't match what this plugin understands (currently `1`), refuse and tell the user to re-onboard.

2. **Resolve the field**. Walk the JSON path. If the path doesn't exist, reject with the closest sibling suggestion — don't silently create new top-level fields.

3. **Compute the new value**:
   - Bare new-value → set the field.
   - `+value` on a list field → append (deduplicate).
   - `-value` on a list field → remove.
   - No value given → re-run the auto-detection probe for that field from `onboard`'s table and propose the result.

4. **Diff and confirm**. Show old value, new value. Wait for explicit user confirmation.

5. **Write**. Update `last_profiled` to now (UTC ISO-8601). `chmod 600 "$PROFILE_FILE"`.

6. **Tell the user** what changed and which commands are affected. For example, if `desktop.session_type` flipped to `wayland`, mention that `troubleshoot-hardware` will now use `wlr-randr` instead of `xrandr`.

## Editable fields

See `lib/PROFILE.md` for the full schema. All fields in there are user-editable except `version`, which is owned by the plugin.
