# Campfire AP and Encounter Leash Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Expose more of the resting hand, regenerate AP in real time, move card levels to campfire decisions, and reset encounters after a warned disengagement.

**Architecture:** `DeckManager` owns float AP, `Game` owns real-time ticking and campfire menus, and `EncounterDirector` owns spatial engagement/reset state. `EnemyBase` exposes a narrow reset interface. Existing card effects, reward UI, and dash controls remain intact.

**Tech Stack:** Godot 4.7.1, GDScript, SceneTree headless tests.

## Global Constraints

- Resting cards expose 154 of 168 pixels.
- AP maximum is 5.0 and base regeneration is 0.65 per second; major and ultimate cards cost 3–5 AP.
- Campfire performs one successful rest, merge, or upgrade per run.
- Encounter engagement radius is 650 pixels, leash radius is 760 pixels, and warning duration is five seconds.
- Timeout restores living active enemies to recorded positions and maximum health.
- Held hand size is eight, displayed as two groups of four with Q/W/E/R and X/Y/A/B slot mappings; A/S and LT/RT switch groups.
- Expedition decks contain 1–16 cards and retain one protected basic attack.

---

### Task 1: Visible hand and real-time AP

**Files:**
- Modify: `scripts/ui/card_hand_ui.gd`
- Modify: `scripts/systems/deck_manager.gd`
- Modify: `scripts/systems/run_state.gd`
- Modify: `scripts/managers/game.gd`
- Modify: `data/cards.json`
- Test: `tests/card_hand_layout_test.gd`
- Test: `tests/card_system_test.gd`

**Interfaces:**
- Produces: `DeckManager.regenerate_energy(delta: float, rate: float) -> float`.
- Produces: `CardHandUI.set_action_points(current: float, maximum: float) -> void`.

- [x] Add assertions that resting visible height is `154.0`, AP regenerates fractionally, and AP clamps to maximum.
- [x] Run the two tests and confirm they fail on the old 108-pixel and integer-turn behavior.
- [x] Change deck energy fields to floats, implement clamped regeneration, and remove automatic end-turn calls from `Game`.
- [x] Add `Game._process(delta)` to regenerate `0.65 * delta`, apply a six-second wisp bonus, and refresh only AP display state.
- [x] Rename the compact badge to `AP`, expose 154 pixels, and keep card disabled state synchronized.
- [x] Run card-hand, card-system, card-combat, and vertical-slice tests.

### Task 2: Campfire-only merge and upgrade

**Files:**
- Modify: `scripts/managers/game.gd`
- Modify: `scripts/systems/run_state.gd`
- Test: `tests/run_card_growth_test.gd`
- Create: `tests/campfire_card_growth_test.gd`

**Interfaces:**
- Produces: `_get_card_copy_count(card_id: String) -> int`.
- Produces: `_merge_card_at_campfire(card_id: String) -> bool`.
- Produces: `_upgrade_card_at_campfire(card_id: String) -> bool`.
- Produces: `_open_campfire_menu() -> void`.

- [x] Replace automatic duplicate-level assertions with assertions that rewards add copies at the existing level.
- [x] Add tests that merge consumes one of two copies, upgrade consumes no copy, both raise one level, and a second campfire action fails.
- [x] Run both growth tests and confirm RED.
- [x] Change `_apply_card_reward` to append every reward copy and initialize only unseen IDs to level one.
- [x] Implement campfire candidate menus through the existing `DialogueUI`, mark `campfire_used` only after success, and run evolution checks after level changes.
- [x] Run growth, dialogue, vertical-slice, and content tests.

### Task 3: Two switchable four-card groups

**Files:**
- Modify: `project.godot`
- Modify: `scripts/systems/deck_manager.gd`
- Modify: `scripts/ui/card_hand_ui.gd`
- Test: `tests/card_hand_layout_test.gd`
- Test: `tests/content_validation_test.gd`

**Interfaces:**
- Input actions: `card_slot_1`, `card_slot_2`, `card_slot_3`, `card_slot_4`.
- Input action: `redraw_hand`.
- Produces: `CardHandUI.get_shortcut_label(index: int) -> String`.

- [x] Assert held hand size is eight while only four cards are visible at once, labelled Q/W/E/R.
- [x] Assert slot actions contain Q/W/E/R and joypad X/Y/A/B; add A/S and LT/RT group switching.
- [x] Remove original attack, skill, HP potion, and MP potion actions and their runtime/HUD flow; move dash to right shoulder.
- [x] Change CardHandUI input handling to four visible slots, two groups, and global hand indices.
- [x] Reserve one protected basic attack, add full-AP redraw, and require explicit overflow discards after multi-draw.
- [x] Run input, card-hand, player, card-combat, overflow, and content tests.

### Task 4: Encounter leash, warning, and reset

**Files:**
- Modify: `scripts/combat/encounter_director.gd`
- Modify: `scripts/monsters/enemy_base.gd`
- Modify: `scripts/managers/game.gd`
- Create: `tests/encounter_leash_test.gd`

**Interfaces:**
- `EncounterDirector.update_engagement(player_position: Vector2, delta: float) -> void`.
- `EncounterDirector.get_disengage_remaining() -> float`.
- `EnemyBase.reset_encounter(spawn_position: Vector2) -> void`.
- Signals: `combat_engaged`, `disengage_warning(seconds)`, `disengage_cancelled`, `combat_reset`.

- [x] Add a director test that engages inside 650 pixels, warns outside 760, cancels on return, and times out after five seconds.
- [x] Assert timeout restores enemy local position, maximum health, velocity, and status snapshot.
- [x] Run the test and confirm RED.
- [x] Store spawn positions at wave creation, implement deterministic engagement updates and active-wave reset.
- [x] Wire director signals in `Game`; display and cancel the HUD countdown without changing encounter rewards.
- [x] Run encounter, boss, combat, and vertical-slice tests.

### Task 5: Rare exhaustible Combo cards and ability evolution

**Files:**
- Modify: `data/cards.json`
- Modify: `scripts/ui/card_hand_ui.gd`
- Modify: `scripts/managers/game.gd`
- Modify: `scripts/combat/card_effect_runner.gd`
- Modify: `scripts/monsters/enemy_base.gd`
- Create: `tests/combo_infusion_test.gd`

**Interfaces:**
- `Game._resolve_combo_card(card: Dictionary) -> bool`.
- `Game._apply_combo_infusions_to_card(card: Dictionary) -> Dictionary`.
- `Game._try_evolve_combo_abilities() -> bool`.

- [x] Add five rare Combo cards, including Flame Imbue and Frostburst Imbue, to the ordinary shuffled deck.
- [x] Exhaust played Combo cards so they never return to the current run's draw cycle.
- [x] Allow stacking to level three, cap active ability types at four, and free a slot through compatible max-level evolution.
- [x] Apply attack, defense, burn, frost, stun, lifesteal, and equipment-driven card buffs.
- [x] Add a 1–16 card pre-run deck builder, a wandering card merchant, and permanent card/equipment discovery.
- [x] Run combo, deck-builder, card-combat, card-content, and vertical-slice tests.

### Task 6: Complete regression and runtime verification

**Files:**
- Modify: `docs/superpowers/plans/2026-07-25-campfire-ap-encounter-leash.md`

**Interfaces:** None.

- [x] Run every `tests/*_test.gd` with an isolated D-drive `APPDATA`.
- [x] Run Godot editor parsing with `--headless --editor --quit`.
- [x] Run the main scene for 300 frames and scan for script, parser, and runtime errors.
- [x] Run `git diff --check`.
- [x] Mark every plan step complete and report the exact test count.
