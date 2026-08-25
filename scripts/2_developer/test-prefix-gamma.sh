#!/usr/bin/env bash
# End-to-end sandbox prefix verification script for GAMMA / xray-monolith.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

WINE_DIR="${WINE_DIR:-$REPO_ROOT/install/wine-cx26-x86_64}"
TEST_PREFIX="${TEST_PREFIX:-/tmp/test-gamma-prefix}"
GAMMA_ROOT="${GAMMA_ROOT:-$HOME/gamma}"

[[ -x "$WINE_DIR/bin/wine" ]] || {
  echo "Error: Wine binary not found at $WINE_DIR/bin/wine" >&2
  exit 1
}

echo "=========================================================="
echo "GAMMA Engine Sandbox Verification Test"
echo "  Wine:        $WINE_DIR/bin/wine"
echo "  Wineserver:  $WINE_DIR/bin/wineserver"
echo "  Test Prefix: $TEST_PREFIX"
echo "  GAMMA Root:  $GAMMA_ROOT"
echo "=========================================================="

# 1. Bootstrap clean prefix
echo "==> Step 1: Bootstrapping clean Wine prefix..."
WINEPREFIX="$TEST_PREFIX" arch -x86_64 "$WINE_DIR/bin/wineserver" -k 2>/dev/null || true
rm -rf "$TEST_PREFIX"
mkdir -p "$TEST_PREFIX"
WINEPREFIX="$TEST_PREFIX" arch -x86_64 "$WINE_DIR/bin/wine" wineboot -u
WINEPREFIX="$TEST_PREFIX" arch -x86_64 "$WINE_DIR/bin/wineserver" -w
echo "  Prefix successfully bootstrapped."

# 2. Configure drive mappings
echo "==> Step 2: Setting up drive mappings..."
mkdir -p "$TEST_PREFIX/dosdevices"
ln -sfn "/" "$TEST_PREFIX/dosdevices/z:"
if [[ -d "$GAMMA_ROOT" ]]; then
  ln -sfn "$GAMMA_ROOT" "$TEST_PREFIX/dosdevices/g:"
  echo "  Mapped G: -> $GAMMA_ROOT"
fi

