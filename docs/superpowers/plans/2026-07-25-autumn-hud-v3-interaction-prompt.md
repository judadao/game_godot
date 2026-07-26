# Autumn HUD 3.0 and Interaction Prompt Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give Autumn Battle V2 a dedicated six-region bottom HUD, dedicated two-row card layer, and a target-following F interaction prompt that cannot overlap the bottom UI.

**Architecture:** Keep Game's exact-instance HUD adoption and public UI APIs. Add standalone Autumn UI scenes composed by an Autumn editor reference, and extend the existing HUD presentation API with an optional CanvasItem target. Town continues using the shared HUD.

**Tech Stack:** Godot 4.7.1, `.tscn` scenes, GDScript, Container-based Control layout, SceneTree integration tests.

## Global Constraints

- Autumn world remains y=0..75 percent and UI remains y=75..100 percent.
- Bottom HUD uses six proportional columns: 23 / 8 / 40 / 10 / 11 / 8.
- Hand capacity remains eight cards in two groups of four.
- Card slots remain Q/W/E/R; group switching remains A/S and LT/RT.
- Runtime code must not position the six HUD regions.
- Town HUD and canonical map identity must not change.
- No new autoload or singleton.
- Support 1152x720 through 2560x1440.

---

### Task 1: Lock the Autumn UI scene and adoption contracts

**Files:**
- Create: `tests/autumn_hud_v3_contract_test.gd`
- Modify: `tests/battle_map_v2_scene_contract_test.gd`
- Modify: `tests/map_layout_scenes_test.gd`

**Interfaces:**
- Consumes: `Game.load_hud()`, `Game.load_card_hand()`, and `EditorHUDReference/HUD`.
- Produces: failing expectations for the three Autumn scene paths and exact-instance adoption.

- [ ] **Step 1: Write the failing scene contract**

Instantiate Town and Autumn authoritative maps. Assert Town HUD scene path is
`res://scenes/ui/HUD.tscn`, Autumn HUD scene path is
`res://scenes/ui/autumn/AutumnHUD.tscn`, and Autumn card path is
`res://scenes/ui/autumn/AutumnCardHandUI.tscn`. Assert Autumn exposes one HUD,
one card hand, and one `AutumnInteractionPrompt`.

- [ ] **Step 2: Run the contract to verify RED**

Run:

```powershell
& 'D:\game\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script tests/autumn_hud_v3_contract_test.gd
```

Expected: exit 1 because the Autumn-specific scenes do not exist.

- [ ] **Step 3: Keep runtime identity assertions real**

Load Autumn through `Game.load_current_map()`, capture the source HUD/card
instance IDs during node addition, and assert the adopted HUDLayer children
retain those IDs.

### Task 2: Build and test the target-following prompt

**Files:**
- Create: `scripts/ui/autumn_interaction_prompt.gd`
- Create: `scenes/ui/autumn/AutumnInteractionPrompt.tscn`
- Modify: `scripts/ui/hud.gd`
- Modify: `scripts/managers/game.gd`
- Rewrite: `tests/interaction_prompt_display_test.gd`

**Interfaces:**
- Consumes: `CanvasItem.get_global_transform_with_canvas().origin`.
- Produces: `set_target(target: CanvasItem)`, `clear_target()`, and HUD
  `set_interaction_prompt(action_text, key_text, target)`.

- [ ] **Step 1: Write the failing prompt behavior test**

Instantiate Autumn through Game, expose a real merchant interaction, and
assert the visible prompt is centered above the merchant, its rectangle ends
before `viewport_height * 0.75`, and it does not intersect CardSafeArea.
Move the merchant and assert the prompt moves on the next frame. Clear the
interaction and assert it hides.

- [ ] **Step 2: Run the prompt test to verify RED**

Expected: exit 1 because the old prompt remains bottom-anchored and does not
follow the target.

- [ ] **Step 3: Implement the minimal follow/clamp script**

On each process frame, derive the target canvas position, subtract 72 pixels,
and clamp the prompt rectangle to 16-pixel viewport margins and the 75-percent
world boundary. Hide when the WeakRef target is invalid.

- [ ] **Step 4: Pass the target through Game**

Change `_update_interaction_prompt()` to call:

```gdscript
hud.call("set_interaction_prompt", prompt, "F", current_interactive)
```

Keep the third argument optional so shared Town HUD remains compatible.

- [ ] **Step 5: Run prompt and keyboard tests**

Run `interaction_prompt_display_test.gd`, `test_ui_keyboard.gd`, and
`interactive_scene_contract_test.gd`; expect exit 0 with no errors.

### Task 3: Build the Autumn six-region HUD

