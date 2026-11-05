# Desktop Manager Workspace

## Purpose

This workspace is a launchpad for managing a single local Linux desktop — installs, config changes, hardware troubleshooting, log review, and service inspection. All actions are logged here so the history is persistent across sessions.

The primitives (`/desktop-manager:check-system`, `/desktop-manager:install-package`, `/desktop-manager:apply-config`, `/desktop-manager:troubleshoot-hardware`, `/desktop-manager:inspect-service`, `/desktop-manager:review-logs`, `/desktop-manager:update-system`, `/desktop-manager:remove-package`) are installed globally via the `desktop-manager` plugin. This workspace holds only **data** — context notes, outputs, and logs.

## Machine Profile

*Filled in during provisioning. Edit freely as the machine changes.*

- **Hostname / role**: <fill-in>
- **Distribution**: <fill-in>
- **Kernel family**: <fill-in>
- **Desktop environment**: <fill-in>
- **Display server**: <fill-in>
- **Primary package manager**: <fill-in>
- **Supplementary package sources**: <fill-in> (flatpak, snap, AUR, etc.)
- **Dual-boot**: <fill-in>
- **Notes**: <fill-in>

## Startup

At the start of a new session, skim `context/` and the most recent entries in `logs/` to catch up on the machine's current state.

## Operating Rules

1. **Confirm before sudo**. Every command that requires elevation must be shown to the user and confirmed before executing.
2. **Back up before changing configs**. Use `apply-config` so rollback paths are recorded.
3. **Log every mutating action**. Installs, removals, config changes, and service restarts get written to `logs/` with timestamp and exact command.
4. **Never touch hardcoded-path-sensitive items without asking**. `.desktop` files, systemd unit paths, shell aliases, cron jobs, and anything referenced by absolute path can break silently if moved.
5. **Scope is local only**. If the user asks about remote hosts, point them at the `sysadmin-homelab` plugin.
6. **Prefer the native package manager** for system software. Reach for flatpak/snap only when asked or when the package isn't in native repos.

## Workspace Structure

```
├── CLAUDE.md       # This file — workspace rules and machine profile
├── README.md       # Short summary + pointer back to the plugin
├── context/        # Reference notes about this machine (hardware quirks, known-good configs, etc.)
├── outputs/        # Reports from check-system, troubleshoot-hardware, review-logs, etc.
└── logs/           # Chronological action log: installs, removals, config changes, updates
```

## Conventions

### File naming

- `snake_case`, lowercase, short.
- Date-stamped outputs use `YYYY-MM-DD-HHMM` in the filename.

### Log entries

Each log file is append-only markdown. One entry per action:

```
## YYYY-MM-DD HH:MM — <action>

- Target: <what was changed>
- Command: <exact command>
- Result: <short outcome>
- Rollback: <how to undo>
```

## When in Doubt

Ask. The cost of asking is low; the cost of breaking a running desktop is high.