# 3. Configure Mac Driver & Registry overrides
echo "==> Step 3: Setting registry overrides..."
WINEPREFIX="$TEST_PREFIX" arch -x86_64 "$WINE_DIR/bin/wine" reg add "HKEY_CURRENT_USER\Software\Wine\Drivers" /v Graphics /t REG_SZ /d mac /f
WINEPREFIX="$TEST_PREFIX" arch -x86_64 "$WINE_DIR/bin/wine" reg add "HKEY_CURRENT_USER\Software\Wine\DllOverrides" /v d3d11 /t REG_SZ /d builtin /f
WINEPREFIX="$TEST_PREFIX" arch -x86_64 "$WINE_DIR/bin/wine" reg add "HKEY_CURRENT_USER\Software\Wine\DllOverrides" /v dxgi /t REG_SZ /d builtin /f
WINEPREFIX="$TEST_PREFIX" arch -x86_64 "$WINE_DIR/bin/wine" reg add "HKEY_CURRENT_USER\Software\Wine\DllOverrides" /v d3d12 /t REG_SZ /d builtin /f
WINEPREFIX="$TEST_PREFIX" arch -x86_64 "$WINE_DIR/bin/wine" reg add "HKEY_CURRENT_USER\Software\Wine\DllOverrides" /v "*d3dcompiler_43" /t REG_SZ /d "native,builtin" /f
WINEPREFIX="$TEST_PREFIX" arch -x86_64 "$WINE_DIR/bin/wine" reg add "HKEY_CURRENT_USER\Software\Wine\DllOverrides" /v "*d3dcompiler_47" /t REG_SZ /d "native,builtin" /f
WINEPREFIX="$TEST_PREFIX" arch -x86_64 "$WINE_DIR/bin/wine" reg add "HKEY_CURRENT_USER\Software\Wine\DllOverrides" /v "*d3dx9_43" /t REG_SZ /d "native,builtin" /f
WINEPREFIX="$TEST_PREFIX" arch -x86_64 "$WINE_DIR/bin/wine" reg add "HKEY_CURRENT_USER\Software\Wine\DllOverrides" /v "*d3dx10_43" /t REG_SZ /d "native,builtin" /f
WINEPREFIX="$TEST_PREFIX" arch -x86_64 "$WINE_DIR/bin/wine" reg add "HKEY_CURRENT_USER\Software\Wine\DllOverrides" /v "*d3dx11_43" /t REG_SZ /d "native,builtin" /f
WINEPREFIX="$TEST_PREFIX" arch -x86_64 "$WINE_DIR/bin/wine" reg add "HKEY_CURRENT_USER\Software\Wine\DllOverrides" /v "*xinput1_3" /t REG_SZ /d "native,builtin" /f
WINEPREFIX="$TEST_PREFIX" arch -x86_64 "$WINE_DIR/bin/wine" reg add "HKEY_CURRENT_USER\Software\Wine\DllOverrides" /v "*msvcp140" /t REG_SZ /d "native,builtin" /f
WINEPREFIX="$TEST_PREFIX" arch -x86_64 "$WINE_DIR/bin/wine" reg add "HKEY_CURRENT_USER\Software\Wine\DllOverrides" /v "*msvcp140_1" /t REG_SZ /d "native,builtin" /f
WINEPREFIX="$TEST_PREFIX" arch -x86_64 "$WINE_DIR/bin/wine" reg add "HKEY_CURRENT_USER\Software\Wine\DllOverrides" /v "*msvcp140_2" /t REG_SZ /d "native,builtin" /f
WINEPREFIX="$TEST_PREFIX" arch -x86_64 "$WINE_DIR/bin/wine" reg add "HKEY_CURRENT_USER\Software\Wine\DllOverrides" /v "*vcruntime140" /t REG_SZ /d "native,builtin" /f
WINEPREFIX="$TEST_PREFIX" arch -x86_64 "$WINE_DIR/bin/wine" reg add "HKEY_CURRENT_USER\Software\Wine\DllOverrides" /v "*vcruntime140_1" /t REG_SZ /d "native,builtin" /f
WINEPREFIX="$TEST_PREFIX" arch -x86_64 "$WINE_DIR/bin/wine" reg add "HKEY_CURRENT_USER\Software\Wine\DllOverrides" /v "*vcomp140" /t REG_SZ /d "native,builtin" /f
WINEPREFIX="$TEST_PREFIX" arch -x86_64 "$WINE_DIR/bin/wine" reg add "HKEY_CURRENT_USER\Software\Wine\DllOverrides" /v "*vcamp140" /t REG_SZ /d "native,builtin" /f
WINEPREFIX="$TEST_PREFIX" arch -x86_64 "$WINE_DIR/bin/wine" reg add "HKEY_CURRENT_USER\Software\Wine\DllOverrides" /v "*vccorlib140" /t REG_SZ /d "native,builtin" /f
WINEPREFIX="$TEST_PREFIX" arch -x86_64 "$WINE_DIR/bin/wine" reg add "HKEY_CURRENT_USER\Software\Wine\DllOverrides" /v "*concrt140" /t REG_SZ /d "native,builtin" /f
WINEPREFIX="$TEST_PREFIX" arch -x86_64 "$WINE_DIR/bin/wine" reg add "HKEY_CURRENT_USER\Software\Wine\DllOverrides" /v "winemenubuilder.exe" /t REG_SZ /d "" /f

# 4. Install winetricks verbs (if winetricks is available)
if command -v winetricks >/dev/null 2>&1; then
  echo "==> Step 4: Installing winetricks (d3dx9_43, d3dx11_43, d3dcompiler_43, d3dcompiler_47, vcrun2022)..."
  WINEPREFIX="$TEST_PREFIX" "$REPO_ROOT/scripts/winetricks.sh" -q d3dx9_43 d3dx11_43 d3dcompiler_43 d3dcompiler_47 vcrun2022 || {
    echo "Warning: Winetricks completed with warnings (continuing with test)..."
  }
fi

# 5. Sanity command test
echo "==> Step 5: Testing basic Windows command..."
WINEPREFIX="$TEST_PREFIX" arch -x86_64 "$WINE_DIR/bin/wine" cmd.exe /c "echo Wine is working smoothly!"

echo "=========================================================="
echo "==> Sandbox verification setup complete!"
echo "To test launch ModOrganizer:"
echo "  WINEPREFIX=\"$TEST_PREFIX\" WINEMSYNC=1 arch -x86_64 \"$WINE_DIR/bin/wine\" \"$GAMMA_ROOT/mo2/ModOrganizer.exe\""
echo "To test launch Anomaly directly:"
echo "  cd \"$GAMMA_ROOT/anomaly\" && WINEPREFIX=\"$TEST_PREFIX\" WINEMSYNC=1 arch -x86_64 \"$WINE_DIR/bin/wine\" \"bin/AnomalyDX11.exe\""
echo "=========================================================="
