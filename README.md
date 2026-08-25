# gamma-wine-engine

**Custom, high-performance Wine 11.0 / CrossOver 26.3.0 engine tailored for S.T.A.L.K.E.R. Anomaly & G.A.M.M.A. on Apple Silicon (macOS).**

---

## Overview

`gamma-wine-engine` provides a standalone, relocatable Wine 11 runtime and packages the production `wswine.bundle` tarball (`gamma-wine-x86_64-CX26-3-0-W11-Gamma001.tar.xz`) used by `gamma-setup-tool`.

> 📖 **Looking for a step-by-step setup guide?** See [How-To Use Guide](docs/how-to-use.md) for instructions on bootstrapping a prefix and creating a standalone `.app` bundle from only the `.tar.xz` engine archive.

### Key Features:
- **Base Runtime**: CrossOver 26.3.0 built on **Wine 11.0** (`x86_64` under Rosetta 2 on Apple Silicon).
- **Dual Metal Graphics Architecture**:
  - **Apple D3DMetal (GPTK 4.0b1)**: Auto-activated by default for 64-bit Direct3D 11/12 rendering via Apple Metal.
  - **DXMT**: Bundled as a selectable Direct3D 11/10 backend (and auto-selected for 32-bit processes).
- **Dynamic Backend Switcher (`cxcompatdb.so`)**: Intercepts process startup to route graphics backends dynamically using `GAMMA_GRAPHICS_BACKEND=d3dmetal` or `dxmt` with zero DLL file modifications in the prefix.
- **Darwin Mach Semaphore Sync (`WINEMSYNC=1`)**: In-process shared memory thread synchronization, eliminating wineserver IPC overhead and micro-stuttering across X-Ray Engine's worker threads.
- **Engine-Level Stability Patches**:
  - `win32u.so`: Clean message-wait event loop preventing UI/menu click deadlocks.
  - `ntdll.so`: Hardware memory barrier in `NtFlushProcessWriteBuffers` avoiding expensive Mach register queries that cause thread stalls under Rosetta 2.
- **Self-Contained Portability**: All runtime dependencies (`gnutls`, `freetype`, `libpng`, `zlib`, `gettext`, `libunistring`) are bundled with `@loader_path` relative linking.

---

## Engine Locations

| Type | Path | Purpose |
|---|---|---|
| **Development Staging Tree** | `install/wine-cx26-x86_64/` | Live uncompressed build tree used for direct testing (`bin/wine`, `bin/wineserver`, `lib/d3dmetal/`) |
| **Packaged Release Tarball** | `dist/artifacts/gamma-wine-x86_64-CX26-3-0-W11-Gamma001.tar.xz` | Codesigned, stripped, standalone production archive (~86 MB) |
| **Setup Tool Asset** | `gamma-setup-tool/sources/GAMMASetupTool/Resources/wine-engine/CX26-3W11-Gamma0-1.tar.xz` | Bundled asset embedded in `GAMMA Setup Tool.app` |

---

## Dedicated Scripts

### 1. Recreate Prefix (`scripts/recreate-prefix.sh`)
Wipes and bootstraps the prefix from scratch with all required winetricks, registry keys, and drive mappings:
```bash
bash scripts/recreate-prefix.sh
```

### 2. Launch Game (`scripts/launch-3dss5.sh`)
Launches S.T.A.L.K.E.R. Anomaly directly using the test prefix with low-latency taskpolicy and optimal performance flags:
```bash
bash scripts/launch-3dss5.sh -dbg
```
*(Pass any game arguments such as `-dbg`, `-nointro`, etc. directly to the script.)*

### 3. Generate Native macOS App Bundle (`scripts/create-app-bundle.sh`)
Builds a standalone `dist/S.T.A.L.K.E.R. Anomaly.app` bundle for direct launching from Finder/Dock with native WindowServer priority and display refresh sync.

**Configuring before creation:**
```bash
# Via CLI Flags & Custom Variables:
bash scripts/create-app-bundle.sh --no-hud -e DXVK_HUD=fps -e MY_VAR=value

# Or simply pass any KEY=VALUE pairs:
bash scripts/create-app-bundle.sh DXVK_HUD=fps FOO=bar --game-args="-dbg -nointro"

# Or via persistent config template:
cp config/app.env.example config/app.env
# Edit config/app.env as desired, then run:
bash scripts/create-app-bundle.sh
```

**Launch the App:**
```bash
open "dist/S.T.A.L.K.E.R. Anomaly.app"
```
*(You can also edit `dist/S.T.A.L.K.E.R. Anomaly.app/Contents/Resources/app.env` directly at any time.)*

---

## How to Create & Configure a New Prefix Manually

If you wish to create a custom prefix without the script, follow these steps:

### Step 1: Initialize Prefix
```bash
export WINE_DIR="$PWD/install/wine-cx26-x86_64"
export WINEPREFIX="$HOME/Library/Application Support/gamma-test-prefix"

# Clean prior server instance
arch -x86_64 "$WINE_DIR/bin/wineserver" -k 2>/dev/null || true
mkdir -p "$WINEPREFIX"

# Bootstrap
WINEPREFIX="$WINEPREFIX" arch -x86_64 "$WINE_DIR/bin/wine" wineboot -u
WINEPREFIX="$WINEPREFIX" arch -x86_64 "$WINE_DIR/bin/wineserver" -w
```

