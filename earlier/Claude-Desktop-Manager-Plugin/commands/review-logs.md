---
name: review-logs
description: Pull recent journalctl and dmesg output filtered for errors/warnings. Surfaces services in the profile's `services_of_interest` by default. Reads $CLAUDE_USER_DATA/desktop-manager/profile.json.
---

Review recent system logs on the local desktop.

## Prelude — load profile

```bash
PLUGIN_DATA_DIR="${CLAUDE_USER_DATA:-${XDG_DATA_HOME:-$HOME/.local/share}/claude-plugins}/desktop-manager"
PROFILE_FILE="$PLUGIN_DATA_DIR/profile.json"

if [ ! -f "$PROFILE_FILE" ]; then
  echo "No machine profile found. Run /desktop-manager:onboard first."
  exit 1
fi
```

Check `system.init_system` — refuse on non-systemd. Read `services_of_interest` (list of unit names to flag) and `desktop.audio_stack` (drives audio-related categorisation).

## Arguments

`$ARGUMENTS` — optional filters:
- `--since=<time>` (default: `boot`)
- `--priority=<err|warning|notice>` (default: `err`)
- `--unit=<name>` to scope to one unit
- `--kernel` to include kernel ring buffer (`dmesg`)

## Procedure

1. **Gather**:
   - `journalctl -b --priority=<priority> --no-pager` (or `--since=<time>`)
   - If `--unit=<name>`: scope with `-u <name>`
   - If `--kernel`: also run `dmesg -T --level=err,warn | tail -n 100`

2. **Deduplicate**: group repeated log lines with a count. Spammy repeated errors are often the real signal.

3. **Categorise** by source (unit name, kernel subsystem). For each unit in `services_of_interest`, surface a dedicated section even if its line count is below the top-10 threshold.

4. **Summarise** top 5–10 distinct issues with: source, severity, count, first occurrence, representative message.

5. **Write** a full report to `outputs/log-review-YYYY-MM-DD-HHMM.md` (workspace) or `$PLUGIN_DATA_DIR/reports/log-review-YYYY-MM-DD-HHMM.md`. Print the summary to the user.

6. **Suggest** which issues warrant `/desktop-manager:inspect-service` or `/desktop-manager:troubleshoot-hardware`. Audio errors map to `desktop.audio_stack` (e.g. pipewire/wireplumber/pulseaudio errors → suggest `troubleshoot-hardware audio`).
