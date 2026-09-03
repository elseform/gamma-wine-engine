# GAMMA Wine Engine Adapter

## Project identity

- Project root: `../gamma-project`
- Repository: `gamma-wine-engine`
- Role: `supporting-application`

Read `../gamma-project/AGENTS.md` before work. Shared safety and cross-repository
policy remain canonical there. This repository owns the custom Wine 11.0 /
CrossOver 26.3.0 engine build pipeline, patches, D3DMetal/DXMT backend
packaging, WineD3D fallback, and release artifacts (`dist/artifacts/*.tar.zst`).

The engine tarball is consumed as a bundled asset by `gamma-setup-tool`; the
`.app` this repo can also build directly (`scripts/interactive-setup.sh`) is
elseform's own GAMMA runtime wrapper. `fetch-dxmt.sh` pulls a prebuilt DXMT
CI artifact into `renderers/dxmt` — a build input, distinct from the `dxmt`
source-authority checkout resolved via `gamma-project`'s
`project-paths-get.py --field dxmt_root`; do not conflate the two.
