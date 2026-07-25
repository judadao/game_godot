# Town East Extension Design

## Goal

Extend the playable Town map from 2600 pixels to 3900 pixels wide while preserving the complete existing street layout. The extension adds usable space only to the east and relocates the east fast-travel portal away from the current buildings.

## Layout Contract

- The existing Town area remains `x = 0–2600`.
- Existing buildings, NPCs, street props, the entrance portal, and the forest, cave, and graveyard portals retain their current local positions.
- The new east extension occupies `x = 2600–3900`.
- `EastRoadPortal` moves from `x = 2550` to `x = 3780`, using the existing ground baseline.
- `TownTailArrival` moves to `x = 3650`, leaving 130 pixels of horizontal clearance from the relocated portal and 250 pixels from the right boundary.

## Scene Changes

- `scenes/maps/town.tscn`
  - Change map width and camera right limit from 2600 to 3900.
  - Move only `TownTailArrival`; preserve all other existing layout nodes.
- `scenes/maps/components/TownStreetGround.tscn`
  - Extend the continuous street region to cover the full 3900-pixel map without seams.
- `scenes/maps/components/TownBackdrop.tscn`
  - Extend the background coverage to the new right edge while keeping the existing visual origin and vertical alignment.
- `scenes/maps/components/TownWorldCollision.tscn`
  - Extend the floor collision across the full map.
  - Move the right boundary to the new east edge.
- `scenes/props/town/TownPortalSet.tscn`
  - Move only `EastRoadPortal` into the new east extension.
  - Preserve the positions of the other four portal instances.

## Runtime Behavior

- The player camera can follow the player to `x = 3900`.
- The player can walk continuously from the existing street into the east extension.
- The right wall does not block the player before the relocated east portal.
- Activating the east portal returns the player to `TownEntranceArrival`.
- Activating the entrance fast-travel portal sends the player to the relocated `TownTailArrival`.

## Verification

Automated checks will assert:

- Town width and camera right limit equal 3900.
- The continuous ground and floor collision reach the new east edge.
- The right wall is positioned at or beyond the new map boundary.
- `EastRoadPortal` and `TownTailArrival` are inside the extension and separated safely.
- Existing buildings, NPCs, street props, and the other four portals retain their current positions.
- Town scene loading and fast-travel tests continue to pass.

Manual verification will run the project and confirm that the ground and background have no visible seam at the old `x = 2600` boundary.
