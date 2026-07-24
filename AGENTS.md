# Repository Guidelines

## Project Structure & Module Organization

This is a Godot project. The root contains `project.godot`, engine import metadata, and the project icon. Game scenes are currently under `senes/`, including `senes/town.tscn`; keep new gameplay scenes in this area unless the project is reorganized. Place reusable scripts beside the scene that owns them at first, then move shared logic into a dedicated `scripts/` directory when multiple scenes depend on it. Keep imported artwork, audio, and other runtime assets in clearly named folders such as `assets/`, `sprites/`, or `audio/`.

## Build, Test, and Development Commands

Open the project in Godot from this directory:

```bash
godot --editor --path .
```

Run the project locally:

```bash
godot --path .
```

Export builds through the Godot editor after configuring export presets. If a CLI export preset is added later, document the exact `godot --headless --export-release ...` command here.

## Coding Style & Naming Conventions

The repository uses UTF-8 via `.editorconfig`. Follow Godot conventions: use PascalCase for node and scene names, snake_case for GDScript files, variables, and functions, and UPPER_SNAKE_CASE for constants. Prefer one primary scene per `.tscn` file, and name files after the scene purpose, for example `town.tscn` or `player_controller.gd`. Keep node names descriptive enough to understand in the scene tree.

## Testing Guidelines

No automated test framework is configured yet. For now, verify changes by running the project in Godot and exercising the affected scene manually. If tests are added, prefer a Godot-native framework such as GUT, place tests under `tests/`, and name files after the behavior under test, for example `test_player_movement.gd`.

## Commit & Pull Request Guidelines

No local git history is available in this workspace, so use concise imperative commit messages such as `Add town scene` or `Configure player movement`. Pull requests should describe the gameplay or project setting changed, list manual verification steps, and include screenshots or short clips for visible scene, UI, or asset changes. Link related issues when available.

## Security & Configuration Tips

Do not commit local editor caches, credentials, platform signing keys, or exported build artifacts. Keep Godot-generated import files only when they are required for reproducible asset imports.
