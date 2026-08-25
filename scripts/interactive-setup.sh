#!/usr/bin/env bash
# Interactive setup: extract engine tar.xz, bootstrap Wine prefix, build .app bundle.
# Standalone — does not call other scripts in this repo.
set -euo pipefail

prompt_path() {
  local message="$1" default="$2" reply
  read -r -p "$message [$default]: " reply || true
  echo "${reply:-$default}"
}

echo "=========================================================="
echo "GAMMA Wine Engine — Interactive Setup"
echo "=========================================================="

# 1. Collect paths
while true; do
  ARTIFACT_PATH="$(prompt_path "Path to engine tar.xz" "$PWD/dist/artifacts/CX26-3W11-Gamma0-1.tar.xz")"
  ARTIFACT_PATH="${ARTIFACT_PATH/#\~/$HOME}"
  [[ -f "$ARTIFACT_PATH" ]] && break
  echo "  Not found: $ARTIFACT_PATH"
done

ENGINE_DIR="$(prompt_path "Target path for engine" "$HOME/Applications/gamma-wine")"
ENGINE_DIR="${ENGINE_DIR/#\~/$HOME}"

WINEPREFIX="$(prompt_path "Wine prefix path" "$HOME/Library/Application Support/gamma-test-prefix")"
WINEPREFIX="${WINEPREFIX/#\~/$HOME}"

APP_PATH="$(prompt_path "Path for the .app bundle" "$HOME/Applications/S.T.A.L.K.E.R. Anomaly.app")"
APP_PATH="${APP_PATH/#\~/$HOME}"

GAMMA_ROOT="$(prompt_path "Path to game root (G: drive)" "$HOME/gamma")"
GAMMA_ROOT="${GAMMA_ROOT/#\~/$HOME}"

echo ""
echo "  Engine tar.xz:  $ARTIFACT_PATH"
echo "  Engine target:  $ENGINE_DIR"
echo "  Wine prefix:    $WINEPREFIX"
echo "  App bundle:     $APP_PATH"
echo "  Game root:      $GAMMA_ROOT"
echo ""
read -r -p "Proceed? [Y/n]: " confirm || true
if [[ "${confirm:-Y}" =~ ^[Nn] ]]; then
  echo "Aborted."
  exit 1
fi

# 2. Extract engine
echo ""
echo "==> Step 1: Extracting Wine engine..."
mkdir -p "$ENGINE_DIR"
tar -xf "$ARTIFACT_PATH" -C "$ENGINE_DIR" --strip-components=1

if [[ ! -x "$ENGINE_DIR/bin/wine" ]]; then
  echo "Error: wine binary missing after extraction at $ENGINE_DIR/bin/wine" >&2
  exit 1
fi
arch -x86_64 "$ENGINE_DIR/bin/wine" --version

# 3. Bootstrap prefix
echo ""
echo "==> Step 2: Bootstrapping Wine prefix..."
arch -x86_64 "$ENGINE_DIR/bin/wineserver" -k 2>/dev/null || true
mkdir -p "$WINEPREFIX"

WINEPREFIX="$WINEPREFIX" arch -x86_64 "$ENGINE_DIR/bin/wine" wineboot -u
WINEPREFIX="$WINEPREFIX" arch -x86_64 "$ENGINE_DIR/bin/wineserver" -w

echo "==> Step 2.2: Drive mappings & user profile..."
mkdir -p "$WINEPREFIX/dosdevices"
ln -sfn "/" "$WINEPREFIX/dosdevices/z:"
ln -sfn "../drive_c" "$WINEPREFIX/dosdevices/c:"
ln -sfn "$GAMMA_ROOT" "$WINEPREFIX/dosdevices/g:"

mkdir -p "$WINEPREFIX/drive_c/users/Sikarugir"
ln -sfn "Sikarugir" "$WINEPREFIX/drive_c/users/crossover"
ln -sfn "Sikarugir" "$WINEPREFIX/drive_c/users/$USER"

