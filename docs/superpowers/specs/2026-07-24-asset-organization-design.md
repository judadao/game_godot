# Asset Organization Design

## Goal

Extract the seven CraftPix archives from `D:\game\素材` and organize their
contents under the Godot project's `assets/` directory so the assets are easy
to locate while building scenes.

The original ZIP archives remain unchanged in `D:\game\素材`.

## Source Archives

- Free Pixel Art Dungeon Objects Asset Pack
- Free Basic Pixel Art UI for RPG
- Free Crystal Caves 2D Platformer Tileset
- Free Autumn Forest 2D Platformer Tileset
- Free Animated Magic Book Pixel Art Asset Pack
- Free Forbidden Graveyard 2D Platformer Tileset
- Free Basic Pixel Art Fantasy Icons 16x16 for UI

## Target Structure

Assets are grouped first by their role in the game, then by asset pack:

```text
assets/
├── environments/
│   ├── autumn_forest/
│   ├── crystal_caves/
│   └── forbidden_graveyard/
├── props/
│   ├── dungeon_objects/
│   └── magic_book/
├── ui/
│   ├── basic_rpg_ui/
│   └── fantasy_icons_16x16/
└── licenses/
```

Within each asset pack, source directories are retained by format where
available, including PNG, PSD, EPS, AI, ASEPRITE, and Tiled project files.
Directory names at the pack and format levels use lowercase snake_case.
Internal filenames are preserved to avoid breaking references in Tiled and
editable source files.

## Included Content

- Runtime images such as PNG files
- Editable source files such as PSD, EPS, AI, and ASEPRITE files
- Tiled maps and related files
- License files and useful readme or documentation files

Each pack's license and readme are copied into `assets/licenses/<pack_name>/`
so attribution and usage terms remain associated with their source pack.

## Excluded Content

The following non-asset files are not copied into the repository:

- `__MACOSX` directories and macOS metadata such as `.DS_Store`
- CraftPix promotional coupon files
- Advertising images and website shortcut `.url` files
- Godot import metadata generated before the project imports the assets

## Extraction and Collision Handling

Each archive has one predetermined target pack directory. Files are extracted
to a temporary staging directory first, then copied into the target structure.
No file silently overwrites another file. If two files resolve to the same
target path with different contents, both are retained with a descriptive
suffix and the collision is reported.

The extraction process does not modify or delete the original archives.

## Godot Integration Boundary

This task prepares source assets only. It does not create or modify `.tscn`
scenes, TileSet resources, import settings, animations, or gameplay scripts.
Those integrations can be implemented in a later task after the asset contents
and dimensions have been inspected in Godot.

## Verification

After organization:

1. Confirm all seven target pack directories exist.
2. Confirm every supported source format present in each archive was retained.
3. Confirm excluded metadata and promotional files are absent.
4. Confirm every source archive remains in `D:\game\素材`.
5. Run `git status --short` and inspect the resulting asset paths.
6. Open the Godot project and allow it to import the new assets; verify that no
   project load errors are introduced.
