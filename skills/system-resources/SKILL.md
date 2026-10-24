---
name: system-resources
description: Diagnose slowdowns, lag, high load, memory pressure, swap thrashing, runaway or zombie processes and I/O wait on an Ubuntu machine, and watch resources live. Use when the user says "the machine is slow", "laggy", "high load", "out of memory", "what is eating my RAM/CPU", "swap is full", "fans are loud", or asks to monitor resources. Works on the local machine or a remote host over SSH.
---

# System resources

Find which resource is exhausted (CPU, memory, I/O or a single process) and why.

## Target

Local by default. Remote: `ssh <host> '<cmd>'`. Most commands here need no root. `iotop` and per-process I/O need `sudo`.

## 1. Which resource?

```bash
uptime; nproc                                   # load vs CPU count
cat /proc/pressure/{cpu,memory,io}             # PSI: share of time tasks stalled
vmstat 1 5                                      # r = runnable, b = blocked on I/O, si/so = swapping, wa = I/O wait
free -h; swapon --show; zramctl 2>/dev/null
```

How to read it:
- **CPU-bound**: load above `nproc`, `us`+`sy` high in vmstat, `cpu some` PSI high.
- **Memory**: `available` low, `si`/`so` non-zero and sustained, `memory some/full` PSI high.
- **I/O**: `wa` high, `b` > 0, `io` PSI high, while the CPU is mostly idle.
- **Nothing obvious**: suspect thermal throttling (`sensors`, `cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq`) or a single-threaded hog. On desktops, also suspect the GPU or compositor.

## 2. Who?

```bash
ps -eo pid,user,%cpu,%mem,rss,etime,comm --sort=-%cpu | head -15
ps -eo pid,user,%mem,rss,comm --sort=-rss | head -15
systemd-cgtop -b -n 1 --order=memory | head -20        # per service/scope. Shows which unit owns the usage.
ps -eo stat,pid,ppid,comm | awk '$1 ~ /^Z/'            # zombies (report the parent)
ps -eo stat,pid,comm | awk '$1 ~ /^D/'                 # stuck in uninterruptible I/O

# Swap per process (top 10)
for f in /proc/[0-9]*/status; do awk '/^Name/{n=$2} /^VmSwap/{if($2>0) print $2" kB", n}' "$f" 2>/dev/null; done | sort -rn | head -10

# I/O per process
sudo iotop -b -o -n 3 2>/dev/null | head -30      # apt install iotop-c (or iotop)
pidstat -d 1 3 2>/dev/null                        # sysstat
```

Recent kills and pressure events:

```bash
journalctl -k --since "1 hour ago" | grep -iE 'out of memory|oom-kill|killed process'
journalctl -u systemd-oomd --since "1 hour ago" --no-pager 2>/dev/null | tail
```

## 3. Live watching

`htop` or `btop`, if installed. Otherwise use `top -o %MEM`, `watch -n2 free -h`, or `vmstat 2`. Over SSH, use `ssh -t <host> htop`. For historical "what happened at 3am", `sar` needs `sysstat` to have been collecting. The `linux-debugging` plugin covers setting that up.

## Desktop vs server

- **Desktop**: the usual culprits are browser tabs, Electron apps, indexers (Baloo, Tracker), snap refreshes, `packagekitd`, and the compositor. `systemd-oomd` kills whole app scopes under pressure on Ubuntu 22.04 and later.
- **Server**: look at containers (`docker stats --no-stream`), databases, backup jobs and cron/timers that fire at that hour (`systemctl list-timers`). On small VMs, check whether swap exists at all.

## Confirm before

- Killing a process (`kill`, then `kill -9` only if it ignores SIGTERM). Name the process and what it is doing first.
- Restarting a service to free leaked memory.
- Adding or resizing swap, or changing `vm.swappiness`. Persistent tuning belongs to the `linux-system-optimisation` plugin.

## Report

1. **Bottleneck**: CPU, memory, I/O or thermal, with the numbers.
2. **Culprit**: the process or unit, and how much it uses.
3. **Immediate relief**: the specific action.
4. **Lasting fix**: a memory limit (`systemctl set-property <unit> MemoryMax=…`), schedule change, more swap or RAM, or an upstream bug.

## Related

`performance-audit` (periodic spot check), `system-status`, `system-diagnose`, `services-manage` (resource limits), `docker-health`. The `linux-system-optimisation` plugin covers benchmarks and tuning. The `linux-debugging` plugin covers OOM history and oomd/earlyoom setup.
