# Card Skill Growth HUD Redesign Implementation Plan

> **For agentic execution:** Implement each numbered task with strict RED → GREEN tests, a scoped commit, an independent task review, and a final whole-branch review.

**Goal:** Replace shared card levels, defense cards, passive-gated evolutions, the Autumn blessing dialog, the old level-up UI, and the split Autumn HUD with one instance-based deck model, reusable defensive/healing effects, learned attack-sequence skills, a queued growth modal, and one authoritative responsive Autumn combat HUD.

**Architecture:** `Game` remains the composition root and owns focused `RefCounted` systems. Static JSON is validated by catalogs, runtime systems own mutable combat/progression state, and UI scenes project state and emit intent only. The existing Autumn map-authored HUD adoption flow remains authoritative; its adopted instance changes from `AutumnHUD` plus a separate card HUD authority to a single `AutumnCombatHUD` root containing the existing `AutumnCardHandUI`.

**Tech Stack:** Godot 4.7.1, GDScript 2, editor-authored `.tscn` scenes, JSON gameplay catalogs, headless `SceneTree` tests.

## Global Constraints

- Fixed cards are exactly `ember_bolt` and `quickstep`; each keeps a stable unique instance at level 1 and cannot be rewarded, upgraded, fused, purged, exhausted, or put on cooldown.
- Ordinary card instances have `{instance_id, card_id, level}` and preserve identity through draw, hand, discard, exhaust, and cooldown piles.
- Maximum ordinary card level is 3. Fusion consumes two distinct selected level-3 instances from the configured recipe and creates one level-1 result instance.
- There is no player card type named `defense`. Defensive actions are `combo`; recovery actions are `healing`; `quickstep` is `utility`; offensive movement attacks are `attack`; the term `skill` is reserved for passive attack-sequence recipes.
- Cooldowns, status durations, skill windows, enemies, projectiles, waves, and AP regeneration freeze while a growth modal owns a pause token.
- Defensive reduction stacks by source only through refresh/replacement rules and is capped at 60%; super armor is a separate tier; unblockable boss damage bypasses both.
- A skill progress event is emitted once per successfully played attack card only when it deals positive damage. Multi-hit attacks still emit one event. Miss, cancellation, and zero damage emit none.
- Count recipes refresh an 8-second window on each successful attack. Exact recipes reset on any wrong attack or successfully played non-attack; a mismatch equal to step one restarts at step one. Taking damage does not reset either recipe kind.
- Initial learned skill `iron_momentum` costs 1 memory point: five successful attacks in the refreshed 8-second window grant weak super armor for 3 seconds, then the skill has a 10-second cooldown.
- Memory capacity is 10 initially and follows Memory Library levels `10, 14, 18, 24, 30`. Loadouts are editable only in town/safe areas.
- Growth sources are queued and resolve one at a time. Wave blessing exposes New Card only. EXP level exposes Upgrade and Full Fusion, or permanent fallback rewards when neither action is valid.
- EXP fallback choice values are exactly 75 gold; 12 autumn wood plus 8 stone; or 4 magic shards. Autumn Core may replace one option only for explicitly configured boss tiers.
- `AutumnCombatHUD` is the sole Autumn combat HUD authority. It contains `TopLeftStack`, `TopCenterStack`, and `BottomStage`, including the card hand. Town HUD behavior remains unchanged.
- Skill HUD feedback is transient only: maximum three toast rows, 1.5-second fade, and visible duplicate triggers refresh instead of duplicating.
- UI uses containers, full-rect roots, scrolling for variable content, no script-built static layout, and must fit 1152×720, 1280×720, 1600×900, 1920×1080, 2560×1080, and 2560×1440.
- Static JSON → validated runtime model → UI projection is the dependency direction. UI never mutates deck, combat, save, or economy state directly.
- Preserve current map replacement, exact authored HUD adoption, Q/W/E/R card shortcuts, two card groups, redraw behavior, Town HUD, portals, equipment, and run result flow unless a listed requirement explicitly replaces behavior.

## Task 1: Introduce Card Instances and Save Migration

**Files:**
- Create: `scripts/systems/card_instance.gd`
- Modify: `scripts/systems/deck_manager.gd`
- Modify: `scripts/systems/run_state.gd`
- Modify: `scripts/systems/meta_state.gd`
- Modify: `scripts/systems/save_service.gd`
- Create: `tests/card_instance_deck_test.gd`
- Create: `tests/card_instance_save_migration_test.gd`

