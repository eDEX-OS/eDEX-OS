#!/usr/bin/env bash
# Static checks: shellcheck for every shell script, yamllint for workflows and Calamares configs,
# nft syntax, and a package-name sanity pass over packages.x86_64.
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT"
fail=0
echo "==> shellcheck"
mapfile -t scripts < <(grep -rlE '^#!/(usr/)?bin/(env )?bash' --exclude-dir=.git --exclude-dir=desktop --exclude-dir=out . | sort)
shellcheck -S warning "${scripts[@]}" || fail=1
echo "==> yamllint"
yamllint -d '{extends: relaxed, rules: {line-length: disable}}' .github/workflows calamares/calamares || fail=1
echo "==> package list"
if grep -nE '^[^#[:space:]]+[[:space:]]' iso/packages.x86_64; then echo "trailing content in packages.x86_64"; fail=1; fi
sort iso/packages.x86_64 | grep -vE '^\s*(#|$)' | uniq -d | grep . && { echo "duplicate packages"; fail=1; } || true
if command -v nft >/dev/null; then tests/privacy/nft-lint.sh || fail=1; else echo "(nft not installed; skipping nft lint)"; fi
[ "$fail" -eq 0 ] && echo "lint OK" || { echo "lint FAILED"; exit 1; }
