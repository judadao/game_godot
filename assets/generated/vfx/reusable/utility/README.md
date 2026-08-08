# Reusable Utility Combat VFX Atlases

These atlases fill presentation-only gaps for generic contact feedback, physical
debris, healing pulses, and void residue. They are not wired to a combat scene
or gameplay profile yet and never own damage, healing, status, targeting, or
movement.

## Shared format

- Generation mode: OpenAI built-in `image_gen` (not CLI)
- Canvas: `1536 x 1024`, opaque RGB PNG
- Grid: `3 columns x 2 rows`; every implied cell is `512 x 512`
- Background: pure black (`#000000`) for additive or luminance-mask use
- Cell contract: one independently crop-safe component per cell, with generous
  internal black padding and no visible grid lines
- Art direction: top-down or shallow top-down, coarse broken hand-painted edges,
  large readable value clusters, limited achromatic value steps, no text or
  watermark
- Runtime crop: `Rect2i(column * 512, row * 512, 512, 512)` in reading order

## `contact_flash_hit_debris_atlas_v1.png`

Use this atlas for weapon contact, armor deflection, projectile hits, physical
impact punctuation, and material-specific secondary debris. It complements the
larger explosion vocabulary under `../atmospheric/`; it is not a replacement
for blast, smoke, or shockwave components.

| Cell | Component | Typical use |
|---|---|---|
| R1C1 | Compact asymmetric contact flash | Universal contact core, hit-stop accent |
| R1C2 | Directional thick hit-spark fan | Slash/projectile travel direction echo |
| R1C3 | Hollow angular collision star | Metal parry, armor deflection, hard guard |
| R2C1 | Broad stone-chip burst | Rock, masonry, earth, heavy ground contact |
| R2C2 | Coarse splinter burst | Wood, bark, brittle armor, recolored crystal |
| R2C3 | Mixed directional impact debris | Generic projectile or knockback contact |

Built-in prompt:

```text
Use case: stylized-concept
Asset type: reusable neutral 2D combat VFX component atlas for a Godot game
Primary request: Create exactly six distinct CONTACT FLASH, HIT SPARK, AND PHYSICAL DEBRIS components for reuse across melee, projectile, armor, stone, and wooden impacts.
Scene/backdrop: perfectly uniform pure black #000000 across the entire canvas and all gutters; no transparency checkerboard, no scenery, no floor plane.
Style/medium: hand-painted top-down or shallow top-down 2D action-game VFX; coarse broken brush edges, large readable value clusters, limited four-step grayscale, chunky authored mark-making, strong silhouettes at small runtime scale; deliberately non-photorealistic and suitable for runtime tinting.
Composition/framing: exact 1536x1024 landscape canvas divided into an invisible strict 3-column by 2-row grid; each implied cell is exactly 512x512. Do not draw grid lines. Keep at least 56 pixels of clear pure-black padding inside every cell. Exactly one centered, self-contained component per cell. Nothing may touch or cross a cell boundary.
Cell contents in reading order: R1C1 one compact asymmetric central contact flash with a hot off-white core and six short broken rays; R1C2 one directional fan of thick hit sparks traveling left-to-right with only seven to nine sparks; R1C3 one angular metal-on-metal collision star with a hollow dark center and chipped uneven arms; R2C1 one grouped burst of six to eight broad top-down stone chips with two size tiers, treated as one compact component; R2C2 one grouped burst of six to eight splintered wooden debris pieces with thick readable silhouettes, treated as one compact component; R2C3 one neutral mixed impact debris fan with a few blunt shards and three short streaks, directional left-to-right, treated as one compact component. Each cell contains only the named component, never multiple alternatives.
Lighting/mood: graphic mask values only; controlled off-white contact core, light gray secondary pieces, medium gray fading tails; no excessive bloom.
Color palette: strictly achromatic grayscale on pure black; no amber, yellow, blue, brown, colored fringe, or chromatic aberration.
Materials/textures: broad chipped facets and coarse dry-brush breaks; no micro-fragments, no dust cloud, no smoke, no explosion, no magic circle.
Constraints: exact 3x2 atlas; exact six isolated components; crop-safe 512x512 cells; clear at small game scale; easy to recolor with modulate; no text, labels, letters, numbers, icons, borders, grid lines, characters, hands, weapons, logos, or watermark.
Avoid: photorealism, glossy 3D rendering, smooth vector polish, high-frequency noise, mushy airbrush, meaningless repeated dots, duplicated shapes, false seams, broken geometry, radial explosion fireballs, shockwave rings, components crossing cells.
```

