---
name: packages-snap-flatpak
description: Manage snaps and flatpaks on Ubuntu — list, refresh, hold or schedule snap refreshes, limit retained revisions and remove disabled ones to reclaim disk, inspect snap services and interface connections; set up Flathub, update, remove unused runtimes and adjust flatpak permissions with overrides. Use when asked "snap is using too much space", "stop snap auto-updating", "hold this snap", "snap refresh", "set up flathub", "flatpak can't see my files", "remove unused flatpak runtimes". Works on the local machine or a remote host over SSH.
---

# Snaps and flatpaks

Ubuntu ships snapd on both desktop and server images (LXD, core snaps, Firefox on desktop). Flatpak is optional and desktop-only in practice.

## Target

Local by default. Remote: `ssh <host> '<cmd>'`; root: `ssh -t <host> 'sudo <cmd>'`. Flatpak user installs (`--user`) are per-user — run as that user.

## Snaps

### Inventory

```bash
snap version
snap list                              # installed, current revisions, tracking channel, publisher
snap list --all | awk '/disabled/'     # old revisions kept on disk
du -sh /var/lib/snapd/snaps
snap refresh --list                    # updates pending
snap changes | tail -10                # recent refreshes / failures
snap services                          # daemons provided by snaps
```

### Refresh control

```bash
sudo snap refresh                                  # refresh all now
sudo snap refresh <name> --channel=<track>/stable  # switch channel
sudo snap refresh --hold=72h <name>                # pause one snap (or omit name for all; --hold with no value = indefinitely)
sudo snap refresh --unhold <name>
snap get system refresh.timer refresh.retain
sudo snap set system refresh.timer=sat,03:00-05:00 # refresh window
sudo snap set system refresh.retain=2              # keep 2 revisions (min 2)
sudo snap revert <name>                            # roll back to previous revision
```

Desktop apps pending refresh while running show "pending update" — closing the app lets it apply.

### Reclaim space

```bash
# remove disabled (old) revisions
snap list --all | awk '/disabled/{print $1, $3}' | while read n r; do sudo snap remove "$n" --revision="$r"; done
sudo rm -rf /var/lib/snapd/cache/*      # safe: hard-linked download cache
```

### Confinement and interfaces

```bash
snap connections <name>                # what the snap can access
sudo snap connect <name>:<plug> [<slot>]   # e.g. removable-media for /media and /mnt
sudo snap disconnect <name>:<plug>
snap info --verbose <name> | grep -E 'confinement|publisher'
```

"Snap can't open files outside $HOME" → connect `removable-media` or move the files; strict snaps cannot read hidden dirs in `$HOME`.

### Remove

```bash
sudo snap remove <name>                # keeps a snapshot for 31 days
sudo snap remove --purge <name>        # no snapshot
snap saved; sudo snap forget <set-id>  # snapshots consume space in /var/lib/snapd/snapshots
```

## Flatpak

### Setup

```bash
sudo apt-get install flatpak
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
# GNOME: sudo apt-get install gnome-software-plugin-flatpak ; KDE: sudo apt-get install plasma-discover-backend-flatpak
```

A logout/login is needed after the first install so exported `.desktop` files appear in menus.

### Day-to-day

```bash
flatpak list --app --columns=application,version,origin,installation
flatpak remotes
flatpak update -y
flatpak uninstall --unused             # orphaned runtimes — usually the biggest space win
flatpak uninstall --delete-data <app-id>
du -sh /var/lib/flatpak ~/.local/share/flatpak 2>/dev/null
```

### Permissions

```bash
flatpak info --show-permissions <app-id>
flatpak override --user --filesystem=/path/to/dir <app-id>     # grant
flatpak override --user --nofilesystem=home <app-id>           # revoke
flatpak override --user --show <app-id>
flatpak override --user --reset <app-id>
```

Flatseal (`com.github.tchx84.Flatseal`) is the GUI equivalent.

## Desktop vs server

- **Desktop**: Firefox and (on some releases) Thunderbird are snaps by default; flatpak is a user choice. Duplicate apps across snap/flatpak/apt are common — see `packages-install`.
- **Server**: snaps present are usually `core*`, `lxd`, `snapd`. Set `refresh.timer` to the maintenance window so snap refreshes don't restart LXD at a bad time; flatpak is rarely appropriate.

## Confirm before

- Removing snaps/flatpaks or their data (`--purge`, `--delete-data`), and removing disabled revisions in bulk.
- Holding refreshes indefinitely (security fixes stop arriving).
- Granting broad permissions (`--filesystem=host`, `--device=all`) or connecting privileged interfaces.

## Report

Snap/flatpak counts, space used and reclaimable, pending updates, refresh policy (timer/retain/holds), and any permission changes made.

## Related

- `packages-install` — choosing snap vs flatpak vs apt.
- `packages-updates` — apt side of updates.
- `storage-reclaim-space` — wider disk cleanup.
