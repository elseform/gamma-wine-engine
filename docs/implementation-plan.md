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
- **DXMT**: cyder-wine-engine has no DXMT build logic itself — it's fetched by a sibling repo (`ogom`, not available to us) into `$WINE_INSTALL/lib/dxmt/{x86_64-unix,x86_64-windows}` and then packed as a separate sidecar archive. DXMT is MIT-licensed (unlike GPTK), so baking it into our `wswine.bundle` tarball is fine license-wise and matches the user's intent ("bundle dxmt... sikarugir engines already do this"). **Decision: do not build DXMT from source — pull the latest prebuilt artifact from `3Shain/dxmt`'s GitHub Actions CI** (via `gh run download`/`gh api` against the repo's default branch, most recent successful workflow run) and install its output directly into `wswine.bundle/lib/wine/x86_64-{unix,windows}/` alongside the stock DLLs as default overrides. No local Meson build, no build-dxmt.sh script needed.
- `sources/dxmt-main-latest/` is currently an empty placeholder — not needed anymore now that DXMT comes from a prebuilt CI artifact rather than a local clone/build.

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

### 3. DXMT: fetch prebuilt CI artifact
- Do not build DXMT locally. Use `gh` (already authenticated) against `3Shain/dxmt` to find the latest successful GitHub Actions workflow run on the default branch and download its build artifact (`gh run list`/`gh run download`, or `gh api` against `/actions/artifacts` if the release isn't published as a formal GitHub Release).
- Write a small `scripts/fetch-dxmt.sh` that automates this lookup + download + extraction into a local staging dir (e.g. `build/dxmt/`), so re-running the pipeline re-fetches a fresh artifact rather than relying on a manually-downloaded file.
- Inspect the downloaded artifact's actual layout to confirm module names/paths (expected shape: `x86_64-unix/*.so` and `x86_64-windows/*.dll`, e.g. `winemetal.so`/`.dll`, `d3d11.dll`, `dxgi.dll` equivalents) — confirm against what the artifact actually contains, don't assume.

### 4. Integrate DXMT into the wine tree
- Copy DXMT's fetched artifact outputs into `install/wine-cx26-x86_64/lib/wine/x86_64-unix/` and `.../x86_64-windows/`, overwriting/supplementing the stock D3D/DXGI modules there.
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

## Progress / what's left (updated 2026-08-24)

### Done
- **Step 1 (bootstrap fork)**: complete. `scripts/`, `patches/` (trimmed), `config/` copied and adapted into this repo; `pack-engine-artifact.sh`/`engine-common.sh` retargeted to stage/tar `wswine.bundle` (pulled forward from step 5, same files). Engine label rebranded to `CX26.3.0-W11-Gamma001` (`config/engine-release.json`, `config/engine-version.txt`) — corrected from an earlier wrong `W10` guess.
- `tools/archives/llvm-mingw-20260616-ucrt-macos-universal.tar.xz` fetched from `mstorsjo/llvm-mingw`'s GitHub release (exact tag/filename match with what `prepare-build-deps.sh` expects).
- **Step 2 (first build milestone) — in progress.** `bash scripts/build-wine.sh --cx 26 --without-vulkan --bootstrap-brew --install-deps` is the running command; deps install into a project-local x86_64 Homebrew at `.brew-x86/` (see `docs/why-no-prebuilt-deps.md` for why nothing pours as a bottle here).
- Two real build-environment bugs hit and fixed along the way (both are environment/tooling issues on this machine, not plan mistakes):
  1. This machine's Xcode 26.6 clang defaults to a native arm64 target even when the whole process runs under `arch -x86_64` (Rosetta doesn't translate the clang binary itself) — `-march=westmere` was being handed to an arm64-target clang and erroring. Fixed by editing the vendored `.brew-x86/Library/Homebrew/hardware.rb` so the `westmere` optflag also carries `-arch x86_64`.
  2. Homebrew's bottled `automake`'s `aclocal`/`automake` scripts hardcode `/usr/local/share/aclocal-*`, which doesn't exist under our `.brew-x86` prefix — broke `gmp`'s `autoreconf` (gmp is a `gnutls` dependency). Fixed in `scripts/env-x86_64.sh`'s `brew_x86_install_runtime()`: extracted the path-rewrite into `_ogom_fix_automake_aclocal()`, and made it pre-install `automake`/`libtool` and patch them *before* anything that autoreconfs, instead of only rewriting once up front (too early to catch automake installed later in the same `brew install` invocation).
