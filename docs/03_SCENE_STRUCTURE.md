# Scene Structure

本文件定義目前 Godot Scene 類型、Node Tree、命名、ownership、instance、
editable children、Signal 與 runtime 生命週期規則。所有範例以 repository 內實際
Godot 4 Scene 為依據；不存在的 Scene 類型不視為 current architecture。

## 目錄

1. [目的與適用範圍](#1-目的與適用範圍)
2. [Scene 資料夾與命名](#2-scene-資料夾與命名)
3. [Scene 類型與根節點](#3-scene-類型與根節點)
4. [Game Entry Scene](#4-game-entry-scene)
5. [Authoritative Map Scene](#5-authoritative-map-scene)
6. [Map Component 與 Editor Helper](#6-map-component-與-editor-helper)
7. [Player、Monster 與 Combat Scene](#7-playermonster-與-combat-scene)
8. [Interactive、NPC、Portal 與 Prop Scene](#8-interactivenpcportal-與-prop-scene)
9. [UI Scene](#9-ui-scene)
10. [Instance、Editable Children、Owner 與 Runtime Node](#10-instanceeditable-childrenowner-與-runtime-node)
11. [Signal、Group 與 NodePath Contract](#11-signalgroup-與-nodepath-contract)
12. [Scene Ownership 與生命週期](#12-scene-ownership-與生命週期)
13. [Code Example](#13-code-example)
14. [Scene Tree Examples](#14-scene-tree-examples)
15. [Godot Example (Godot 4)](#15-godot-example-godot-4)
16. [Best Practice](#16-best-practice)
17. [Anti Pattern](#17-anti-pattern)
18. [Scene Authoring Checklist](#18-scene-authoring-checklist)
19. [Review Checklist](#19-review-checklist)
20. [Future Extension](#20-future-extension)
21. [Related Documents](#21-related-documents)

## 1. 目的與適用範圍

### 1.1 目標

- 讓 Scene editor中的結構與runtime ownership一致。
- 讓每種 Scene有清楚root type、固定children與public signal contract。
- 保護authoritative map、HUD adoption、spawn、camera、collision與cleanup。
- 避免同一功能出現第二套Scene或runtime-generated duplicate。
- 讓Node rename、path change與instance override可被tests追蹤。

### 1.2 Authority

Scene的authority依用途分開：

| 類型 | Authority |
|---|---|
| Main application | `res://scenes/game/game.tscn` |
| Playable map | authoritative `*Map.tscn`或`layouts/*Layout.tscn` |
| Canonical map content | `town.tscn`、`autumn_forest.tscn`等base content |
| Shared component | component自己的`.tscn` |
| Runtime dynamic object | spawning director／owner script |
| HUD/Card hand | map中`EditorHUDReference`的exact child instances |

「檔案存在」不代表可任意作runtime entry。地圖必須遵守第5節mapping。

## 2. Scene 資料夾與命名

### 2.1 Current folders

```text
scenes/
├── game/       application entry
├── maps/       playable maps, wrappers, components, editor helpers
├── player/     Player
├── monsters/   enemy and boss
├── combat/     hit/effect/pickup scenes
├── npc/        NPC and Merchant variants
├── props/      interactive and decorative props
├── ui/         HUD, menus, reusable UI components
└── dev/        editor/runtime preview scenes
```

### 2.2 Naming

- Scene/root Node：PascalCase，例如 `Player.tscn` → `Player`。
- Script：snake_case，例如 `player_controller.gd`。
- Node：描述責任，例如 `PlayerSpawn`、`WorldCollision`、`InteractionArea`。
- Map authoritative entry：沿用current naming：
  `TownMap.tscn`、`AutumnBattleMapV2.tscn`、`*Layout.tscn`。
- Editor-only helper：`EditorHUDReference`、`EditorHelpers`，不得取模糊名稱。
- 禁止：`new_scene.tscn`、`temp.tscn`、`test2.tscn`、`final_final.tscn`。

### 2.3 Basename uniqueness

`tests/scene_registry_test.gd`要求所有`scenes/**`的Scene basename
case-insensitive唯一。新增Scene前先：

```powershell
rg --files scenes -g '*.tscn'
```

不要在不同folder建立同名Scene，除非先修改registry contract與所有loader。

## 3. Scene 類型與根節點

| Scene 類型 | Current root | Current example |
|---|---|---|
| Application | `Node` | `scenes/game/game.tscn` |
| World/map | `Node2D`或inherited map root | `scenes/maps/town.tscn` |
| Player/enemy | `CharacterBody2D` | `Player.tscn`, `AutumnEnemy.tscn` |
| Static interactive | `StaticBody2D` | `Merchant.tscn`, `Portal.tscn`, `Chest.tscn` |
| Trigger/pickup/projectile | `Area2D` | `ExperienceGem.tscn` |
| World collision component | `StaticBody2D` | `TownWorldCollision.tscn` |
| Decorative component | `Node2D`或`Sprite2D` | Town background/building/prop scenes |
| Screen UI | `Control` | HUD, Inventory, Dialogue, Shop |
| UI layer/reference | `CanvasLayer` | `EditorHUDReference.tscn` |
| Dev preview | `Node2D` | `CombatLayoutPreview.tscn` |

根節點不得因單一需求任意更換。更換root會影響instance overrides、groups、
physics、layout與tests，必須視為architecture change。

## 4. Game Entry Scene

### 4.1 Authoritative path

`res://scenes/game/game.tscn`

### 4.2 Required tree

```text
Game (Node, scripts/managers/game.gd)
├── MapRoot (Node)
├── HUDLayer (CanvasLayer)
├── MenuLayer (CanvasLayer)
└── CardEffectRunner (Node, scripts/combat/card_effect_runner.gd)
```

### 4.3 Responsibilities

- `MapRoot`：一次一個current map。
- `HUDLayer`：一次一個 adopted HUD；AutumnCardHandUI 是 AutumnHUD 的 child。
- `MenuLayer`：runtime menus/modal UI stack。
- `CardEffectRunner`：解析卡牌effect，不擁有地圖或UI。

禁止將Player、NPC、固定地圖物件直接放入Game entry；它們由map擁有。
禁止把Menu UI預先複製到Game tree；由`Game.open_ui()`管理runtime instance。

## 5. Authoritative Map Scene

### 5.1 兩層path contract

Current map identity：

| Canonical content | Authoritative editor/runtime |
|---|---|
| `res://scenes/maps/town.tscn` | `res://scenes/maps/town/TownMap.tscn` |
| `res://scenes/maps/autumn_safe_zone.tscn` | `res://scenes/maps/autumn_safe/AutumnSafeZoneMap.tscn` |
| `res://scenes/maps/autumn_forest.tscn` | `res://scenes/maps/autumn_battle/AutumnBattleMapV2.tscn` |
| `res://scenes/maps/crystal_caves.tscn` | `res://scenes/maps/layouts/CrystalCavesLayout.tscn` |
| `res://scenes/maps/forbidden_graveyard.tscn` | `res://scenes/maps/layouts/ForbiddenGraveyardLayout.tscn` |

Canonical scene是穩定 compatibility entry；authoritative scene擁有可編輯世界、
per-map editor HUD reference與helper。runtime透過
`Game._resolve_main_scene_path()`使用authoritative path。

### 5.2 Town required contract

`tests/map_main_scene_editor_test.gd`要求
`res://scenes/maps/town/TownMap.tscn`可見：

```text
TownMap
├── ParallaxBackground
├── Buildings
├── Ground
├── Props
├── Portals
├── NPCs
├── BuildingEntrances
├── EternalForgeIdentity
├── WorldCollision
├── PlayerSpawn
├── Player
├── EditorHUDReference
└── EditorHelpers
```

Town canonical scene另有：

- `TownEntranceArrival`
- `TownTailArrival`
- one `Portals/BattleGateway` instance
- camera/map metadata

Town v1 使用單一 `1942 × 720` 的 Eternal Forge 橫向世界。主背景由
`TownBackdrop/EternalForgeConcept` 以 1:1 顯示一次，禁止重複中央火炬或以不同
X/Y scale 拉寬圖中物件；`TownEternalForgeIdentity.tscn` 持有八個
可編輯中文地點標籤、區域光暈與後續可替換的 landmark 向量層。舊
`Buildings`、`Ground`、`Props` linked scenes 保留作為 gameplay／progression
identity，但初版 runtime 不與烘焙背景重複顯示。角色、NPC、Portal 與地面碰撞
統一使用新圖道路的 `y=672` baseline。
Town 的六個建築 UI 觸發由 `BuildingEntrances` 獨立擁有；每個 Area 橫向覆蓋
該建築完整地基，交界處由 Game 選擇距離 Player 最近的 candidate。NPC 僅保留角色
視覺與 body collision，不得加入 `Interactives` 或持有 `InteractionArea`。入口透過
`building_ui_requested` 將 `building_id`、`ui_route` 與 `service_id` 交給 Game。
東側原設計稿研究室改為裝備圖紙商，使用 Shop UI 販售永久 equipment 圖紙；
最東側原劍魂精煉工房改為普通民宅，只開啟無服務的住宅資訊 UI。

`res://scenes/maps/battle_portal_hub.tscn` 是獨立可玩 map。Town 的唯一
`BattleGateway` 先進入此大廳；大廳的 `RegionPortals` 固定有四個入口槽位：
Autumn、Crystal、Graveyard 與鎖定的 Fourth Region。中央 `BossPortalAnchor`
只保留位置，不得提前建立 `BossPortal`；尾王解鎖時再由正式 progression contract
投影。Town return 使用無大型門體的左側互動出口。
該出口的互動區與最左側 Autumn portal 必須保持大於一個 Player body 寬度的
水平淨空，避免玩家同時進入兩個 portal interaction candidates。
Town 入口沿用背景圖內建的大型藍色門作為唯一視覺，因此
`Portals/BattleGateway/TownVisual` 必須保持隱藏，但互動碰撞與傳送行為仍保留；
互動與兩塊地標標籤皆對齊背景貼圖主體的 `x=830` 中心線。火炬標籤使用上方塔身
留白，傳送門標籤使用門頂階梯留白，且門前 `x=650..950` 應保持無 NPC 遮擋。

### 5.3 Autumn required contract

Autumn 有兩個 authoritative scenes：

```text
AutumnSafeZoneMap
├── Backdrop / Terrain / WorldCollision
├── PlayerSpawn / BattleReturnSpawn / Player
├── TownPortal / BattlePortal
├── Campfire
├── SeatedTrailMerchant
├── EditorHUDReference
└── EditorHelpers

AutumnBattleMapV2
├── GeneratedBackdrop
├── GeneratedRoute
│   └── RouteChunk00..23
├── GameplayZones
├── PlayerSpawn / ForestShortcutSpawn / Player
├── AutumnRunDirector
├── HiddenBranchCache / WanderingCardMerchant / ShortcutLever
├── WestSafePortal / EastSafePortal
├── WorldBounds
├── EditorHUDReference
└── EditorHelpers
```

`AutumnRouteChunk` 的 440px floor collision 在接縫保留 2px overlap。平台只可使用
one-way collision；樹、柵欄、岩石等 dressing 不得阻擋主路。新增變體需同步
`autumn_modular_route_test.gd` 的 manifest／determinism／continuous-floor contract。
固定 Run interactives 的 body collision layer 必須為 0，只保留 InteractionArea。
安全區使用不含 CardHand 的專用 editor HUD reference。

### 5.4 Required map metadata

Current maps在root metadata提供：

- `map_width`
- `map_height`
- `camera_limit_left`
- `camera_limit_top`
- `camera_limit_right`
- `camera_limit_bottom`

`Game._configure_player_camera()`讀取這些values。新增map或調整bounds時同步更新
collision、portal reachability與`tests/map_navigation_contract_test.gd`。

### 5.5 Player與spawn

- 每個playable authoritative map恰好一個`Player`。
- 每個map至少有`PlayerSpawn`。
- Portal可指定其他named `Marker2D`，例如Town fast travel arrival。
- `Game._register_player()`以`find_child("Player")`與spawn name定位。
- rename前必須更新Portal、Game、tests與save flow。

### 5.6 HUD authoring與runtime adoption

每個authoritative map instance：

```text
EditorHUDReference (CanvasLayer)
└── HUD (Control)
    └── AutumnCardHandUI（Autumn only）
```

Editor中：

- `EditorHUDReference` 讓單一 HUD authority（含 Autumn 內嵌 hand）可在 map 主
  Scene 預覽與調整。
- `EditorHUDReference` script使用`Engine.is_editor_hint()`控制visibility。
- map用`[editable path]`暴露需要調整的children。

Runtime：

- `Game.load_hud()` 將 exact `HUD` instance reparent 到 `HUDLayer`。
- Autumn 不得把 hand 再 reparent 成第二個 root；它隨 HUD 一起移動。
- `EditorHUDReference/HUD` 因此不再留在 current map 下。
- identity、anchors、offsets、scale與layout overrides必須保留。

不要再放第二份HUD到map或Game。不要以script重建map-authored root layout。

## 6. Map Component 與 Editor Helper

### 6.1 Town components

Current composition：

- active：`scenes/maps/town/components/TownBackdrop.tscn`
- active：`scenes/maps/town/components/TownEternalForgeIdentity.tscn`
- active：`scenes/maps/town/components/TownNPCs.tscn`
- active：`scenes/maps/town/components/TownBuildingEntrances.tscn`
- active：`scenes/maps/town/components/TownWorldCollision.tscn`
- portals：`scenes/maps/town/portals/TownPortalSet.tscn`
- hidden compatibility visuals：`scenes/maps/town/legacy/**`

`legacy/` 內容仍由 progression 與 linked-scene contract 使用，但 runtime
presentation 隱藏；不得在此新增新 Town 視覺。
共享元件應instance而非copy Scene Tree。

### 6.2 Component responsibility

- backdrop只含視覺layer，不處理經濟或Portal。
- ground/collision分開，視覺改動不得隱式改physics。
- NPC container組合display-only NPC instances，不承載互動或對話資料。
- Building entrance container組合門口互動 instances，不承載 UI instance。
- Portal set組合route instances，不自行load map。
- decorative prop不應加入`Interactives`，除非它真的實作完整contract。

### 6.3 Editor helpers

Current helper scenes：

- `scenes/maps/town/editor/TownEditorHelpers.tscn`
- `scenes/maps/town/editor/TownEternalForgeEditorHUDReference.tscn`
- `scenes/maps/autumn_battle/editor/AutumnBattleMapV2EditorHelpers.tscn`
- `scenes/maps/autumn_battle/editor/AutumnEditorHUDReference.tscn`
- `scenes/maps/autumn_safe/editor/AutumnSafeZoneEditorHelpers.tscn`
- `scenes/ui/hud/editor/SharedEditorHUDReference.tscn`

Helper script必須：

```gdscript
@tool
extends Node2D

func _ready() -> void:
	visible = Engine.is_editor_hint()
```

若helper runtime建立children且要保存到Scene，必須設定正確`owner`；目前優先使用
靜態Scene nodes。Editor helper不可在runtime啟動gameplay。

## 7. Player、Monster 與 Combat Scene

### 7.1 Player contract

`res://scenes/player/Player.tscn`

```text
Player (CharacterBody2D, group "Player")
├── Visual (Node2D)
│   └── CharacterSprite (Sprite2D)
├── CollisionShape2D
├── InteractionDetector (Area2D)
│   └── CollisionShape2D
├── Hurtbox (Area2D)
│   └── CollisionShape2D
└── Camera2D
```

Script：`scripts/player/player_controller.gd`。

Required signals：

- `state_changed(state: StringName)`
- `resources_changed(health, max_health, mana, max_mana)`
- `defeated`

不要把HUD child放進Player。Camera跟隨Player，但limits由current map metadata配置。

### 7.2 Enemy contract

`AutumnEnemy.tscn`與`AutumnGuardian.tscn`：

```text
Enemy (CharacterBody2D, group "Enemies")
├── Visual
├── CollisionShape2D
├── Hurtbox (Area2D, Hurtbox)
│   └── CollisionShape2D
└── HealthBar
    ├── Background
    └── Fill
```

`EnemyBase` signals：

- `defeated(enemy, experience, gold)`
- `health_changed(current, maximum)`
- `attack_telegraphed(pattern, duration)`
- `attack_performed(pattern)`

Boss另有`Bosses` group、phase/drop signals。HealthBar是world-space display，
不是global HUD。

### 7.3 Director ownership

`AutumnRunDirector`屬於map Scene並加入`EncounterDirectors` group。它可runtime：

- instantiate enemy/guardian
- add children under director
- instantiate ExperienceGem
- cleanup/reset active wave

靜態地形、Portal、campfire、chest不得由director重建。

### 7.4 Area2D combat scenes

- `scenes/combat/ExperienceGem.tscn`：pickup lifecycle。
- `Hurtbox`是adapter，不決定整場戰鬥。

Dynamic node建立端必須定義終止條件、signal disconnect與`queue_free()`。

## 8. Interactive、NPC、Portal 與 Prop Scene

### 8.1 Base interactive tree

Current contract由`tests/interactive_scene_contract_test.gd`保護：

```text
InteractiveRoot (StaticBody2D, group "Interactives")
├── Visual
├── CollisionShape2D
└── InteractionArea (Area2D)
    └── CollisionShape2D
```

Base script：`scripts/interaction/interactive_object.gd`。

Required base signals：

- `interaction_available`
- `interaction_unavailable`
- `interacted`

### 8.2 Specialized scenes

| Scene | Extra group | Script | Domain signal |
|---|---|---|---|
| `scenes/npc/Merchant.tscn` | `NPCs` | `npc.gd` | `shop_requested` |
| `scenes/npc/Merchant.tscn` | `NPCs`, `Merchants` | `merchant.gd` | `dialogue_requested`, `shop_requested` |
| `scenes/props/Portal.tscn` | `Portals` | `portal.gd` | `portal_entered`, `locked_interaction` |
| `scenes/props/Chest.tscn` | `Props` | `chest.gd` | `chest_opened` |

Town NPC variant可override：

- `interaction_id`
- `prompt_text`
- `display_name`
- `dialogue_id`
- Merchant的`shop_id`

Override不應改掉base child names或group。

### 8.3 Portal rule

Portal Scene只描述destination intent與lock state：

```gdscript
@export_file("*.tscn") var target_scene_path: String
@export var target_spawn_name: StringName = &"PlayerSpawn"
```

Portal不得直接replace SceneTree。它emit signal，由Game解析canonical path、run
transition與authoritative scene。

### 8.4 Decorative props

Town prop/building多為`Sprite2D` scene，groups如`TownProp`、`TownBuilding`。
這些group是分類，不代表互動。若新增Collision或Interactive：

1. 評估root type是否仍正確。
2. 建立完整collision/area。
3. 接base interactive script與signals。
4. 加contract test。

## 9. UI Scene

### 9.1 Root rules

- screen UI root使用`Control`。
- editor HUD reference使用`CanvasLayer`包住`Control` roots。
- full-screen root使用Full Rect。
- dynamic list items放Container。
- static layout保留在`.tscn`。
- runtime只建立真正variable children，例如card buttons、dialogue choices。

詳細layout規則見`docs/04_UI_GUIDE.md`。

### 9.2 Current major UI scenes

| Scene | Root | Responsibility |
|---|---|---|
| `scenes/ui/hud/HUD.tscn` | `Control` | status/area/objective/prompt |
| `scenes/ui/cards/CardHandUI.tscn` | `Control` | card fan/AP/combo/boss |
| `scenes/ui/inventory/InventoryUI.tscn` | `Control` | prototype inventory projection |
| `scenes/ui/dialogue/DialogueUI.tscn` | `Control` | speaker/text/choice interaction |
| `scenes/ui/shop/ShopUI.tscn` | `Control` | icon-based merchant catalog transaction intent |
| `scenes/ui/system/PauseMenu.tscn` | `Control` | pause/settings/save/load intent |
| `scenes/ui/town/MaterialYardUI.tscn` | `Control` | forging materials and permanent tools |
| `scenes/ui/town/PlayerBlacksmithUI.tscn` | `Control` | blueprint forge, workshop upgrades, sales table |
| `scenes/ui/town/TownHallUI.tscn` | `Control` | village stage and Town Hall upgrade |
| `scenes/ui/town/TownResidenceUI.tscn` | `Control` | information-only residence screen |

### 9.3 Reusable UI child scenes

Existing examples：

- HUD：`scenes/ui/hud/*.tscn`
- Inventory：`InventoryHeader`, `InventoryCategoryTabs`,
  `InventorySlot`, `InventoryDetailPanel`
- Shop：`ShopItemRow`, `ShopDetailPanel`, `ShopMerchantPanel`

同型元件應instance共享Scene，不複製StyleBox與Node Tree。Theme與元件詳細規範
見`docs/07_THEME_GUIDE.md`、`docs/08_COMPONENT_LIBRARY.md`。

### 9.4 Town building service Scene contract

三個現役功能建築 screen 都在 `.tscn` author 穩定 layout，script 只建立真正的
資料驅動內容，例如 Player Blacksmith equipment rows：

```text
MenuLayer
└── DedicatedTownBuildingUI (Control, Full Rect)
    ├── DimBackground
    └── SafeMargin
        └── CenterContainer
            └── SemanticWindow (PanelContainer)
                └── Container-authored header/resources/workspace/actions
```

- `MaterialYardUI` 以 Materials／Forge Tools filter 切換資料驅動 offers，鎖定項目
  保持可見並顯示所需火炬 Tier。
- `PlayerBlacksmithUI` 以 service rail 切換 Forge／Workshop Upgrade／Sales Table；
  recipe rows 由已持有圖紙、工具與 blacksmith level 投影。
- `TownHallUI` 只保留 Overview／Hall Upgrade 兩個主要入口，左側固定村長肖像。
- 三者的 Full Rect root、semantic window、public API、focus、重開與六解析度
  geometry 由 dedicated tests 保護。

舊通用 Town progression scene/script 已退役；功能建築不得再建立第二套通用
runtime layout authority。

## 10. Instance、Editable Children、Owner 與 Runtime Node

### 10.1 Instance first

可重用內容使用`PackedScene` instance：

- Player
- NPC/Merchant variants
- Portal/Chest
- map components
- HUD child components
- monsters/combat pickups

不要copy/paste同一Node Tree到多個map。

### 10.2 Editable children

Authoritative map使用`[editable path]`允許在主Scene Inspector調整component instance。

允許：

- position/visual override
- Portal destination/prompt
- NPC dialogue/shop ID
- HUD root layout override
- collision shape與map-specific placement

需要謹慎：

- rename inherited child
- 改script/root type
- 移除required child
- override owner造成Scene保存異常

修改後必須直接打開authoritative Scene、F6與Main。

### 10.3 Owner

Godot `owner`決定動態Node是否保存進PackedScene。規則：

- runtime enemy、drop、damage number不設定owner，生命週期只屬runtime。
- `@tool`若建立需持久化的editor child，設定到edited scene root owner。
- 能用靜態`.tscn`表達的layout/content，不以tool script動態重建。

### 10.4 Runtime-only nodes

Current合法例：

- EncounterDirector spawned enemies。
- ExperienceGem。
- CardHandUI variable card buttons。
- DialogueUI extra choice buttons。
- damage number/telegraph/summon visual。

每個runtime-only node必須有清楚owner、cleanup與重入行為。

## 11. Signal、Group 與 NodePath Contract

### 11.1 Groups

Current runtime groups：

- `Player`
- `Enemies`, `AutumnEnemies`, `Bosses`
- `EncounterDirectors`
- `Interactives`, `NPCs`, `Merchants`, `Portals`, `Props`
- editor/content classification：`TownProp`, `TownBuilding`

Group rename等同public API change。搜尋：

```powershell
rg -n 'groups=|get_nodes_in_group|get_first_node_in_group|is_in_group' scenes scripts tests
```

### 11.2 NodePath

Stable child使用`@onready`或typed`get_node()`；optional child使用
`get_node_or_null()`並處理null。

Deep path出現在HUD/Inventory/Shop scripts，Scene rename時必須：

1. `rg`所有path。
2. 更新script與test。
3. instantiate Scene驗證`_ready()`。
4. 驗證runtime adoption後path仍相對正確。

### 11.3 Signal connection

- Scene內固定button可使用`.tscn [connection]`。
- runtime/dynamic instance在owner script連接。
- 連接前檢查`is_connected()`。
- `CONNECT_ONE_SHOT`用於一次性choice/result。
- queue_free後不得保留stale reference。

## 12. Scene Ownership 與生命週期

### 12.1 Map transition

| Phase | Owner action |
|---|---|
| Before unload | Game capture selected Player properties |
| Unload | queue_free MapRoot children，清current references |
| Instantiate | add authoritative map under MapRoot |
| UI | adopt map HUD（Autumn hand 已內嵌） |
| Player | find Player，move to spawn，apply state/equipment |
| Wiring | connect interactive/director/player signals |
| Ready | update HUD，emit `map_loaded` |

### 12.2 UI lifecycle

- `Game.open_ui()` owns instantiate/add/stack/pause。
- UI ownspresentation、focus與intent signal。
- `Game.close_ui()` ownsstack removal、pause update、queue_free。
- UI自發`closed`時回到Game cleanup。

### 12.3 Encounter lifecycle

- map owns director。
- director owns spawnedcombat children。
- enemy emits defeated before delayed queue_free。
- Game listens to director/gem progress，不直接擁有enemy instances。

### 12.4 Editor/runtime boundary

`EditorHUDReference`與`EditorHelpers`使用`Engine.is_editor_hint()`。
任何`@tool` script：

- `_enter_tree()`與`_ready()`都需安全。
- 不在editor寫save、啟動encounter或改runtime progression。
- reload時不重複建立children/signals。

## 13. Code Example

### 13.1 Interactive scene contract

來源：`scripts/interaction/interactive_object.gd`

```gdscript
extends StaticBody2D

signal interaction_available(interactive: Node, interactor: Node)
signal interaction_unavailable(interactive: Node, interactor: Node)
signal interacted(interactive: Node, interactor: Node)

@onready var interaction_area: Area2D = $InteractionArea

func _ready() -> void:
	interaction_area.body_entered.connect(
		_on_interaction_area_body_entered
	)
	interaction_area.body_exited.connect(
		_on_interaction_area_body_exited
	)
```

這段code依賴固定`InteractionArea` NodePath與base signals，因此Scene與script
必須一起review。

## 14. Scene Tree Examples

### 14.1 Portal

```text
Portal (StaticBody2D, Interactives + Portals)
├── Visual (Sprite2D)
├── CollisionShape2D
└── InteractionArea (Area2D)
    └── CollisionShape2D
```

### 14.2 Inventory UI

```text
InventoryUI (Control)
├── DimBackground
└── MainPanel (PanelContainer)
    └── MainMargin (MarginContainer)
        └── MainLayout (VBoxContainer)
            ├── HeaderPanel (instance)
            └── ContentRow (HBoxContainer)
                ├── InventoryColumn
                │   ├── CategoryTabs (instance)
                │   └── SlotGrid
                │       └── InventorySlot instances
                └── DetailPanel (instance)
```

### 14.3 Runtime map

```text
Game/MapRoot
└── AutumnBattleMapV2
    ├── world-authored nodes
    ├── Player
    ├── AutumnRunDirector
    │   └── runtime enemies/gems
    ├── interactives
    └── EditorHUDReference
        └── [empty of adopted HUD roots at runtime]
```

## 15. Godot Example (Godot 4)

### 15.1 Runtime PackedScene ownership

```gdscript
func spawn_enemy(scene: PackedScene, parent: Node) -> Node:
	if scene == null or parent == null:
		return null
	var enemy := scene.instantiate()
	parent.add_child(enemy)
	return enemy
```

使用Godot 4的`PackedScene.instantiate()`。只有真正dynamic enemy應使用此模式；
靜態map content應留在authoritative `.tscn`。

### 15.2 Editor-only helper

```gdscript
@tool
extends Node2D

func _enter_tree() -> void:
	visible = Engine.is_editor_hint()

func _ready() -> void:
	visible = Engine.is_editor_hint()
```

## 16. Best Practice

- 用Scene instance組合可重用content。
- 一個Scene root對應一個明確lifecycle/responsibility。
- 地圖只從authoritative main scene編輯與runtime載入。
- static map/UI內容在editor可見。
- dynamic nodes由明確owner建立與清理。
- groups、signals、NodePaths視為public contract。
- map root metadata、spawn與camera一起review。
- UI root layout在reparent前後保持。

## 17. Anti Pattern

- 直接runtime load canonical base map，繞過authoritative wrapper。
- 同一 map 放兩個 Player、Camera 或 HUD authority；Autumn 另掛獨立 CardHandUI。
- script在`_ready()`重建可在Scene editor authored的整套layout。
- copy/paste component tree而不instance共享Scene。
- rename required node但只修一個script。
- 將temporary enemy/effect保存到Scene owner。
- editor helper在runtime可見或啟動gameplay。
- 用Node名稱推測domain而不查scene/script/group。

## 18. Scene Authoring Checklist

新增／修改Scene前：

- [ ] 已確認authoritative path與root type。
- [ ] 已搜尋同功能Scene與basename。
- [ ] 已列固定children、NodePath、groups、signals、script。
- [ ] 已確認instance/editable children/owner關係。
- [ ] static內容留在`.tscn`，dynamic內容有owner與cleanup。
- [ ] Map修改已檢查spawn、camera metadata、collision、Portal、HUD。
- [ ] UI修改已檢查Container、anchors、size flags與多解析度需求。
- [ ] 已標記使用者dirty Scene，不覆蓋其override。

## 19. Review Checklist

- [ ] Scene可load且無missing resource/parser error。
- [ ] Root name/type/script符合domain contract。
- [ ] Required child與NodePath存在。
- [ ] Groups與signals正確且未重複連接。
- [ ] Instance不是copy，editable override保留。
- [ ] Authoritative map 的 Player/Camera/HUD 數量正確，Autumn hand 只存在 HUD 內。
- [ ] Runtime adoption後HUD identity/layout保持。
- [ ] Map F6與Main都可操作。
- [ ] Portal destination/spawn與canonical mapping一致。
- [ ] Dynamic child可cleanup，換圖後無殘留。
- [ ] Git diff只含任務必要Scene/docs/tests。

## 20. Future Extension

以下為Proposed／TODO，不是Current：

- Current沒有gameplay `.tres`／`.res` catalog；若未來Scene引用typed Resource，
  需先在`docs/06_RESOURCE_GUIDE.md`定義authority、validation與save boundary。
- 用自動工具產生Scene/group/signal index。
- 為每種Scene contract建立共同test helper。
- 將更多UI StyleBox與visual component抽成共享Theme/Scene。
- 為新map提供authoritative wrapper template與metadata validator。
- 若導入NPC navigation、Quest Scene或Audio emitter，先定義ownership與save boundary。
- 若導入`AnimationPlayer`／`AnimationTree`，定義Scene child naming與animation event contract。

## 21. Autumn HUD 與 Growth Scene Contract

本節是 Autumn 改版後的 scene authority；若前文 generic HUD 範例與本節衝突，
以本節為準。Town 仍沿用自己的 HUD 與 CardHand scene，不因 Autumn 改版而重組。

```text
AutumnBattleMapV2
└── EditorHUDReference (CanvasLayer)
    └── HUD (AutumnHUD exact instance)
        ├── TopLeftStack
        │   ├── ActiveStatusList
        │   └── ObjectivePanel
        ├── TopCenterStack
        │   ├── BossHealth
        │   └── SkillToastStack
        └── BottomStage
            ├── PlayerVitals
            ├── ActionPoints
            ├── CardStage
            │   ├── ActionSpacer
            │   └── AutumnCardHandUI
            ├── InputGlyphHints
            └── PersonalResources
```

靜態區塊必須 editor-authored；script 只建立 cards、statuses 與 toast 等動態內容。
`Game` adoption 只 reparent `HUD` exact instance。不得在 map、`HUDLayer` 或 preview
helper 中保留另一個 Autumn hand authority。

Growth modal scene contract：

```text
Game/MenuLayer
└── CardGrowthUI（runtime modal）
    ├── Header
    ├── ChoiceGrid
    ├── Detail/selection state
    └── Confirm action
```

`CardGrowthUI` 不擁有 upgrade/fusion 規則，也不直接寫 Meta。它只顯示
`GrowthChoiceQueue.peek()` 的 page，並 emit choice ID。`Game` 必須在 caller
整合時負責 resolve、套用 mutation、永久 fallback save、下一頁與 pause token。
舊 `LevelUpUI` 不再是 Autumn/EXP 成長的 scene authority。

## 22. Related Documents

- `docs/README.md`
- `docs/01_AI_GUIDE.md`
- `docs/02_PROJECT_ARCHITECTURE.md`
- `docs/04_UI_GUIDE.md`
- `docs/05_CODING_STANDARD.md`
- `docs/06_RESOURCE_GUIDE.md`
- `docs/08_COMPONENT_LIBRARY.md`
- `docs/09_TESTING_GUIDE.md`
- `docs/10_DEBUG_GUIDE.md`
- `docs/rule_1.md`
