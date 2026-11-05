---
name: new-workspace
description: Provision a new desktop-manager workspace on disk. Use when the user wants a persistent scaffold for managing their local Linux desktop (tracking installs, config changes, hardware issues, log reviews). Accepts a workspace name and optional target parent path. Scaffolds the workspace, personalises CLAUDE.md from the user's global memory, and (by default) creates a public GitHub repo.
disable-model-invocation: true
allowed-tools: Bash(mkdir *), Bash(cp *), Bash(cat *), Bash(git init *), Bash(git add *), Bash(git commit *), Bash(gh repo create *), Bash(gh auth status), Bash(git push *), Read
---

# Provision Desktop-Manager Workspace

Creates a new workspace for managing the local Linux desktop. This plugin's commands (`/desktop-manager:check-system`, `/desktop-manager:install-package`, `/desktop-manager:troubleshoot-hardware`, etc.) are globally available once installed — this skill only provisions the **data scaffold** (CLAUDE.md, context/, outputs/, logs/) that those commands read from and write to.

## Arguments

`$ARGUMENTS` is parsed as:

- **First positional**: workspace name (kebab-case, used as directory and GitHub repo name). Required.
- **Second positional** (optional): target parent path. Defaults to `~/repos/github/my-repos`.
- **`--local-only`** (optional): skip GitHub repo creation and push. Default: create a public GitHub repo and push.
- **`--private`** (optional): create the GitHub repo as private. Default: public.

### Examples

```
/desktop-manager:new-workspace my-desktop
/desktop-manager:new-workspace workstation-ops --private
/desktop-manager:new-workspace laptop-manager --local-only
```

## Procedure

### 1. Parse arguments

Extract workspace name, target parent path, and flags from `$ARGUMENTS`. If workspace name is missing, ask the user for it before proceeding.

### 2. Resolve the scaffold path

The bundled scaffold lives at `${CLAUDE_SKILL_DIR}/../../template/`. Confirm it exists.

### 3. Read ambient facts

Read `~/.claude/CLAUDE.md` if it exists. Extract OS, distribution, desktop environment, locale, timezone, and user identity facts. These will personalise the workspace's CLAUDE.md at step 6.

### 4. Create the workspace directory

```bash
mkdir -p <target-parent>/<workspace-name>
cp -r ${CLAUDE_SKILL_DIR}/../../template/. <target-parent>/<workspace-name>/
```

Do **not** copy any `.claude/` tree. The plugin's primitives are global.

### 5. Personalise CLAUDE.md

Open the new workspace's `CLAUDE.md` and:

- Replace placeholder identity with the facts from step 3 (OS, distribution, DE, locale, timezone, user name if available).
- Add a short header noting the workspace name.
- If ambient facts include the native package manager, embed it so downstream commands can skip re-detecting.

### 6. Prompt for workspace-specific facts

Ask the user only for facts this plugin can't infer from global memory:

- **Desktop environment** (GNOME, KDE, XFCE, etc.) — if not already in ambient facts.
- **Display server** (X11 / Wayland) — if not already in ambient facts.
- **Dual-boot setup?** — whether the machine also boots another OS (affects bootloader/partition caution level).
- **Primary package manager** — confirm the detected one (apt / dnf / pacman / zypper) and note any supplementary sources in regular use (flatpak, snap, AUR helper, homebrew-linux).
- **Hostname / role** — short label for the machine (e.g. "main workstation", "travel laptop").

Write these into `CLAUDE.md` under a `## Machine Profile` section.

### 7. Initialise git and (optionally) publish

```bash
cd <target-parent>/<workspace-name>
git init
git add .
git commit -m "Initial workspace from desktop-manager plugin"
```

Unless `--local-only` is set:

```bash
gh repo create <workspace-name> --<public|private> --source=. --push
```

Use `--public` by default, `--private` if flag was passed.

### 8. Print next steps

Tell the user:

- Workspace path.
- Which plugin commands apply next — typically start with `/desktop-manager:check-system` to baseline the machine.
- Where logs/outputs land (`logs/`, `outputs/`).
- Reminder that the workspace is **data** — they can delete/move it freely without losing the plugin's commands.

## Notes

- The scaffold path must be resolved via `${CLAUDE_SKILL_DIR}/../../template/` (not `${CLAUDE_PLUGIN_ROOT}` — that variable isn't exported in skill bash injection, only in hooks/MCP).
- Never copy `.claude/commands/`, `.claude/agents/`, or `.claude/skills/` into the new workspace. If the user wants workspace-local overrides, they can add them manually later.
- Don't hard-code any personal paths, hostnames, or identifiers — everything comes from user memory or prompts.
- This plugin is for the **local desktop only**. If the user asks about remote servers or homelab nodes, redirect them to the `sysadmin-homelab` plugin.
