# How-To Guide: Standalone Engine, Prefix & App Setup

This guide explains how to set up a complete, high-performance S.T.A.L.K.E.R. Anomaly / G.A.M.M.A. gaming environment starting **only** from the prebuilt engine archive:
`CX26-3W11-Gamma0-1.tar.xz` (or `gamma-wine-x86_64-CX26-3-0-W11-Gamma001.tar.xz`).

No external wrappers, third-party launchers, or build tools are required.

---

## Prerequisites

- **macOS**: 10.15 (Catalina) or newer on Apple Silicon (M1/M2/M3/M4) or Intel.
- **Rosetta 2**: (On Apple Silicon) Installed and enabled (`softwareupdate --install-rosetta`).
- **Game Files**: Installed in `$HOME/gamma/3dss5` (or any location you choose).
- **Engine Tarball**: `CX26-3W11-Gamma0-1.tar.xz`.

---

## Step 1: Extract the Wine Engine

Choose an installation destination for the Wine engine (e.g. `~/Applications/gamma-wine` or inside your tools directory):

```bash
# 1. Define paths
export ENGINE_DIR="$HOME/Applications/gamma-wine"
export ARTIFACT_PATH="$PWD/dist/artifacts/CX26-3W11-Gamma0-1.tar.xz"

# 2. Extract archive
mkdir -p "$ENGINE_DIR"
tar -xf "$ARTIFACT_PATH" -C "$ENGINE_DIR" --strip-components=1

# 3. Verify Wine binary
arch -x86_64 "$ENGINE_DIR/bin/wine" --version
# Output: wine-11.0
```

---

## Step 2: Bootstrap the Wine Prefix

We will create a clean prefix at `~/Library/Application Support/gamma-test-prefix`.

### 2.1 Initialize Prefix
```bash
export WINEPREFIX="$HOME/Library/Application Support/gamma-test-prefix"
export WINE_DIR="$HOME/Applications/gamma-wine"

# Clean any running instance and initialize
arch -x86_64 "$WINE_DIR/bin/wineserver" -k 2>/dev/null || true
mkdir -p "$WINEPREFIX"

WINEPREFIX="$WINEPREFIX" arch -x86_64 "$WINE_DIR/bin/wine" wineboot -u
WINEPREFIX="$WINEPREFIX" arch -x86_64 "$WINE_DIR/bin/wineserver" -w
```

### 2.2 Configure Drive Mappings & User Profiles
```bash
# Map C: and Z: (root)
mkdir -p "$WINEPREFIX/dosdevices"
ln -sfn "/" "$WINEPREFIX/dosdevices/z:"
ln -sfn "../drive_c" "$WINEPREFIX/dosdevices/c:"

# Map G: to your game root directory (~/gamma)
ln -sfn "$HOME/gamma" "$WINEPREFIX/dosdevices/g:"

# User profile normalization
mkdir -p "$WINEPREFIX/drive_c/users/Sikarugir"
ln -sfn "Sikarugir" "$WINEPREFIX/drive_c/users/crossover"
ln -sfn "Sikarugir" "$WINEPREFIX/drive_c/users/$USER"
```

### 2.3 Set Clean Registry Overrides
```bash
# Set Mac graphics driver and clean gamma behavior
WINEPREFIX="$WINEPREFIX" arch -x86_64 "$WINE_DIR/bin/wine" reg add "HKEY_CURRENT_USER\Software\Wine\Drivers" /v Graphics /t REG_SZ /d mac /f
WINEPREFIX="$WINEPREFIX" arch -x86_64 "$WINE_DIR/bin/wine" reg add "HKEY_CURRENT_USER\Software\Wine\Mac Driver" /v AllowSetGamma /t REG_DWORD /d 0 /f

# Direct3D Metal translation overrides
WINEPREFIX="$WINEPREFIX" arch -x86_64 "$WINE_DIR/bin/wine" reg add "HKEY_CURRENT_USER\Software\Wine\DllOverrides" /v d3d11 /t REG_SZ /d builtin /f
WINEPREFIX="$WINEPREFIX" arch -x86_64 "$WINE_DIR/bin/wine" reg add "HKEY_CURRENT_USER\Software\Wine\DllOverrides" /v dxgi /t REG_SZ /d builtin /f
WINEPREFIX="$WINEPREFIX" arch -x86_64 "$WINE_DIR/bin/wine" reg add "HKEY_CURRENT_USER\Software\Wine\DllOverrides" /v d3d12 /t REG_SZ /d builtin /f

# DirectX compiler & runtime overrides
WINEPREFIX="$WINEPREFIX" arch -x86_64 "$WINE_DIR/bin/wine" reg add "HKEY_CURRENT_USER\Software\Wine\DllOverrides" /v "*d3dcompiler_43" /t REG_SZ /d "native,builtin" /f
WINEPREFIX="$WINEPREFIX" arch -x86_64 "$WINE_DIR/bin/wine" reg add "HKEY_CURRENT_USER\Software\Wine\DllOverrides" /v "*d3dcompiler_47" /t REG_SZ /d "native,builtin" /f
WINEPREFIX="$WINEPREFIX" arch -x86_64 "$WINE_DIR/bin/wine" reg add "HKEY_CURRENT_USER\Software\Wine\DllOverrides" /v "*d3dx9_43" /t REG_SZ /d "native,builtin" /f
WINEPREFIX="$WINEPREFIX" arch -x86_64 "$WINE_DIR/bin/wine" reg add "HKEY_CURRENT_USER\Software\Wine\DllOverrides" /v "*d3dx10_43" /t REG_SZ /d "native,builtin" /f
WINEPREFIX="$WINEPREFIX" arch -x86_64 "$WINE_DIR/bin/wine" reg add "HKEY_CURRENT_USER\Software\Wine\DllOverrides" /v "*d3dx11_43" /t REG_SZ /d "native,builtin" /f
WINEPREFIX="$WINEPREFIX" arch -x86_64 "$WINE_DIR/bin/wine" reg add "HKEY_CURRENT_USER\Software\Wine\DllOverrides" /v "winemenubuilder.exe" /t REG_SZ /d "" /f
```

