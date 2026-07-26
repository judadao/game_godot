# Fixed Basic Attack, Dash, and Group Toggle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep Ember Bolt and Quickstep permanently in hand slots Q and W, restrict their growth to equipment with story-gated Dash upgrades, make every group input toggle, and show locked glowing Autumn card frames.

**Architecture:** Replace the single protected-card field with an ordered protected-card collection owned by `DeckManager`, then route every normalization, discard, purge, and growth decision through `is_card_protected()`. Preserve the existing two InputMap actions but make both call one toggle API. Mark protected card projections as fixed so the Autumn card component can own lock and glow presentation.

**Tech Stack:** Godot 4.7.1, GDScript, JSON content data, `.tscn` Control scenes, headless SceneTree tests.

## Global Constraints

- Fixed order is exactly `ember_bolt`, then `quickstep`.
- Fixed cards count toward the 16-card deck maximum.
- Quickstep costs 1 AP, dashes 120 pixels, grants 0.2 seconds of evasion, and draws no cards.
- Fixed cards never use card XP, merge, reward, or evolution growth.
- Dash equipment cannot upgrade or apply Dash bonuses before `dash_upgrade_unlocked`.
- A, S, LT, and RT each toggle to the other available group.
- Town rendering remains unchanged; Autumn owns lock and glow visuals.

---

### Task 1: Ordered protected cards and deck lifecycle

**Files:**
- Create: `tests/fixed_cards_contract_test.gd`
- Modify: `scripts/systems/deck_manager.gd`
- Modify: `data/cards.json`
- Test: `tests/card_system_test.gd`
- Test: `tests/hand_overflow_test.gd`

**Interfaces:**
- Produces: `protected_card_ids: Array[String]`,
  `set_protected_cards(card_ids: Array) -> void`, and
  `is_card_protected(card_id: String) -> bool`.
- Consumes: the existing `start`, `play_from_hand`, `redraw_hand_for_all_energy`,
  `end_turn`, and draw-pile APIs.

- [ ] Write a failing test proving shuffled starts place Ember Bolt and
  Quickstep at indices zero and one, playing either retains its slot, redraw
  and end-turn retain both, and neither enters discard or exhaust.
- [ ] Write a failing content assertion proving Quickstep costs 1 and its effect
  has no `draw_cards`.
- [ ] Run both tests and verify failures are caused by the single protected ID
  and old Quickstep data.
- [ ] Implement the ordered collection and retain all protected cards in order.
- [ ] Update Quickstep data and run focused deck tests until green.

### Task 2: Normalize, reserve, and block fixed-card growth

**Files:**
- Modify: `scripts/systems/meta_state.gd`
- Modify: `scripts/ui/deck_builder_ui.gd`
- Modify: `scripts/ui/card_discard_ui.gd`
- Modify: `scripts/managers/game.gd`
- Modify: `tests/hand_overflow_test.gd`
- Modify: `tests/wandering_merchant_test.gd`
- Modify: `tests/run_card_growth_test.gd`
- Test: `tests/fixed_cards_contract_test.gd`

**Interfaces:**
- Consumes: `DeckManager.is_card_protected(card_id)`.
- Produces: normalization result `[ember_bolt, quickstep, ...]`, a protected-ID
  collection accepted by `CardDiscardUI.configure`, and fixed-card rejection
  across reward, merge, level-up, evolution, and purge flows.

- [ ] Extend the failing contract test with duplicate/missing/16-card migration,
  deck-builder reservation, overflow rejection, merchant purge rejection, and
  card-growth rejection cases.
- [ ] Run and verify each case fails against current behavior.
- [ ] Add one shared fixed-ID constant to the owning systems, normalize exactly
  one copy of each at the front, and cap the result at 16.
- [ ] Update deck builder copy limits and user copy to reserve two fixed cards.
- [ ] Update overflow UI and Game removal/growth paths to query protected
  membership.
