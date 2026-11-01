#!/bin/sh
# lumen-vm.sh — try Lumen in a virtual machine: test changes without touching
# this desktop, or show it off. QEMU with KVM, a GPU-accelerated window
# (virtio-gpu + OpenGL, which Hyprland needs), this folder shared read-only.
#
#   lumen vm check                  what's missing (QEMU, KVM, an install image)
#   lumen vm create <fedora.iso>    a 40 GB disk (grows as used) and boot the installer
#   lumen vm start                  boot the installed VM
#   lumen vm inside                 the commands to run inside the VM once Fedora is installed
#   lumen vm delete                 remove the VM's disk (asks first)
#
# It never downloads anything: get the image yourself from
# https://fedoraproject.org/everything/download (or Workstation) and check it
# with the CHECKSUM file there (sha256sum -c). Installing QEMU is yours too:
#   sudo dnf install qemu-kvm qemu-img qemu-ui-gtk qemu-device-display-virtio-gpu-gl
set -eu
LUMEN_ROOT=${LUMEN_ROOT:-$HOME/.config/lumen}
VMDIR=${XDG_DATA_HOME:-$HOME/.local/share}/lumen/vm
DISK=$VMDIR/lumen.qcow2
MEM=${LUMEN_VM_MEM:-6G}
CPUS=${LUMEN_VM_CPUS:-4}

need() {
    ok=1
    command -v qemu-system-x86_64 >/dev/null 2>&1 || { echo "QEMU isn't installed: sudo dnf install qemu-kvm qemu-img qemu-ui-gtk qemu-device-display-virtio-gpu-gl"; ok=0; }
    command -v qemu-img >/dev/null 2>&1 || { echo "qemu-img isn't installed (same command)"; ok=0; }
    [ -r /dev/kvm ] && [ -w /dev/kvm ] || { echo "No access to /dev/kvm (virtualisation off in the firmware, or not in the kvm group)"; ok=0; }
    [ $ok = 1 ]
}
run() {   # run <extra qemu args…>
    # the repository, read-only, as the 9p tag "lumen" (see: lumen vm inside)
    exec qemu-system-x86_64 -enable-kvm -machine q35 -cpu host -smp "$CPUS" -m "$MEM" \
        -drive file="$DISK",if=virtio,discard=unmap \
        -device virtio-vga-gl -display gtk,gl=on \
        -device virtio-net-pci,netdev=n0 -netdev user,id=n0 \
        -device intel-hda -device hda-duplex \
        -virtfs local,path="$(readlink -f "$LUMEN_ROOT")",mount_tag=lumen,security_model=none,readonly=on \
        -name "Lumen VM" "$@"
}

case ${1:-} in
check)
    if need; then echo "QEMU and KVM: ready"; fi
    if [ -f "$DISK" ]; then echo "VM disk: $DISK ($(du -h "$DISK" | cut -f1) used)"; else echo "No VM yet: lumen vm create <fedora.iso>"; fi ;;
create)
    iso=${2:?usage: lumen vm create <fedora.iso>  (download it yourself — see lumen vm with no arguments)}
    [ -f "$iso" ] || { echo "No such file: $iso" >&2; exit 1; }
    need || exit 1
    [ -e "$DISK" ] && { echo "There's already a VM ($DISK): lumen vm start, or lumen vm delete first" >&2; exit 1; }
    mkdir -p "$VMDIR"
    qemu-img create -q -f qcow2 "$DISK" 40G
    echo "Install Fedora in the window that opens; then: lumen vm start, and lumen vm inside for the next steps."
    run -cdrom "$iso" -boot once=d ;;
start)
    need || exit 1
    [ -f "$DISK" ] || { echo "No VM yet: lumen vm create <fedora.iso>" >&2; exit 1; }
    run ;;
inside)
    cat <<'EOF'
Inside the VM (a terminal there), once Fedora is installed:

  # your Lumen folder from this computer, read-only
  sudo mkdir -p /mnt/lumen && sudo mount -t 9p -o trans=virtio,version=9p2000.L,ro lumen /mnt/lumen
  # a copy to run (the install writes generated files into it)
  cp -a /mnt/lumen ~/lumen && cd ~/lumen
  ./install.sh --dry-run      # read what it would do
  ./install.sh
  # then log out and pick "Lumen" on the login screen

To try newer changes later: copy /mnt/lumen again (or git pull from it).
EOF
    ;;
delete)
    [ -f "$DISK" ] || { echo "No VM disk" >&2; exit 1; }
    printf 'Delete the VM disk %s (%s)? [y/N] ' "$DISK" "$(du -h "$DISK" | cut -f1)"; read -r a
    [ "$a" = y ] || [ "$a" = Y ] || exit 0
    rm -f "$DISK"; echo "Deleted." ;;
*)
    sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2 ;;
esac
