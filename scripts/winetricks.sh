#!/usr/bin/env bash
# Helper to run winetricks against a GAMMA/Wine prefix with our built engine.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

WINE_DIR="${WINE_DIR:-$REPO_ROOT/install/wine-cx26-x86_64}"
if [[ ! -x "$WINE_DIR/bin/wine" ]]; then
  # Fallback to local default GAMMA app wrapper location if present
  if [[ -x "$HOME/gamma/wine/bin/wine" ]]; then
    WINE_DIR="$HOME/gamma/wine"
  elif [[ -d "/Applications/S.T.A.L.K.E.R. G.A.M.M.A..app/Contents/SharedSupport/wine" ]]; then
    WINE_DIR="/Applications/S.T.A.L.K.E.R. G.A.M.M.A..app/Contents/SharedSupport/wine"
  fi
fi

WINEPREFIX="${WINEPREFIX:-$HOME/gamma/prefix}"

if ! command -v winetricks >/dev/null 2>&1; then
  echo "Error: winetricks is not installed on your system." >&2
  echo "Install it via: brew install winetricks" >&2
  exit 1
fi

if [[ ! -x "$WINE_DIR/bin/wine" ]]; then
  echo "Error: Wine binary not found at $WINE_DIR/bin/wine" >&2
  echo "Set WINE_DIR to the wine directory." >&2
  exit 1
fi

echo "==> Running winetricks"
echo "  Wine:       $WINE_DIR/bin/wine"
echo "  Wineserver: $WINE_DIR/bin/wineserver"
echo "  Prefix:     $WINEPREFIX"
echo "  Command:    winetricks $*"
echo ""

WINE="$WINE_DIR/bin/wine" \
WINESERVER="$WINE_DIR/bin/wineserver" \
WINEPREFIX="$WINEPREFIX" \
winetricks "$@"
