#!/usr/bin/env bash
# Build the ISO on a CachyOS/Arch host (needs root; runs the same steps as CI).
set -euo pipefail
exec sudo "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/scripts/ci-build-iso.sh"
