The `edex-de` package is built from the `desktop/` submodule with its own PKGBUILD
(`desktop/packaging/aur/PKGBUILD`) through `desktop/scripts/build-pkg.sh`, so the ISO always ships
exactly the pinned submodule commit. See `scripts/build-packages.sh`.