- [ ] Add failing tests proving duplicate card IDs retain different levels/IDs across every pile, protected instances remain stable, and legacy shared-level payloads migrate deterministically and idempotently.
- [ ] Run both new tests and capture expected RED failures caused by missing `CardInstance` and instance-aware save fields.
- [ ] Implement a validated `CardInstance` value object with deterministic serialization/deserialization and a monotonically allocated instance ID contract.
- [ ] Convert `DeckManager` piles to card-instance dictionaries while retaining compatibility helpers that accept legacy string decks at the public boundary.
- [ ] Add a cooldown pile with remaining seconds; reusable cards leave cooldown for discard only after `tick_cooldowns(delta)`.
- [ ] Make protected-card checks instance-aware and preserve exactly one stable instance per fixed card.
- [ ] Replace run-wide `card_levels` as the active authority with instance arrays while retaining migration reads only.
- [ ] Bump save schema, migrate old `selected_deck` and `permanent_card_levels` deterministically, serialize learned skills/loadout and card instances, and prove a second migration does not change output.
- [ ] Run focused tests GREEN, then all affected existing deck/save/progression tests.
- [ ] Commit only Task 1 files.

## Task 2: Replace Card Taxonomy and Fusion Catalog

**Files:**
- Modify: `data/cards.json`
- Modify: `data/evolutions.json`
- Modify: `scripts/systems/card_database.gd`
- Modify: `scripts/systems/evolution_manager.gd`
- Modify: `scripts/ui/card_hand_ui.gd`
- Modify: `scripts/ui/autumn_battle_card.gd`
- Create: `tests/card_taxonomy_fusion_test.gd`
- Modify: `tests/content_validation_test.gd`

- [ ] Add failing validation tests for absence of `defense`, required healing tags/styles, exact defensive cooldown values, and six two-material fusion recipes.
- [ ] Run focused tests RED against the old catalog.
- [ ] Reclassify Guard → Iron Will, Iron Skin → Stone Form, Fortress Stance → Unbreakable Stance, Stoneguard Pact → Counterguard; encode the approved armor/reduction/retaliation durations, AP, and cooldowns.
- [ ] Reclassify Quickstep as utility, Dash Strike/Gale Lunge as attack, and recovery cards as healing; add Verdant Renewal and normalize Renewal Spirit/Blood Pact recovery semantics.
- [ ] Remove passive evolution fields as runtime requirements and reshape `evolutions.json` to exact two-card level-3 fusion materials/results.
- [ ] Refactor `EvolutionManager.find_available` to accept owned instances and return eligible instance pairs.
- [ ] Add dark emerald/light green healing card styling and update editor sample cards.
- [ ] Run focused tests GREEN and all card catalog/visual tests.
- [ ] Commit only Task 2 files.

## Task 3: Add Combat Status Authority and Status Effects

**Files:**
- Create: `scripts/combat/combat_status_controller.gd`
- Modify: `scripts/combat/card_effect_runner.gd`
- Modify: `scripts/player/player_controller.gd`
- Modify: `scenes/player/Player.tscn`
- Create: `tests/combat_status_controller_test.gd`
- Modify: `tests/card_combat_integration_test.gd`

- [ ] Add failing tests for same-source refresh, strongest armor tier, 60% reduction cap, unblockable bypass, retaliation, regeneration pulses, lifesteal, expiry, and paused ticking.
- [ ] Run focused tests RED before production changes.
- [ ] Implement `CombatStatusController` as the single owner of source-keyed timed armor, reduction, retaliation, regeneration, and lifesteal.
- [ ] Give Player an editor-authored controller child and route incoming damage through it while keeping enemy defense unrelated.
- [ ] Add effect-runner kinds for armor, reduction, retaliation, regeneration, and timed lifesteal; return positive-damage outcome without duplicating skill events for multi-hit cards.
- [ ] Remove ordinary player Block generation from card execution while retaining compatibility methods only where unrelated callers require them.
- [ ] Run focused tests GREEN and affected combat/player tests.
- [ ] Commit only Task 3 files.

## Task 4: Add Learned Attack-Sequence Skills and Memory Library

