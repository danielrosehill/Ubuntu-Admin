#!/usr/bin/env bash
# status-snapshot.sh — read-only health snapshot of an Ubuntu machine, printed as Markdown.
#
# Local:   bash status-snapshot.sh
# Remote:  ssh <host> 'bash -s' < status-snapshot.sh
#
# Changes nothing. Sections that need root are attempted with `sudo -n` and
# skipped (with a note) when passwordless sudo is unavailable.
# Part of the ubuntu-admin agent skills: https://github.com/danielrosehill/Ubuntu-Admin

set -u
export LC_ALL=C

have() { command -v "$1" >/dev/null 2>&1; }
section() { printf '\n## %s\n\n```\n' "$1"; }
endsection() { printf '```\n'; }

printf '# Status snapshot: %s\n\n' "$(hostname -f 2>/dev/null || hostname)"
printf 'Taken: %s\n' "$(date -Is)"

section "Identity"
# Serials, machine/boot IDs and UUIDs are left out so the output is safe to paste.
if have hostnamectl; then
  hostnamectl 2>/dev/null | sed 's/^ *//' | grep -viE '^(machine id|boot id|product uuid|hardware serial|chassis asset tag)'
else uname -a; fi
. /etc/os-release 2>/dev/null && echo "OS: ${PRETTY_NAME:-unknown}"
echo "Kernel: $(uname -r)"
v=$(systemd-detect-virt 2>/dev/null); echo "Virtualization: ${v:-none}"
echo "Session type: ${XDG_SESSION_TYPE:-none (no graphical session in this shell)}"
endsection

section "Uptime and load"
uptime
echo "CPUs: $(nproc)"
for f in cpu memory io; do
  [ -r /proc/pressure/$f ] && printf 'PSI %-6s %s\n' "$f" "$(head -1 /proc/pressure/$f)"
done
endsection

section "Memory"
free -h
swapon --show 2>/dev/null
endsection

section "Filesystems (real only)"
df -hT -x tmpfs -x devtmpfs -x squashfs -x overlay -x efivarfs 2>/dev/null
echo
echo "Inode use >= 80%:"
df -i -x tmpfs -x devtmpfs -x squashfs -x overlay -x efivarfs 2>/dev/null | awk 'NR>1 && $5+0 >= 80 {print}' || true
endsection

section "Systemd"
echo "System state: $(systemctl is-system-running 2>/dev/null)"
systemctl --failed --no-pager --no-legend 2>/dev/null || true
if [ -n "${XDG_RUNTIME_DIR:-}" ]; then
  echo "User units failed:"
  systemctl --user --failed --no-pager --no-legend 2>/dev/null || true
fi
endsection

section "Errors in the last hour (journal, priority err+)"
journalctl -p err --since "1 hour ago" --no-pager -q 2>/dev/null | tail -30 \
  || echo "(journal not readable — add the user to group systemd-journal or adm)"
endsection

section "Updates"
if have apt; then
  n=$(apt list --upgradable 2>/dev/null | tail -n +2 | wc -l)
  echo "Upgradable packages (from last apt update): $n"
  apt list --upgradable 2>/dev/null | tail -n +2 | grep -i -- '-security' | head -10
  ls -l --time-style=+%F\ %R /var/lib/apt/periodic/update-success-stamp 2>/dev/null \
    | awk '{print "Last successful apt update:", $6, $7}'
fi
if [ -f /var/run/reboot-required ]; then
  echo "REBOOT REQUIRED"; cat /var/run/reboot-required.pkgs 2>/dev/null
else
  echo "No reboot required"
fi
endsection

if have docker; then
  section "Docker"
  if docker info >/dev/null 2>&1; then
    docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}'
    echo
    echo "Not running:"
    docker ps -a --filter status=exited --filter status=dead --filter status=restarting \
      --format '{{.Names}}: {{.Status}}'
    echo
    docker system df
  elif sudo -n docker info >/dev/null 2>&1; then
    sudo -n docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}'
    sudo -n docker system df
  else
    echo "(docker present but not accessible to $(id -un) without a sudo password)"
  fi
  endsection
fi

if have snap; then
  section "Snaps"
  echo "Installed: $(snap list 2>/dev/null | tail -n +2 | wc -l)"
  echo "Disabled revisions: $(snap list --all 2>/dev/null | awk '/disabled/' | wc -l)"
  snap changes 2>/dev/null | tail -3
  endsection
fi

if have sensors; then
  section "Temperatures"
  sensors 2>/dev/null | grep -E '^(Package id|Tctl|Tdie|Composite|edge|temp1)' || true
  endsection
fi

section "Recent logins and reboots"
who
last -x -n 5 reboot shutdown 2>/dev/null | head -6
endsection
