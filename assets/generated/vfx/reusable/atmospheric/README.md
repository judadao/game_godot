# Reusable Atmospheric Combat VFX

This folder contains neutral, black-backed component atlases intended for
composition by multiple combat skills. The source images are deliberately
opaque RGB PNGs: black is the neutral background for additive rendering or a
luminance-to-alpha mask, so these assets do not depend on model-generated
transparency.

## Technical contract

| Atlas | Canvas | Grid | Cell | Content |
|---|---:|---:|---:|---|
| `smoke_dust_components_atlas_v1.png` | 1252 x 1252 | 4 x 4 | 313 x 313 | smoke, dust, mist, debris |
| `explosion_spark_components_atlas_v1.png` | 1252 x 1252 | 4 x 4 | 313 x 313 | flashes, blasts, shock forms, sparks |

- Every cell is independently crop-safe and contains one reusable component.
- Every cell has at least 20 px of pure-black internal padding on all sides.
- The outer image edge is pure black and contains no active pixels.
- Both final atlases are deterministic neutral grayscale (`R == G == B` for
  every pixel). Values below 18 were clamped to exact RGB `0, 0, 0`; all cell
  safety bands were then explicitly repainted true black. This prevents faint
  colored rectangles or near-black noise under additive/screen rendering.
- The generated 1254 x 1254 outputs were symmetrically cropped to 1252 x 1252,
  then each cell was uniformly inset to enforce the fixed 313 px grid and safe
  gutters. No component was redrawn during this deterministic normalization.
- Import as a normal texture. Create `AtlasTexture` regions at
  `Rect2(column * 313, row * 313, 313, 313)`.

## Runtime use

- Additive: use `CanvasItemMaterial.BLEND_MODE_ADD`; tint with `modulate`. Black
  contributes no light, while the grayscale or pale-amber marks remain visible.
- Masked smoke: in a shader, derive opacity from luminance
  (`max(r, max(g, b))`) and apply a separate smoke color. This supports dark,
  opaque-looking smoke even though the source background is black.
- Keep filtering consistent with the rest of the combat presentation. At small
  scale, nearest or low-filter sampling best preserves the coarse broken edge;
  linear filtering is suitable for large, slowly fading smoke.
- Cells are semantic parts, not animation frames. Combine, rotate, mirror,
  scale, tint, and stagger them to build attack-specific timing.

## Cell map

Rows and columns are one-based.

### Smoke and dust

| Cell | Component |
|---|---|
| R1C1 | small ground-impact dust puff |
| R1C2 | medium ground-impact dust puff |
| R1C3 | heavy ground-impact dust puff |
| R1C4 | circular landing dust ring |
| R2C1 | short directional skid tail |
| R2C2 | long directional rush trail |
| R2C3 | outward twin dust wings |
| R2C4 | low rolling dust bank |
| R3C1 | soft round smoke puff |
| R3C2 | broken clustered smoke cloud |
| R3C3 | narrow rising smoke column |
| R3C4 | curling smoke plume |
| R4C1 | thin wispy ribbon |
| R4C2 | broad mist patch |
| R4C3 | grouped dust/debris chips |
| R4C4 | dissipating smoke spiral |

### Explosion and sparks

| Cell | Component |
|---|---|
| R1C1 | small star impact |
| R1C2 | four-point flash |
| R1C3 | round ignition core |
| R1C4 | sharp radial burst |
| R2C1 | small ground explosion |
| R2C2 | medium round explosion |
| R2C3 | broad low explosion |
| R2C4 | vertical eruption |
| R3C1 | broken shock ring |
| R3C2 | outward smoke-fire crown |
| R3C3 | one-sided impact wedge |
| R3C4 | mushroom-like blast plume |
| R4C1 | tight spark fan |
| R4C2 | wide radial spark spray |
| R4C3 | clustered hot debris chips |
| R4C4 | fading ember-and-smoke remnant |

## Generation record

Mode: OpenAI built-in `image_gen` generation. No CLI or model-native
transparency path was used.

### Revision after independent review

- Important background finding: both atlases were converted to deterministic
  grayscale, near-black values below 18 were clamped to RGB zero, and every
  20 px cell safety band was explicitly rebuilt as true black.
- Important smoke finding: `smoke_dust_components_atlas_v1.png` R4C2 was edited
  with built-in `image_gen`, then only that cell was composited back into the
  locked atlas. The replacement is one broader, connected mist bank with large
  value clusters and no crossed short-stroke/scaled repetition.
- Minor explosion finding: R4C4 received a restrained 1.18x luminance contrast
  lift after grayscale conversion so the ember/smoke remnant remains readable.
- After the content edit, both atlases were re-normalized to 1252 x 1252,
  4 x 4, 313 px cells with at least 20 px safe padding. The resulting locked
  revision passed independent full-frame, native-detail, and fixed 3 x 2
  six-slice review on 2026-08-08 with Critical 0 and Important 0.

R4C2 edit prompt:

