# eDEX-OS packages

Every package is built from **this checkout** by `scripts/build-packages.sh` (run inside an Arch
container with the CachyOS repo enabled) and published to a local `[edex-os]` repository that the ISO
build consumes. No package fetches sources from the network:

| Package | Source tree | Notes |
|---|---|---|
| `edex-de` | `desktop/` (submodule) | built with the submodule's own `packaging/aur/PKGBUILD` |
| `edex-os-settings` | `system-settings/` | privacy stack: Tor modes, nftables, dnscrypt, NM, helpers, polkit |
| `edex-os-branding` | `branding/` + `branding/generated/` | Plymouth, GRUB theme, wallpapers, icons (`scripts/make-artwork.sh` first) |
| `edex-os-calamares-config` | `calamares/` | installer config under `/etc/edex-os/calamares`, `edex-install` |
| `edex-os-greetd-config` | `packaging/greetd/` | greetd drop-in for the eDEX greeter, PAM fingerprint line |
| `edex-os-live` | `live/` | live-ISO-only bits, removed by the installer |
| AUR: `yay-bin`, `paru-bin`, `lyrebird`, `snowflake-pt-client` | `scripts/aur-packages.txt` | pinned commits |

`pkgver` is injected by the build script from `git describe`; the PKGBUILDs carry a placeholder.
