# Town Object Scene Split Design

## Goal

Split reusable visual objects currently embedded in `scenes/maps/town.tscn` into standalone scenes and re-instance them from the town map without changing the visible composition.

## Scope

This pass covers town visual objects under `Buildings`, `Props`, and non-interactive visual NPC sprites. It keeps `Sky`, `ParallaxBackground`, `Ground`, `WorldCollision`, `PlayerSpawn`, `Player`, and existing interactive scene instances in the town map.

The legacy `scenes/town.tscn` must remain loadable. It may keep its older prototype structure if changing it would risk breaking the main playable scene, but it must not gain new missing resources.

## Architecture

Create small object scenes in:

- `scenes/props/buildings/`
- `scenes/props/town/`
- `scenes/npc/town/`

Each object scene uses a `Sprite2D` root with the object texture and offset baked into the scene. The town map owns placement only: `position`, optional `scale`, and semantic node names. This keeps map layout editable while making art objects reusable.

## Testing

Add a Godot headless test that loads `scenes/maps/town.tscn` and asserts that `Buildings`, `Props`, and visual NPC entries are scene instances, while required map roots still exist. Run the existing all-scene load and game integration checks after implementation.
