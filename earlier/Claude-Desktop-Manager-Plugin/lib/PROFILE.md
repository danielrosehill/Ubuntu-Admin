# desktop-manager: profile.json reference

Single source of truth for the schema written by `onboard` and read by every other command/skill in this plugin.

## Resolution

```bash
PLUGIN_DATA_DIR="${CLAUDE_USER_DATA:-${XDG_DATA_HOME:-$HOME/.local/share}/claude-plugins}/desktop-manager"
PROFILE_FILE="$PLUGIN_DATA_DIR/profile.json"
```

Never write to `~/.claude/plugins/desktop-manager/` — that path is clobbered on plugin update. Canonical convention is documented in `rudder:plugin-data-storage`.

## Schema (version 1)

```json
{
  "version": 1,
  "last_profiled": "2026-04-30T12:00:00Z",
  "system": {
    "distro_id": "ubuntu",
    "distro_version": "25.10",
    "distro_codename": "questing",
    "kernel": "6.17.0-22-generic",
    "arch": "x86_64",
    "init_system": "systemd",
    "hostname": "workstation"
  },
  "desktop": {
    "environment": "KDE",
    "session_type": "wayland",
    "audio_stack": "pipewire"
  },
  "packaging": {
    "native": "apt",
    "supplementary": ["flatpak", "snap"],
    "preferred_for_gui_apps": "flatpak",
    "ask_when_ambiguous": true
  },
  "hardware": {
    "cpu_model": "AMD Ryzen 9 ...",
    "cpu_cores": 16,
    "ram_gb": 64,
    "gpu": [
      { "vendor": "NVIDIA", "model": "RTX 4090", "driver_in_use": "nvidia" }
    ],
    "storage": [
      { "mount": "/", "fs": "ext4", "size_gb": 1000, "used_pct": 42 }
    ]
  },
  "policies": {
    "sudo_mode": "timestamp",
    "auto_reboot_after_update": false,
    "default_editor": "nano",
    "preferred_journal_pager": "journalctl --no-pager"
  },
  "services_of_interest": [
    "NetworkManager",
    "bluetooth",
    "pipewire"
  ],
  "quirks": [
    "Free-form notes the user gave during onboarding."
  ],
  "user": {
    "name": "daniel",
    "home": "/home/daniel"
  }
}
```

## Field semantics

| Field | Purpose | Used by |
|---|---|---|
| `system.distro_id` | Pick package manager defaults | install-package, remove-package, update-system |
| `system.init_system` | Pick service inspection commands | inspect-service |
| `desktop.session_type` | Pick `xrandr` vs `wlr-randr` | troubleshoot-hardware |
| `desktop.audio_stack` | Pick `pactl` vs `wpctl` flow | troubleshoot-hardware |
| `packaging.native` | The default PM (apt/dnf/pacman/zypper) | install/remove/update |
| `packaging.preferred_for_gui_apps` | Which backend to default to for GUI apps when both flatpak and native have it | install-package |
| `packaging.ask_when_ambiguous` | If `false`, just go with `preferred_for_gui_apps` | install-package |
| `policies.sudo_mode` | `passwordless` / `timestamp` / `password` — affects when to warn the user | all sudo paths |
| `policies.auto_reboot_after_update` | If `true`, may reboot without re-asking when post-update flag is set | update-system |
| `services_of_interest` | Pre-flagged services for `review-logs` summarisation | review-logs |
| `quirks` | Free-form caveats the user surfaces (e.g. "AMDGPU resets randomly") | troubleshoot-hardware |

## Migration / breaking changes

Bump `version` whenever the schema changes incompatibly. Skills should refuse to run against a `version` they don't understand and tell the user to run `/desktop-manager:update-profile`.
