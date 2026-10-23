---
name: shell-config
description: Check and fix bash shell configuration on Ubuntu — validate ~/.bashrc, ~/.profile and ~/.bash_profile (syntax, shellcheck, slow startup), explain login vs non-login loading, analyse PATH (duplicates, missing directories, ~/.local/bin, ordering and shadowed binaries), set environment variables in the right place (~/.profile, environment.d, /etc/environment), and manage dotfiles with yadm (status, add, commit, push, bootstrap on a new machine). Use when asked "check my bashrc", "my PATH is a mess", "command not found after install", "where do I set this env var", "terminal is slow to open", "sync my dotfiles", "yadm status". Works on the local machine or a remote host over SSH.
---

# Shell configuration

## Target

Local by default. Remote: `ssh <host> '<cmd>'`. Note that `ssh <host> '<cmd>'` runs a **non-interactive, non-login** shell — Ubuntu's `.bashrc` returns early for non-interactive shells, so PATH seen over plain SSH differs from a terminal. Use `ssh -t <host> 'bash -lic "<cmd>"'` to see the interactive view.

## 1. Which files load when

| Shell | Reads |
| --- | --- |
| Login (console, `ssh host` interactive, `bash -l`) | `/etc/profile` → first of `~/.bash_profile`, `~/.bash_login`, `~/.profile` |
| Interactive non-login (terminal emulator) | `/etc/bash.bashrc`, `~/.bashrc` |
| Desktop session (GNOME/KDE) | `~/.profile` via the display manager, plus `~/.config/environment.d/*.conf` (systemd user env) |

Ubuntu's `~/.profile` sources `~/.bashrc` and adds `~/bin` and `~/.local/bin` to PATH if they exist **at login**. A `~/.bash_profile` stops `~/.profile` from loading — a common cause of "my PATH changes vanished".

## 2. Validate

```bash
ls -la ~/.bashrc ~/.profile ~/.bash_profile ~/.bash_login ~/.bash_aliases 2>/dev/null
for f in ~/.bashrc ~/.profile ~/.bash_profile ~/.bash_aliases; do [ -f "$f" ] && { bash -n "$f" && echo "ok  $f" || echo "ERR $f"; }; done
command -v shellcheck >/dev/null && shellcheck -s bash -e SC1090,SC1091 ~/.bashrc ~/.profile
diff <(cat /etc/skel/.bashrc) ~/.bashrc | head -80        # what was customised vs the Ubuntu default
time bash -ic exit                                        # startup time; > 0.5 s is worth profiling
PS4='+ $EPOCHREALTIME ' bash -xic exit 2>&1 | head -200   # find the slow lines (nvm, conda init are typical)
```

Flag: syntax errors, the same block appended multiple times (installers re-adding init lines), secrets exported in plain files (just note the location; don't print values), commands that print output (breaks scp/rsync).

## 3. PATH analysis

```bash
echo "$PATH" | tr ':' '\n' | nl
echo "$PATH" | tr ':' '\n' | sort | uniq -d                          # duplicates
echo "$PATH" | tr ':' '\n' | while read d; do [ -d "$d" ] || echo "missing: $d"; done
type -a python3 node pip 2>/dev/null                                  # shadowing: first hit wins
grep -nE 'PATH=' ~/.bashrc ~/.profile ~/.bash_profile /etc/environment ~/.config/environment.d/*.conf 2>/dev/null
```

Good order: user dirs (`~/.local/bin`, version-manager shims) before system dirs only when intended. Add PATH entries idempotently:

```bash
case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) PATH="$HOME/.local/bin:$PATH" ;; esac
```

"Command not found right after install" → `hash -r`, or `~/.local/bin` didn't exist at login (log out/in, or source `~/.profile`).

## 4. Where to set environment variables

- Interactive shell only (prompt, aliases): `~/.bashrc`.
- Per-user, all sessions including GUI apps: `~/.profile` or `~/.config/environment.d/<name>.conf` (`KEY=value`, no `export`).
- System-wide: `/etc/environment` (plain `KEY=value`, no expansion) or `/etc/profile.d/<name>.sh`.
- For a systemd service: `Environment=`/`EnvironmentFile=` in the unit — services read none of the above.

## 5. Dotfiles with yadm

```bash
yadm status
yadm list -a                         # tracked files
yadm diff --stat
yadm add ~/.bashrc ~/.bash_aliases && yadm commit -m "<message>" && yadm push
yadm remote -v
# new machine
yadm clone <repo-url> && yadm bootstrap   # runs ~/.config/yadm/bootstrap if present
yadm alt                                  # per-host/OS alternates: file##os.Linux, file##hostname.<host>
```

Never add private keys or tokens to the dotfiles repo; use yadm's encryption (`~/.config/yadm/encrypt` + `yadm encrypt`) or keep them out. Alternatives: chezmoi (templating, secrets-manager integration), GNU Stow (symlinks from a plain git repo).

## Desktop vs server

- **Desktop**: GUI-launched apps ignore `~/.bashrc` — set their variables in `~/.profile` or environment.d.
- **Server**: cron and systemd don't load shell files; scripts must set PATH themselves or use absolute paths.

## Confirm before

- Editing any shell init file (back it up first: `cp ~/.bashrc ~/.bashrc.$(date +%Y%m%d%H%M%S).bak`).
- Editing `/etc/environment` or `/etc/profile.d/`.
- `yadm push`, or adding new files to a dotfiles repo (could be public).

## Report

Files checked and their status, PATH findings (duplicates, missing, shadowed), startup time and slow lines, env-var placement advice, dotfiles state, and changes made with backup paths.

## Related

- `shell-aliases` — `~/.bash_aliases`.
- `dev-environment` — version-manager init lines.
- `packages-cli-tools` — installing yadm.
