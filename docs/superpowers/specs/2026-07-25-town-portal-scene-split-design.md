# Town Portal Scene Split Design

## Goal

Split `TownPortalSet.tscn` so each visible and interactive portal is a real, independently editable scene. Keep `TownPortalSet.tscn` responsible only for arranging portal instances in the town.

## Scene Architecture

Create four focused portal scenes under `scenes/props/town/portals/`:

- `TownFastTravelPortal.tscn`: reusable blue town fast-travel portal. The set scene supplies the target spawn, interaction ID, and prompt for its entrance and east instances.
- `TownForestPortal.tscn`: complete Autumn Forest portal with its atlas visual, collision, interaction configuration, and target map.
- `TownCavesPortal.tscn`: complete Crystal Caves portal with its atlas visual, collision, interaction configuration, and target map.
- `TownGraveyardPortal.tscn`: complete Forbidden Graveyard portal with its atlas visual, collision, interaction configuration, and target map.

`TownPortalSet.tscn` will contain only five PackedScene instances. It will not own portal textures, atlas subresources, detached visual sprites, or editable inherited children.

## Required Node Names and Layout

Keep the existing runtime node paths:

- `Portals/EntranceFastTravelPortal`
- `Portals/ForestPortal`
- `Portals/CavesPortal`
- `Portals/GraveyardPortal`
- `Portals/EastRoadPortal`

Arrange all portal roots on the shared town baseline `y = 618`:

- Entrance fast travel: `x = 100`
- Autumn Forest: `x = 2110`
- Crystal Caves: `x = 2260`
- Forbidden Graveyard: `x = 2410`
- East fast travel: `x = 2550`

The order in the scene tree will match their left-to-right order.

## Behavior and Data Flow

Each portal scene inherits the existing portal interaction behavior. Destination portals own their target scene paths. The two fast-travel instances remain in the same town map and receive opposite spawn marker names from `TownPortalSet.tscn`.

All portals remain non-blocking on the road with `collision_layer = 0`. Their interaction areas remain active. The retired default visual and magic-book visual are hidden inside the focused portal scenes, so only the town atlas visual is rendered.

## Compatibility

No game-manager code or interaction IDs will change. Existing fast-travel and destination map paths remain intact. The Town scene continues to instance `TownPortalSet.tscn` at `Portals`, preserving all paths used by tests and runtime code.

## Verification

- Load every new portal scene through Godot.
- Assert `TownPortalSet.tscn` contains exactly five scene instances and no inline `Sprite2D` portal visuals.
- Assert all five instances use the shared `y = 618` baseline and the specified x ordering.
- Assert both fast-travel portals retain their opposite town spawn targets.
- Assert the three destination portals retain their map paths.
- Assert all portal collision layers remain non-blocking.
- Run Town rebuild, fast-travel, scene-split, scene-registry, and main-scene startup checks.
