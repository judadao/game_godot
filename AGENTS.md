# Repository Guidelines

## Mandatory Task Workflow

Before modifying project files, read `docs/rule_1.md` completely and follow its
preflight, scope-control, UI-layout, verification, and reporting checklists.
Start each implementation task by inspecting the relevant scenes, scripts,
resources, signals, callers, and Git changes. Share a concise preflight summary,
then proceed without waiting unless a real blocker or a requirement-changing
choice cannot be resolved from the repository.

Never overwrite, discard, or stage unrelated user changes. UI work requires
behavioral and visual checks at the resolutions listed in `docs/rule_1.md`;
successful parsing alone is not completion.

## Project Structure & Module Organization

This is a Godot project. The root contains `project.godot`, engine import
metadata, and the project icon. Runtime scenes are organized under `scenes/` by
domain: `game/`, `maps/`, `player/`, `npc/`, `ui/`, `monsters/`, and `props/`.
The game entry scene is `scenes/game/game.tscn`. Editable master map scenes live
in map-specific folders, including `scenes/maps/town/TownMap.tscn` and
`scenes/maps/autumn_tree/AutumnTreeMap.tscn`. Scripts follow the same domain
split under `scripts/`, such as `scripts/player/player_controller.gd` and
`scripts/managers/game.gd`.

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

Headless `SceneTree` tests live under `tests/` and use the `*_test.gd` suffix.
Run every affected test directly:

```bash
godot --headless --path . --script res://tests/<name>_test.gd
```

Then run the affected scene or the main project and exercise the changed flow.
For UI changes, also perform the multi-resolution checks required by
`docs/rule_1.md`.

## Commit & Pull Request Guidelines

No local git history is available in this workspace, so use concise imperative commit messages such as `Add town scene` or `Configure player movement`. Pull requests should describe the gameplay or project setting changed, list manual verification steps, and include screenshots or short clips for visible scene, UI, or asset changes. Link related issues when available.

## Security & Configuration Tips

Do not commit local editor caches, credentials, platform signing keys, or exported build artifacts. Keep Godot-generated import files only when they are required for reproducible asset imports.
