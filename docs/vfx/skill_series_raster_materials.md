# Skill-Series Raster Material Contract

## Purpose

The skill-series renderer combines refined raster brushwork with the existing
procedural and specialized VFX layers. Raster materials are presentation only:
they cannot own target selection, damage, timing authority, status effects, or
collision.

## Composition Matrix

The authoritative composition is:

- 13 unique series bases: `sword_rain`, `moon_wheel`, `feather`, `thorn`,
  `dr_stone`, `black_hole`, `fire`, `lightning`, `water_flow`, `arcane_swamp`,
  `dragon_breath`, `dawn_vitality`, and `shared_branch_vitality`.
- 8 unique Blessing overlays: `dark`, `fire`, `ice`, `light`, `lightning`,
  `poison`, `water`, and `wind`.
- A normal Blessing overlay does not exist. `normal` remains an element taxonomy
  entry only.
- Evolved Blessings provide two element overlays without becoming two Gift
  overlays.

This produces every Skill × Blessing visual variant through runtime composition
without maintaining 104 duplicated source images. A deterministic variant
signature records the series, tier, element list, base path, and overlay paths.

## Visual Language

Each 1254 × 1254 RGBA plate is authoring provenance for anticipation, travel,
contact, and residual components. Runtime does not display or translate the
plate itself. Components whose rectangular bounds overlap another plate cell
use independently alpha-isolated transparent component textures; the original
rectangle remains recorded for source review. Series bases retain their motion
family and palette. Element overlays may change material, palette, noise, and
supporting fragments, but they must not replace the series topology. In
particular, lightning keeps its chain and delayed sky-strike structure.

The material plate uses large color clusters, limited value steps, coarse broken
linework, and readable silhouettes. Reject smooth vector-like edges,
photorealistic texture, noisy microdetail, false seams, mushy alpha edges, and
meaningless repeated motifs.

## Runtime Ownership

`SkillSeriesRasterMaterialVFX2D` is a child of `SkillVFXComposer2D`. The composer
passes the active recipe, tier, Blessing overlays, progress, source, target,
specialized-renderer core positions, and impact timing. The runtime consumes
the mapped phase, anchor, placement, transform, blend, timing, and bounded stack
cadence. Travel follows current core/path positions; contact and ground layers
select matching core landing points; residual enters later and fades
independently. When source and target are equal, core positions remain the
placement authority so area skills do not collapse at the origin. Every runtime
Sprite uses an AtlasTexture backed by an isolated single-component texture or a
strictly smaller plate crop. Existing specialized renderers remain the
motion/topology authority.

Authoritative references:

- `data/skill_series_vfx.json`
- `data/skill_series_raster_composition.json`
- `scripts/systems/skill_series_vfx_catalog.gd`
- `scripts/vfx/skill_vfx_recipe_catalog.gd`
- `scripts/vfx/blessing_vfx_mutation_catalog.gd`
- `scripts/vfx/skill_series_raster_material_vfx_2d.gd`
- `tools/build_skill_series_raster_components.py`
- `tools/build_skill_series_raster_composition_review.py`
- `tests/skill_series_raster_composition_data_test.gd`
- `tests/skill_series_raster_material_vfx_test.gd`

## Crop-First Composition Design Authority

`data/skill_series_raster_composition.json` is the per-plate composition
authority and is marked `runtime_wired`. The runtime adapter consumes it as
presentation data without changing the composer scene tree, timing authority,
or gameplay. The catalog-wide material runtime contract remains the fallback
when a per-series composition entry is unavailable.

Every crop is `[x, y, width, height]` in native 1254-square source pixels.
`native_alpha_bounds` records the non-zero-alpha `[left, top, right, bottom]`
box seen in the reviewed PNG. Stages are always ordered
`anticipation -> travel -> contact -> residual`. Every layer then declares its
anchor, placement rule, local offset, rotation, scale, blend, tint, delay,
lifetime, and tier-specific stack recipe.

