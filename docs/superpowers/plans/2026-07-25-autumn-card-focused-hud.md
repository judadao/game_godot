# Autumn Card-Focused HUD Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Autumn Battle V2's flat text-button cards with a structured, tall, layered two-row card presentation matching the approved concept while preserving all gameplay and input behavior.

**Architecture:** Add an Autumn-only `Button` card component and an Autumn-only subclass of `CardHandUI`. The subclass owns card creation and active/inactive row presentation; the base class continues to own cards, AP, group state, input, selection signals, and redraw behavior. Town continues to use the base renderer.

**Tech Stack:** Godot 4.7.1, GDScript, `.tscn` Control scenes, `StyleBoxFlat`, headless SceneTree tests.

## Global Constraints

- Preserve the upper 75% world-safe area and lower 25% HUD area.
- Preserve Q/W/E/R card activation and A/S plus LT/RT group switching.
- Preserve four cards per group and at most eight visible cards.
- Do not change Town HUD or Town card rendering.
- Use container-authored rows; do not store absolute per-card viewport positions.
- Support 1280x720, 1600x900, 1920x1080, 2560x1440, ultrawide, and tall-window layouts.

---

### Task 1: Lock the Autumn card visual contract

**Files:**
- Create: `tests/autumn_card_visual_contract_test.gd`
- Modify: `tests/autumn_hud_v3_layout_test.gd`

**Interfaces:**
- Consumes: `CardHandUI.set_cards(cards: Array, energy: float)` and `set_active_group(group_index: int)`.
- Produces: observable card structure, active/inactive row states, and safe geometry expectations.

- [ ] **Step 1: Write the failing component contract test**

Instantiate `AutumnCardHandUI.tscn`, provide eight literal card dictionaries,
and assert that each generated root is an `AutumnBattleCard` with
`CardContent/Shortcut`, `CardContent/CardName`, `CardContent/CardType`,
`CardContent/IconStage`, `CardContent/Level`, and
`CardContent/CostRow/CostValue`.

- [ ] **Step 2: Write the failing row-state test**

Assert that group zero cards are interactive, full-bright, and above group one;
group one cards are dim, non-focusable, and ignore mouse input. Switch to group
one and assert that these states reverse without changing global card indices.

- [ ] **Step 3: Write the failing geometry test**

For every required viewport, assert four cards per row, card aspect ratio from
0.68 through 0.78, all active cards within the hand column and the lower 25%,
and no bottom clipping.

- [ ] **Step 4: Run tests and verify RED**

Run:

```powershell
& $godot --headless --path . --script tests/autumn_card_visual_contract_test.gd
& $godot --headless --path . --script tests/autumn_hud_v3_layout_test.gd
```

Expected: FAIL because `AutumnBattleCard`, its structured child zones, and the
Autumn renderer do not exist.

### Task 2: Build the structured Autumn card component

**Files:**
- Create: `scenes/ui/autumn/AutumnBattleCard.tscn`
- Create: `scripts/ui/autumn_battle_card.gd`
- Test: `tests/autumn_card_visual_contract_test.gd`

**Interfaces:**
- Consumes: `configure(card: Dictionary, shortcut: String, affordable: bool)`.
- Produces: `set_row_active(active: bool, affordable: bool)`,
  `set_hovered(hovered: bool)`, and structured child nodes.

- [ ] **Step 1: Create the Button-based card scene**

Author a tall minimum-size root with `CardContent` zones for shortcut, name,
type, icon stage, level, and AP cost. Set every child to
`MOUSE_FILTER_IGNORE`; keep root focus and mouse ownership.

- [ ] **Step 2: Implement card configuration**

Populate all labels, tooltip, optional icon, and type glyph from the card
dictionary. Store affordability separately from row-active state.

- [ ] **Step 3: Implement visual states**

Create type-tinted normal styles, brighter gold hover/focus styles, muted
inactive-row styles, and unaffordable styles. `set_row_active()` must restore
affordability when a locked row becomes active.

- [ ] **Step 4: Run the component contract**

Expected: structured-card assertions PASS; renderer assertions remain RED.