- Deps installed so far (`.brew-x86/Cellar/`): `autoconf`, `automake`, `bison`, `ca-certificates`, `flex`, `gettext`, `gmp`, `help2man`, `json-c`, `libidn2`, `libpng`, `libtool`, `libunistring`, `m4`, `pkgconf`.
- Build was deliberately paused right after `gmp` finished (user requested a checkpoint) — safe to resume any time; `brew`/`brew_x86_install_runtime` skip everything already installed.

### Left to do
1. **Resume/finish `--install-deps`**: remaining runtime deps per `build-wine.sh`'s `RUNTIME_DEPS` list — `zlib`, `bzip2`, `freetype`, `libffi`, `gnutls` (and gnutls's own remaining transitive deps beyond `gmp`/`libidn2`, e.g. `nettle`, `p11-kit`, `unbound` — brew will resolve these).
2. **Wine `./configure && make && make install`**: once deps are in, the same `build-wine.sh` invocation continues into patching the Wine source tree, `./configure --prefix=$WINE_INSTALL ...`, then `make`/`make install` into `install/wine-cx26-x86_64/` — this is the long step (native x86_64 Wine build under Rosetta), budget real time for it. Consider running it with `--configure-only` first as an additional checkpoint before committing to the full `make`, per the earlier chunking discussion.
3. **Sanity test standalone**: `wineboot -u`, run a trivial `.exe` directly via the built `bin/wine`, before any packaging/D3DMetal work (plan step 2's own verification note).
4. **Verify Cyder-infra patch order**: confirm the wineserver/ntdll hardening patches apply cleanly without any MapleStory patch ahead of them in sequence (open unknown from step 2 — check `apply_cyder_patch` markers if `build-wine.sh`'s patch-apply step complains).
5. **DXMT (revised — no local build)**: use `gh` against `3Shain/dxmt` to find the latest successful GitHub Actions run (or Release, if one exists) and download its artifact; write `scripts/fetch-dxmt.sh` to automate this. Confirm the artifact's actual module layout (`x86_64-unix/*.so`, `x86_64-windows/*.dll`) once downloaded.
6. **Integrate DXMT** into `install/wine-cx26-x86_64/lib/wine/x86_64-{unix,windows}/`, overwriting/supplementing stock D3D/DXGI modules, DXMT as the default override.
7. **Package as `wswine.bundle`**: run the already-adapted `pack-engine-artifact.sh` (retargeted in step 1) to produce `dist/artifacts/gamma-wine-x86_64-CX26-3-0-W11-Gamma001.tar.xz` — keep DXMT baked into the main archive, keep the `apple_gptk` fail-closed check.
8. **Verification**: standalone tarball extract + `wineboot -u` + DXMT DLL load check; then integration test against `gamma-setup-tool` (local cache file or `file://` URL), full setup flow against a real prefix in `~/gamma`.

## Open questions / unknowns (resolve during the build, not up front)
- Exact DXMT CI artifact layout/module names, and whether `3Shain/dxmt` publishes artifacts as GitHub Releases (simpler, `gh release download`) vs. only as ephemeral Actions run artifacts (needs `gh run download`, may require workflow permissions/retention checks) — confirm once we look.
- Whether any Cyder-infra patch has an undeclared dependency on a MapleStory patch being applied first (patch-apply order).
- Exact behavior needed if DXMT and D3DMetal both claim the same DLL slot at runtime for a given game — may need experimentation once both are wired up and tested against a real STALKER Anomaly session.
