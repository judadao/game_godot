# Town Rebuild Plan

## Visual contract

- Camera: side-view orthographic, no isometric or front-facing assets.
- Native target: 1280x720, world height 724 px.
- Active Eternal Forge road baseline: y=672 px; player, NPCs, and portals share
  this baseline. Hidden legacy props retain their original authoring baseline.
- Visible road art begins at y=660 px and overlaps the unchanged gameplay
  baseline by 12 px, so character feet and building foundations cannot expose
  the background between the foreground and floor.
- Lighting: warm daylight from upper left; shadows fall down-right.
- Pixel density: detailed 32-bit pixel art, approximately 2 px of outline at gameplay scale.
- Palette: warm limestone, dark oak, blue slate roofs, restrained red shop awnings, brass accents.
- Scale anchors: player 112 px tall, NPC 120-150 px, house 320-390 px tall, door 120 px tall.
- Collision: only ground, map boundaries, and explicitly marked architecture block movement. Decorative props never block roads.

## World layout

The Eternal Forge town keeps a 1942x720 gameplay world and a y=672 baseline.
Runtime displays the approved Base modular composition. The 72 independently
replaceable entries in `data/town_modular_layout.json` are the shared runtime,
editor, and Figma layout. Locked-A Image #2 remains a hidden composition reference.
Existing canonical map identity, portal
targets, spawn transfer, HUD adoption, camera, collision, and save contracts remain
unchanged.

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

Candidate Town presentation sources live under `assets/town/modular_v1/`,
`assets/town/modular_v2/`, and `assets/town/modular_v3/`. The locked A background
layers and Base foreground sources provide 46 unique PNGs reused as 72 selectable
scene entries:

1. `background/`
   - modular-v3 `town_a_background_plate.png`,
     `autumn_forest_canopy_base_v2.png`, and
     `autumn_ancient_tree_base_v2.png`. The generated canopy provides the missing
     layered orange/ochre/russet foliage behind the full roofline; the isolated
     tree provides the central focal tree without becoming a foreground close-up.
     Green legacy and parallax forest materials are forbidden from the visible
     composition. The legacy forest stable ID now owns the approved autumn canopy;
     legacy mountain and city entries remain hidden.
2. `ground/`
   - `stone_road_tile.png` and `bridge_wall_tile.png`, each instanced as eight
     independently replaceable visible modules. Road-patch dressing remains hidden
     so it cannot repaint the continuous stone surface.
3. `buildings/`
   - Material Yard, Player Forge, Town Hall, Sword Soul Shop, Blueprint Research,
     and East Residence.
4. `landmarks/`
   - Eternal Forge Monument uses the refined aspect-locked MaterialYard-style Base
     v4 source; Battle Portal also uses Base v4. They retain the fire bowl,
     rune-tower silhouette, stone arch, and blue-purple vortex while matching
     Material Yard's deliberate pixel clusters, irregular gray-blue masonry, coarse
     broken linework, limited shade ramps, neutral base light, and structural AO.
     The Base v4 monument keeps roughly 4x source-to-display density so its stone,
     copper, and banner detail remains compatible with adjacent Base buildings.
5. `props/`
   - street lantern, forge/soul braziers, hanging banner, west fence, notice board,
     material crates/barrels, and forge anvil. These modular-v1 entries remain hidden
     for stable-ID compatibility and do not participate in runtime composition.
6. `modular_v2/buildings`, `modular_v2/props`, and `modular_v2/streetscape`
   - six perspective-locked B2 buildings plus 18 visual-only market, household,
     planting, and road-dressing sources. Twelve remain visible; six large east-side
     facade blockers remain hidden stable entries.

All buildings use the shared `b2_front_right_orthographic` profile: front face
dominant, narrow right face, vertical uprights, upper-right depth recession, and
horizontal foundations on the common gameplay baseline.
Town Hall, Sword Soul Shop, Equipment Blueprint Shop, and Far East Residence use
MaterialYard-style Base v3 candidates at approximately 4x source-to-display pixel
density, so the east side does not lose scale or facade detail.

## Scene architecture

- `town.tscn` owns zoning, spawn markers, background, ground and world collision.
- `data/town_modular_layout.json` is the single 72-entry visual layout contract.
- `data/town_visual_style.json` defines the shared hand-inked storybook pixel-art
  palette, lighting direction, paper-grain surface treatment, concept source, and
  exact 46-source coverage.
- `tools/build_town_modular_scene.py` generates the static, editor-visible
  `scenes/maps/town/components/TownModularVisuals.tscn`; runtime does not rebuild
  authored Town layout from script.
- `TownBackdrop.tscn` displays its linked `TownModularVisuals` instance.
  `concept/town/main_horizontal_concept/town_style_direction_a_locked.png`
  remains linked but hidden as the composition reference.
- Generated visual children do not own interactions. The six building triggers remain
  in `TownBuildingEntrances.tscn`, and BattleGateway remains in `TownPortalSet.tscn`.
- Six building labels use the B2 plaque asset and project the corresponding foundation
  trigger: hidden away from buildings, visible above the current building only while a
  Player-group body is inside its full-foundation Area.
- NPC visuals, collision, portal signals, target fields, and progression ownership remain
  in their existing scenes.
- `tools/build_town_modular_figma_board.py` produces one Figma discussion board:
  exact Image #2 first, then the reconstructed candidate and selectable object library.

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
- No hidden modular-v1 street prop or hanging banner is visible at runtime.
- Building labels stay above silhouettes and only appear for Player foundation proximity.
- All seven NPC roles display exactly one visual.
- No Town building UI is triggered by an NPC.
- Every shop, dialogue and portal can be reached by keyboard.
- Town BattleGateway enters the portal hub and the hub return interaction restores Town.
- Background and ground cover the full camera width at every supported window size.
- The generated scene exposes exactly 72 stable object IDs across background, ground,
  facility, landmark, and street-prop groups.
- The Figma board locks exact Image #2 as its first section. Its candidate section and
  `TownModularVisuals.tscn` are regenerated from the same JSON instead of maintaining
  separate placement data.
