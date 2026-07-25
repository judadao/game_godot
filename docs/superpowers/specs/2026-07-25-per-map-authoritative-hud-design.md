# Per-Map Authoritative HUD Design

## Problem

Each map layout contains `EditorHUDReference/HUD`, but `Game.load_hud()` ignores
that instance and creates a fresh `scenes/ui/HUD.tscn`. Layout overrides therefore
appear in the editor but not in the running game.

## Design

The HUD instance inside each authoritative map layout is also that map's runtime
HUD. All layouts continue to inherit the shared `HUD.tscn`, so scripts and common
structure stay shared, while node-property overrides are saved independently in
each `*Layout.tscn`.

When a map is loaded, `Game` takes `EditorHUDReference/HUD` from the instantiated
layout and reparents it to the global `HUDLayer`. The reference layer and viewport
guides remain editor-only. If a non-layout map has no embedded HUD, `Game` falls
back to the exported `hud_scene` for compatibility.

## Lifecycle

1. Free the previous runtime HUD and map.
2. Instantiate the requested authoritative map layout.
3. Adopt its embedded HUD into `Game/HUDLayer`.
4. Register the player and update the adopted HUD with current state.

This guarantees the editor and runtime use the same node overrides without
duplicating HUD behavior.

## Verification

- A regression test gives the Autumn layout a distinctive HUD offset and verifies
  the running `Game` adopts that exact instance and offset.
- Existing layout, portal-flow, map-state, and full project tests remain green.
- A headless editor parse and short main-scene run report no script errors.
