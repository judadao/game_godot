# Autumn Battle Map V2 Design

## Goal

Create a new standalone Autumn battle map matching the approved Battle UI 2.0
concept: a readable left-to-right adventure route in the upper 75% world
region, with the shared combat HUD occupying the lower 25%.

## Architecture Decision

The new authority is
`res://scenes/maps/autumn_battle/AutumnBattleMapV2.tscn`. It does not inherit
`autumn_forest.tscn` or `AutumnTreeMap.tscn`. The canonical identity remains
`res://scenes/maps/autumn_forest.tscn`, and `MapRegistry` resolves that identity
to the new V2 scene so portals, saves, and gameplay checks remain compatible.

Rejected alternatives:

- Rebuilding inside inherited `AutumnTreeMap.tscn`: old child overrides and
  editor resaves would continue leaking legacy layout into the new map.
- Procedural runtime generation: harder to edit visually and unnecessary for
  one authored progression map.

## World Layout

The map is 2600×720. The playable world occupies y=0–540; the ground baseline
is approximately y=500, leaving y=540–720 for Battle UI 2.0.

Horizontal route:

1. x=0–420: return portal, cabin, player spawn.
2. x=420–820: event/choice marker and hidden cache.
3. x=820–1650: wide survival-wave arena and limited jump platforms.
4. x=1650–2100: campfire, wandering merchant, shortcut interaction.
5. x=2100–2600: locked forward portal and next-map exit.

The route must remain continuously traversable on the main floor. Decorative
platforms may add vertical play but cannot block the direct route.

## Scene Structure

```text
AutumnBattleMapV2
├── Background                 instance AutumnBattleBackdrop
├── Ground                     instance AutumnBattleTerrain
├── Platforms                  Node2D authored in terrain component
├── SetDressing                instance AutumnBattleSetDressing
├── GameplayZones
│   ├── SpawnZone
│   ├── EventChoiceZone
│   ├── EnemyWaveZone
│   ├── MerchantZone
│   └── ExitZone
├── PlayerSpawn
├── Player
├── AutumnRunDirector
├── HiddenBranchCache
├── ForestRest
├── ShortcutLever
├── WanderingCardMerchant
├── WorldCollision             instance AutumnBattleWorldCollision
├── TownPortal
├── ForwardPortal
├── EditorHUDReference
└── EditorHelpers
```

The root exposes `map_width`, `map_height`, and camera limit metadata. It owns
exactly one Player, one Camera2D, one HUD reference, and one CardHandUI
reference.

## Reused Assets and Gameplay

- Autumn panorama, ground, tree, and props atlases under
  `assets/environments/autumn_town_style/generated/`.
- Existing `Player.tscn`, `AutumnEnemy.tscn`, `AutumnGuardian.tscn`,
  `Merchant.tscn`, `Chest.tscn`, and `Portal.tscn`.
- Existing `SurvivalWaveDirector`; its five-phase and Guardian behavior remain
  unchanged.
- Existing interaction IDs, loot IDs, merchant shop ID, and portal targets.
- Existing `EditorHUDReference.tscn`, `HUD.tscn`, and `CardHandUI.tscn`.

The map does not add a second HUD, director implementation, or global state.
Survival timing continues to start through the existing Game flow; delayed
arena activation is outside this map-generation scope.

## Visual Editing

The V2 authority is the primary Godot editor entry. Visual components and
`EditorHUDReference` are editable children. A V2-specific editor helper shows
map bounds, the y=540 world/HUD boundary, and the five route zones.

The V2 scene must not serialize nested override blocks below
`EditorHUDReference/HUD` or `EditorHUDReference/CardHandUI`. Shared UI layout is
edited only in the master UI scenes. CardHand editor samples contain eight
cards so both rows are visible directly in the map editor.

## Verification

- RED/GREEN tests cover standalone authority, metadata, required nodes, route
  ordering, collision bounds, interactives, registry mapping, and editor UI.
- Existing navigation, Town portal, survival, boss, merchant, campfire, card,
  and HUD tests remain green.
- CombatLayoutPreview loads V2 and displays eight cards.
- A 1280×720 OpenGL capture is visually inspected.
- All tests, editor load, main scene smoke, and `git diff --check` complete
  without errors.