### Task 3: Add the Autumn-only renderer and layered rows

**Files:**
- Create: `scripts/ui/autumn_card_hand_ui.gd`
- Modify: `scenes/ui/autumn/AutumnCardHandUI.tscn`
- Test: `tests/autumn_card_visual_contract_test.gd`
- Test: `tests/autumn_hud_v3_layout_test.gd`

**Interfaces:**
- Consumes: the base `CardHandUI` APIs and `AutumnBattleCard` methods.
- Produces: `_build_card_button`, `_capture_resting_layouts`,
  `_set_card_hover`, and responsive group presentation.

- [ ] **Step 1: Switch the Autumn scene to the subclass**

Set the scene script to `autumn_card_hand_ui.gd`. Give both row containers a
tall minimum height and use negative VBox separation so the inactive header
remains visible behind the complete active row.

- [ ] **Step 2: Override card construction**

Instantiate `AutumnBattleCard.tscn`, configure it with the existing dictionary,
connect the existing selection and hover signals, and retain
`global_card_index` metadata.

- [ ] **Step 3: Override resting row presentation**

Apply full scale, white modulation, focus, mouse handling, and high z-index to
the active group. Apply smaller scale, dark modulation, ignored mouse, no
focus, and low z-index to the inactive group.

- [ ] **Step 4: Preserve AP refresh behavior**

When AP changes, update each Autumn card's affordability without unlocking the
inactive row. Preserve the redraw button contract.

- [ ] **Step 5: Run focused tests and verify GREEN**

Run the Autumn visual, layout, group-switch, keyboard, and hand-overflow tests.
Expected: all PASS with no parser or runtime errors.

### Task 4: Refine supporting Autumn HUD presentation

**Files:**
- Modify: `scenes/ui/autumn/AutumnCardHandUI.tscn`
- Modify: `scenes/ui/autumn/AutumnHUD.tscn`
- Modify: `scenes/dev/AutumnEditorHUDReference.tscn`
- Test: `tests/autumn_hud_v3_layout_test.gd`

**Interfaces:**
- Consumes: the unchanged six-column contract.
- Produces: lower visual weight for AP/group guide and a clear hand focal area.

- [ ] **Step 1: Refine AP and group-guide framing**

Reduce unnecessary internal gaps, keep readable AP/redraw controls, and match
the concept's thin gold frame and dark translucent surfaces.

- [ ] **Step 2: Verify editor reference ownership**

Confirm `AutumnEditorHUDReference` instances the exact new Autumn hand scene
and exposes it in the authoritative Autumn map editor.

- [ ] **Step 3: Run multi-resolution layout tests**

Expected: no overlap, clipping, or world-safe-area intrusion at every required
viewport.

### Task 5: Document and verify the finished HUD

**Files:**
- Modify: `docs/04_UI_GUIDE.md`
- Modify: `docs/08_COMPONENT_LIBRARY.md`
- Modify: `scenes/maps/README.md`

**Interfaces:**
- Consumes: final scene paths and renderer behavior.
- Produces: maintainer guidance for Autumn-only ownership and card states.

- [ ] **Step 1: Document the Autumn card component and renderer**

Record scene paths, public methods, row-state behavior, container ownership,
and the Town isolation rule.

- [ ] **Step 2: Capture the real layout**

Run `CombatLayoutPreview.tscn` at 1280x720 and 2560x1440, capture screenshots,
and inspect card hierarchy, active/inactive contrast, bounds, and readability.

- [ ] **Step 3: Run the complete test suite**

Run every `tests/*_test.gd` plus `tests/test_ui_keyboard.gd` in isolated user
data directories. Expected: zero failures.

- [ ] **Step 4: Run smoke checks**

Launch the main project, `AutumnBattleMapV2.tscn`, and the headless editor.
Expected: exit code zero and no parser, missing-node, or runtime errors.

- [ ] **Step 5: Check the final diff**

Run `git diff --check`, confirm no temporary capture scripts remain, and
confirm only intended Autumn UI, tests, and documentation were added by this
feature.
