---
name: install-package
description: Install one or more packages using the package manager recorded in the machine profile (apt, dnf, pacman, zypper, flatpak, snap). Honours `packaging.preferred_for_gui_apps` and `packaging.ask_when_ambiguous`. Reads $CLAUDE_USER_DATA/desktop-manager/profile.json.
---

Install a package on the local desktop.

## Prelude — load profile

```bash
PLUGIN_DATA_DIR="${CLAUDE_USER_DATA:-${XDG_DATA_HOME:-$HOME/.local/share}/claude-plugins}/desktop-manager"
PROFILE_FILE="$PLUGIN_DATA_DIR/profile.json"

if [ ! -f "$PROFILE_FILE" ]; then
  echo "No machine profile found. Run /desktop-manager:onboard first."
  exit 1
fi
```

Read `packaging.native`, `packaging.supplementary`, `packaging.preferred_for_gui_apps`, `packaging.ask_when_ambiguous`, `policies.sudo_mode` from the profile.

## Arguments

`$ARGUMENTS` — package name(s), optionally `--source=<apt|dnf|pacman|zypper|flatpak|snap>` to override the profile.

## Procedure

1. **Pick the backend**:
   - If `--source` is given, use it.
   - Else: query each candidate (`packaging.native` + `packaging.supplementary`) for the package. If only one has it, pick it. If multiple have it (e.g. native and flatpak):
     - If `packaging.ask_when_ambiguous == false`, use `packaging.preferred_for_gui_apps`.
     - If `true`, show the user the candidates with version numbers and ask.
   - If none have it, search across all and report misses; suggest near-matches.

2. **Resolve the exact package name** from the chosen backend's index. If there are close matches (typo / unscoped name), show them and confirm.

3. **Show the plan**: print the full install command (prefixed with `sudo` if the backend requires it) plus a one-line summary of what changes. If `policies.sudo_mode == "password"`, warn the user a password prompt is coming.

4. **Confirm** with the user. Wait for explicit yes.

5. **Execute** and stream output.

6. **Log** to `logs/install-log.md` in the workspace if one exists (`/desktop-manager:new-workspace`); else `$PLUGIN_DATA_DIR/logs/install-log.md`. Record timestamp, package, backend, command run, exit code.

7. **Post-install check**: if the package provides a binary, run `which <binary>` and confirm.
