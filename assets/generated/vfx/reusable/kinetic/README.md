# Reusable Kinetic VFX Atlases

This folder contains neutral grayscale components for runtime tinting, scaling,
flipping, rotation, and layered combat-effect assembly. Both atlases retain a
pure-black background intentionally; use additive or screen-style blending
rather than alpha blending the source image directly.

## Shared contract

- Generation mode: built-in `image_gen` (no CLI fallback).
- Canvas: 1536×1024 PNG.
- Grid: 3 columns × 2 rows, six equal 512×512 cells.
- Reading order: left-to-right, top-to-bottom.
- Cell safety: every component is isolated within its own cell with black
  padding and no visible grid lines.
- Palette: white, pale gray, and medium gray on `#000000` for shader or
  `modulate` tinting.
- Final deterministic normalization: BT.709 luminance
  (`0.2126R + 0.7152G + 0.0722B`) is written back to all RGB channels;
  luminance `<= 16` is set to exact RGB `(0, 0, 0)`.
- Final deterministic cell registration: each non-black cell bbox is centered
  and fitted within `400×400`; the outer 48px moat of every 512×512 cell is
  then forced to exact RGB `(0, 0, 0)`.
- Recommended blend: additive for luminous energy; screen/lighten for softer
  pressure shells. Crop the cell before applying color, scale, flip, or
  rotation.
- Presentation only: these textures do not own hit detection, damage, targets,
  status, or gameplay timing.

## `slash_energy_mask_atlas_v1.png`

Cell contents:

1. Thin fast crescent slash.
2. Broad heavy crescent cleave.
3. Long straight cutting streak.
4. Crossed double slash.
5. Tight circular spinning slash arc.
6. Directional shattered contact slash.

Built-in generation prompt:

```text
Use case: stylized-concept
Asset type: reusable 2D game VFX mask atlas for sword slashes and sword-energy attacks
Input images: Image 1 is a shape-and-layering reference only; simplify it into neutral grayscale, coarse hand-painted game VFX pieces.
Primary request: create one production-ready 1536×1024 atlas divided into an exact 3-column × 2-row grid of six equal 512×512 cells, with one isolated reusable slash component centered in each cell. Reading order: (1) thin fast crescent slash, (2) broad heavy crescent cleave, (3) long straight cutting streak, (4) crossed double slash, (5) tight circular spinning slash arc, (6) shattered contact slash with a clear directional burst. All components face right by default but must remain useful when rotated, flipped, scaled, and color-tinted.
Scene/backdrop: perfectly flat pure black #000000 across the entire canvas.
Style/medium: hand-painted 2D action-game VFX, coarse broken brush edges, strong large value clusters, limited grayscale value steps, luminous white core with light-gray and dark-gray outer energy; clear silhouette before texture; restrained paper-dry brush irregularity; no photorealism.
Composition/framing: exact evenly aligned 3×2 layout; generous 36px or greater black safety padding on every side of every cell; every effect stays entirely inside its own cell and never touches or crosses a cell boundary; no visible grid lines or borders.
Color palette: neutral white, pale gray, medium gray only on pure black, designed as a mask for runtime tinting.
Constraints: six distinct silhouettes; each cell contains exactly one slash effect with only its tightly attached chips/sparks; no repeated copies; no animation-strip progression; no text; no symbols; no watermark; no characters; no weapons; no scenery; no floor; no cast shadows.
Avoid: blue or colored light, flames, smoke clouds, magic circles, full opaque discs, arrows, missiles, noisy lace texture, tiny meaningless repetition, smooth vector gradients, fuzzy bloom obscuring the edge, cell overlap, seams, checkerboard, labels and decorative borders.
```

Style reference: `res://assets/generated/vfx/basic_attack_crescent_quality_atlas_v3.png`.
The reference was used for silhouette/layering direction only; this atlas is a
neutral, coarser component library and does not replace the existing Basic
Attack presentation authority.

Final built-in boundary-correction prompt:

```text
Use case: precise-object-edit
Input images: Image 1 is the edit target, a 1536×1024 exact 3-column × 2-row grayscale slash VFX atlas.
Primary request: preserve all six existing slash designs, style, orientation and reading order, but scale/recenter each cell's complete effect just enough to enforce a clean black safety moat. Remove or pull inward every detached spark, chip, streak or glow pixel near cell boundaries.
Constraints: exact 1536×1024 canvas; exact 3×2 grid of six 512×512 cells; every cell must have at least 48px of perfectly black #000000 empty space on all four sides, including both sides of the invisible dividers at x=512, x=1024 and y=512. No component, fragment, glow or antialiasing may touch or cross any cell boundary. Preserve neutral white/pale-gray/medium-gray, pure black background, one component per cell, coarse hand-painted brush edges, and the current six silhouettes. No visible borders or grid lines. No text, labels, symbols, watermark, characters, weapons, scenery, flames, smoke, colored light or added objects.
```

## `shockwave_energy_mask_atlas_v1.png`

Cell contents:

