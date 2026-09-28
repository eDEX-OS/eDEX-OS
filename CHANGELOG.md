# Changelog

## 1.0.0-rc.1 — 2026-09-28

First release candidate of the rebuilt distribution.

* eDEX-DE 3 (Rust shell on Hyprland) and `edex-greeter` replace the Tauri desktop; the submodule is
  pinned and built into a local `[edex-os]` package repository during the ISO build.
* archiso profile completed: live initramfs (`archiso.conf`, `linux-cachyos.preset`), users, keyring init,
  greetd autologin, Plymouth, GRUB (UEFI) and syslinux (BIOS) menus with eDEX themes.
* Calamares configuration under `/etc/edex-os/calamares` with a working exec sequence (kernel copy,
  stock preset, btrfs subvolumes, LUKS, GRUB with EFI fallback, greetd, live cleanup, CPU-optimised
  CachyOS repositories).
* Privacy stack rewrite: `edex-tor-mode` (off/socks5/transparent, fail-closed, rollback, persisted),
  `edex-tor-bridges`, `edex-tailscale-operator`, `edex-logind-conf`, `edex-enable-cachy-repos`,
  `edex-filter` firewall without ruleset flushes, dnscrypt as the real resolver, tmpfiles/systemd drop-ins
  instead of overwriting package-owned files.
* CI: lint, package build, ISO build in an Arch container, QEMU UEFI/BIOS boot tests asserting
  `EDEX_CI` markers, unattended install test, release publishing, daily eDEX-DE bump PRs.