## `healing_void_components_atlas_v1.png`

The first row provides neutral restorative shapes; the second row provides
shadow/void residue. Tint and time these independently so opposing semantic
roles never become visually ambiguous in the same skill.

| Cell | Component | Typical use |
|---|---|---|
| R1C1 | Broad broken healing pulse ring | Expanding heal tick, cleanse pulse, buff radius |
| R1C2 | Five-wisp restorative fountain | Regeneration tick, revive lift, life-energy release |
| R1C3 | Four-lobed life-energy bloom | Compact heal confirmation, supportive contact |
| R2C1 | Two-arm inward void spiral | Suction, shadow teleport, life-drain anticipation |
| R2C2 | Low irregular void residue pool | Curse residue, portal scar, shadow ground fade |
| R2C3 | Directional dissolving void fragments | Dispel, blink exit, dark projectile afterimage |

Built-in prompt:

```text
Use case: stylized-concept
Asset type: reusable neutral 2D combat VFX component atlas for a Godot game
Primary request: Create exactly six distinct HEALING PULSE AND VOID RESIDUE components for reuse across restorative, life-drain, shadow, teleport, curse, and dispel skills.
Scene/backdrop: perfectly uniform pure black #000000 across the entire canvas and all gutters; no transparency checkerboard, scenery, floor plane, or horizon.
Style/medium: hand-painted top-down 2D action-game VFX; coarse broken brush edges, large readable value clusters, limited four-step grayscale, chunky authored mark-making, strong silhouettes at small runtime scale; deliberately non-photorealistic and suitable for runtime tinting.
Composition/framing: exact 1536x1024 landscape canvas divided into an invisible strict 3-column by 2-row grid; each implied cell is exactly 512x512. Do not draw grid lines. Keep at least 56 pixels of clear pure-black padding inside every cell. Exactly one centered, self-contained component per cell. Nothing may touch or cross a cell boundary.
Cell contents in reading order: R1C1 one broad broken circular healing pulse ring seen top-down, with an uneven thick outer wave and hollow black center; R1C2 one compact upward fountain of five broad restorative wisps emerging from a small bright contact base, treated as one grouped component; R1C3 one soft four-lobed life-energy bloom with a bright center and four chunky separated petal-like pulses, no literal flower stem and no medical cross; R2C1 one asymmetric inward-curling void suction spiral with a large hollow black center and only two coarse broken arms; R2C2 one low irregular shadow residue pool seen top-down, with a broken pale-gray rim, charcoal inner mass, and two detached fading scraps, treated as one component; R2C3 one dissolving void fragment cluster drifting left-to-right, composed of five broad torn shards and three short fading wisps, treated as one component. Each cell contains only the named component, never multiple alternatives.
Lighting/mood: graphic mask values only; healing components use off-white cores with light and medium gray decay, void components reverse the value hierarchy with charcoal masses, pale broken rims, and sparse off-white accents; controlled glow, no excessive bloom.
Color palette: strictly achromatic grayscale on pure black; no green, gold, pink, purple, blue, colored fringe, or chromatic aberration.
Materials/textures: broad dry-brush breaks, coarse torn energy edges, limited tonal steps; no fine smoke curls or dense particles.
Constraints: exact 3x2 atlas; exact six isolated components; crop-safe 512x512 cells; clear at small game scale; easy to recolor with modulate or luminance mask; no text, labels, letters, numbers, icons, borders, grid lines, characters, hands, weapons, faces, skulls, runes, occult symbols, medical cross, logos, or watermark.
Avoid: photorealism, glossy 3D rendering, smooth vector polish, high-frequency noise, mushy airbrush, meaningless repeated dots, duplicated shapes, false seams, broken geometry, generic magic circles, clock-face marks, radial grids, components crossing cells.
```

Targeted built-in edit prompt used for the final padded version:

