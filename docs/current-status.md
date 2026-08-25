# Current Status & Maintenance Guide

## Current State (August 2026)

All development, stability fixes, and prefix bootstrap scripts for `gamma-wine-engine` are **100% verified and operational**:

1. **Wine 11.0 / CrossOver 26.3.0 Host Build**:
   - Built out-of-tree targeting macOS 10.15+ on `x86_64` under Rosetta 2.
   - Installed to `install/wine-cx26-x86_64/`.

2. **Critical Engine Stability Fixes**:
   - **`win32u.so` (`dlls/win32u/message.c`)**: Reverted legacy MapleStory message loop hack, restoring standard `NtWaitForMultipleObjects` and eliminating UI click hangs.
   - **`ntdll.so` (`dlls/ntdll/unix/virtual.c`)**: Replaced expensive Mach register query walk in `NtFlushProcessWriteBuffers` with a hardware memory fence (`__sync_synchronize()`), preventing thread deadlocks on Apple Silicon.
   - **`cxcompatdb.c`**: Dynamic backend router that automatically loads GPTK 4.0b1 D3DMetal for 64-bit and DXMT for 32-bit with full DllOverrides.

3. **Prefix Recreation & Launch Scripts**:
   - **Recreate Script (`scripts/recreate-prefix.sh`)**: Cleanly wipes and bootstraps `~/Library/Application Support/gamma-test-prefix` with winetricks (`d3dx9_43`, `d3dx11_43`, `d3dcompiler_43`, `d3dcompiler_47`, `vcrun2022`, `win10`, `sound=coreaudio`) and drive mappings (`G:` -> `$HOME/gamma`).
   - **Launch Script (`scripts/launch-3dss5.sh`)**: Launches `AnomalyDX11AVX.exe` with `WINEMSYNC=1`, `ROSETTA_ADVERTISE_AVX=1`, and proper working directory.

4. **Production Release Artifacts**:
   - `dist/artifacts/gamma-wine-x86_64-CX26-3-0-W11-Gamma001.tar.xz` (~86 MB, signed & verified).
   - Synced to `gamma-setup-tool/sources/GAMMASetupTool/Resources/wine-engine/CX26-3W11-Gamma0-1.tar.xz`.
