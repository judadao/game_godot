# Battle UI 2.0 Layout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the approved five-column combat HUD with a proportional 25% bottom band and a container-managed two-row hand.

**Architecture:** `HUD.tscn` and `CardHandUI.tscn` remain separate runtime siblings but use matching five-column `HBoxContainer` grids. `card_hand_ui.gd` creates card buttons directly under scene-authored `BackRow` and `FrontRow` containers and only applies a temporary hover transform.

**Tech Stack:** Godot 4.7.1, GDScript, `.tscn` scenes, headless SceneTree regression tests.

## Global Constraints

- Preserve combat data, signals, input actions, and public UI methods.
- The bottom HUD occupies 20–25% of viewport height.
- Persistent UI layout uses Godot Containers.
- Support 1152×720 through 2560×1440.
- Keep group one slot one as protected `ember_bolt`.

---

### Task 1: Lock the responsive layout contract

**Files:**
- Modify: `tests/ui_layout_guardrails_test.gd`
- Modify: `tests/card_hand_layout_test.gd`
- Modify: `tests/card_group_switch_test.gd`
- Modify: `tests/hud_obstruction_test.gd`

**Interfaces:**
- Consumes: `CardHandUI.set_cards(cards: Array, energy: float)` and `set_active_group(group_index: int)`.
- Produces: regression assertions for `BottomHUD`, `BackRow`, `FrontRow`, and the five HUD columns.

- [x] **Step 1: Write failing assertions**

Assert that the bottom band begins at 75% viewport height, both card rows are
`HBoxContainer` nodes inside a `VBoxContainer`, each row contains four cards,
and status/AP/hand/information/progress columns do not overlap.

- [x] **Step 2: Run tests to verify RED**

```powershell
Godot_v4.7.1-stable_win64_console.exe --headless --path . --script tests/ui_layout_guardrails_test.gd
Godot_v4.7.1-stable_win64_console.exe --headless --path . --script tests/card_hand_layout_test.gd
Godot_v4.7.1-stable_win64_console.exe --headless --path . --script tests/card_group_switch_test.gd
Godot_v4.7.1-stable_win64_console.exe --headless --path . --script tests/hud_obstruction_test.gd
```

Expected: failures report the old fixed-height safe area and missing
`BackRow`/`FrontRow` container structure.

### Task 2: Rebuild the card stage

**Files:**
- Modify: `scenes/ui/CardHandUI.tscn`
- Modify: `scripts/ui/card_hand_ui.gd`

**Interfaces:**
- Consumes: the existing eight-card array and active group index.
- Produces: four buttons under `BackRow`, four under `FrontRow`, with unchanged card selection signals.

- [x] **Step 1: Author the proportional container tree**

Replace the fixed 214-pixel band and free-positioned `CardFan` with a
bottom-anchored `CardSafeArea`, matching five-column `BottomRow`, and
`CardRows/VBoxContainer` containing `BackRow` and `FrontRow`.

- [x] **Step 2: Move runtime buttons into row containers**

Build active-group buttons in `FrontRow` and inactive-group buttons in
`BackRow`. Store the global hand index on every button and preserve Q/W/E/R
labels and selection behavior.

- [x] **Step 3: Limit hover to a temporary transform**

Apply `scale = Vector2(1.08, 1.08)` and a 10-pixel upward position delta only
while the active card is hovered. Restore the exact container-assigned
position and scale afterward.

- [x] **Step 4: Run focused card tests**

Run the Task 1 card and layout tests. Expected: PASS with no error markers.

### Task 3: Align the persistent HUD

**Files:**
- Modify: `scenes/ui/HUD.tscn`
- Modify: `scripts/ui/hud.gd`
- Modify: `scenes/dev/EditorHUDReference.tscn`

**Interfaces:**
- Consumes: existing HUD setter methods.
- Produces: status in column one, objective in column four, and gold/EXP in column five.

- [x] **Step 1: Add matching HUD containers**

Create the proportional bottom grid and reparent `HUDStatus`,
`HUDQuestTracker`, and `HUDProgressPanel` into their matching columns.

- [x] **Step 2: Update stable node references**

Update `hud.gd` paths without changing public methods or data formatting.

- [x] **Step 3: Run HUD and keyboard tests**

```powershell
Godot_v4.7.1-stable_win64_console.exe --headless --path . --script tests/hud_obstruction_test.gd
Godot_v4.7.1-stable_win64_console.exe --headless --path . --script tests/test_ui_keyboard.gd
```

Expected: PASS with no parser or runtime errors.

### Task 4: Verify the Autumn composition

**Files:**
- Modify: `tests/combat_layout_preview_test.gd`
- Modify: `tests/combat_camera_safe_area_test.gd`
- Modify: `docs/04_UI_GUIDE.md`
- Modify: `docs/12_GAME_DESIGN.md`

**Interfaces:**
- Consumes: `CombatLayoutPreview.tscn` with authoritative `AutumnTreeMap`.
- Produces: verified world/HUD boundary and documented Battle UI 2.0 contract.

- [x] **Step 1: Assert the combined five-column composition**

Verify HUD and hand share the same bottom boundary and all visible controls
remain inside it.

- [x] **Step 2: Capture the preview**

```powershell
Godot_v4.7.1-stable_win64_console.exe --path . --scene res://scenes/dev/CombatLayoutPreview.tscn --rendering-method gl_compatibility --resolution 1280x720 --write-movie .test_userdata/battle_ui_2.png --fixed-fps 1 --quit-after 2
```

Inspect the final PNG for map coverage, card readability, and overlap.

- [x] **Step 3: Run full verification**

Run all `tests/*_test.gd`, `tests/test_ui_keyboard.gd`, the editor smoke
check, the main scene for 300 frames, and `git diff --check`. Expected:
zero failures and zero `SCRIPT ERROR`, `Parse Error`, or `ERROR:` markers.
