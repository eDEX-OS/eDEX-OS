# eDEX-OS

A privacy-focused, performance-tuned Linux distribution based on [CachyOS](https://cachyos.org/) (Arch), featuring the [eDEX-DE](https://github.com/eDEX-OS/eDEX-DE) sci-fi Hyprland desktop environment.

## Features

- **linux-cachyos** kernel with BORE/EEVDF scheduler and x86-64-v3/v4 CPU-optimized packages
- **eDEX-DE** — Tauri v2 + Hyprland sci-fi desktop with integrated Privacy Control Panel (`Ctrl+Shift+P`)
- **Tor** — dual-mode: SOCKS5 proxy or full transparent proxy (off by default, switchable from DE)
- **Tailscale** — mesh VPN with peer list, exit node selection, and login from DE
- **WireGuard & OpenVPN** — import and manage VPN profiles via NetworkManager from DE
- **dnscrypt-proxy** — DNS-over-HTTPS with DNSSEC enabled by default
- **nftables** — hardened deny-inbound firewall baseline
- **MAC address randomization** — per-connection via NetworkManager
- **Calamares** — GUI installer (UEFI + BIOS, btrfs/ext4/xfs/f2fs, LUKS encryption)
- **yay** and **paru** — both AUR helpers pre-installed

## Repository Layout

```
eDEX-OS/
├── desktop/                    # git submodule → eDEX-OS/eDEX-DE
├── iso/                        # archiso profile
│   ├── profiledef.sh
│   ├── packages.x86_64
│   ├── pacman.conf             # CachyOS + Arch repos
│   ├── grub/grub.cfg
│   ├── efiboot/                # systemd-boot entries
│   └── airootfs/               # live environment overlay
├── calamares/                  # Calamares installer config
│   └── etc/calamares/
│       ├── settings.conf
│       ├── branding/edex-os/   # logo, slideshow, colors
│       └── modules/            # partition, users, services, etc.
├── packages/                   # Custom PKGBUILDs
│   ├── edex-os-settings/       # privacy configs + edex-tor-mode script
│   ├── edex-os-branding/       # Plymouth, GRUB themes, wallpapers
│   └── edex-os-calamares-config/
├── system-settings/            # Source files for edex-os-settings package
│   ├── etc/sysctl.d/           # kernel privacy hardening
│   ├── etc/nftables.conf       # baseline firewall
│   ├── etc/NetworkManager/     # MAC randomization
│   ├── etc/dnscrypt-proxy/     # DoH config
│   ├── etc/tor/                # torrc
│   ├── etc/polkit-1/rules.d/   # pkexec rules for tor-mode + NM
│   └── usr/bin/edex-tor-mode   # tor mode-switch script
├── branding/                   # Source for edex-os-branding package
│   ├── plymouth/edex-os/       # boot splash theme
│   ├── grub/edex-os/           # GRUB theme
│   └── wallpapers/
├── buildiso.sh                 # ISO build wrapper (calls mkarchiso)
├── scripts/
│   ├── build-de.sh             # builds eDEX-DE binary from submodule
│   └── test-iso.sh             # QEMU smoke test
└── .github/workflows/
    ├── build-de.yml            # Tauri build on GitHub-hosted runner
    ├── build-iso.yml           # ISO build on self-hosted Arch runner
    ├── test-iso.yml            # QEMU boot test
    └── pkgbuild.yml            # PKGBUILD validation
```

## Building

### Requirements

- Arch Linux or CachyOS host (for ISO build)
- `archiso` package
- `rust`, `nodejs`, `npm` (for eDEX-DE)
- `webkit2gtk-4.1`, `gtk3`, `libayatana-appindicator`, `patchelf` (Tauri deps)

```bash
# Install build deps (Arch/CachyOS)
sudo pacman -S --needed archiso rust nodejs npm webkit2gtk-4.1 gtk3 libayatana-appindicator patchelf
```

### Clone

```bash
git clone --recurse-submodules https://github.com/eDEX-OS/eDEX-OS.git
cd eDEX-OS
```

### Build eDEX-DE first

```bash
bash scripts/build-de.sh
```

### Build ISO

```bash
bash buildiso.sh
# ISO output: out/eDEX-OS-x86_64-YYYY.MM.DD.iso
```

### Test in QEMU

```bash
bash scripts/test-iso.sh
```

## CI/CD

ISO builds require a **self-hosted GitHub Actions runner** on an Arch/CachyOS system labeled `arch-linux`.

```bash
# On your build server, install required packages:
sudo pacman -S --needed \
  archiso calamares rust nodejs npm git base-devel \
  webkit2gtk-4.1 gtk3 libayatana-appindicator patchelf \
  qemu-system-x86 ovmf namcap
```

**Repository secrets required for release signing:**
- `GPG_PRIVATE_KEY` — ASCII-armored GPG private key
- `GPG_PASSPHRASE` — passphrase for the key

## Privacy Control Panel

Press `Ctrl+Shift+P` in eDEX-DE to open the Privacy Control Panel with three tabs:

| Tab | Features |
|-----|----------|
| **TOR** | Mode selector (Off/SOCKS5/Transparent), bridge request & management |
| **TAILSCALE** | Login, status, peer list, exit node selection |
| **VPN** | WireGuard/OpenVPN connect/disconnect, WireGuard config import |

## Tor Modes

| Mode | Description |
|------|-------------|
| `off` | Tor not running |
| `socks5` | Tor SOCKS5 proxy on `127.0.0.1:9050` |
| `transparent` | All TCP/DNS redirected through Tor via nftables |

Mode switching is done via `pkexec /usr/bin/edex-tor-mode <mode>` — no password prompt for `wheel` group members.

## License

GPL-3.0 — see [LICENSE](LICENSE)
