#!/usr/bin/env bash
# QEMU boot test of the live ISO:
#   1. firmware boot (UEFI via OVMF, BIOS via SeaBIOS) must reach the eDEX-OS boot menu on the serial
#      console (GRUB and syslinux are both configured for it);
#   2. the ISO's kernel + initramfs are booted directly with `console=ttyS0 edex.ci` (the default menu
#      entries keep their output on the display) and the live system must print
#      EDEX_CI: boot-ok, installer-ok and shell-ok (edex-ci-report.service).
#
#   scripts/test-iso.sh [--mode uefi|bios|both] [--iso path] [--timeout secs] [--no-shell]
set -euo pipefail
MODE=both; ISO=""; TIMEOUT=${EDEX_TEST_TIMEOUT:-}; MENU_TIMEOUT=300; SHELL_TEST=1
while [ $# -gt 0 ]; do
    case "$1" in
        --mode) MODE=$2; shift 2 ;;
        --iso) ISO=$2; shift 2 ;;
        --timeout) TIMEOUT=$2; shift 2 ;;
        --no-shell) SHELL_TEST=0; shift ;;
        *) echo "unknown option $1" >&2; exit 2 ;;
    esac
done
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
[ -n "$ISO" ] || ISO=$(ls "$ROOT"/out/edex-os-*.iso 2>/dev/null | head -1 || true)
[ -f "$ISO" ] || { echo "no ISO found (build first or pass --iso)" >&2; exit 1; }
OUT="$ROOT/out/test"; mkdir -p "$OUT"

find_ovmf() {
    for f in /usr/share/edk2/x64/OVMF_CODE.4m.fd /usr/share/edk2/x64/OVMF_CODE.fd /usr/share/OVMF/OVMF_CODE_4M.fd \
             /usr/share/OVMF/OVMF_CODE.fd /usr/share/edk2-ovmf/x64/OVMF_CODE.fd /usr/share/qemu/OVMF.fd; do
        [ -f "$f" ] && { echo "$f"; return; }
    done
    return 1
}
for tool in qemu-system-x86_64 bsdtar; do
    command -v "$tool" >/dev/null || { echo "missing required tool: $tool" >&2; exit 2; }
done
# shellcheck disable=SC2054
if [ -w /dev/kvm ]; then ACCEL=(-enable-kvm -cpu host); else ACCEL=(-accel tcg,thread=multi -cpu max); fi
# Without KVM the live boot (pacman keyring population in particular) takes far longer.
if [ -z "$TIMEOUT" ]; then if [ -w /dev/kvm ]; then TIMEOUT=900; else TIMEOUT=2400; fi; fi
# shellcheck disable=SC2054
COMMON=(-m 4096 -smp 2 -vga virtio -display none -device virtio-rng-pci -netdev user,id=n0 -device virtio-net-pci,netdev=n0 -monitor none -no-reboot)

wait_for() {
    # wait_for <log> <pid> <seconds> <regex-success> <regex-failure>
    local log=$1 pid=$2 secs=$3 ok=$4 bad=$5
    for _ in $(seq 1 "$secs"); do
        if grep -aqE "$ok" "$log" 2>/dev/null; then return 0; fi
        if [ -n "$bad" ] && grep -aqE "$bad" "$log" 2>/dev/null; then return 1; fi
        kill -0 "$pid" 2>/dev/null || return 1
        sleep 1
    done
    return 1
}

menu_boot() {
    local mode=$1 log="$OUT/menu-$1.log" fw=()
    if [ "$mode" = uefi ]; then
        local ovmf; ovmf=$(find_ovmf) || { echo "OVMF firmware not found" >&2; return 2; }
        fw=(-drive "if=pflash,format=raw,readonly=on,file=$ovmf")
    fi
    echo "==> $mode firmware boot to the menu (log: $log)"
    : > "$log"
    qemu-system-x86_64 "${ACCEL[@]}" "${COMMON[@]}" "${fw[@]}" -drive "file=$ISO,media=cdrom,readonly=on,if=ide" -boot d \
        -serial "file:$log" >/dev/null 2>&1 &
    local pid=$!
    local rc=0
    wait_for "$log" "$pid" "$MENU_TIMEOUT" "eDEX-OS live" "" || rc=1
    kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true
    if [ "$rc" -eq 0 ]; then echo "    menu-ok"; else echo "    menu NOT reached"; tr -d '\r' < "$log" | tail -20; fi
    return $rc
}

shell_boot() {
    local log="$OUT/boot-live.log" tmp
    tmp=$(mktemp -d); trap 'rm -rf -- "${tmp:?}"' RETURN
    bsdtar -xf "$ISO" -C "$tmp" arch/boot/x86_64/vmlinuz-linux-cachyos arch/boot/x86_64/initramfs-linux-cachyos.img
    local label; label=$(dd if="$ISO" bs=1 skip=32808 count=32 2>/dev/null | tr -d ' \0')
    echo "==> live system boot with serial console (label $label, log: $log)"
    : > "$log"
    qemu-system-x86_64 "${ACCEL[@]}" "${COMMON[@]}" -drive "file=$ISO,media=cdrom,readonly=on,if=ide" \
        -kernel "$tmp/arch/boot/x86_64/vmlinuz-linux-cachyos" -initrd "$tmp/arch/boot/x86_64/initramfs-linux-cachyos.img" \
        -append "archisobasedir=arch archisolabel=$label console=tty0 console=ttyS0,115200 edex.ci systemd.firstboot=off plymouth.enable=0 loglevel=4" \
        -serial "file:$log" >/dev/null 2>&1 &
    local pid=$!
    local rc=0
    wait_for "$log" "$pid" "$TIMEOUT" "EDEX_CI: shell-(ok|fail)" "Kernel panic" || rc=1
    kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true
    for m in boot-ok installer-ok shell-ok; do
        if grep -aq "EDEX_CI: $m" "$log"; then echo "    $m"; else echo "    $m MISSING"; rc=1; fi
    done
    [ "$rc" -eq 0 ] || { echo "==> live boot FAILED; last log lines:"; tr -d '\r' < "$log" | tail -40; }
    return $rc
}

rc=0
case "$MODE" in
    uefi) menu_boot uefi || rc=1 ;;
    bios) menu_boot bios || rc=1 ;;
    both) menu_boot uefi || rc=1; menu_boot bios || rc=1 ;;
    *) echo "bad mode $MODE" >&2; exit 2 ;;
esac
if [ "$SHELL_TEST" -eq 1 ]; then shell_boot || rc=1; fi
[ "$rc" -eq 0 ] && echo "ISO boot tests OK" || echo "ISO boot tests FAILED"
exit $rc
