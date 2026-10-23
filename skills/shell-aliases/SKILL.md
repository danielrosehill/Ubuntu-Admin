---
name: shell-aliases
description: Manage bash aliases in ~/.bash_aliases on Ubuntu — list and search, add or edit with a conflict check, delete, prune duplicates and broken entries, suggest useful aliases, generate a Markdown reference, and take timestamped backups before every change. Use when asked "add an alias for X", "what aliases do I have", "show my git aliases", "remove alias Y", "clean up my aliases", "suggest some aliases", "document my aliases", "back up my aliases". Works on the local machine or a remote host over SSH.
---

# Bash aliases

Ubuntu's default `~/.bashrc` sources `~/.bash_aliases` if it exists, so aliases belong there, not in `.bashrc`.

## Target

Local by default. Remote: `ssh <host> '<cmd>'` — aliases are per-user, so target the right account (`ssh <user>@<host>`). To test remotely in an interactive shell: `ssh -t <host> 'bash -ic "type <alias>"'`.

## 1. Preconditions

```bash
grep -n 'bash_aliases' ~/.bashrc          # Ubuntu default: if [ -f ~/.bash_aliases ]; then . ~/.bash_aliases; fi
[ -f ~/.bash_aliases ] || touch ~/.bash_aliases
```

If `.bashrc` doesn't source it (custom or non-Ubuntu dotfiles), say so before adding anything.

## 2. List and search

```bash
grep -nE '^\s*alias ' ~/.bash_aliases
grep -nE '^\s*#' ~/.bash_aliases                  # section headers, used for grouping
grep -nE "^\s*alias [^=]*(<term>)|=.*<term>" ~/.bash_aliases   # search by name or expansion
grep -cE '^\s*alias ' ~/.bash_aliases             # count
```

Group by the file's own comment headers; if there are none, group by inferred category (git, navigation, docker, system…). Show name, expansion and inline comment.

## 3. Backup (before every change)

```bash
mkdir -p ~/.bash_aliases_backups
cp ~/.bash_aliases ~/.bash_aliases_backups/bash_aliases_$(date +%Y%m%d_%H%M%S).bak
ls -1t ~/.bash_aliases_backups | tail -n +11       # older than the newest 10 — offer to prune
```

## 4. Add or edit

1. Pick a name, then check it doesn't shadow anything:

   ```bash
   bash -ic 'type <name>' 2>&1      # existing alias, function, builtin or command?
   command -v <name>; compgen -c | grep -x <name>
   ```

   Avoid shadowing real commands (`ls`/`grep` colour aliases being the deliberate exception).
2. Follow the file's existing style and section; add a short comment.
3. Quote correctly: single quotes so variables expand at run time — `alias gs='git status -sb'`. Anything needing arguments in the middle should be a function, not an alias.
4. Validate and load:

   ```bash
   bash -n ~/.bash_aliases && source ~/.bash_aliases && type <name>
   ```

## 5. Delete and prune

```bash
# duplicates (same name defined twice — last one wins)
grep -oE '^\s*alias [^=]+' ~/.bash_aliases | awk '{print $2}' | sort | uniq -d
# aliases whose first word is not an installed command
grep -E '^\s*alias ' ~/.bash_aliases | sed -E "s/^\s*alias ([^=]+)=['\"]?([^ '\";|&]+).*/\1 \2/" \
  | while read a c; do command -v "$c" >/dev/null || echo "$a -> missing: $c"; done
```

Remove with an exact-line edit (not a broad `sed`), then `bash -n` and re-source. Running shells keep removed aliases until `unalias <name>` or a new shell.

## 6. Ideate

Base suggestions on what the user actually runs — `history | awk '{$1=""; print}' | sort | uniq -c | sort -rn | head -30` — and on installed tools (git, docker, systemctl, apt). Offer a handful, one per line with what it does; add only the ones accepted.

## 7. Document

Write a Markdown reference (default `~/bash-aliases.md`, or where the user asks): generation date, one table per section with alias, expansion, plain-English description. Add a table of contents above ten aliases.

## Desktop vs server

- **Desktop**: aliases often sync across machines via a dotfiles manager — after changes, remind the user to commit/push (see `shell-config`); don't push automatically.
- **Server**: keep aliases out of `root`'s shell and service accounts unless asked; scripts and systemd units never see aliases.

## Confirm before

- Overwriting or deleting an existing alias.
- Pruning entries or old backups.
- Adding an alias that shadows an existing command.

## Report

What changed (added/edited/removed, with the final definitions), backup path, validation result, and total alias count.

## Related

- `shell-config` — `.bashrc`, PATH and dotfiles management.
- `dev-environment` — git aliases belong in `git config alias.*` when they are git subcommands.
