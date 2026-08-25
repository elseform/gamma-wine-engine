# DXMT on CX26: Handoff / Known-Broken

## Summary

DXMT does not work on this repo's CX26 engine (`CX26-3W11-Gamma0-1`). D3DMetal
works fine and is the only functional renderer right now. This was
investigated at length; root cause is narrowed down but not fixed.

## Symptom

With `DXMT=1` (or `GAMMA_GRAPHICS_BACKEND=dxmt`), the game exe fails to start:

```
0024:err:module:import_dll Library winemetal.dll (which is needed by L"C:\windows\system32\DXGI.DLL") not found
0024:err:module:import_dll Library DXGI.DLL (which is needed by L"C:\windows\system32\d3d11.dll") not found
0024:err:module:import_dll Library winemetal.dll (which is needed by L"C:\windows\system32\d3d11.dll") not found
0024:err:module:import_dll Library d3d11.dll (which is needed by L"G:\3dss5\bin\AnomalyDX11AVX.exe") not found
0024:err:module:loader_init Importing dlls for L"G:\3dss5\bin\AnomalyDX11AVX.exe" failed, status c0000135
```

`cxcompatdb` correctly detects and activates the `dxmt` backend (logs
`graphics backend=dxmt machine=x86_64-windows path=.../lib/dxmt`). `d3d11.dll`
and `dxgi.dll` load fine as builtin. Only `winemetal.dll` — DXMT's Metal
unixlib bridge — fails, taking DXGI/d3d11 down with it since they depend on
it.

## What was ruled out

Tested independently, all identical failure:

- `cxcompatdb`'s dynamic `add_load_order_override(winemetal=b)` (the normal path)
- Persistent registry override: `HKCU\Software\Wine\DllOverrides\winemetal=builtin`
- `native,builtin` fallback order instead of `builtin` alone
- Baking `winemetal.dll` + `winemetal.so` directly into the default
  `lib/wine/x86_64-windows` / `x86_64-unix` (the same location where
  `d3d11.dll`/`dxgi.dll` succeed) instead of the separate `lib/dxmt` dir
- Three different DXMT builds: the vanilla `3Shain/dxmt` CI artifact fetched
  by `scripts/1_build/fetch-dxmt.sh`, the one currently in `build/dxmt`, and
  the **exact build `gamma-setup-tool` downloads and ships for the Sikarugir
  (CX24) engine** (cached at
  `~/Library/Caches/stalker-gamma-sikarugir-setup/dxmt/dxmt-d31278d4….zip`) —
  all three fail identically on this CX26 engine.

That last point matters: it rules out "wrong/incompatible DXMT build" as the
cause. The same DXMT binaries that work (see below) fail here.

## What's confirmed working elsewhere

`/Users/elseform/Applications/stalker-gamma-recs.app` (Wineskin app on
`SikarugirCX 24.0.7`, i.e. CrossOver 24, built by `gamma-setup-tool`) runs
DXMT successfully — confirmed live: flipped its `Info.plist` `D3DMETAL`/`DXMT`
keys and watched `AnomalyDX11.exe` actually run under DXMT. Its
`winemetal.dll` is baked directly into the default `lib/wine/x86_64-windows`
(no separate switchable directory), with no `.so` counterpart present
anywhere in that tree at all — a different runtime story than CX26's
`cxcompatdb`-mediated `lib/dxmt` switch entirely.

`gamma-setup-tool` (`sources/GAMMASetupCore/SetupEngine.swift:741`) itself
disables DXMT (and GPTK4/D3DMetal) installation when `engine ==
gammaWine26Engine` (i.e. this exact CX26 artifact) — but that guard also
disables GPTK4 for CX26, and GPTK4/D3DMetal demonstrably works here, so it
reads as "CX26 is self-contained, don't inject external renderer payloads,"
not "DXMT is known-broken on CX26." Not a real signal either way.

## Root cause (narrowed, not confirmed)

