---
name: desktop-fonts
description: List, install and manage fonts on Ubuntu — count and search installed families, install from apt (fonts-* packages, Microsoft core fonts), from Google Fonts by name, or from local font files, per-user or system-wide, refresh the cache, and fix basic rendering. Use when asked "what fonts do I have", "install the Inter / Roboto / <name> font", "install Google Fonts", "add Microsoft fonts", "font not showing up in apps", or "fonts look blurry". Works locally or on a remote host over SSH (for system-wide installs).
---

# Fonts

## Target

Local by default. Per-user installs affect only the current user; system installs need root (`ssh -t <host> 'sudo …'` remotely).

## 1. What is installed

```bash
fc-list : family | sort -u | wc -l                 # number of families
fc-list : family | sort -u | less
fc-list | grep -i '<name>'                         # is a font present, and where
fc-match sans-serif; fc-match serif; fc-match monospace   # current defaults
dpkg -l 'fonts-*' | awk '/^ii/{print $2}'          # fonts from apt
ls ~/.local/share/fonts /usr/local/share/fonts 2>/dev/null
```

## 2. Install from apt (preferred when packaged)

```bash
apt search '^fonts-' 2>/dev/null | grep -i '<name>'
sudo apt install -y fonts-noto fonts-noto-color-emoji fonts-jetbrains-mono fonts-firacode fonts-inter
sudo apt install -y ttf-mscorefonts-installer   # Arial, Times New Roman…; shows a EULA prompt
```

`ttf-mscorefonts-installer` asks the user to accept Microsoft's EULA — the user must accept it themselves (non-interactive acceptance needs `echo ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true | sudo debconf-set-selections`, only with their consent).

## 3. Install Google Fonts by name

Google Fonts are published at `github.com/google/fonts` under `ofl/<lowercase-name-no-spaces>/` (a few under `apache/` or `ufl/`).

```bash
NAME="Space Grotesk"; DIR=$(echo "$NAME" | tr -d ' ' | tr '[:upper:]' '[:lower:]')
mkdir -p ~/.local/share/fonts/google/"$DIR"
for lic in ofl apache ufl; do
  curl -fsSL "https://api.github.com/repos/google/fonts/contents/$lic/$DIR" 2>/dev/null \
   | grep -o '"download_url": *"[^"]*\.ttf"' | cut -d'"' -f4 \
   | while read -r u; do curl -fsSL -o ~/.local/share/fonts/google/"$DIR"/"$(basename "$u")" "$u"; done
done
fc-cache -f && fc-list | grep -i "$NAME"
```

Variable fonts arrive as e.g. `SpaceGrotesk[wght].ttf` — that single file covers all weights. Unauthenticated GitHub API calls are rate-limited (60/hour); for many fonts, clone `google/fonts` sparsely instead.

## 4. Install local font files

```bash
mkdir -p ~/.local/share/fonts && cp <files>.{ttf,otf} ~/.local/share/fonts/   # per user
sudo mkdir -p /usr/local/share/fonts && sudo cp <files> /usr/local/share/fonts/ # system-wide
fc-cache -f
```

## 5. Rendering basics

- GNOME: `gsettings set org.gnome.desktop.interface font-antialiasing 'rgba'` and `font-hinting 'slight'`; check with `gsettings get …`.
- Per-user fontconfig overrides live in `~/.config/fontconfig/fonts.conf`.
- Snap and Flatpak apps see host fonts in `/usr/share/fonts` and `~/.local/share/fonts`; if one doesn't, restart it — Flatpak also needs `flatpak --user override --filesystem=~/.local/share/fonts:ro` in rare cases.

## Desktop vs server

- **Desktop**: per-user installs are the default choice.
- **Server**: only matters for document rendering (LibreOffice headless, PDF generation, Typst) — install system-wide so service users see them.

## Confirm before

- System-wide installs and accepting any EULA.
- Removing font packages (other packages may depend on them).

## Report

Fonts installed (name, source, location), verification from `fc-list`, and anything not found.

## Related

- `packages-install` — choosing install methods generally.
- `desktop-codecs` — the other "restricted extras".
