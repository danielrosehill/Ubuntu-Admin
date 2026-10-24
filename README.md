# Ubuntu-Admin

![License: MIT](https://img.shields.io/badge/license-MIT-green)
![Ubuntu 22.04 | 24.04 | 26.04](https://img.shields.io/badge/Ubuntu-22.04%20%7C%2024.04%20%7C%2026.04-E95420)

Agent skills for administering **Ubuntu machines, desktop or server, on the local machine or over SSH**.

Plugin name: `ubuntu-admin`. It has 46 skills, 2 agents and 3 helper scripts.

## Purpose

One coherent toolkit for the everyday work of looking after Ubuntu boxes: checking health, diagnosing problems, keeping packages and services in order, running Docker, looking after disks and backups, configuring the network, and dealing with hardware. Each skill:

- **works locally or remotely**. Run commands as-is, or as `ssh <host> '<cmd>'`. Desktop and server differences are noted inline, so there are no separate desktop and server copies of the same task.
- **uses real Ubuntu tooling**: apt with deb822 sources and `signed-by` keyrings, snap, flatpak, systemd, netplan, NetworkManager, `ubuntu-drivers`, `pro`, needrestart.
- **confirms before it changes anything destructive**. Every skill that changes the system lists the steps that need a yes in a `Confirm before` section.
- **returns a short report**, not a dump of raw output.

### Conventions

| Situation | Pattern |
| --- | --- |
| One remote command | `ssh <host> '<cmd>'` |
| A block or local script on a remote host | `ssh <host> 'bash -s' < script.sh` or a `<<'EOF'` heredoc |
| Root on a remote host with a sudo password | `ssh -t <host> 'sudo <cmd>'` |
| Not sure what the host is | run `system-preflight` first |
| Managing a host repeatedly | `host-workspace` creates a folder that holds its profile, backups and logs |

### Scripts

`scripts/` holds three read-only helpers that the skills call:

- `status-snapshot.sh` prints a Markdown health snapshot. It leaves out serials and machine IDs.
- `perf-audit.sh` prints one JSON object of performance facts for `performance-audit`. Adds `vcgencmd` throttling flags on a Raspberry Pi.
- `preflight.sh` prints a JSON description of the machine: release, desktop or server, desktop environment, network renderer, virtualization, sudo, tools.

When `${CLAUDE_PLUGIN_ROOT}` is not set (for example, a skill read on its own outside an installed plugin), clone this repository and run them from there:

```bash
git clone --depth 1 https://github.com/danielrosehill/Ubuntu-Admin ~/Ubuntu-Admin
bash ~/Ubuntu-Admin/scripts/preflight.sh                      # local
ssh <host> 'bash -s' < ~/Ubuntu-Admin/scripts/status-snapshot.sh  # remote
```

## Skills

### System

| Skill | What it does |
| --- | --- |
| `system-preflight` | Detects release, desktop or server, desktop environment and session, network renderer, VM, sudo and tools, as JSON. |
| `system-status` | Read-only health snapshot: load, memory, disks, failed units, errors, updates, reboot flag, Docker. |
| `system-diagnose` | Triage of a live problem from fresh journal, kernel, unit, OOM and coredump evidence. |
| `system-resources` | Slowdowns, memory pressure, swap, runaway, zombie and I/O-blocked processes; live monitoring. |
| `performance-audit` | Repeatable spot check: load, PSI, active swapping, OOM kills, disks, containers at their limits, temperatures; ranked report and a per-host trend log. Reuses the saved hardware profile. |
| `system-config-edit` | Back up, edit, validate (`sshd -t`, `netplan try`, `visudo -c` and others), reload, roll back. |
| `system-change-log` | Dated problem, cause, fix and reverse record of a change, with optional git commit. |
| `system-virtualization` | KVM/libvirt host readiness, nested virtualization and IOMMU; guest detection and agents. |
| `host-workspace` | Creates an admin workspace (CLAUDE.md/AGENTS.md, context, backups, outputs) for a host or fleet. |

### Packages

| Skill | What it does |
| --- | --- |
| `packages-apt-health` | Repairs broken dpkg and apt: locks, half-configured packages, held packages, missing keys. |
| `packages-repos` | Audits and cleans APT sources, PPAs and third-party repos; migrates apt-key to keyrings. |
| `packages-updates` | Pending and security updates, upgrades, reboot-required, needrestart, unattended-upgrades, release upgrades. |
| `packages-install` | Picks the best install method (apt, vendor repo, snap, flatpak, .deb, AppImage, GitHub release) and installs it. |
| `packages-snap-flatpak` | Snap refresh, hold and old revisions; Flatpak remotes, unused runtimes and overrides. |
| `packages-cli-tools` | Installs and verifies common CLIs: gh, aws, rclone, b2, pipx, uv, brew, SDKMAN, yadm. |

### Services

| Skill | What it does |
| --- | --- |
| `services-check` | Sweeps systemd for failed, flapping and degraded units and reviews what is enabled at boot. |
| `services-manage` | Start, stop, enable and mask units; drop-in overrides; new units and timers; resource limits. |
| `services-logs` | Fetches, saves and summarises unit or time-window logs, local or remote; follows them live. |
| `services-mail-relay` | Lets a host send notification mail (msmtp or postfix relay) and tests it. |

### Docker

| Skill | What it does |
| --- | --- |
| `docker-setup` | Docker Engine from Docker's apt repo, compose plugin, daemon.json log rotation, groups. |
| `docker-health` | Daemon and containers: unhealthy, restarting, logs, stats, networks, volume permissions. |
| `docker-cleanup` | Space report, then targeted pruning of images, containers, build cache, volumes and logs. |
| `docker-compose-deploy` | Deploys, updates and rolls back compose stacks; one directory per stack. |

### Storage

| Skill | What it does |
| --- | --- |
| `storage-drive-health` | SMART and NVMe health, self-tests, smartd monitoring. |
| `storage-filesystems` | fstab sanity, ext4, XFS and BTRFS checks, scrubs, Snapper and Timeshift snapshot health. |
| `storage-raid-lvm` | mdadm arrays (degraded or rebuilding), LVM inspect and extend, ZFS pool status. |
| `storage-network-mounts` | NFS and SMB/CIFS mounts, fstab and systemd automount, stale handles. |
| `storage-backup` | What to back up, the state of existing jobs and restore points, test restores, a restic or rclone timer. |
| `storage-reclaim-space` | Frees space on a full disk: journal, apt, old kernels, snaps, logs, core dumps. |

### Network

| Skill | What it does |
| --- | --- |
| `network-diagnose` | Live network triage: links, DHCP, DNS (resolvectl), routes, Wi-Fi, LAN reachability, listening ports. |
| `network-config` | netplan and NetworkManager configuration: static IP, DNS, bridges, hostname; `netplan try`. |
| `network-lan-scan` | Discovers LAN hosts (arp-scan, nmap -sn, avahi) and writes a Markdown LAN map. |
| `network-ssh-hosts` | `~/.ssh/config` aliases, reachability tests, ssh-copy-id, multiplexing, sudo over SSH. |
| `network-cloudflared-tunnel` | Installs, checks and troubleshoots a cloudflared tunnel service and its ingress rules. |

### Hardware

| Skill | What it does |
| --- | --- |
| `hardware-profile` | AI- and human-readable hardware profile (CPU, RAM, board, storage, GPU, NICs), saved once per host under `$CLAUDE_USER_DATA/host-profiles/`; hw-probe, compatibility checks. |
| `hardware-gpu` | GPU driver state, `ubuntu-drivers`, NVIDIA, AMD/ROCm, Intel, Secure Boot/MOK, ML readiness, passthrough. |
| `hardware-usb-input` | USB device tree, hot-plug events, autosuspend, scancodes (evtest), key remapping. |
| `hardware-power` | Suspend and hibernate, wake sources, lid and idle behaviour, power profiles, Wake-on-LAN. |

### Desktop

| Skill | What it does |
| --- | --- |
| `desktop-displays` | Lists displays, multi-monitor, scaling and display profiles on GNOME, X11 and wlroots (KDE goes to kde-plasma). |
| `desktop-fonts` | Lists fonts and installs them per user or system-wide, including Google Fonts by name. |
| `desktop-codecs` | Media codec and hardware video acceleration checks; restricted-extras and GStreamer plugins. |

### Shell, files and dev

| Skill | What it does |
| --- | --- |
| `shell-aliases` | Add, edit, prune, list, document and back up `~/.bash_aliases`. |
| `shell-config` | Validates bashrc and profile, analyses PATH, handles environment files and yadm dotfiles. |
| `dev-environment` | Python (uv, pipx, pyenv), Node, Java (SDKMAN) and other SDK inventory and setup; git global config. |
| `files-permissions` | Debugs "permission denied": path walk, ACLs, groups, mount options, AppArmor and snap denials. |
| `files-organise` | Tidies a directory: sort by type, flatten, chunk, split photos and video, consolidate, always as a dry run first. |

## Agents

| Agent | Role |
| --- | --- |
| `ubuntu-operator` | Carries out multi-step admin work across one or more hosts: plan, back up, validate, confirm destructive steps, log. |
| `ubuntu-troubleshooter` | Read-only investigator. Goes from evidence to root cause across logs, services, resources, Docker, storage and network. Proposes fixes but does not apply them. |

## Related plugins

These areas are deliberately left out and handled elsewhere:

| Area | Plugin |
| --- | --- |
| Firewall, SSH hardening, keys, antivirus, audits, certificates | `ubuntu-security` |
| KDE Plasma (shortcuts, panels, kscreen, reset) | `kde-plasma` |
| Bluetooth | `linux-bt` |
| Journal, boot and crash forensics, OOM history, kdump | `linux-debugging` |
| Benchmarks, tuning, deep disk-usage analysis, duplicates, dev clutter, package audits | `linux-system-optimisation` |
| PipeWire audio | `pipewire-audio` |
| Printers | `network-cups` |
| .deb packaging and releases | `linux-packaging` |

## Supersedes

This plugin replaces three older plugins. They are not deleted, but new work goes here.

- `linux-desktop-mgmt`: 275 command files, 150 of them unique, plus 2 skills. About half were byte-identical copies under a second, prefixed path (for example `check-apt-health` and `package-management-check-apt-health`). Each pair maps to the same target below.
- `linux-server-mgmt`: 43 commands and 10 agents.
- `sysadmin-homelab`: 14 commands, 1 agent, 1 skill and 9 workspace templates.

Abbreviations below: D = linux-desktop-mgmt, S = linux-server-mgmt, H = sysadmin-homelab.

### Ported: old to new

| New skill / agent | Old items |
| --- | --- |
| `system-status` | D `system-health`, `system-health-checkup`; S `hardware/system-health`, `notifications/uptime-stats`; H `status` |
| `system-diagnose` | H `diagnose`, `diagnose-crash`; D `diagnose-crash` (live part) |
| `system-resources` | D `diagnose-slowdown`, `monitor-system-resources`; S `notifications/process-monitor`, `notifications/resource-alerts`; H `diagnose-memory` |
| `system-preflight` | D skill `os-preflight`; S `documentation/document-distro` |
| `system-config-edit` | H `update-config`, `backup-config` |
| `system-change-log` | D skill `log-desktop-fix`; S agent `server-documentarian` |
| `system-virtualization` | D `check-virtualization`; S `hardware/proxmox-status` (guest side) |
| `host-workspace` | H skill `new-workspace` and templates `linux-servers`, `docker`, `remote-admin`, `lan`, `single-board-computers` (merged into one template); D `setup-machine-profile`; S `claude-setup` |
| `packages-apt-health` | D `check-apt-health` |
| `packages-repos` | D `check-third-party-repos` |
| `packages-updates` | D `system-upgrade`, `configure-auto-updates`; S `updates/check-updates`, `updates/update-check`, `updates/manage-autoupdate` |
| `packages-install` | D `install-package-best`, `install-this`, `install-from-gh`, `install-github-program`, `input-remapper`, `optimize-vscode-installation` |
| `packages-snap-flatpak` | New: snap and flatpak upkeep that the old plugins scattered across other commands |
| `packages-cli-tools` | D `install-brew`, `installation-clis-install-brew`, `install-gh-cli`, `install-pipx`, `install-sdkman`, `install-yadm`, `setup-aws-cli`, `setup-b2-cli`, `setup-rclone`; S `backups/verify-backup-clis`, `backups/verify-github-cli` |
| `dev-environment` | D `identify-python-environments`, `setup-pyenv`, `manage-conda-environments`, `node-version-check`, `npm-install`, `sdk-check`, `check-git-config`, `check-global-gitignore` |
| `shell-aliases` | D `add-bash-alias`; H `manage-aliases`, `list-aliases`, `document-aliases`, `backup-aliases` |
| `shell-config` | D `validate-bashrc`, `check-path`, `check-yadm`, `manually-update-yadm` |
| `services-check` | D `check-failed-units`, `review-startup-services`, `failed-boot-services`, `service-monitor`; S `general/check-services`, agent `service-monitor`; H `check-services` |
| `services-manage` | New: unit, override and timer authoring, which the old status commands only pointed at |
| `services-logs` | D `tail-system-logs`, `analyze-journal-errors`; S `logs/analyze-logs`, `logs/check-logs-noteworthy`, agent `log-analyzer`; H `logs` |
| `services-mail-relay` | S `testing/email-test` |
| `docker-setup` | D `setup-docker`; S `docker/check-docker-permissions` (group part) |
| `docker-health` | S `docker/docker-health`, `docker/prune-docker`, `filesystem/volume-check`, `docker/check-docker-permissions`, agent `docker-troubleshooter` |
| `docker-cleanup` | S `docker/cleanup-docker` |
| `docker-compose-deploy` | S `deployments/deployment-list`, agent `deployment-manager` |
| `storage-drive-health` | D `check-drive-health` |
| `storage-filesystems` | D `filesystem-health`, `btrfs-snapper-health`; S `disk/filesystem-health`, `hardware/xfs-check` |
| `storage-raid-lvm` | D `check-raid-config`; S `hardware/raid-status`, agent `storage-manager` (also a duplicate in D) |
| `storage-network-mounts` | D `setup-nfs-mounts`, `setup-smb-mounts`; S `nfs/check-nfs-mounts` |
| `storage-backup` | D `identify-backup-targets`; S `backups/backup-status`, `backups/check-restore-points`, agent `backup-manager` |
| `storage-reclaim-space` | D `disk-usage`, `large-files`; S `disk/disk-usage`, `filesystem/cleanup-filesystem` |
| `network-diagnose` | D `network-health`, `diagnose-lan-connectivity`; S `networking/network-health`, `networking/check-lan-connectivity`, `networking/port-check`; H `diagnose-network` |
| `network-config` | New: netplan and NetworkManager configuration (the old plugins had diagnosis only) |
| `network-lan-scan` | D `scan-lan`, `smart-arp` |
| `network-ssh-hosts` | D `list-ssh-connections`, `lan-ssh-setup`; S `networking/configuration-ssh-list-ssh-connections` |
| `network-cloudflared-tunnel` | S `networking/tunnel-status`, agent `tunnel-manager` |
| `hardware-profile` | D `hardware-profile`, `hardware-identity`, `profile-cpu`, `profile-gpu`, `profile-motherboard`, `profile-ram`, `hardware-check`, `benchmark-hardware` (inventory part); H `hw-probe` |
| `hardware-gpu` | D `gpu-status`, `review-gpu-settings`, `check-gpu-os-optimization`, `gpu-ai-ml-assessment`; S `hardware/gpu-status` |
| `hardware-usb-input` | D `list-usb-devices`, `evtest`, `input-remapper` |
| `hardware-power` | D `hibernation`, `evaluate-wake-devices`, `wol-setup` |
| `desktop-displays` | D `list-connected-displays`, `setup-multi-monitor`, `optimize-display-scaling`, `switch-display-profile`, `capture-current-config` |
| `desktop-fonts` | D `list-fonts`, `install-google-fonts` |
| `desktop-codecs` | D `check-codecs`, `codecs`, `video-codecs` |
| `files-permissions` | D `debug-folder-permissions` |
| `files-organise` | D `desktop-tidy`, `flatten`, `chunk-this-dir`, `separate-by-filetype`, `separate-photos-and-video`, `consolidate-folders`, `organize-loose-files`, `suggest-folder-structure` |
| agent `ubuntu-operator` | H agent `sysadmin-operator`; S agents `deployment-manager`, `service-monitor` (operational parts) |
| agent `ubuntu-troubleshooter` | S agents `log-analyzer`, `docker-troubleshooter`, `performance-optimizer` |

### Sent to `ubuntu-security`

- D `analyze-firewall`, `detect-spyware`, `probe-vulnerabilities`, `security-posture-check`, `write-audit`, `yubi-setup`, `fingerprint-scanner` (empty file), `install-clamav`, `manage-ssh-keys`, `configuration-secrets-manage-api-keys`
- S `seurity/certificate-check`, `seurity/firewall-check`, `seurity/security-audit`, `networking/configuration-ssh-manage-ssh-keys`, agent `security-auditor`
- Firewall rule inspection that used to sit inside S `networking/port-check`

### Covered by another plugin

| Old item | Covered by |
| --- | --- |
| D `backup-kde-settings`, `list-kde-shortcuts`, `reset-plasma-config`, `optimize-kde-performance` | `kde-plasma` (panel-layout-backup, keyboard-shortcuts, plasma-restart, kwriteconfig-edit) |
| D `reset-bluetooth`, `troubleshoot-bluetooth` | `linux-bt` |
| D `check-boot-logs`, `review-boot`, `boot-time`, `optimize-boot-speed`, `diagnose-crash` (post-mortem part); S `optimisation/boot-time` | `linux-debugging` (boot-inspect, journal-inspect, investigate-last-crash) |
| D `benchmark-gpu`, `benchmark-hardware` (benchmark part), `identify-unused-packages`, `evaluate-installed-software`; S `benchmarking/benchmark-gpu`, `benchmarking/benchmark-hardware` | `linux-system-optimisation` (benchmark, optimise, audit-installed) |
| D `optimize-pipewire`, `mic-always-100`, `set-as-default-mic` | `pipewire-audio` |
| D `diagnose-printers` | `network-cups` |

### Dropped

| Old item | Reason |
| --- | --- |
| D `system-prompt`, `system-prompt-original`, `system-prompt-to-agent` | Personal desktop-to-laptop sync prompt and a repo-conversion prompt; not admin tasks |
| D `mgmt-to-add-1` | A to-do list for writing commands, not a command |
| D `network-diagram` | Documentation of the old plugin's agent routing; obsolete |
| D `optimize-paragraph-breaks`, `optimize-for-web`, `optimize-fonts`, `optimize-dashboard` | Writing and web-design prompts, not system administration |
| D `ai-clis`, `evaltools` | Personal "suggest AI tools to install" seeders |
| D `setup-ollama`, `prune-ollama`, `suggest-ollama-models`, `hw-benchmark`, `audit-local-ai-packages`, `setup-comfyui`, `setup-speech-to-text`, `manage-mcp-servers` | Local-AI app setup, out of scope for OS administration. GPU and ML readiness is kept in `hardware-gpu`. |
| D `setup-conda-data-analysis`, `setup-conda-llm-finetune`, `setup-conda-rocm`, `setup-conda-stt-finetune` | Project-specific environment recipes. Conda detection is kept in `dev-environment`. |
| D `suggest-ides` | Generic recommendation list. Installing an editor goes through `packages-install`. |
| D `delete-old-repos`, `organise-repos` | Personal repository housekeeping |
| H templates `android-debug`, `conda`, `nas-synology`, `proxmox` | Not Ubuntu administration |
| H README entries `diagnose-audio`, `diagnose-gpu`, `diagnose-usb` | Listed in the old README but never shipped as files. `hardware-gpu` and `hardware-usb-input` cover the topics; audio goes to `pipewire-audio`. |

## Install

Point your agent at this repository's `skills/` folder, or install it from a marketplace that lists `ubuntu-admin`. Each skill is self-contained Markdown. The two scripts are optional accelerators, and every skill gives the manual commands too.

## License

MIT. See [LICENSE](LICENSE).
