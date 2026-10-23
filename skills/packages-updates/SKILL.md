---
name: packages-updates
description: Check for and apply Ubuntu updates and manage automatic updating — pending security vs regular updates, phased and kept-back packages, apt upgrade vs full-upgrade, reboot-required and needrestart, old-kernel cleanup, unattended-upgrades configuration (20auto-upgrades, 50unattended-upgrades, origins, auto-reboot window, mail) and its logs, plus release upgrades with do-release-upgrade. Use when asked "any updates?", "update the server", "patch <host>", "does it need a reboot", "configure automatic updates", "unattended-upgrades", "upgrade to the next LTS". Works on the local machine or a remote host over SSH.
---

# Updates

Read first, then act. Applying updates and changing auto-update policy are confirm-first.

## Target

Local by default. Remote: `ssh <host> '<cmd>'`; root: `ssh -t <host> 'sudo <cmd>'`. For long upgrades over SSH, run inside `tmux` or `screen` on the host so a dropped connection doesn't kill dpkg mid-run.

## 1. What is pending

```bash
sudo apt-get update -q
apt list --upgradable 2>/dev/null | tail -n +2
apt list --upgradable 2>/dev/null | grep -c -- '-security'          # security-pocket updates
/usr/lib/update-notifier/apt-check --human-readable 2>/dev/null       # "N updates can be applied, M are security"
sudo apt-get -s upgrade | grep -A50 'kept back'                       # held back by dependencies or phasing
apt-mark showhold
pro status 2>/dev/null | grep -E 'esm-(infra|apps)'                   # ESM coverage (Ubuntu Pro)
```

**Phased updates**: Ubuntu rolls some updates out gradually; `apt` reports them as "deferred due to phasing" or "kept back". That is normal — do not force them with `-o APT::Get::Always-Include-Phased-Updates=1` unless the user needs that specific fix.

Snaps update on their own; see `snap refresh --list` (`packages-snap-flatpak`).

## 2. Apply

```bash
sudo apt-get upgrade              # never removes packages
sudo apt-get full-upgrade         # may install/remove to resolve deps (new kernels land via this or upgrade on recent releases)
sudo apt-get autoremove --purge   # old kernels and orphaned deps — review the list
```

Always show the plan (`-s` or the interactive prompt) before confirming on a server.

## 3. Restart needs

```bash
[ -f /var/run/reboot-required ] && cat /var/run/reboot-required.pkgs
sudo needrestart -r l -b 2>/dev/null     # batch list: kernel status + services using outdated libraries
uname -r; dpkg -l 'linux-image-[0-9]*' | awk '/^ii/{print $2}'   # running vs installed kernels
```

needrestart (installed by default on server since 22.04) restarts services itself in interactive mode; on servers prefer `-r l` (list) and restart services deliberately. Kernel updates need a reboot unless Livepatch is enabled (`canonical-livepatch status`).

## 4. Kernel cleanup

Ubuntu keeps the running kernel plus one previous via `autoremove`. If `/boot` is full:

```bash
df -h /boot
dpkg -l 'linux-image-*' 'linux-modules-*' | awk '/^ii/{print $2,$3}'
sudo apt-get autoremove --purge
```

Never remove the running kernel (`uname -r`). Avoid manual `dpkg --purge` of kernels unless autoremove can't run because /boot is already full — then remove the oldest single non-running one first.

## 5. Automatic updates (unattended-upgrades)

```bash
dpkg -l unattended-upgrades | tail -1
cat /etc/apt/apt.conf.d/20auto-upgrades
grep -vE '^\s*(//|$)' /etc/apt/apt.conf.d/50unattended-upgrades
systemctl list-timers 'apt-daily*' --no-pager
sudo unattended-upgrade --dry-run --debug 2>&1 | tail -20
tail -50 /var/log/unattended-upgrades/unattended-upgrades.log
```

Enable: `sudo apt-get install unattended-upgrades && sudo dpkg-reconfigure -plow unattended-upgrades`, which writes:

```
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
```

Tune in a drop-in rather than editing the packaged file — e.g. `/etc/apt/apt.conf.d/52unattended-upgrades-local`:

```
Unattended-Upgrade::Allowed-Origins {
        "${distro_id}:${distro_codename}-security";
        "${distro_id}ESMApps:${distro_codename}-apps-security";
        "${distro_id}ESM:${distro_codename}-infra-security";
//      "${distro_id}:${distro_codename}-updates";      // uncomment for all stable updates
};
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "true";
Unattended-Upgrade::Automatic-Reboot-Time "04:00";
Unattended-Upgrade::Mail "<admin-email>";             // needs a working MTA, see services-mail-relay
Unattended-Upgrade::MailReport "only-on-error";
```

Third-party repos are added with `Unattended-Upgrade::Origins-Pattern { "origin=Docker"; };` — check the origin string with `apt-cache policy`.

Validate syntax: `sudo unattended-upgrade --dry-run --debug`.

## 6. Release upgrade

```bash
cat /etc/update-manager/release-upgrades     # Prompt=lts | normal | never
do-release-upgrade -c                         # is a new release available?
```

Before running: system fully updated, a backup verified (`storage-backup`), ≥ 5 GB free on `/`, third-party repos noted (they will be disabled), console or out-of-band access for servers. Then `sudo do-release-upgrade` (it opens a fallback sshd on port 1022 when run over SSH). LTS-to-LTS upgrades are offered only after the new LTS's first point release unless `-d` is used.

## Desktop vs server

- **Desktop**: the Software Updater/Discover also applies updates; default is security updates automatically, others via prompt. Automatic reboot is usually unwanted.
- **Server**: security-only auto-updates plus a maintenance reboot window is the common baseline. Coordinate reboots across hosts that depend on each other.

## Confirm before

- `apt-get upgrade` / `full-upgrade` / `autoremove` on any server, and any removal of packages.
- Rebooting or restarting services flagged by needrestart.
- Changing unattended-upgrades origins or enabling automatic reboot.
- `do-release-upgrade` — explicit yes from the user, after the checklist above.

## Report

Counts (security / regular / kept back / phased), what was applied, reboot required (yes/no, why), services needing restart, auto-update policy in effect, anything held.

## Related

- `packages-apt-health` — when updates fail.
- `packages-repos` — repos disabled by a release upgrade.
- `packages-snap-flatpak` — snap and flatpak updates.
- `system-status` — pending updates as part of the health sweep.
