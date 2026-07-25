# Exploration and Survival Combat Loop Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Build a navigable exploration-to-battle loop where timed survival waves drop experience gems, level-ups strengthen cards, campfires restore resources, merchants sell run supplies, and boss victory unlocks the stage exit.

**Architecture:** Keep `EncounterDirector` as the existing fixed-wave foundation and add `SurvivalWaveDirector` as a focused subclass for the Autumn battle stage. `ExperienceGem` owns pickup behavior, `RunState` owns experience/level queues, and a new `LevelUpUI` owns three-choice presentation. `Game` remains the integration boundary for portal normalization, upgrade application, merchant transactions, and stage completion.

**Tech Stack:** Godot 4.7.1, GDScript, `.tscn` scenes, JSON content, SceneTree headless tests.

## Global Constraints

- All project files and test user data remain under `D:\game\game_godot`.
- Entering Autumn Forest accepts a valid protected-basic deck of 1–16 cards.
- The held hand remains eight cards displayed as two Q/W/E/R groups.
- AP regeneration, Combo stacking/exhaust/evolution, and card-only attacks remain intact.
- Survival phases use 45/45/50/55-second normal phases followed by a boss phase.
- Level-up selection pauses combat and presents exactly three choices.
- Campfires never mutate card levels.
- The stage exit stays disabled until the guardian boss is defeated.

---

### Task 1: Repair the real Town-to-Autumn portal flow

**Files:**
- Modify: `scripts/managers/game.gd`
- Modify: `scripts/systems/meta_state.gd`
- Modify: `scripts/ui/deck_builder_ui.gd`
- Test: `tests/town_autumn_portal_flow_test.gd`
- Test: `tests/vertical_slice_flow_test.gd`

**Interfaces:**
- Produces: `Game._normalize_expedition_deck(deck_ids: Array) -> Array[String]`.
- Produces: `MetaState.normalize_selected_deck(valid_ids: Array[String]) -> Array[String]`.

- [x] **Step 1: Write the failing real-interaction regression test**

Instantiate `game.tscn`, obtain `current_map/Portals/ForestPortal`, move the player
inside its `InteractionArea`, invoke the same candidate and `_try_interact()`
path used by gameplay, confirm `DeckBuilderUI`, and assert:

```gdscript
_expect(game.call("get_open_ui", "DeckBuilderUI") != null, "Forest portal must open deck building.")
deck_builder.emit_signal("deck_confirmed", ["ember_bolt"])
await process_frame
_expect(game.current_map.scene_file_path == "res://scenes/maps/autumn_forest.tscn", "Confirmed deck must enter Autumn Forest.")
_expect(game.run_state.active, "Entering Autumn Forest must start a run.")
```

- [x] **Step 2: Run the portal and vertical-slice tests and confirm the gameplay path fails**

Run both scripts with isolated `APPDATA`. Expected initial failure: the real
interaction path does not complete the transition for migrated/invalid deck
state.

- [x] **Step 3: Implement deterministic deck normalization**

Normalize saved and submitted deck IDs by removing unknown cards, clamping to
16, inserting one `ember_bolt` when missing, and falling back to only
`ember_bolt` when no valid entries remain. Update the builder before rendering
and before confirmation so old profiles cannot produce an inert button.

- [x] **Step 4: Verify portal behavior**

Run `town_autumn_portal_flow_test.gd`, `deck_builder_test.gd`, save migration,
map navigation, and vertical-slice tests. Expected: all pass.

---

### Task 2: Add the timed survival wave director

**Files:**
- Create: `scripts/combat/survival_wave_director.gd`
- Modify: `scenes/maps/autumn_forest.tscn`
- Modify: `scripts/managers/game.gd`
- Create: `tests/survival_wave_director_test.gd`
- Modify: `tests/autumn_run_test.gd`
- Modify: `tests/content_validation_test.gd`

**Interfaces:**
- Consumes: inherited enemy/guardian scenes and encounter signals.
- Produces: `SurvivalWaveDirector.advance_survival(delta: float) -> void`.
- Produces: `SurvivalWaveDirector.get_phase_remaining() -> float`.
- Produces: `SurvivalWaveDirector.is_exit_unlocked() -> bool`.
- Signal: `phase_time_changed(phase: int, remaining: float, alive: int, cap: int)`.
- Signal: `boss_stage_completed`.

- [x] **Step 1: Write director tests for timed replenishment and escalation**

Use short test phases (0.2 seconds) with caps `2`, `4`, and `6`. Assert that
the director replenishes killed enemies during a phase, advances on elapsed
time without requiring an empty arena, increases the alive cap, and spawns the
guardian exactly once in the boss phase.

- [x] **Step 2: Run the director test and confirm RED**

Expected failure: `SurvivalWaveDirector` and its timing interfaces do not exist.

- [x] **Step 3: Implement phase data and spawn budgeting**

Implement the production phases:

