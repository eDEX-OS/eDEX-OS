# Installer

`edex-install` runs `calamares -c /etc/edex-os/calamares` through pkexec (the live user is allowed by
polkit). The exec sequence:

`partition → mount → unpackfs → machineid → fstab → locale → keyboard → localecfg → luksbootkeyfile →
luksopenswaphookcfg → shellprocess@kernel → initcpiocfg → initcpio → users → networkcfg → hwclock →
services-systemd → grubcfg → bootloader → shellprocess@postinstall → packages → removeuser → umount`

The post-install script ships in `edex-os-calamares-config`, so `packages` (which removes that package)
must run after it.

* `unpackfs` copies `airootfs.sfs` and the kernel image (`sourcefs: file`).
* `shellprocess@kernel` (`install-steps/20-kernel.sh`, runs un-chrooted with `${ROOT}`) removes the
  archiso initramfs config, restores the stock `linux-cachyos` preset from mkinitcpio's template, drops
  live-only units and copies the initialised pacman keyring.
* `initcpiocfg` adds the `plymouth` hook and strips the archiso hooks; `initcpio` builds the initramfs for
  `linux-cachyos`.
* `users` creates the account (groups incl. `tor` for the control cookie) and sets the root password.
* `services-systemd` enables NetworkManager, greetd, tailscaled, nftables, dnscrypt-proxy.socket,
  edex-tor-mode, edex-tailscale-operator, bluetooth, power-profiles-daemon, fstrim (accounts-daemon is D-Bus-activated on demand).
* `grubcfg`/`bootloader` install GRUB with the eDEX theme, os-prober on, EFI fallback entry.
* `shellprocess@postinstall` (`install-steps/80-postinstall.sh`, chrooted) enables the CPU-optimised
  CachyOS repositories, Plymouth theme, greetd as display manager with fingerprint PAM, os-release, and
  purges live leftovers.
* `packages` removes `edex-os-live`, `edex-os-calamares-config`, `cachyos-calamares`,
  `edex-os-boost-compat` and `mkinitcpio-archiso`; `removeuser` deletes `liveuser`.

`live/usr/bin/edex-ci-install` performs the same steps without Calamares for the CI install test.
