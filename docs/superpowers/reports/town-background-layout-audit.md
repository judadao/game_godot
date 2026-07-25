# Town Modular Background Layout Audit

## Scope

This is a read-only layout recommendation for replacing the composite background
inside `scenes/maps/components/TownBackdrop.tscn`. Coordinates are local to
`TownBackdrop`, with the Town canvas spanning `x = 0..3900` and `y = 0..724`.
All listed `Sprite2D` positions assume centered sprites.

## Current-State Findings

- `TownBackdrop.tscn` currently uses a 2600-by-724 gradient sky centered at
  `(1300, 362)`.
- `town_background_clean_v3.png` is 1681 by 935 and is displayed at
  `(1333.6124, 239.65628)`, scale `(1.5757138, 1.0366979)`, `z_index = -20`.
  It contains sky, clouds, mountains, forest, and a distant city in one opaque
  image.
- `town_mid_near_layer.png` is 2039 by 771 and is displayed at
  `(1312.75, 400.5063)`, scale `(1.2900932, 1.0518968)`, `z_index = -10`.
  It contains a transparent near-town silhouette whose visible bottom aligns
  near the Town ground.
- The source parallax strips are each 2172 by 724. Their manifest marks them as
  prototype-only, non-seamless proxies, so they are useful as style references
  but should not be tiled as final modules.
- The established style is detailed bright pixel art: saturated cyan sky,
  cream/light-blue clouds, cool blue mountains, blue-green trees, slate-blue
  roofs, and warm sunlit walls. Lighting reads from the upper left.
- Town collision/ground references put the playable baseline around
  `y = 657`; background trees should finish no lower than `y = 650`, leaving
  the street layer at `z_index = -5` unobstructed.

## Recommended Scene Stack

Use linked child scenes under `TownBackdrop` in this order. Give each child
scene root the listed `z_index`; individual sprites can keep `z_index = 0`
relative to their root.

| Child scene | Root position | Root scale | Root z-index |
| --- | ---: | ---: | ---: |
| `TownSkyLayer` | `(0, 0)` | `(1, 1)` | `-50` |
| `TownCloudSet` | `(0, 0)` | `(1, 1)` | `-45` |
| `TownMountainSet` | `(0, 0)` | `(1, 1)` | `-40` |
| `TownDistantBuildings` | `(0, 0)` | `(1, 1)` | `-30` |
| `TownTreeSet` | `(0, 0)` | `(1, 1)` | `-20` |

Keep `TownBackdrop` itself at `(0, 0)`, scale `(1, 1)`. Do not scale a linked
child scene at the composition level; scaling belongs only on individual
sprites. This prevents the nested-scale multiplication present in the current
composite setup.

## Exact Composition

### Sky

`TownSkyLayer` should contain one opaque 3900-by-724 sky sprite:

| Node | Position | Scale | z-index |
| --- | ---: | ---: | ---: |
| `Sky` | `(1950, 362)` | `(1, 1)` | `0` |

Use a vertical gradient close to the current palette: top `#73BAF5`, middle
`#C4E3FC`, horizon `#FAE6BD`. The sky must cover the full canvas without
texture repeat or horizontal stretching.

### Clouds

Generate five transparent, tightly trimmed cloud modules at roughly
384-by-192 pixels. Preserve transparent corners and left-side cream highlights.

| Node | Module | Position | Scale | Flip H |
| --- | --- | ---: | ---: | --- |
| `Cloud01` | broad cumulus | `(330, 165)` | `(1.10, 1.10)` | no |
| `Cloud02` | low wispy cluster | `(1040, 275)` | `(0.82, 0.82)` | no |
| `Cloud03` | tall cumulus | `(1780, 125)` | `(1.15, 1.15)` | yes |
| `Cloud04` | broken mid cloud | `(2580, 245)` | `(0.90, 0.90)` | no |
| `Cloud05` | broad cumulus variant | `(3470, 155)` | `(1.05, 1.05)` | yes |

The open intervals are intentional: retain blue-sky breathing room over
`x = 1250..1500` and `x = 2850..3150`. Cloud bottoms should remain above
`y = 350`.

### Mountains

Generate four transparent mountain-ridge modules at roughly 1024-by-420
pixels, with their visible ridge bases at the bottom of each image. Place them
with 120-220 pixels of visual overlap so no sky gap reaches the forest horizon.

| Node | Module | Position | Scale | Flip H |
| --- | --- | ---: | ---: | --- |
| `Mountain01` | medium multi-peak ridge | `(480, 430)` | `(1.05, 1.05)` | no |
| `Mountain02` | tall hero peak | `(1470, 405)` | `(0.96, 0.96)` | yes |
| `Mountain03` | medium broken ridge | `(2490, 435)` | `(1.08, 1.08)` | no |
| `Mountain04` | tall hero peak variant | `(3490, 410)` | `(0.98, 0.98)` | no |

