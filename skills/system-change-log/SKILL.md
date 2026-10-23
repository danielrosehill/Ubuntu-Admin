---
name: system-change-log
description: Write a short, structured, dated record of an admin change or fix on an Ubuntu machine — problem, root cause, fix, how to reverse it — into a log directory, optionally committing it to git. It also writes longer host documentation (configuration, runbooks, filesystem layout) when asked. Use right after a non-trivial change, or when the user says "log this", "write this up", "document this fix", "add to the ops log", or "document this server".
---

# System change log

The fix is half the work; the record of what was wrong and why the fix worked is the other half. Write it while the details are fresh.

## When

- After a non-trivial change: a package added or removed for a reason, a config edited, a service fixed, a hardware or driver workaround.
- When the user asks for it.
- Proactively, after you have walked through a fix. Ask once whether they want it logged.

Do not log read-only checks.

## Where

Resolve the log directory in this order:

1. `$UBUNTU_ADMIN_LOG_DIR` if set.
2. `outputs/` in the current admin workspace, if the current directory is one (see `host-workspace`).
3. `~/admin-log/` (create it).

Inside it, use `<host>/YYYY-MM-DD-<short-slug>.md`. Get the date from `date +%F`. Do not guess it.

## Entry format

```markdown
# <Short title>

- **Date:** YYYY-MM-DD
- **Host:** <hostname or alias> — <Ubuntu version, desktop/server>
- **Area:** packages | services | network | storage | hardware | docker | desktop | other

## Problem
What was observed. Concrete symptoms and error text, not speculation.

## Root cause
What was actually wrong. If unconfirmed, say "suspected: …, not confirmed".

## Fix
The exact commands or file changes, in fenced code blocks.

## What did not work
Approaches tried and why they failed. Include these: they save the next person the same detour.

## Reverse
How to undo it (backup path, package to reinstall, setting to restore).

## Follow-up
Anything left to watch or do.
```

Keep it under about 60 lines, and link to upstream docs rather than restating them. Get the host facts from `/etc/os-release` and `hostnamectl`. Include the kernel version only for kernel or driver fixes.

## Longer documentation

When asked to "document this server" or write a runbook, write into `docs/` in the workspace instead. Use one file per subject (`services.md`, `storage.md`, `network.md`, `runbook-<task>.md`). Update an existing file rather than starting a parallel one. `system-status` and `hardware-profile` output make good raw material.

## Git

```bash
cd "$LOG_DIR"
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git add "<file>" && git commit -m "log: <short title>"
  git rev-parse --abbrev-ref --symbolic-full-name @{u} >/dev/null 2>&1 && git push
fi
```

Never `git init` a directory without asking.

## Never write

- Secret values (passwords, tokens, private keys, Wi-Fi PSKs). Describe them instead, as in "rotated the API token for X".
- Serial numbers, MAC addresses or public IPs, if the log repository is or may become public.
- An invented root cause.

## Report

The path of the entry, and whether it was committed and pushed.

## Related

`system-config-edit` (backups to reference in "Reverse"), `host-workspace`.
