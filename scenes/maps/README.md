# Map editing entries

## Authoritative scenes

- Town: `res://scenes/maps/town/TownMap.tscn`
- Autumn Safe Zone: `res://scenes/maps/autumn_safe/AutumnSafeZoneMap.tscn`
- Autumn Battle V2: `res://scenes/maps/autumn_battle/AutumnBattleMapV2.tscn`

Open these `*Map.tscn` scenes in Godot to edit the playable map. The canonical
portal paths (`town.tscn`, `autumn_safe_zone.tscn`, and `autumn_forest.tscn`) resolve to these entries at
runtime; do not use a legacy layout scene as an editing or runtime entry.

Town exposes `ParallaxBackground`, `Buildings`, `Ground`, `Props`, `Portals`,
`NPCs`, `BuildingEntrances`, `WorldCollision`, the player spawn,
`EditorHUDReference`, and `EditorHelpers`. Autumn Safe exposes its campfire,
seated trail merchant, Town/Battle portals, collision, player spawn, and a HUD
reference without a CardHand root. Autumn Battle exposes generated backdrop/route authorities, a
route-wide director, two safe-zone return portals, bounds, player spawn,
`EditorHUDReference`, and chunk-seam helpers. Expand editable children in the
Scene tree to adjust their Inspector overrides.

Town NPC scenes are display and body-collision only. Building UI triggers live
in `town/components/TownBuildingEntrances.tscn`; all six buildings own their
complete foundation range, building ID, UI route, and service context. The
former east residence is now the Equipment Blueprint Shop; only the far-east
residence remains information-only. Player Blacksmith owns blueprint forging,
workshop upgrades, Sword Soul upgrades, and crafted-equipment sales. Never add
an interaction area back to an NPC.

## Per-map HUD preview and runtime adoption

Every authoritative map instances a map-specific editor HUD reference. Its
editable children are the source for that map's runtime UI:

- Town uses
  `res://scenes/maps/town/editor/TownEternalForgeEditorHUDReference.tscn`,
  which owns the Town-only Eternal Forge HUD and card hand.
- Autumn Battle V2 uses
  `res://scenes/maps/autumn_battle/editor/AutumnEditorHUDReference.tscn`, which
  owns the Autumn-only `AutumnHUD.tscn`, `AutumnCardHandUI.tscn`, and
  `AutumnInteractionPrompt.tscn`.
- Crystal Caves and Forbidden Graveyard use
  `res://scenes/ui/hud/editor/SharedEditorHUDReference.tscn`.

Autumn Battle V2 is standalone and must not inherit or override the legacy
`autumn_forest.tscn` scene:

- `EditorHUDReference/HUD` is the HUD preview and runtime HUD instance.
- `EditorHUDReference/CardHandUI` is the card-hand preview and runtime card-hand
  instance.
- The card-hand scene selected by the map, including
  `CardRows/BackRow/FrontRow`, is the runtime-authoritative card layout. Edit
  static safe-area and control placement there (or through the map's editable
  child overrides). Gameplay creates only the variable card buttons inside the
  two authored row containers.

The battle route is `24 × 440 = 10560` pixels. Add traversal variety in
`scripts/maps/autumn_route_chunk.gd`; preserve a continuous floor and use only
optional one-way platforms. `AutumnRouteGenerator.regenerate(seed)` owns
runtime variation and repeatable backdrop tiling. Do not serialize generated
children into the main scene.
Runtime seed is available through `get_active_seed()` and `route_seed` metadata.
Hidden cache, wandering card merchant, and shortcut lever remain fixed,
nonblocking interaction landmarks over the generated route.
Raised chunks alternate with flat breathing-room chunks. Upper-canopy steps use
reachable vertical gaps; Down drops the Player through one-way platforms only.

When a map loads, `Game.load_hud()` and `Game.load_card_hand()` reparent those
exact instances to `Game/HUDLayer`. Root anchors, offsets, position, scale, and
other Inspector overrides must remain intact; do not replace them with duplicate
HUD or card-hand instances.

`EditorHelpers` and the `EditorHUDReference` overlay are hidden during normal
runtime map play. Use the Scene tree and Inspector to adjust map content and
the editable UI children, then run the map or main game to verify the adopted
HUD at 1152x720, 1280x720, 1600x900, 1920x1080, 2560x1080, and 2560x1440.

## Autumn Battle V2 UI contract

The world owns the upper 75% of the viewport and the Autumn HUD owns the lower
25%. The HUD and card overlay share the same six-column grid:

`23 status / 8 AP / 40 hand / 10 group guide / 11 objective+combo / 8 economy`

Keep Q/W/E/R as the four active card slots. A, S, LT, and RT each toggle
between the front and back groups; none of these inputs selects a specific
group. The interaction prompt follows its world target and is
clamped above the 75% world boundary, so it must not be manually positioned
inside the bottom HUD.

Autumn cards are authored through
`res://scenes/ui/autumn/AutumnBattleCard.tscn` and rendered by
`res://scripts/ui/autumn/autumn_card_hand_ui.gd`. Edit the card's internal information
zones in the component scene. Edit row spacing and the six-column reservation
in `AutumnCardHandUI.tscn`. Do not move individual runtime cards in the map
scene: their responsive size and front/back overlap are renderer-owned.

The expedition backpack contains 4–16 Combo or Healing cards. At run start it
is shuffled and four cards are drawn into one Q/W/E/R hand. Played cards recycle
through discard and are immediately replaced, so the hand remains at four.
T discards the current four and draws four replacements without consuming AP.
`ember_bolt` is an independently selected automatic attack and never enters
the hand or card piles. `quickstep` is not part of the card catalog.

Deck Builder selects auto attack independently from an unlocked attack card.
It consumes no backpack or HUD slot, costs no AP, never enters a card pile,
and is locked for the run. It fires only when a valid target is within its
close-range contract and never feeds the skill sequence.

Up only triggers Jump. Space triggers the player's intrinsic Dash. Dash has no
backpack, hand, pile, or AP representation. Dash Edge and Gale Drive remain
legacy catalog cards with `combat_hand = false`; they are not offered by the
deck builder or run rewards. Their infusions use `target_action = dash` to modify the intrinsic
Dash temporarily rather than moving the player directly.
