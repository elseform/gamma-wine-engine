#!/usr/bin/env bash
# Bootstrap ~/Library/Application Support/gamma-test-prefix with full gamma-setup-tool winetricks and mappings.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

WINE_DIR="${WINE_DIR:-$REPO_ROOT/install/wine-cx26-x86_64}"
TARGET_PREFIX="${TARGET_PREFIX:-$HOME/Library/Application Support/gamma-test-prefix}"
GAMMA_ROOT="${GAMMA_ROOT:-$HOME/gamma}"

[[ -x "$WINE_DIR/bin/wine" ]] || {
  echo "Error: Wine binary not found at $WINE_DIR/bin/wine" >&2
  exit 1
}

echo "=========================================================="
echo "Bootstrapping GAMMA Test Prefix"
echo "  Wine:        $WINE_DIR/bin/wine"
echo "  Target:      $TARGET_PREFIX"
echo "  GAMMA Root:  $GAMMA_ROOT"
echo "=========================================================="

FORCE_CLEAN=0
for arg in "$@"; do
  case "$arg" in
    --clean|--recreate|--force|-f)
      FORCE_CLEAN=1
      ;;
  esac
done

if [[ "$FORCE_CLEAN" -eq 1 && -d "$TARGET_PREFIX" ]]; then
  echo "==> Cleaning existing prefix: $TARGET_PREFIX..."
  WINEPREFIX="$TARGET_PREFIX" arch -x86_64 "$WINE_DIR/bin/wineserver" -k 2>/dev/null || true
  rm -rf "$TARGET_PREFIX"
fi

# 1. Terminate running wineserver for this prefix
WINEPREFIX="$TARGET_PREFIX" arch -x86_64 "$WINE_DIR/bin/wineserver" -k 2>/dev/null || true
mkdir -p "$TARGET_PREFIX"

# 2. Initialize prefix
echo "==> Step 1: Bootstrapping Wine prefix..."
WINEPREFIX="$TARGET_PREFIX" arch -x86_64 "$WINE_DIR/bin/wine" wineboot -u
WINEPREFIX="$TARGET_PREFIX" arch -x86_64 "$WINE_DIR/bin/wineserver" -w
echo "  Prefix initialized."

# 3. Drive mappings
echo "==> Step 2: Configuring drive mappings..."
mkdir -p "$TARGET_PREFIX/dosdevices"
ln -sfn "/" "$TARGET_PREFIX/dosdevices/z:"
ln -sfn "../drive_c" "$TARGET_PREFIX/dosdevices/c:"
if [[ -d "$GAMMA_ROOT" ]]; then
  ln -sfn "$GAMMA_ROOT" "$TARGET_PREFIX/dosdevices/g:"
  echo "  Mapped G: -> $GAMMA_ROOT"
fi

# 4. User profile normalization (matching Sikarugir / gamma-setup-tool)
echo "==> Step 3: Setting up user profile symlinks..."
mkdir -p "$TARGET_PREFIX/drive_c/users/Sikarugir"
ln -sfn "Sikarugir" "$TARGET_PREFIX/drive_c/users/crossover" 2>/dev/null || true
ln -sfn "Sikarugir" "$TARGET_PREFIX/drive_c/users/$USER" 2>/dev/null || true