### 2.4 Install Required Winetricks Packages
Download `winetricks` (or use the bundled `scripts/winetricks.sh` if in the repository):
```bash
# Download official winetricks if not present
curl -fsSL https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks -o /tmp/winetricks
chmod +x /tmp/winetricks

# Install DirectX runtimes, VC++ 2022, CoreAudio sound, and Windows 10 mode
WINE="$WINE_DIR/bin/wine" WINESERVER="$WINE_DIR/bin/wineserver" WINEPREFIX="$WINEPREFIX" \
  /tmp/winetricks -q \
    d3dx9_43 \
    d3dx11_43 \
    d3dcompiler_43 \
    d3dcompiler_47 \
    vcrun2022 \
    win10 \
    sound=coreaudio

WINEPREFIX="$WINEPREFIX" arch -x86_64 "$WINE_DIR/bin/wineserver" -w
```

---

## Step 3: Create the Standalone macOS `.app` Bundle

Creating a native `.app` bundle gives the game:
- **`taskpolicy -l 0 -t 0`**: Tier 0 low-latency scheduling priority.
- **WindowServer Event Coalescing**: Smooth 1:1 camera rotation and mouse tracking.
- **DisplayLink Sync**: Smooth frame delivery matching your monitor's native refresh rate (60Hz / 120Hz).

### 3.1 Create Application Directory Structure
```bash
export APP_PATH="$HOME/Applications/S.T.A.L.K.E.R. Anomaly.app"

mkdir -p "$APP_PATH/Contents/MacOS"
mkdir -p "$APP_PATH/Contents/Resources"
```

### 3.2 Write `Info.plist`
```bash
cat > "$APP_PATH/Contents/Info.plist" << 'EOF'
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
```

### 3.3 Write Configurable Environment (`Contents/Resources/app.env`)
```bash
cat > "$APP_PATH/Contents/Resources/app.env" << EOF
# S.T.A.L.K.E.R. Anomaly App Runtime Configuration
# Edit this file anytime to toggle settings directly!

export WINE_DIR="$HOME/Applications/gamma-wine"
export WINEPREFIX="$HOME/Library/Application Support/gamma-test-prefix"
export MTL_HUD_ENABLED=1
export WINEMSYNC=1
export WINEESYNC=1
export ROSETTA_ADVERTISE_AVX=1
export WINEDEBUG="-all"
export DEFAULT_GAME_ARGS="-dbg"
EOF
```

### 3.4 Write Launcher Executable (`Contents/MacOS/launcher`)
```bash
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

# Arguments to pass
ARGS=("${@}")
if [[ ${#ARGS[@]} -eq 0 && -n "${DEFAULT_GAME_ARGS:-}" ]]; then
  # shellcheck disable=SC2086
  set -- $DEFAULT_GAME_ARGS
fi

exec taskpolicy -l 0 -t 0 arch -x86_64 "$ENGINE_DIR/bin/wine" "$EXE_PATH" "$@"
EOF

chmod +x "$APP_PATH/Contents/MacOS/launcher"
```

---

## Step 4: Run the Game

You can now start the game in two convenient ways:

### Method 1: Launch via Finder / Dock
Double click **`S.T.A.L.K.E.R. Anomaly.app`** or run:
```bash
open "$HOME/Applications/S.T.A.L.K.E.R. Anomaly.app"
```

### Method 2: Launch via CLI with Custom Arguments
```bash
"$HOME/Applications/S.T.A.L.K.E.R. Anomaly.app/Contents/MacOS/launcher" -dbg -nointro
```

---

## Adjusting Settings & Environment Variables

You can customize runtime behavior anytime by editing:
`$HOME/Applications/S.T.A.L.K.E.R. Anomaly.app/Contents/Resources/app.env`

- **Disable Metal HUD**: `export MTL_HUD_ENABLED=0`
- **Enable/Disable Msync**: `export WINEMSYNC=1` (or `0`)
- **Add Custom Variables**: e.g. `export DXVK_HUD="fps"` or `export FOO="bar"`
