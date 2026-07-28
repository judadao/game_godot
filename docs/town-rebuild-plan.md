# Town Rebuild Plan

## Visual contract

- Camera: side-view orthographic, no isometric or front-facing assets.
- Native target: 1280x720, world height 724 px.
- Active Eternal Forge road baseline: y=672 px; player, NPCs, and portals share
  this baseline. Hidden legacy props retain their original authoring baseline.
- Lighting: warm daylight from upper left; shadows fall down-right.
- Pixel density: detailed 32-bit pixel art, approximately 2 px of outline at gameplay scale.
- Palette: warm limestone, dark oak, blue slate roofs, restrained red shop awnings, brass accents.
- Scale anchors: player 112 px tall, NPC 120-150 px, house 320-390 px tall, door 120 px tall.
- Collision: only ground, map boundaries, and explicitly marked architecture block movement. Decorative props never block roads.

## World layout

The Eternal Forge v1 town uses one 1942x720 side-scrolling image segment. Existing
canonical map identity, portal targets, spawn transfer, HUD adoption, and save
contracts remain compatible while camera and collision bounds match that segment.

| Range | District | Purpose |
| --- | --- | --- |
| x=0-240 | Material Yard | Player spawn, guard and material supply shop |
| x=240-520 | Player Forge | Player home, blacksmith forge and blacksmith interaction |
| x=520-760 | Eternal Flame | The single monument landmark and town progression focus |
| x=760-980 | Battle Portal Plaza | One BattleGateway leading to the dedicated portal hub |
| x=980-1220 | Civic Hall | Mayor and town progress interaction |
| x=1220-1460 | Sword Soul Shop | Merchant interaction and purple soul-magic storefront |
| x=1460-1700 | Blueprint Research | Research landmark and future presentation refinement |
| x=1700-1942 | Soul Refinery | Innkeeper/refinery district |

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
   - Town BattleGateway plus the portal-hub region entrances.
6. `town_npcs_atlas_v2.png`
   - player-scale mayor, merchant, innkeeper, blacksmith, guard, male villager and female villager.

## Scene architecture

- `town.tscn` owns zoning, spawn markers, background, ground and world collision.
- Each building remains a separate `.tscn` scene.
- Each interactive NPC remains a separate `.tscn` scene and keeps its existing interaction ID.
- Decorative props use split scenes or AtlasTexture regions but have no collision by default.
- Portal scenes keep the current portal signals and target fields; only their visuals are replaced.

## Interaction preservation

- NPC roles are display-only and own no interaction area.
- Material Yard, Player Blacksmith, Town Hall, and Sword Soul Shop each own a
  full-foundation interaction trigger.
- Design Research and Soul Refinery are services inside Player Blacksmith.
- The two east-side buildings have full-foundation residence information
  triggers but no public services.
- Forest portal: `forest_portal`
- Caves portal: `caves_portal`
- Graveyard portal: `graveyard_portal`
- Town contains one BattleGateway; internal fast travel is retired for the compact map.
- The hub contains four region slots around a centered final-boss reservation.

## Acceptance checks

- No mixed perspective or mismatched pixel density.
- No decorative object blocks the player.
- All seven NPC roles display exactly one visual.
- No Town building UI is triggered by an NPC.
- Every shop, dialogue and portal can be reached by keyboard.
- Town BattleGateway enters the portal hub and the hub return interaction restores Town.
- Background and ground cover the full camera width at every supported window size.