```text
Use case: precise-object-edit
Input images: Image 1 is the edit target, a 1536x1024 healing and void component atlas.
Primary request: Preserve the same exact six grayscale components, their reading-order identities, the strict 3-column by 2-row layout, coarse hand-painted style, tonal hierarchy, and pure-black background. Change only scale and placement inside each implied 512x512 cell: uniformly shrink and recenter every component so every active painted mark, stray fleck, and glow is contained inside the central 360x360 area of its own cell, leaving at least 76 pixels of perfectly pure black internal padding on all four sides of all six cells. Remove any tiny outlying flecks that would violate this padding.
Canvas and grid invariant: output exactly 1536x1024; invisible strict 3 columns x 2 rows; each cell exactly 512x512; no divider lines; no mark may touch or cross any cell edge.
Color invariant: strictly achromatic grayscale on pure black #000000, no colored fringe.
Content invariant in reading order: R1C1 broken healing ring; R1C2 five-wisp restorative fountain; R1C3 four-lobed life-energy bloom; R2C1 two-arm inward void spiral; R2C2 low irregular void residue pool; R2C3 directional dissolving void fragments. Do not replace, merge, duplicate, relabel, or redesign any component.
Constraints: exactly one self-contained component per cell; no new objects, text, symbols, border, watermark, grid line, scene, floor plane, or background texture. Keep crisp readable silhouettes and coarse broken edges; no blur or extra bloom.
```

## Independent-review revision 2

An independent visual review rejected the first candidate with Important
findings. The replacement PNGs were locked on 2026-08-08 after the following
changes:

- Both atlases were deterministically converted to grayscale, with values at or
  below `16` mapped to `RGB(0, 0, 0)`. Each component was cropped to its active
  bounds, proportionally reduced only when required, and recentered in its own
  cell. The final RGB channels are identical.
- `contact_flash_hit_debris_atlas_v1.png` uses a minimum `56 px` all-black
  per-cell gutter. R2C1 now has six broad stone chunks; R2C2 has six coarse,
  non-radial wooden splinter groups without glossy ice/metal facets; R2C3 was
  simplified and recentered.
- `healing_void_components_atlas_v1.png` uses a minimum `76 px` all-black
  per-cell gutter. R2C3 was replaced with exactly five separated broad shadow
  chunks and three short pale wisps. The pieces contain no dense internal crack
  network and read as evaporating void residue rather than ice or stone.
- Deterministic checks on the locked files report `1536 x 1024`, RGB mode,
  grayscale channel delta `0`, and maximum RGB value `0` throughout every
  required gutter. Actual nonzero padding is listed below in L/T/R/B order.

| Atlas | Cell padding evidence |
|---|---|
| Contact | R1C1 `132/121/132/122`; R1C2 `59/108/60/108`; R1C3 `92/100/92/100`; R2C1 `100/109/100/109`; R2C2 `94/104/95/105`; R2C3 `70/145/71/145` |
| Healing/Void | R1C1 `151/158/152/158`; R1C2 `159/133/159/134`; R1C3 `160/166/160/166`; R2C1 `156/142/156/142`; R2C2 `140/183/141/183`; R2C3 `93/146/94/147` |

The final contact content edit used this built-in prompt:

```text
Use case: precise-object-edit
Input images: Image 1 is the edit target, a strict 1536x1024, 3-column by 2-row reusable contact VFX atlas.
Primary request: Preserve the exact canvas, invisible 3x2 grid, pure-black backdrop, grayscale hand-painted style, and all three top-row components. Redraw and simplify only the three bottom-row material/debris components to resolve visual review findings.
Bottom-row changes in reading order:
- R2C1: exactly 7 separate broad stone chunks, no more and no fewer. Use 3 medium angular rocks and 4 smaller blunt rocks, irregularly spaced as one compact top-down burst. No tiny flecks. Chunky stone facets, not crystal. Contain all marks inside the central 384x384 region of the 512x512 cell.
- R2C2: exactly 7 separate coarse wooden splinters, no more and no fewer. Use thick irregular bark/wood chips with blunt broken ends, varied lengths and rotations, loosely scattered rather than arranged as a radial star. Use coarse dry-brush grain and dark knot-like notches, not glossy facets. It must read clearly as wood, never ice, metal, crystal, light rays, or an energy explosion. No tiny flecks and no repeated wedge pattern. Contain all marks inside the central 384x384 region of the cell.
- R2C3: one compact generic impact-debris fan made from exactly 5 blunt irregular shards plus exactly 3 short broad motion streaks, with ample separation and no tiny flecks. Preserve left-to-right direction. Contain all marks inside the central 384x384 region of the cell.
Grid and padding invariant: exact output 1536x1024; each implied cell exactly 512x512; at least 64 pixels of perfectly empty black padding on all four sides of every cell; no component, fleck, brush mark, or glow may enter that padding; nothing crosses a cell boundary; do not draw dividers.
Style invariant: coarse broken hand-painted edges, large readable value clusters, restrained four-step achromatic grayscale, crisp silhouettes, non-photorealistic, runtime-tintable. Preserve the top row identities: R1C1 contact flash, R1C2 directional spark fan, R1C3 hollow metal collision star.
Constraints: black background only; no text, labels, borders, grid lines, characters, weapons, smoke, dust clouds, explosion fireballs, magic circles, watermark, colored fringe, high-frequency noise, or extra debris pieces.
```

The final whole-atlas healing/void edit used this built-in prompt:

```text
Use case: precise-object-edit
Input images: Image 1 is the edit target, a strict 1536x1024, 3-column by 2-row healing and void VFX atlas.
Primary request: Preserve the exact six component identities, reading-order layout, achromatic hand-painted style, and pure-black backdrop. Uniformly shrink and recenter all six components, and completely redraw only R2C3 to resolve visual review findings.
Whole-atlas padding change: each component and every fleck, glow, wisp, brush mark, and detached scrap must fit entirely inside the central 336x336 area of its own 512x512 cell. This leaves at least 88 pixels of perfectly empty pure black on every side of all six cells. Do not allow any outlier outside that central area.
R2C3 replacement: redraw as one compact left-to-right DISSOLVING VOID RESIDUE component made of exactly 5 separate broad torn shadow-energy chunks plus exactly 3 separate short soft wisps. The five chunks must be solid charcoal-to-mid-gray painted masses with simple coarse torn outer silhouettes and at most one broad value patch each. No internal crack lines, no crystalline facets, no sharp rock geometry, no ice-like shard texture. The three wisps must be short, thick, soft-edged fading brush tails, not long projectile streaks. Keep the grouping sparse and clearly countable: five chunks and three wisps only, with ample black separation. It must read as evaporating shadow residue, not ice, stone, metal, glass, smoke cloud, or projectile debris.
Grid invariant: exact output 1536x1024; invisible strict 3 columns x 2 rows; each cell exactly 512x512; no divider lines; nothing crosses cells.
Preserved identities: R1C1 broad broken healing ring; R1C2 five-wisp restorative fountain; R1C3 four-lobed life-energy bloom; R2C1 two-arm inward void spiral; R2C2 low irregular void residue pool; R2C3 five torn void chunks plus three short wisps.
Style invariant: coarse broken hand-painted edges, large readable value clusters, limited four-step grayscale, crisp silhouette, non-photorealistic, runtime-tintable. No excess bloom or high-frequency texture.
Constraints: pure black background only; no text, labels, numbers, symbols, borders, grid lines, characters, faces, skulls, runes, medical cross, magic circle, watermark, colored fringe, tiny flecks, dense cracks, repeated spikes, or extra fragments.
```

The final R2C3 count/layout correction used this built-in prompt:

```text
Use case: precise-object-edit
Input images: Image 1 is the edit target. Edit ONLY the bottom-right R2C3 cell; preserve all other pixels and cells.
Primary request for R2C3: Replace the current residue arrangement with a new, sparse, explicitly countable arrangement of exactly eight isolated shapes: FIVE dark torn void chunks on the left two-thirds and THREE pale short wisps in a vertical column on the right.
Required five chunk placement, all separated by clear black gaps:
1. one broad dark chunk at upper-left;
2. one broad dark chunk at upper-middle;
3. one broad dark chunk at middle-left;
4. one broad dark chunk at middle-middle;
5. one broad dark chunk alone at lower-middle.
Required three wisp placement, all separated by clear black gaps:
1. one short pale wisp at upper-right;
2. one short pale wisp at middle-right;
3. one short pale wisp at lower-right.
Each dark chunk is a simple solid charcoal-to-mid-gray evaporating shadow patch with a coarse rounded torn outline and one broad soft value patch, never a stone shard. Each pale wisp is short, thick, soft-edged, and horizontally fading. EXACTLY five chunks and exactly three wisps; no extra shapes, tiny flecks, cracks, facets, streaks, or glow specks.
Padding: keep all eight shapes within the central 320x320 area of the 512x512 R2C3 cell, leaving at least 96 pixels pure black on all four sides. No mark crosses cells.
Canvas/grid invariant: exact 1536x1024 RGB, pure black background, invisible 3x2 grid, 512x512 cells. Preserve R1C1 healing ring, R1C2 healing fountain, R1C3 healing bloom, R2C1 void spiral, and R2C2 void pool exactly.
Style: achromatic, coarse hand-painted, large clean value clusters, no high-frequency details. The five chunks must read as soft evaporating void residue, not ice, rock, metal, glass, projectile shards, feathers, or leaves.
No text, border, grid line, symbol, watermark, color, or added object.
```

## Independent-review revision 3

The second independent review found two remaining Important composition issues.
Only Contact R2C2 and Healing/Void R2C3 were replaced; deterministic cell hashes
confirmed the other ten `512 x 512` cells stayed byte-identical.

- Contact R2C2 now uses six individual wood fragments of different lengths,
  widths, angles, broken silhouettes, and material marks. They form one
  asymmetric shattered-wood group instead of six equal-angle bundles of
  parallel rods. During generation, the useful wood candidate drifted into the
  generated candidate's R2C3 despite the edit instruction; only that generated
  cell was selected, normalized, and composited into the locked atlas's R2C2.
- Healing/Void R2C3 now reads as one overlapping dissolving shadow cluster:
  five differently sized dark sheets interlock at the left/center, while three
  unequal short wisps leave different points on the right edge. It no longer
  uses a `2 + 2 + 1` sample matrix or a separate vertical wisp column.
- Each replacement cell was converted to grayscale, mapped at `<=16` to true
  `RGB(0, 0, 0)`, proportionally fit inside a `360 x 360` active envelope, and
  centered. Contact R2C2 has actual nonzero padding `76/115/76/115`; Healing/
  Void R2C3 has `76/142/76/143`. Both complete PNGs have channel delta `0` and
  their full `76 px` cell moats have maximum RGB value `0`.

Locked SHA-256:

| Atlas | SHA-256 |
|---|---|
| `contact_flash_hit_debris_atlas_v1.png` | `0DEB349D10394F774A70DEE2367F6FE404C81514D6B0C80762A77BA679D2B9B6` |
| `healing_void_components_atlas_v1.png` | `5DFC708812AEA61D40CFAFC49E55EBD28F41E66383FA74E2D4DEFD2D4DD40E65` |

Final built-in wood-material edit prompt:

```text
Use case: precise-object-edit
Input images: Image 1 is the edit target. Change ONLY R2C2. Preserve the six other atlas cells exactly.
Primary request: Keep R2C2's current count of exactly seven unique single fragments and its irregular asymmetric grouping, but restyle those seven shapes from thick beveled stone slabs into unmistakable FLAT SHATTERED WOOD / BARK SPLINTERS.
Required material correction: remove all 3D beveled side faces, masonry thickness, stone facets, smooth polygon edges, and ceramic appearance. Each fragment must be a flat hand-painted wood silhouette with rough bark-darkened outer edges, fibrous jagged snapped ends, one wedge-shaped missing bite, and one short irregular TRANSVERSE grain/knot mark. Use broad matte gray value clusters: dark charcoal bark rim, medium-gray wooden body, one off-white dry-brush highlight. No long grain stripes and no parallel internal lines.
Keep the seven shapes distinct and varied: long crooked notched board, wide bark plate, short bent chip, tapered wedge, curved bark strip, squat triangular splinter, asymmetrical medium plank. Make every end torn and uneven. Shapes may overlap into one cluster, but do not merge them into bundles.
Composition: one compact off-center left-to-right shattered-wood burst with overlapping depth and uneven gaps. Preserve no rows, columns, equal-angle radial layout, symmetry, duplicated contours, or presentation-board spacing.
Count/silhouette invariant: exactly seven individual flat wood fragments, seven distinct outer silhouettes total. Never multiple rods inside one fragment; no sticks, chopsticks, bamboo, pencils, ice, crystal, rocks, stone tiles, metal, feathers, or light beams.
Padding: entire cluster within central 320x320 of the 512x512 R2C2 cell, leaving at least 96 pixels pure black on each side.
Canvas/grid: exact 1536x1024 RGB, pure-black background, strict invisible 3x2 grid, no dividers or cross-cell art.
No text, symbols, watermark, color, glow, smoke, dust, sparks, tiny debris, or extra objects.
```