**Files:**
- Create: `data/skills.json`
- Create: `scripts/systems/skill_recipe_manager.gd`
- Modify: `scripts/systems/town_manager.gd`
- Modify: `data/town_upgrades.json`
- Create: `tests/skill_recipe_manager_test.gd`
- Create: `tests/skill_memory_progression_test.gd`

- [ ] Add failing tests for all count/exact reset rules, parallel recipes, simultaneous triggers, independent cooldowns, hidden discovery, safe-area loadout editing, and capacities `10,14,18,24,30`.
- [ ] Run focused tests RED.
- [ ] Implement strict skills catalog validation and `SkillRecipeManager` with learned set, active loadout, memory costs, count/exact progress, timeouts, cooldowns, and signals for trigger/discovery.
- [ ] Add `iron_momentum` and representative exact/common recipes using attack IDs only; reject non-attack recipe steps.
- [ ] Extend town data/runtime with Memory Library capacity projection and purchase validation without adding UI mutation to the manager.
- [ ] Serialize learned/active skill state through Task 1’s `MetaState` fields.
- [ ] Run focused tests GREEN plus town/content tests.
- [ ] Commit only Task 4 files.

## Task 5: Add Growth Choice Queue and Instance Progression

**Files:**
- Create: `scripts/systems/growth_choice_queue.gd`
- Modify: `scripts/managers/game.gd`
- Modify: `scripts/systems/run_state.gd`
- Modify: `scripts/systems/inventory_manager.gd`
- Create: `tests/growth_choice_queue_test.gd`
- Rewrite: `tests/run_card_growth_test.gd`
- Remove obsolete behavior from: `tests/campfire_card_growth_test.gd`

- [ ] Add failing tests for FIFO source handling, exactly one consumed action, individual instance upgrades, selected pair fusion/net −1, fixed-card rejection, wave new-card-only entries, EXP fallback rewards, immediate persistence request, and invalid close retention.
- [ ] Run focused tests RED.
- [ ] Implement a queue whose entries declare source and allowed pages; keep it independent from UI nodes.
- [ ] Replace old level-up choice generation and blessing dialogue calls with queue entries and instance IDs.
- [ ] Implement new-card, upgrade, fusion, and fallback reward commands through domain systems; remove campfire growth and passive evolution paths while preserving restoration-only campfires.
- [ ] Add permanent fallback resources through the current inventory/meta synchronization boundary and expose a save request signal/callback.
- [ ] Run focused tests GREEN plus run/level/campfire/fixed-card/vertical-slice tests.
- [ ] Commit only Task 5 files.

## Task 6: Build the Unified Card Growth UI and Pause Token

**Files:**
- Create: `scenes/ui/CardGrowthUI.tscn`
- Create: `scripts/ui/card_growth_ui.gd`
- Remove runtime use of: `scenes/ui/LevelUpUI.tscn`
- Remove runtime use of: `scripts/ui/level_up_ui.gd`
- Modify: `scripts/managers/game.gd`
- Create: `tests/card_growth_ui_test.gd`
- Modify: `tests/test_ui_keyboard.gd`

- [ ] Add failing scene tests for centered responsive modal, source title, allowed tab visibility, scroll grid, instance badge, detail comparison, select-then-confirm, empty reasons, focus, controller/keyboard parity, and non-consuming invalid close.
- [ ] Run focused tests RED.
- [ ] Author the entire static modal tree in `.tscn`; runtime code may only populate dynamic card/reward rows.
- [ ] Project the current queue entry into New Card, Upgrade, Fusion, or Reward pages and emit a typed confirmation intent.
- [ ] Integrate one reference-counted modal pause token with `Game`; UI remains always-process and release occurs only when no queued/modal owner remains.
- [ ] Remove the old LevelUpUI and Autumn Blessing dialogue entry from runtime registry and content validation.
- [ ] Run focused tests GREEN at all six required viewport sizes and affected input/modal tests.
- [ ] Commit only Task 6 files.

## Task 7: Build the Authoritative Autumn Combat HUD

**Files:**
- Create: `scenes/ui/autumn/AutumnCombatHUD.tscn`
- Create: `scripts/ui/autumn_combat_hud.gd`
- Modify: `scenes/maps/autumn_battle/AutumnBattleMapV2.tscn`
- Modify: `scripts/ui/autumn_card_hand_ui.gd`
- Modify: `scripts/ui/autumn_battle_card.gd`
- Remove runtime use of: `scenes/ui/autumn/AutumnHUD.tscn`
- Create: `tests/autumn_combat_hud_contract_test.gd`
- Rewrite: `tests/autumn_hud_v3_layout_test.gd`
- Rewrite: `tests/autumn_hud_v3_contract_test.gd`

