# Town and Autumn Tree Vertical Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend the existing Town and Autumn Forest into a repeatable, saveable action-card roguelite loop with persistent Town growth, build progression, an elite, and a three-phase boss.

**Architecture:** Keep `scenes/game/game.tscn` as the composition root and preserve existing Town scene contracts. Add focused run, card, deck, combo, evolution, inventory, save, and town services under `scripts/systems/`; keep content in JSON under `data/`; expose player/enemy behavior through signals and methods; let `game.gd` remain the integration facade while new services own new rules.

**Tech Stack:** Godot 4.7.1, typed GDScript, JSON content data, standalone headless `SceneTree` tests, existing pixel-art assets and procedural Godot UI/effects.

## Global Constraints

- Use only Town and Autumn Forest as primary maps.
- Preserve existing Town composition, portal scenes, and all current passing tests.
- Do not overwrite the existing untracked HUD/navigation asset work.
- New gameplay rules must be data-driven and saved by stable IDs, never scene-node references.
- Keyboard and mouse are required; gamepad actions remain extensible.
- Every behavior change starts with a failing standalone headless test.
- All project tests and `--headless --editor --quit` must pass before completion.

---

### Task 1: Persistent and Run State

**Files:**
- Create: `scripts/systems/run_state.gd`
- Create: `scripts/systems/meta_state.gd`
- Create: `scripts/systems/save_service.gd`
- Create: `tests/progression_state_test.gd`
- Modify: `scripts/managers/game.gd`

**Interfaces:**
- Produces: `RunState.begin_run()`, `RunState.finish_run(victory)`, `MetaState.add_resource(id, amount)`, `SaveService.save_meta(path, data)`, and `SaveService.load_meta(path)`.
- Consumes: player resource/stat dictionaries and stable content IDs.

- [ ] Write a failing test proving death resets run level/cards/combo while preserving permanent resources, upgrades, unlocks, equipment, shortcut state, and settings.
- [ ] Run the test and confirm it fails because the state classes do not exist.
- [ ] Implement default-safe dictionaries, reward transfer, and schema-versioned save/load.
- [ ] Run the progression test and all existing quick-save/UI tests.

### Task 2: Data-Driven Cards, Deck, Combo, and Evolution

**Files:**
- Create: `data/cards.json`
- Create: `data/evolutions.json`
- Create: `scripts/systems/card_database.gd`
- Create: `scripts/systems/deck_manager.gd`
- Create: `scripts/systems/combo_manager.gd`
- Create: `scripts/systems/evolution_manager.gd`
- Create: `tests/card_system_test.gd`

**Interfaces:**
- Produces: `CardDatabase.load_catalog()`, `get_card(id)`, `DeckManager.start(deck_ids)`, `play_from_hand(index)`, `ComboManager.record_card(card)`, and `EvolutionManager.find_available(levels, passives)`.
- Consumes: stable card IDs and JSON definitions.

- [ ] Write failing tests for 18 unique effect-bearing cards, draw/hand/discard reshuffle, energy validation, five visible combo rules, and six valid evolution recipes.
- [ ] Run the test and confirm missing implementations are the failure cause.
- [ ] Implement the minimum deterministic systems and content definitions needed by the tests.
- [ ] Run the card-system test and validate every icon/effect path.

### Task 3: Card Casting and Combat HUD

**Files:**
- Create: `scripts/combat/card_effect_runner.gd`
- Create: `scripts/ui/card_hand_ui.gd`
- Create: `scenes/ui/CardHandUI.tscn`
- Create: `tests/card_combat_integration_test.gd`
- Modify: `scenes/game/game.tscn`
- Modify: `scripts/managers/game.gd`
- Modify: `scenes/ui/HUD.tscn`
- Modify: `scripts/ui/hud.gd`

**Interfaces:**
- Produces: `CardEffectRunner.cast(card, caster, targets)`, card-hand selection signals, energy/hand/combo/evolution HUD setters.
- Consumes: deck/card/combo/evolution services and player/enemy groups.

- [ ] Write a failing integration test proving keyboard/mouse card selection spends energy, moves the card to discard, damages or buffs real nodes, and reports combo state.
- [ ] Run the test and confirm it fails on the absent card combat UI/runner.
- [ ] Implement tactical slowdown while the hand is focused, immediate casts, bounded procedural projectiles/AOE, status effects, and visible combo/evolution banners.
- [ ] Run the integration test and existing HUD keyboard tests.

