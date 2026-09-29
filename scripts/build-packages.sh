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
pacman -S --needed --noconfirm base-devel git sudo namcap librsvg imagemagick grub ttf-dejavu fontconfig >/dev/null

# pkgver in the AUR style: <last tag>.r<commits since>.g<hash>, or 0.r<count>.g<hash> without a tag.
if tag=$(git -C "$ROOT" describe --tags --abbrev=0 2>/dev/null); then
    VERSION="${tag#v}.r$(git -C "$ROOT" rev-list --count "$tag..HEAD").g$(git -C "$ROOT" rev-parse --short HEAD)"
else
    VERSION="0.r$(git -C "$ROOT" rev-list --count HEAD 2>/dev/null || echo 0).g$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || date +%Y%m%d)"
fi
VERSION=${VERSION//-/.}
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
    # Local packages are arch-independent config bundles: nothing to build, so dependency
    # resolution (which would need the not-yet-published [edex-os] repo) is skipped.
    (cd "$dir" && as_builder makepkg -d --noconfirm --skipchecksums -f --noprogressbar >/dev/null)
}

# 1. eDEX-DE from the submodule, with its own PKGBUILD.
if [ ! -f "$ROOT/desktop/Cargo.toml" ]; then
    echo "desktop/ submodule is not checked out (git submodule update --init)" >&2
    exit 1
fi
DE_REV=$(git -C "$ROOT/desktop" rev-parse --short HEAD)
if ls "$OUT"/edex-de-*.pkg.tar.zst >/dev/null 2>&1 && [ "${EDEX_REBUILD_DE:-0}" != 1 ]; then
    msg "reusing the edex-de package already in $OUT (set EDEX_REBUILD_DE=1 to rebuild)"
else
    msg "building edex-de from desktop/ ($DE_REV)"
    DE_WORK="${WORK:?}/edex-de"
    rm -rf -- "${DE_WORK:?}"
    # A submodule's .git is only a pointer file, so clone it into a standalone repository at the
    # pinned commit (the package script uses `git archive`).
    git clone -q --no-hardlinks "$ROOT/desktop" "$DE_WORK"
    git -C "$DE_WORK" checkout -q "$(git -C "$ROOT/desktop" rev-parse HEAD)"
    chown -R "$BUILDER" "$DE_WORK"
    rm -f "$OUT"/edex-de-*.pkg.tar.zst
    # The submodule's script writes the package next to its PKGBUILD unless PKGDEST is set.
    (cd "$DE_WORK" && sudo -u "$BUILDER" -H env HOME="/home/$BUILDER" PKGDEST="$OUT" scripts/build-pkg.sh >/dev/null) || true
    ls "$OUT"/edex-de-*.pkg.tar.zst >/dev/null 2>&1 || { echo "edex-de package was not produced" >&2; exit 1; }
fi

# 2. Local packages.
build_local edex-os-settings system-settings
build_local edex-os-branding branding
build_local edex-os-calamares-config calamares
build_local edex-os-greetd-config packaging/greetd
build_local edex-os-live live

# Packages with a checksum-pinned upstream source (not built from this tree).
for name in edex-os-boost-compat snowflake-pt-client; do
    if ls "$OUT/$name"-*.pkg.tar.zst >/dev/null 2>&1 && [ "${EDEX_REBUILD_PINNED:-0}" != 1 ]; then
        msg "reusing $name already in $OUT"
        continue
    fi
    dir="$WORK/$name"
    rm -rf -- "${dir:?}"; mkdir -p "$dir"
    cp "$ROOT/packages/$name/PKGBUILD" "$dir/"
    chown -R "$BUILDER" "$dir"
    # Fetch and checksum the pinned source first, retrying: upstream archive endpoints are
    # intermittently unavailable.
    fetched=0
    for attempt in 1 2 3 4 5; do
        if (cd "$dir" && as_builder makepkg --verifysource --noconfirm >/dev/null 2>&1); then fetched=1; break; fi
        msg "source download for $name failed (attempt $attempt); retrying"
        find "$dir" -maxdepth 1 -name '*.part' -delete
        sleep $((attempt * 15))
    done
    [ "$fetched" = 1 ] || { echo "could not download the source of $name" >&2; exit 1; }
    msg "building $name"
    (cd "$dir" && as_builder makepkg -s --noconfirm -f --noprogressbar >/dev/null)
done

# 3. Pinned AUR packages.
while read -r name commit; do
    [ -z "$name" ] || [ "${name#\#}" != "$name" ] && continue
    if ls "$OUT/$name"-*.pkg.tar.zst >/dev/null 2>&1 && [ "${EDEX_REBUILD_AUR:-0}" != 1 ]; then
        msg "reusing AUR package $name already in $OUT (set EDEX_REBUILD_AUR=1 to rebuild)"
        continue
    fi
    dir="$WORK/aur-$name"
    if [ ! -d "$dir/.git" ]; then
        as_builder git clone -q "https://aur.archlinux.org/$name.git" "$dir"
    fi
    (cd "$dir" && as_builder git fetch -q origin && as_builder git checkout -q "$commit")
    msg "building AUR $name@$commit"
    # Upstream sources are fetched over the network; retry transient download failures.
    ok=0
    for attempt in 1 2 3; do
        if (cd "$dir" && as_builder makepkg -s --noconfirm -f --noprogressbar >/dev/null); then ok=1; break; fi
        msg "attempt $attempt for $name failed; retrying"
        rm -rf -- "${dir:?}/src"
        sleep $((attempt * 10))
    done
    [ "$ok" = 1 ] || { echo "AUR package $name failed after 3 attempts" >&2; exit 1; }
done < "$ROOT/scripts/aur-packages.txt"

# 4. Repository database.
msg "creating [$REPO_NAME] repository in $OUT"
rm -f "$OUT/$REPO_NAME".db* "$OUT/$REPO_NAME".files* "$OUT"/*-debug-*.pkg.tar.zst
repo-add -q "$OUT/$REPO_NAME.db.tar.gz" "$OUT"/*.pkg.tar.zst
ls -1 "$OUT"/*.pkg.tar.zst | sed 's|.*/||'
