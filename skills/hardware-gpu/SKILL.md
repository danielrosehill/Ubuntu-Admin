---
name: hardware-gpu
description: Inspect and fix GPU setup on Ubuntu — identify GPUs and the driver bound to each, install or switch NVIDIA drivers with ubuntu-drivers, check AMD amdgpu/ROCm and Intel stacks, Secure Boot/MOK signing for DKMS modules, Wayland vs X11 with NVIDIA, compute readiness for CUDA/ROCm workloads, GPU passthrough inside a VM, and monitoring tools. Use when asked "which GPU driver am I using", "install nvidia drivers", "nvidia-smi not working", "is ROCm set up", "can PyTorch see my GPU", "GPU status", "GPU passthrough check", or "black screen after driver install". Works on the local machine or a remote host over SSH.
---

# GPU

## Target

Local by default. Remote: `ssh <host> '<cmd>'`; root `ssh -t <host> 'sudo …'`. Driver changes on a remote headless box are low-risk for display but still need a reboot.

## 1. Identify

```bash
lspci -nnk | grep -A3 -E 'VGA|3D|Display'      # "Kernel driver in use" is the truth
lsmod | grep -E '^(nvidia|nouveau|amdgpu|radeon|i915|xe) '
ls -l /dev/dri/                                 # card*/renderD* nodes
echo "$XDG_SESSION_TYPE"                         # desktop: wayland or x11
sudo dmesg -T | grep -iE 'nvidia|amdgpu|i915|drm' | grep -iE 'error|fail|timeout|hang' | tail -20
```

## 2. NVIDIA

```bash
ubuntu-drivers list                       # candidate drivers (add --gpgpu for servers)
ubuntu-drivers devices                    # marks the "recommended" one
sudo ubuntu-drivers install               # recommended desktop driver
sudo ubuntu-drivers install --gpgpu nvidia:<version>-server   # headless compute servers
nvidia-smi                                # driver/CUDA version, utilisation, processes
nvidia-smi --query-gpu=name,driver_version,temperature.gpu,utilization.gpu,memory.used,memory.total,power.draw --format=csv
dkms status
```

- `nvidia-smi` "couldn't communicate with the driver": module not loaded — check `dkms status`, Secure Boot (below), and that `linux-headers-$(uname -r)` is installed.
- Prefer `ubuntu-drivers`/apt packages over the `.run` installer; mixing them breaks upgrades.
- Wayland on NVIDIA needs driver ≥ 535 with `nvidia-drm.modeset=1` (default on recent Ubuntu packages). Check: `cat /sys/module/nvidia_drm/parameters/modeset` → `Y`.

### Secure Boot

```bash
mokutil --sb-state
```

With Secure Boot on, DKMS modules must be signed with an enrolled MOK. Ubuntu's prebuilt `linux-modules-nvidia-*` packages are already signed (preferred). For DKMS builds, `sudo update-secureboot-policy --enroll-key` and complete enrolment at the blue MOK screen on next boot (needs someone at the console).

## 3. AMD

```bash
cat /sys/class/drm/card*/device/power_dpm_force_performance_level 2>/dev/null
sudo apt install -y mesa-vulkan-drivers vulkan-tools && vulkaninfo --summary | head -30
# ROCm (compute) — install per AMD's docs for the Ubuntu release, then:
id -nG | grep -qw render && id -nG | grep -qw video || sudo usermod -aG render,video "$USER"   # re-login after
rocminfo | grep -E 'Name:|Marketing' | head
rocm-smi
```

Consumer cards not on AMD's official support list may need `HSA_OVERRIDE_GFX_VERSION=<x.y.z>`; state that this is unsupported.

## 4. Intel

```bash
sudo apt install -y intel-gpu-tools && sudo intel_gpu_top
vainfo | head        # media acceleration; see desktop-codecs
```

Newer Arc / Xe GPUs may use the `xe` driver instead of `i915`.

## 5. Compute readiness

```bash
python3 - <<'PY'
try:
    import torch
    print("torch", torch.__version__, "cuda/rocm available:", torch.cuda.is_available())
    if torch.cuda.is_available(): print(torch.cuda.get_device_name(0))
except ImportError: print("torch not installed in this interpreter")
PY
nvcc --version 2>/dev/null || echo "CUDA toolkit not installed (runtime from the driver may still be enough for pip wheels)"
docker info 2>/dev/null | grep -i runtimes      # nvidia-container-toolkit registered?
```

## 6. Inside a VM (passthrough)

```bash
systemd-detect-virt
lspci -nnk | grep -A3 -iE 'vga|3d'     # the passed-through card should appear with its real vendor ID
```

If the guest doesn't see it, the problem is on the hypervisor (IOMMU, VFIO binding, `hostpci` config) — check there, not in the guest.

## 7. Monitoring tools

`nvtop` (NVIDIA/AMD/Intel, `apt install nvtop`), `radeontop`, `intel_gpu_top`, `nvidia-smi dmon`.

## Desktop vs server

- **Desktop**: display stack matters — after a driver change verify login works on both Wayland and X11 sessions; keep a TTY (Ctrl+Alt+F3) route to roll back.
- **Server**: use the `-server` NVIDIA branch, enable persistence (`sudo systemctl enable --now nvidia-persistenced`), and check the container toolkit for Docker workloads.

## Confirm before

- Installing, removing or switching drivers (`ubuntu-drivers install`, `apt purge nvidia-*`), and the reboot that follows.
- Enrolling a MOK key; adding the user to groups.
- Changing power/performance levels.

## Report

GPU(s), driver in use and version, health (temp/utilisation/errors), compute readiness (CUDA/ROCm visible: yes/no), and what was changed or recommended.

## Related

- `hardware-profile` — overall inventory.
- `desktop-codecs` — VA-API/VDPAU video acceleration.
- `desktop-displays` — monitors and scaling.
- `docker-setup` — NVIDIA container toolkit.
- `linux-system-optimisation` plugin — GPU benchmarks and tuning.