The failure happens *before* `find_builtin_dll` is ever called for
`winemetal.dll` — confirmed via `WINEDEBUG=+module` trace: every other DLL in
the chain (`d3d11.dll`, `dxgi.dll`, and everything in the boot sequence)
prints `find_builtin_dll looking for "X.dll"` before mapping successfully.
`winemetal.dll` never does; it goes straight from
`load_dll looking for L"winemetal.dll" in (null)` to
`Failed to load module L"winemetal.dll"; status=c0000135` with zero trace
output in between.

That points at an early-exit inside `find_dll_file()` in
`build/cx26/sources/wine/dlls/ntdll/loader.c`, upstream of the builtin search
— i.e. somewhere in the apiset lookup (`find_apiset_dll`), the activation
context / SxS manifest lookup (`find_actctx_dll`), or `find_basename_module`,
all called before `search_dll_file`/`find_builtin_without_file`/
`find_builtin_dll` are ever reached. Traced through `find_apiset_dll` and
`find_actctx_dll` by hand; neither one has an obvious reason to special-case
a name like `winemetal.dll` (both look generic, name-agnostic). Did not reach
a smoking gun before time was cut off. `find_basename_module` (checks for an
already-loaded module by basename) was not fully ruled out.

**Nothing in `cxcompatdb.c` or the override/registry layer can fix this** —
the rejection happens inside CrossOver's own `ntdll` module-loading code,
below anything `cxcompatdb` or `wine reg add` can influence. Every
override/placement lever available from outside `ntdll` was tried and behaves
identically to no override at all.

## What would actually move this forward

1. Instrument `ntdll` directly: add `ERR()`/temp `fprintf` prints into
   `find_apiset_dll`, `find_actctx_dll`, `find_basename_module`, and the top
   of `find_dll_file` in `build/cx26/sources/wine/dlls/ntdll/loader.c`,
   rebuild via `scripts/1_build/build-wine.sh`, and get an actual return-value
   trace for the `winemetal.dll` lookup specifically. This is the direct way
   to find the exact early-exit branch. Not attempted yet — requires a full
   wine rebuild, not just the standalone `cxcompatdb.so`
   (`scripts/1_build/build-cyder-cxcompatdb.sh` only rebuilds the plugin, not
   `ntdll.so` itself).
2. Once the exact branch is found, decide whether it's patchable (add to
   `patches/`, matching the existing pattern of small upstream/CX behavior
   patches already in this repo) or whether it's fundamental to how this
   CrossOver version's loader works.
3. Cross-check against `stalker-gamma-recs.app`'s CX24 `ntdll.so` — if the
   same code path exists there and behaves differently for `winemetal.dll`,
   diffing CX24 vs CX26 loader.c around that logic would confirm the
   regression/version-specific cause directly instead of guessing.

## Current state / workaround

DXMT is left wired up in `cxcompatdb.c` and `install-renderers.sh` (staged in
`lib/dxmt`, selectable via `DXMT=1`) since the plumbing itself is correct and
harmless — it just doesn't work. D3DMetal is fully functional and is what
`scripts/interactive-setup.sh` and `docs/how-to-use.md` assume by default. No
code changes were made as part of this investigation beyond throwaway test
files in a live `.app`, which were reverted.

## Resolution

**Status: Fixed.**

The root cause was that `winemetal.dll` (the PE file) was only placed in `lib/dxmt/x86_64-windows` and never copied to the default `lib/wine/x86_64-windows` directory during engine assembly.

In CX26, `ntdll`'s `load_dll` restricts builtin PE loading via `find_builtin_without_file`. If a DLL doesn't have a fake DLL generated in `C:\windows\system32`, it will only be found if it's placed in `system_dll_path` (which points to `lib/wine/x86_64-windows`).

Since `wineboot -u` only generates fake DLLs for files it finds in `lib/wine/x86_64-windows`, `winemetal.dll` never got a fake DLL, causing the PE loader to fail early with `STATUS_DLL_NOT_FOUND`. (D3DMetal's `d3d11.dll` worked because a generic `d3d11.dll` PE file already exists in `lib/wine`).

**The Fix:**
`scripts/1_build/install-renderers.sh` was updated to explicitly copy `winemetal.dll` to `lib/wine/x86_64-windows/`. This allows `wineboot -u` to generate the fake DLL for it, satisfying the PE loader, while `cxcompatdb` continues to correctly swap the `.so` unixlib path at runtime.
