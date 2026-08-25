#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PREFIX="${TARGET_PREFIX:-$HOME/Library/Application Support/gamma-test-prefix}"
ENGINE_DIR="${WINE_DIR:-$REPO_ROOT/install/wine-cx26-x86_64}"
EXE_PATH="G:\\3dss5\\bin\\AnomalyDX11AVX.exe"

# 1. Prefix & Engine Environment
export WINEPREFIX="${WINEPREFIX:-$PREFIX}"

export WINEMSYNC="${WINEMSYNC:-1}"
export WINEESYNC="${WINEESYNC:-1}"
export ROSETTA_ADVERTISE_AVX="${ROSETTA_ADVERTISE_AVX:-1}"
export MTL_HUD_ENABLED="${MTL_HUD_ENABLED:-${ENABLE_MTL_HUD:-1}}"

# 2. Performance & Console I/O Elimination
# Silence Wine debug/fixme output to eliminate terminal stream lock contention
export WINEDEBUG="${WINEDEBUG:--all}"
export WINEBOOT_HIDE_DIALOG=1

# 3. Locale & String Normalization
export LC_ALL="en_US.UTF-8"
export LANG="en_US.UTF-8"

# 4. Explicit D3DMetal Framework & Library Paths
export CX_APPLEGPT_LIBD3DSHARED_PATH="$ENGINE_DIR/lib/external/libd3dshared.dylib"
export CX_APPLEGPTK_LIBD3DSHARED_PATH="$ENGINE_DIR/lib/external/libd3dshared.dylib"
export CX_D3DMETALPATH="$ENGINE_DIR/lib/external/D3DMetal.framework"

echo "=========================================================="
echo "Launching S.T.A.L.K.E.R. Anomaly (3DSS5) with D3DMetal"
echo "  Wine Engine:    $ENGINE_DIR/bin/wine"
echo "  Prefix:         $PREFIX"
echo "  Executable:     $EXE_PATH"
echo "  Task Policy:    taskpolicy -l 0 -t 0 (Low Latency / High Throughput)"
echo "  Msync / Esync:  WINEMSYNC=1 / WINEESYNC=1"
echo "=========================================================="

cd "$HOME/gamma/3dss5/bin"

# Ensure macOS brings the Wine window into foreground focus for DirectInput capture
(
  sleep 2
  osascript -e 'tell application "System Events" to set frontmost of (first process whose name contains "wine" or name contains "Anomaly") to true' 2>/dev/null || true
) &

# Execute Wine with macOS Low-Latency Tier 0 and High-Throughput scheduling
exec taskpolicy -l 0 -t 0 arch -x86_64 "$ENGINE_DIR/bin/wine" "$EXE_PATH" "$@"
