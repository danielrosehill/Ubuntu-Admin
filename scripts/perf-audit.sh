#!/usr/bin/env bash
# perf-audit.sh — read-only performance snapshot of a Linux machine, printed as one JSON object.
#
# Local:   bash perf-audit.sh
# Remote:  ssh <host> 'bash -s' < perf-audit.sh
#
# Changes nothing. Root-only reads use `sudo -n` and come back null without passwordless sudo.
# Works on Ubuntu/Debian desktops, servers and Raspberry Pi OS (adds vcgencmd fields there).
# Takes ~6 s (vmstat samples 5 s so active swapping is measured, not guessed from swap used).
# Part of the ubuntu-admin agent skills: https://github.com/danielrosehill/Ubuntu-Admin

set -u
export LC_ALL=C
have() { command -v "$1" >/dev/null 2>&1; }
SUDO=""; sudo -n true 2>/dev/null && SUDO="sudo -n"
py=python3; have $py || { echo '{"error":"python3 missing"}'; exit 1; }

# Collect raw sections into a temp dir, then let python assemble valid JSON.
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
hostname > "$T/host"
uname -r > "$T/kernel"
nproc > "$T/nproc"
cat /proc/loadavg > "$T/loadavg"
cat /proc/uptime > "$T/uptime"
for r in cpu memory io; do [ -r /proc/pressure/$r ] && sed "s/^/$r /" /proc/pressure/$r; done > "$T/psi"
cat /proc/meminfo > "$T/meminfo"
vmstat 1 6 | tail -5 > "$T/vmstat"
swapon --show=NAME,TYPE,SIZE,USED --bytes --noheadings 2>/dev/null > "$T/swap"
df -P -B1 -x tmpfs -x devtmpfs -x squashfs -x overlay -x efivarfs 2>/dev/null | tail -n +2 > "$T/df"
df -P -i -x tmpfs -x devtmpfs -x squashfs -x overlay -x efivarfs 2>/dev/null | tail -n +2 > "$T/dfi"
ps -eo pid,%cpu,%mem,rss,comm --sort=-%cpu | sed -n 2,9p > "$T/ps_cpu"
ps -eo pid,%cpu,%mem,rss,comm --sort=-rss  | sed -n 2,9p > "$T/ps_mem"
$SUDO journalctl -k --since "-7 days" --no-pager 2>/dev/null | grep -ciE 'out of memory|oom-kill|killed process' > "$T/oom" || true
journalctl -u systemd-oomd --since "-7 days" --no-pager 2>/dev/null | grep -ci 'killed' > "$T/oomd" || true
systemctl --failed --no-legend --plain 2>/dev/null | awk '{print $1}' > "$T/failed"
grep -m1 'model name' /proc/cpuinfo | cut -d: -f2- | sed 's/^ //' > "$T/cpumodel"
[ -r /proc/device-tree/model ] && tr -d '\0' < /proc/device-tree/model > "$T/dtmodel"
lsblk -d -n -o NAME,SIZE,ROTA,TRAN,MODEL 2>/dev/null | grep -vE '^(loop|zram|ram)' > "$T/disks"
if have sensors; then sensors -j 2>/dev/null > "$T/sensors"; fi
for z in /sys/class/thermal/thermal_zone*/temp; do [ -r "$z" ] && cat "$z"; done > "$T/thermal" 2>/dev/null
if have vcgencmd; then
  { vcgencmd measure_temp; vcgencmd get_throttled; vcgencmd measure_volts core; } > "$T/vcgencmd" 2>/dev/null
fi
if have docker && docker info >/dev/null 2>&1; then
  docker stats --no-stream --format '{{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}' > "$T/dstats" 2>/dev/null
  docker ps -aq | xargs -r docker inspect --format '{{.Name}}	{{.RestartCount}}	{{.State.Status}}	{{.State.OOMKilled}}	{{.HostConfig.Memory}}' > "$T/dinspect" 2>/dev/null
fi
# Is anything keeping history? (so the report can say whether "what happened at 3am" is answerable)
{ have docker && docker ps --format '{{.Names}} {{.Image}}' 2>/dev/null
  systemctl list-units --type=service --no-legend --plain 2>/dev/null | awk '{print $1}'
} | grep -ioE 'beszel[^ ]*|netdata|node[-_]exporter|prometheus|telegraf|glances|sysstat|collectd|zabbix[^ ]*' | sort -u > "$T/monitors"

$py -I - "$T" <<'PY'
import json, os, sys, re
T = sys.argv[1]
def rd(n):
    p = os.path.join(T, n)
    return open(p).read().strip() if os.path.exists(p) else ""
def lines(n): return [l for l in rd(n).splitlines() if l.strip()]
def num(s):
    try: return float(s)
    except: return None

out = {"host": rd("host"), "kernel": rd("kernel"), "cpu_model": rd("cpumodel") or None,
       "board": rd("dtmodel") or None, "cores": int(rd("nproc") or 0)}
la = rd("loadavg").split()
out["load"] = {"1m": num(la[0]), "5m": num(la[1]), "15m": num(la[2])} if la else None
out["load_per_core_5m"] = round(out["load"]["5m"] / out["cores"], 2) if la and out["cores"] else None
out["uptime_days"] = round(float(rd("uptime").split()[0]) / 86400, 1) if rd("uptime") else None

