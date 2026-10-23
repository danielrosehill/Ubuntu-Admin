---
name: network-ssh-hosts
description: Manage SSH host aliases and remote-admin access from an Ubuntu machine — list and add ~/.ssh/config entries, test reachability and non-interactive key auth (BatchMode), copy a public key to hosts with ssh-copy-id so the rest of these skills can run remotely, enable ControlMaster multiplexing for many-command sessions, and run sudo over SSH. Use when asked "list my SSH hosts", "add an SSH alias for <host>", "set up passwordless SSH to these machines", "can I reach <host> over SSH", "ssh is slow for repeated commands", "run sudo remotely". Key generation, rotation and auditing are in ubuntu-security.
---

# Network SSH hosts

Every remote mode in this plugin is `ssh <host> '<cmd>'`. This skill makes `<host>` work.

## Target

Runs on the admin machine (the one you're typing on). Touches `~/.ssh/config` locally and `~/.ssh/authorized_keys` on targets.

## 1. List configured hosts

```bash
ls -la ~/.ssh/
grep -iE '^\s*(Host|HostName|User|Port|IdentityFile|ProxyJump)\b' ~/.ssh/config ~/.ssh/config.d/* 2>/dev/null
ssh -G <alias> | grep -E '^(hostname|user|port|identityfile|proxyjump) '   # effective settings for one alias
```

Present as a table: alias, hostname, user, port, key, jump host.

## 2. Test reachability and auth

```bash
for h in <alias1> <alias2>; do
  if ssh -o BatchMode=yes -o ConnectTimeout=5 "$h" true 2>/dev/null; then echo "OK    $h"
  else echo "FAIL  $h: $(ssh -o BatchMode=yes -o ConnectTimeout=5 "$h" true 2>&1 | tail -1)"; fi
done
```

`Permission denied (publickey…)` → key not installed; `Connection timed out` → network/firewall; `Host key verification failed` → host was reinstalled or IP reused — verify with the user before `ssh-keygen -R <host>`.

## 3. Add an alias

```sshconfig
# ~/.ssh/config
Host <alias>
    HostName <hostname-or-ip>
    User <user>
    # Port 22
    # IdentityFile ~/.ssh/id_ed25519
    # ProxyJump <bastion-alias>
```

Prefer hostnames that resolve on the LAN over raw IPs. Keep `~/.ssh/config` mode 600. With many hosts, use `Include ~/.ssh/config.d/*` at the top and one file per group.

## 4. Passwordless access with an existing key

```bash
ls ~/.ssh/*.pub                                     # need one; if none, see ubuntu-security for key creation
ssh-copy-id -i ~/.ssh/id_ed25519.pub <alias>         # asks for the account password once
ssh -o BatchMode=yes <alias> 'echo ok; hostname; . /etc/os-release; echo $PRETTY_NAME'
```

For several hosts, do them one at a time — the user types each password. Fresh Ubuntu Server: `sudo apt install openssh-server` on the target first if SSH isn't running.

## 5. Multiplexing (many commands, one handshake)

```sshconfig
Host *
    ControlMaster auto
    ControlPath ~/.ssh/cm-%C
    ControlPersist 10m
    ServerAliveInterval 30
```

Subsequent `ssh <alias> …` calls reuse the connection — much faster for skill sweeps. `ssh -O exit <alias>` closes it.

## 6. sudo over SSH

```bash
ssh -t <alias> 'sudo apt update'                  # -t gives sudo a terminal for the password prompt
ssh <alias> 'sudo -n true' && echo "passwordless sudo available"
ssh <alias> 'sudo bash -s' < local-script.sh      # needs passwordless sudo (no tty)
```

Don't set up `NOPASSWD` sudo unless the user asks; it's a security decision (see `ubuntu-security`).

## Confirm before

- Writing to `~/.ssh/config` (show the stanza first).
- Installing a key on any host (`ssh-copy-id`).
- Removing a known_hosts entry after a host-key mismatch — the user must confirm the host was legitimately reinstalled.

## Report

Table of aliases with OK/FAIL and the reason, any aliases added, hosts that now accept key auth.

## Related

- `host-workspace` — record a host's profile once it's reachable.
- `network-diagnose` — when the host isn't reachable at all.
- `ubuntu-security` plugin — key generation, rotation, sshd hardening, authorized_keys audit.
