# Town Object Scene Split Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert embedded town visual objects into reusable Godot scene instances.

**Architecture:** Standalone object scenes hold texture and sprite offset. `scenes/maps/town.tscn` keeps layout containers and per-instance positions. Existing interactive scenes remain unchanged.

**Tech Stack:** Godot 4.7.1, `.tscn`, typed GDScript tests.

## Global Constraints

- Do not overwrite the existing town visual composition.
- Do not delete half-finished scenes.
- Do not add external assets.
- Keep all scenes loadable in Godot headless.

---

### Task 1: Add Town Instancing Regression Test

**Files:**
- Create: `tests/town_object_scene_split_test.gd`

**Interfaces:**
- Consumes: `res://scenes/maps/town.tscn`
- Produces: a failing test that detects inline `Sprite2D` children in `Buildings`, `Props`, and visual NPC groups.

- [ ] **Step 1: Write the failing test**

Create `tests/town_object_scene_split_test.gd` with checks for required containers and expected instanced object names.

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --path . --script res://tests/town_object_scene_split_test.gd`
Expected: FAIL because current town still has inline object sprites.

### Task 2: Extract Object Scenes

**Files:**
- Create: `scenes/props/buildings/*.tscn`
- Create: `scenes/props/town/*.tscn`
- Create: `scenes/npc/town/*.tscn`
- Modify: `scenes/maps/town.tscn`

**Interfaces:**
- Consumes: texture resources currently referenced by `scenes/maps/town.tscn`
- Produces: instanced town object scenes with the same visible positions, offsets, and scales.

- [ ] **Step 1: Create building scenes**

Create one `Sprite2D`-root scene for each building sprite: `WestHouse`, `ItemShop`, `Blacksmith`, `MarketStall`, `TownPortal`, `TownWell`, `NoticeBoard`.

- [ ] **Step 2: Create prop scenes**

Create one `Sprite2D`-root scene for each reusable prop sprite: `Fence`, `PotionSign`, `WeaponSign`, `Lamp`, `CrossroadSign`, `Bench`, `BarrelStack`, `Crates`, `MarketCart`, `EastTree`, `FlowerBed`.

- [ ] **Step 3: Create visual NPC scenes**

Create one `Sprite2D`-root scene for each visual NPC sprite: `Mayor`, `VillagerMale`, `VillagerFemale`, `Smith`, `Guard`, `Innkeeper`.

- [ ] **Step 4: Replace inline objects with scene instances**

Update `scenes/maps/town.tscn` so `Buildings`, `Props`, and visual NPC nodes instance the new object scenes and preserve original `position` and `scale`.

### Task 3: Verify and Commit

**Files:**
- Modify: `docs/placeholder-assets.md` if placeholders need extra notes.

**Interfaces:**
- Consumes: all scenes and tests from Tasks 1-2
- Produces: a committed, pushed branch.

- [ ] **Step 1: Run verification**

Run:

```bash
godot --headless --path . --script res://tests/town_object_scene_split_test.gd
godot --headless --path . --script /tmp/check_all_scenes.gd
godot --headless --path . --script /tmp/check_game_integration.gd
godot --headless --path . --editor --quit
git diff --check
```

- [ ] **Step 2: Commit and push**

Commit message: `refactor: split town objects into reusable scenes`
