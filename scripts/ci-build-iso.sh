#!/usr/bin/env bash
# ci-build-iso.sh — runs inside archlinux:latest Docker container as root (--privileged)
# Bootstraps CachyOS repos, installs archiso, then builds the eDEX-OS ISO.
set -euo pipefail

echo "==> Initializing pacman keyring..."
# archlinux:latest may have an uninitialized keyring; initialize if needed
[[ -f /etc/pacman.d/gnupg/pubring.gpg ]] || pacman-key --init
pacman-key --populate archlinux

echo "==> Updating system and installing build tools..."
pacman -Syu --noconfirm
pacman -S --needed --noconfirm \
  base-devel git curl \
  archiso squashfs-tools dosfstools mtools libisoburn

echo "==> Importing CachyOS signing key..."
# Try keyserver first, fall back to direct HKP download
pacman-key --recv-keys F3B607488DB35A47 \
  --keyserver hkps://keyserver.ubuntu.com 2>/dev/null \
  || curl -fsSL \
    'https://keyserver.ubuntu.com/pks/lookup?op=get&search=0xF3B607488DB35A47' \
    | pacman-key --add -
pacman-key --lsign-key F3B607488DB35A47

echo "==> Installing CachyOS keyring and mirrorlist..."
pacman -U --noconfirm \
  'https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-keyring-3-1-any.pkg.tar.zst' \
  'https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-mirrorlist-18-1-any.pkg.tar.zst'

echo "==> Refreshing package databases..."
pacman -Sy --noconfirm

echo "==> Building eDEX-OS ISO..."
mkdir -p out
mkarchiso -v -w /tmp/edex-os-work -o out iso/

echo "==> ISO built successfully:"
ls -lh out/*.iso
