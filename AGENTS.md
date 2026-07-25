# Repository Guidelines

## 目錄

- [1. Mandatory Task Workflow](#1-mandatory-task-workflow)
- [2. Project Structure and Module Organization](#2-project-structure--module-organization)
- [3. Build, Test, and Development Commands](#3-build-test-and-development-commands)
- [4. Coding Style and Naming Conventions](#4-coding-style--naming-conventions)
- [5. Testing Guidelines](#5-testing-guidelines)
- [6. Commit and Pull Request Guidelines](#6-commit--pull-request-guidelines)
- [7. Security and Configuration Tips](#7-security--configuration-tips)
- [8. Code Example](#8-code-example)
- [9. Scene Tree Example](#9-scene-tree-example)
- [10. Godot Example](#10-godot-example)
- [11. Checklist](#11-checklist)
- [12. Best Practice](#12-best-practice)
- [13. Anti Pattern](#13-anti-pattern)
- [14. Review Checklist](#14-review-checklist)
- [15. Future Extension](#15-future-extension)
- [16. Related Documents](#16-related-documents)

## 1. Mandatory Task Workflow

This file is the canonical first entry in the governance reading order.
After reading this file, read `CLAUDE.md`, `docs/README.md`,
`docs/01_AI_GUIDE.md`, and `docs/rule_1.md` completely. Then use the task matrix
in `docs/README.md` to read every relevant governance document. Governance
changes must also re-check `docs/rule_2.md`.

Follow the documented preflight, scope-control, UI-layout, verification, and
reporting checklists. Code, scenes, data, tests, and governance documentation
must remain synchronized in the same task.
Start each implementation task by inspecting the relevant scenes, scripts,
resources, signals, callers, and Git changes. Share a concise preflight summary,
then proceed without waiting unless a real blocker or a requirement-changing
choice cannot be resolved from the repository.

Never overwrite, discard, or stage unrelated user changes. UI work requires
behavioral and visual checks at the resolutions listed in `docs/rule_1.md`;
successful parsing alone is not completion.

## 2. Project Structure & Module Organization

This is a Godot project. The root contains `project.godot`, engine import
metadata, and the project icon. Runtime scenes are organized under `scenes/` by
domain: `game/`, `maps/`, `player/`, `npc/`, `ui/`, `monsters/`, and `props/`.
The game entry scene is `scenes/game/game.tscn`. Editable master map scenes live
in map-specific folders, including `scenes/maps/town/TownMap.tscn` and
`scenes/maps/autumn_tree/AutumnTreeMap.tscn`. Scripts follow the same domain
split under `scripts/`, such as `scripts/player/player_controller.gd` and
`scripts/managers/game.gd`.

## 3. Build, Test, and Development Commands

Open the project in Godot from this directory:

```bash
godot --editor --path .
```

`godot` assumes the executable is on `PATH`. In the current Windows workspace,
the verified console executable is documented in `docs/09_TESTING_GUIDE.md`;
use that absolute path when `godot` is unavailable.

Run the project locally:

```bash
godot --path .
```

Export builds through the Godot editor after configuring export presets. If a CLI export preset is added later, document the exact `godot --headless --export-release ...` command here.

## 4. Coding Style & Naming Conventions

The repository uses UTF-8 via `.editorconfig`. Follow Godot conventions: use PascalCase for node and scene names, snake_case for GDScript files, variables, and functions, and UPPER_SNAKE_CASE for constants. Prefer one primary scene per `.tscn` file, and name files after the scene purpose, for example `town.tscn` or `player_controller.gd`. Keep node names descriptive enough to understand in the scene tree.

## 5. Testing Guidelines

Headless `SceneTree` tests live under `tests/`. Most use the `*_test.gd` suffix;
the current exception is `tests/test_ui_keyboard.gd`. Run every affected test
directly:

```bash
godot --headless --path . --script res://tests/<name>_test.gd
```

Then run the affected scene or the main project and exercise the changed flow.
Full regression means all `tests/*_test.gd` plus `tests/test_ui_keyboard.gd`.
For UI changes, also perform the multi-resolution checks required by
`docs/rule_1.md`.

## 6. Commit & Pull Request Guidelines

This repository has established Git history. Use concise imperative commit
messages such as `Refactor combat UI layout guardrails`. Follow
`docs/11_GIT_WORKFLOW.md`: preserve unrelated dirty changes, stage explicit
paths, verify the cached diff, and keep code, tests, and governance docs in
sync. Pull requests should describe gameplay or project settings changed, list
verification steps, and include screenshots or clips for visible changes.

## 7. Security & Configuration Tips

Do not commit local editor caches, credentials, platform signing keys, or exported build artifacts. Keep Godot-generated import files only when they are required for reproducible asset imports.

## 8. Code Example

```gdscript
func register_player(candidate: Node) -> void:
	if candidate == null:
		push_error("Cannot register a null player.")
		return
	player_registered.emit(candidate)
```

## 9. Scene Tree Example

```text
Game
├── MapRoot
├── HUDLayer
├── MenuLayer
└── CardEffectRunner
```

## 10. Godot Example

```gdscript
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_starting_map()
```

## 11. Checklist

- [ ] Read the required governance documents in their defined order.
- [ ] Inspect the authoritative scenes, scripts, data, tests, and Git state.
- [ ] Keep unrelated dirty files unstaged and unchanged.
- [ ] Add a failing regression test before a bug fix or refactor.
- [ ] Update governance documents when their contracts change.

## 12. Best Practice

Prefer one authoritative implementation, explicit ownership, signals across
domains, editor-authored static UI, focused commits, and reproducible
verification evidence.

## 13. Anti Pattern

Do not duplicate map or HUD authorities, silently swallow Godot errors, mutate
unrelated files, rely on runtime reconstruction for static layouts, or claim
success from a parse-only check.

## 14. Review Checklist

- [ ] The change respects dependency and Scene Tree ownership boundaries.
- [ ] New paths, signals, groups, and data fields have contract coverage.
- [ ] Full tests and applicable editor/main smoke checks pass.
- [ ] UI changes have the required multi-resolution evidence.
- [ ] The cached Git diff contains only authorized files.

## 15. Future Extension

- TODO: document a CI command once a repository-owned runner exists.
- TODO: document export commands after export presets are committed.
- TODO: add performance budgets after a repeatable profiling baseline exists.

## 16. Related Documents

- `CLAUDE.md`
- `docs/README.md`
- `docs/01_AI_GUIDE.md`
- `docs/02_PROJECT_ARCHITECTURE.md`
- `docs/09_TESTING_GUIDE.md`
- `docs/11_GIT_WORKFLOW.md`
