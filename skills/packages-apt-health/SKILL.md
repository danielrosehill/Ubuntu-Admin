---
name: packages-apt-health
description: Diagnose and repair a broken APT/dpkg state on Ubuntu — held locks ("Could not get lock /var/lib/dpkg/lock-frontend"), interrupted installs, unmet dependencies, half-configured packages, held packages, NO_PUBKEY / signature errors, a full /var, and odd apt configuration. Use when asked "apt is broken", "dpkg was interrupted", "fix broken packages", "apt update fails", "unmet dependencies", "check apt health", or before a large upgrade. Works on the local machine or a remote host over SSH.
---

# APT health

Find out why apt or dpkg is failing and bring the package system back to a clean, consistent state. Start read-only; every repair step is listed under **Confirm before**.

## Target

Local by default. Remote: `ssh <host> '<cmd>'`; anything with `sudo` over SSH: `ssh -t <host> 'sudo <cmd>'`.

## 1. Read-only triage

```bash
. /etc/os-release; echo "$PRETTY_NAME"
sudo apt-get check                             # dependency consistency, no changes
dpkg --audit                                   # half-installed / unconfigured packages
dpkg -l | awk '$1 !~ /^(ii|rc)$/ && NR>5'      # anything not cleanly installed (iU, iF, iH, rH…)
apt-mark showhold                              # held packages (block upgrades)
df -h /var /boot                               # apt needs room in /var/cache and /boot
sudo apt-get update 2>&1 | grep -Ei 'err|fail|warn|NO_PUBKEY|EXPKEYSIG|not signed|Conflicting'
```

Simulate rather than act: `sudo apt-get -s dist-upgrade` shows what would break without touching anything.

## 2. "Could not get lock"

Usually something legitimate is running — most often `unattended-upgrades`, `packagekitd` (Software/Discover on desktops) or another terminal.

```bash
sudo fuser -v /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock /var/lib/apt/lists/lock /var/cache/apt/archives/lock
ps -o pid,etime,cmd -C apt,apt-get,dpkg,unattended-upgr,packagekitd
systemctl status unattended-upgrades apt-daily.service apt-daily-upgrade.service --no-pager | grep -E 'Active|Main PID'
```

- If a process holds it: **wait** for it to finish (`tail -f /var/log/unattended-upgrades/unattended-upgrades-dpkg.log`). Never delete lock files while a holder exists.
- Only if no process holds the lock (`fuser` prints nothing) and dpkg was interrupted, continue to step 3.

## 3. Repair an interrupted or inconsistent state

In this order, re-checking with `sudo apt-get check` between steps:

```bash
sudo dpkg --configure -a                 # finish configuring unpacked packages
sudo apt-get --fix-broken install        # resolve unmet dependencies (review the plan first!)
sudo apt-get install --reinstall <pkg>   # for one package with damaged files (`dpkg -V <pkg>` shows them)
```

A package whose maintainer script keeps failing: read the error in `/var/log/apt/term.log`, fix the cause (often a full disk, a missing service, a failed `update-initramfs`) rather than forcing it. `dpkg --remove --force-remove-reinstreq <pkg>` is a last resort.

Full `/boot` (common with many old kernels) breaks kernel installs — see `packages-updates` for kernel cleanup.

## 4. Signature and key errors

```bash
sudo apt-get update 2>&1 | grep -E 'NO_PUBKEY|EXPKEYSIG|is not signed'
grep -rl "<repo-host>" /etc/apt/sources.list.d/       # which source file is failing
```

`apt-key` is deprecated (removed in recent releases). Fix by fetching the vendor key into `/etc/apt/keyrings/` and referencing it with `signed-by` — the procedure is in `packages-repos`. If the repo is abandoned, disable it instead.

## 5. Configuration sanity

```bash
apt-config dump | grep -Ei 'proxy|AllowUnauthenticated|AllowInsecure|Install-Recommends|Pin'
ls /etc/apt/apt.conf.d/ /etc/apt/preferences.d/ 2>/dev/null
grep -rh 'Acquire::.*Proxy' /etc/apt/apt.conf.d/ 2>/dev/null   # a stale proxy breaks every update
```

Flag any `AllowUnauthenticated "true"` or `Trusted "yes"` / `[trusted=yes]` in sources as worth removing.

## 6. Cleanup once healthy

```bash
sudo apt-get autoremove --purge   # review the list first
sudo apt-get clean                # empties /var/cache/apt/archives
dpkg -l | awk '/^rc/{print $2}'   # removed packages with leftover config
```

## Desktop vs server

- **Desktop**: PackageKit (GNOME Software, KDE Discover) and the snap/apt "software updater" grab the lock often; close them before blaming apt.
- **Server**: unattended-upgrades is the usual lock holder, typically 06:00–07:00 local plus random delay (`systemctl list-timers apt-daily*`).

## Confirm before

- Killing any apt/dpkg process or removing a lock file.
- `apt-get --fix-broken install` or `autoremove` when the plan removes packages — show the list first.
- `dpkg --force-*` options of any kind.
- `apt-mark unhold` (the hold may be deliberate).
- Purging `rc` package configs.

## Report

1. **State** — healthy / degraded / broken, one line.
2. **Cause** — lock holder, failing package, failing repo, disk, or config, with the evidence line.
3. **Actions taken** and the result of a final `sudo apt-get check` and `sudo apt-get update`.
4. **Left over** — holds, disabled repos, anything the user should decide.

## Related

- `packages-repos` — failing or untrusted sources, key migration.
- `packages-updates` — applying upgrades, kernel cleanup, unattended-upgrades.
- `storage-reclaim-space` — when /var or /boot is full.
