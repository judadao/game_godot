# Town Portal Scene Split Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the inline portal definitions in `TownPortalSet.tscn` with five arranged instances of four focused portal scenes.

**Architecture:** Each focused portal scene owns its inherited portal behavior and town atlas visual. `TownPortalSet.tscn` owns only instance names, fast-travel spawn overrides, and world positions, preserving all runtime node paths.

**Tech Stack:** Godot 4.7.1, `.tscn` PackedScene resources, GDScript headless SceneTree tests.

## Global Constraints

- Preserve `Portals/EntranceFastTravelPortal`, `ForestPortal`, `CavesPortal`, `GraveyardPortal`, and `EastRoadPortal`.
- All portal roots use baseline `y = 618`.
- All portal collision layers remain `0`.
- `TownPortalSet.tscn` contains no inline portal `Sprite2D` visuals or atlas textures.
- Preserve all existing interaction IDs, prompts, spawn targets, and destination map paths.
- Do not stage unrelated dirty or untracked workspace files.

---

### Task 1: Portal Split Contract

**Files:**
- Modify: `tests/town_rebuild_test.gd`
- Modify: `tests/town_fast_travel_test.gd`

**Interfaces:**
- Consumes: `TownPortalSet.tscn` through `scenes/maps/town.tscn`.
- Produces: executable assertions for scene linkage, ordering, positions, targets, and non-blocking collision.

- [ ] **Step 1: Add failing linkage and layout assertions**

Add expected paths:

```gdscript
var portal_scenes := {
	"EntranceFastTravelPortal": "res://scenes/props/town/portals/TownFastTravelPortal.tscn",
	"ForestPortal": "res://scenes/props/town/portals/TownForestPortal.tscn",
	"CavesPortal": "res://scenes/props/town/portals/TownCavesPortal.tscn",
	"GraveyardPortal": "res://scenes/props/town/portals/TownGraveyardPortal.tscn",
	"EastRoadPortal": "res://scenes/props/town/portals/TownFastTravelPortal.tscn",
}
var expected_x := [100.0, 2110.0, 2260.0, 2410.0, 2550.0]
```

For each ordered child, assert `scene_file_path`, `position`, and `collision_layer`. Assert the set contains exactly five children.

- [ ] **Step 2: Run the tests and verify failure**

Run:

```powershell
& 'D:\game\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script tests/town_rebuild_test.gd
```

Expected: FAIL because focused portal scenes do not exist and the current set contains inline visual nodes.

- [ ] **Step 3: Commit the test contract**

```powershell
git add -- tests/town_rebuild_test.gd tests/town_fast_travel_test.gd
git commit -m "Test town portal scene split"
```

### Task 2: Focused Portal Scenes and Arrangement

**Files:**
- Create: `scenes/props/town/portals/TownFastTravelPortal.tscn`
- Create: `scenes/props/town/portals/TownForestPortal.tscn`
- Create: `scenes/props/town/portals/TownCavesPortal.tscn`
- Create: `scenes/props/town/portals/TownGraveyardPortal.tscn`
- Modify: `scenes/props/town/TownPortalSet.tscn`

**Interfaces:**
- Consumes: `scenes/props/Portal.tscn`, `scenes/props/magic_book_portal.tscn`, and `town_props_portals_atlas_v2.png`.
- Produces: four focused PackedScenes and a five-instance `TownPortalSet`.

- [ ] **Step 1: Create the reusable fast-travel scene**

Instance `Portal.tscn`, set `collision_layer = 0` and `show_default_visual = false`, then add one `TownVisual` Sprite2D using atlas region `Rect2(660, 660, 220, 320)`, scale `Vector2(0.42, 0.42)`, and offset `Vector2(0, -160)`.

- [ ] **Step 2: Create the three destination scenes**

Each scene instances `magic_book_portal.tscn`, sets `collision_layer = 0`, hides `PortalGlow`, `BookAnchor`, and `DestinationLabel`, and adds one `TownVisual` with scale `Vector2(0.46, 0.46)` and offset `Vector2(0, -160)`.

Use these exact atlas regions and targets:

```text
Forest: Rect2(870, 660, 220, 320) -> res://scenes/maps/autumn_forest.tscn
Caves: Rect2(1080, 660, 220, 320) -> res://scenes/maps/crystal_caves.tscn
Graveyard: Rect2(1290, 660, 220, 320) -> res://scenes/maps/forbidden_graveyard.tscn
```

- [ ] **Step 3: Replace the portal set contents**

Make `TownPortalSet.tscn` reference only the four focused PackedScenes. Add the five instances in left-to-right order at:

```text
EntranceFastTravelPortal = Vector2(100, 618)
ForestPortal = Vector2(2110, 618)
CavesPortal = Vector2(2260, 618)
GraveyardPortal = Vector2(2410, 618)
EastRoadPortal = Vector2(2550, 618)
```

Set the entrance target to `TownTailArrival` and east target to `TownEntranceArrival`.

- [ ] **Step 4: Run focused and registry verification**

Run:

```powershell
& 'D:\game\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script tests/town_rebuild_test.gd
& 'D:\game\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script tests/town_fast_travel_test.gd
& 'D:\game\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script tests/scene_registry_test.gd
& 'D:\game\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --quit-after 10
```

Expected: all commands exit `0` with no Godot errors.

- [ ] **Step 5: Commit only portal implementation files**

```powershell
git add -- scenes/props/town/portals scenes/props/town/TownPortalSet.tscn tests/town_rebuild_test.gd tests/town_fast_travel_test.gd
git commit -m "Split and arrange town portal scenes"
```
