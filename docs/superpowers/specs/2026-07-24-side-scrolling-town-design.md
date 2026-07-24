# Side-Scrolling Town Design

## Goal

Build `scenes/maps/town.tscn` into a prototype side-scrolling RPG town using the curated assets under `concept/town/can_use/`.

## Scene Design

The scene root is `Town` (`Node2D`). It contains layered visual groups for sky/parallax, ground, buildings, street props, NPCs, player, camera, and world collision. The town is a single horizontal street roughly 2600 pixels wide, designed for left/right traversal.

## Asset Use

Use the recommended runtime manifest as the source of truth. Preferred background strips are clouds, mountains, forest, and rooftops. Runtime town dressing uses semantic assets for house, item shop, blacksmith, market stall, portal, well, signs, lamps, crates, flowers, and NPCs. Assets remain prototype-only.

## Gameplay Scope

The player is a simple `CharacterBody2D` placeholder with left/right movement and gravity. The town includes a floor collision and invisible left/right blockers. NPCs and buildings are visual only in this pass; their names and node grouping make future interaction areas straightforward to add.

## Verification

Verify by loading the Godot project headlessly and checking that `scenes/maps/town.tscn` parses without errors. Manual visual review in the Godot editor remains required because this pass composes prototype art by hand.
