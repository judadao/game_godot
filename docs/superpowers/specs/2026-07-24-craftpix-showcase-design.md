# CraftPix Showcase Design

## Goal

Turn the existing Godot prototype into a playable asset showcase with Town as
the central hub, three themed environment scenes, an RPG-styled HUD and
inventory, dungeon props, and an animated magic-book portal.

## Chosen Approach

Use separate scenes connected through a small scene-navigation API. This keeps
each visual theme independent, lets future gameplay replace one map without
rewriting the others, and avoids loading every high-resolution source asset
into Town at once.

Rejected alternatives:

- Putting every asset into Town would make one oversized, visually incoherent
  scene.
- Building static preview galleries would show the art but would not produce a
  useful playable prototype.

## Scene Architecture

`scenes/game/game.tscn` remains the main scene. `scripts/managers/game.gd`
owns map changes and exposes `change_map(map_path: String)`.

The playable map set is:

- `scenes/maps/town.tscn`: central hub, existing player movement retained,
  upgraded with CraftPix props and four labeled destinations.
- `scenes/maps/autumn_forest.tscn`: warm forest environment with layered
  background, platforms, foliage, collectibles, and a return portal.
- `scenes/maps/crystal_caves.tscn`: cool cave environment with crystal props,
  platforms, collectibles, and a return portal.
- `scenes/maps/forbidden_graveyard.tscn`: dark graveyard environment with
  tombs, trees, platforms, collectibles, and a return portal.

Each environment is a side-view 2D scene sized for the existing horizontal
player controller. Each map owns its floor and boundary collisions and
instantiates a player. Scene exits are `Area2D` nodes using a reusable
`scripts/maps/map_portal.gd` script.

## Town Upgrade

Town keeps the current buildings, NPCs, player, camera, and collision layout.
New CraftPix dungeon props decorate market and portal areas without covering
the walkable lane. A magic-book animation becomes the visual focus of the
travel area. Three nearby portals lead to the forest, caves, and graveyard.

Destination labels and input prompts make navigation discoverable. The
existing concept-art background remains because the downloaded environment
packs are platformer themes rather than a complete town replacement.

## UI

The HUD is restyled with the basic RPG UI textures and fantasy icons while
remaining readable at the current viewport size. It shows:

- current area name;
- movement and interaction hints;
- compact health and mana presentation;
- buttons for inventory and direct return to Town.

`InventoryUI.tscn` becomes a usable overlay with a framed item grid populated
from the 16x16 icon pack. The UI may use atlas regions or individual icon
files, but must not duplicate source textures.

## Props and Magic Book

Dungeon objects are composed into a reusable
`scenes/props/dungeon_props_showcase.tscn` scene. The scene groups traps,
supplies, pedestals, and decorative objects so Town and future maps can
instantiate it without duplicating texture declarations.

The magic book is implemented as
`scenes/props/magic_book_portal.tscn` with an `AnimatedSprite2D` or scripted
frame sequence using the supplied book sprites. It has an idle/opening visual
loop and may act as a portal when given a target map.

## Interaction and Data Flow

1. Game loads Town and the HUD.
2. A portal emits or invokes a map-change request through the Game node.
3. Game removes the current map, instantiates the requested map, and updates
   the HUD area label.
4. Every themed map provides a clearly marked route back to Town.
5. UI overlays pause only their own input; they do not destroy or reload maps.

Invalid map paths produce `push_error` and leave the current map intact.
Portals ignore repeated body-entry events while a transition is active.

## Agent Work Split

Five bounded agents implement non-overlapping domains:

1. Autumn Forest scene.
2. Crystal Caves scene.
3. Forbidden Graveyard scene.
4. RPG HUD and inventory UI.
5. Dungeon props, magic-book portal, and Town integration.

The root agent owns shared navigation changes, conflict resolution, final
integration, and full-project verification.

## Verification

- Parse every new or modified `.tscn` and `.gd` file with Godot 4.7.1.
- Run the project headlessly and confirm no load, script, or missing-resource
  errors.
- Verify all four maps can be instantiated independently.
- Verify every themed map contains a player, collisions, and a Town return
  route.
- Verify Town exposes all three themed destinations.
- Verify HUD and inventory scenes instantiate without errors.
- Do not stage generated `.import` files unless a resource requires a custom
  import setting.
