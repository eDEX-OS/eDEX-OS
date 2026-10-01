# Changelog

## 1.3.0 — 2026-10-01

Ships eDEX-DE 3.2.0.

* **Software:** Flatpak with Flathub configured system-wide, GNOME Software (Flatpak and pacman
  packages through PackageKit), KDE Discover (Flatpak), Homebrew (`brew` bootstraps itself into
  `/home/linuxbrew/.linuxbrew` on first run; shells pick it up afterwards), Brave Origin as the
  default browser.
* **paru works:** the AUR `paru-bin` build was linked against an older libalpm and failed to start;
  `yay` and `paru` now come from the CachyOS repository, built against the shipped pacman.
* **Themed apps:** Qt 6 (qt6ct), GTK 3/4 (adw-gtk3, libadwaita colours) and KDE/Kirigami apps use
  the eDEX colours, font and Papirus-Dark icons.
* **Privacy panel:** Tor and Tailscale show their real state in the live session; WireGuard tunnels
  can be created and managed.
* eDEX Settings and eDEX Privacy appear in app search.
* SUPER+SHIFT+F hides the side panels for full-width apps.
* Smaller live initramfs (no `kms` hook: GPU drivers load from the root image) and no Qt 5 Wayland
  or Breeze icons, keeping the ISO under GitHub's 2 GiB limit.
* Local package builds no longer reuse stale versions.

## 1.2.0 — 2026-09-30

Ships eDEX-DE 3.1.0.

* **Keyboard and mouse work in the live session and on installed systems** (the shell and the
  greeter never picked up the input devices); the terminal has focus from login.
* Tapping the Windows key opens the launcher; SUPER+Return shows and focuses the terminal.
* Workspace buttons, Log out, launching apps and screen blanking work with Hyprland 0.56.
* The on-screen keyboard is off by default (a setting for touchscreens).
* Much lower idle CPU, especially without a GPU driver (VMs).
* Releases can be started from the Actions tab (Build ISO with `release_tag`); publishing now waits
  for the boot and install tests. Release notes take only the matching changelog section.

Tested in QEMU: live boot (UEFI and BIOS), typing and launcher in the live session, unattended
install booting both ways.

## 1.1.0 — 2026-09-29

Same build as 1.0.0 (CI fixes for the release: git in the build container, `CAP_NET_ADMIN` for the
nft lint, `bsdtar` for the boot test, xz-compressed root image to fit GitHub's 2 GiB asset limit).

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