### Step 2: Configure Drive Mappings & User Profiles
```bash
# Drive C: and Z:
mkdir -p "$WINEPREFIX/dosdevices"
ln -sfn "/" "$WINEPREFIX/dosdevices/z:"
ln -sfn "../drive_c" "$WINEPREFIX/dosdevices/c:"

# Drive G: (pointing to your game installation folder)
ln -sfn "$HOME/gamma" "$WINEPREFIX/dosdevices/g:"

# User Profile Symlinks
mkdir -p "$WINEPREFIX/drive_c/users/Sikarugir"
ln -sfn "Sikarugir" "$WINEPREFIX/drive_c/users/crossover"
ln -sfn "Sikarugir" "$WINEPREFIX/drive_c/users/$USER"
```

### Step 3: Set Registry Overrides (DllOverrides & Drivers)
```bash
WINEPREFIX="$WINEPREFIX" arch -x86_64 "$WINE_DIR/bin/wine" reg add "HKEY_CURRENT_USER\Software\Wine\Drivers" /v Graphics /t REG_SZ /d mac /f
WINEPREFIX="$WINEPREFIX" arch -x86_64 "$WINE_DIR/bin/wine" reg add "HKEY_CURRENT_USER\Software\Wine\DllOverrides" /v d3d11 /t REG_SZ /d builtin /f
WINEPREFIX="$WINEPREFIX" arch -x86_64 "$WINE_DIR/bin/wine" reg add "HKEY_CURRENT_USER\Software\Wine\DllOverrides" /v dxgi /t REG_SZ /d builtin /f
WINEPREFIX="$WINEPREFIX" arch -x86_64 "$WINE_DIR/bin/wine" reg add "HKEY_CURRENT_USER\Software\Wine\DllOverrides" /v d3d12 /t REG_SZ /d builtin /f
WINEPREFIX="$WINEPREFIX" arch -x86_64 "$WINE_DIR/bin/wine" reg add "HKEY_CURRENT_USER\Software\Wine\DllOverrides" /v "*d3dcompiler_43" /t REG_SZ /d "native,builtin" /f
WINEPREFIX="$WINEPREFIX" arch -x86_64 "$WINE_DIR/bin/wine" reg add "HKEY_CURRENT_USER\Software\Wine\DllOverrides" /v "*d3dcompiler_47" /t REG_SZ /d "native,builtin" /f
WINEPREFIX="$WINEPREFIX" arch -x86_64 "$WINE_DIR/bin/wine" reg add "HKEY_CURRENT_USER\Software\Wine\DllOverrides" /v "*d3dx9_43" /t REG_SZ /d "native,builtin" /f
WINEPREFIX="$WINEPREFIX" arch -x86_64 "$WINE_DIR/bin/wine" reg add "HKEY_CURRENT_USER\Software\Wine\DllOverrides" /v "*d3dx10_43" /t REG_SZ /d "native,builtin" /f
WINEPREFIX="$WINEPREFIX" arch -x86_64 "$WINE_DIR/bin/wine" reg add "HKEY_CURRENT_USER\Software\Wine\DllOverrides" /v "*d3dx11_43" /t REG_SZ /d "native,builtin" /f
WINEPREFIX="$WINEPREFIX" arch -x86_64 "$WINE_DIR/bin/wine" reg add "HKEY_CURRENT_USER\Software\Wine\DllOverrides" /v "*msvcp140" /t REG_SZ /d "native,builtin" /f
WINEPREFIX="$WINEPREFIX" arch -x86_64 "$WINE_DIR/bin/wine" reg add "HKEY_CURRENT_USER\Software\Wine\DllOverrides" /v "*vcruntime140" /t REG_SZ /d "native,builtin" /f
WINEPREFIX="$WINEPREFIX" arch -x86_64 "$WINE_DIR/bin/wine" reg add "HKEY_CURRENT_USER\Software\Wine\DllOverrides" /v "*concrt140" /t REG_SZ /d "native,builtin" /f
WINEPREFIX="$WINEPREFIX" arch -x86_64 "$WINE_DIR/bin/wine" reg add "HKEY_CURRENT_USER\Software\Wine\DllOverrides" /v "winemenubuilder.exe" /t REG_SZ /d "" /f
```

### Step 4: Install Winetricks Verbs
```bash
WINEPREFIX="$WINEPREFIX" bash scripts/winetricks.sh -q \
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

## How to Launch the Game Manually

To run the game with full performance and DirectInput mouse capture:

```bash
export WINEPREFIX="$HOME/Library/Application Support/gamma-test-prefix"
export WINEMSYNC=1
export ROSETTA_ADVERTISE_AVX=1
export MTL_HUD_ENABLED=1

# Change to the game's bin directory so xrCore loads local DLLs
cd "$HOME/gamma/3dss5/bin"

# Launch Anomaly
arch -x86_64 "$PWD/install/wine-cx26-x86_64/bin/wine" "G:\3dss5\bin\AnomalyDX11AVX.exe" -dbg
```

---

## Build & Maintenance Commands

- **Build Wine from Source**:
  ```bash
  bash scripts/build-wine.sh --cx 26 --without-vulkan
  ```
- **Install Renderers (D3DMetal + DXMT)**:
  ```bash
  bash scripts/install-renderers.sh install/wine-cx26-x86_64
  ```
- **Package Release Archive**:
  ```bash
  bash scripts/pack-engine-artifact.sh --xz --force
  ```
