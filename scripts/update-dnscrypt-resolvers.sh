#!/usr/bin/env bash
# Refresh the resolver list bundled in edex-os-settings (system-settings/usr/share/edex-os/dnscrypt)
# from the current DNSCrypt/dnscrypt-resolvers master commit. The list seeds dnscrypt-proxy's cache
# so DNS works before (or without) a successful download; dnscrypt-proxy checks the minisign
# signature itself and keeps refreshing the list online.
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
DEST=$ROOT/system-settings/usr/share/edex-os/dnscrypt
REPO=https://github.com/DNSCrypt/dnscrypt-resolvers
KEY=RWQf6LRCGA9i53mlYecO4IzT51TGPpvWucNSCh1CBM0QTaLn73Y7GFO3

commit=$(git ls-remote "$REPO" refs/heads/master | cut -f1)
[ -n "$commit" ] || { echo "cannot resolve $REPO master" >&2; exit 1; }
tmp=$(mktemp -d); trap 'rm -rf -- "${tmp:?}"' EXIT
for f in public-resolvers.md public-resolvers.md.minisig; do
    curl -fsSL --retry 5 -o "$tmp/$f" "https://raw.githubusercontent.com/DNSCrypt/dnscrypt-resolvers/$commit/v3/$f"
done
if command -v minisign >/dev/null; then
    minisign -Vm "$tmp/public-resolvers.md" -P "$KEY" >/dev/null
else
    echo "minisign not installed: signature not checked here (dnscrypt-proxy checks it at load)" >&2
fi
mkdir -p "$DEST"
cp "$tmp"/public-resolvers.md "$tmp"/public-resolvers.md.minisig "$DEST/"
echo "$commit" > "$DEST/COMMIT"
echo "bundled resolver list updated to $commit"