echo "==> Step 2.3: Registry overrides..."
WINEPREFIX="$WINEPREFIX" arch -x86_64 "$ENGINE_DIR/bin/wine" reg add "HKEY_CURRENT_USER\Software\Wine\Drivers" /v Graphics /t REG_SZ /d mac /f
WINEPREFIX="$WINEPREFIX" arch -x86_64 "$ENGINE_DIR/bin/wine" reg add "HKEY_CURRENT_USER\Software\Wine\Mac Driver" /v AllowSetGamma /t REG_DWORD /d 0 /f

WINEPREFIX="$WINEPREFIX" arch -x86_64 "$ENGINE_DIR/bin/wine" reg add "HKEY_CURRENT_USER\Software\Wine\DllOverrides" /v d3d11 /t REG_SZ /d builtin /f
WINEPREFIX="$WINEPREFIX" arch -x86_64 "$ENGINE_DIR/bin/wine" reg add "HKEY_CURRENT_USER\Software\Wine\DllOverrides" /v dxgi /t REG_SZ /d builtin /f
WINEPREFIX="$WINEPREFIX" arch -x86_64 "$ENGINE_DIR/bin/wine" reg add "HKEY_CURRENT_USER\Software\Wine\DllOverrides" /v d3d12 /t REG_SZ /d builtin /f
WINEPREFIX="$WINEPREFIX" arch -x86_64 "$ENGINE_DIR/bin/wine" reg add "HKEY_CURRENT_USER\Software\Wine\DllOverrides" /v "*d3dcompiler_43" /t REG_SZ /d "native,builtin" /f
WINEPREFIX="$WINEPREFIX" arch -x86_64 "$ENGINE_DIR/bin/wine" reg add "HKEY_CURRENT_USER\Software\Wine\DllOverrides" /v "*d3dcompiler_47" /t REG_SZ /d "native,builtin" /f
WINEPREFIX="$WINEPREFIX" arch -x86_64 "$ENGINE_DIR/bin/wine" reg add "HKEY_CURRENT_USER\Software\Wine\DllOverrides" /v "*d3dx9_43" /t REG_SZ /d "native,builtin" /f
WINEPREFIX="$WINEPREFIX" arch -x86_64 "$ENGINE_DIR/bin/wine" reg add "HKEY_CURRENT_USER\Software\Wine\DllOverrides" /v "*d3dx10_43" /t REG_SZ /d "native,builtin" /f
WINEPREFIX="$WINEPREFIX" arch -x86_64 "$ENGINE_DIR/bin/wine" reg add "HKEY_CURRENT_USER\Software\Wine\DllOverrides" /v "*d3dx11_43" /t REG_SZ /d "native,builtin" /f
WINEPREFIX="$WINEPREFIX" arch -x86_64 "$ENGINE_DIR/bin/wine" reg add "HKEY_CURRENT_USER\Software\Wine\DllOverrides" /v "winemenubuilder.exe" /t REG_SZ /d "" /f

echo "==> Step 2.4: Installing winetricks packages..."
WINETRICKS_BIN="/tmp/winetricks"
if ! command -v winetricks >/dev/null 2>&1 && [[ ! -x "$WINETRICKS_BIN" ]]; then
  curl -fsSL https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks -o "$WINETRICKS_BIN"
  chmod +x "$WINETRICKS_BIN"
fi
WINETRICKS_CMD="$(command -v winetricks || echo "$WINETRICKS_BIN")"

WINE="$ENGINE_DIR/bin/wine" WINESERVER="$ENGINE_DIR/bin/wineserver" WINEPREFIX="$WINEPREFIX" \
  "$WINETRICKS_CMD" -q \
    d3dx9_43 \
    d3dx11_43 \
    d3dcompiler_43 \
    d3dcompiler_47 \
    vcrun2022 \
    win10 \
    sound=coreaudio

WINEPREFIX="$WINEPREFIX" arch -x86_64 "$ENGINE_DIR/bin/wineserver" -w

# 4. Create .app bundle
echo ""
echo "==> Step 3: Creating .app bundle..."
mkdir -p "$APP_PATH/Contents/MacOS"
mkdir -p "$APP_PATH/Contents/Resources"

