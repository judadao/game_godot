# Authoritative Map Layout Scenes

## Goal

Provide one editable scene per map whose node overrides are used by the real game, while preserving the existing map scenes as reusable bases.

## Architecture

Each map gets an inherited scene under `scenes/maps/layouts/`. The inherited scene keeps the base map root and all expected child paths, so gameplay systems continue finding `Player`, `PlayerSpawn`, portals, collisions, and encounter directors.

The layout scene adds a shared editor-only HUD reference layer. This layer is visible while editing but hidden during gameplay because the game continues to own the runtime HUD.

The game resolves canonical map paths such as `res://scenes/maps/town.tscn` to their authoritative layout equivalents before instantiation. Existing portals and saved paths remain compatible.

## Layout Scenes

- `TownLayout.tscn` inherits `town.tscn`.
- `AutumnForestLayout.tscn` inherits `autumn_forest.tscn`.
- `CrystalCavesLayout.tscn` inherits `crystal_caves.tscn`.
- `ForbiddenGraveyardLayout.tscn` inherits `forbidden_graveyard.tscn`.

## Editing Contract

Designers edit the inherited layout scene for map-specific placement. Overrides saved there are loaded by the game. Shared source art or structures may still be changed in the base map scene when the change should affect every inherited use.

The HUD reference layer is visual guidance only. Shared runtime HUD styling remains owned by `HUD.tscn`, while map-specific world placement belongs to the corresponding layout scene.

## Compatibility

- Existing portal target paths remain canonical base-map paths.
- The game translates canonical paths to layout paths at the loading boundary.
- Direct tests that load base maps remain supported.
- Existing uncommitted base-map changes are preserved.

## Verification

- All four layout scenes load and retain required map metadata and node paths.
- The game starts with `TownLayout.tscn`.
- Canonical portal paths resolve to the matching layout scene.
- The editor-only HUD reference is hidden outside the editor.
- The complete Godot test suite, editor parse, and runtime smoke test are executed.
