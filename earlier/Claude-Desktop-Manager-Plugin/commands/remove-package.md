---
name: remove-package
description: Remove a package from the local desktop, showing reverse-dependencies first. Uses the package manager recorded in the machine profile. Reads $CLAUDE_USER_DATA/desktop-manager/profile.json.
---

Safely remove a package from the local desktop.

## Prelude — load profile

```bash
PLUGIN_DATA_DIR="${CLAUDE_USER_DATA:-${XDG_DATA_HOME:-$HOME/.local/share}/claude-plugins}/desktop-manager"
PROFILE_FILE="$PLUGIN_DATA_DIR/profile.json"

if [ ! -f "$PROFILE_FILE" ]; then
  echo "No machine profile found. Run /desktop-manager:onboard first."
  exit 1
fi
```

Read `packaging.native`, `packaging.supplementary`, `policies.sudo_mode`.

## Arguments

`$ARGUMENTS` — the package name, optionally followed by `--source=<backend>` and/or `--purge` (apt only).

## Procedure

1. **Determine the package source**: which backend currently owns this package? Walk `packaging.native` + `packaging.supplementary` until one reports the package is installed. If `--source` is given, use it.

2. **Reverse-dependency check** based on the resolved backend:
   - apt: `apt-cache rdepends --installed <pkg>`
   - dnf: `dnf repoquery --installed --whatrequires <pkg>`
   - pacman: `pacman -Qi <pkg>` (Required By)
   - zypper: `zypper search --requires-pattern <pkg>`
   - flatpak / snap: list dependent runtimes / connected snaps where applicable.

3. **Show the plan** with the reverse-deps list. If anything else depends on this package, surface that prominently. If `policies.sudo_mode == "password"`, warn that sudo will prompt.

4. **Confirm** explicitly. No silent removals.

5. **Execute** with the appropriate command (`apt remove`, `apt purge`, `dnf remove`, `pacman -R`, `zypper remove`, `flatpak uninstall`, `snap remove`).

6. **Log** to `logs/remove-log.md` in the workspace, or `$PLUGIN_DATA_DIR/logs/remove-log.md` otherwise: timestamp, package, backend, reverse-deps noted, command run, exit code.

Never auto-remove orphaned dependencies without asking.
