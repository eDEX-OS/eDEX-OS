# Testing

| Test | Command | Asserts |
|---|---|---|
| Lint | `scripts/lint.sh` | shellcheck, yamllint (workflows, Calamares), nft syntax of both rulesets, package list hygiene |
| Packages | `scripts/build-packages.sh` (container) | every PKGBUILD builds; `namcap` reports |
| Boot | `scripts/test-iso.sh --mode both` | QEMU UEFI (OVMF) and BIOS boots reach `graphical.target` (`EDEX_CI: boot-ok`), Calamares links (`installer-ok`), and Hyprland reports the `edex-de:canvas` layer (`shell-ok`); markers come from `edex-ci-report.service` when `edex.ci` is on the kernel command line, which the test passes through the serial entries |
| Install | `scripts/test-install.sh` | boots the ISO kernel with `edex.ci=install`; `edex-ci-install` partitions the virtual disk, unsquashes the root, runs the shared `install-steps`, installs GRUB for both firmwares and removes the live packages; the disk then boots in UEFI and BIOS and `edex-ci-installed.service` reports `installed-ok` once greetd is active |
| Privacy | `sudo tests/privacy/tor-mode-test.sh` | on a live system: mode persistence, fail-closed output policy, UDP blocked, TCP redirect rule, rollback on bootstrap timeout, `check.torproject.org` when networked |

Logs land in `out/test/`. In CI the boot and install jobs upload them as artifacts.
