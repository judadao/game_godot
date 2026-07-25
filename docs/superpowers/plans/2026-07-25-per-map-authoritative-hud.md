# Per-Map Authoritative HUD Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the HUD edited inside each map layout the HUD used by that map at runtime.

**Architecture:** Each layout keeps an independently overridable instance of the shared HUD scene. `Game` adopts that instance into its global HUD layer during map loading, with the existing exported HUD scene retained only as a compatibility fallback.

**Tech Stack:** Godot 4.7, GDScript, `.tscn` inherited scenes, existing headless test scripts.

## Global Constraints

- Preserve all existing uncommitted user changes.
- Do not duplicate HUD scripts or behavior.
- Formal runtime and editor layout must use the same HUD instance overrides.

---

### Task 1: Add the Runtime Adoption Contract

**Files:**
- Modify: `tests/map_layout_scenes_test.gd`
- Modify: `scripts/managers/game.gd`

**Interfaces:**
- Consumes: `current_map/EditorHUDReference/HUD`
- Produces: `load_hud()`, which adopts the embedded `Control` into `$HUDLayer`

- [ ] **Step 1: Write the failing test**

Instantiate `Game`, load `AutumnForestLayout.tscn`, and assert that `game.hud`
is the layout's original embedded HUD, is parented to `$HUDLayer`, and retains
the Autumn-specific `HUDStatus` offsets.

- [ ] **Step 2: Run the focused test to verify it fails**

Run the existing headless test runner for `tests/map_layout_scenes_test.gd`.
Expected: FAIL because `Game.load_hud()` creates a different shared HUD instance.

- [ ] **Step 3: Implement minimal runtime adoption**

Call `load_hud()` inside `load_current_map()` after the map enters the tree.
In `load_hud()`, reparent an embedded layout HUD when present; otherwise
instantiate `hud_scene`. Remove the duplicate startup `load_hud()` call.

- [ ] **Step 4: Run focused tests**

Run map-layout, portal-flow, map-state-transfer, vertical-slice, and camera-safe-area tests.
Expected: all pass.

- [ ] **Step 5: Run full verification**

Run the full headless suite, editor parse, and a short main-scene execution.
Expected: zero failures and no scanned Godot errors.

- [ ] **Step 6: Commit**

Stage only the design, plan, test, and manager changes. Commit with
`Use map layout HUD at runtime`, then push `main`.
