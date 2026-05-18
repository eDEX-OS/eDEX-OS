#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ISO_PROFILE="${SCRIPT_DIR}/iso"
WORK_DIR="/tmp/edex-os-work"
OUT_DIR="${SCRIPT_DIR}/out"

echo "==> Building eDEX-OS ISO"
echo "==> Profile: ${ISO_PROFILE}"

mkdir -p "${OUT_DIR}"
sudo mkarchiso -v -w "${WORK_DIR}" -o "${OUT_DIR}" "${ISO_PROFILE}"

echo "==> ISO built:"
ls -lh "${OUT_DIR}"/*.iso

echo "==> Generating checksums"
cd "${OUT_DIR}"
for iso in *.iso; do
    sha256sum "${iso}" > "${iso}.sha256"
    sha512sum "${iso}" > "${iso}.sha512"
    echo "  ${iso}.sha256"
    echo "  ${iso}.sha512"
done

echo "==> Done."
