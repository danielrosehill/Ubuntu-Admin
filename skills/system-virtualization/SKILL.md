---
name: system-virtualization
description: Check and set up virtualization on Ubuntu, in both directions. As a host, it covers CPU VT-x/AMD-V and BIOS enablement, KVM/QEMU/libvirt install, kvm/libvirt groups, the default network, storage pools, nested virtualization, IOMMU for PCI passthrough, and conflicts with VirtualBox or VMware. As a guest, it covers detecting the hypervisor, guest agents, and what that means for disk, GPU and sensor checks. Use when asked "can this machine run VMs", "set up KVM", "virt-manager not working", "enable nested virtualization", "IOMMU groups", "is this a VM", or "install qemu-guest-agent". Works on the local machine or a remote host over SSH.
---

# System virtualization

## Target

Local by default. Remote: `ssh <host> '<cmd>'`, and `ssh -t <host> 'sudo …'` for installs.

## Am I a guest?

```bash
systemd-detect-virt            # none | kvm | qemu | vmware | microsoft | oracle | lxc | wsl ...
systemd-detect-virt --container
hostnamectl | grep -i virtualization
```

If it is a guest:
- Install the matching agent so the hypervisor can shut down cleanly, report IPs and freeze filesystems for snapshots. Use `qemu-guest-agent` for KVM/Proxmox (and enable the agent option in the VM settings), `open-vm-tools` for VMware, and `linux-azure`/`hyperv-daemons` (`linux-cloud-tools-virtual`) for Hyper-V.
  ```bash
  sudo apt install qemu-guest-agent && sudo systemctl enable --now qemu-guest-agent
  ```
- SMART, fan and temperature, firmware and most GPU checks do not apply unless a device is passed through. Run those on the hypervisor.
- With a passed-through GPU, check with `lspci -k` that the guest driver is bound (see `hardware-gpu`).
- If you can SSH to the hypervisor (for example Proxmox, as `ssh <hypervisor> 'qm status <vmid>; qm config <vmid>'`), use it to check VM state, snapshots, backups and `hostpci` passthrough entries.

## Host readiness (KVM/libvirt)

```bash
grep -Eoc '(vmx|svm)' /proc/cpuinfo               # >0 = CPU supports it
sudo apt install cpu-checker && kvm-ok             # "KVM acceleration can be used" or why not (e.g. disabled in BIOS)
lsmod | grep -E '^kvm(_intel|_amd)?'
ls -l /dev/kvm
```

If `kvm-ok` says the feature is disabled, it must be enabled in the BIOS/UEFI as VT-x/AMD-V/SVM. That cannot be done from the OS.

Install the stack:

```bash
sudo apt install qemu-kvm libvirt-daemon-system libvirt-clients virtinst bridge-utils ovmf
sudo apt install virt-manager                      # desktop GUI only
sudo usermod -aG libvirt,kvm "$USER"               # log out and in for it to apply
systemctl status libvirtd --no-pager               # on 24.04+ also: systemctl status virtqemud.socket
virsh -c qemu:///system list --all
```

Networking and storage:

```bash
virsh net-list --all                               # 'default' NAT network should be active + autostart
sudo virsh net-start default; sudo virsh net-autostart default
virsh pool-list --all                              # 'default' -> /var/lib/libvirt/images
df -h /var/lib/libvirt/images
```

For VMs that must sit on the LAN, use a bridge (`br0`) defined in netplan instead of NAT. See `network-config`. Bridges do not work over most Wi-Fi adapters.

Dry-run a VM definition without creating anything:

```bash
virt-install --name test --memory 1024 --vcpus 1 --disk size=5 --osinfo ubuntu24.04 \
  --cdrom /path/to.iso --graphics none --dry-run --print-xml | head -20
```

## Nested virtualization and passthrough

```bash
cat /sys/module/kvm_intel/parameters/nested 2>/dev/null || cat /sys/module/kvm_amd/parameters/nested
# Enable persistently (Intel shown; use kvm_amd for AMD):
echo 'options kvm_intel nested=1' | sudo tee /etc/modprobe.d/kvm-nested.conf

# IOMMU for PCI passthrough
sudo dmesg | grep -iE 'DMAR|IOMMU|AMD-Vi' | head
for g in /sys/kernel/iommu_groups/*; do echo "Group ${g##*/}:"; for d in "$g"/devices/*; do echo "  $(lspci -nns "${d##*/}")"; done; done
```

On Intel, IOMMU needs `intel_iommu=on iommu=pt` added to `GRUB_CMDLINE_LINUX_DEFAULT` in `/etc/default/grub`, followed by `sudo update-grub` and a reboot. AMD enables it by default on most boards.

## Conflicts

- VirtualBox and KVM can coexist on recent kernels, but running both kinds of VM at once can still fail. Check with `lsmod | grep vbox`.
- VirtualBox and VMware kernel modules are built with DKMS. With Secure Boot on, they need MOK enrolment (`mokutil --sb-state`). Without it, the modules will not load after a kernel update.
- Docker and libvirt both manipulate iptables/nftables. If VMs lose network after installing Docker, check the `FORWARD` policy (Docker sets it to DROP).

## Confirm before

Installing packages, adding the user to groups, editing GRUB or modprobe options (both need a reboot), changing libvirt networks, and destroying or undefining any VM (`virsh destroy`/`undefine` and the disk image).

## Report

A readiness table showing CPU support, BIOS enabled, modules, libvirt, group membership, default network, nested and IOMMU status. Follow it with the concrete fixes. For a guest, give the hypervisor type, agent status and which checks to skip.

## Related

`system-preflight`, `hardware-profile`, `hardware-gpu` (passthrough), `network-config` (bridges).
