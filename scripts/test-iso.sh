#!/usr/bin/env bash
# Boot the ISO in QEMU (UEFI and/or BIOS) and assert the serial-console markers printed by
# edex-ci-report in the live system:  EDEX_CI: boot-ok  and  EDEX_CI: shell-ok.
#
#   scripts/test-iso.sh [--mode uefi|bios|both] [--iso path] [--timeout secs]
set -euo pipefail
MODE=both; ISO=""; TIMEOUT=${EDEX_TEST_TIMEOUT:-600}
while [ $# -gt 0 ]; do
    case "$1" in
        --mode) MODE=$2; shift 2 ;;
        --iso) ISO=$2; shift 2 ;;
        --timeout) TIMEOUT=$2; shift 2 ;;
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
accel_args() {
    if [ -w /dev/kvm ]; then echo "-enable-kvm -cpu host"; else echo "-accel tcg,thread=multi -cpu max"; fi
}

run_boot() {
    local mode=$1 log="$OUT/boot-$1.log" fw=()
    if [ "$mode" = uefi ]; then
        local ovmf; ovmf=$(find_ovmf) || { echo "OVMF firmware not found" >&2; return 2; }
        fw=(-drive "if=pflash,format=raw,readonly=on,file=$ovmf")
    fi
    echo "==> booting $ISO ($mode), log: $log"
    # shellcheck disable=SC2046
    timeout --foreground "$TIMEOUT" qemu-system-x86_64 $(accel_args) -m 4096 -smp 2 "${fw[@]}" \
        -drive "file=$ISO,media=cdrom,readonly=on,if=ide" -boot d -vga virtio -display none \
        -device virtio-rng-pci -netdev user,id=n0 -device virtio-net-pci,netdev=n0 \
        -serial "file:$log" -monitor none -no-reboot >/dev/null 2>&1 &
    local pid=$!
    local ok=1
    for _ in $(seq 1 "$TIMEOUT"); do
        if grep -q "EDEX_CI: shell-ok" "$log" 2>/dev/null; then ok=0; break; fi
        if grep -q "EDEX_CI: shell-fail" "$log" 2>/dev/null; then break; fi
        kill -0 "$pid" 2>/dev/null || break
        sleep 1
    done
    kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true
    grep -q "EDEX_CI: boot-ok" "$log" && echo "    boot-ok" || { echo "    boot marker missing"; ok=1; }
    grep -q "EDEX_CI: shell-ok" "$log" && echo "    shell-ok" || { echo "    shell marker missing"; ok=1; }
    grep -q "EDEX_CI: installer-ok" "$log" && echo "    installer-ok" || { echo "    installer broken or marker missing"; ok=1; }
    [ "$ok" -eq 0 ] || { echo "==> $mode boot FAILED; last log lines:"; tail -40 "$log"; }
    return $ok
}

rc=0
case "$MODE" in
    uefi) run_boot uefi || rc=1 ;;
    bios) run_boot bios || rc=1 ;;
    both) run_boot uefi || rc=1; run_boot bios || rc=1 ;;
    *) echo "bad mode $MODE" >&2; exit 2 ;;
esac
[ "$rc" -eq 0 ] && echo "ISO boot tests OK" || echo "ISO boot tests FAILED"
exit $rc
