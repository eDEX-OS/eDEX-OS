# Contributing to eDEX-OS

* Package sources live in this repository (`system-settings/`, `live/`, `calamares/`, `branding/`,
  `packaging/greetd/`); PKGBUILDs under `packages/` only install those trees. Change the tree, not the
  ISO's `airootfs/`, unless the file is genuinely live-medium-only configuration for archiso itself.
* Never overwrite files owned by upstream packages: use `/etc/edex-os/*` plus systemd drop-ins, tmpfiles
  and polkit rules (see `system-settings/`).
* `scripts/lint.sh` must pass; `tests/privacy/nft-lint.sh` runs in it when `nft` is installed.
* Package names in `iso/packages.x86_64` must exist in Arch, CachyOS or `[edex-os]`;
  `scripts/ci-build-iso.sh` fails otherwise.
* Anything that changes the install sequence must keep `calamares/install-steps/*.sh` and
  `live/usr/bin/edex-ci-install` in sync, because the CI install test runs the scripted twin of the
  Calamares sequence.
* Desktop changes go to [eDEX-DE](https://github.com/eDEX-OS/eDEX-DE); bump `desktop/` here afterwards
  (`bump-desktop.yml` does it for tagged releases).

## Releasing

1. Update `CHANGELOG.md`.
2. Tag `vX.Y.Z` (pre-releases `vX.Y.Z-rc.N`) and push; `build-iso.yml` builds and tests the ISO and
   `release.yml` publishes it with checksums (and a GPG signature when `GPG_PRIVATE_KEY` is set).