- [ ] Add failing contract/layout tests for the exact approved node tree, one embedded card hand, status/objective placement, boss/skill-toast stack, vitals/AP/input/resource placement, and no second Autumn HUD authority.
- [ ] Run focused tests RED.
- [ ] Author `TopLeftStack`, `TopCenterStack`, and `BottomStage` with responsive containers and translucent dark panels.
- [ ] Embed the existing two-row `AutumnCardHandUI`; move boss display responsibility from the card-hand scene to the HUD.
- [ ] Add status projection and maximum-three 1.5-second skill toasts whose duplicate visible skill refreshes.
- [ ] Keep compact group/redraw input glyphs and personal gold/EXP resources at bottom right.
- [ ] Replace the exact map-authored HUD reference instance; preserve runtime reparent identity.
- [ ] Run focused tests GREEN at all six required resolutions and editor-placeholder/runtime-empty states.
- [ ] Commit only Task 7 files.

## Task 8: Integrate Combat Events, Skills, Cooldowns, HUD, and Growth

**Files:**
- Modify: `scripts/managers/game.gd`
- Modify: `scenes/game/game.tscn`
- Modify: `scripts/systems/deck_manager.gd`
- Modify: `scripts/combat/card_effect_runner.gd`
- Modify: `scripts/combat/survival_wave_director.gd`
- Create: `tests/card_skill_growth_integration_test.gd`
- Modify: `tests/vertical_slice_flow_test.gd`
- Modify: `tests/ui_layout_guardrails_test.gd`

- [ ] Add a failing integration test covering successful attack → skill trigger → status/toast, combo cooldown/discard return, queued wave/EXP growth pauses, boss HUD ownership, and resumed timing.
- [ ] Run focused test RED.
- [ ] Wire managers and signals in `Game`; project card instances with levels/IDs into the hand and route selections by instance identity.
- [ ] Advance AP/cooldowns/statuses/skill windows only when the modal pause token allows simulation.
- [ ] Emit one attack success after positive resolved damage, feed all active skills, apply triggered effects, and show HUD toast.
- [ ] Route boss health to `AutumnCombatHUD`; route statuses/objectives/resources without changing Town HUD calls.
- [ ] Ensure wave blessing and EXP pending levels enqueue instead of opening competing dialogs; drain sequentially.
- [ ] Delete obsolete game-manager combo/passive-evolution/level-up/HUD duplication once no caller remains.
- [ ] Run focused test GREEN and all affected integration/map/run/input tests.
- [ ] Commit only Task 8 files.

## Task 9: Synchronize Documentation and Complete Verification

**Files:**
- Modify: `docs/02_PROJECT_ARCHITECTURE.md`
- Modify: `docs/03_SCENE_STRUCTURE.md`
- Modify: `docs/04_UI_GUIDE.md`
- Modify: `docs/06_RESOURCE_GUIDE.md`
- Modify: `docs/08_COMPONENT_LIBRARY.md`
- Modify: `docs/09_TESTING_GUIDE.md`
- Modify: `docs/12_GAME_DESIGN.md`
- Modify: `docs/13_ROADMAP.md`
- Modify: `scenes/maps/README.md`

- [ ] Update ownership, schemas, scene tree, pause contract, card/skill/growth rules, test inventory, and verified roadmap truth from the implemented revision.
- [ ] Scan changed files for `TODO|TBD|placeholder|pass #|NotImplemented`.
- [ ] Run every `tests/*_test.gd` plus `tests/test_ui_keyboard.gd` with isolated `APPDATA`; require zero nonzero exits and zero `SCRIPT ERROR|Parse Error|ERROR:` markers.
- [ ] Run `--headless --editor --path . --quit` and main-scene `--headless --path . --quit-after 300`.
- [ ] Capture automated layout evidence at 1152×720, 1280×720, 1600×900, 1920×1080, 2560×1080, and 2560×1440, including empty/long/max-content states.
- [ ] Inspect `git diff`, cached file list, and cached diff; stage only authorized implementation/test/document paths.
- [ ] Request final whole-branch independent review and resolve all Critical/Important findings.
- [ ] Commit documentation/verification changes and report all commit hashes; do not push unless explicitly requested.
