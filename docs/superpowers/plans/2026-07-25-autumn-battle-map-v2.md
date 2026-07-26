# Autumn Battle Map V2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Generate a standalone authoritative Autumn battle map matching the approved left-to-right Battle UI 2.0 concept.

**Architecture:** A fresh `AutumnBattleMapV2.tscn` composes four editable visual/collision components and keeps gameplay nodes at the root. MapRegistry preserves the old canonical identity while resolving it to the new authority.

**Tech Stack:** Godot 4.7.1, GDScript, `.tscn` scenes, SceneTree regression tests.

## Global Constraints

- Never inherit the old Autumn map scenes.
- Preserve canonical Autumn identity and existing gameplay APIs.
- Keep all world content above y=540 at 1280×720.
- Reuse the shared Battle UI 2.0 and existing gameplay scenes.
- Do not serialize nested HUD/CardHand child overrides in the map.

---

### Task 1: Define the new map contract

**Files:**
- Create: `tests/battle_map_v2_scene_contract_test.gd`
- Create: `tests/battle_map_v2_spatial_flow_test.gd`

- [ ] Write assertions for the standalone root, metadata, required nodes,
  unique Player/Camera/HUD, route ordering, collision bounds, interaction
  IDs, and portal state.
- [ ] Run both tests and verify they fail because V2 does not exist.

### Task 2: Generate editable world components

**Files:**
- Create: `scenes/maps/autumn_battle/components/AutumnBattleBackdrop.tscn`
- Create: `scenes/maps/autumn_battle/components/AutumnBattleTerrain.tscn`
- Create: `scenes/maps/autumn_battle/components/AutumnBattleSetDressing.tscn`
- Create: `scenes/maps/autumn_battle/components/AutumnBattleWorldCollision.tscn`

- [ ] Build the panorama and rear silhouettes.
- [ ] Build continuous ground and arena platforms.
- [ ] Place cabin, event sign, campfire, merchant stall dressing, and portal
  framing along the approved route.
- [ ] Add floor, walls, and matching one-way platform collision.

### Task 3: Generate the standalone authority

**Files:**
- Create: `scenes/maps/autumn_battle/AutumnBattleMapV2.tscn`
- Create: `scenes/maps/autumn_battle/editor/AutumnBattleMapV2EditorHelpers.tscn`

- [ ] Compose the four world components.
- [ ] Add zone markers and gameplay nodes at approved coordinates.
- [ ] Configure director, interactives, merchant, and portals with existing IDs.
- [ ] Instance one EditorHUDReference and one hidden editor helper.
- [ ] Run Task 1 tests and make them pass.

### Task 4: Switch runtime and editor integration

**Files:**
- Modify: `scripts/systems/map_registry.gd`
- Modify: `scenes/dev/CombatLayoutPreview.tscn`
- Modify: `scripts/dev/combat_layout_preview.gd`
- Modify: `scripts/ui/card_hand_ui.gd`
- Modify: map registry/editor/layout/navigation/portal/camera integration tests

- [ ] Point canonical Autumn resolution to V2.
- [ ] Point preview and camera integration to V2.
- [ ] Show eight editor sample cards.
- [ ] Add serialized-override hygiene coverage.
- [ ] Run focused integration tests.

### Task 5: Documentation and complete verification

**Files:**
- Modify: `scenes/maps/README.md`
- Modify: `docs/02_PROJECT_ARCHITECTURE.md`
- Modify: `docs/03_SCENE_STRUCTURE.md`
- Modify: `docs/04_UI_GUIDE.md`
- Modify: `docs/08_COMPONENT_LIBRARY.md`
- Modify: `docs/09_TESTING_GUIDE.md`
- Modify: `docs/12_GAME_DESIGN.md`
- Modify: `docs/13_ROADMAP.md`

- [ ] Document V2 as the sole authoritative Autumn editing entry.
- [ ] Capture the real V2 scene at 1280×720 and inspect it.
- [ ] Run every test, editor smoke, main scene smoke, and `git diff --check`.
