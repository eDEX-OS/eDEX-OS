# eDEX-OS

[![Build ISO](https://github.com/eDEX-OS/eDEX-OS/actions/workflows/build-iso.yml/badge.svg)](https://github.com/eDEX-OS/eDEX-OS/actions/workflows/build-iso.yml)
[![Lint](https://github.com/eDEX-OS/eDEX-OS/actions/workflows/lint.yml/badge.svg)](https://github.com/eDEX-OS/eDEX-OS/actions/workflows/lint.yml)

A privacy-focused, performance-tuned Linux distribution based on [CachyOS](https://cachyos.org/) (Arch)
whose desktop is [eDEX-DE](https://github.com/eDEX-OS/eDEX-DE): a Rust + wgpu sci-fi shell drawn on
Hyprland, with a matching greetd login screen.

## What is on the ISO

| Area | What you get |
|---|---|
| Kernel & packages | `linux-cachyos`; the installer enables the x86-64-v3/v4 CachyOS repositories your CPU supports |
| Desktop | Hyprland 0.56 + eDEX-DE 3: terminal, file browser, dashboard, on-screen keyboard, launcher, 14-category settings, privacy panel, notifications, power menu, `edex-greeter` under `cage` |
| Tor | `edex-tor-mode off / socks5 / transparent`: transparent mode redirects all TCP and DNS through Tor with a **fail-closed** nftables policy (LAN, DHCP and Tailscale excepted; `--strict` blocks Tailscale too) and rolls back if Tor cannot bootstrap; obfs4 (lyrebird) and Snowflake bridges |
| Tailscale | pre-installed, your user is made the operator, exit nodes / LAN access / advertising from the privacy panel |
| VPN | WireGuard and OpenVPN through NetworkManager |
| DNS | dnscrypt-proxy (DNSSEC, no-log resolvers) is the system resolver; NetworkManager never rewrites `resolv.conf` |
| Firewall | nftables `edex-filter`: inbound denied, Tailscale allowed, forwarding only for Tailscale exit-node use |
| Privacy defaults | MAC randomisation, RFC 4941 IPv6 temporary addresses, no connectivity probes, kernel hardening sysctls |
| Installer | Calamares (CachyOS build) with an eDEX-OS configuration: btrfs subvolumes, LUKS, GRUB (UEFI + BIOS), Plymouth, greetd, live bits removed |
| Boot | GRUB (UEFI) and syslinux (BIOS) with eDEX themes, Plymouth splash, copy-to-RAM / safe-graphics / serial entries |
| Extras | `yay`, `paru`, kitty, fish, nemo, pipewire, bluetooth, fprintd, power-profiles-daemon |

Live medium: user `liveuser` (no password, passwordless sudo), root password `edex`. The desktop starts
automatically; press the **INSTALL** button in the top bar, run `edex-install`, or pick "Install eDEX-OS"
from the launcher.

## Build

Everything is built from this checkout inside an `archlinux:latest` container: the packages (including
eDEX-DE from the `desktop/` submodule and pinned AUR packages) go into a local `[edex-os]` repository,
then `mkarchiso` builds the ISO.

```bash
git clone --recurse-submodules https://github.com/eDEX-OS/eDEX-OS.git && cd eDEX-OS
docker run --rm --privileged --device /dev/fuse -v "$PWD:/workspace" -w /workspace archlinux:latest \
    bash scripts/ci-build-iso.sh
ls out/            # edex-os-*.iso + checksums, out/repo/ with the packages
```

On a CachyOS/Arch host `./buildiso.sh` runs the same script with sudo. Needs about 12 GB of disk and
network access to the Arch, CachyOS and AUR mirrors.

## Test

```bash
scripts/lint.sh                     # shellcheck, yamllint, nft syntax, package list sanity
scripts/test-iso.sh --mode both     # QEMU UEFI + BIOS boot: EDEX_CI: boot-ok / installer-ok / shell-ok
scripts/test-install.sh             # unattended install to a virtual disk, then boot it UEFI + BIOS
sudo tests/privacy/tor-mode-test.sh # on a live system: fail-closed policy, rollback, Tor exit check
```

CI runs all of these on every push (`build-iso.yml`), builds the packages on package changes
(`packages.yml`), and publishes tagged builds with checksums once the boot and install tests pass. `bump-desktop.yml` opens a
pull request when eDEX-DE has a new release tag.

## Repository layout

```
desktop/                 git submodule → eDEX-OS/eDEX-DE (built into the edex-de package)
iso/                     archiso profile: profiledef.sh, packages.x86_64, pacman.conf.in, airootfs/, grub/, syslinux/
packages/                PKGBUILDs built from this tree (see packages/README.md)
system-settings/         edex-os-settings: /etc/edex-os/{torrc,nftables.conf,dnscrypt-proxy.toml}, helpers, units, polkit
live/                    edex-os-live: live autologin, live user setup, CI hooks
calamares/               edex-os-calamares-config: /etc/edex-os/calamares, edex-install, install-steps/
packaging/greetd/        edex-os-greetd-config
branding/                src/*.svg → generated artwork (scripts/make-artwork.sh); Plymouth + GRUB themes
scripts/                 ci-build-iso.sh, build-packages.sh, make-artwork.sh, test-iso.sh, test-install.sh, lint.sh
tests/privacy/           nft lint and the live Tor-mode test
docs/                    building, testing, architecture, installer, privacy
```

## Privacy semantics

* **Tor off** (default): nothing is routed through Tor; `tor.service` is stopped.
* **socks5**: Tor listens on `127.0.0.1:9050`; only applications configured to use it are anonymised.
* **transparent**: `edex-tor-mode transparent` writes `/etc/tor/torrc.d/50-transparent.conf`, loads the
  `inet edex-tor` table (TCP → TransPort 9040, DNS → DNSPort 5353, everything else dropped), waits for Tor
  to bootstrap and rolls back to socks5 on timeout. The mode persists across reboots (`edex-tor-mode.service`
  loads the drop policy *before* Tor starts, so there is no fail-open window). Tailscale keeps working unless
  `--strict` is used; LAN and DHCP are always allowed.
* Tailscale as an exit node forwards only through `tailscale0`; the baseline firewall never forwards
  anything else.
* DNS always goes to dnscrypt-proxy (or Tor's DNSPort in transparent mode); `/etc/resolv.conf` is a
  symlink installed by tmpfiles and NetworkManager runs with `dns=none`.

## Known limitations

* No Secure Boot (shim/MOK) support; disable Secure Boot or enrol your own keys.
* NVIDIA: install `nvidia-open-dkms` after installation and add `nvidia_drm.modeset=1`; the live medium
  uses the open-source stack (`nomodeset` entry available).
* The installer is the CachyOS Calamares build. It is currently linked against boost 1.91 while Arch ships a
  newer boost, so the live medium carries `edex-os-boost-compat` (the Boost 1.91 runtime from the Arch archive,
  checksum-pinned, in a private library directory used only by `edex-install`; removed on install). Drop it
  once CachyOS rebuilds Calamares; the boot test's `installer-ok` marker checks that the installer links.
* Tor transparent mode + Tailscale: Tailscale traffic bypasses Tor by design (WireGuard cannot go through
  Tor); use `--strict` if that matters.
* ARM images and X11 sessions are out of scope.

## License

GPL-3.0. eDEX-OS is not affiliated with CachyOS or Arch Linux.
