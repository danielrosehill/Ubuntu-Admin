# Desktop Manager Workspace

Local Linux desktop management workspace — a scaffold for tracking installs, config changes, hardware troubleshooting, and log reviews on a single workstation.

Provisioned by the [`desktop-manager`](https://github.com/danielrosehill/desktop-manager-plugin) Claude Code plugin.

## Usage

The plugin's slash commands are globally available (installed via the marketplace). This repo just holds the data:

| Command | What it does |
|---------|--------------|
| `/desktop-manager:check-system` | Snapshot OS, hardware, DE, package managers |
| `/desktop-manager:install-package` | Install a package (detects apt/dnf/pacman/zypper/flatpak/snap) |
| `/desktop-manager:remove-package` | Remove a package with reverse-dependency check |
| `/desktop-manager:apply-config` | Apply a config change with rollback path |
| `/desktop-manager:troubleshoot-hardware` | Diagnose a misbehaving device |
| `/desktop-manager:inspect-service` | Inspect a systemd unit |
| `/desktop-manager:review-logs` | Pull filtered journalctl / dmesg output |
| `/desktop-manager:update-system` | Run a full system update |

Start with `/desktop-manager:check-system` to baseline the machine.

## Structure

```
├── CLAUDE.md       # Workspace rules + machine profile
├── context/        # Reference notes about this machine
├── outputs/        # Reports from check-system, troubleshoot, log reviews
└── logs/           # Chronological log of installs, removals, config changes
```
