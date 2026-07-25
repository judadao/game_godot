# Compact Fanned Card Hand Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the opaque 860-by-204 Play Card panel with a compact, bottom-centered, overlapping and hoverable card hand.

**Architecture:** Keep deck and combat rules in `game.gd`. Refactor only `CardHandUI` so it builds independent compact overlays and positions card controls directly with deterministic fan geometry. Expose read-only layout helpers for UI contract tests.

**Tech Stack:** Godot 4.7.1, GDScript, programmatically generated Control nodes, SceneTree headless tests.

## Global Constraints

- Resting hand visible height must not exceed 125 pixels.
- Full card size is 132 by 168 pixels.
- Hover raises a card by 75 pixels, scales it to 1.08, and gives it highest draw order.
- Keyboard shortcuts 1–5 and `card_selected(index)` remain unchanged.
- Energy, combo, and boss health remain visible without a full-width opaque panel.
- Missing icons must retain a readable text-only card.

---

### Task 1: Lock the unobstructed layout contract

**Files:**
- Create: `tests/card_hand_layout_test.gd`
- Modify: `scripts/ui/card_hand_ui.gd`

**Interfaces:**
- Consumes: `CardHandUI.set_cards(cards: Array, energy: int)`.
- Produces: `get_hand_panel_count() -> int`, `get_resting_visible_height() -> float`, `get_card_layout(index: int) -> Dictionary`, `preview_card_hover(index: int, hovered: bool) -> void`.

- [x] **Step 1: Write the failing layout test**

```gdscript
var ui := (load("res://scenes/ui/CardHandUI.tscn") as PackedScene).instantiate()
root.add_child(ui)
ui.set_cards(cards, 3)
await process_frame
_expect(ui.get_hand_panel_count() == 0, "Hand must not create a large opaque panel.")
_expect(ui.get_resting_visible_height() <= 125.0, "Resting hand must leave the map visible.")
var first := ui.get_card_layout(0)
var second := ui.get_card_layout(1)
_expect(float(second.position.x) - float(first.position.x) < 132.0, "Cards must overlap.")
```

- [x] **Step 2: Run test and confirm RED**

Run:

```powershell
$env:APPDATA='D:\game\game_godot\.test_userdata\card_hand_red'
& 'D:\game\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script tests/card_hand_layout_test.gd
```

Expected: non-zero exit because the layout inspection methods do not exist.

- [x] **Step 3: Add layout constants and read-only helpers**

Add exact constants:

```gdscript
const CARD_SIZE := Vector2(132.0, 168.0)
const RESTING_VISIBLE_HEIGHT := 108.0
const HOVER_RISE := 75.0
const HOVER_SCALE := Vector2(1.08, 1.08)
```

Implement the four inspection interfaces without moving combat state into the UI.

- [x] **Step 4: Run the test**

Expected: layout helper assertions pass after Task 2 supplies card geometry.

---

### Task 2: Build the fanned hand and compact overlays

**Files:**
- Modify: `scripts/ui/card_hand_ui.gd`
- Test: `tests/card_hand_layout_test.gd`
- Test: `tests/card_combat_integration_test.gd`

**Interfaces:**
- Consumes: card dictionaries with `name`, `description`, `type`, `cost`, `level`, and optional `icon_path`.
- Produces: clickable card buttons that retain `select_card(index)`.

- [x] **Step 1: Replace the large margin and panel**

Create a full-rect `_hand_layer: Control`, add energy and combo labels directly to it, and create each card as a `Button` child. Do not create a `PanelContainer` around the whole hand.

- [x] **Step 2: Apply deterministic fan geometry**

For `count` cards:

```gdscript
var spacing := minf(104.0, 520.0 / float(maxi(1, count - 1)))
var center_offset := (float(index) - float(count - 1) * 0.5)
var position := Vector2(
    viewport_width * 0.5 + center_offset * spacing - CARD_SIZE.x * 0.5,
    viewport_height - RESTING_VISIBLE_HEIGHT
)
var rotation := deg_to_rad(center_offset * 2.0)
```

Clamp spacing so hands larger than five cards remain inside the viewport.

- [x] **Step 3: Style individual cards**

Use one `StyleBoxFlat` per normal, hover, pressed, and disabled state. Each card shows number, name, type and level, wrapped description, and energy cost. Preserve optional icons.

- [x] **Step 4: Position compact overlays**

Place energy to the left of the hand, combo to the right, and boss health at the top center. All overlay backgrounds must be tight to their content.

- [x] **Step 5: Re-run card UI tests**

Run `card_hand_layout_test.gd` and `card_combat_integration_test.gd`.

Expected: both exit zero; existing selection behavior remains intact.

---

### Task 3: Add hover focus and complete verification

**Files:**
- Modify: `scripts/ui/card_hand_ui.gd`
- Test: `tests/card_hand_layout_test.gd`

**Interfaces:**
- Consumes: `mouse_entered` and `mouse_exited` from each card.
- Produces: `_set_card_hover(index: int, hovered: bool)` and test wrapper `preview_card_hover`.

- [x] **Step 1: Add failing hover assertions**

```gdscript
var resting := ui.get_card_layout(2)
ui.preview_card_hover(2, true)
var raised := ui.get_card_layout(2)
_expect(float(raised.position.y) <= float(resting.position.y) - 70.0, "Hovered card must rise.")
_expect(int(raised.z_index) > int(resting.z_index), "Hovered card must draw in front.")
```

- [x] **Step 2: Implement hover animation**

On enter, kill the card's existing tween, set `z_index = 100 + index`, and tween position, scale, and rotation to raised focus values over 0.12 seconds. On exit, restore cached resting position, scale, rotation, and `z_index = index`.

- [x] **Step 3: Handle refresh and viewport resizing**

Kill active card tweens before rebuilding. Connect viewport `size_changed` once and call `_layout_cards()` so the fan remains centered after resize.

- [x] **Step 4: Run all automated tests**

Run every `tests/*_test.gd` with isolated `APPDATA` directories.

Expected: all tests exit zero.

- [x] **Step 5: Run runtime and format verification**

Run:

```powershell
$env:APPDATA='D:\game\game_godot\.test_userdata\card_hand_smoke'
& 'D:\game\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --quit-after 300
git diff --check
```

Expected: no script/scene errors and no whitespace errors.
