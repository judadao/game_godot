# Can Use Town Prototype Assets

This folder contains curated prototype PNG assets that are safe to use for
town scene assembly.

Use these for prototype scene replacement only. They are cleaner than concept-board crops, but still require manual review before production.

## Folders

- `npc/`: auto-sliced NPC proxy PNGs.
- `building/`: auto-sliced building/facility proxy PNGs.
- `prop/`: auto-sliced street dressing and prop proxy PNGs.
- `tileset/`: auto-sliced terrain/building-module/tile proxy PNGs.
- `background/`: preferred v3 parallax strips only.
- `ui/`: auto-sliced UI component proxy PNGs.
- `source_sheets/`: copied source sheets used for slicing.
- `contact_sheets/`: quick visual review sheets per category.
- `manifests/can_use_manifest.json`: source crop, size, and prototype/final-needed metadata.

## Rules

- Do not mark these as final art yet.
- Keep `production_status: prototype_only` until reviewed.
- Disable filtering and mipmaps in Godot imports.
- World objects should use bottom-center pivots and explicit `visual_rect`, `collision_rect`, and `interaction_rect` contracts.
- UI should be rebuilt as reusable 9-slice components before final use.

## Asset Count

Total assets in manifest: 168

## Recommended First Runtime Pass

Use `manifests/recommended_runtime_assets.json` for semantic aliases such as
`mayor`, `item_shop`, `blacksmith`, `portal`, `notice_board`, `bench`, and
`parallax_clouds`. The numbered auto-slice filenames are intentionally kept
stable, but the recommendation manifest is the easier entry point for scene
assembly.

## Background / Parallax

The preferred usable background strips are the v3 files. These were generated
as dedicated parallax layers instead of cropped from a mixed concept board, so
they avoid the previous cut-off objects and foreground contamination.

- `background/parallax_clouds_strip_v3.png`
- `background/parallax_mountains_strip_v3.png`
- `background/parallax_forest_strip_v3.png`
- `background/parallax_rooftops_strip_v3.png`

The older `_01` and `_v2` strips were removed from `background/` so runtime
wiring cannot accidentally select the cropped/mixed versions.

Suggested `ParallaxLayer.motion_scale` values:

- Clouds: `0.05 - 0.10`
- Mountains: `0.12 - 0.18`
- Forest: `0.25 - 0.35`
- Rooftops: `0.45 - 0.60`

`contact_sheets/background_v3_contact_sheet.png` is the current visual review
sheet. The v3 strip manifests are recorded in
`manifests/background_v3_manifest.json`.

## Known Cleanup Needed

- Some `npc_npc_archetype_*` files include props or side-view pairs.
- `npc_asset_021.png` is not an NPC and should not be used as a character.
- `building_building_facility_004.png` is a grouped strip, not a single
  building sprite.
- Many `prop_prop_street_dressing_*` files are grouped mini-sheets and should be
  re-sliced before they are used as individual scene objects.
- UI files are prototype component sources. Large windows should become
  `StyleBoxTexture` / 9-slice components before final runtime use.

## Background Asset Notes

The `background/*_v3.png` files are the preferred runtime proxy backgrounds.
They were regenerated as separated parallax layers instead of cropped from the
town panorama.

Recommended runtime order:

1. `parallax_clouds_strip_v3.png` with very slow motion.
2. `parallax_mountains_strip_v3.png` with slow motion.
3. `parallax_forest_strip_v3.png` with medium motion.
4. `parallax_rooftops_strip_v3.png` as the nearest background skyline.

Deprecated cropped backgrounds were removed from `background/`. Full-width town
concept references now live in `concept/town/main_horizontal_concept/`.

All current backgrounds are `internal_prototype_only`; final release assets
still need review and approval.
