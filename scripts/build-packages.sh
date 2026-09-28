#!/usr/bin/env bash
# Build every eDEX-OS package from this checkout (plus pinned AUR packages) into a local pacman
# repository. Runs as root inside an Arch container that already has the CachyOS repo enabled
# (scripts/ci-build-iso.sh does that); creates an unprivileged "builder" user for makepkg.
#
#   scripts/build-packages.sh [out-dir]      (default: out/repo)
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
OUT=$(realpath -m "${1:-$ROOT/out/repo}")
REPO_NAME=edex-os
WORK=${EDEX_PKG_WORK:-/tmp/edex-pkg-work}
BUILDER=builder
mkdir -p "$OUT" "$WORK"

msg() { echo "==> $*"; }

if [ "$(id -u)" -ne 0 ]; then
    echo "run as root inside the build container" >&2
    exit 1
fi
if ! id "$BUILDER" >/dev/null 2>&1; then
    useradd -m "$BUILDER"
fi
echo "$BUILDER ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/90-builder
chmod 440 /etc/sudoers.d/90-builder
pacman -S --needed --noconfirm base-devel git sudo namcap librsvg imagemagick grub >/dev/null

VERSION=$(git -C "$ROOT" describe --tags --always 2>/dev/null | sed -e 's/^v//' -e 's/-/./g')
[ -n "$VERSION" ] || VERSION=$(date +%Y.%m.%d)
msg "eDEX-OS version $VERSION"

# Artwork used by edex-os-branding.
"$ROOT/scripts/make-artwork.sh"

as_builder() { sudo -u "$BUILDER" -H env HOME="/home/$BUILDER" PKGDEST="$OUT" "$@"; }
chown -R "$BUILDER" "$WORK" "$OUT"

build_local() {
    # build_local <pkgname> <tree-dir>... : tar the trees as <pkgname>-<ver>/ and run makepkg.
    local name=${1:?}; shift
    local dir="${WORK:?}/${name:?}"
    local stage="$dir/${name}-${VERSION:?}"
    rm -rf -- "${dir:?}"
    mkdir -p "$stage"
    for tree in "$@"; do
        cp -a "$ROOT/$tree/." "$stage/"
    done
    tar -C "$dir" -cf "$dir/$name-$VERSION.tar" "$name-$VERSION"
    rm -rf -- "${stage:?}"
    sed -e "s/^pkgver=.*/pkgver=$VERSION/" "$ROOT/packages/$name/PKGBUILD" > "$dir/PKGBUILD"
    cp "$ROOT/packages/$name"/*.install "$dir/" 2>/dev/null || true
    chown -R "$BUILDER" "$dir"
    msg "building $name"
    (cd "$dir" && as_builder makepkg -s --noconfirm --skipchecksums -f --noprogressbar >/dev/null)
}

# 1. eDEX-DE from the submodule, with its own PKGBUILD.
if [ ! -f "$ROOT/desktop/Cargo.toml" ]; then
    echo "desktop/ submodule is not checked out (git submodule update --init)" >&2
    exit 1
fi
msg "building edex-de from desktop/ ($(git -C "$ROOT/desktop" rev-parse --short HEAD))"
DE_WORK="${WORK:?}/edex-de"
rm -rf -- "${DE_WORK:?}"
cp -a "$ROOT/desktop" "$DE_WORK"
chown -R "$BUILDER" "$DE_WORK"
(cd "$DE_WORK" && as_builder scripts/build-pkg.sh >/dev/null)
cp "$DE_WORK"/packaging/aur/*.pkg.tar.zst "$OUT/"

# 2. Local packages.
build_local edex-os-settings system-settings
build_local edex-os-branding branding
build_local edex-os-calamares-config calamares
build_local edex-os-greetd-config packaging/greetd
build_local edex-os-live live

# 3. Pinned AUR packages.
while read -r name commit; do
    [ -z "$name" ] || [ "${name#\#}" != "$name" ] && continue
    dir="$WORK/aur-$name"
    if [ ! -d "$dir/.git" ]; then
        as_builder git clone -q "https://aur.archlinux.org/$name.git" "$dir"
    fi
    (cd "$dir" && as_builder git fetch -q origin && as_builder git checkout -q "$commit")
    msg "building AUR $name@$commit"
    (cd "$dir" && as_builder makepkg -s --noconfirm -f --noprogressbar >/dev/null)
done < "$ROOT/scripts/aur-packages.txt"

# 4. Repository database.
msg "creating [$REPO_NAME] repository in $OUT"
rm -f "$OUT/$REPO_NAME".db* "$OUT/$REPO_NAME".files*
repo-add -q "$OUT/$REPO_NAME.db.tar.gz" "$OUT"/*.pkg.tar.zst
ls -1 "$OUT"/*.pkg.tar.zst | sed 's|.*/||'
