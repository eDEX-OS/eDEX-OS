#!/usr/bin/env bash
# eDEX-OS install step: make the copied live tree bootable as a normal system.
# Runs on the LIVE system (not chrooted) with the target root as $1, after unpackfs and before
# Calamares' initcpio module. Shared by the Calamares shellprocess@kernel step and edex-ci-install.
set -euo pipefail
ROOT=${1:?target root}
[ -d "$ROOT/etc" ] || { echo "not a root tree: $ROOT" >&2; exit 1; }

echo "==> kernel images in $ROOT/boot:"; ls "$ROOT/boot"/vmlinuz-* 2>/dev/null || echo "    (none yet)"
[ -f "$ROOT/boot/vmlinuz-linux-cachyos" ] || cp /run/archiso/bootmnt/arch/boot/x86_64/vmlinuz-linux-cachyos "$ROOT/boot/"

# Live-only initramfs configuration goes away; the stock linux-cachyos preset comes back.
rm -f "$ROOT/etc/mkinitcpio.conf.d/archiso.conf"
sed 's|%PKGBASE%|linux-cachyos|g' "$ROOT/usr/share/mkinitcpio/hook.preset" > "$ROOT/etc/mkinitcpio.d/linux-cachyos.preset"
rm -f "$ROOT/boot/initramfs-linux-cachyos.img"
# Nothing from the live boot must leak into the installed system.
rm -f "$ROOT/etc/systemd/system/etc-pacman.d-gnupg.mount" "$ROOT/etc/systemd/system/multi-user.target.wants/pacman-init.service" "$ROOT/etc/systemd/system/pacman-init.service"
rm -f "$ROOT/etc/systemd/system/multi-user.target.wants/edex-setup-live.service" "$ROOT/etc/systemd/system/graphical.target.wants/edex-ci-report.service" "$ROOT/etc/systemd/system/graphical.target.wants/edex-ci-install.service"
rm -f "$ROOT/etc/pacman.d/hooks/uncomment-mirrors.hook" "$ROOT/etc/pacman.d/hooks/zzzz99-remove-custom-hooks-from-airootfs.hook"
rm -f "$ROOT/etc/motd" "$ROOT/etc/issue"
rm -f "$ROOT/etc/systemd/system/greetd.service.d/live.conf"
rmdir "$ROOT/etc/systemd/system/greetd.service.d" 2>/dev/null || true
rm -f "$ROOT/etc/ssh/sshd_config.d/10-edex-live.conf"
# Persistent journal on installed systems.
rm -f "$ROOT/etc/systemd/journald.conf.d/50-edex-live.conf"
rm -f "$ROOT/etc/systemd/logind.conf.d/50-edex-live.conf"
# The keyring initialised on the live system is copied over so pacman works right away.
if [ -d /etc/pacman.d/gnupg ] && [ ! -e "$ROOT/etc/pacman.d/gnupg/pubring.kbx" ]; then
    rm -rf "$ROOT/etc/pacman.d/gnupg"
    cp -a /etc/pacman.d/gnupg "$ROOT/etc/pacman.d/gnupg"
fi
echo "==> kernel step done"