```gdscript
[
  {"duration": 45.0, "spawn_interval": 2.4, "alive_cap": 8, "pool": [&"sprout", &"hopper"]},
  {"duration": 45.0, "spawn_interval": 1.8, "alive_cap": 12, "pool": [&"sprout", &"hopper", &"thornling"]},
  {"duration": 50.0, "spawn_interval": 1.35, "alive_cap": 17, "pool": [&"hopper", &"thornling", &"charger"]},
  {"duration": 55.0, "spawn_interval": 1.0, "alive_cap": 22, "pool": [&"sprout", &"thornling", &"charger", &"elite"]},
  {"duration": -1.0, "spawn_interval": 3.0, "alive_cap": 16, "pool": [&"thornling", &"charger"]},
]
```

Spawn around predefined arena markers, never above the current alive cap, and
pause all phase/spawn timers while the tree is paused.

- [x] **Step 4: Wire Autumn Forest and HUD phase updates**

Replace the forest director script with the subclass, keep it in the
`EncounterDirectors` group, and update the objective text with phase time,
alive count, and cap.

- [x] **Step 5: Run encounter regressions**

Run survival, autumn run, boss, leash, combat, content, and vertical-slice tests.

---

### Task 3: Drop and collect physical experience gems

**Files:**
- Create: `scripts/combat/experience_gem.gd`
- Create: `scenes/combat/ExperienceGem.tscn`
- Modify: `scripts/combat/survival_wave_director.gd`
- Create: `tests/experience_gem_test.gd`

**Interfaces:**
- Signal: `ExperienceGem.collected(value: int)`.
- Produces: `ExperienceGem.configure(value: int, target: Node2D) -> void`.
- Signal from director: `experience_gem_spawned(gem: Node, value: int)`.

- [x] **Step 1: Write pickup and one-shot collection tests**

Assert that a gem keeps its exact configured value, accelerates toward a player
inside its attraction radius, emits once on overlap, and cannot grant value a
second time.

- [x] **Step 2: Run the gem test and confirm RED**

Expected failure: the gem scene and script are missing.

- [x] **Step 3: Implement the gem**

Use an `Area2D` with a visible polygon/sprite, attraction radius `180`, pickup
radius `30`, and movement speed increasing from `180` to `520`. Disable
monitoring before emitting `collected`.

- [x] **Step 4: Spawn gems from enemy defeats**

On each non-boss defeat, instantiate a gem at the enemy global position with
the archetype experience reward. Keep gold aggregation unchanged.

- [x] **Step 5: Run gem, enemy, survival, and scene registry tests**

Expected: exact XP values and no double collection.

---

### Task 4: Add queued run levels and three-choice card upgrades

**Files:**
- Modify: `scripts/systems/run_state.gd`
- Create: `scripts/ui/level_up_ui.gd`
- Create: `scenes/ui/LevelUpUI.tscn`
- Modify: `scripts/managers/game.gd`
- Create: `tests/run_experience_test.gd`
- Create: `tests/level_up_ui_test.gd`
- Modify: `tests/run_card_growth_test.gd`

**Interfaces:**
- Produces: `RunState.add_experience(amount: int) -> int`.
- Produces: `RunState.consume_pending_level() -> bool`.
- Produces: `Game._build_level_up_choices() -> Array[Dictionary]`.
- Produces: `Game._apply_level_up_choice(choice: Dictionary) -> bool`.
- Signal: `LevelUpUI.choice_selected(choice: Dictionary)`.

- [x] **Step 1: Write RunState threshold and queued-level tests**

Assert threshold `40`, recurrence `ceil(previous * 1.32 + 12)`, retained excess
experience, and multiple pending levels from one large gain.

- [x] **Step 2: Write LevelUpUI contract tests**

Assert exactly three buttons, immutable choice metadata, no cancel path, and one
selection emission.

- [x] **Step 3: Run both tests and confirm RED**

Expected failure: XP queue and UI do not exist.

- [x] **Step 4: Implement RunState experience authority**

Move run experience display values away from player-only progression. Reset
level, experience, threshold, and pending count at run start/end.

- [x] **Step 5: Implement choice generation and application**

Generate distinct choices from owned cards below level three, discovered cards
when the run deck has fewer than sixteen cards, and active Combo abilities.
Fill shortages with `max_health`, `ap_regen`, or `remove_card` choices. Upgrade
card levels, invoke evolution checks, and refresh the hand.

- [x] **Step 6: Queue modal selections**

Collecting a gem calls `add_experience`. Open one pause-enabled `LevelUpUI` per
pending level; after selection, consume one pending level and open the next
until none remain.

- [x] **Step 7: Run XP, UI, card growth, Combo, HUD, and vertical-slice tests**

Expected: level-up pauses do not advance waves and upgrades occur without a
campfire.

---

### Task 5: Convert campfire to restoration only

