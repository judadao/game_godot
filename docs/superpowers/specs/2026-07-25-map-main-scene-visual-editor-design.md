# Map Main Scene Visual Editor Design

## Goal

Provide one clearly named, complete visual editing entry for Town and Autumn
Tree:

- `res://scenes/maps/town/TownMap.tscn`
- `res://scenes/maps/autumn_tree/AutumnTreeMap.tscn`

Opening either scene must show the composed map, editable layout instances,
editor-only guides, and the real HUD/card-hand preview.

## Architecture

The existing `town.tscn` and `autumn_forest.tscn` remain reusable map-content
bases. Each new main scene inherits its base and adds:

- the shared authoritative HUD and card-hand reference;
- a map-specific `EditorHelpers` scene;
- editable paths for layout-affecting child instances;
- explicit runtime-safe overrides where required.

The game manager resolves canonical portal targets to the new main scenes. At
runtime it adopts the main scene's HUD and card hand into the persistent HUD
layer, preventing duplicate UI. Editor helpers hide themselves outside the
editor and contain no collision or input nodes.

## Editor Helpers

Town helpers show map/camera bounds, spawn points, district labels, and portal
locations. Autumn helpers show map/camera bounds, player/enemy spawn locations,
survival and boss regions, rewards, shortcuts, and transitions. Helpers are
static scene-owned nodes so they remain saved and visible after reopening Godot.

Runtime-spawned wave enemies and experience gems remain runtime content. Their
director and representative spawn/region markers are visible in the main scene.

## Legacy Entrypoints

`TownLayout.tscn` and `AutumnForestLayout.tscn` are superseded by the clearly
named main scenes and removed after all runtime references and tests migrate.
The base scenes remain because they are the reusable content layer, not user
entrypoints.

## Standalone Execution

Both main scenes contain a Player, Camera, world collision, and safe inactive
runtime systems. Running either scene with F6 must remain alive without missing
autoloads, duplicate Player/Camera/HUD instances, or script errors.

## Verification

- Contract tests inspect required content, editable paths, editor helpers,
  runtime UI adoption, and canonical map resolution.
- Each main scene runs headlessly as the current scene.
- Main game, full test suite, and headless editor load complete without scanned
  Godot errors.
