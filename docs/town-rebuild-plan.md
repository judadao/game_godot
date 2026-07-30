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

The Eternal Forge town keeps a 1942x720 gameplay world and a y=672 baseline.
Its visual source canvas is 1942x809 and is assembled from the 54 independently
replaceable entries in `data/town_modular_layout.json`. Existing canonical map
identity, portal targets, spawn transfer, HUD adoption, camera, collision, and save
contracts remain unchanged.

| Range | District | Purpose |
| --- | --- | --- |
| x=0-240 | Material Yard | Player spawn, guard and material supply shop |
| x=240-520 | Player Forge | Player home, blacksmith forge and blacksmith interaction |
| x=520-760 | Eternal Flame | The single monument landmark and town progression focus |
| x=760-980 | Battle Portal Plaza | One BattleGateway leading to the dedicated portal hub |
| x=980-1220 | Civic Hall | Mayor and town progress interaction |
| x=1220-1460 | Sword Soul Shop | Merchant interaction and purple soul-magic storefront |
| x=1460-1700 | Equipment Blueprint Shop | Permanent equipment blueprint merchant |
| x=1700-1942 | Far East Residence | Information-only residential district |

## Asset batches

All runtime Town presentation sources live under `assets/town/modular_v1/`.
The 28 unique PNG sources are reused as 54 selectable scene entries:

1. `background/`
   - `sky.png`, `mountain_layer.png`, `castle_layer.png`, `forest_layer.png`, and the
     independently replaceable `ancient_town_tree.png`.
2. `ground/`
   - `stone_road_tile.png` and `bridge_wall_tile.png`, each instanced as eight
     independently replaceable modules.
3. `buildings/`
   - Material Yard, Player Forge, Town Hall, Sword Soul Shop, Blueprint Research,
     and East Residence.
4. `landmarks/`
   - Eternal Forge Monument and Battle Portal.
5. `props/`
   - street lantern, forge/soul braziers, hanging banner, west fence, notice board,
     material crates/barrels, and forge anvil.

## Scene architecture

- `town.tscn` owns zoning, spawn markers, background, ground and world collision.
- `data/town_modular_layout.json` is the single 54-entry visual layout contract.
- `data/town_visual_style.json` defines the shared hand-inked storybook pixel-art
  palette, lighting direction, paper-grain surface treatment, concept source, and
  exact 28-source coverage.
- `tools/build_town_modular_scene.py` generates the static, editor-visible
  `scenes/maps/town/components/TownModularVisuals.tscn`; runtime does not rebuild
  authored Town layout from script.
- `TownBackdrop.tscn` instances `TownModularVisuals`. The old Eternal Forge composite
  remains available as a hidden compatibility/reference sprite.
- Generated visual children do not own interactions. The six building triggers remain
  in `TownBuildingEntrances.tscn`, and BattleGateway remains in `TownPortalSet.tscn`.
- NPC visuals, collision, portal signals, target fields, and progression ownership remain
  in their existing scenes.
- `tools/build_town_modular_figma_board.py` reads the same layout and PNG sources to
  generate both the reconstructed map and the selectable Figma object library.

## Interaction preservation

- NPC roles are display-only and own no interaction area.
- Material Yard, Player Blacksmith, Town Hall, and Sword Soul Shop each own a
  full-foundation interaction trigger.
- Blueprint forging, workshop upgrades, Sword Soul upgrades, and crafted-equipment
  sales are services inside Player Blacksmith.
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
- The generated scene exposes exactly 54 stable object IDs across background, ground,
  facility, landmark, and street-prop groups.
- The Figma board and `TownModularVisuals.tscn` are regenerated from the same JSON
  instead of maintaining separate placement data.