Because several authored plate cells have overlapping bounding boxes or touching
alpha islands, source rectangles are provenance/fallback data rather than the
safe runtime texture. Every component therefore also references one trimmed,
alpha-isolated PNG under
`assets/generated/vfx/skill_materials/components/{base|blessing}/` and an
`asset_region` that covers that complete derived texture. The derived pixels
are copied from the source plate without repainting; fully transparent RGB is
cleared to prevent sampling bleed. The reproducible manifest records source and
output SHA-256 hashes, source alpha bounds, isolated dimensions, and anchors.
Runtime must prefer `component.asset_path` over the legacy source region.

The following is a compact audit view. `B/A/M` is the basic/advanced/master
instance count. Exact transforms, timing, overlap, spacing, and secondary
contact layers remain authoritative in the JSON.

| Series | Anticipation | Travel | Contact composition | Residual |
| --- | --- | --- | --- | --- |
| `sword_rain` | `lock_star`, 0.00/0.42 s, orbit 1/1/1 | `blue_crescent`, 0.18/0.38 s, path 3/4/5 | crossed `blue_crescent` + `crystal_debris` | debris drift 2/3/4 |
| `moon_wheel` | spinning `moon_crescent`, 0.00/0.34 s, 1/2/3 | bouncing crescent, 0.12/0.62 s, 2/3/4 | `moon_burst` + outward `moon_shards` | returning shards 2/3/5 |
| `feather` | `feather_fan`, 0.00/0.54 s, 1/2/3 | `feather_dash`, 0.18/0.40 s, 3/5/7 | dash + descending `falling_feathers` | slow fall 3/5/7 |
| `thorn` | clustered `thorn_seed`, 0.00/0.46 s, 1/2/3 | `thorn_run`, 0.22/0.58 s, 3/5/7 | `thorn_bloom` + bud cap | settling bloom 1/2/3 |
| `dr_stone` | `stone_orbit`, 0.00/0.58 s, 3/6/10 | `stone_lance`, 0.20/0.52 s, 3/6/10 | incoming lance + `stone_crater` | crater/dust settle 1/2/3 |
| `black_hole` | `void_ring`, 0.00/0.68 s, 1/2/3 | inward `void_comet`, 0.22/0.66 s, 3/5/8 | `void_collapse` + inward comet fan | contracting ring 1/2/3 |
| `fire` | `fire_lane` telegraph, 0.00/0.30 s, 2/3/4 | ground ignition lane, 0.16/0.48 s, 3/5/7 | `fire_pillar` + `fire_burst` | ember burst 2/3/5 |
| `lightning` | `storm_ring`, 0.00/0.36 s, 1/2/3 | `chain_bolt`, 0.14/0.34 s, 3/5/7 | `sky_impact` + forked bolt | ground arcs 2/4/6 |
| `water_flow` | `tidal_curl`, 0.00/0.44 s, 1/2/3 | `water_stream`, 0.14/0.58 s, 3/5/8 | wash-through stream + `water_splash` | receding curl 1/2/3 |
| `arcane_swamp` | `swamp_crown`, 0.00/0.54 s, 1/2/3 | `swamp_tendril`, 0.18/0.66 s, 3/5/7 | wrapping tendril + `swamp_splash` | persistent pool 1/2/3 |
| `dragon_breath` | `dragon_head`, 0.00/0.40 s, 1/1/2 | sweeping `breath_beam`, 0.16/0.58 s, 1/2/3 | beam tip + `breath_burst` | afterburn burst 1/2/3 |
| `dawn_vitality` | `sun_bloom`, 0.00/0.62 s, 1/2/3 | `rising_leaves`, 0.22/0.74 s, 3/5/8 | bloom pulse + `healing_court` | persistent court 1/2/3 |
| `shared_branch_vitality` | `branch_aura`, 0.00/0.50 s, 1/2/3 | `branch_dash`, 0.16/0.54 s, 3/5/8 | dash surge + `branch_court` | vitality afterimages 3/5/8 |