**Files:**
- Create: `scenes/ui/autumn/AutumnHUD.tscn`
- Create: `scenes/ui/autumn/AutumnCardHandUI.tscn`
- Modify: `scripts/ui/card_hand_ui.gd`
- Create: `tests/autumn_hud_v3_layout_test.gd`

**Interfaces:**
- Consumes: existing `HUD` methods and `CardHandUI` public methods.
- Produces: authored six-column layouts using ratios 23/8/40/10/11/8.

- [ ] **Step 1: Write the multi-resolution failing layout test**

For every supported viewport, instantiate both Autumn UI scenes, populate
eight real card dictionaries, and assert each corresponding column has the
same horizontal boundaries, the safe area starts at 75 percent, all eight
cards remain visible, and HUD/card controls do not intersect.

- [ ] **Step 2: Run the layout test to verify RED**

Expected: exit 1 because the Autumn scenes and six-column structure are
missing.

- [ ] **Step 3: Author `AutumnHUD.tscn`**

Create a standalone HUD scene using the existing HUD script and compatible
status/objective/economy node paths. Add `HintReserve` between HandReserve and
InfoColumn. Use dark opaque panels, warm gold borders, and existing status,
quest, and progress components.

- [ ] **Step 4: Author `AutumnCardHandUI.tscn`**

Keep the script-required AP, Hand, Info, boss, and row node names. Add a
dedicated HintSlot for `CardGroupBadge`; place ComboHint in InfoSlot. Update
card script node lookup to use authored unique names so both shared and
Autumn scenes remain compatible.

- [ ] **Step 5: Verify card behavior**

Run `autumn_hud_v3_layout_test.gd`, `card_hand_layout_test.gd`,
`card_group_switch_test.gd`, `hand_overflow_test.gd`, and
`card_hand_editor_sample_test.gd`; expect exit 0.

### Task 4: Compose Autumn editor and preview scenes

**Files:**
- Create: `scenes/dev/AutumnEditorHUDReference.tscn`
- Modify: `scenes/maps/autumn_battle/AutumnBattleMapV2.tscn`
- Modify: `scenes/dev/CombatLayoutPreview.tscn`
- Modify: `scripts/dev/combat_layout_preview.gd`
- Modify: `tests/combat_layout_preview_test.gd`

**Interfaces:**
- Consumes: Autumn HUD and card scenes from Task 3.
- Produces: direct-map editor visibility and one runtime preview composition.

- [ ] **Step 1: Extend the preview test and verify RED**

Assert preview HUD/card scene paths are the Autumn variants and exactly one
visible prompt/HUD/card root exists.

- [ ] **Step 2: Create the Autumn editor reference**

Reuse the 1280x720 viewport and y=540 stage guides, instance Autumn HUD and
AutumnCardHandUI, and retain the editor-only visibility script.

- [ ] **Step 3: Switch Autumn map and preview**

Replace only Autumn's editor reference. Keep Town on
`EditorHUDReference.tscn`. Point CombatLayoutPreview to the Autumn variants
and continue hiding the embedded map reference.

- [ ] **Step 4: Run editor and preview contracts**

Run `combat_layout_preview_test.gd`, `map_main_scene_editor_test.gd`,
`map_layout_scenes_test.gd`, and `battle_map_v2_scene_contract_test.gd`.

### Task 5: Documentation and final verification

**Files:**
- Modify: `docs/04_UI_GUIDE.md`
- Modify: `docs/08_COMPONENT_LIBRARY.md`
- Modify: `docs/12_GAME_DESIGN.md`
- Modify: `scenes/maps/README.md`

**Interfaces:**
- Consumes: final scene paths and public method signatures.
- Produces: editor instructions and validation evidence.

- [ ] **Step 1: Document Autumn ownership**

Record that Town uses shared HUD scenes while Autumn uses the three Autumn
variants. Document the optional interaction target and the six column ratios.

- [ ] **Step 2: Run the full suite**

Run every `tests/*_test.gd` plus `tests/test_ui_keyboard.gd` with isolated
APPDATA. Expected: every test exits 0.

- [ ] **Step 3: Run smoke tests**

Run the project, Autumn map, and headless editor for five frames. Expected:
exit 0 and no `ERROR:`, `SCRIPT ERROR`, `Parse Error`, `Node not found`, or
`Missing Resource`.

- [ ] **Step 4: Capture and inspect 1280x720 and 2560x1440**

Verify the prompt follows the target, no prompt or HUD control enters the
world/HUD boundary incorrectly, all eight cards are visible, and the six
regions align with the approved concept.

- [ ] **Step 5: Run `git diff --check`**

Expected: exit 0.
