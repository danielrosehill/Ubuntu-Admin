---
name: hardware-profile
description: Build a hardware profile of an Ubuntu machine that both people and agents can read — system identity, CPU, memory modules, storage, GPU, network, USB/PCI, firmware and sensors — saved as Markdown, with optional per-component deep dives, an optional hw-probe run, and a "will device X work with this machine" compatibility check. Use when asked "what hardware is in this box", "profile this machine", "hardware inventory", "how much RAM / which slots are free", "what CPU does the server have", "is this part compatible", or "run hw-probe". Works on the local machine or a remote host over SSH.
---

# Hardware profile

Read-only. Benchmarks are out of scope (see the `linux-system-optimisation` plugin).

## Target

Local by default. Remote: `ssh -t <host> 'sudo <cmd>'` (dmidecode needs root), or pipe a block with `ssh <host> 'bash -s'`.

## 1. Tools

```bash
sudo apt install -y dmidecode lshw pciutils usbutils lm-sensors inxi   # all small; most are preinstalled
```

## 2. Core profile

```bash
hostnamectl                                            # model, firmware date, virtualization
sudo dmidecode -t system -t baseboard -t bios | grep -E 'Manufacturer|Product Name|Version|Release Date|Serial'
lscpu | grep -E 'Model name|Socket|Core|Thread|MHz|L[23] cache|Virtualization|NUMA node\('
grep -o -wE 'avx2|avx512f|aes|sha_ni' /proc/cpuinfo | sort -u | tr '\n' ' '; echo
grep -m1 microcode /proc/cpuinfo
free -h
sudo dmidecode -t memory | grep -E 'Maximum Capacity|Number Of Devices|^\s+(Size|Type|Speed|Configured Memory Speed|Locator|Manufacturer|Part Number):' 
lsblk -d -o NAME,SIZE,ROTA,TRAN,MODEL
lspci -nnk | grep -A3 -E 'VGA|3D|Display'
ip -br link; for i in $(ls /sys/class/net | grep -v lo); do echo "$i: $(cat /sys/class/net/$i/speed 2>/dev/null)Mb/s $(ethtool -i $i 2>/dev/null | awk '/driver/{print $2}')"; done
lsusb
sensors 2>/dev/null | head -30
inxi -Fxz 2>/dev/null          # one-shot summary; -z masks serials and MACs
```

**Serials, MAC addresses and UUIDs are redacted by default** in anything written to disk. Include them only if the user asks (e.g. for an asset register).

## 3. Deep dives (on request)

| Component | Commands |
| --- | --- |
| CPU | `lscpu -e`, `cpupower frequency-info`, `cat /sys/devices/system/cpu/vulnerabilities/*`, `lscpu --caches` |
| RAM | `sudo dmidecode -t 17` (every slot incl. empty), `sudo lshw -class memory`, ECC: `sudo dmidecode -t 16 \| grep 'Error Correction'` |
| Motherboard / firmware | `sudo dmidecode -t 2 -t 0`, `fwupdmgr get-devices`, `[ -d /sys/firmware/efi ] && echo UEFI \|\| echo BIOS`, `mokutil --sb-state` |
| GPU | see `hardware-gpu` |
| Storage | `sudo smartctl -i /dev/<d>`, `sudo nvme list`, see `storage-drive-health` |
| PCIe lanes | `sudo lspci -vv -s <slot> \| grep -E 'LnkCap|LnkSta'` (negotiated vs capable link) |

## 4. hw-probe (optional)

```bash
sudo apt install -y hw-probe
sudo -E hw-probe -all -save ./hw-probe-$(date +%Y%m%d)
```

`-upload` sends the full probe (including identifiers) to linux-hardware.org and returns a public URL. Only use it if the user explicitly wants a shareable report; say that it leaves the machine before running it.

## 5. Save the profile

Default location: `${CLAUDE_USER_DATA:-$HOME/.claude-user-data}/host-profiles/<hostname>.md` (short `hostname`, lowercased), or a path the user names. One file per host, **overwritten in place** on re-profile; if the directory is a git repository, commit and push, and history keeps the old versions. Never write profiles into this plugin's repo.

Sections: Identity, CPU, Memory (slots used/free, max supported), Storage, GPU, Network, Peripherals, Firmware, Sensors, Notes. Put a fenced JSON block at the top with the key facts for agents: `hostname`, `profiled` (YYYY-MM-DD), `kernel`, `os`, `cpu_model`, `cores`, `threads`, `ram_total_gb`, `ram_slots_free`, `gpu`, `disks[]`, `nics[]`. `performance-audit` reads that block to skip re-profiling, so keep the field names. Use Notes for facts an audit should know (role, what runs there, VMs with pinned RAM, swap on slow media).

## 6. Compatibility check

When asked whether a product works with this machine (RAM stick, GPU, NVMe, dock, Wi-Fi card):

1. Build or read the profile.
2. Check the physical/electrical constraints: RAM type and max per slot, free slots; M.2 key and PCIe generation; PSU headroom and slot for GPUs (ask if unknown); USB-C/Thunderbolt version for docks.
3. Check Linux support: in-kernel driver for the chipset (search the vendor ID with `lspci -nn`/`lsusb` style IDs), proprietary driver availability via `ubuntu-drivers`, firmware in `linux-firmware`.
4. Answer yes / yes-with-caveats / no, with the reason.

## Desktop vs server

- **Desktop / laptop**: battery health `upower -i $(upower -e | grep BAT)`, display panel, webcam, fingerprint reader presence.
- **Server / VM**: `systemd-detect-virt`; inside a VM the "hardware" is virtual — profile the host instead for physical facts.

## Confirm before

- Installing packages (`hw-probe`, `inxi`).
- Any `hw-probe -upload`.

## Report

The saved file path, plus a 5–10 line summary (model, CPU, RAM used/free slots, storage, GPU, NICs) and any notable limits (e.g. "max 32 GB RAM, both slots full").

## Related

- `hardware-gpu`, `hardware-usb-input`, `storage-drive-health` — component detail.
- `system-status` — runtime health rather than inventory.
- `performance-audit` — reads this profile on every audit.
- `linux-system-optimisation` plugin — benchmarks.