cat > "$APP_PATH/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>English</string>
	<key>CFBundleDisplayName</key>
	<string>S.T.A.L.K.E.R. Anomaly</string>
	<key>CFBundleExecutable</key>
	<string>launcher</string>
	<key>CFBundleIconFile</key>
	<string>Anomaly</string>
	<key>CFBundleIdentifier</key>
	<string>com.gamma.stalkeranomaly</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>1.0</string>
	<key>CFBundleName</key>
	<string>S.T.A.L.K.E.R. Anomaly</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>1.5.2</string>
	<key>CFBundleVersion</key>
	<string>1.0.0</string>
	<key>LSMinimumSystemVersion</key>
	<string>10.15</string>
	<key>NSHighResolutionCapable</key>
	<true/>
	<key>NSSupportsAutomaticGraphicsSwitching</key>
	<true/>
	<key>NSPrincipalClass</key>
	<string>NSApplication</string>
</dict>
</plist>
EOF

cat > "$APP_PATH/Contents/Resources/app.env" << EOF
# S.T.A.L.K.E.R. Anomaly App Runtime Configuration
# Edit this file anytime to toggle settings directly!

export WINE_DIR="$ENGINE_DIR"
export WINEPREFIX="$WINEPREFIX"
export MTL_HUD_ENABLED=1
export WINEMSYNC=1
export WINEESYNC=1
export ROSETTA_ADVERTISE_AVX=1
export WINEDEBUG="-all"
export DEFAULT_GAME_ARGS="-dbg"
EOF

cat > "$APP_PATH/Contents/MacOS/launcher" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

APP_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
RESOURCES_DIR="$APP_DIR/Contents/Resources"

# Load embedded environment configuration
if [[ -f "$RESOURCES_DIR/app.env" ]]; then
  source "$RESOURCES_DIR/app.env"
fi

export WINEPREFIX="${WINEPREFIX:-$HOME/Library/Application Support/gamma-test-prefix}"
export WINEMSYNC="${WINEMSYNC:-1}"
export WINEESYNC="${WINEESYNC:-1}"
export ROSETTA_ADVERTISE_AVX="${ROSETTA_ADVERTISE_AVX:-1}"
export MTL_HUD_ENABLED="${MTL_HUD_ENABLED:-1}"
export WINEDEBUG="${WINEDEBUG:--all}"
export WINEBOOT_HIDE_DIALOG=1
export LC_ALL="en_US.UTF-8"
export LANG="en_US.UTF-8"

ENGINE_DIR="${WINE_DIR:-$HOME/Applications/gamma-wine}"
EXE_PATH="G:\3dss5\bin\AnomalyDX11AVX.exe"

# Explicit D3DMetal Paths
export CX_APPLEGPT_LIBD3DSHARED_PATH="$ENGINE_DIR/lib/external/libd3dshared.dylib"
export CX_APPLEGPTK_LIBD3DSHARED_PATH="$ENGINE_DIR/lib/external/libd3dshared.dylib"
export CX_D3DMETALPATH="$ENGINE_DIR/lib/external/D3DMetal.framework"

cd "$HOME/gamma/3dss5/bin"

# Bring window to frontmost focus for DirectInput capture
(
  sleep 2
  osascript -e 'tell application "System Events" to set frontmost of (first process whose name contains "wine" or name contains "Anomaly") to true' 2>/dev/null || true
) &

# Arguments to pass (bash 3.2 on macOS chokes on "${@}" under set -u when empty)
if [[ $# -eq 0 && -n "${DEFAULT_GAME_ARGS:-}" ]]; then
  # shellcheck disable=SC2086
  set -- $DEFAULT_GAME_ARGS
fi

exec taskpolicy -l 0 -t 0 arch -x86_64 "$ENGINE_DIR/bin/wine" "$EXE_PATH" "$@"
EOF

chmod +x "$APP_PATH/Contents/MacOS/launcher"

echo ""
echo "=========================================================="
echo "Setup complete."
echo "  Engine:  $ENGINE_DIR"
echo "  Prefix:  $WINEPREFIX"
echo "  App:     $APP_PATH"
echo ""
echo "Launch via:  open \"$APP_PATH\""
echo "Or CLI:      \"$APP_PATH/Contents/MacOS/launcher\" -dbg -nointro"
echo "=========================================================="
