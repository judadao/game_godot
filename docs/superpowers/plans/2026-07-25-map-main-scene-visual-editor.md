# Map Main Scene Visual Editor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create one complete, editable Godot main scene for Town and Autumn Tree.

**Architecture:** Keep existing complete map scenes as reusable bases. Add clearly named inherited main scenes containing authoritative UI and scene-owned editor helpers, then route the game to those scenes and retire ambiguous legacy layout entries.

**Tech Stack:** Godot 4.7, GDScript `@tool`, inherited `.tscn` scenes, headless SceneTree tests.

## Global Constraints

- Preserve uncommitted user work in `autumn_forest.tscn` and HUD interaction UI.
- Layout-affecting objects must be visible in the editor.
- Editor helpers must be scene-owned, runtime-hidden, non-colliding, and non-interactive.
- Main scenes must run standalone and must not duplicate Player, Camera, HUD, or managers.

---

### Task 1: Main Scene Contract

**Files:**
- Create: `tests/map_main_scene_editor_test.gd`

- [ ] Assert the two exact main scene paths exist.
- [ ] Instantiate each and assert complete map content, one Player/Camera, UI preview, editor helpers, and map metadata.
- [ ] Assert Game resolves canonical Town/Autumn paths to the new main scenes.
- [ ] Run and observe failure because the scenes do not exist.

### Task 2: Editor Helpers and Main Scenes

**Files:**
- Create: `scripts/maps/map_editor_helpers.gd`
- Create: `scenes/maps/town/editor/TownEditorHelpers.tscn`
- Create: `scenes/maps/autumn_tree/editor/AutumnTreeEditorHelpers.tscn`
- Create: `scenes/maps/town/TownMap.tscn`
- Create: `scenes/maps/autumn_tree/AutumnTreeMap.tscn`

- [ ] Add runtime-hidden helper roots with scene-owned labels, polygons, lines, and markers.
- [ ] Inherit the complete base maps and instance the real editor HUD/card-hand reference.
- [ ] Add editable paths for buildings, NPCs, props, portals, collisions, rewards, interactions, and UI.
- [ ] Run the contract test and confirm scene-content assertions pass.

### Task 3: Runtime Migration and Documentation

**Files:**
- Modify: `scripts/managers/game.gd`
- Modify: affected flow tests
- Create: `scenes/maps/README.md`
- Delete: `scenes/maps/layouts/TownLayout.tscn`
- Delete: `scenes/maps/layouts/AutumnForestLayout.tscn`

- [ ] Map canonical portal paths to the new main scenes.
- [ ] Update startup and flow contracts without changing portal target paths.
- [ ] Document exact entrypoints, editable children, and F6 usage.
- [ ] Remove the two ambiguous legacy entry scenes.

### Task 4: Verification and Delivery

- [ ] Run focused map, portal, state-transfer, UI, and scene-registry tests.
- [ ] Run every `tests/*_test.gd` in isolated user-data directories.
- [ ] Run both main scenes directly for 300 frames.
- [ ] Open both scenes headlessly in the editor and scan for script/resource errors.
- [ ] Run the main game for 300 frames.
- [ ] Commit implementation-owned files and push `main`.
