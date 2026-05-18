#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ISO="$(ls "${SCRIPT_DIR}/../out/eDEX-OS-"*.iso 2>/dev/null | head -1)"

if [[ -z "$ISO" ]]; then
    echo "No ISO found in out/. Run buildiso.sh first."
    exit 1
fi

echo "==> Testing ISO: $ISO"
qemu-system-x86_64 \
  -enable-kvm \
  -m 4096 \
  -cpu host \
  -smp 2 \
  -bios /usr/share/ovmf/x64/OVMF.fd \
  -drive "file=${ISO},media=cdrom,readonly=on" \
  -boot d \
  -vga virtio \
  -display sdl \
  -no-reboot \
  -serial stdio
