#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="${SCRIPT_DIR}/.."
DE_DIR="${REPO_DIR}/desktop"
DEST="${REPO_DIR}/iso/airootfs/usr/bin/edex-de"

echo "==> Building eDEX-DE"
cd "${DE_DIR}"
npm install
npm run tauri build

echo "==> Copying eDEX-DE binary to iso/airootfs/usr/bin/"
# Try bundle first, fall back to raw binary
if ls src-tauri/target/release/bundle/deb/*/data/usr/bin/edex-de 2>/dev/null; then
    cp src-tauri/target/release/bundle/deb/*/data/usr/bin/edex-de "${DEST}"
else
    cp src-tauri/target/release/edex-de "${DEST}"
fi

chmod 755 "${DEST}"
echo "==> eDEX-DE built and copied to ${DEST}"