1. Thin circular pressure ring.
2. Thick broken concussion ring.
3. Right-facing hemispherical wavefront.
4. Low forward pressure fan.
5. Two broad concentric broken pressure ripples sharing one center.
6. Asymmetric contact bloom with an expanding shell.

Built-in base generation prompt:

```text
Use case: stylized-concept
Asset type: reusable 2D game VFX mask atlas for energy shockwaves, force impacts, knockback and spell detonations
Input images: Image 1 is the repository's coarse hand-painted value-cluster reference; Image 2 is a luminous energy layering reference only. Do not copy their exact shapes.
Primary request: create one production-ready 1536×1024 atlas divided into an exact 3-column × 2-row grid of six equal 512×512 cells, with one isolated reusable energy shockwave component centered in each cell. Reading order: (1) thin circular pressure ring seen front-on, (2) thick broken circular concussion ring, (3) right-facing hemispherical wavefront arc, (4) low ground-hugging forward pressure fan, (5) compact double-pulse concentric shockwave treated as one cohesive component, (6) asymmetric contact shockwave bloom with a clear impact center and expanding shell. Shapes must support rotation, flipping, scaling, color tinting and layering under gameplay effects.
Scene/backdrop: perfectly flat pure black #000000 across the entire canvas.
Style/medium: hand-painted 2D action-game VFX, coarse broken brush edges, strong large value clusters, limited grayscale value steps, luminous white core with pale-gray and medium-gray pressure shell; readable silhouette first; restrained dry-brush breakup; no photorealism.
Composition/framing: exact evenly aligned 3×2 layout; generous 40px or greater black safety padding on every side of every cell; every effect stays entirely inside its own cell and never touches or crosses a cell boundary; no visible grid lines or borders.
Color palette: neutral white, pale gray, medium gray only on pure black, designed as a mask for runtime additive/screen blending and tinting.
Constraints: six clearly different shockwave topologies; each cell contains exactly one cohesive effect with at most a few tightly attached pressure chips; no repeated copies; no animation-strip progression; no text; no symbols; no watermark; no characters; no weapons; no scenery; no floor plane; no cast shadows.
Avoid: blue or colored light, fire, smoke clouds, lightning bolts, magical glyphs, runes, clocks, decorative circles, arrows, missiles, solid opaque discs, noisy lace texture, tiny meaningless repetition, smooth vector gradients, fuzzy bloom hiding the edge, cell overlap, seams, checkerboard, labels and borders.
```

Built-in targeted edit prompt for R2C2:

```text
Use case: precise-object-edit
Input images: Image 1 is the edit target, a 1536×1024 exact 3-column × 2-row grayscale VFX atlas.
Primary request: change only the bottom-center cell (row 2, column 2). Replace its spiky concentric rings and central star with one cohesive irregular double-pulse pressure ripple: two broad broken brush rings with softly offset thickness, open black centers, and only a few attached blunt pressure chips. It must read as physical air compression, not a magical glyph.
Constraints: preserve the other five cells pixel-for-pixel in composition and intent; preserve exact canvas size, pure black background, exact 3×2 alignment, and at least 40px black safety padding inside every cell. Keep neutral white/pale-gray/medium-gray only. No text, watermark, border, grid line, symbols, runes, starbursts, compass points, evenly repeated spikes, decorative marks, lightning, fire, smoke cloud, characters, weapons or scenery. Keep each component entirely within its cell.
```

Style references:

- `res://assets/generated/vfx/reusable/atmospheric/explosion_spark_components_atlas_v1.png`
- `res://assets/generated/vfx/basic_attack_crescent_quality_atlas_v3.png`

Final built-in boundary-correction prompt:

```text
Use case: precise-object-edit
Input images: Image 1 is the edit target, a 1536×1024 exact 3-column × 2-row grayscale shockwave VFX atlas.
Primary request: preserve all six existing shockwave designs, style, orientation and reading order, but scale/recenter each cell's complete effect just enough to enforce a clean black safety moat. In particular pull the bottom-left forward pressure fan inward from its right edge and pull the bottom-right contact bloom inward from its top edge. Remove or pull inward every detached chip, streak or glow pixel near cell boundaries.
Constraints: exact 1536×1024 canvas; exact 3×2 grid of six 512×512 cells; every cell must have at least 48px of perfectly black #000000 empty space on all four sides, including both sides of the invisible dividers at x=512, x=1024 and y=512. No component, fragment, glow or antialiasing may touch or cross any cell boundary. Preserve neutral white/pale-gray/medium-gray, pure black background, one cohesive component per cell, coarse hand-painted brush edges, and the current six topologies. Keep bottom-center as an irregular double pressure ripple without a central star or evenly repeated spikes. No visible borders or grid lines. No text, labels, symbols, runes, watermark, characters, weapons, scenery, fire, smoke cloud, lightning, colored light or added objects.
```

Use these components for force impacts, knockback cues, ground contacts,
detonations, barrier hits, and skill contact beats. Avoid using the circular
cells as unexplained decorative glyphs; connect them to a real contact or
expansion event.

