# GAMMA Wine Engine Adapter

## Project identity

- Project root: `../gamma-project`
- Repository: `gamma-wine-engine`
- Role: `supporting-application`

Read `../gamma-project/AGENTS.md` before work. Shared safety and cross-repository
policy remain canonical there. This repository owns the custom Wine 11.0 /
CrossOver 26.3.0 engine build pipeline, patches, backend packaging (D3DMetal,
DXMT, DXVK, wined3d), and release artifacts (`dist/artifacts/*.tar.xz`).

The engine tarball is consumed as a bundled asset by `gamma-setup-tool`; the
`.app` this repo can also build directly (`scripts/interactive-setup.sh`) is
elseform's own GAMMA runtime wrapper. `fetch-dxmt.sh` pulls a prebuilt DXMT
CI artifact into `sources/dxmt` — a build input, distinct from the `dxmt`
source-authority checkout resolved via `gamma-project`'s
`project-paths-get.py --field dxmt_root`; do not conflate the two.
