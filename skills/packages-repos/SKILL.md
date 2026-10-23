---
name: packages-repos
description: Audit and manage APT software sources on Ubuntu — list every repository (classic .list and deb822 .sources), identify PPAs and third-party vendor repos, find failing, duplicate or unsigned sources, migrate legacy apt-key keys to /etc/apt/keyrings with signed-by, add a vendor repo correctly, remove or downgrade away from a PPA, and spot packages from third-party origins that the official archive now provides. Use when asked "what repos do I have", "remove this PPA", "apt-key is deprecated", "add the vendor apt repo", "clean up third-party repositories", "is this package from a PPA". Works on the local machine or a remote host over SSH.
---

# APT repositories

Keep the set of package sources small, signed, and intentional.

## Target

Local by default. Remote: `ssh <host> '<cmd>'`; root steps: `ssh -t <host> 'sudo <cmd>'`.

## 1. Inventory

Ubuntu 24.04+ keeps the official archive in deb822 format at `/etc/apt/sources.list.d/ubuntu.sources`; older releases and many vendors still use one-line `.list` files. Read both:

```bash
ls -l /etc/apt/sources.list /etc/apt/sources.list.d/
grep -hv '^\s*#' /etc/apt/sources.list /etc/apt/sources.list.d/*.list 2>/dev/null | grep -E '^deb'
for f in /etc/apt/sources.list.d/*.sources; do echo "== $f"; grep -E '^(Types|URIs|Suites|Components|Signed-By|Enabled):' "$f"; done
apt-cache policy | grep -E '^ *[0-9]+ http' | sort -u      # effective sources and priorities
```

Classify each: **official** (`archive.ubuntu.com`, `security.ubuntu.com`, `*.ports.ubuntu.com`, `esm.ubuntu.com`), **PPA** (`ppa.launchpadcontent.net`), **vendor** (Docker, Google, Microsoft, NodeSource …), **unknown**.

## 2. Problems to flag

```bash
sudo apt-get update 2>&1 | grep -Ei 'err|fail|404|NO_PUBKEY|EXPKEYSIG|not signed|Release file|configured multiple times'
grep -rn 'trusted=yes' /etc/apt/sources.list* 2>/dev/null                # unsigned on purpose — risky
grep -rLE 'signed-by|Signed-By' /etc/apt/sources.list.d/ 2>/dev/null      # third-party without a scoped key
ls /etc/apt/trusted.gpg /etc/apt/trusted.gpg.d/ 2>/dev/null               # legacy global keyrings
```

- **404 / no Release file**: PPA not built for this Ubuntu release (common after an upgrade) or abandoned.
- **Configured multiple times**: same repo in `.list` and `.sources`, or two vendor files.
- **Global keys** in `trusted.gpg(.d)`: any key there can sign any repo. Migrate to scoped keys.

## 3. Add a vendor repo the modern way

```bash
sudo install -d -m 0755 /etc/apt/keyrings
curl -fsSL https://<vendor>/key.gpg | sudo gpg --dearmor -o /etc/apt/keyrings/<vendor>.gpg
sudo tee /etc/apt/sources.list.d/<vendor>.sources >/dev/null <<EOF
Types: deb
URIs: https://<vendor-repo-url>
Suites: $(. /etc/os-release; echo "$VERSION_CODENAME")   # or the vendor's suite name, e.g. stable
Components: main
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/<vendor>.gpg
EOF
sudo apt-get update
```

If the vendor ships an ASCII-armored key, `Signed-By` can also point at a `.asc` file directly.

## 4. Migrate a legacy apt-key key

```bash
sudo apt-key list 2>/dev/null          # if apt-key still exists; otherwise:
gpg --no-default-keyring --keyring /etc/apt/trusted.gpg --list-keys 2>/dev/null
# export the one key a repo needs, by its last 8 hex chars, into a scoped keyring
sudo gpg --no-default-keyring --keyring /etc/apt/trusted.gpg --export <KEYID> | sudo tee /etc/apt/keyrings/<vendor>.gpg >/dev/null
```

Then add `signed-by=/etc/apt/keyrings/<vendor>.gpg` to that repo's `deb [...]` line (or `Signed-By:` in `.sources`), run `apt-get update`, and only then delete the key from the global ring (`gpg --keyring /etc/apt/trusted.gpg --delete-key <KEYID>`).

## 5. Remove or disable a source

```bash
sudo add-apt-repository --remove ppa:<owner>/<name>      # PPA
sudo apt-get install ppa-purge && sudo ppa-purge ppa:<owner>/<name>   # remove AND downgrade its packages to official versions
# disable without deleting: .sources → add "Enabled: no"; .list → comment the line
sudo sed -i 's/^deb /# deb /' /etc/apt/sources.list.d/<file>.list
```

Remove the matching keyring from `/etc/apt/keyrings/` once nothing references it.

## 6. Third-party packages now in the official archive

```bash
# installed packages whose installed version comes from a non-Ubuntu origin (slow: one policy call per package)
for p in $(apt list --installed 2>/dev/null | awk -F/ 'NR>1{print $1}'); do
  apt-cache policy "$p" | awk -v p="$p" '/\*\*\*/{getline; if ($0 !~ /ubuntu\.com|\/var\/lib\/dpkg/) print p": "$0}'
done
apt-cache policy <pkg>      # shows every candidate version and which repo offers it
```

For each, compare the official version; if it is adequate, `ppa-purge` or remove the repo and reinstall from the archive. Packages with no repo at all (`/var/lib/dpkg/status` only) were installed from a local `.deb` and never update — list them: `apt list '?obsolete'` (24.04+) or `aptitude search '~o'`.

## Desktop vs server

- **Desktop**: PPAs accumulate (graphics drivers, browsers, codecs). After a release upgrade, `do-release-upgrade` disables them — re-enable only those built for the new release.
- **Server**: keep third-party repos to what the services need (Docker, a database vendor). Pin them if they overlap the archive (`/etc/apt/preferences.d/`).

## Confirm before

- Adding any repository or key (it gains the ability to replace system packages).
- Removing or disabling a repo, and running `ppa-purge` (it downgrades packages).
- Deleting keys from global keyrings.

## Report

Table of sources: file, type (official/PPA/vendor/unknown), signed-by scoped?, status (ok/failing/duplicate/unsigned), recommendation. Then actions taken and the final `apt-get update` result.

## Related

- `packages-apt-health` — when apt itself is broken.
- `packages-install` — choosing between a vendor repo, snap, flatpak or a binary.
- `packages-updates` — release upgrades that disable PPAs.
