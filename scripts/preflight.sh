#!/usr/bin/env bash
# preflight.sh — detect what kind of Ubuntu machine this is, as JSON.
#
# Local:   bash preflight.sh
# Remote:  ssh <host> 'bash -s' < preflight.sh
#
# Read-only. Prints one JSON object on stdout so an agent can branch on it.
# Part of the ubuntu-admin agent skills: https://github.com/danielrosehill/Ubuntu-Admin

set -u
have() { command -v "$1" >/dev/null 2>&1 && echo true || echo false; }
json_str() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }

. /etc/os-release 2>/dev/null
id="${ID:-unknown}"; like="${ID_LIKE:-}"; ver="${VERSION_ID:-unknown}"
codename="${VERSION_CODENAME:-${UBUNTU_CODENAME:-unknown}}"
is_ubuntu=false
case "$id $like" in *ubuntu*) is_ubuntu=true ;; esac
lts=false
case "${VERSION:-}" in *LTS*) lts=true ;; esac

# Desktop vs server: a graphical target or an installed desktop meta-package.
default_target=$(systemctl get-default 2>/dev/null || echo unknown)
desktop_pkg=$(dpkg-query -W -f='${db:Status-Abbrev} ${Package}\n' 'ubuntu-desktop*' 'kubuntu-desktop' 'xubuntu-desktop' \
  'ubuntu-mate-desktop' 'lubuntu-desktop' 'ubuntucinnamon-desktop' 'ubuntu-budgie-desktop' 2>/dev/null \
  | awk '$1=="ii" {print $2; exit}')
role=server
if [ "$default_target" = "graphical.target" ] || [ -n "$desktop_pkg" ]; then role=desktop; fi

# Desktop environment of any active graphical session (works over SSH too).
de="${XDG_CURRENT_DESKTOP:-}"
if [ -z "$de" ] && command -v loginctl >/dev/null 2>&1; then
  for s in $(loginctl list-sessions --no-legend 2>/dev/null | awk '{print $1}'); do
    t=$(loginctl show-session "$s" -p Type --value 2>/dev/null)
    if [ "$t" = "wayland" ] || [ "$t" = "x11" ]; then
      de=$(loginctl show-session "$s" -p Desktop --value 2>/dev/null); session_type="$t"; break
    fi
  done
fi
session_type="${session_type:-${XDG_SESSION_TYPE:-none}}"

# Network renderer
if systemctl is-active --quiet NetworkManager 2>/dev/null; then net=NetworkManager
elif systemctl is-active --quiet systemd-networkd 2>/dev/null; then net=systemd-networkd
else net=unknown; fi

virt=$(systemd-detect-virt 2>/dev/null); virt="${virt:-none}"
sudo_nopass=false; sudo -n true 2>/dev/null && sudo_nopass=true

cat <<EOF
{
  "hostname": "$(json_str "$(hostname)")",
  "distro_id": "$(json_str "$id")",
  "distro_like": "$(json_str "$like")",
  "version": "$(json_str "$ver")",
  "codename": "$(json_str "$codename")",
  "is_ubuntu_family": $is_ubuntu,
  "lts": $lts,
  "role": "$role",
  "desktop_meta_package": "$(json_str "$desktop_pkg")",
  "default_target": "$(json_str "$default_target")",
  "desktop_environment": "$(json_str "$de")",
  "session_type": "$(json_str "$session_type")",
  "network_renderer": "$net",
  "netplan": $(have netplan),
  "init": "$(json_str "$(ps -p 1 -o comm= 2>/dev/null)")",
  "virtualization": "$(json_str "$virt")",
  "arch": "$(uname -m)",
  "kernel": "$(uname -r)",
  "sudo_without_password": $sudo_nopass,
  "tools": {
    "apt": $(have apt), "snap": $(have snap), "flatpak": $(have flatpak),
    "docker": $(have docker), "podman": $(have podman), "smartctl": $(have smartctl),
    "nvidia_smi": $(have nvidia-smi), "ubuntu_drivers": $(have ubuntu-drivers),
    "pro": $(have pro), "needrestart": $(have needrestart)
  }
}
EOF
