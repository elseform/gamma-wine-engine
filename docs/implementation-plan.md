# gamma-wine-engine: build via repurposed cyder-wine-engine pipeline

## Context

`gamma-setup-tool` currently installs prebuilt Wine engines (`WS12WineCX24.0.7_7`, `WS12WineSikarugir10.0_6`) fetched from the `Sikarugir-App/Engines` GitHub releases. These are CrossOver-based Wine builds with Apple's GPTK4 D3DMetal and DXMT bundled in, used to run the STALKER Anomaly modpack (`~/gamma`) on Apple Silicon. The user wants their own engine build — CrossOver 26.3.0 (Wine 10/11-based) + GPTK4 4.0b1 + DXMT — both to have full control over the build/patch set and to learn how the wine/CrossOver/Metal integration actually works, rather than depending on a third-party binary.

A sibling checkout, `reference/cyder-wine-engine`, is a mature, working pipeline that does almost exactly this (CX26.3.0 → Wine build → packaged engine artifact), built for a different downstream game (MapleStory) and consumer (a "Cyder" launcher, not gamma-setup-tool). The user decided to **repurpose this pipeline directly** rather than build from scratch: fork its scripts/patches into `gamma-wine-engine`, strip what's game-specific, adapt the output format to what `gamma-setup-tool` expects, and add the one piece it's missing (a DXMT build step — cyder-wine-engine delegates that to an unavailable sibling repo `ogom`).

This is still explicitly a **learning/hobby project** — reuse cyder-wine-engine's proven scripts/patches as the base, but the user will be running/adapting each step themselves rather than treating it as a black box.

## Key technical findings that shape this plan

- **cyder-wine-engine's build system**: `scripts/build-wine.sh` drives an out-of-tree `configure && make && make install` of the CrossOver source (`--enable-win64 --enable-archs=i386,x86_64 --with-mingw=llvm-mingw`, host arch forced `x86_64` via `arch -x86_64`, `MACOSX_DEPLOYMENT_TARGET` pinned). It expects `crossover-sources-26.3.0.tar.gz` at `tools/archives/` — **exact filename match already sitting in our `sources/`**, so no rename needed.
- **Patches**: `patches/` has 3 tiers — generic Wine/CrossOver fixes (keep), Cyder-infra reliability patches to wineserver/ntdll (keep — general hardening, not game-specific), and ~20 `maplestory-cx26-*` patches gated behind `--maplestory` (drop — game-specific to MapleStory, not our target). One exception, `maplestory-cx26-message-wait-handoff.patch`, applies unconditionally to all CX26 builds despite its name — needs individual review to decide keep/drop.
- **Output format mismatch (critical adaptation point)**: `pack-engine-artifact.sh` produces a tarball rooted at `wine-x86_64/`, not `wswine.bundle/`. `gamma-setup-tool`'s `installEngine()` (`SetupEngine.swift`) hard-requires the extracted top-level dir be named `wswine.bundle/` (renamed to `wine/`), containing `bin/wine`, optionally `bin/wineserver`, and `lib/`. **Must rename the staging dir / tar root in the packaging step** to `wswine.bundle`.
- **GPTK4/D3DMetal**: cyder-wine-engine deliberately **never bakes GPTK into the engine artifact** (`apple_gptk` is licensed from Apple, not redistributable — the pack script fails closed if it detects `apple_gptk` in the staged tree) and instead resolves it at runtime from an external path with `DYLD_FALLBACK_LIBRARY_PATH`. This actually matches what `gamma-setup-tool` already does today (`installGPTK4Binaries` copies from its own bundled `Resources/gptk4/` into `Contents/Frameworks/renderer/d3dmetal`, independent of the wine tarball). **Decision: keep GPTK4 external/unbundled, consistent with both upstream precedent and gamma-setup-tool's current code — no engine-tarball changes needed for GPTK.**
- **DXMT**: cyder-wine-engine has no DXMT build logic itself — it's fetched by a sibling repo (`ogom`, not available to us) into `$WINE_INSTALL/lib/dxmt/{x86_64-unix,x86_64-windows}` and then packed as a separate sidecar archive. DXMT is MIT-licensed (unlike GPTK), so baking it into our `wswine.bundle` tarball is fine license-wise and matches the user's intent ("bundle dxmt... sikarugir engines already do this"). **Decision: write our own DXMT fetch+build step** (clone `3Shain/dxmt`, build, install into `wswine.bundle/lib/wine/x86_64-{unix,windows}/` alongside the stock DLLs as default overrides) — this is genuinely new work, not present anywhere in the reference repo.
- `sources/dxmt-main-latest/` is currently an empty placeholder — needs the actual DXMT source cloned in.

## Plan

### 1. Bootstrap the fork
- Copy the reusable pieces of `reference/cyder-wine-engine` into `gamma-wine-engine`: `scripts/` (build-wine.sh, build-media-stack.sh, prepare-build-deps.sh, env-x86_64.sh, bundle-wine-dylibs.sh, strip-wine-install.sh, sign-wine.sh, pack-engine-artifact.sh, rebuild-wine-host-unix.sh), `patches/` (generic + Cyder-infra tiers only, drop `maplestory-cx26-*` except reviewing the unconditional one), `config/engine-release.json` as a template, `.env.example`.
- Skip: `build-graphics-stack.sh`/MoltenVK/DXVK machinery entirely — not needed since D3DMetal is the primary renderer, not the DXVK-validation path.
- Rename/rebrand engine identity in `config/engine-release.json` and version-label plumbing (`cyder_engine_version_label`-style helpers) from `CX26.3.0-W11-Cyder011` to a gamma-specific label (e.g. `CX26.3.0-W10-Gamma001`), so builds are clearly distinguishable from upstream Cyder ones.
- Add `tools/archives/crossover-sources-26.3.0.tar.gz` (symlink or copy from `sources/`).

