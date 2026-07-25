# Town East Extension Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend Town to 3900 pixels while preserving the existing street layout and replace the composite background with independently placeable sky, cloud, mountain, distant-building, and tree scenes.

**Architecture:** Existing foreground composition remains fixed in `x = 0–2600`; only the east fast-travel endpoint and map bounds move. Background visuals become five focused linked scenes composed by `TownBackdrop.tscn`, with project-local PNG assets generated in a consistent pixel-art style.

**Tech Stack:** Godot 4.7.1 scenes, GDScript headless contract tests, PNG raster assets generated with the built-in image generation workflow.

## Global Constraints

- Existing building, NPC, prop, entrance portal, forest portal, cave portal, and graveyard portal positions must not change.
- Town width and camera right limit must equal 3900.
- `EastRoadPortal` must be at `Vector2(3780, 618)`.
- `TownTailArrival` must be at `Vector2(3650, 576)`.
- Background modules must match the current Town pixel-art style and side-view perspective.
- No scene may contain a nested instance of itself.

---

### Task 1: Lock the extension and modular-background contracts

**Files:**
- Modify: `tests/town_rebuild_test.gd`
- Modify: `tests/town_fast_travel_test.gd`

**Interfaces:**
- Consumes: current Town node paths and current local positions.
- Produces: failing assertions for map width, bounds, preserved positions, portal placement, and linked background scenes.

- [ ] **Step 1: Record the existing building, NPC, prop, and non-east portal positions in test dictionaries.**
- [ ] **Step 2: Assert Town metadata width/right limit are 3900 and `TownTailArrival.position == Vector2(3650, 576)`.**
- [ ] **Step 3: Assert `EastRoadPortal.position == Vector2(3780, 618)` and targets `TownEntranceArrival`.**
- [ ] **Step 4: Assert `TownBackdrop` exposes linked `Sky`, `Clouds`, `Mountains`, `DistantBuildings`, and `Trees` child scenes with minimum sprite counts.**
- [ ] **Step 5: Run `godot --headless --path . --script tests/town_rebuild_test.gd` and confirm the new assertions fail.**

### Task 2: Generate modular Town background PNG assets

**Files:**
- Create: `assets/town/background_modules/town_sky_3900.png`
- Create: `assets/town/background_modules/cloud_01.png` through `cloud_04.png`
- Create: `assets/town/background_modules/mountain_01.png` through `mountain_03.png`
- Create: `assets/town/background_modules/distant_buildings_01.png` through `distant_buildings_04.png`
- Create: `assets/town/background_modules/tree_cluster_01.png` through `tree_cluster_06.png`

**Interfaces:**
- Consumes: current Town background as the style reference.
- Produces: project-local opaque sky and transparent placeable modules.

- [ ] **Step 1: Generate one clean sky foundation with no foreground objects or text.**
- [ ] **Step 2: Generate cloud, mountain, distant-building, and tree-cluster sheets on flat chroma-key backgrounds using separate prompts per asset category.**
- [ ] **Step 3: Remove chroma keys with the installed imagegen helper and split sheets into individually named PNG modules.**
- [ ] **Step 4: Validate alpha channels, transparent corners, subject coverage, and lack of key-color fringe.**

### Task 3: Build focused background child scenes

**Files:**
- Create: `scenes/maps/components/background/TownSkyLayer.tscn`
- Create: `scenes/maps/components/background/TownCloudSet.tscn`
- Create: `scenes/maps/components/background/TownMountainSet.tscn`
- Create: `scenes/maps/components/background/TownDistantBuildings.tscn`
- Create: `scenes/maps/components/background/TownTreeSet.tscn`
- Modify: `scenes/maps/components/TownBackdrop.tscn`

**Interfaces:**
- Consumes: assets from Task 2.
- Produces: five linked scenes composed by `TownBackdrop.tscn`.

- [ ] **Step 1: Create one scene per visual category with descriptive Sprite2D node names and fixed negative z-index bands.**
- [ ] **Step 2: Arrange modules across `x = 0–3900` without visible gaps or repeated adjacent silhouettes.**
- [ ] **Step 3: Replace embedded backdrop sprites with linked instances of the five new scenes.**
- [ ] **Step 4: Confirm `TownBackdrop` contains no duplicate or self-nested scene instance.**

### Task 4: Extend Town geometry and relocate the east endpoint

**Files:**
- Modify: `scenes/maps/town.tscn`
- Modify: `scenes/maps/components/TownStreetGround.tscn`
- Modify: `scenes/maps/components/TownWorldCollision.tscn`
- Modify: `scenes/props/town/TownPortalSet.tscn`

**Interfaces:**
- Consumes: exact positions from the design contract.
- Produces: a continuous 3900-pixel playable Town with reachable east fast travel.

- [ ] **Step 1: Set Town width and camera right metadata to 3900.**
- [ ] **Step 2: Move `TownTailArrival` to `Vector2(3650, 576)` and no other existing layout marker.**
- [ ] **Step 3: Extend the continuous ground sprite region to cover the full width without changing its baseline.**
- [ ] **Step 4: extend floor collision to the full width and move the right wall to `x = 3924`.**
- [ ] **Step 5: Move only `EastRoadPortal` to `Vector2(3780, 618)`.**

### Task 5: Integrate and verify

**Files:**
- Modify: `tests/town_rebuild_test.gd`
- Modify: `tests/town_fast_travel_test.gd`

**Interfaces:**
- Consumes: completed modular scenes and extended geometry.
- Produces: verified runtime behavior and regression coverage.

- [ ] **Step 1: Run Town rebuild, fast-travel, portal split, object split, scene registry, and map navigation tests.**
- [ ] **Step 2: Run the main project headlessly for three frames and confirm zero scene/resource errors.**
- [ ] **Step 3: Inspect the complete staged diff for changed legacy coordinates outside the approved east endpoint.**
- [ ] **Step 4: Commit implementation with an imperative message and push only when requested.**
