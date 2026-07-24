# Placeholder Assets

The current prototype uses repository-local concept art from `res://concept/town/can_use/`.
These files are suitable for local integration and scene composition only.

No external or copyrighted assets were downloaded for this integration pass.

Shared placeholder directories:

- `res://assets/` remains available for future runtime art.
- `res://resources/` remains available for future shared Godot resources such as themes.
- `res://data/` remains available for future gameplay data.

Current prototype placeholders:

- `res://scenes/player/Player.tscn` uses the curated Legacy Fantasy swordsman sheets for idle, run, jump, and attack animations.
- `res://scenes/maps/town.tscn` keeps the existing town sprites as the visual layer and adds hidden interactive scene instances for the mayor, merchant, blacksmith, innkeeper, chest, and portals.
- `res://scripts/managers/game.gd` uses inline prototype dialogue text, shop stock, and chest feedback data until `res://data/` gameplay tables are added.
