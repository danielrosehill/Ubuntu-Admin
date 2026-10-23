---
name: services-mail-relay
description: Make an Ubuntu server able to send notification mail (from unattended-upgrades, cron, smartd, mdadm, backup scripts) through an external SMTP relay, using msmtp-mta (simple, no daemon) or Postfix as a satellite with relayhost and SMTP auth; then test sending, inspect the queue and read mail logs. Use when asked "set up email alerts", "the server can't send mail", "test email from <host>", "configure a relay host", "why didn't I get the cron mail". Works on the local machine or a remote host over SSH.
---

# Services mail relay

Outbound-only mail so the system can tell someone when something breaks. Not a mail server.

## Target

Local by default. Remote: `ssh -t <host> 'sudo …'`. You need from the user: SMTP host and port (587 STARTTLS or 465 TLS), username, an app password or API key, the From address, and the recipient for alerts.

## 1. What's there now

```bash
dpkg -l | grep -E 'msmtp|postfix|exim4|ssmtp|nullmailer' | awk '{print $1,$2,$3}'
systemctl is-active postfix exim4 2>/dev/null
readlink -f /usr/sbin/sendmail
command -v mail || echo "no mail command (install bsd-mailx or mailutils)"
```

## 2a. msmtp (recommended for a single box)

```bash
sudo apt install msmtp msmtp-mta bsd-mailx
sudo tee /etc/msmtprc >/dev/null <<'EOF'
defaults
auth           on
tls            on
tls_trust_file /etc/ssl/certs/ca-certificates.crt
logfile        /var/log/msmtp.log

account        relay
host           <smtp-host>
port           587
from           <from-address>
user           <smtp-user>
passwordeval   "cat /etc/msmtp-password"

account default : relay
aliases        /etc/aliases
EOF
sudo install -m 600 /dev/null /etc/msmtp-password   # then write the secret into it
sudo chmod 644 /etc/msmtprc
echo "root: <alert-recipient>" | sudo tee -a /etc/aliases
echo "default: <alert-recipient>" | sudo tee -a /etc/aliases
sudo touch /var/log/msmtp.log && sudo chmod 666 /var/log/msmtp.log
```

The password file must be readable by whatever user sends mail; for root-only senders keep it `600 root`.

## 2b. Postfix satellite (when you want a queue and retries)

```bash
sudo DEBIAN_FRONTEND=noninteractive apt install postfix libsasl2-modules bsd-mailx
sudo postconf -e 'relayhost = [<smtp-host>]:587' \
  'smtp_sasl_auth_enable = yes' 'smtp_sasl_security_options = noanonymous' \
  'smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd' \
  'smtp_tls_security_level = encrypt' 'inet_interfaces = loopback-only' \
  'mydestination =' 
echo '[<smtp-host>]:587 <smtp-user>:<password>' | sudo tee /etc/postfix/sasl_passwd >/dev/null
sudo chmod 600 /etc/postfix/sasl_passwd && sudo postmap /etc/postfix/sasl_passwd
echo "root: <alert-recipient>" | sudo tee -a /etc/aliases && sudo newaliases
sudo postfix check && sudo systemctl restart postfix
```

If the provider requires a fixed sender, add `sender_canonical_maps` so `root@<host>` is rewritten to the authorised From address.

## 3. Test

```bash
echo "Test from $(hostname) at $(date)" | mail -s "Test from $(hostname)" <alert-recipient>
echo "root alias test" | mail -s "root alias test" root
```

## 4. Queue and logs

```bash
tail -n 30 /var/log/msmtp.log                 # msmtp
mailq; sudo postqueue -p                      # postfix queue
sudo postqueue -f                             # retry now
journalctl -u postfix@- -n 50 --no-pager      # postfix logs (unit name on 22.04+)
sudo tail -n 50 /var/log/mail.log
```

Common failures: `535 Authentication failed` (wrong app password), `Sender address rejected` (From not authorised), connection timeouts (outbound 25/587 blocked by the hosting provider — use 587 or 465).

## 5. Wire up the senders

- unattended-upgrades: `Unattended-Upgrade::Mail "<alert-recipient>";` and `Unattended-Upgrade::MailReport "on-change";` in `/etc/apt/apt.conf.d/50unattended-upgrades`.
- smartd: `DEVICESCAN -m <alert-recipient>` in `/etc/smartd.conf`.
- mdadm: `MAILADDR <alert-recipient>` in `/etc/mdadm/mdadm.conf`.
- cron: `MAILTO=<alert-recipient>` at the top of the crontab.

## Confirm before

Installing Postfix (it replaces any existing MTA), editing `/etc/aliases`, writing credential files, and sending test mail to an address the user didn't give.

## Report

Which MTA was configured, the relay host and port, test result (delivered / error line from the log), and which senders now point at the alert address.

## Related

- `packages-updates` — unattended-upgrades mail reports.
- `storage-drive-health` — smartd alerts.
- `services-logs` — mail log review.
