#!/usr/bin/env bash
# Syntax-check every nftables ruleset shipped by eDEX-OS (nft -c needs no root for -f on a file
# when no ruleset is loaded; run inside the Arch build container in CI).
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
fail=0
check() { echo "==> $1"; nft -c -f "$1" || fail=1; }
check "$ROOT/system-settings/etc/edex-os/nftables.conf"
tmp=$(mktemp)
sed -e 's/@TOR_UID@/43/' "$ROOT/system-settings/usr/share/edex-os/tor/transparent.nft" > "$tmp"
echo "==> transparent.nft (strict)"; nft -c -f "$tmp" || fail=1
sed -i 's/^\(\s*\)# @TAILSCALE@ /\1/' "$tmp"
echo "==> transparent.nft (with Tailscale exemptions)"; nft -c -f "$tmp" || fail=1
rm -f "$tmp"
[ "$fail" -eq 0 ] && echo "nft lint OK" || { echo "nft lint FAILED"; exit 1; }
