#!/usr/bin/env bash
# Unattended installation test: boot the ISO with `edex.ci=install`, let edex-ci-install put
# eDEX-OS on a blank virtual disk, then boot that disk in UEFI and BIOS mode and require the
# installed system to reach the eDEX greeter (EDEX_CI: installed-ok printed by the units below).
#
#   scripts/test-install.sh [--iso path] [--timeout secs]
set -euo pipefail
ISO=""; TIMEOUT=${EDEX_TEST_TIMEOUT:-1200}
while [ $# -gt 0 ]; do
    case "$1" in
        --iso) ISO=$2; shift 2 ;;
        --timeout) TIMEOUT=$2; shift 2 ;;
        *) echo "unknown option $1" >&2; exit 2 ;;
    esac
done
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
[ -n "$ISO" ] || ISO=$(ls "$ROOT"/out/edex-os-*.iso 2>/dev/null | head -1 || true)
[ -f "$ISO" ] || { echo "no ISO found" >&2; exit 1; }
OUT="$ROOT/out/test"; mkdir -p "$OUT"
DISK="$OUT/install.qcow2"
rm -f "$DISK"; qemu-img create -f qcow2 "$DISK" 24G >/dev/null

ovmf=""
for f in /usr/share/edk2/x64/OVMF_CODE.4m.fd /usr/share/edk2/x64/OVMF_CODE.fd /usr/share/OVMF/OVMF_CODE_4M.fd /usr/share/OVMF/OVMF_CODE.fd; do
    [ -f "$f" ] && { ovmf=$f; break; }
done
[ -n "$ovmf" ] || { echo "OVMF not found" >&2; exit 1; }
if [ -w /dev/kvm ]; then ACCEL="-enable-kvm -cpu host"; else ACCEL="-accel tcg,thread=multi -cpu max"; fi

# Extract kernel + initramfs so we can pass edex.ci=install without touching the boot menu.
TMP=$(mktemp -d); trap 'rm -rf -- "${TMP:?}"' EXIT
bsdtar -xf "$ISO" -C "$TMP" arch/boot/x86_64/vmlinuz-linux-cachyos arch/boot/x86_64/initramfs-linux-cachyos.img 2>/dev/null \
    || (cd "$TMP" && 7z x -y "$ISO" 'arch/boot/*' >/dev/null)
cp "$TMP/arch/boot/x86_64/initramfs-linux-cachyos.img" "$TMP/initrd.img"
LABEL=$(blkid -o value -s LABEL "$ISO" 2>/dev/null || isoinfo -d -i "$ISO" | sed -n 's/^Volume id: //p')

echo "==> installing (log: $OUT/install.log)"
# shellcheck disable=SC2086
timeout --foreground "$TIMEOUT" qemu-system-x86_64 $ACCEL -m 4096 -smp 2 \
    -drive "if=pflash,format=raw,readonly=on,file=$ovmf" \
    -drive "file=$ISO,media=cdrom,readonly=on,if=ide" \
    -drive "file=$DISK,format=qcow2,if=virtio" \
    -kernel "$TMP/arch/boot/x86_64/vmlinuz-linux-cachyos" -initrd "$TMP/initrd.img" \
    -append "archisobasedir=arch archisolabel=$LABEL console=ttyS0,115200 edex.ci=install" \
    -vga virtio -display none -device virtio-rng-pci -netdev user,id=n0 -device virtio-net-pci,netdev=n0 \
    -serial "file:$OUT/install.log" -monitor none -no-reboot >/dev/null 2>&1 || true
grep -q "EDEX_CI: install-ok" "$OUT/install.log" || { echo "installation FAILED"; tail -60 "$OUT/install.log"; exit 1; }
echo "    install-ok"

boot_disk() {
    local mode=$1 log="$OUT/installed-$1.log" fw=()
    [ "$mode" = uefi ] && fw=(-drive "if=pflash,format=raw,readonly=on,file=$ovmf")
    echo "==> booting the installed disk ($mode), log: $log"
    # shellcheck disable=SC2086
    timeout --foreground "$TIMEOUT" qemu-system-x86_64 $ACCEL -m 4096 -smp 2 "${fw[@]}" \
        -drive "file=$DISK,format=qcow2,if=virtio" -vga virtio -display none -device virtio-rng-pci \
        -netdev user,id=n0 -device virtio-net-pci,netdev=n0 -serial "file:$log" -monitor none -no-reboot >/dev/null 2>&1 &
    local pid=$!
    for _ in $(seq 1 "$TIMEOUT"); do
        grep -q "EDEX_CI: installed-ok" "$log" 2>/dev/null && { kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; echo "    installed-ok"; return 0; }
        kill -0 "$pid" 2>/dev/null || break
        sleep 1
    done
    kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true
    echo "    installed system did not report ($mode)"; tail -40 "$log"; return 1
}
rc=0
boot_disk uefi || rc=1
boot_disk bios || rc=1
[ "$rc" -eq 0 ] && echo "install tests OK" || echo "install tests FAILED"
exit $rc