## Independent review revision 1 — 2026-08-08

The first independent review returned Important findings. The final files in
this folder include the following corrections, which were subsequently checked
again at object, full-frame, and fixed 3×2 six-slice detail:

- Both atlases: deterministic grayscale conversion, near-black thresholding,
  exact-black full-canvas/cell moats, and centered `400×400` maximum content
  bounds.
- Slash R1C3: replaced the arrow/projectile silhouette with a neutral long
  horizontal cutting streak tapered at both ends.
- Slash R1C3 and R2C3: recentered and reduced to at least 48px cell margins.
- Shockwave R1C1: replaced cardinal/equidistant spikes and ticks with an
  asymmetric thin broken pressure ring.
- Shockwave R1C2: replaced periodic inward teeth, the lower star point, and
  high-frequency debris with a few broad coarse ring clusters.
- Shockwave R2C2: replaced the spiral with exactly two broken concentric rings
  that share one center and contain no star point.
- Shockwave R2C1: recentered and reduced to at least 48px cell margins.

Latest built-in slash edit prompt:

```text
Use case: precise-object-edit
Asset type: reusable 2D game VFX mask atlas
Input images: Image 1 is the edit target, an exact 1536×1024 atlas with a 3-column × 2-row grid of six 512×512 cells.
Primary request: change only R1C3 and R2C3. In R1C3 replace the current arrowhead/missile-like shape with one neutral long straight sword-cut streak: a narrow, slightly hand-broken horizontal cutting band with tapered brush ends on BOTH ends, a luminous white central cut, restrained pale-gray trailing fibers parallel to the cut, and no pointed projectile head, shaft, arrow silhouette, or travel object. In R2C3 preserve the existing shattered contact slash design but scale it down and center it in the cell. Scale and center both edited cells so their entire visible component, fragments, glow, and antialiasing fit comfortably within an inner 400×400 safe area, leaving at least 56px of visually empty black space on all four sides.
Style/medium: neutral grayscale, coarse hand-painted 2D action-game VFX, strong large value clusters, broken dry-brush edges, limited value steps; readable silhouette before texture.
Invariants: preserve R1C1, R1C2, R2C1, and R2C2 unchanged in design, position, and scale. Preserve exact canvas size and exact grid alignment. Pure black background; no visible grid or borders. One isolated component per cell; nothing crosses cells.
Avoid: arrows, arrowheads, missiles, spearheads, projectiles, flames, smoke, magic glyphs, text, labels, symbols, watermark, characters, weapons, scenery, colored light, decorative repetition, fuzzy bloom, cell overlap.
```

Latest built-in shockwave edit prompt:

```text
Use case: precise-object-edit
Asset type: reusable 2D game VFX mask atlas
Input images: Image 1 is the edit target, an exact 1536×1024 atlas with a 3-column × 2-row grid of six 512×512 cells.
Primary request: change only R1C1, R1C2, R2C1, and R2C2. R1C1: replace the evenly spiked ring with one thin irregular broken pressure ring. Use varying brush thickness, 3–5 uneven gaps, subtle asymmetry, and a clean open center. No cardinal spikes, tick marks, compass points, repeated teeth, stars, or evenly spaced decoration. R1C2: replace the periodic inward-spiked ring and bottom starburst with one thick coarse broken concussion ring made from 5–7 large connected pressure-brush clusters. Keep a clean open center. Use low-frequency shape variation and at most three blunt attached chips. No inward teeth, no bottom star, no repeated scallops, no high-frequency debris. R2C1: preserve the low forward pressure-fan topology but scale it down and center it so the entire body, fragments, glow, and antialiasing stay inside an inner 400×400 safe area. R2C2: replace the spiral with exactly two broad broken concentric pressure rings sharing the exact same center. The rings must be circular pressure ripples, not a spiral: each ring closes around the same center but has 2–4 irregular blunt gaps and varied brush width. No central star, no star points, no dots, no spikes, no runes, no decorative marks, no offset centers.
Style/medium: neutral grayscale, coarse hand-painted 2D action-game VFX, strong large value clusters, limited grayscale value steps, broken dry-brush edges; physical air compression, not magic glyphs.
Composition: center all edited components and keep their complete visible content inside an inner 400×400 safe area, leaving at least 56px visually empty black space on every side. Preserve exact canvas size and exact 3×2 alignment.
Invariants: preserve R1C3 and R2C3 unchanged in design, position, and scale. Pure black background, no visible grid or borders, one cohesive component per cell, no crossing cells.
Avoid: evenly repeated spikes, cardinal points, clock ticks, decorative circles, magic sigils, spirals, starbursts, stars, runes, high-frequency fragments, smoke clouds, fire, lightning, arrows, projectiles, text, labels, watermark, characters, weapons, scenery, colored light.
```

Final independent review: PASS on 2026-08-08, with Critical 0 and Important 0
for the locked slash and shockwave atlases. Any later pixel or runtime
composition change requires a new review.