### 2. First build milestone — plain wine, no DXMT/D3DMetal yet
- Follow the adapted `build-wine.sh --cx 26 --without-vulkan` path (no `--maplestory`, no MoltenVK/DXVK steps) to produce a working `install/wine-cx26-x86_64/` tree.
- Sanity test standalone: `wineboot -u`, run a trivial `.exe` (e.g. `notepad.exe` or `cmd.exe /c echo hi`) directly via the built `bin/wine`, before any packaging or D3DMetal work — confirms the core build is sound.
- Note open unknown: whether all "Cyder-infra" patches (wineserver/ntdll hardening) apply cleanly without the MapleStory patches ahead of them in sequence — verify patch order/dependencies via `apply_cyder_patch` markers, adjust `build-wine.sh`'s patch list section if a Cyder patch turns out to assume a MapleStory patch was already applied.

### 3. DXMT: fetch and build
- `git clone https://github.com/3Shain/dxmt` into `sources/dxmt-main-latest/` (replacing the empty placeholder), or as a separate `tools/archives` step consistent with the rest of the pipeline.
- Read DXMT's own build docs (Meson-based, per its README) to determine build command/dependencies on macOS/x86_64; this is new ground not covered by cyder-wine-engine — write a new `scripts/build-dxmt.sh` modeled on the shape of `build-media-stack.sh` (install deps, meson setup/compile, validate output files exist).
- Output layout should mirror D3DMetal's own split — verify against DXMT's actual build output once built, expected to produce `x86_64-unix/*.so` and `x86_64-windows/*.dll` (e.g. `winemetal.so`/`.dll`, `d3d11.dll`, `dxgi.dll` equivalents — confirm exact module names from DXMT's own output).

### 4. Integrate DXMT into the wine tree
- Copy DXMT's built outputs into `install/wine-cx26-x86_64/lib/wine/x86_64-unix/` and `.../x86_64-windows/`, overwriting/supplementing the stock D3D/DXGI modules there.
- Decide the default DLL-override policy where DXMT and D3DMetal overlap (both can provide d3d11/dxgi-equivalent paths) — default to DXMT for the DLLs it replaces since it's being baked into the engine itself, while GPTK4/D3DMetal remains the externally-wired path gamma-setup-tool already manages (per the decision in the findings section, this keeps the two integration points cleanly separated rather than fighting over the same DLL slot).

### 5. Package as `wswine.bundle`
- Adapt `pack-engine-artifact.sh`: change `ENGINE_TREE="$STAGING/wine-x86_64"` and the corresponding `tar -cf - wine-x86_64` line (and the `engine-common.sh` version-lookup path) to use `wswine.bundle` instead, so the tarball extracts directly into what `gamma-setup-tool`'s `installEngine()` expects.
- Keep DXMT inside this main archive now (not a separate sidecar `.tar.zst` as cyder does), since the goal is a self-contained tarball; drop the `pack-graphics-payloads.sh` DXVK/DXVK2 sidecar logic entirely (not used here).
- Keep the `apple_gptk` exclusion/fail-closed check as-is — GPTK must never be baked in.
- Output a locally-testable `.tar.xz`, e.g. `dist/artifacts/gamma-wine-x86_64-CX26-3-0-W10-Gamma001.tar.xz`.

### 6. Verification
- Standalone: extract the produced tarball manually, confirm `wswine.bundle/bin/wine` + `bin/wineserver` are executable, `wineboot -u` succeeds, DXMT DLLs load (check via `winedbg`/log output or a small DirectX test exe) before touching gamma-setup-tool at all.
- Integration: point `gamma-setup-tool` at the local tarball for a manual test — either temporarily add the new engine id to `SetupDefaults.supportedEngines` / point its download URL at a local `file://` path or a manually-placed cache file at `~/Library/Application Support/Sikarugir/Engines/<engineName>.tar.xz` (the tool checks local cache before downloading), then run the existing setup flow end-to-end against a real game prefix in `~/gamma`. Do not modify gamma-setup-tool's source as part of this plan unless the tarball format needs a deviation beyond the `wswine.bundle` rename already covered in step 5.

## Files/dirs to create in `gamma-wine-engine`
- `scripts/` — adapted from cyder-wine-engine (see step 1)
- `patches/` — trimmed patch set (generic + Cyder-infra tiers)
- `config/engine-release.json` — gamma's own version/label config
- `tools/archives/` — input archives (CrossOver source, later DXMT if archived rather than git-cloned)
- `docs/` — the user's own build notes/learnings as they go (optional, light)

## Open questions / unknowns (resolve during the build, not up front)
- Exact DXMT build command/deps and output module names — depends on DXMT's own README once cloned.
- Whether any Cyder-infra patch has an undeclared dependency on a MapleStory patch being applied first (patch-apply order).
- Exact behavior needed if DXMT and D3DMetal both claim the same DLL slot at runtime for a given game — may need experimentation once both are wired up and tested against a real STALKER Anomaly session.
