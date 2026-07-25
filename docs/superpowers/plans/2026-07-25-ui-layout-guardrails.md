# UI Layout Guardrails Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the card hand Scene-authored and add multi-viewport regression
checks that prevent combat UI from covering or escaping its assigned regions.

**Architecture:** Static combat UI nodes live in `.tscn` files and runtime code
only updates state or adds card buttons to a bounded `CardFan`. Per-map scenes
continue to own their HUD/card-hand instances, which Game reparents without
resetting layout overrides.

**Tech Stack:** Godot 4.7, GDScript, `.tscn` scenes, headless `SceneTree` tests.

## Global Constraints

- Preserve all existing gameplay, signals, public methods, and map transitions.
- Preserve current uncommitted Autumn map and interaction-prompt edits.
- Keep `CardHandUI` full-rect and its opaque bottom safe area 184 pixels high.
- Keep four visible Q/W/E/R cards centered and fully visible at rest.
- Do not position static card-hand controls from GDScript.
- Verify 1152×720, 1280×720, 1600×900, 1920×1080, and 2560×1440 viewports.

---

### Task 1: Lock the layout behavior with a failing contract test

**Files:**
- Create: `tests/ui_layout_guardrails_test.gd`

**Interfaces:**
- Consumes: `CardHandUI.set_cards(cards, energy)` and real HUD/card scenes.
- Produces: a headless regression contract for authored nodes and viewport
  containment.

- [x] **Step 1: Add a real-scene test**

Instantiate `CardHandUI.tscn` and `HUD.tscn` in real `SubViewport` nodes. Require
the authored paths `CardSafeArea/BottomMargin/BottomRow/HandSlot/CardFan`,
`LeftControls`, `ComboHint`, `CardGroupBadge`, and `BossStack`.

- [x] **Step 2: Verify RED**

Run:

```powershell
& 'D:\game\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tests/ui_layout_guardrails_test.gd
```

Expected: FAIL because the current scene is an empty root and creates layout
nodes only from `_ready()`.

### Task 2: Author the card-hand layout in the Scene

**Files:**
- Modify: `scenes/ui/CardHandUI.tscn`
- Modify: `scripts/ui/card_hand_ui.gd`

**Interfaces:**
- Consumes: existing card dictionaries and AP/combo/boss updates.
- Produces: the same public CardHandUI API and signals with authored static
  children.

- [x] **Step 1: Add the bottom layout and display nodes to the Scene**

Add the 184-pixel `CardSafeArea`, equal-width `LeftSlot`/`RightSlot`, centered
`HandSlot/CardFan`, group badge, and boss stack. Keep `process_mode = 3` and the
root full-rect settings already saved by the user.

- [x] **Step 2: Bind authored nodes**

Replace `_build_layout()` with `@onready` references. Add card buttons only to
`CardFan`; never recreate AP, combo, group, redraw, safe-area, or boss nodes.

- [x] **Step 3: Bound the fan algorithm**

Use `CardFan.size` to derive overlap and positions. Return root-relative values
from `get_card_layout()` so the existing test/debug API remains stable.

- [x] **Step 4: Verify GREEN**

Run `ui_layout_guardrails_test.gd`, `card_hand_layout_test.gd`,
`card_group_switch_test.gd`, and `card_combat_integration_test.gd`.

### Task 3: Strengthen HUD and map-adoption contracts

**Files:**
- Modify: `tests/ui_layout_guardrails_test.gd`
- Modify: `tests/map_layout_scenes_test.gd`
- Modify: `scenes/dev/EditorHUDReference.tscn`
- Modify: `scenes/maps/README.md`

**Interfaces:**
- Consumes: map-owned `EditorHUDReference` instances and Game adoption methods.
- Produces: tests and editor guidance that reject duplicate UI or lost layout
  overrides.

- [x] **Step 1: Check HUD regions across viewports**

Assert the status remains lower-left, quest/progress remain lower-right, and
each visible rect stays within its viewport without entering the actual card
union.

- [x] **Step 2: Check map override preservation**

Record root offsets before initialization/adoption and assert they remain
unchanged after reparenting into `HUDLayer`.

- [x] **Step 3: Update editor labels and map documentation**

Describe `CardHandUI.tscn` as the authoritative visible layout and
`CardFan` as the only runtime-populated region.

### Task 4: Full verification and delivery

**Files:**
- Verify all changed files and existing user changes without staging unrelated
  files.

**Interfaces:**
- Consumes: the complete project.
- Produces: a verified commit on `main`.

- [x] **Step 1: Run every headless test**

Run every `tests/*_test.gd` with an isolated project-local `APPDATA` directory.
Expected: every script exits zero with no `SCRIPT ERROR`, `Parse Error`, or
unexpected `ERROR:` output.

- [x] **Step 2: Run Scene and main-project smoke checks**

Load the authoritative Town and Autumn scenes in editor/headless mode, run both
with F6-equivalent scene execution, then run the main project.

- [x] **Step 3: Inspect diffs and commit**

Run `git diff --check`, stage only the guardrail implementation and documents,
commit with `Refactor combat UI layout guardrails`, and push `main`.