- [ ] Keep fixed IDs out of `run_state.card_levels` and level-up choices.
- [ ] Run all affected progression and merchant tests until green.

### Task 3: Story-gated equipment growth

**Files:**
- Modify: `scripts/systems/meta_state.gd`
- Modify: `scripts/systems/inventory_manager.gd`
- Modify: `scripts/managers/game.gd`
- Modify: `data/equipment.json`
- Create: `tests/fixed_card_equipment_growth_test.gd`
- Test: `tests/progression_state_test.gd`
- Test: `tests/town_runtime_ui_test.gd`

**Interfaces:**
- Produces: `MetaState.dash_upgrade_unlocked`,
  `InventoryManager.set_progression_unlocks(unlocks: Dictionary)`, and
  story-aware `upgrade_equipment`.
- Consumes: `dash_distance_bonus`, `dash_evasion_bonus`, and an equipment
  `upgrade_requirement`.

- [ ] Write a failing test proving Swift Ring cannot upgrade or enhance
  Quickstep before story unlock, can do both afterward, and the flag survives
  save/load.
- [ ] Run and verify the failures are caused by missing story state and dormant
  equipment fields.
- [ ] Add the persistent flag, configure inventory progression, and mark Swift
  Ring with its requirement and visible bonuses.
- [ ] Set and save the flag on Heartwood Guardian completion.
- [ ] Apply Dash bonuses only to Quickstep after unlock; keep fixed cards at
  catalog level one.
- [ ] Run equipment, progression, and content validation tests until green.

### Task 4: Toggle inputs and fixed-card presentation

**Files:**
- Modify: `scripts/ui/card_hand_ui.gd`
- Modify: `scripts/ui/autumn_card_hand_ui.gd`
- Modify: `scripts/ui/autumn_battle_card.gd`
- Modify: `scenes/ui/autumn/AutumnBattleCard.tscn`
- Modify: `scenes/ui/autumn/AutumnCardHandUI.tscn`
- Modify: `scripts/dev/combat_layout_preview.gd`
- Modify: `tests/card_group_switch_test.gd`
- Modify: `tests/autumn_card_visual_contract_test.gd`

**Interfaces:**
- Produces: `toggle_active_group() -> void` and
  `AutumnBattleCard.set_fixed(fixed: bool)`.
- Consumes: projected card dictionary field `fixed: bool`.

- [ ] Write failing input tests proving either InputMap action toggles 0→1 and
  1→0 and a one-group hand remains at zero.
- [ ] Write failing Autumn component tests proving the first two card buttons
  show `LockBadge`, report fixed state, and use a stronger persistent glow.
- [ ] Run and verify RED.
- [ ] Route both actions to `toggle_active_group` and update HUD hint copy.
- [ ] Add the lock badge, fixed tooltip, code-native glow, and non-layout pulse.
- [ ] Mark preview cards fixed and run group/UI/multi-resolution tests.

### Task 5: Documentation and complete verification

**Files:**
- Modify: `docs/04_UI_GUIDE.md`
- Modify: `docs/08_COMPONENT_LIBRARY.md`
- Modify: `docs/12_GAME_DESIGN.md`
- Modify: `scenes/maps/README.md`

**Interfaces:**
- Consumes: final fixed-card, equipment, input, and UI behavior.
- Produces: maintainer-facing ownership and migration guidance.

- [ ] Document both fixed IDs, 14 selectable cards, fixed growth exclusions,
  story-gated Dash equipment, toggle semantics, and lock/glow ownership.
- [ ] Capture Autumn battle UI at 1280x720 and 2560x1440 and inspect both
  active groups.
- [ ] Run every `tests/*_test.gd` plus `tests/test_ui_keyboard.gd` in isolated
  user-data directories.
- [ ] Launch the project, Autumn map, combat preview, and headless editor and
  reject parser, missing-node, or runtime errors.
- [ ] Run `git diff --check` and confirm no temporary capture scripts remain.