psi = {}
for l in lines("psi"):
    res, kind, *kv = l.split()
    d = dict(x.split("=") for x in kv)
    psi[f"{res}_{kind}_avg60"] = num(d.get("avg60"))
out["psi"] = psi or None

mi = {l.split(":")[0]: int(l.split()[1]) for l in lines("meminfo") if len(l.split()) >= 2}
gb = lambda kb: round(kb / 1048576, 2)
out["memory_gb"] = {"total": gb(mi.get("MemTotal", 0)), "available": gb(mi.get("MemAvailable", 0)),
                    "swap_total": gb(mi.get("SwapTotal", 0)),
                    "swap_used": gb(mi.get("SwapTotal", 0) - mi.get("SwapFree", 0))}
out["memory_available_pct"] = round(100 * mi.get("MemAvailable", 0) / mi["MemTotal"], 1) if mi.get("MemTotal") else None

# vmstat columns: r b swpd free buff cache si so bi bo in cs us sy id wa st [gu]
vm = [l.split() for l in lines("vmstat")]
if vm:
    avg = lambda i: round(sum(float(r[i]) for r in vm) / len(vm), 1)
    out["vmstat_5s"] = {"runnable": avg(0), "blocked": avg(1), "swap_in_kbps": avg(6),
                        "swap_out_kbps": avg(7), "cpu_user": avg(12), "cpu_sys": avg(13),
                        "cpu_idle": avg(14), "io_wait": avg(15)}
out["swap_devices"] = [dict(zip(["name", "type", "size", "used"], l.split())) for l in lines("swap")]

fs = []
inodes = {l.split()[5]: l.split()[4] for l in lines("dfi") if len(l.split()) >= 6}
for l in lines("df"):
    f = l.split()
    if len(f) < 6 or f[5].startswith(("/tmp/.mount_", "/snap/")): continue  # AppImage/snap mounts are always 100%
    fs.append({"mount": f[5], "size_gb": round(int(f[1]) / 1e9, 1), "used_pct": int(f[4].rstrip("%")),
               "inodes_used_pct": int(inodes.get(f[5], "0%").rstrip("%-") or 0)})
out["filesystems"] = fs
out["disks"] = lines("disks")

ps = lambda n: [dict(zip(["pid", "cpu_pct", "mem_pct", "rss_kb", "comm"], l.split(None, 4))) for l in lines(n)]
out["top_cpu"], out["top_mem"] = ps("ps_cpu"), ps("ps_mem")
out["oom_kills_7d"] = {"kernel": int(rd("oom") or 0) if rd("oom") else None, "systemd_oomd": int(rd("oomd") or 0)}
out["failed_units"] = lines("failed")

temps = [int(x) / 1000 for x in lines("thermal") if x.lstrip("-").isdigit()]
try:  # lm-sensors, when installed, sees more chips (k10temp/coretemp/nvme) than thermal_zone
    def walk(o):
        for k, v in o.items():
            if isinstance(v, dict): yield from walk(v)
            elif k.startswith("temp") and k.endswith("_input") and 0 < v < 150: yield v
    temps += list(walk(json.loads(rd("sensors")))) if rd("sensors") else []
except Exception: pass
out["max_temp_c"] = max(temps) if temps else None
vc = rd("vcgencmd")
if vc:
    t = re.search(r"temp=([\d.]+)", vc); th = re.search(r"throttled=(0x[0-9a-fA-F]+)", vc)
    bits = int(th.group(1), 16) if th else 0
    out["pi"] = {"temp_c": num(t.group(1)) if t else None, "throttled_raw": th.group(1) if th else None,
                 "undervoltage_now": bool(bits & 0x1), "throttled_now": bool(bits & 0x4),
                 "undervoltage_since_boot": bool(bits & 0x10000), "throttled_since_boot": bool(bits & 0x40000),
                 "soft_temp_limit_since_boot": bool(bits & 0x80000)}

if rd("dinspect"):
    stats = {l.split("\t")[0]: l.split("\t") for l in lines("dstats")}
    cs = []
    for l in lines("dinspect"):
        name, restarts, status, oom, limit = l.split("\t")
        name = name.lstrip("/")
        s = stats.get(name)
        mem_pct = num(s[3].rstrip("%")) if s else None
        cs.append({"name": name, "status": status, "restarts": int(restarts), "oom_killed": oom == "true",
                   "mem_limit_set": limit != "0", "cpu_pct": num(s[1].rstrip("%")) if s else None,
                   "mem": s[2] if s else None, "mem_pct_of_limit": mem_pct if limit != "0" else None})
    cs.sort(key=lambda c: -(c["cpu_pct"] or 0))
    out["containers"] = {"total": len(cs), "running": sum(c["status"] == "running" for c in cs),
                         "near_mem_limit": [c["name"] for c in cs if (c["mem_pct_of_limit"] or 0) >= 85],
                         "restart_loops": [c["name"] for c in cs if c["restarts"] >= 3 or c["status"] == "restarting"],
                         "oom_killed": [c["name"] for c in cs if c["oom_killed"]],
                         "top": cs[:8]}
out["history_monitoring"] = lines("monitors")
print(json.dumps(out, indent=1))
PY
