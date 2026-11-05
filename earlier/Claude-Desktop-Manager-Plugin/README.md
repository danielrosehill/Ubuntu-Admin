# desktop-manager-plugin

Claude Code plugin for managing a local Linux desktop workstation. **v2.0** introduces a per-machine profile that's auto-detected on first run, persisted to user data (outside the plugin tree), and consulted by every command — so you stop re-answering "what distro is this" and Claude stops guessing wrong.

Scope is explicitly **local desktop only**. Remote server/homelab admin lives in the separate `sysadmin-homelab` plugin.

Part of the [danielrosehill Claude Code marketplace](https://github.com/danielrosehill/Claude-Code-Plugins).

## How it works

1. **First run**: `/desktop-manager:onboard` auto-profiles the machine (distro, kernel, DE, session type, audio stack, package managers, GPU) and asks a few quick questions for the things it can't detect (sudo policy, GUI-app packaging preference, hardware quirks, services to surface).

2. **Profile is persisted** to `$CLAUDE_USER_DATA/desktop-manager/profile.json` (falling back to `$XDG_DATA_HOME/claude-plugins/desktop-manager/` and then `~/.local/share/claude-plugins/desktop-manager/`). It lives **outside** the plugin install tree, so plugin upgrades don't touch it and it doesn't get committed to git.

3. **Every command reads the profile** and uses it instead of re-detecting. KDE+Wayland boxes get `wlr-randr` and `kwriteconfig`; GNOME+X11 boxes get `xrandr` and `gsettings`; pipewire boxes get `wpctl` flows.

4. **Surgical edits**: `/desktop-manager:update-profile <field> [value]` for one-off changes (e.g. you switched to Wayland, swapped GPU, added a new service to watch).

## Skills

- `/desktop-manager:onboard` — auto-profile + interview, persist `profile.json`. Run on first install or when the machine changes.
- `/desktop-manager:update-profile` — surgical field edits.
- `/desktop-manager:new-workspace <name> [<target-path>] [--local-only] [--private]` — scaffold a workspace on disk for tracking install / config / hw-triage notes over time.

## Commands

All commands refuse to run without a `profile.json` and point you at `/desktop-manager:onboard`.

- `/desktop-manager:check-system` — live snapshot anchored against the recorded profile, flags drift.
- `/desktop-manager:install-package` — install via the recorded package manager(s); honours your GUI-app preference and ambiguity policy.
- `/desktop-manager:remove-package` — reverse-deps first, then remove.
- `/desktop-manager:update-system` — refresh + upgrade across native + flatpak + snap; honours `auto_reboot_after_update`.
- `/desktop-manager:apply-config` — DE-aware config change with rollback path (KDE / GNOME / XFCE / MATE / direct file).
- `/desktop-manager:inspect-service` — systemd unit status + logs + failure signatures (refuses on non-systemd).
- `/desktop-manager:review-logs` — journalctl + dmesg filtered for errors; surfaces `services_of_interest`.
- `/desktop-manager:troubleshoot-hardware` — class-based probes (audio/display/usb/bt/net/input), variant-picked from profile.

## Profile schema

See `lib/PROFILE.md` for the full schema and field semantics.

## Install

```
/plugin marketplace add danielrosehill/Claude-Code-Plugins
/plugin install desktop-manager
/desktop-manager:onboard
```

## License

MIT.