```text
Use case: precise-object-edit
Asset type: reusable 2D game VFX component atlas for Godot
Input images: Image 1 is the edit target and existing 4-column by 4-row smoke/dust atlas.
Primary request: change only cell R4C2, the second cell from the left in the bottom row. Replace its current crossed short-brush broad mist patch with one larger, continuous, coherent low mist bank.
R4C2 subject: a broad horizontal fog mass with one connected silhouette, gently uneven outer contour, 2 to 3 large grayscale value clusters, a soft dense center and two low tapering ends. Use sparse coarse broken outer brush edges, but no interior crisscrossing strokes and no repeated scales or leaf-like dabs.
Constraints: preserve the other 15 cells exactly in subject, placement, scale, palette and grid. Keep the pure black background. Keep a strict equal 4x4 grid with one component per cell, no visible divider lines, and generous black padding inside R4C2. No marks may cross a cell boundary. No text, labels, borders, logos, or watermark.
Style/medium: the same hand-painted grayscale 2D VFX style as Image 1, with large readable clusters, limited value steps and coarse broken edges.
Avoid in R4C2: intersecting short brush strokes, woven texture, fish-scale texture, feather repetition, noisy speckles, mushy airbrush, photorealistic fog, high-frequency detail. Change only R4C2; keep everything else unchanged.
```

### Smoke and dust prompt

```text
Use case: stylized-concept
Asset type: reusable 2D game VFX component atlas for Godot
Primary request: create one production-ready SMOKE AND DUST atlas containing exactly 16 distinct reusable monochrome components.
Scene/backdrop: perfectly pure solid black (#000000) across the entire canvas, including every gutter; no transparency and no scenery.
Subject: a strict 4-column by 4-row grid of 16 isolated smoke/dust components. Row 1: four compact ground-contact dust puffs (small impact, medium impact, heavy impact, circular landing ring). Row 2: four directional dust motions (short left-to-right skid tail, long left-to-right rush trail, outward twin dust wings, low rolling dust bank). Row 3: four smoke masses (soft round smoke puff, broken clustered cloud, narrow rising smoke column, curling smoke plume). Row 4: four residual pieces (thin wispy ribbon, broad mist patch, three separated dust chips as one grouped component, dissipating smoke spiral). Every cell contains exactly one centered component and generous internal padding.
Style/medium: stylized hand-painted 2D action-game VFX; coarse broken brush edges, large readable value clusters, limited value steps, deliberate chunky mark-making inspired by hand-painted stone and wood textures; crisp silhouette at game scale.
Composition/framing: exact equal 4x4 cell grid, 1024x1024 square atlas, implied 256x256 cells. Invisible grid only: do not draw divider lines. No mark may cross a cell boundary. Keep at least 20 pixels equivalent safe padding inside every cell. Each component must fit fully within its cell.
Color palette: grayscale only, charcoal gray through off-white; pure black background. Keep value separation bold enough for runtime tinting and luminance-mask use.
Lighting/mood: graphic and readable, not volumetric realism.
Constraints: exactly 16 components; one component per cell; no text, labels, numbers, borders, grid lines, characters, weapons, logos, watermark, floor plane, shadows outside components, or background texture. All cells must be useful independently. No component may touch or cross its cell edge.
Avoid: photorealistic smoke, soft mushy airbrush, high-frequency noise, fractal detail, meaningless repetition, tiny speckle clutter, false seams, copied duplicate shapes, smooth vector gradients, colored smoke.
```

### Explosion and sparks prompt

```text
Use case: stylized-concept
Asset type: reusable 2D game VFX component atlas for Godot
Primary request: create one production-ready EXPLOSION, IMPACT FLASH, AND SPARK atlas containing exactly 16 distinct reusable components.
Scene/backdrop: perfectly pure solid black (#000000) across the entire canvas, including every gutter; no transparency and no scenery.
Subject: a strict 4-column by 4-row grid of 16 isolated explosion and spark components. Row 1: four compact cores (small star impact, four-point flash, round ignition core, sharp radial burst). Row 2: four blast shapes (small ground explosion, medium round explosion, broad low explosion, vertical eruption). Row 3: four pressure/impact forms (broken shock ring, outward smoke-fire crown, one-sided impact wedge, mushroom-like blast plume). Row 4: four secondary components (tight fan of sparks, wide radial spark spray, clustered hot debris chips, fading ember-and-smoke remnant). Every cell contains exactly one centered component and generous internal padding.
Style/medium: stylized hand-painted 2D action-game VFX; coarse broken brush edges, large readable value clusters, limited value steps, deliberate chunky mark-making inspired by hand-painted stone and wood textures; crisp silhouette at game scale.
Composition/framing: exact equal 4x4 cell grid, 1024x1024 square atlas, implied 256x256 cells. Invisible grid only: do not draw divider lines. No mark may cross a cell boundary. Keep at least 20 pixels equivalent safe padding inside every cell. Each component must fit fully within its cell.
Color palette: mostly grayscale white and warm gray with a very restrained pale amber accent in hottest cores only; pure black background. Preserve strong luminance so users can runtime-tint it and use additive blending or luminance masks.
Lighting/mood: graphic, forceful, readable, not realistic pyrotechnics.
Constraints: exactly 16 components; one component per cell; no text, labels, numbers, borders, grid lines, characters, weapons, logos, watermark, floor plane, or background texture. All cells must be useful independently. No component may touch or cross its cell edge.
Avoid: photorealistic fireballs, orange-red color dominance, soft mushy airbrush, excessive glow bloom, high-frequency noise, fractal detail, meaningless repetition, tiny speckle clutter, false seams, duplicated shapes, smooth vector gradients.
```
