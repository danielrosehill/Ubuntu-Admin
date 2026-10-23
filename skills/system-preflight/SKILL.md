---
name: system-preflight
description: Detect what kind of Ubuntu machine you are about to administer — Ubuntu version and LTS status, desktop or server, desktop environment and Wayland/X11, NetworkManager or systemd-networkd, VM or bare metal, passwordless sudo, and which tools (snap, flatpak, docker, smartctl, nvidia-smi) exist — and return it as JSON. Use at the start of any admin task on an unfamiliar or remote host, when a command depends on desktop vs server, or when asked "what is this box", "which Ubuntu is this", "is this a desktop or a server". Works on the local machine or a remote host over SSH.
---

# System preflight

Many admin steps differ between an Ubuntu desktop and an Ubuntu server, or between releases. Find out first, then pick the right commands. This is read-only.

## Target

Local by default; remote with `ssh <host> 'bash -s' < script` or `ssh <host> '<cmd>'`.

## Run the bundled detector

```bash
# ${CLAUDE_PLUGIN_ROOT} is set when the plugin is installed. Otherwise clone
# https://github.com/danielrosehill/Ubuntu-Admin and point at its scripts/ folder.
SCRIPT="${CLAUDE_PLUGIN_ROOT:-$HOME/Ubuntu-Admin}/scripts/preflight.sh"
[ -f "$SCRIPT" ] || git clone --depth 1 https://github.com/danielrosehill/Ubuntu-Admin "$HOME/Ubuntu-Admin"

bash "$SCRIPT"                     # local
ssh <host> 'bash -s' < "$SCRIPT"   # remote
```

It prints one JSON object: `distro_id`, `version`, `codename`, `lts`, `role` (`desktop`|`server`), `desktop_environment`, `session_type`, `network_renderer`, `virtualization`, `sudo_without_password`, and a `tools` map of booleans.

## Manual equivalents

```bash
. /etc/os-release; echo "$ID $VERSION_ID $VERSION_CODENAME"   # ubuntu 24.04 noble
systemctl get-default                                          # graphical.target => desktop
dpkg -l 'ubuntu-desktop*' 'kubuntu-desktop' 'xubuntu-desktop' 2>/dev/null | grep ^ii
loginctl list-sessions; loginctl show-session <id> -p Type -p Desktop
systemctl is-active NetworkManager systemd-networkd
systemd-detect-virt                                            # none | kvm | vmware | lxc ...
sudo -n true && echo "passwordless sudo"
```

## How to use the result

| Fact | Consequence |
| --- | --- |
| `is_ubuntu_family: false` | Stop. These skills assume apt, snapd and Ubuntu defaults. Say what was detected and which steps would not carry over. Debian works for most, but not for snap, `pro` or `ubuntu-drivers`. |
| `version` < 22.04 | The release may be past standard support. Check `pro status` and say so before anything else. |
| `role: server` | No user session units, no display/fonts/codecs skills. Network is usually netplan + systemd-networkd. |
| `role: desktop` | NetworkManager owns networking. Snap and flatpak apps are likely. User units (`systemctl --user`) matter. |
| `session_type: wayland` | `xrandr`, `xdotool` and similar X11 tools will not work. |
| `virtualization` ≠ `none` | Disk SMART, sensors, firmware and GPU checks may not apply. The hypervisor owns them. |
| `sudo_without_password: false` on a remote host | Use `ssh -t <host> 'sudo …'` so sudo can prompt, or batch root steps together. |
| `netplan: true` | Persistent network changes go through `/etc/netplan/*.yaml`, even on desktops with NetworkManager. |

## Report

One line: `Ubuntu 24.04 LTS (noble) server, KVM guest, systemd-networkd, docker present, sudo needs password`. Then carry on with the task.

## Related

- `system-status`: the health sweep that usually follows.
- `host-workspace`: record these facts permanently for a host you will manage again.
