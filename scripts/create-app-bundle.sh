#!/usr/bin/env bash
# Generate a standalone macOS .app bundle for S.T.A.L.K.E.R. Anomaly with customizable environment.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Default configuration values
ENABLE_MTL_HUD="${ENABLE_MTL_HUD:-${MTL_HUD_ENABLED:-1}}"
ENABLE_MSYNC="${ENABLE_MSYNC:-${WINEMSYNC:-1}}"
ENABLE_ESYNC="${ENABLE_ESYNC:-${WINEESYNC:-1}}"
ADVERTISE_AVX="${ROSETTA_ADVERTISE_AVX:-1}"
WINEDEBUG_VAL="${WINEDEBUG:--all}"
GAME_ARGS="${GAME_ARGS:--dbg}"
CUSTOM_PREFIX="${TARGET_PREFIX:-$HOME/Library/Application Support/gamma-test-prefix}"
CONFIG_FILE="${CONFIG_FILE:-}"

# Array for custom arbitrary environment variables
declare -a CUSTOM_ENVS=()

# Parse command line flags & arbitrary variables
while [[ $# -gt 0 ]]; do
  case "$1" in
    -e|--env)
      shift
      [[ $# -gt 0 ]] || { echo "Error: -e/--env requires KEY=VALUE" >&2; exit 1; }
      CUSTOM_ENVS+=("$1")
      shift
      ;;
    -e=*|--env=*)
      CUSTOM_ENVS+=("${1#*=}")
      shift
      ;;
    --hud|--metal-hud|--enable-hud)
      ENABLE_MTL_HUD=1
      shift
      ;;
    --no-hud|--disable-hud)
      ENABLE_MTL_HUD=0
      shift
      ;;
    --msync|--enable-msync)
      ENABLE_MSYNC=1
      shift
      ;;
    --no-msync|--disable-msync)
      ENABLE_MSYNC=0
      shift
      ;;
    --game-args=*)
      GAME_ARGS="${1#*=}"
      shift
      ;;
    --prefix=*)
      CUSTOM_PREFIX="${1#*=}"
      shift
      ;;
    --config=*)
      CONFIG_FILE="${1#*=}"
      shift
      ;;
    *=*)
      # Direct arbitrary KEY=VALUE variable (e.g. DXVK_HUD=fps FOO=BAR)
      CUSTOM_ENVS+=("$1")
      shift
      ;;
    -h|--help)
      echo "Usage: $0 [OPTIONS] [KEY=VALUE ...]"
      echo ""
      echo "Options:"
      echo "  -e, --env KEY=VALUE          Set any custom environment variable"
      echo "  KEY=VALUE                    Set arbitrary custom environment variables directly"
      echo "  --hud / --no-hud             Enable or disable Metal Performance HUD (default: enabled)"
      echo "  --msync / --no-msync         Enable or disable Darwin Mach Semaphore synchronization (default: enabled)"
      echo "  --game-args=\"<args>\"         Default game arguments passed to executable (default: -dbg)"
      echo "  --prefix=\"<path>\"            Target Wine prefix path"
      echo "  --config=\"<path>\"            Path to an external .env file to embed"
      echo ""
      echo "Examples:"
      echo "  $0 --no-hud"
      echo "  $0 -e DXVK_HUD=fps -e MY_VAR=1"
      echo "  $0 DXVK_HUD=fps MY_CUSTOM_FLAG=true --game-args=\"-dbg -nointro\""
      exit 0
      ;;
    *)
      echo "Unknown option: $1 (use --help for options)" >&2
      shift
      ;;
  esac
done

# Load external config file if provided or if config/app.env exists
if [[ -n "$CONFIG_FILE" && -f "$CONFIG_FILE" ]]; then
  echo "==> Loading configuration from: $CONFIG_FILE"
  # shellcheck disable=SC1090
  source "$CONFIG_FILE"
