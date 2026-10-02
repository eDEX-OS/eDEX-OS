# Architecture

```
firmware ─ GRUB (UEFI) / syslinux (BIOS) ─ linux-cachyos + archiso initramfs (plymouth) ─ airootfs.sfs
   systemd: NetworkManager · nftables (edex-filter) · dnscrypt-proxy.socket · tailscaled · tor (on demand)
            edex-tor-mode.service (restores the persisted mode) · edex-tailscale-operator · greetd
   greetd ── live: initial_session edex-session (liveuser)      installed: edex-greeter-session (cage + edex-greeter, text fallback)
   edex-session ── start-hyprland ── ~/.config/hypr/hyprland.lua ── require("edex") (/usr/share/edex-de/hypr/edex)
   Hyprland ── edex-de.service (user) ── layer-shell shell; apps tile into the terminal slot
```

Packages and where their files go:

| Package | Files |
|---|---|
| edex-de | `/usr/bin/{edex-de,edex-greeter,edex-session}`, `/usr/share/edex-de/{hypr,themes,backgrounds}`, user unit, skel Lua, greeter config |
| edex-os-settings | `/etc/edex-os/{torrc,nftables.conf,dnscrypt-proxy.toml,resolv.conf}`, service drop-ins, NM/sysctl/tmpfiles/polkit, `/usr/bin/edex-*` helpers, `edex-tor-mode.service`, `edex-tailscale-operator.service`, `/usr/share/edex-os/tor/*` |
| edex-os-branding | Plymouth theme, GRUB theme + fonts, wallpapers, icons, `/etc/default/grub.d/90-edex-os.cfg`, `/usr/lib/os-release-edex` |
| edex-os-calamares-config | `/etc/edex-os/calamares`, `/usr/bin/edex-install`, desktop entry, polkit rule, `/usr/share/edex-os/install-steps` |
| edex-os-greetd-config | `/etc/edex-os/greetd.toml`, greetd drop-in, PAM reference |
| edex-os-live | live greetd autologin, sudoers, polkit, logind/journald drop-ins, `edex-setup-live`, CI units |

The live ISO's `airootfs/` only carries what archiso itself needs (users, keyring init, initramfs config,
unit symlinks); everything else is a package so the installed system gets identical files.
