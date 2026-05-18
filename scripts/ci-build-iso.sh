#!/usr/bin/env bash
# ci-build-iso.sh — runs inside archlinux:latest Docker container as root (--privileged)
# Bootstraps CachyOS repos, installs archiso, then builds the eDEX-OS ISO.
set -euo pipefail

echo "==> Disabling GPG signature verification for CI (Docker has no entropy source)..."
# pacman-key --init requires entropy unavailable in Docker CI.
# SigLevel=Never lets us install packages without a populated keyring.
sed -i 's/^SigLevel\s*=.*/SigLevel = Never/' /etc/pacman.conf
sed -i 's/^LocalFileSigLevel\s*=.*/LocalFileSigLevel = Never/' /etc/pacman.conf

echo "==> Creating CachyOS mirrorlist files..."
mkdir -p /etc/pacman.d
# Main CachyOS mirror
cat > /etc/pacman.d/cachyos-mirrorlist << 'EOF'
Server = https://mirror.cachyos.org/repo/$arch/$repo
EOF
# v3/v4 mirrors (for AVX2/AVX512 repos — point to main mirror as fallback)
cat > /etc/pacman.d/cachyos-v3-mirrorlist << 'EOF'
Server = https://mirror.cachyos.org/repo/$arch/$repo
EOF
cat > /etc/pacman.d/cachyos-v4-mirrorlist << 'EOF'
Server = https://mirror.cachyos.org/repo/$arch/$repo
EOF

echo "==> Adding CachyOS repositories to host pacman.conf..."
cat >> /etc/pacman.conf << 'EOF'

[cachyos-v3]
Include = /etc/pacman.d/cachyos-v3-mirrorlist

[cachyos]
Include = /etc/pacman.d/cachyos-mirrorlist
EOF

echo "==> Updating system and installing build tools..."
pacman -Sy --noconfirm
pacman -S --needed --noconfirm \
  base-devel git curl \
  archiso squashfs-tools dosfstools mtools libisoburn \
  grub syslinux

echo "==> Patching ISO profile pacman.conf for CI (disable SigLevel)..."
sed -i 's/^SigLevel\s*=.*/SigLevel = Never/' /workspace/iso/pacman.conf
sed -i 's/^LocalFileSigLevel\s*=.*/LocalFileSigLevel = Never/' /workspace/iso/pacman.conf

echo "==> Copying mirrorlist files where mkarchiso can find them..."
# mkarchiso uses /etc/pacman.d/ from the host when resolving Include directives
# These are already created above — nothing more needed.

echo "==> Building eDEX-OS ISO..."
mkdir -p /workspace/out
mkarchiso -v -w /tmp/edex-os-work -o /workspace/out /workspace/iso/

echo "==> ISO built successfully:"
ls -lh /workspace/out/*.iso
