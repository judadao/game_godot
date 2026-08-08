# Reusable Combat VFX Raster Library

This folder contains presentation-only raster components that can be recolored,
scaled, rotated, mirrored, layered, and timed by combat VFX scenes. These assets
never own damage, targets, status effects, movement, or progression.

The first reviewed batch contains eight atlases and 68 independently cropped
components: 12 ground, 12 kinetic, 32 atmospheric, and 12 utility parts.
No atlas in this folder is referenced by a runtime scene, shader, profile, or
skill catalog yet; this batch is preserved for later selection.

## Library contract

- Atlases use one documented strict grid: `3 x 2` at `1536 x 1024` with
  `512 x 512` cells, or `4 x 4` at `1252 x 1252` with `313 x 313` cells.
- Every cell is independent, padded, and must not cross a cell edge.
- Runtime-ready atlases must contain a real alpha channel with transparent corners.
- Source atlases may retain a flat black generation background when the sibling
  README labels them as source-only; runtime consumers use the alpha derivative.
- Color-neutral masks are preferred where a skill needs palette overrides.
- A composed effect follows `contact flash -> main shape -> secondary debris ->
  residual fade`; one atlas cell is a component, not a complete gameplay event.
- Import filtering, blend mode, lifetime, direction, and palette are selected by
  the consuming VFX scene or material.

## Coverage inventory

| Visual role | Existing reusable coverage | This library | Status |
|---|---|---|---|
| Blade slash / cutting arc | Procedural slash layers and Basic Attack-specific sheets | `kinetic/` neutral slash atlas | Added in this batch |
| Energy shockwave / impact ring | Procedural impact layers | `kinetic/` neutral shockwave atlas | Added in this batch |
| Smoke / dust / dissipating residue | Fire-specific primitive smoke | `atmospheric/` neutral smoke atlas | Added in this batch |
| Explosion / flare / sparks | Fire burst and impact particles | `atmospheric/` explosion atlas | Added in this batch |
| Poison puddle / splash residue | Poison primitives and one ultimate-path atlas | `ground/` modular poison puddles | Added in this batch |
| Ice trail / frost crack / shard wake | Ice primitives and one ultimate-path atlas | `ground/` modular frost trails | Added in this batch |
| Fire trail / scorch | Fire primitives and ultimate-path atlas | Existing coverage is sufficient | Reuse existing |
| Water splash / wave arc | Water primitives | Existing coverage is sufficient | Reuse existing |
| Lightning bolt / surface arc | Deterministic A-to-B lightning primitives | Existing coverage is sufficient | Reuse existing |
| Wind lane / burst | Wind primitives | Existing coverage is sufficient | Reuse existing |
| Healing aura / holy pulse | Skill-specific grammar layers | `utility/` neutral healing components | Added in this batch |
| Void suction / dark residue | Black-hole renderer and skill-specific material | `utility/` neutral void components | Added in this batch |
| Blood / physical debris / rock chips | Skill-specific particles and DR. Stone layers | No shared raster family yet | Future candidate |

## Selection rule

Use a procedural primitive when endpoints, collision shape, continuous motion, or
long-lived deformation must react to gameplay. Use these atlases for authored
silhouettes, short contact accents, debris, ground residue, and afterimages. A
skill composes these parts through the existing VFX presentation boundary; it
does not fork the artwork or move combat authority into the texture library.

## Review rule

Every final atlas requires an independent object review at native detail, a
full-atlas review, and all six fixed cells reviewed as `R1C1` through `R2C3`.
Any change to an atlas or its runtime scale, position, z-order, or composition
invalidates the previous visual verdict.
