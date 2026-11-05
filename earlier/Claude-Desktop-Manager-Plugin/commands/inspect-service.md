---
name: inspect-service
description: Inspect a systemd service or user unit — status, recent logs, failure history, config path. Refuses to run on non-systemd machines (per the machine profile). Reads $CLAUDE_USER_DATA/desktop-manager/profile.json.
---

Inspect a systemd unit on the local desktop.

## Prelude — load profile

```bash
PLUGIN_DATA_DIR="${CLAUDE_USER_DATA:-${XDG_DATA_HOME:-$HOME/.local/share}/claude-plugins}/desktop-manager"
PROFILE_FILE="$PLUGIN_DATA_DIR/profile.json"

if [ ! -f "$PROFILE_FILE" ]; then
  echo "No machine profile found. Run /desktop-manager:onboard first."
  exit 1
fi
```

Check `system.init_system`. If it isn't `systemd`, refuse and tell the user this command is systemd-only.

## Arguments

`$ARGUMENTS` — the unit name (e.g. `NetworkManager`, `bluetooth`, `pipewire.service`). If the unit is a user service, append `--user`.

## Procedure

1. **Unit type detection**: system vs user. If the user didn't specify and the unit doesn't exist at system scope, try user scope (`systemctl --user`).

2. **Core checks**:
   - `systemctl [--user] status <unit> --no-pager`
   - `systemctl [--user] is-enabled <unit>`
   - `systemctl [--user] is-failed <unit>`

3. **Logs**: `journalctl [--user] -u <unit> -b --no-pager | tail -n 100`. Highlight the first and last error lines.

4. **Config path**: `systemctl [--user] show <unit> -p FragmentPath`. Offer to open/print it.

5. **Common failure signatures**: permission errors, missing binaries (ExecStart pointing at a nonexistent path), port-already-in-use, dependency failures. If detected, suggest the corresponding fix.

6. **Report**: status, enabled state, restart count, top error signatures, recommended next action. If the unit appears in the profile's `services_of_interest`, mention that it's flagged for default surfacing in `/desktop-manager:review-logs`.
