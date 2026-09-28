#!/usr/bin/env bash
# eDEX-OS install step: runs INSIDE the installed system (chroot) after the bootloader.
# Shared by the Calamares shellprocess@postinstall step and edex-ci-install.
set -euo pipefail

echo "==> enabling CPU-optimised CachyOS repositories"
/usr/bin/edex-enable-cachy-repos || true

echo "==> plymouth theme"
plymouth-set-default-theme edex-os || true

echo "==> default target and runtime state"
systemctl set-default graphical.target
mkdir -p /etc/tor/torrc.d /var/lib/edex-os
chgrp tor /etc/tor/torrc.d 2>/dev/null || true
chmod 750 /etc/tor/torrc.d
echo off > /var/lib/edex-os/tor-mode
systemd-tmpfiles --create edex-os.conf edex-greeter.conf >/dev/null 2>&1 || true

echo "==> greetd: eDEX greeter"
rm -f /etc/systemd/system/display-manager.service
ln -sf /usr/lib/systemd/system/greetd.service /etc/systemd/system/display-manager.service
if [ -f /etc/pam.d/greetd ] && ! grep -q pam_fprintd /etc/pam.d/greetd; then
    sed -i '0,/^auth/s//auth       sufficient   pam_fprintd.so max-tries=3 timeout=30\nauth/' /etc/pam.d/greetd
fi

echo "==> os-release"
if [ -f /usr/lib/os-release-edex ]; then
    install -m644 /usr/lib/os-release-edex /etc/os-release
fi

echo "==> live leftovers"
rm -f /etc/sudoers.d/10-edex-live /etc/polkit-1/rules.d/49-edex-live.rules
rm -rf /home/liveuser
sed -i '/^liveuser:/d' /etc/passwd /etc/shadow 2>/dev/null || true
sed -i 's/,liveuser$//; s/:liveuser,/:/; s/:liveuser$/:/' /etc/group /etc/gshadow 2>/dev/null || true
if [ -f /etc/greetd/config.toml ] && grep -q liveuser /etc/greetd/config.toml; then
    rm -f /etc/greetd/config.toml
fi

echo "==> regenerating initramfs with the final hooks"
mkinitcpio -P || true

echo "==> post-install done"
