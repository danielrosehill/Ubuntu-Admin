---
name: packages-cli-tools
description: Install and verify common admin and developer CLIs on Ubuntu by the preferred method for each — GitHub CLI (gh) from its official apt repo, AWS CLI v2, rclone, Backblaze b2, pipx, uv, yadm, SDKMAN and Homebrew on Linux (and when not to use it) — and produce a verification table showing installed, version and configured/authenticated status. Use when asked "install gh", "set up aws cli", "is rclone configured", "verify my backup CLIs", "install pipx / uv", "should I use brew on Ubuntu", "check which CLIs are set up". Works on the local machine or a remote host over SSH.
---

# Common CLI tools

Install each tool the way that keeps it updated with the least friction, then verify it actually works.

## Target

Local by default. Remote: `ssh <host> '<cmd>'`; root: `ssh -t <host> 'sudo <cmd>'`. Auth flows (`gh auth login`, `aws configure`, `rclone config`) are interactive — use `ssh -t`.

## 1. Verification table

```bash
for t in gh aws rclone b2 pipx uv yadm brew sdk git curl jq; do
  p=$(command -v "$t" 2>/dev/null) || { printf '%-8s missing\n' "$t"; continue; }
  v=$("$t" --version 2>/dev/null | head -1)
  printf '%-8s %-30s %s\n' "$t" "$p" "$v"
done
[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ] && echo "sdkman   installed (shell function)"
```

Then check configuration (no secrets printed):

```bash
gh auth status 2>&1 | head -5
aws configure list 2>/dev/null; aws sts get-caller-identity --query Arn --output text 2>/dev/null
rclone listremotes
b2 account get 2>/dev/null | head -3      # older b2 versions: b2 get-account-info
```

## 2. Install, per tool

**gh** — official apt repo (updates with the system):

```bash
sudo install -d -m 0755 /etc/apt/keyrings
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
sudo apt-get update && sudo apt-get install gh
gh auth login            # then: gh auth setup-git
```

**AWS CLI v2** — not in the archive (the `awscli` deb is v1); use the official bundle or the snap:

```bash
sudo snap install aws-cli --classic
# or: curl -fsSLo /tmp/awscliv2.zip "https://awscli.amazonaws.com/awscli-exe-linux-$(uname -m).zip" && unzip -q /tmp/awscliv2.zip -d /tmp && sudo /tmp/aws/install --update
aws configure            # or: aws configure --profile <name>; S3-compatible providers need --endpoint-url per call or in ~/.aws/config
```

**rclone** — archive version lags; the upstream .deb is current:

```bash
sudo apt-get install rclone                      # simple, older
# or: curl -fsSL https://rclone.org/install.sh | sudo bash   (confirm first — runs a remote script)
rclone config                                    # add remotes; config at ~/.config/rclone/rclone.conf
```

**b2** — `pipx install b2` (then `b2 account authorize`).

**pipx** and **uv**:

```bash
sudo apt-get install pipx && pipx ensurepath     # adds ~/.local/bin to PATH
pipx install uv                                  # or: curl -LsSf https://astral.sh/uv/install.sh | sh
```

**yadm** — `sudo apt-get install yadm` (see `shell-config` for use).

**SDKMAN** (JVM tools):

```bash
sudo apt-get install zip unzip curl
curl -s "https://get.sdkman.io" | bash && source "$HOME/.sdkman/bin/sdkman-init.sh" && sdk version
```

**Homebrew on Linux** — only when a tool exists nowhere else, on a single-user desktop. It installs to `/home/linuxbrew/.linuxbrew`, puts its own libraries ahead of system ones on PATH (which can shadow apt tools), and is unsupported as root. Prefer apt, snap, pipx/uv or a release binary first.

```bash
sudo apt-get install build-essential procps curl file git
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
# add the shellenv line it prints to ~/.bashrc
```

## 3. Smoke tests

```bash
gh api user --jq .login
ssh -T git@github.com 2>&1 | head -1
rclone lsd <remote>: --max-depth 1
aws s3 ls --profile <name> [--endpoint-url <url>]
```

## Desktop vs server

- **Desktop**: per-user installs (pipx, uv, SDKMAN, brew) are fine.
- **Server**: prefer system packages; service accounts that run backups need the tool and its config under *their* home (`sudo -u <svc> rclone listremotes`).

## Confirm before

- Adding a vendor apt repo/key, or running any `curl … | sh` installer.
- Installing Homebrew.
- Interactive credential setup — never echo or log secret values.

## Report

The verification table (tool, path, version, configured/authenticated yes/no), what was installed and by which method, and any tool that needs manual updates.

## Related

- `packages-install` — general install-method choice.
- `packages-repos` — vendor repo hygiene.
- `dev-environment` — language runtimes and git configuration.
- `storage-backup` — using rclone/aws/b2 for backups.
