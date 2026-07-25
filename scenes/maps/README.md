# Map editing entries

## Authoritative scenes

- Town: `res://scenes/maps/town/TownMap.tscn`
- Autumn Forest: `res://scenes/maps/autumn_tree/AutumnTreeMap.tscn`

Open these `*Map.tscn` scenes in Godot to edit the playable map. The canonical
portal paths (`town.tscn` and `autumn_forest.tscn`) resolve to these entries at
runtime; do not use a legacy layout scene as an editing or runtime entry.

Town exposes `ParallaxBackground`, `Buildings`, `Ground`, `Props`, `Portals`,
`NPCs`, `WorldCollision`, the player spawn, `EditorHUDReference`, and
`EditorHelpers`. Autumn Forest exposes its background, terrain, platforms,
set dressing, run director, interactables, portals, collision, player spawn,
`EditorHUDReference`, and `EditorHelpers`. Expand editable children in the
Scene tree to adjust their Inspector overrides.

## Per-map HUD preview and runtime adoption

Every authoritative map instances `EditorHUDReference`. Its editable children
are the source for that map's runtime UI:

- `EditorHUDReference/HUD` is the HUD preview and runtime HUD instance.
- `EditorHUDReference/CardHandUI` is the card-hand preview and runtime card-hand
  instance.
- `CardHandUI.tscn`, including its `CardFan`, is the runtime-authoritative card
  layout. Edit static safe-area and control placement there (or through the
  map's editable child overrides). Gameplay creates only the variable card
  buttons inside `CardFan`.

When a map loads, `Game.load_hud()` and `Game.load_card_hand()` reparent those
exact instances to `Game/HUDLayer`. Root anchors, offsets, position, scale, and
other Inspector overrides must remain intact; do not replace them with duplicate
HUD or card-hand instances.

`EditorHelpers` and the `EditorHUDReference` overlay are hidden during normal
runtime map play. Use the Scene tree and Inspector to adjust map content and
the editable UI children, then run the map or main game to verify the adopted
HUD at 1280x720, 1600x900, 1920x1080, and 2560x1440.