Target the mountain base at `y = 570 +/- 15`. Mountain blue values should be
lighter and less saturated than foreground roofs; the hero peaks should not
all land at the same height.

### Distant Buildings

Generate six transparent town-silhouette groups at roughly 640-by-300 pixels.
Each module should contain multiple roofs/towers rather than one isolated
building. Their visible bottom edge should sit at the image bottom.

| Node | Module | Position | Scale | Flip H |
| --- | --- | ---: | ---: | --- |
| `DistantBuildings01` | low roofs + one tower | `(310, 555)` | `(0.92, 0.92)` | no |
| `DistantBuildings02` | dense roof cluster | `(960, 570)` | `(0.84, 0.84)` | yes |
| `DistantBuildings03` | clock/spire cluster | `(1600, 545)` | `(1.00, 1.00)` | no |
| `DistantBuildings04` | low roofs + twin towers | `(2250, 568)` | `(0.88, 0.88)` | no |
| `DistantBuildings05` | dense roof cluster | `(2910, 558)` | `(0.94, 0.94)` | yes |
| `DistantBuildings06` | tapering edge cluster | `(3600, 572)` | `(0.86, 0.86)` | no |

Target visible building bottoms at `y = 625`. Keep the tallest spire under
`y = 390`. The `x = 1500..1750` cluster is the visual anchor; the east extension
uses lower silhouettes so it feels continuous without duplicating the current
centerpiece.

### Trees

Generate seven transparent tree-cluster modules at roughly 640-by-260 pixels.
Use irregular deciduous crowns, blue-green shadow masses, and yellow-green
upper-left highlights. Their visible bottom edge should sit at the image bottom.

| Node | Module | Position | Scale | Flip H |
| --- | --- | ---: | ---: | --- |
| `Trees01` | medium rounded cluster | `(260, 610)` | `(1.00, 1.00)` | no |
| `Trees02` | low wide cluster | `(820, 625)` | `(0.92, 0.92)` | yes |
| `Trees03` | tall irregular cluster | `(1370, 600)` | `(1.08, 1.08)` | no |
| `Trees04` | medium broken cluster | `(1940, 618)` | `(0.96, 0.96)` | no |
| `Trees05` | tall irregular variant | `(2500, 602)` | `(1.04, 1.04)` | yes |
| `Trees06` | low wide cluster | `(3070, 625)` | `(0.94, 0.94)` | no |
| `Trees07` | medium rounded edge cluster | `(3660, 612)` | `(1.02, 1.02)` | yes |

Target visible tree bottoms at `y = 650`. Adjacent silhouettes should overlap
by about 80-140 pixels. Do not lower them to the `y = 657` collision baseline,
because a few pixels of separation helps the `z = -5` street/ground layer mask
their trimmed edges.

## Asset and Import Constraints

- Use one PNG per module, not an atlas region, so every node remains independently
  movable in the Godot editor.
- Preserve nearest-neighbor pixel art: texture filtering off, mipmaps off, and
  integer sprite positions after final visual tuning.
- Generate at or above the target native sizes above. No recommended scale
  exceeds `1.15`, comfortably below the design limit of `2.0`.
- Use premultiplied-looking clean alpha edges: transparent corner pixels must
  have zero alpha and should not retain cyan, white, or black matte fringes.
- Avoid perfect horizontal mirroring of any module with a unique tower, flag,
  text-like mark, or directional lighting. The `Flip H` entries above are safe
  only for cloud, ridge, roof-mass, and foliage variants whose upper-left
  lighting is repainted after generation if the flip becomes noticeable.
- Keep all five layer scenes free of references to `TownBackdrop.tscn`;
  `TownBackdrop.tscn` should be the sole composition owner.

## Coverage and Review Checks

1. At camera positions centered near `x = 0`, `1300`, `2600`, and `3900`, the
   viewport must show sky plus at least one cloud, mountain, building, and tree
   silhouette where the layer is vertically visible.
2. Inspect `x = 2600` specifically. No module edge or repeated motif should
   announce the old map boundary.
3. Confirm the outermost mountains and trees extend beyond `x = 0` and
   `x = 3900` after their scales are applied, so camera rounding cannot expose
   transparent slivers.
4. Confirm every cloud, mountain, building group, and tree cluster is a distinct
   `Sprite2D` node and can be moved independently.
5. Confirm all sprite scales remain uniform (`scale.x == scale.y`) and at or
   below `2.0`.
6. Run the scene with nearest-neighbor rendering and check for alpha halos,
   non-integer placement shimmer, and foreground overlap near `y = 650`.