## Blessing Overlay Application

The eight overlays use their own three local cells instead of recoloring or
moving a complete element plate. Their `shape` values match
`BlessingVFXMutationCatalog`. All are additive accents, inherit the active
base series source/path/contact anchors, and preserve their authored palette
with `#FFFFFF` tint.

| Blessing | Shape | Anticipation / travel / contact crop | Four-stage application |
| --- | --- | --- | --- |
| `dark` | `void_echo` | `void_seed / void_streak / void_burst` | seed 1/2/3; path 2/3/5; burst + streak forks; delayed burst residue |
| `fire` | `turbulent_flare` | `flare_seed / flame_streak / fire_burst` | seed 1/2/3; path 2/3/5; burst + flame forks; ember residue |
| `ice` | `crystal_shard` | `ice_seed / ice_streak / ice_burst` | seed 1/2/3; path 2/3/5; shatter + ice forks; frozen residue |
| `light` | `radiant_halo` | `light_seed / light_streak / light_burst` | halo 1/2/3; path 2/3/5; radiance + streak forks; halo residue |
| `lightning` | `forked_snap` | `bolt_seed / bolt_streak / bolt_burst` | snap 1/2/3; path 2/3/5; burst + bolt forks; arc residue |
| `poison` | `corrosive_split` | `poison_seed / poison_streak / poison_burst` | seed 1/2/3; path 2/3/5; splash + slick forks; puddle residue |
| `water` | `returning_wave` | `water_seed / water_streak / water_burst` | curl 1/2/3; path 2/3/5; splash + stream forks; water residue |
| `wind` | `crescent_stream` | `wind_seed / wind_streak / wind_burst` | pinwheel 1/2/3; path 2/3/5; burst + stream forks; wind residue |

## Composition Guardrails

- Crop before any scale, rotation, placement, or repetition.
- Never attach or translate the full 1254-square plate as a gameplay sprite.
- A whole-region AtlasTexture is valid only when its atlas is an independently
  reviewed single-component texture; it is never valid for a base or Blessing
  multi-object plate.
- Runtime instance count is capped at 24. When Blessings are present, the base
  composition reserves at least one instance for each mapped Blessing stage.
- A repeated travel component may overlap along a path, but its stagger must
  remain visible and its spacing must not reveal neighboring plate cells.
- Contact may combine two or more declared crops only at the same local contact
  anchor. It must not reconstruct the source-sheet layout.
- Residual begins after contact and fades independently. It may reuse a declared
  crop with a different transform, but it may not reveal a new unlisted region.
- The screenshots captured at 11:41-11:42 on 2026-08-08 show the failure mode:
  unrelated plate cells travel and pile up together. Those frames are negative
  references, not target composition.

## Reproducible Review Evidence

Regenerate isolated component assets, import them without a visible window, and
then build native/full-frame evidence:

```bash
python tools/build_skill_series_raster_components.py --project-root .
godot --headless --path . --import
python tools/build_skill_series_raster_composition_review.py \
  --project-root . \
  --output-dir artifacts/skill_series_raster_composition_review_v3 \
  --tier master
```

The review helper writes 39 base and 24 Blessing native component PNGs, two
unscaled native-detail contact sheets, four integrated phase full frames, a
four-phase timeline, and a fixed 3-column by 2-row slice set for every integrated
frame and the timeline. Review evidence is CPU-composed; additive layers use a
screen approximation, while Godot remains the production blend authority.

## Verification

Run `tests/skill_series_raster_composition_data_test.gd`, the focused raster
contract, the VFX suite, affected catalog/content tests,
headless scene/main smoke checks, and the final full regression. Generated art
also requires independent native-detail, integrated full-frame, and fixed 3 × 2
slice review after the final asset or composition change.
