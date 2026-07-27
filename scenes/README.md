# Scene directory

`scenes/` contains runtime composition only. Open the feature folder that owns
the content instead of searching by filename across the whole project.

## Runtime entry points

| Purpose | Stable path | Editable implementation |
|---|---|---|
| Game | `game/game.tscn` | same path |
| Town identity | `maps/town.tscn` | `maps/town/TownMap.tscn` |
| Autumn identity | `maps/autumn_forest.tscn` | `maps/autumn_battle/AutumnBattleMapV2.tscn` |
| Crystal Caves identity | `maps/crystal_caves.tscn` | `maps/layouts/CrystalCavesLayout.tscn` |
| Graveyard identity | `maps/forbidden_graveyard.tscn` | `maps/layouts/ForbiddenGraveyardLayout.tscn` |
| Battle portal hub | `maps/battle_portal_hub.tscn` | same path |

The stable map paths are public gameplay and save-data identities. Do not move
them as part of folder cleanup. `MapRegistry` resolves a stable identity to its
editable implementation.

## Ownership

```text
scenes/
├── game/                  application composition
├── maps/                  map entries and map-owned components
│   ├── town/
│   │   ├── components/    active Town world composition
│   │   ├── portals/       Town and battle-hub travel
│   │   ├── editor/        Town HUD/editor authoring helpers
│   │   └── legacy/        hidden linked visuals still used by progression
│   └── autumn_battle/     Autumn map, components, and editor helpers
├── combat/                reusable combat runtime scenes
├── monsters/              enemy scenes
├── npc/                   reusable and Town NPC scenes
├── player/                player scene
├── props/                 reusable gameplay interactives
├── ui/                    feature-owned UI
└── dev/                   runnable previews only; never production authority
```

Map-specific visuals belong below their map. A scene belongs in `props/` only
when multiple maps can reuse it. Test-only fixtures belong under `tests/`, not
under `scenes/`.

## Naming

- `*Map.tscn`: editable map implementation.
- `*HUD.tscn`, `*UI.tscn`: feature UI root.
- `components/`: pieces instantiated only by that feature or map.
- `editor/`: authoring helpers that are hidden or adopted at runtime.
- `legacy/`: still-referenced compatibility content, never a place for new work.

Before deleting or moving a scene, check path strings in `project.godot`,
`scripts/`, `scenes/`, `tests/`, and save migration aliases. A zero incoming
`ext_resource` reference alone is not sufficient because portals and saves load
scene paths dynamically.