### Task 4: Autumn Forest Run Encounters and Boss

**Files:**
- Create: `scripts/monsters/enemy_base.gd`
- Create: `scripts/monsters/enemy_archetype.gd`
- Create: `scripts/monsters/autumn_guardian.gd`
- Create: `scripts/combat/encounter_director.gd`
- Create: `scenes/monsters/AutumnGuardian.tscn`
- Create: `scenes/monsters/AutumnEnemy.tscn`
- Create: `tests/autumn_run_test.gd`
- Modify: `scenes/maps/autumn_forest.tscn`

**Interfaces:**
- Produces: common `take_damage`, `defeated`, telegraph, drop, elite, and boss phase signals; encounter completion and run victory signals.
- Consumes: player group, combat card effects, run/meta reward services.

- [ ] Write a failing test for three normal encounters, five distinct archetypes, one two-pattern elite, a rest point, branch reward, shortcut state, and a three-phase boss that drops one autumn core.
- [ ] Run the test and confirm the map/content contract is absent.
- [ ] Implement bounded encounter activation, telegraphed attacks, common damage/drop behavior, guardian phases, victory portal, and procedural feedback.
- [ ] Run the run-contract test, combat test, map test, and scene registry test.

### Task 5: Town Growth, Economy, and Equipment

**Files:**
- Create: `data/equipment.json`
- Create: `data/town_upgrades.json`
- Create: `scripts/systems/inventory_manager.gd`
- Create: `scripts/systems/town_manager.gd`
- Create: `scripts/ui/town_progress_ui.gd`
- Create: `scenes/ui/TownProgressUI.tscn`
- Create: `tests/town_progression_test.gd`
- Modify: `scripts/managers/game.gd`
- Modify: `scenes/maps/components/TownBuildings.tscn`
- Modify: `scenes/maps/components/TownNPCs.tscn`

**Interfaces:**
- Produces: ten fixed equipment definitions across weapon/armor/accessory slots, upgrade/equip APIs, five resource balances, three Town levels, building upgrade requirements, and projections for Town UI.
- Consumes: permanent state and stable item/building IDs.

- [ ] Write failing tests for equipment uniqueness and slot effects, five-resource spending, three Town levels, and visual-stage projections.
- [ ] Run the test and verify failure is due to missing systems/content.
- [ ] Implement fixed equipment, upgrade costs, Mayor/Blacksmith/Mage/Guild/Shop actions, and visible construction/light/sign/NPC stage changes.
- [ ] Run Town progression plus all existing Town, shop, inventory, and interaction tests.

### Task 6: End-to-End Flow, Results, and Input

**Files:**
- Create: `scripts/ui/run_result_ui.gd`
- Create: `scenes/ui/RunResultUI.tscn`
- Create: `tests/vertical_slice_flow_test.gd`
- Modify: `project.godot`
- Modify: `scripts/managers/game.gd`
- Modify: `scripts/player/player_controller.gd`

**Interfaces:**
- Produces: Town → run → death/victory result → Town flow; dash and card inputs; player state transfer between map-owned Player instances.
- Consumes: all prior services and UI projections.

- [ ] Write a failing flow test covering new save, enter forest, encounter, card play, level reward, combo, evolution, elite, boss, return, Town upgrade, save/reload, second run, and death retention.
- [ ] Run it and confirm the first missing observable behavior.
- [ ] Integrate services into Game, preserve player state across portal swaps, add dash/card/gamepad mappings, results, settings, and deterministic test hooks that exercise real services.
- [ ] Run the complete flow test and every standalone test.

### Task 7: Polish and Release Verification

**Files:**
- Create: `tests/content_validation_test.gd`
- Modify: focused combat/UI scripts and scenes from prior tasks only.

**Interfaces:**
- Produces: bounded hit stop, shake setting, damage numbers, flash/particles, card/combo/evolution/boss phase feedback, and one validation entry point.
- Consumes: emitted combat and progression signals.

- [ ] Write a failing validation test for unique IDs, recipe references, equipment references, scene paths, input actions, save migration, and all required content counts.
- [ ] Run it and record each missing contract.
- [ ] Add only the missing feedback and validation behavior, with caps on transient nodes/projectiles.
- [ ] Run all tests, editor parse/import, a timed main-scene smoke test, and `git diff --check`.
- [ ] Review the final diff for accidental changes to user-owned untracked work and document verified controls and limitations.
