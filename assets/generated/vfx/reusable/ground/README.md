# Reusable Ground VFX Atlases

These atlases are supplemental composition parts. They do not replace the
existing runtime atlases in `res://assets/generated/vfx/ground/` and are not
wired to a scene or gameplay profile yet.

## Shared format

- Generation mode: built-in `image_gen` (not CLI)
- Canvas: `1536 x 1024`, opaque 24-bit RGB PNG
- Grid: `3 columns x 2 rows`; each implied cell is `512 x 512`
- Background: deterministic black (`RGB 0,0,0`); there are no printed grid lines
- Final mask normalization: RGB channels are identical, intensity values `1..18`
  are thresholded to `0`, and each nonzero cell component is centered within a
  maximum `400 x 400` bounding box using aspect-preserving downscale only
- Cell contract: one self-contained component per cell; components do not cross
  cell boundaries; every nonzero pixel has at least `56px` measured clearance
  from its cell boundary
- Art direction: top-down or shallow top-down, coarse broken hand-painted edges,
  large readable value clusters, limited grayscale steps, no text or watermark
- Runtime extraction: crop regions in reading order with
  `Rect2i(column * 512, row * 512, 512, 512)`
- Suggested compositing: use `SCREEN` for soft masks or `ADD` for emissive
  highlights, then tint with `modulate`; use `MIX` only when the black backing
  has first been removed by a shader or mask threshold
- Reuse: cells may be independently tinted, stretched, rotated, overlapped, or
  chained. Preserve nearest-cell sampling and padding so adjacent cells never
  bleed into a region crop.

## Revision notes

### Reviewer remediation — 2026-08-08

The first candidate received Important findings during independent review. The
formal PNGs were regenerated with built-in edit mode and then deterministically
normalized:

- Both atlases were converted to true grayscale RGB (`R = G = B`). Near-black
  generated noise at intensity `1..18` was cleared to exact black.
- Every 512px cell was independently cropped, aspect-preserving downscaled only
  when larger than 400px, and re-centered. The final measured minimum nonzero
  clearance is 56px; all 48px grid-boundary safety belts are exact black.
- Poison R2C2 was initially replaced with a thick, short, rounded corrosion
  network. This first remediation was later superseded by the poison-only
  rereview revision below.
- Ice R1C1 and R1C2 were replaced with broad-facet trail pieces using only a few
  large value planes and clean blunt chaining ends. Ice R2C3 was simplified to
  remove excess tiny flecks.

First poison remediation prompt (superseded after rereview):

```text
Use case: precise-object-edit
Asset type: reusable 2D poison-ground combat VFX mask atlas
Input images: Image 1 is the edit target and existing 3-column x 2-row atlas.
Primary request: Change only cell R2C2, the bottom-center component. Replace its lightning-like / ice-crack-like branching shape with one unmistakable CORROSION VEIN decal: a thick, short, organic acid-eaten network with 3 to 5 rounded lobed channels, blunt dissolved tips, asymmetrical branching, and a few broad pitted gaps. It should resemble viscous chemical corrosion spreading through a surface, not electricity, roots, frost, or fractured ice.
Style/medium: preserve the atlas's coarse hand-painted grayscale mask style, limited value steps, chunky readable silhouette, and pure black background.
Composition/framing: preserve the exact 1536x1024 canvas and exact 3x2 implied cell layout. The replacement must be centered within R2C2 and fit comfortably inside that 512x512 cell. No pixels from the replacement may approach within 70px of the cell boundary.
Constraints: change only R2C2; keep R1C1, R1C2, R1C3, R2C1, and R2C3 visually unchanged in subject, placement, scale, and brush style. Keep one component per cell. No grid lines, text, labels, borders, icons, color, or watermark.
Avoid: thin lightning forks, thin frost cracks, root-like tendrils, excessive terminal branches, high-frequency detail, tiny speckles, smooth vector lines, photorealism, false seams, or cell crossing.
```

Ice built-in edit prompt:

```text
Use case: precise-object-edit
Asset type: reusable 2D frozen-ground combat VFX mask atlas
Input images: Image 1 is the edit target and existing 3-column x 2-row atlas.
Primary request: Change cells R1C1 and R1C2 only. Redesign them as clean modular frozen-ground trail pieces made from a few LARGE BROAD ICE FACETS and broad opaque frost brush planes. Remove the dense crystalline mosaic and nearly all hairline cracks. R1C1 must be a straight horizontal segment whose left and right chaining ends are clean, short, blunt, approximately the same vertical thickness, and visually open for overlap with the next segment. R1C2 must be a gently curved segment with equally clean blunt open ends and the same approximate thickness as R1C1. Use no more than 5 to 7 major facets in each segment, with large uninterrupted gray value planes and only 2 to 4 thick separation strokes.
Style/medium: preserve the atlas's coarse hand-painted grayscale mask style, limited value steps, readable silhouette, and pure black background; use large color/value clusters rather than detailed crystal texture.
Composition/framing: preserve the exact 1536x1024 canvas and exact 3x2 implied cell layout. Center both replacements in their 512x512 cells and keep every visible pixel at least 70px from the cell boundary.
Secondary change: in R2C3 keep the same ice-splinter cluster but reduce the tiny detached flecks, retaining only a few large readable splinters. Preserve R1C3, R2C1, and R2C2 visually unchanged in subject, placement, scale, and brush style.
Constraints: one component per cell; no component may cross a cell boundary; no grid lines, text, labels, borders, icons, color, or watermark.
Avoid: dense crystalline grids, small polygon mosaics, hairline cracks, sawtooth chaining ends, high-frequency detail, tiny snow noise, excessive detached flecks, smooth vector polish, photorealism, false seams, or cell crossing.
```

### Poison R2C2 rereview remediation — 2026-08-08

The first poison remediation still read as a cheese/amoeba shape because it
contained approximately eight regular circular holes and repeated the ring
language already used by R1C2 and R2C1. Only R2C2 was replaced again:

- The final component has one diagonal lower-left-to-upper-right trunk, two
  offset chunky fork junctions, three secondary channels, and blunt dissolved
  terminals.
- It has no enclosed holes, loops, circles, rings, center hub, or radial
  symmetry.
- Only the final R2C2 512px cell was composited into the formal atlas. Pixel
  hashes for R1C1, R1C2, R1C3, R2C1, and R2C3 were checked before and after and
  remained identical.
- R2C2 was independently converted to grayscale RGB, intensity `1..18` was
  cleared to exact black, and the component was centered in a maximum 400px
  bounding box. Its measured minimum cell clearance is 56px.

Final poison rereview built-in edit prompt:

```text
Use case: precise-object-edit
Asset type: reusable 2D poison-ground combat VFX mask atlas
Input images: Image 1 is the latest edit candidate. Only its R2C2 bottom-center cell is still wrong.
Primary request: Change ONLY R2C2 again. Replace the radial blob/star/amoeba with a DIAGONALLY ORIENTED CORROSION CHANNEL NETWORK. It must have one obvious thick main trunk running from lower-left toward upper-right, then split at two visibly offset fork junctions into three broad secondary channels. Add at most two short blunt side stubs. The result must read as a path-like branching caustic vein with direction and hierarchy, not arms radiating from a center.
Topology and silhouette: open branching structure; irregular channel width; chunky Y-shaped forks; long offset main trunk; blunt ragged dissolved ends; broad gray inner fill and broken off-white eroded edge. NO holes, NO loops, NO circles, NO rings, NO round cavities, NO repeated lobes, NO center hub, NO radial symmetry, NO starfish silhouette, NO amoeba silhouette.
Style/medium: coarse broken hand-painted grayscale mask, large readable shapes, limited value planes on uniform black. Organic acid erosion, not lightning, frost, tree roots, leaf veins, or delicate cracks.
Composition/framing: preserve exact 1536x1024 canvas and exact 3x2 layout. Center the diagonal network within R2C2 and keep it at least 72px from every R2C2 boundary.
Invariants: change only R2C2. Keep the other five cells visually unchanged. No text, labels, grid, borders, color, watermark, small speckles, micro-branches, or crossing between cells.
```

## `poison_ground_mask_atlas_v1.png`

Intended for poison pools, corrosive ground, plague trails, alchemical spills,
and recolored shadow/acid zones.

| Cell | Component |
|---|---|
| R1C1 | Broad irregular five-lobed puddle fill |
| R1C2 | Broken uneven puddle rim with hollow center |
| R1C3 | Compact satellite splash island |
| R2C1 | Top-down bubble-ring cluster in a low puddle patch |
| R2C2 | Diagonal corrosion channel with offset chunky forks |
| R2C3 | Compact droplet-and-spatter accent cluster |

Built-in prompt:

```text
Use case: stylized-concept
Asset type: reusable 2D combat VFX mask atlas for a Godot game
Primary request: Create a POISON GROUND / TOXIC PUDDLE modular atlas containing exactly six distinct hand-painted grayscale VFX components.
Scene/backdrop: perfectly uniform pure black #000000 canvas, no texture, no gradient, no transparency checkerboard.
Style/medium: top-down 2D game VFX, hand-painted with coarse broken brush edges, large readable value clusters, limited four-step grayscale palette (dark gray, mid gray, light gray, off-white); crisp silhouette; deliberately non-photorealistic and suitable for runtime tinting.
Composition/framing: exact 3-column by 2-row equal cell grid on a 1536x1024 landscape canvas; each implied cell is 512x512. Do not draw grid lines. Keep at least 48px clear black padding inside every cell. Exactly one self-contained component per cell, centered, and nothing may cross a cell boundary.
Cell contents in reading order: R1C1 one broad irregular five-lobed puddle fill; R1C2 one broken uneven puddle rim with a hollow black center; R1C3 one compact satellite splash island; R2C1 one top-down bubble-ring cluster embedded in a low puddle patch; R2C2 one branching corrosion-vein decal with thick readable forks; R2C3 one compact droplet-and-spatter accent cluster. Each cell must contain only that single named component, not multiple alternatives.
Lighting/mood: graphic emissive mask values only; no cast shadow, no floor plane, no perspective horizon.
Color palette: strictly achromatic grayscale on pure black, no green, purple, brown, or colored fringe.
Materials/textures: viscous toxic-liquid shapes suggested by chunky brush marks and a few large internal highlights; no micro-bubbles or dense speckle.
Constraints: all six components are top-down; clear silhouette at small game scale; tile/crop friendly; easy to recolor; no labels, no letters, no numbers, no icons, no border, no watermark.
Avoid: photorealism, glossy 3D rendering, neon-colored liquid, high-frequency noise, repeated meaningless dots, mushy texture, smooth vector polish, false seams, broken geometry, components touching or crossing cells.
```

## `ice_trail_mask_atlas_v1.png`

Intended for frozen trails, ground-freeze casts, frost rifts, ice-path movement,
and recolored crystal or arcane-glass attacks.

| Cell | Component |
|---|---|
| R1C1 | Horizontal modular frozen-ground trail segment |
| R1C2 | Gently curved frozen-ground trail segment |
| R1C3 | Tapered spearhead-like trail start/end cap |
| R2C1 | Forked frost-crack decal |
| R2C2 | Low ice ridge with broad faceted shards |
| R2C3 | Compact ice-splinter and frost-fleck cluster |

Built-in prompt:

```text
Use case: stylized-concept
Asset type: reusable 2D combat VFX mask atlas for a Godot game
Primary request: Create an ICE GROUND / FROZEN TRAIL modular atlas containing exactly six distinct hand-painted grayscale VFX components.
Scene/backdrop: perfectly uniform pure black #000000 canvas, no texture, no gradient, no transparency checkerboard.
Style/medium: top-down 2D game VFX, hand-painted with coarse broken brush edges, large readable value clusters, limited four-step grayscale palette (dark gray, mid gray, light gray, off-white); crisp silhouette; deliberately non-photorealistic and suitable for runtime tinting.
Composition/framing: exact 3-column by 2-row equal cell grid on a 1536x1024 landscape canvas; each implied cell is 512x512. Do not draw grid lines. Keep at least 48px clear black padding inside every cell. Exactly one self-contained component per cell, centered, and nothing may cross a cell boundary.
Cell contents in reading order: R1C1 one horizontal modular frozen-ground trail segment with clean blunt open ends for chaining; R1C2 one gently curved frozen-ground trail segment with clean open ends; R1C3 one tapered spearhead-like trail start/end cap; R2C1 one forked frost-crack decal with thick readable branches; R2C2 one low top-down ice-ridge component with only a few broad faceted shards; R2C3 one compact cluster of ice splinters and frost flecks. Each cell must contain only that single named component, not multiple alternatives.
Lighting/mood: graphic emissive mask values only; no cast shadow, no floor plane, no perspective horizon.
Color palette: strictly achromatic grayscale on pure black, no blue, cyan, purple, or colored fringe.
Materials/textures: frozen glass and rime suggested with a few broad facets and coarse brush marks; avoid tiny crystalline mosaic details.
Constraints: all six components read from a top-down or shallow top-down game camera; clear silhouette at small game scale; stretch/crop/chain friendly; easy to recolor; no labels, no letters, no numbers, no icons, no border, no watermark.
Avoid: photorealism, glossy 3D rendering, neon color, high-frequency snow noise, repeated meaningless dots, mushy texture, smooth vector polish, false seams, broken geometry, components touching or crossing cells.
```

## Integration notes

These are source atlases only. A future integration task should decide which
cells map to `core`, `edge`, `accent`, and `debris`, add the relevant profile or
scene reference, and run the affected VFX structural tests. The locked source
atlases passed independent native/full/six-slice review on 2026-08-08 with
Critical 0 and Important 0; any future runtime scale, position, z-order, or
composition still requires a new integration review.