elif [[ -f "$REPO_ROOT/config/app.env" ]]; then
  echo "==> Loading configuration from: $REPO_ROOT/config/app.env"
  # shellcheck disable=SC1090
  source "$REPO_ROOT/config/app.env"
fi

APP_DIR="$REPO_ROOT/dist/S.T.A.L.K.E.R. Anomaly.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "=========================================================="
echo "Creating macOS Application Bundle: S.T.A.L.K.E.R. Anomaly.app"
echo "  Target:        $APP_DIR"
echo "  Metal HUD:     $ENABLE_MTL_HUD"
echo "  Msync:         $ENABLE_MSYNC"
echo "  Rosetta AVX:   $ADVERTISE_AVX"
echo "  Game Args:     $GAME_ARGS"
echo "  Prefix:        $CUSTOM_PREFIX"
if [[ ${#CUSTOM_ENVS[@]} -gt 0 ]]; then
  echo "  Custom Envs:   ${CUSTOM_ENVS[*]}"
fi
echo "=========================================================="

mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

# 1. Generate Info.plist
cat > "$CONTENTS_DIR/Info.plist" << 'EOF'
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

# 2. Copy icon if available
if [[ -f "/Users/elseform/Applications/stalker-gamma.app/Contents/Resources/Anomaly.icns" ]]; then
  cp -f "/Users/elseform/Applications/stalker-gamma.app/Contents/Resources/Anomaly.icns" "$RESOURCES_DIR/Anomaly.icns"
fi

# 3. Write embedded app.env
cat > "$RESOURCES_DIR/app.env" << EOF
# S.T.A.L.K.E.R. Anomaly App Runtime Configuration
# Edit this file anytime to adjust settings without recreating the .app bundle.

export MTL_HUD_ENABLED=$ENABLE_MTL_HUD
export WINEMSYNC=$ENABLE_MSYNC
export WINEESYNC=$ENABLE_ESYNC
export ROSETTA_ADVERTISE_AVX=$ADVERTISE_AVX
export WINEDEBUG="$WINEDEBUG_VAL"
export TARGET_PREFIX="$CUSTOM_PREFIX"
export DEFAULT_GAME_ARGS="$GAME_ARGS"

# Custom Environment Variables
EOF

if [[ ${#CUSTOM_ENVS[@]} -gt 0 ]]; then
  for env_pair in "${CUSTOM_ENVS[@]}"; do
    var_name="${env_pair%%=*}"
    var_val="${env_pair#*=}"
    echo "export $var_name=\"$var_val\"" >> "$RESOURCES_DIR/app.env"
  done
fi

# 4. Write launcher script
cat > "$MACOS_DIR/launcher" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
RESOURCES_DIR="$APP_DIR/Contents/Resources"

# Load embedded app.env if present
if [[ -f "$RESOURCES_DIR/app.env" ]]; then
  # shellcheck disable=SC1090
  source "$RESOURCES_DIR/app.env"
fi

REPO_ROOT="$(cd "$APP_DIR/.." && pwd)"
if [[ ! -f "$REPO_ROOT/scripts/launch-3dss5.sh" ]]; then
  REPO_ROOT="$(cd "$APP_DIR/../.." && pwd)"
fi

GAME_LAUNCHER="$REPO_ROOT/scripts/launch-3dss5.sh"
if [[ ! -x "$GAME_LAUNCHER" ]]; then
  echo "Error: Launcher script not found at $GAME_LAUNCHER" >&2
  exit 1
fi

# Pass configured default args if no arguments provided from Finder/CLI
if [[ $# -eq 0 && -n "${DEFAULT_GAME_ARGS:-}" ]]; then
  # shellcheck disable=SC2086
  exec "$GAME_LAUNCHER" $DEFAULT_GAME_ARGS
else
  exec "$GAME_LAUNCHER" "$@"
fi
EOF

chmod +x "$MACOS_DIR/launcher"
echo "==> Application bundle successfully created at: $APP_DIR"
echo "    You can edit '$RESOURCES_DIR/app.env' anytime to toggle settings directly."