# 5. Registry overrides
WINEPREFIX="$TARGET_PREFIX" arch -x86_64 "$WINE_DIR/bin/wine" reg add "HKEY_CURRENT_USER\Software\Wine\Drivers" /v Graphics /t REG_SZ /d mac /f
WINEPREFIX="$TARGET_PREFIX" arch -x86_64 "$WINE_DIR/bin/wine" reg add "HKEY_CURRENT_USER\Software\Wine\Mac Driver" /v AllowSetGamma /t REG_DWORD /d 0 /f
WINEPREFIX="$TARGET_PREFIX" arch -x86_64 "$WINE_DIR/bin/wine" reg add "HKEY_CURRENT_USER\Software\Wine\DllOverrides" /v d3d11 /t REG_SZ /d builtin /f
WINEPREFIX="$TARGET_PREFIX" arch -x86_64 "$WINE_DIR/bin/wine" reg add "HKEY_CURRENT_USER\Software\Wine\DllOverrides" /v dxgi /t REG_SZ /d builtin /f
WINEPREFIX="$TARGET_PREFIX" arch -x86_64 "$WINE_DIR/bin/wine" reg add "HKEY_CURRENT_USER\Software\Wine\DllOverrides" /v d3d12 /t REG_SZ /d builtin /f
WINEPREFIX="$TARGET_PREFIX" arch -x86_64 "$WINE_DIR/bin/wine" reg add "HKEY_CURRENT_USER\Software\Wine\DllOverrides" /v "*d3dcompiler_43" /t REG_SZ /d "native,builtin" /f
WINEPREFIX="$TARGET_PREFIX" arch -x86_64 "$WINE_DIR/bin/wine" reg add "HKEY_CURRENT_USER\Software\Wine\DllOverrides" /v "*d3dcompiler_47" /t REG_SZ /d "native,builtin" /f
WINEPREFIX="$TARGET_PREFIX" arch -x86_64 "$WINE_DIR/bin/wine" reg add "HKEY_CURRENT_USER\Software\Wine\DllOverrides" /v "*d3dx9_43" /t REG_SZ /d "native,builtin" /f
WINEPREFIX="$TARGET_PREFIX" arch -x86_64 "$WINE_DIR/bin/wine" reg add "HKEY_CURRENT_USER\Software\Wine\DllOverrides" /v "*d3dx10_43" /t REG_SZ /d "native,builtin" /f
WINEPREFIX="$TARGET_PREFIX" arch -x86_64 "$WINE_DIR/bin/wine" reg add "HKEY_CURRENT_USER\Software\Wine\DllOverrides" /v "*d3dx11_43" /t REG_SZ /d "native,builtin" /f
WINEPREFIX="$TARGET_PREFIX" arch -x86_64 "$WINE_DIR/bin/wine" reg add "HKEY_CURRENT_USER\Software\Wine\DllOverrides" /v "*msvcp140" /t REG_SZ /d "native,builtin" /f
WINEPREFIX="$TARGET_PREFIX" arch -x86_64 "$WINE_DIR/bin/wine" reg add "HKEY_CURRENT_USER\Software\Wine\DllOverrides" /v "*msvcp140_1" /t REG_SZ /d "native,builtin" /f
WINEPREFIX="$TARGET_PREFIX" arch -x86_64 "$WINE_DIR/bin/wine" reg add "HKEY_CURRENT_USER\Software\Wine\DllOverrides" /v "*msvcp140_2" /t REG_SZ /d "native,builtin" /f
WINEPREFIX="$TARGET_PREFIX" arch -x86_64 "$WINE_DIR/bin/wine" reg add "HKEY_CURRENT_USER\Software\Wine\DllOverrides" /v "*msvcp140_atomic_wait" /t REG_SZ /d "native,builtin" /f
WINEPREFIX="$TARGET_PREFIX" arch -x86_64 "$WINE_DIR/bin/wine" reg add "HKEY_CURRENT_USER\Software\Wine\DllOverrides" /v "*msvcp140_codecvt_ids" /t REG_SZ /d "native,builtin" /f
WINEPREFIX="$TARGET_PREFIX" arch -x86_64 "$WINE_DIR/bin/wine" reg add "HKEY_CURRENT_USER\Software\Wine\DllOverrides" /v "*vcruntime140" /t REG_SZ /d "native,builtin" /f
WINEPREFIX="$TARGET_PREFIX" arch -x86_64 "$WINE_DIR/bin/wine" reg add "HKEY_CURRENT_USER\Software\Wine\DllOverrides" /v "*vcruntime140_1" /t REG_SZ /d "native,builtin" /f
WINEPREFIX="$TARGET_PREFIX" arch -x86_64 "$WINE_DIR/bin/wine" reg add "HKEY_CURRENT_USER\Software\Wine\DllOverrides" /v "*vcomp140" /t REG_SZ /d "native,builtin" /f
WINEPREFIX="$TARGET_PREFIX" arch -x86_64 "$WINE_DIR/bin/wine" reg add "HKEY_CURRENT_USER\Software\Wine\DllOverrides" /v "*vcamp140" /t REG_SZ /d "native,builtin" /f
WINEPREFIX="$TARGET_PREFIX" arch -x86_64 "$WINE_DIR/bin/wine" reg add "HKEY_CURRENT_USER\Software\Wine\DllOverrides" /v "*vccorlib140" /t REG_SZ /d "native,builtin" /f
WINEPREFIX="$TARGET_PREFIX" arch -x86_64 "$WINE_DIR/bin/wine" reg add "HKEY_CURRENT_USER\Software\Wine\DllOverrides" /v "*concrt140" /t REG_SZ /d "native,builtin" /f
WINEPREFIX="$TARGET_PREFIX" arch -x86_64 "$WINE_DIR/bin/wine" reg add "HKEY_CURRENT_USER\Software\Wine\DllOverrides" /v "winemenubuilder.exe" /t REG_SZ /d "" /f

# 6. Install winetricks verbs (same as gamma-setup-tool)
echo "==> Step 5: Installing winetricks packages (d3dx9_43, d3dx11_43, d3dcompiler_43, d3dcompiler_47, vcrun2022, win10)..."
WINEPREFIX="$TARGET_PREFIX" "$REPO_ROOT/scripts/winetricks.sh" -q \
  d3dx9_43 \
  d3dx11_43 \
  d3dcompiler_43 \
  d3dcompiler_47 \
  vcrun2022 \
  win10 \
  sound=coreaudio || {
  echo "Winetricks finished."
}

WINEPREFIX="$TARGET_PREFIX" arch -x86_64 "$WINE_DIR/bin/wineserver" -w

echo "=========================================================="
echo "==> Setup complete for: $TARGET_PREFIX"
echo "=========================================================="
