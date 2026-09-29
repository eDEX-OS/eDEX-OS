# Changelog

## 1.0.0 — 2026-09-29

First stable release: everything in 1.0.0-rc.1, plus

* Installer: post-install now runs before the live-only packages are removed (the script ships in one
  of them), in Calamares and in the CI install test.
* dnscrypt-proxy starts offline: a signed resolver list pinned to a dnscrypt-resolvers commit seeds its
  cache, so DNS works when the list cannot be downloaded (refresh with
  `scripts/update-dnscrypt-resolvers.sh`).
* `edex-os-boost-compat` supplies the Boost 1.91 libraries `cachyos-calamares` is linked against (live
  medium only).
* The ISO fits GitHub's 2 GiB release-asset limit (xz-compressed root image).
* CI fixes: the ISO build installs git before using it; the nft lint runs with `CAP_NET_ADMIN`.

Tested: live boot (UEFI and BIOS) and unattended install to disk booting both ways in QEMU. Not yet
tested on real hardware: GPU drivers, Tor/Tailscale end to end, fingerprint login.

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
