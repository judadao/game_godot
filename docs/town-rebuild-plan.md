# Town Rebuild Plan

## Visual contract

- Camera: side-view orthographic, no isometric or front-facing assets.
- Native target: 1280x720, world height 724 px.
- Ground baseline: y=632 px; every prop and character shares this baseline.
- Lighting: warm daylight from upper left; shadows fall down-right.
- Pixel density: detailed 32-bit pixel art, approximately 2 px of outline at gameplay scale.
- Palette: warm limestone, dark oak, blue slate roofs, restrained red shop awnings, brass accents.
- Scale anchors: player 112 px tall, NPC 120-150 px, house 320-390 px tall, door 120 px tall.
- Collision: only ground, map boundaries, and explicitly marked architecture block movement. Decorative props never block roads.

## World layout

The rebuilt town remains 2600x724 so existing camera and save data remain compatible.

| Range | District | Purpose |
| --- | --- | --- |
| x=0-430 | West Gate | Player spawn, return fast-travel portal, guard post, visual town entrance |
| x=430-900 | Residential Lane | Two homes, mayor route, notice board, flowers and benches |
| x=900-1420 | Civic Square | Town hall, mayor, well, quest focus and open circulation space |
| x=1420-1960 | Market Street | Item shop, inn, merchant stalls, potion merchant and innkeeper |
| x=1960-2300 | Artisan Row | Blacksmith workshop, forge props, blacksmith and storage |
| x=2300-2600 | Portal Plaza | Forest, cave and graveyard portals plus fast travel back to entrance |

## Asset batches

1. `town_background_v2.png`
   - sky, distant mountains, forest and roof silhouettes in one coherent parallax panorama.
2. `town_street_atlas_v2.png`
   - continuous street, curb, drain, stairs and plaza variation.
3. `town_buildings_atlas_v2.png`
   - residence A/B, town hall, item shop, inn and blacksmith.
4. `town_props_atlas_v2.png`
   - notice board, well, lamp, bench, fence, crates, barrels, flower bed, forge and market cart.
5. `town_portals_atlas_v2.png`
   - fast travel, autumn forest, crystal cave and graveyard portals sharing one stone-and-brass frame.
6. `town_npcs_atlas_v2.png`
   - player-scale mayor, merchant, innkeeper, blacksmith, guard, male villager and female villager.

## Scene architecture

- `town.tscn` owns zoning, spawn markers, background, ground and world collision.
- Each building remains a separate `.tscn` scene.
- Each interactive NPC remains a separate `.tscn` scene and keeps its existing interaction ID.
- Decorative props use split scenes or AtlasTexture regions but have no collision by default.
- Portal scenes keep the current portal signals and target fields; only their visuals are replaced.

## Interaction preservation

- Mayor: `town_mayor`
- Item merchant: `item_merchant`, shop `general_store`
- Blacksmith: `blacksmith`, shop `blacksmith`
- Innkeeper: `innkeeper`
- Forest portal: `forest_portal`
- Caves portal: `caves_portal`
- Graveyard portal: `graveyard_portal`
- Entrance/tail fast travel remains bidirectional.

## Acceptance checks

- No mixed perspective or mismatched pixel density.
- No decorative object blocks the player.
- All seven NPC roles display exactly one visual.
- Mayor interaction remains attached only to the bearded mayor.
- Every shop, dialogue and portal can be reached by keyboard.
- Town entrance and tail fast travel work in both directions.
- Background and ground cover the full camera width at every supported window size.