Final built-in dissolving-cluster edit prompt:

```text
Use case: precise-object-edit
Input images: Image 1 is the edit target. Edit ONLY R2C3 and preserve the other five cells exactly.
Primary request: Keep R2C3 as one cohesive left-to-right dissolving void cluster with three staggered wisps, but clean the dark origin so it visibly consists of exactly FIVE overlapping broad torn sheets rather than one mushy cloud.
Five-sheet structure: draw five large simple charcoal/mid-gray paper-like shadow sheets with distinct sizes and distinct protruding torn contours. Overlap each neighboring pair by roughly one quarter of its area so the pieces form one dense cluster, while preserving a short readable boundary and a different broad value for each sheet. Use one dominant central sheet, a smaller upper-left sheet, a long lower-left sheet behind it, a medium upper-right peeling sheet, and a tapered lower-right sheet. Their silhouettes interlock and overlap; do not separate them into a matrix.
Surface cleanup: each sheet has one flat broad value mass and a coarse torn rim only. Remove granular texture, small blotches, noisy internal fragments, dense smoke mottling, cracks, facets, and repeated scallops. The cluster must be crisp and authored, not mushy.
Wisps: preserve exactly THREE short pale thick wisps, but attach their starts to three different locations along the cluster's right edge. Keep different height, length, curvature, and angle: upper wisp curves up, middle is nearly horizontal, lower curves down. They must stagger naturally and never align in a vertical presentation column.
Composition: one asymmetric overlapping dissolving mass with dense origin on left and sparse release to right. No rows, columns, equal spacing, symmetry, copied contours, display-board layout, or disconnected sample pieces.
Count invariant: exactly five overlapping dark sheets plus exactly three pale wisps. No extra flecks or shapes.
Padding: all R2C3 marks inside the central 320x320 area of its 512x512 cell, at least 96 pixels pure black on every side.
Canvas/grid: exact 1536x1024 RGB; pure-black backdrop; strict invisible 3x2 grid; no divider or cross-cell art.
Style: coarse hand-painted limited grayscale, large clean value clusters, soft torn void residue, no text, symbols, watermark, color, rock, ice, metal, glass, bevels, smoke cloud, projectile shards, glow specks, or high-frequency detail.
```

## Compositing guidance

- Bright contact components: use additive or screen blending, tint with
  `modulate`, and keep the core lifetime shorter than the debris lifetime.
- Physical debris: use screen/add for luminous magic impacts; use a
  luminance-to-alpha shader plus an opaque material tint for stone, wood, ice,
  or metal fragments.
- Healing: layer R1C1 below the actor, then stagger R1C2 or R1C3 above the
  contact point. Keep a bright center and a slower, lower-opacity outer fade.
- Void: derive alpha from luminance when a dark opaque mass is required. Use
  R2C1 for anticipation, R2C2 for ground residue, and R2C3 for directional
  afterimage; simple additive blending alone will only preserve the pale rim.
- These cells are semantic components, not animation frames. Rotate, mirror,
  scale, tint, and stagger them; use existing procedural primitives where exact
  endpoints, collision geometry, or continuous deformation must follow gameplay.

## Review status

Revision 3 passed independent native-detail, full-atlas, and fixed R1C1 through
R2C3 review on 2026-08-08 with Critical 0 and Important 0. The locked contact
and healing/void atlases were reviewed after the final component replacements.
Any later pixel, scale, position, z-order, or composition change invalidates
that verdict.