**Files:**
- Modify: `scripts/managers/game.gd`
- Modify: `tests/campfire_card_growth_test.gd`
- Create: `tests/campfire_restoration_test.gd`

**Interfaces:**
- Produces: `Game._rest_at_campfire() -> bool`.

- [x] **Step 1: Replace campfire growth tests**

Assert campfire restores current HP and MP to maximum, marks the individual
camp used, and leaves `card_levels`, hand, draw pile, and discard pile exactly
unchanged.

- [x] **Step 2: Run the tests and confirm the old merge/upgrade menu fails**

Expected initial failure: campfire still exposes card mutations.

- [x] **Step 3: Remove merge and upgrade actions from campfire UI**

Render only `Rest` and `Leave`. Keep card merge helpers out of the interaction
path so older saves/tests can be migrated safely without exposing the feature.

- [x] **Step 4: Run campfire, growth, dialogue, and vertical-slice tests**

Expected: restoration passes and no campfire action upgrades a card.

---

### Task 6: Expand the wandering merchant into a run-supply shop

**Files:**
- Modify: `scripts/managers/game.gd`
- Modify: `scenes/maps/autumn_forest.tscn`
- Create: `tests/wandering_merchant_test.gd`

**Interfaces:**
- Produces: `Game._build_wandering_stock() -> Array[Dictionary]`.
- Produces: `Game._purchase_wandering_offer(offer: Dictionary) -> bool`.

- [x] **Step 1: Write transaction tests**

Assert health potion `25`, mana potion `20`, ordinary card `35`, rare/Combo card
`70`, and purge `45`. Verify insufficient run gold changes nothing, healing
cannot exceed maximum, protected basic cannot be removed, and bought cards are
added only to the current run.

- [x] **Step 2: Run the merchant test and confirm RED**

Expected failure: current merchant offers only random add/purge actions.

- [x] **Step 3: Generate persistent per-run stock**

Store generated offers under `run_state.temporary_buffs["wandering_stock"]`.
Always include both potions, choose one discovered ordinary card and one
rare/Combo card, and include purge when a removable card exists.

- [x] **Step 4: Implement immediate-use supplies and card transactions**

Spend `run_state.gold_earned`, apply the offer, update stock/message/hand, and
preserve the removed legacy combat potion hotkeys.

- [x] **Step 5: Run merchant, shop, inventory, save, and vertical-slice tests**

Expected: run-only purchases and no regression to town shops.

---

### Task 7: Lock stage progression behind boss victory

**Files:**
- Modify: `scripts/combat/survival_wave_director.gd`
- Modify: `scripts/interaction/portal.gd`
- Modify: `scripts/managers/game.gd`
- Modify: `scenes/maps/autumn_forest.tscn`
- Create: `tests/boss_stage_gate_test.gd`
- Modify: `tests/boss_mechanics_test.gd`

**Interfaces:**
- Produces: `Portal.set_locked(locked: bool, reason: String) -> void`.
- Consumes: `SurvivalWaveDirector.boss_stage_completed`.

- [x] **Step 1: Write locked-exit tests**

Assert the forward exit rejects interaction before boss death, support spawning
stops when the guardian dies, route progress is saved, rewards are granted,
and the exit accepts interaction afterward.

- [x] **Step 2: Run the gate test and confirm RED**

Expected failure: Autumn Forest has only a return portal and no boss-gated
forward transition.

- [x] **Step 3: Add portal lock state and forward exit**

Add a disabled forward portal to the next exploration destination. Locked
interaction displays its reason; unlocked interaction emits the normal portal
signal.

- [x] **Step 4: Complete the stage on guardian death**

Stop timers/spawns, grant remaining gem value, set permanent route progress,
discover one new card/equipment item when available, unlock the forward exit,
and update HUD/objective.

- [x] **Step 5: Run boss, portal, progression, save, and vertical-slice tests**

Expected: no route advance without boss victory.

---

### Task 8: Full regression and runtime verification

**Files:**
- Modify: `docs/superpowers/plans/2026-07-25-exploration-survival-combat-loop.md`

**Interfaces:** None.

- [x] **Step 1: Run every `tests/*.gd` script**

Use a unique `D:\game\game_godot\.test_userdata\verify_<test>` APPDATA path for
each script. Fail on non-zero exit or any `SCRIPT ERROR`, `Parse Error`, or
`ERROR:` output.

- [x] **Step 2: Parse the project**

Run Godot with `--headless --path . --editor --quit` and scan output.

- [x] **Step 3: Run the main scene for 300 frames**

Run `--headless --path . --quit-after 300` and require zero scanned errors.

- [x] **Step 4: Inspect changes**

Run `git diff --check`, inspect `git status --short`, and ensure no project or
test files were written outside `D:\game\game_godot`.

- [x] **Step 5: Mark the plan complete**

Record exact passing test count, parser result, runtime frame count, and any
remaining gameplay limitation.
