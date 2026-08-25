#!/usr/bin/env bash
# Integrate DXMT and GPTK4 (D3DMetal) into the Wine installation tree.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

WINE_INSTALL="${1:-$REPO_ROOT/install/wine-cx26-x86_64}"
DXMT_SRC="${DXMT_SRC:-$REPO_ROOT/sources/dxmt}"
[[ -d "$DXMT_SRC" ]] || DXMT_SRC="$REPO_ROOT/build/dxmt"
GPTK_SRC="${GPTK_SRC:-$REPO_ROOT/sources/gptk4.0b1/d3dmetal}"

[[ -d "$WINE_INSTALL" ]] || {
  echo "Error: Wine install directory not found: $WINE_INSTALL" >&2
  exit 1
}

echo "==> Integrating Renderers into $WINE_INSTALL"

# 1. Stage DXMT in lib/dxmt (switchable alternative backend)
if [[ -d "$DXMT_SRC" ]]; then
  echo "--> Staging DXMT (Metal D3D11/DXGI/D3D10 in lib/dxmt)..."
  mkdir -p "$WINE_INSTALL/lib/dxmt/x86_64-windows" \
           "$WINE_INSTALL/lib/dxmt/i386-windows" \
           "$WINE_INSTALL/lib/dxmt/x86_64-unix"

  if [[ -f "$DXMT_SRC/x86_64-unix/winemetal.so" ]]; then
    cp "$DXMT_SRC/x86_64-unix/winemetal.so" "$WINE_INSTALL/lib/wine/x86_64-unix/"
    cp "$DXMT_SRC/x86_64-unix/winemetal.so" "$WINE_INSTALL/lib/dxmt/x86_64-unix/"
    echo "  Installed winemetal.so"
  fi

  if [[ -d "$DXMT_SRC/x86_64-windows" ]]; then
    cp -R "$DXMT_SRC/x86_64-windows/"* "$WINE_INSTALL/lib/dxmt/x86_64-windows/"
    echo "  Staged DXMT x86_64 DLLs in lib/dxmt/x86_64-windows/"
  fi

  if [[ -d "$DXMT_SRC/i386-windows" ]]; then
    cp -R "$DXMT_SRC/i386-windows/"* "$WINE_INSTALL/lib/dxmt/i386-windows/"
    if [[ -d "$WINE_INSTALL/lib/wine/i386-windows" ]]; then
      cp -R "$DXMT_SRC/i386-windows/"* "$WINE_INSTALL/lib/wine/i386-windows/"
    fi
    echo "  Staged DXMT i386 DLLs"
  fi
fi

# 2. Install GPTK 4.0b1 (D3DMetal) as the ACTIVE DEFAULT in lib/wine
if [[ -d "$GPTK_SRC" ]]; then
  echo "--> Installing GPTK 4.0b1 (D3DMetal) as active default..."
  mkdir -p "$WINE_INSTALL/lib/external"
  cp -R "$GPTK_SRC/external/"* "$WINE_INSTALL/lib/external/"

  # Install D3DMetal PE DLLs as default into lib/wine/x86_64-windows
  if [[ -d "$GPTK_SRC/wine/x86_64-windows" ]]; then
    for dll in "$GPTK_SRC/wine/x86_64-windows"/*.dll; do
      cp "$dll" "$WINE_INSTALL/lib/wine/x86_64-windows/"
      echo "  Installed $(basename "$dll") (D3DMetal default)"
    done
  fi

  # Install D3DMetal Unix bridge .so symlinks as default into lib/wine/x86_64-unix
  if [[ -d "$GPTK_SRC/wine/x86_64-unix" ]]; then
    for so in "$GPTK_SRC/wine/x86_64-unix"/*.so; do
      cp -P "$so" "$WINE_INSTALL/lib/wine/x86_64-unix/"
      echo "  Installed $(basename "$so") (D3DMetal bridge default)"
    done
  fi

  # Also preserve clean copy in lib/d3dmetal
  mkdir -p "$WINE_INSTALL/lib/d3dmetal/x86_64-windows" "$WINE_INSTALL/lib/d3dmetal/x86_64-unix"
  cp -R "$GPTK_SRC/wine/x86_64-windows/"* "$WINE_INSTALL/lib/d3dmetal/x86_64-windows/"
  cp -RP "$GPTK_SRC/wine/x86_64-unix/"* "$WINE_INSTALL/lib/d3dmetal/x86_64-unix/"

  # Compatibility symlinks for Sikarugir / CrossOver legacy paths
  ln -sfn ../external "$WINE_INSTALL/lib/d3dmetal/external"
  ln -sfn d3dmetal "$WINE_INSTALL/lib/apple_gptk"
  mkdir -p "$WINE_INSTALL/lib64/apple_gptk"
  ln -sfn ../../lib/d3dmetal "$WINE_INSTALL/lib64/apple_gptk/wine"
  ln -sfn ../../lib/external "$WINE_INSTALL/lib64/apple_gptk/external"
fi

echo "==> Renderers successfully integrated."
