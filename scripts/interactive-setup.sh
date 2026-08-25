#!/usr/bin/env bash
# Interactive setup: builds a fully self-contained .app bundle — engine and
# Wine prefix both live inside Contents/Resources/, nothing external needed.
# Standalone — does not call other scripts in this repo.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

prompt_path() {
  local message="$1" default="$2" reply
  read -r -p "$message [$default]: " reply || true
  echo "${reply:-$default}"
}

echo "=========================================================="
echo "GAMMA Wine Engine — Interactive Setup (self-contained .app)"
echo "=========================================================="

# 1. Collect paths
while true; do
  ARTIFACT_PATH="$(prompt_path "Path to engine tar.xz" "$SCRIPT_DIR/dist/artifacts/CX26-3-0-W11-Gamma002.tar.xz")"
  ARTIFACT_PATH="${ARTIFACT_PATH/#\~/$HOME}"
  [[ -f "$ARTIFACT_PATH" ]] && break
  echo "  Not found: $ARTIFACT_PATH"
done

APP_NAME="$(prompt_path "Name for the .app bundle (without .app)" "GAMMA")"
APP_NAME="${APP_NAME%.app}"

APP_DIR_PARENT="$(prompt_path "Directory to place the .app in" "$HOME/Applications")"
APP_DIR_PARENT="${APP_DIR_PARENT/#\~/$HOME}"
APP_PATH="$APP_DIR_PARENT/$APP_NAME.app"

GAMMA_ROOT="$(prompt_path "Path to game root (G: drive)" "$HOME/gamma")"
GAMMA_ROOT="${GAMMA_ROOT/#\~/$HOME}"

while true; do
  EXE_REL_PATH="$(prompt_path "Path to .exe, relative to game root" "3dss5/bin/AnomalyDX11AVX.exe")"
  EXE_REL_PATH="${EXE_REL_PATH#/}"
  [[ -f "$GAMMA_ROOT/$EXE_REL_PATH" ]] && break
  echo "  Not found: $GAMMA_ROOT/$EXE_REL_PATH"
  read -r -p "  Use anyway? [y/N]: " force || true
  [[ "${force:-N}" =~ ^[Yy] ]] && break
done
EXE_WIN_PATH="G:\\${EXE_REL_PATH//\//\\}"
EXE_RUN_DIR="$GAMMA_ROOT/$(dirname "$EXE_REL_PATH")"

# Engine and prefix now live inside the app bundle
ENGINE_DIR="$APP_PATH/Contents/Resources/engine"
WINEPREFIX="$APP_PATH/Contents/Resources/prefix"

echo ""
echo "  Engine tar.xz:  $ARTIFACT_PATH"
echo "  App bundle:     $APP_PATH"
echo "  Engine (in app): $ENGINE_DIR"
echo "  Prefix (in app): $WINEPREFIX"
echo "  Game root:      $GAMMA_ROOT"
echo ""
read -r -p "Proceed? [Y/n]: " confirm || true
if [[ "${confirm:-Y}" =~ ^[Nn] ]]; then
  echo "Aborted."
  exit 1
fi

# 2. Create app skeleton, extract engine
echo ""
echo "==> Step 1: Extracting Wine engine into app bundle..."
mkdir -p "$APP_PATH/Contents/MacOS"
mkdir -p "$APP_PATH/Contents/Resources"
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

# 4. Finish .app bundle (Info.plist, app.env, launcher)
echo ""
echo "==> Step 3: Writing .app bundle metadata & launcher..."

cat > "$APP_PATH/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>English</string>
	<key>CFBundleDisplayName</key>
	<string>$APP_NAME</string>
	<key>CFBundleExecutable</key>
	<string>launcher</string>
	<key>CFBundleIconFile</key>
	<string>Anomaly</string>
	<key>CFBundleIdentifier</key>
	<string>com.gamma.stalkeranomaly</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>1.0</string>
	<key>CFBundleName</key>
	<string>$APP_NAME</string>
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

# app.env only carries toggles now — engine/prefix paths are resolved by the
# launcher relative to its own location, so the bundle stays relocatable.
cat > "$APP_PATH/Contents/Resources/app.env" << EOF
# S.T.A.L.K.E.R. Anomaly App Runtime Configuration
# Edit this file anytime to toggle settings directly!

export MTL_HUD_ENABLED=1
export WINEMSYNC=1
export WINEESYNC=1
export ROSETTA_ADVERTISE_AVX=1
export WINEDEBUG="-all"
EOF

cat > "$APP_PATH/Contents/MacOS/launcher" << EOF
#!/usr/bin/env bash
set -euo pipefail

APP_DIR="\$(cd "\$(dirname "\$0")/../.." && pwd)"
RESOURCES_DIR="\$APP_DIR/Contents/Resources"

# Engine and prefix live inside the bundle itself
ENGINE_DIR="\$RESOURCES_DIR/engine"
export WINEPREFIX="\$RESOURCES_DIR/prefix"

# Load embedded environment configuration (toggles only)
if [[ -f "\$RESOURCES_DIR/app.env" ]]; then
  source "\$RESOURCES_DIR/app.env"
fi

export WINEMSYNC="\${WINEMSYNC:-1}"
export WINEESYNC="\${WINEESYNC:-1}"
export ROSETTA_ADVERTISE_AVX="\${ROSETTA_ADVERTISE_AVX:-1}"
export MTL_HUD_ENABLED="\${MTL_HUD_ENABLED:-1}"
export WINEDEBUG="\${WINEDEBUG:--all}"
export WINEBOOT_HIDE_DIALOG=1
export LC_ALL="en_US.UTF-8"
export LANG="en_US.UTF-8"

EXE_PATH="$EXE_WIN_PATH"

# Explicit D3DMetal Paths
export CX_APPLEGPT_LIBD3DSHARED_PATH="\$ENGINE_DIR/lib/external/libd3dshared.dylib"
export CX_APPLEGPTK_LIBD3DSHARED_PATH="\$ENGINE_DIR/lib/external/libd3dshared.dylib"
export CX_D3DMETALPATH="\$ENGINE_DIR/lib/external/D3DMetal.framework"

cd "$EXE_RUN_DIR"

# Bring window to frontmost focus for DirectInput capture
(
  sleep 2
  osascript -e 'tell application "System Events" to set frontmost of (first process whose name contains "wine" or name contains "Anomaly") to true' 2>/dev/null || true
) &

# Arguments to pass (bash 3.2 on macOS chokes on "\${@}" under set -u when empty)
if [[ \$# -eq 0 && -n "\${DEFAULT_GAME_ARGS:-}" ]]; then
  # shellcheck disable=SC2086
  set -- \$DEFAULT_GAME_ARGS
fi

exec taskpolicy -l 0 -t 0 arch -x86_64 "\$ENGINE_DIR/bin/wine" "\$EXE_PATH" "\$@"
EOF

chmod +x "$APP_PATH/Contents/MacOS/launcher"

echo ""
echo "=========================================================="
echo "Setup complete — fully self-contained bundle."
echo "  App:     $APP_PATH"
echo "  Engine:  $ENGINE_DIR  (inside app)"
echo "  Prefix:  $WINEPREFIX  (inside app)"
echo ""
echo "Launch via:  open \"$APP_PATH\""
echo "Or CLI:      \"$APP_PATH/Contents/MacOS/launcher\" -dbg -nointro"
echo "=========================================================="
