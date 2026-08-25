#!/usr/bin/env bash
# Recreate ~/Library/Application Support/gamma-test-prefix from scratch with full winetricks, drives, and settings.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/setup-test-prefix.sh" --clean "$@"
