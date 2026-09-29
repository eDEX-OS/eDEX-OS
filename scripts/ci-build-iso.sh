#!/usr/bin/env bash
# Build the eDEX-OS ISO. Runs as root inside `archlinux:latest` (docker --privileged) with the
# repository mounted at /workspace. Also usable on a CachyOS/Arch host as root.
#
#   docker run --rm --privileged -v "$PWD:/workspace" -w /workspace archlinux:latest \
#       bash scripts/ci-build-iso.sh
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
OUT="$ROOT/out"
WORK=${EDEX_ISO_WORK:-/tmp/edex-os-work}
REPO_DIR="$OUT/repo"
msg() { echo "==> $*"; }

if [ "$(id -u)" -ne 0 ]; then echo "run as root" >&2; exit 1; fi

# Keyrings: Arch first, then the CachyOS keyring straight from its mirror (no keyserver needed).
msg "initialising pacman keyrings"
pacman-key --init >/dev/null 2>&1
pacman-key --populate archlinux >/dev/null 2>&1
pacman -Sy --noconfirm --needed archlinux-keyring >/dev/null
if ! pacman -Q cachyos-keyring >/dev/null 2>&1; then
    M=https://mirror.cachyos.org/repo/x86_64/cachyos
    tmp=$(mktemp -d)
    for p in cachyos-keyring-20240331-1-any cachyos-mirrorlist-27-1-any cachyos-v3-mirrorlist-27-1-any cachyos-v4-mirrorlist-27-1-any; do
        curl -sfL "$M/$p.pkg.tar.zst" -o "$tmp/$p.pkg.tar.zst"
    done
    pacman -U --noconfirm "$tmp"/*.pkg.tar.zst >/dev/null
    pacman-key --populate cachyos >/dev/null 2>&1
    rm -rf -- "${tmp:?}"
fi
if ! grep -q '^\[cachyos\]' /etc/pacman.conf; then
    printf '\n[cachyos]\nInclude = /etc/pacman.d/cachyos-mirrorlist\n' >> /etc/pacman.conf
fi

msg "installing build tools"
pacman -Syu --noconfirm --needed base-devel git archiso squashfs-tools dosfstools mtools libisoburn grub syslinux \
    librsvg imagemagick ttf-dejavu sudo namcap >/dev/null
# The checkout is mounted from the host (another owner): let git read it for versions and archives.
git config --global --add safe.directory '*'

if [ "${EDEX_SKIP_PACKAGES:-0}" = 1 ] && [ -f "$REPO_DIR/edex-os.db" ]; then
    msg "reusing the packages already in $REPO_DIR (EDEX_SKIP_PACKAGES=1)"
else
    msg "building packages into [edex-os]"
    "$ROOT/scripts/build-packages.sh" "$REPO_DIR"
fi

msg "generating iso/pacman.conf"
sed "s|@REPO_DIR@|$REPO_DIR|" "$ROOT/iso/pacman.conf.in" > "$ROOT/iso/pacman.conf"

msg "checking that every package in packages.x86_64 resolves"
dbtmp=$(mktemp -d)
pacman --config "$ROOT/iso/pacman.conf" --dbpath "$dbtmp" -Sy >/dev/null
grep -vE '^\s*(#|$)' "$ROOT/iso/packages.x86_64" | xargs pacman --config "$ROOT/iso/pacman.conf" --dbpath "$dbtmp" -Sp --print-format '%n' >/dev/null
rm -rf -- "${dbtmp:?}"

msg "staging generated artwork into the profile"
install -Dm644 "$ROOT/branding/generated/syslinux/splash.png" "$ROOT/iso/syslinux/splash.png"
install -dm755 "$ROOT/iso/grub/fonts" "$ROOT/iso/grub/themes/edex-os/icons"
install -m644 "$ROOT"/branding/generated/grub/*.pf2 "$ROOT/iso/grub/fonts/"
install -m644 "$ROOT"/branding/generated/grub/*.pf2 "$ROOT/branding/generated/grub/background.png" "$ROOT/branding/grub/edex-os/theme.txt" "$ROOT/iso/grub/themes/edex-os/"
install -m644 "$ROOT"/branding/generated/grub/icons/*.png "$ROOT/iso/grub/themes/edex-os/icons/"

msg "running mkarchiso"
rm -rf -- "${WORK:?}"
mkdir -p "$OUT"
mkarchiso -v -w "$WORK" -o "$OUT" "$ROOT/iso"

msg "ISO built"
ls -lh "$OUT"/*.iso
cd "$OUT"
for iso in *.iso; do
    sha256sum "$iso" > "$iso.sha256"
    sha512sum "$iso" > "$iso.sha512"
done
rm -rf -- "${WORK:?}"
