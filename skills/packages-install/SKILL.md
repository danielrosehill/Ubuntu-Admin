---
name: packages-install
description: Install software on Ubuntu by the best available method — pick between the Ubuntu archive, a vendor apt repo, snap, flatpak, a .deb, an AppImage, a GitHub release binary or a source build, preferring whatever updates itself with least maintenance; install a downloaded .deb/AppImage/tarball; install a tool from a GitHub repository with a menu entry; or move an existing app between snap, apt and flatpak (e.g. VS Code). Use when asked "install X", "what's the best way to install X", "install this .deb / AppImage / tarball", "install from this GitHub repo", "move X from snap to apt", "add a menu entry". Works on the local machine or a remote host over SSH (GUI steps are desktop-only).
---

# Install software

Choose the install method first, then install. The goal: a working app that keeps itself updated.

## Target

Local by default. Remote: `ssh <host> '<cmd>'`; root: `ssh -t <host> 'sudo <cmd>'`. Menu entries and AppImages apply to desktops only.

## 1. Is it already installed?

```bash
command -v <app>; dpkg -l | grep -i <app>; snap list 2>/dev/null | grep -i <app>; flatpak list 2>/dev/null | grep -i <app>
ls ~/.local/bin /opt /usr/local/bin 2>/dev/null | grep -i <app>
```

Two copies (e.g. snap and apt) cause "wrong version launches" confusion — resolve that first (section 5).

## 2. Pick the method

Check what the project offers (its install docs, `apt-cache policy <pkg>`, `snap info <name>`, `flatpak search <name>`), then prefer, in order:

| Order | Method | Use when | Updates |
| --- | --- | --- | --- |
| 1 | Ubuntu archive (`apt install`) | the archive version is recent enough | with the system |
| 2 | Vendor apt repo | vendor publishes one (Docker, Google Chrome, VS Code, gh) | with the system |
| 3 | Snap | publisher is verified (✓) and snap confinement is acceptable | automatic |
| 4 | Flatpak (Flathub) | desktop GUI app, verified publisher | `flatpak update` / software centre |
| 5 | Standalone `.deb` | no repo; note many .debs add their own repo on install | only if it adds a repo |
| 6 | AppImage | portable GUI app, no other option | manual or in-app |
| 7 | GitHub release binary | CLI tools shipping static binaries | manual — note it |
| 8 | Build from source | nothing else exists | manual |

Servers: prefer 1–2, then snap; avoid flatpak and AppImage. State the recommendation and the reason, then wait for confirmation.

## 3. Install by method

```bash
sudo apt-get install <pkg>                              # archive / vendor repo (add repo via packages-repos)
sudo snap install <name> [--classic]                    # --classic only when the snap requires it
flatpak install flathub <app-id>                        # desktop; see packages-snap-flatpak for Flathub setup
sudo apt-get install ./<file>.deb                       # resolves dependencies, unlike dpkg -i
```

AppImage (desktop):

```bash
install -Dm755 <file>.AppImage ~/.local/bin/<app>.AppImage   # or /opt/<app>/ for all users
sudo apt-get install libfuse2t64 2>/dev/null || sudo apt-get install libfuse2   # 24.04+ name vs 22.04
```

Tarball: extract to `/opt/<app>/` (system-wide) or `~/.local/opt/<app>/` (user), then symlink the binary into `/usr/local/bin` or `~/.local/bin`.

## 4. From a GitHub repository

```bash
# latest release assets for this architecture
curl -fsSL https://api.github.com/repos/<owner>/<repo>/releases/latest \
  | grep -Eo '"browser_download_url": *"[^"]+"' | cut -d'"' -f4 | grep -Ei "linux|$(dpkg --print-architecture)|x86_64|amd64"
```

- A `.deb` asset → `apt-get install ./file.deb`. A static binary → `install -m755` into `~/.local/bin`. Verify checksums if the release publishes them.
- No release → clone into a sources directory the user chooses (ask; e.g. `~/src/<repo>`), follow its README build steps, install to `~/.local` (`--prefix ~/.local`, `pipx install .`, `cargo install --path .`).
- Record the install method and source URL so it can be updated later.

Menu entry for a GUI app (desktop):

```bash
cat > ~/.local/share/applications/<app>.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=<App Name>
Exec=<absolute path to binary> %U
Icon=<absolute path to icon or icon name>
Categories=<Utility;Development;>
Terminal=false
EOF
desktop-file-validate ~/.local/share/applications/<app>.desktop && update-desktop-database ~/.local/share/applications
```

## 5. Switch an app between snap / apt / flatpak

Example: VS Code from snap to Microsoft's apt repo.

1. Note user data locations (snap: `~/snap/<name>/`; flatpak: `~/.var/app/<id>/`; apt: normal `~/.config/…`). VS Code keeps settings in `~/.config/Code` in all three, extensions in `~/.vscode/extensions`.
2. Install the new one (vendor repo via `packages-repos`: key `https://packages.microsoft.com/keys/microsoft.asc`, URI `https://packages.microsoft.com/repos/code`, suite `stable`, component `main`).
3. Verify it launches and `command -v` resolves to it (`hash -r`).
4. Remove the old one: `sudo snap remove <name>` / `flatpak uninstall <id>` / `sudo apt-get remove <pkg>`.

## Desktop vs server

- **Desktop**: GUI apps via apt, snap or flatpak are all fine; avoid three copies of the same app.
- **Server**: install only what services need; prefer archive packages that unattended-upgrades will patch.

## Confirm before

- Adding any third-party repo, PPA or key.
- Installing with `--classic` snaps, running a vendor's `curl | sh` installer, or building/running code from an unvetted repo.
- Removing the old copy of an app when switching methods.

## Report

What was installed, by which method and why, version, how it updates, binary path, and anything that must be updated manually.

## Related

- `packages-repos` — adding vendor apt repos properly.
- `packages-snap-flatpak` — snap/flatpak housekeeping.
- `packages-cli-tools` — standard admin/dev CLIs.
