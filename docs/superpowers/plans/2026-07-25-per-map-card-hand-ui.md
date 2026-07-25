# Per-Map Card Hand UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an editable card hand to Autumn Map Layout and use it at runtime.

**Architecture:** The shared editor reference contains real HUD and card-hand instances. `Game` reparents both into its HUD layer, reconnecting card signals and refreshing active run data after each map load.

**Tech Stack:** Godot 4.7, GDScript tool scripts, inherited `.tscn` scenes, headless tests.

## Global Constraints

- Preserve existing uncommitted user scene changes.
- Use the layout instance at runtime instead of maintaining a separate preview.
- Do not expose editor sample cards to gameplay.

---

### Task 1: Define the Layout Card-Hand Contract

**Files:**
- Modify: `tests/map_layout_scenes_test.gd`
- Modify: `scenes/dev/EditorHUDReference.tscn`
- Modify: `scenes/maps/layouts/AutumnForestLayout.tscn`

- [ ] Add failing assertions for embedded and runtime-adopted `CardHandUI`.
- [ ] Run the focused test and confirm it fails because layouts lack the card hand.
- [ ] Instance `CardHandUI` in the reference scene and expose its Autumn editable path.

### Task 2: Adopt and Preview the Card Hand

**Files:**
- Modify: `scripts/managers/game.gd`
- Modify: `scenes/game/game.tscn`
- Modify: `scripts/ui/card_hand_ui.gd`

- [ ] Replace the fixed game-scene card hand with a layout-owned instance plus fallback.
- [ ] Reconnect signals and refresh current run data after each adoption.
- [ ] Enable editor execution and populate four stable sample cards only in editor mode.
- [ ] Run focused card, layout, portal, and vertical-slice tests.

### Task 3: Verify and Deliver

- [ ] Run all `tests/*_test.gd` with isolated `APPDATA`.
- [ ] Run a headless editor parse and 300-frame main-scene execution.
- [ ] Stage only implementation-owned hunks, commit, and push `main`.
