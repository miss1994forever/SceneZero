# Assets3D

Place bundled `.usdz` scene assets here.

Recommended first assets:

- `Human.usdz`
- `Chair.usdz`
- `Table.usdz`
- `Sofa.usdz`
- `Desk.usdz`
- `Bookcase.usdz`
- `Bed.usdz`
- `NightStand.usdz`
- `LampStand.usdz`

Current bundled furniture props:

- `Human.usdz` is converted from Quaternius Background Posed Humans Pack
  `Female_Standing` OBJ asset. Quaternius marks the pack as CC0.
- `Chair.usdz`, `Table.usdz`, `Sofa.usdz`, `Desk.usdz`, `Bookcase.usdz`,
  `Bed.usdz`, and `NightStand.usdz` are converted from Quaternius Ultimate
  Furniture Pack OBJ assets. Quaternius marks the pack as CC0.
- `LampStand.usdz` is converted from Kenney Furniture Kit `lampRoundFloor`.
  Kenney assets are CC0.

Runtime note:

- Bundled USDZ files are loaded first.
- If a USDZ is missing or fails to load, the app falls back to procedural
  RealityKit primitives in `ARSceneController.swift`.

Rules:

- Keep each model lightweight, ideally 1-5 MB.
- Prefer static white-box / low-poly models.
- Keep file names aligned with `AssetPreset.bundleModelName`.
- The app must keep working if any file is missing; RealityKit primitive fallback remains required.
