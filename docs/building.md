# Building eDEX-OS

`scripts/ci-build-iso.sh` is the single entry point, for CI and for humans:

1. initialises the Arch keyring and installs the CachyOS keyring/mirrorlists straight from
   `mirror.cachyos.org` (no keyserver needed), enabling `[cachyos]`;
2. installs archiso and the build tools;
3. runs `scripts/build-packages.sh`: renders the artwork (`scripts/make-artwork.sh`), builds `edex-de` from
   the `desktop/` submodule with its own PKGBUILD, builds every `packages/*` PKGBUILD from the checked-out
   trees, builds the pinned AUR packages (`scripts/aur-packages.txt`) and creates `out/repo/edex-os.db`;
4. generates `iso/pacman.conf` from `iso/pacman.conf.in` with the local repository first;
5. checks that every entry of `iso/packages.x86_64` resolves;
6. stages the generated syslinux splash, GRUB fonts and theme into the profile;
7. runs `mkarchiso` and writes checksums into `out/`.

Run it in a container (`docker run --rm --privileged --device /dev/fuse -v "$PWD:/workspace" -w
/workspace archlinux:latest bash scripts/ci-build-iso.sh`) or as root on an Arch/CachyOS host
(`./buildiso.sh`). Set `SOURCE_DATE_EPOCH` for reproducible labels.

Versions: packages get `pkgver` from `git describe --tags`; the ISO is named `edex-os-x86_64-<date or tag>.iso`.
