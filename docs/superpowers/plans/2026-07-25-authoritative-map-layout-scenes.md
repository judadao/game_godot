# Authoritative Map Layout Scenes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add one editable, authoritative inherited layout scene for every map and make the real game load those scenes.

**Architecture:** Four layout scenes inherit the existing base maps and add a shared editor-only HUD reference. `game.gd` resolves canonical base-map paths to layout paths at the loading boundary, preserving existing portals and saves.

**Tech Stack:** Godot 4.7.1, GDScript, `.tscn` inherited scenes, headless SceneTree tests.

## Global Constraints

- Preserve the user's uncommitted `scenes/maps/autumn_forest.tscn` changes.
- Do not duplicate map content.
- Runtime HUD remains owned by `Game`.
- Canonical portal target paths remain backward compatible.

---

### Task 1: Layout Scene Contract

**Files:**
- Create: `tests/map_layout_scenes_test.gd`

**Interfaces:**
- Consumes: Canonical map paths and expected root node contracts.
- Produces: A failing executable contract for four authoritative layout scenes.

- [ ] **Step 1: Write the failing test**

Assert that all four `res://scenes/maps/layouts/*Layout.tscn` resources exist, instantiate with their inherited root nodes and metadata, and include `EditorHUDReference`.

- [ ] **Step 2: Run test to verify it fails**

Run the Godot console with `--headless --path . --script res://tests/map_layout_scenes_test.gd`.

- [ ] **Step 3: Keep the test focused on observable scene behavior**

Assert real instantiated nodes and resource paths rather than source text.

### Task 2: Shared Editor HUD Reference

**Files:**
- Create: `scripts/dev/editor_hud_reference.gd`
- Create: `scenes/dev/EditorHUDReference.tscn`

**Interfaces:**
- Produces: `EditorHUDReference`, visible only when `Engine.is_editor_hint()` is true.

- [ ] **Step 1: Implement the editor-only CanvasLayer**

Instance `HUD.tscn`, draw the 1280×720 viewport boundary and bottom card-stage boundary, and hide the layer at runtime.

- [ ] **Step 2: Run the focused test**

Require the layer to exist in every layout scene and remain hidden during headless runtime.

### Task 3: Four Inherited Layout Scenes

**Files:**
- Create: `scenes/maps/layouts/TownLayout.tscn`
- Create: `scenes/maps/layouts/AutumnForestLayout.tscn`
- Create: `scenes/maps/layouts/CrystalCavesLayout.tscn`
- Create: `scenes/maps/layouts/ForbiddenGraveyardLayout.tscn`

**Interfaces:**
- Consumes: Existing base map scenes and `EditorHUDReference.tscn`.
- Produces: Authoritative editable map scenes with unchanged gameplay node paths.

- [ ] **Step 1: Create inherited scenes**

Use each existing map as the root instance and add `EditorHUDReference` as a child.

- [ ] **Step 2: Verify inherited contracts**

Instantiate each scene and assert `PlayerSpawn`, `Player`, metadata, and editor reference nodes.

### Task 4: Runtime Path Resolution

**Files:**
- Modify: `scripts/managers/game.gd`
- Modify: map-flow tests that assert instantiated scene paths.

**Interfaces:**
- Produces: `_resolve_layout_scene_path(path: String) -> String` and canonical comparison helpers.

- [ ] **Step 1: Add failing runtime resolution assertions**

Assert the starting map resource and canonical portal destinations resolve to layout scene paths.

- [ ] **Step 2: Implement path resolution**

Translate the four canonical base paths immediately before loading while retaining canonical comparisons for town and autumn-run behavior.

- [ ] **Step 3: Run focused navigation and flow tests**

Verify town entry, autumn deck flow, boss route progression, and save-compatible canonical paths.

### Task 5: Verification and Delivery

**Files:**
- Modify only tests required by the new authoritative scene-path contract.

**Interfaces:**
- Produces: Verified, committed layout workflow.

- [ ] **Step 1: Run every `tests/*_test.gd` in a fresh isolated APPDATA directory**

- [ ] **Step 2: Run editor parse and both main-game and layout-scene smoke tests**

- [ ] **Step 3: Stage only owned changes**

Exclude unrelated user modifications from the commit.

- [ ] **Step 4: Commit and push**

Use the imperative commit message `Add authoritative map layout scenes`.
