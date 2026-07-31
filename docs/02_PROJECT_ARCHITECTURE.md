# Project Architecture

本文件描述目前 repository 可驗證的 runtime 架構、ownership、資料流與已知風險。
它不是理想化藍圖。尚未存在的能力以 `TODO` 標示，不得將 Future Extension
當成已完成系統。

## 目錄

1. [文件目的與架構基準](#1-文件目的與架構基準)
2. [Application Entry 與 Composition Root](#2-application-entry-與-composition-root)
3. [Runtime Ownership](#3-runtime-ownership)
4. [Scene 與地圖架構](#4-scene-與地圖架構)
5. [主要 Script 與 Public Contract](#5-主要-script-與-public-contract)
6. [Signal 與跨系統資料流](#6-signal-與跨系統資料流)
7. [State、Inventory 與 Save](#7-stateinventory-與-save)
8. [UI、Pause 與 Input](#8-uipause-與-input)
9. [Combat、NPC、Dialogue、Quest、Audio、Animation](#9-combatnpcdialoguequestaudioanimation)
10. [依賴方向與變更規則](#10-依賴方向與變更規則)
11. [架構風險](#11-架構風險)
12. [Code Examples](#12-code-examples)
13. [Scene Tree Example](#13-scene-tree-example)
14. [Godot Example (Godot 4)](#14-godot-example-godot-4)
15. [Best Practice](#15-best-practice)
16. [Anti Pattern](#16-anti-pattern)
17. [Architecture Checklist](#17-architecture-checklist)
18. [Review Checklist](#18-review-checklist)
19. [Future Extension](#19-future-extension)
20. [Related Documents](#20-related-documents)

## 1. 文件目的與架構基準

### 1.1 技術基準

| 項目 | 現況 |
|---|---|
| Engine | Godot 4.7，`project.godot` 的 feature 為 `4.7` |
| Language | GDScript 2 |
| Application main scene | `res://scenes/game/game.tscn` |
| Base viewport | 1280 × 720 |
| Stretch | `canvas_items` |
| Runtime scenes | `scenes/` |
| Runtime scripts | `scripts/` |
| Static gameplay data | `data/*.json` |
| Autoload | **無**；`project.godot` 沒有 `[autoload]` |

### 1.2 文件中的狀態詞

- **Current**：可由目前 code、Scene、data 或 test 驗證。
- **Known Risk**：現有實作仍能運作，但 ownership 或資料一致性需要特別保護。
- **TODO**：repository 尚未存在，未來若實作需先完成設計、測試與文件同步。
- **Proposed**：只可出現在 Future Extension，不代表已核准。

### 1.3 核心原則

目前架構採 Scene composition，不採全域 singleton。不得在文件、測試或新程式中
假定有 `GameManager`、`QuestManager`、`DialogueManager` 或 `AudioManager`
Autoload。若未來新增 Autoload，必須同時更新本文件、Scene ownership、reset contract、
save boundary 與 scene reload tests。

## 2. Application Entry 與 Composition Root

### 2.1 Main scene

`project.godot`：

```ini
[application]
run/main_scene="res://scenes/game/game.tscn"
```

`scenes/game/game.tscn` 的根 `Game` 掛載
`res://scripts/managers/game.gd`，是目前 application composition root。

```text
Game (Node, scripts/managers/game.gd)
├── MapRoot (Node)
├── HUDLayer (CanvasLayer)
├── MenuLayer (CanvasLayer)
├── SkillCastPresentation (CanvasLayer)
└── CardEffectRunner (Node, CardEffectRunner)
```

### 2.2 Startup order

`Game._ready()` 的 current order：

1. 將 `Game`、`HUDLayer`、`MenuLayer` 設為 `PROCESS_MODE_ALWAYS`。
2. 透過 `SaveService.load_meta()` 讀取 `user://saves/meta_progress.json`。
3. 將 `MetaState.inventory_state`／legacy fields 套入 Inventory runtime state。
4. 將 `MetaState.town_state`／legacy fields 套入 Town runtime state。
5. 載入卡牌、技能與合成 recipe catalog；實際的 `SkillRecipeManager`、
   `GrowthChoiceQueue` 與成長 UI caller 由 `Game` 組裝。
6. 連接 `CardEffectRunner.effect_resolved`。
7. 呼叫 `load_current_map(starting_map)`。
8. 將 runtime progression 同步回 `MetaState`。

Startup 任一步驟的順序改變都可能影響地圖初始 HUD、裝備屬性、存檔 migration
或卡牌 catalog；修改時必須跑 progression、map 與 vertical slice tests。

### 2.3 Game lifecycle signals

`scripts/managers/game.gd` 對外宣告：

```gdscript
signal map_loaded(map: Node)
signal player_registered(player_node: Node)
signal ui_opened(ui_name: String, ui_node: Control)
signal ui_closed(ui_name: String, ui_node: Control)
```

目前 production code 未發現這四個 signals 的外部 consumer，但它們仍是 public
lifecycle contract。刪除或改參數前必須搜尋 tests、tools 與未追蹤工作。

## 3. Runtime Ownership

### 3.1 Ownership tree

```text
Game
├── current_map under MapRoot
│   ├── Player
│   ├── world/collision/portals/NPCs
│   └── encounter-owned runtime enemies and drops
├── HUDLayer
│   └── adopted HUD
│       └── embedded AutumnCardHandUI（僅 Autumn HUD）
├── MenuLayer
│   └── ui_stack managed modal/primary UI
├── CardEffectRunner
└── RefCounted state/services
    ├── MetaState
    ├── RunState
    ├── SaveService
    ├── CardDatabase
    ├── DeckManager
    ├── CardCollectionService
    ├── SkillRecipeManager
    ├── GrowthChoiceQueue
    ├── inventory_manager.gd instance
    └── town_manager.gd instance
```

### 3.2 Node ownership

- `MapRoot` 擁有當前地圖 instance；換圖時舊 children `queue_free()`。
- 地圖 Scene 擁有 Player、spawn、world collision、Portal、NPC 與靜態佈局。
- Encounter director 擁有 runtime-spawned enemy、guardian 與 experience gem。
- `HUDLayer` 擁有 current HUD；Autumn 的手牌是 `AutumnHUD` 內嵌 presentation，
  不得再作為與 HUD 並列的第二個 runtime root。換圖時釋放舊 HUD instance。
- `MenuLayer` 擁有 Inventory、Pause、Dialogue、Shop、MaterialYard、
  PlayerBlacksmith、TownHall 等 runtime UI。
- Dynamic damage number、summon visual、boss telegraph 使用短生命週期 Node/Tween，
  建立端同時負責 cleanup。

### 3.3 RefCounted ownership

State/system instances由 `Game` 建立並持有，不加入 SceneTree：

| Instance | Class／Script | Responsibility |
|---|---|---|
| `meta_state` | `MetaState` | 永久 progression save model |
| `run_state` | `RunState` | 一輪 expedition 的 transient state |
| `save_service` | `SaveService` | meta JSON 安全寫入與載入 |
| `card_database` | `CardDatabase` | validated card catalog |
| `deck_manager` | `DeckManager` | CardInstance 的 draw/hand/discard/exhaust/cooldown 與 AP |
| `card_collection_service` | `CardCollectionService` | 協調 MetaState／RunState／DeckManager 的 add／fuse／remove 與 collection snapshot／rollback |
| `skill_recipe_manager` | `SkillRecipeManager` | 已裝備的攻擊 recipe、視窗、進度與 cooldown |
| `growth_choice_queue` | `GrowthChoiceQueue` | wave/EXP 成長事件的單一 FIFO queue |
| `inventory_manager` | unnamed `RefCounted` script | resources/equipment runtime model |
| `town_manager` | unnamed `RefCounted` script | building levels/village stage |

`inventory_manager.gd` 與 `town_manager.gd` 沒有 `class_name`，由 `Game` preload
script 後 `new()`，以 `call()` 溝通。這是 Current，不應在文件中虛構 typed service。

## 4. Scene 與地圖架構

### 4.1 Canonical 與 authoritative path

Portal/content identity 使用 canonical path；runtime/editor 使用 authoritative main scene。
mapping 由純 `RefCounted` `scripts/systems/map_registry.gd` 管理。`Game` preload
該 registry，並保留原有 path constants、`MAP_MAIN_SCENE_PATHS` 與 compatibility
wrappers，讓 portal、HUD、save 與既有測試不需知道實作已抽離：

| Canonical path | Authoritative path | Runtime root |
|---|---|---|
| `res://scenes/maps/town.tscn` | `res://scenes/maps/town/TownMap.tscn` | `TownMap` |
| `res://scenes/maps/autumn_safe_zone.tscn` | `res://scenes/maps/autumn_safe/AutumnSafeZoneMap.tscn` | `AutumnSafeZoneMap` |
| `res://scenes/maps/autumn_forest.tscn` | `res://scenes/maps/autumn_battle/AutumnBattleMapV2.tscn` | `AutumnBattleMapV2` |
| `res://scenes/maps/crystal_caves.tscn` | `res://scenes/maps/layouts/CrystalCavesLayout.tscn` | `CrystalCaves` |
| `res://scenes/maps/forbidden_graveyard.tscn` | `res://scenes/maps/layouts/ForbiddenGraveyardLayout.tscn` | `ForbiddenGraveyard` |

Town canonical content 維持 `1942 × 720` Eternal Forge gameplay world 與
`y=672` baseline。`res://data/town_modular_layout.json` 定義
`1942 × 809` source canvas 上由 layout 列出的可替換物件，
`tools/build_town_modular_scene.py` 將其生成為 editor 與 runtime 共用的
`TownModularVisuals.tscn`；`TownBackdrop/ModularVisuals` 是目前 presentation
authority。核准的 Image #2 保留在 hidden
`TownBackdrop/EternalForgeConcept` 作背景、比例與整體構圖 reference。
`tools/build_town_modular_figma_board.py` 產生單頁 Figma board，並以同一 layout
輸出完整重組預覽與可單獨選取的分件素材庫。
Town 視覺統一採用 `data/town_visual_style.json` 的
`storybook_handdrawn_pixel_v2`：手繪不規則墨線、紙張顆粒、低飽和木石色、
冷苔綠陰影與左上暖蜜色主光。正式排版權威是
`concept/town/main_horizontal_concept/town_style_direction_a_locked.png`。
`town_a_background_plate.png` 提供藍天、白雲與群山；屋頂後方另疊
`autumn_forest_canopy_base_v2.png` 的繁盛秋林與
`autumn_ancient_tree_base_v2.png` 主樹。前景建築與秋林之間另有 visual-only
`green_ruins_boundary_tower_base_v3.png`、
`green_ruins_debris_bush_strip_base_v2.png` 與
`green_ruins_east_edge_cluster_base_v2.png`：粗像素古塔移到西側地圖邊界，
低矮灌木／斷牆／碎柱帶橫跨地圖，右緣再以針葉樹與落地殘牆封住淺色楔形空隙。
右緣針葉樹使用 Base MaterialYard 的大型不對稱枝葉色塊、粗斷筆觸與有限明暗，
不得以重複針葉紋理或密集高光製造細節；
三者 z-index 保持在秋林之前、主樹之後，避免遮住最大古樹。中央熔爐與傳送門保留既有辨識輪廓；
不滅熔爐與傳送門皆使用 MaterialYard-style Base v5。兩者共用大型
灰藍石塊、粗斷裂線稿、有限明暗與中性固有色；Base v5 熔爐另以約 4×
source-to-display pixel density 對齊鄰近 Base 建築的石材、銅件與木旗細節。
頂部火焰與中央符文光由獨立 8 幀循環動畫疊加，不再烘焙進靜態塔身。
傳送門 Base v5 只保留石框、木件、苔痕與未發光頂部晶石；門洞旋渦與內緣光
由 `TownBattlePortalAnimation.tscn` 的固定暗紫 underpaint 與兩組 12 幀
手繪逐格素材獨立負責，
頂部符文則使用 2 秒柔和呼吸。所有門洞幀在資產準備階段以 aperture mask 裁切，
不以單張貼圖做機械式 shader 旋轉。
`TownAmbientAnimation.tscn` 另外持有完整古樹的 root-anchored 徐風 shader，
以及可獨立替換的 12 幀屋簷枝葉、飄落葉與鳥類 sprite sheets。古樹平時固定，
每隔 8–18 秒才由上半部緩慢受風再回正；落葉以世界位置單向下降，近地停留後
原地淡出，不在半空 loop 或逆向飛。十個鳥停棲點以屋頂小群、地面小群及零散
個體分布，長時間待機後才因 Player 靠近或自然等待而起飛，同群以短錯時依序
離開。此 component 只負責 presentation，不建立碰撞、互動、NPC 或玩法
authority。
八塊道路與八塊橋牆組成唯一可見地板。道路視覺面從 `y=660`
開始，與維持在 `y=672` 的角色、建築與互動基準重疊 12 px，避免腳下與地基露出
背景縫隙。不得再以
`town_eternal_forge_v1.png` 整張暖色城鎮合成圖作 runtime background。
村長家、劍魂商、裝備圖紙商與東郊民宅使用以材料行為唯一 style reference 的
`*_base_v3.png`，runtime 維持約 4× source-to-display pixel density，且
foundation 全部對齊 `y=672`。
六棟主建築也已統一為材料行 Base 的群塊、線稿與中性固有色語言。前景 Base
只烘焙結構 AO 與接觸陰影，大面方向光由後續 Godot overlay 擁有。
分件候選中的六棟正式建築與街景使用 B2
`b2_front_right_orthographic`：正面為主、只露右側窄面、垂直線保持垂直、
深度邊一致往右上後退、地基維持水平。新增 18 個無碰撞生活／地面 dressing
物件只增加街景密度，不建立新的互動或玩法權威；其中六個會遮住東側立面的
大型 dressing 保持 hidden。舊 modular-v1 街具與浮空旗幟
保留 stable layout entry 供相容／替換，但 `visible=false`，不得參與 runtime
composition 或遮住建築。
互動、碰撞、NPC、Portal、Player 與 progression identity 仍由既有 linked scenes
管理；模組化 Sprite 不建立第二套 gameplay authority。
`EternalForgeIdentity` 提供八個精簡地點標籤與後續物件精修入口。六棟建築標籤
由 `scripts/maps/town_location_labels.gd` 投影 `TownBuildingEntrances` 的地基
進出 signal：Player 在地基外時 hidden，進入時只顯示目前建築的 B2 木牌，並固定
放在建築最高輪廓上方。不滅火炬與傳送門的世界標籤預設 hidden，傳送門仍由
HUD interaction prompt 說明。
六棟建築由 `TownBuildingEntrances` 擁有覆蓋完整地基的互動 Area 與 UI route；
其中五棟提供服務，最東側民宅只開啟資訊 UI。原東側住宅改為裝備圖紙商，
與劍魂商分別販售 equipment／Sword Soul 永久圖紙。NPC 不再是 Town 建築服務的
互動 authority。相鄰 Area 同時候選時，Game 在互動當下選擇距離 Player 最近者。

Town portal ownership 已收斂為 `TownPortalSet/BattleGateway`。它只前往
`res://scenes/maps/battle_portal_hub.tscn`；區域目的地由 hub 的四個 region
portal slots 擁有，中央 `BossPortalAnchor` 是無互動、無 scene target 的未來尾王
定位點。

Autumn 現在拆為 safe zone 與 battle route。Town/hub 的 Autumn portal 先進入
`AutumnSafeZoneMap`；安全區由左至右配置 Town return、Player spawn、可重複使用
的營火、非阻擋坐姿商人及 battle portal，完整收在單一 1280px gameplay viewport。
battle portal 才開啟 Deck Builder 並開始 Run。戰鬥 route 為
`24 × 440 = 10560` pixels，由 `AutumnRouteGenerator` 先規劃低地、中台、高台與
平原區段，再以短 transition chunks 連接。浮空平台以 1–2 chunks 群組及 1–2
chunks 空白交替，只提供可選路線，不得成為前進必要條件。兩端 portal 都回到安全
區，離開時依 Guardian 狀態以勝利或撤退結算 Run。安全區 HUD 不建立 CardHand
authority，戰鬥 route 不放置固定商人、寶箱或捷徑開關。

規則：

- Portal `target_scene_path` 可保留 canonical path。
- `MapRegistry` 只處理 path identity，不載入 scene、不持有 Node/Player/UI/save。
- `Game._resolve_main_scene_path()` 後才 `load()` destination。
- HUD area name與 run/map identity 經 `_canonical_map_scene_path()` 比對。
- Save 的 `map_path` 目前保存 instantiated authoritative
  `current_map.scene_file_path`。
- Registry 抽取不改變 quick-save payload；任何改存 canonical path 的提案都屬
  schema/migration 變更，需另行測試。
- 新地圖若採此 pattern，必須同時加入 mapping、authoritative scene、Portal
  contract、save compatibility與 tests。

### 4.2 Map load flow

```text
Portal.portal_entered
→ Game._on_portal_entered()
→ canonical target
→ Game._resolve_main_scene_path()
→ load PackedScene
→ Game.load_current_map()
   ├── capture transferable Player state
   ├── queue_free old map
   ├── instantiate authoritative map
   ├── adopt HUD（Autumn hand 已內嵌）
   ├── register Player at named spawn
   ├── apply transferred/equipment state
   ├── wire Interactives/EncounterDirectors
   ├── update HUD
   └── map_loaded.emit()
```

`load_current_map()` 不使用 `SceneTree.change_scene_to_*()`；application `Game`
保持存活，只替換 `MapRoot` child。

### 4.3 HUD adoption

Authoritative map 包含 editor-visible `EditorHUDReference`：

```text
EditorHUDReference (CanvasLayer)
└── HUD (Control)
    └── AutumnCardHandUI（僅 Autumn）
```

Runtime 時 `Game.load_hud()` 將 **exact HUD instance** `reparent()` 到
`Game/HUDLayer`。這不是複製，也不是重新 instantiate。Autumn 不再呼叫獨立的
`load_card_hand()` 來建立第二個 root；Town 的既有 HUD 契約不因這次改版改動。

重要 contract：

- reparent 前後 root anchors、offsets、position、scale、metadata 必須保持。
- 換圖時 previous HUD（連同其內嵌 hand）必須釋放。
- Autumn runtime 只允許一個 HUD authority；不得另掛獨立 CardHand root。
- `tests/map_layout_scenes_test.gd` 驗證 exact instance identity。

Scene authoring細節見 `docs/03_SCENE_STRUCTURE.md`。

## 5. 主要 Script 與 Public Contract

### 5.1 State/data

| Class | Source | Public API |
|---|---|---|
| `MetaState` | `scripts/systems/meta_state.gd` | `add_resource`, `can_afford`, `spend`, `apply_run_summary`, `to_dict`, `apply_dict`, `normalize_selected_deck` |
| `RunState` | `scripts/systems/run_state.gd` | `begin_run`, `finish_run`, `add_reward`, `add_experience`, `consume_pending_level` |
| `CardDatabase` | `scripts/systems/card_database.gd` | `load_catalog`, `get_card`, `has_card`, `get_all_cards` |
| `DeckManager` | `scripts/systems/deck_manager.gd` | `start`, `draw_cards`, `play_from_hand`, `regenerate_energy`, `discard_and_redraw_hand`, `end_turn` |
| `CardCollectionService` | `scripts/systems/card_collection_service.gd` | `is_configured`, `get_deck_size`, `get_copy_count`, `add_persistent_card`, `fuse`, `remove_instance`, `capture_state`, `restore_state` |
| `CardInstance` | `scripts/systems/card_instance.gd` | `instance_id`, `card_id`, `level`, `is_fixed`, `is_growth_locked`, `to_dict`, `from_dict` |
| `SkillRecipeManager` | `scripts/systems/skill_recipe_manager.gd` | `load_catalog`, `configure_loadout`, `record_card`, `tick`, `reset_runtime` |
| `GrowthChoiceQueue` | `scripts/systems/growth_choice_queue.gd` | `enqueue_wave_blessing`, `enqueue_experience_growth`, `peek`, `resolve` |
| `ElementTaxonomy` | `scripts/systems/element_taxonomy.gd` | `get_all`, `normalize`, `is_valid`, `get_color`；武器、神賜與戰鬥 VFX 共用的元素命名權威 |
| `ElementalGroundTrailCatalog` | `scripts/systems/elemental_ground_trail_catalog.gd` | 驗證火／冰／毒地面路徑 profile、四象限 atlas 與 visual budget |
| `SaveService` | `scripts/systems/save_service.gd` | `save_meta`, `load_meta` |

### 5.2 Combat

| Class | Source | Contract |
|---|---|---|
| `CardEffectRunner` | `scripts/combat/card_effect_runner.gd` | `cast()` 修改 caster/targets，emit `effect_resolved`；大招致死前先以 `prepare_hit_presentation()` 傳遞元素與真實 impact delay |
| `AutoAttackFeedback` | `scripts/combat/auto_attack_feedback.gd`、`scripts/combat/premium_crescent_layer.gd` | 以 deterministic 月牙 sheet 加上分層 additive atlas 投影普攻蓄勢、流動劍氣、命中、實際傷害與 Combo power；不處理傷害規則 |
| `SkillCastPresentation` | `scripts/combat/skill_cast_presentation.gd` | 以 unscaled Tween 顯示放大招式名稱並管理短暫施法慢動作 |
| Elemental combat VFX | `scenes/combat/vfx/*.tscn` | 火／冰攻擊纏繞與範圍大招的純 presentation；不擁有傷害判定 |
| `ElementalGroundTrail` | `scenes/combat/vfx/ElementalGroundTrail.tscn`、`data/elemental_ground_trail_profiles.json` | 沿元素大招路徑拼裝 Core／Edge／Accent／Debris atlas 部件與連續 ribbon；火、冰、毒使用不同 topology，不擁有傷害判定 |
| `NamedSkillVFX` | `scenes/combat/vfx/NamedSkillVFX.tscn`、`data/named_skill_vfx_profiles.json` | 依精確 Skill／Finisher id、唯一 archetype 與 beat pattern 組合五種圖集部件；`play()` 另接收 evolution level 與 buff stacks 以增加結構層，不擁有傷害判定 |
| `CombatStatusController` | `scripts/combat/combat_status_controller.gd` | super armor、damage reduction、lifesteal、regeneration、retaliation 與 timer pause |
| `EncounterDirector` | `scripts/combat/encounter_director.gd` | wave plan、engagement/leash、enemy ownership |
| `SurvivalWaveDirector` | `scripts/combat/survival_wave_director.gd` | single countdown、scheduled Elite/Boss、Final Rush、XP gem |
| `EnemyBase` | `scripts/monsters/enemy_base.gd` | archetype、attack、damage、status、reset；大招致死立即結算玩法，再以 unscaled `impact_hold → dissolve → burst` 保留可讀消滅演出 |
| `AutumnGuardian` | `scripts/monsters/autumn_guardian.gd` | boss phases/pattern profiles |
| `Hurtbox` | `scripts/combat/hurtbox.gd` | `receive_hit()` adapter |
| `ExperienceGem` | `scripts/combat/experience_gem.gd` | configure/attract/collect |

### 5.3 UI

UI 對上層提供 setter/configure API與 typed signals：

- `HUD`：player/resource/area/objective/prompt projection。
- `CardHandUI`：cards/AP/combo/boss presentation；emit selection。
- `DialogueUI`：speaker/text/choices；emit choice/advanced/canceled。
- `ShopUI`：圖示化 catalog projection 與結構化商品列；emit
  mode/quantity/confirmed。
- `InventoryUI`：消耗品、永久材料、持有裝備 projection，以及只讀 discovery
  codex。Codex 由 `MetaState.unlocked_cards`／`learned_skill_ids` 投影普通攻擊、
  skills 與 infusions，預覽重用
  production elemental VFX，不擁有戰鬥規則。
- `MaterialYardUI`：依 Eternal Torch／village stage 解鎖的鍛造材料與永久工具。
- `PlayerBlacksmithUI`：圖紙鍛造、blacksmith 等級、Sword Soul 升級與裝備販售桌。
- `TownHallUI`：village stage、總建築等級、Town Hall 成本與升級操作。
- `PauseMenu`：emit save/load/settings/exit-combat/quit 等 intent；Game 只在 active
  combat Run 啟用退出戰鬥，接收 intent 後以失敗結算保留已得資源並回 Town。

三個功能建築 UI 都是 editor-authored Full Rect Scene，由
`Game._open_town_service_ui()` 依 `service_id` 選擇，並透過 `set_context()` 與
`set_services()` 接收既有 Town/Inventory `RefCounted` services。它們目前仍直接
呼叫 domain API 完成建築／裝備升級；材料、圖紙、鍛造與販售 intent 交給
`Game` 透過 `ForgeService` 驗證，成功後立即同步 Meta/save。`Game.close_ui()`
仍負責最終同步與 world visual projection。UI 不應新增 domain 規則，直接 service mutation
仍是 Known Risk；舊的通用 Town progression screen 已退役。

## 6. Signal 與跨系統資料流

### 6.1 Signal direction

```text
leaf Scene / UI
  ── typed signal ──▶ Game orchestrator
                         │
                         ├──▶ RefCounted system mutation
                         ├──▶ Scene lifecycle
                         └──▶ UI projection method
```

下層元件不尋找 `Game`。`Game._connect_if_present()` 對 group-discovered Node
依 signal name連接 handler。

### 6.2 Interaction flow

```text
InteractionArea.body_entered
→ interaction_available(interactive, player)
→ Game.current_interactive
→ HUD.set_interaction_prompt()
→ Input "interact"
→ interactive.interact(player)
→ one of:
   dialogue_requested / shop_requested / portal_entered / chest_opened
→ Game handler
```

只有 `Interactives` group內 Node會被 `_wire_interactives()` 掃描。新增互動場景時，
Scene group、base signals與固定 child contract缺一不可。

### 6.3 Card combat flow

```text
data/cards.json
→ CardDatabase
→ DeckBuilderUI selects 1 Healing slot + 3 Combo slots + one auto-attack card
→ MetaState selected deck / auto_attack_card_id
→ RunState + DeckManager
→ CardHandUI.set_cards()
→ card_selected(index)
→ Game._on_card_selected()
→ card level + equipment + infusion projection
→ CardEffectRunner.cast(card, player, targets)
→ Player/Enemy public combat API
→ effect_resolved
→ damage visual / camera shake / hit stop
```

### 6.4 Progression flow

```text
combat reward
→ RunState temporary rewards
→ Game._finish_run()
→ MetaState.apply_run_summary()
→ InventoryManager resources
→ Game._sync_progression_to_meta()
→ SaveService.save_meta()
→ HUD / dedicated town building UI projection
```

任何直接改 `MetaState.resources` 而未同步 InventoryManager，或只改
`wallet_gold` 而未更新 InventoryManager，皆可能製造漂移。

## 7. State、Inventory 與 Save

### 7.1 Static / runtime / save boundary

```text
Validated static JSON
→ runtime catalog / manager state
→ MetaState or RunState
→ UI projection
→ explicit save serialization
```

資料格式與 validation詳見 `docs/06_RESOURCE_GUIDE.md`。

### 7.2 MetaState vs RunState

| Boundary | `MetaState` | `RunState` |
|---|---|---|
| Lifetime | application/restart persistent | one expedition |
| Save | `meta_progress.json` | 不直接完整保存 |
| Examples | resources、unlocks、deck、equipment、town、shortcuts | level、XP、AP、temporary cards/buffs、run rewards |
| Reset | load/default/migration | `begin_run()`／`finish_run()` |

不得將 `RunState` transient buffs寫入 permanent meta，除非玩法與 schema
明確要求且有 migration test。

### 7.3 Inventory overlap

目前有三份相關狀態：

1. `inventory_manager.gd`：permanent resources/equipment model。
2. `MetaState`：save fields與 legacy compatibility。
3. `Game.wallet_gold`、`Game.player_inventory`、`_merchant_catalogs`：
   consumable/merchant compatibility state。

`Game._sync_progression_to_meta()` 是主要同步點。`InventoryUI` 合併只讀
`player_inventory` 與 InventoryManager projection；交易仍由
`MaterialYardUI`、`PlayerBlacksmithUI` 與 service layer 處理。治理與 review
必須把 compatibility consumables 視為 Known Risk，不得由 UI 直接 mutation。

### 7.4 Save pipelines

Permanent meta：

- path：`user://saves/meta_progress.json`
- schema：`MetaState.SCHEMA_VERSION == 7`
- service：`SaveService`
- behavior：`.tmp` write → parse validation → backup → rename

Quick save：

- path：`user://saves/quick_save.json`
- schema：1
- owner：`Game._save_quick_slot()`／`_load_quick_slot()`
- payload：authoritative map path、Player position/stats、prototype wallet/inventory/catalog
- limitation：不是完整 `RunState` 或 meta snapshot

兩條 pipeline 的 validation、backup restore與migration不同。不可用「完整存檔系統」
一詞掩蓋差異。

## 8. UI、Pause 與 Input

### 8.1 UI stack

`Game.open_ui()`：

- 防止相同名稱重複 instance。
- instantiate到 `MenuLayer`。
- 記錄 `ui_stack`、name與pause flag。
- 連接 common control/lifecycle signals。
- 呼叫 UI `open()`，設定 focus。
- 依 stack更新 `SceneTree.paused` 與 Player input。

`close_ui()` 對三個專用功能建築 UI 同步 town/inventory progression、寫入 meta
save、更新 town visual 與 equipment stats；之後 emit lifecycle signal、
`queue_free()` 並更新 pause。

### 8.2 Pause

只要 stack中任一 UI的 pause flag為 true，`get_tree().paused = true`。UI root設
`PROCESS_MODE_ALWAYS`，因此 paused時仍能回應。Player input只有在 stack為空時啟用。

### 8.3 Input ownership

| Action | Current consumer |
|---|---|
| move／↑ Jump／Space Dash | `player_controller.gd` |
| automatic horizontal Basic Attack、interact/inventory/pause/card focus | `game.gd` |
| card group/slot | `card_hand_ui.gd` |
| UI navigation | individual UI scripts |

`card_group_1` / `card_group_2` 已移除；A/S 僅保留移動用途。專案沒有正式 Input Context
service；修改 mappings或處理順序時須用實際 run驗證。

## 9. Combat、NPC、Dialogue、Quest、Audio、Animation

### 9.1 Combat — Current

- Autumn battle route 使用 `SurvivalWaveDirector`；安全區沒有 encounter director。
- 長路線的 enemy spawn 以 Player 為錨點並限制在 route bounds，engagement
  distance 以最近存活 enemy 計算，不以 director 原點計算。
- 端點附近若單側沒有至少 340px 淨空，spawn 必須改用另一側，不得 clamp 到 Player
  身上。`GeneratedRoute.route_seed` 可供 remote inspector 取得以重現地圖。
- 程序平台段與 flat breathing-room chunk 必須交錯；Player 按 ↓ 時只可穿越
  `one_way_collision` 平台，不得穿越 continuous floor。
- director runtime-spawn enemy/guardian/experience gem。
- `SurvivalWaveDirector` 是 180 秒倒數、連續 density curve、定時 Elite／Boss 與
  Final Rush 的唯一 authority；只有 00:00 completion Guardian 可完成 Run。
- `Enemies`、`EncounterDirectors` groups用於 target與wiring。
- card effect透過 capability methods，例如 `take_hit()`、`add_block()`、
  `restore_health()`、`apply_status()`。
- `Game._resolve_combat_vfx_profile()` 是卡牌 tags、Combo elements 與 VFX 的單一
  mapping authority。`CardEffectRunner` 仍是傷害／狀態 authority。
- `ElementTaxonomy` 是正式元素 ID 的單一權威：
  `water/fire/wind/lightning/ice/poison/light/dark/normal`。舊
  flame／earth／storm／frost／venom／neutral 等名稱只可在輸入邊界正規化，
  不得成為新的 catalog identity。
- 五個 Combo Finisher 與四個已學觸發技由
  `NamedSkillVFXCatalog` 保留精確名稱身份。九招各自擁有唯一 `archetype`、
  3–5 個遞增 `beat_pattern`、三級 `evolution_layers`，以及對齊的
  `stack_milestones`／`stack_traits`；不得只替換 motion 名稱後共用同一動畫模板。
  `NamedSkillVFX.play(profile_id, direction, intensity, preview, evolution_level,
  buff_stacks)` 將等級限制在 1–3，並依非負疊層里程碑增加 accent parts。
  元素 mutation 只能疊加，不得把原始金屬、雷牢、天輪、冰棺、節拍或戰術剪影
  替換成泛用火焰。
- 手動施放顯示中央招式名稱並短暫慢動作；普通自動攻擊不反覆觸發標題。火／冰
  projectile 使用 `ElementalAttackAura`，範圍技使用自動清理的 Fire／Ice VFX。
  大招本體與 `ElementalGroundTrail` 都使用 unscaled timeline：火系生成兩道掃掠
  焦痕、冰系生成一條主裂隙與兩條分岔、毒系保留不規則毒灘 profile。玩法傷害仍
  即時結算；致死敵人的碰撞與獎勵也立即結算，但 sprite 會保留到對應招式 impact
  delay 後才元素化消散，避免慢動作期間在視覺命中前先消失。
- Enemy archetype是 runtime-created `Resource`，不是 `.tres` catalog。

### 9.2 NPC — Current

- 通用 NPC/Merchant scene可使用 `StaticBody2D` + `Interactives` group。
- Town NPC由 `scenes/maps/town/components/TownNPCs.tscn` 組合，且是
  display-only；Town 互動由 `TownBuildingEntrances` 負責。
- 沒有 NPC navigation、schedule、AI movement或persistent NPC state。
- Merchant只發 intent signal；stock/economy由 `Game` 管理。

### 9.3 Dialogue — Partial

Current：

- `dialogue_id`從 NPC signal傳給 `Game`。
- `DialogueUI`支援 speaker、text、choices與 typed signals。
- 少量台詞在 `Game._dialogue_text_for()` hard-code。

TODO：

- dialogue data catalog/Resource
- conversation graph與conditions/effects
- localization keys
- voice/audio integration
- dialogue progress save
- Quest gating

不得宣稱存在 `DialogueManager`。

### 9.4 Quest — TODO

Current只有：

- `HUD.set_objective()` 與 `HUDQuestTracker`
- combat/combo/run訊息投影
- Inventory `"quest"` category與 hard-coded `town_map`

不存在 Quest model、QuestManager、quest lifecycle signals、save schema或
NPC condition integration。`HUDQuestTracker`目前是 objective/status display，
不是正式 Quest 系統。

### 9.5 Audio — TODO

Current只有 `PauseMenu`直接操作 Master bus：

- `AudioServer.get_bus_index("Master")`
- `AudioServer.set_bus_volume_db()`

專案沒有 audio files、`AudioStreamPlayer*`、audio manager或 bus layout resource。
`MetaState.settings.master_volume`尚未接線；不得宣稱音量已持久化。

### 9.6 Animation — Partial

Current：

- Player手動切 Sprite2D texture/hframes/frame。
- AutumnSlime手動更新 frame。
- UI與特效使用 Godot 4 Tween。
- Magic book portal在 `_process()` 用 `sin()` 浮動。

不存在 `AnimationPlayer`、`AnimationTree`、`AnimatedSprite2D`或共用 state graph。

## 10. 依賴方向與變更規則

### 10.1 允許方向

```text
Scene/UI input
→ signals
→ Game orchestrator
→ system/domain API
→ state mutation
→ projection back to Scene/UI
```

- system scripts不得依賴 UI Scene。
- UI不得直接改 static catalog。
- map content不得自行建立第二個 global HUD/save manager。
- lower-level scene不得假定 `/root/Game` absolute NodePath。
-跨邊界 Dictionary使用 validation與 `duplicate(true)`。

### 10.2 架構變更同步

| 變更 | 同步項目 |
|---|---|
| Main scene / Autoload | 02、03、05、09、tests |
| Map path / root / ownership | 02、03、09、Portal/save tests |
| JSON/schema | 02、06、09、migration/content tests |
| Public class/signal | 02、03或06、callers、contract tests |
| UI ownership | 02、03、04、08、layout tests |
| Save payload | 02、06、09、old payload fixture |

## 11. 架構風險

| Severity | Risk | Evidence | Required control |
|---|---|---|---|
| High | Game monolith | `game.gd`約2,108行，仍涵蓋多domain；map path registry已抽離 | 新規則優先放可測system；改動跑跨系統tests |
| High | Inventory多份真相 | manager/meta/prototype dictionaries | 明確同步點與一致性assertion |
| High | Save雙管線 | SaveService vs Game quick save | 分開文件、fixtures與migration |
| High | Map雙路徑 | canonical vs authoritative | registry test、save compatibility |
| Medium | Dynamic string API | `call/get/find_child/signal name` | path/API contract tests |
| Medium | HUD adoption identity | reparent exact instance | identity/layout snapshot tests |
| Medium | Dialogue/Quest命名誤導 | UI存在但domain不完整 | TODO標記、禁止虛構manager |
| Medium | Input overlap | A movement/card group | run-level input validation |
| Medium | UI/domain混合 | 三個專用功能建築 UI 直接 mutate services | 保持 domain API 邊界，未來抽 coordinator/presenter |

## 12. Code Examples

### 12.1 Current map path resolution

來源：`scripts/systems/map_registry.gd` 與 `scripts/managers/game.gd`

```gdscript
func resolve(scene_path: String) -> String:
	return String(CANONICAL_TO_AUTHORITATIVE.get(canonical(scene_path), scene_path))

func _resolve_main_scene_path(scene_path: String) -> String:
	return map_registry.resolve(scene_path)
```

### 12.2 Signal-first boundary

來源：`scripts/interaction/portal.gd`

```gdscript
signal portal_entered(
	portal: Node,
	target_scene_path: String,
	target_spawn_name: StringName,
	interactor: Node
)

func interact(interactor: Node = null) -> bool:
	if locked:
		locked_interaction.emit(locked_reason)
		return false
	if not super.interact(interactor):
		return false
	portal_entered.emit(self, target_scene_path, target_spawn_name, interactor)
	return true
```

### 12.3 State projection

來源：`scripts/managers/game.gd`

```gdscript
func _sync_progression_to_meta() -> void:
	wallet_gold = int(inventory_manager.call("get_resource_amount", &"gold"))
	meta_state.inventory_state = inventory_manager.call("to_dict") as Dictionary
	meta_state.town_state = town_manager.call("to_dict") as Dictionary
```

## 13. Scene Tree Example

```text
Game
├── MapRoot
│   └── AuthoritativeMap
│       ├── PlayerSpawn
│       ├── Player
│       ├── WorldCollision
│       ├── Interactives
│       └── EncounterDirector
├── HUDLayer
│   └── HUD
│       └── AutumnCardHandUI（Autumn only）
├── MenuLayer
│   └── [runtime modal UI]
└── CardEffectRunner
```

此 tree表示 runtime ownership；authoritative map在 editor中還含
`EditorHUDReference`，其 HUD children會在 runtime被adopt到 `HUDLayer`。

## 14. Godot Example (Godot 4)

以下示範在目前架構內安全連接 optional signal，不引入 Autoload：

```gdscript
func _connect_if_present(
	source: Node,
	signal_name: StringName,
	callback: Callable
) -> void:
	if not source.has_signal(signal_name):
		return
	if source.is_connected(signal_name, callback):
		return
	source.connect(signal_name, callback)
```

Godot 4 使用 `Signal.connect()`／`Object.connect()`與 `Callable`。不得引用 Godot 3
的字串 method target signature。

## 15. Best Practice

- 以 `Game`作composition root，但將純規則留在小型 `RefCounted` system。
- 使用typed signal表達下層intent，上層決定流程。
- canonical map path與authoritative path同時文件化。
- 將static catalog、runtime state、save DTO、UI projection分開。
- 使用Scene/group/API contract tests保護dynamic wiring。
- save schema變更保留old payload fixture與migration證據。
- 未存在系統明確標 `TODO`。

## 16. Anti Pattern

- 為方便存取直接新增未治理的 Autoload。
- 讓 Portal直接 `change_scene_to_file(canonical_path)`繞過registry。
- 重新instantiate HUD而遺失map-authored override。
- 讓 UI直接修改card catalog或敵人。
- 同一交易只更新wallet或只更新InventoryManager。
- 把quick save描述成完整run snapshot。
- 看到 `HUDQuestTracker`就聲稱已存在Quest system。
- 繼續把新domain規則塞入`game.gd`。

## 17. Architecture Checklist

開始架構相關修改前：

- [ ] 已確認 `project.godot` main scene與Autoload現況。
- [ ] 已找出current owner、caller、signal與cleanup。
- [ ] 已區分canonical/authoritative map path。
- [ ] 已區分static catalog、runtime、meta、run、save、UI projection。
- [ ] 已列出所有被修改的public API與tests。
- [ ] 已辨識Inventory/Save重疊風險。
- [ ] 不存在能力已標 `TODO`，未自行設計玩法。

## 18. Review Checklist

- [ ] Main scene仍為`res://scenes/game/game.tscn`，或已同步全部治理與測試。
- [ ] 沒有未文件化Autoload/global state。
- [ ] Map load保留Player transfer、spawn、camera、HUD adoption。
- [ ] Signal參數與producer/consumer一致。
- [ ] UI只投影與emit intent，沒有新增domain規則。
- [ ] MetaState/RunState lifetime沒有混淆。
- [ ] Save payload/schema/backup/migration有實際測試。
- [ ] Inventory各份狀態在所有mutation path同步。
- [ ] dynamic Node/Signal reference處理null、duplicate connection與cleanup。
- [ ] code、Scene、data、test、docs同步。

## 19. Future Extension

以下均為 Proposed，尚未實作：

1. 分階段抽出Save、Shop、Run Combat、UI Stack coordinator，縮小`Game`。
2. 統一InventoryManager與prototype inventory，建立single source of truth。
3. 將meta/quick save整合到有migration registry的persistence service。
4. 為成熟catalog評估typed Resource；先決定JSON migration與authoring流程。
5. 建立正式Quest、data-driven Dialogue與Audio架構。
6. 建立input context，消除movement/card/UI action衝突。
7. 用ADR記錄Autoload、Resource與save架構決策。

## 20. Related Documents

- `docs/README.md`
- `docs/01_AI_GUIDE.md`
- `docs/03_SCENE_STRUCTURE.md`
- `docs/04_UI_GUIDE.md`
- `docs/05_CODING_STANDARD.md`
- `docs/06_RESOURCE_GUIDE.md`
- `docs/09_TESTING_GUIDE.md`
- `docs/10_DEBUG_GUIDE.md`
- `docs/12_GAME_DESIGN.md`
- `docs/13_ROADMAP.md`
- `docs/rule_1.md`

## 21. Card、Skill、Growth 與 Autumn HUD 契約（2026-07-26）

本節取代本文較早的 Autumn「HUD 與 CardHand 並列」、Defense 卡牌及被動
evolution 描述。`Game` 仍是 composition root，持有 queue、UI、pause 與 save
transaction；跨 MetaState／RunState／DeckManager 的 collection mutation 則集中於
`CardCollectionService`，不得在 UI 或其他 caller 複製三份寫入邏輯。

### 21.1 Instance、牌堆與存檔邊界

`CardInstance` 是 runtime 與持久化卡牌 identity：

```text
CardInstance
├── instance_id: String
├── card_id: String
└── level: int（1..3）
```

`DeckManager.start_fixed_hand()` 建立本次 Run 唯一的一組四張技能：
剛好一張 Healing 與三張不重複 Combo。固定手牌只受 AP 限制；使用後留在原 slot，
不進 draw／discard／exhaust／cooldown，也不提供 redraw 或輪抽。
傳送門前的 `DeckBuilderUI` 直接投影四個固定槽位：slot 0 只接受 Healing，
slot 1–3 只接受不重複 Combo。選取槽位後，候選清單只顯示相同類型；畫面同步列出
目前三張 Combo 已學會且可完成的 named Finisher recipes。確認順序就是戰鬥
Q／W／E／R 的固定順序。
`ember_bolt` 僅作為獨立 Basic Attack，不進入手牌、棄牌或 Combo 抽牌循環。`quickstep`
已從正式卡表移除。玩家固有 Dash 由 `PlayerController` 的 Space action 擁有，
不是 `CardInstance`，不進 deck/hand/piles、不花 AP，也不觸發出牌事件。

戰前另由 `DeckBuilderUI` 從已解鎖 attack cards 選一個 Basic Attack。選擇保存於
`MetaState.auto_attack_card_id`，Run 開始時複製到 run-local lock；戰鬥中不可切換。
Basic Attack 不建立額外 CardInstance、不進 hand 或任一牌堆、不花 AP，也不送入
`SkillRecipeManager.record_card()`。有效敵人進入角色面向的水平走廊時自動施放；
沒有合法目標時不消耗 cooldown、Combo 公式或終結技。

只有 Combo 技能會記入三格公式並永久增加對應 Combo stack；Healing 不記入也不
中斷公式。`ComboFinisherCatalog` 以 `data/combo_finishers.json` 驗證精確且已學會
的三招配方，支援 AAA 重複招式與有順序的 ABC 複合招式。未學會配方所需的任一
Combo 技能時不能形成終結技。完成的終結技進入 FIFO queue，下一發自動 Basic
Attack 逐一施放；效果為「配方終結技基底＋該三招組合＋所有 Divine Gift 效果」。
施放後只消耗 queue 的第一招，不消耗永久 Combo stacks。

Combo 卡本身提供的 infusion／status 不屬於永久公式狀態：每張卡各自持有 1.5 秒
基礎倒數，時間到只移除該張卡的 runtime modifier，並由剩餘效果重建攻擊 profile。
因此尺寸、速度、射程與元素等重疊效果可在不同時間獨立恢復。技能觸發用 Combo
Chain 仍使用獨立的 2.5 秒視窗，不受卡片效果到期影響。

`DivineGiftManager` 是 Run-local 神賜權威。每個 stage/wave 最多排入一個必選
神賜頁，避免同關多隻菁英重複開頁。神賜最高三級；最新選取的神賜提供招式稱號，
例如 `千刃殺` 變成 `絕對零度的千刃殺`，所有持有神賜則共同加入燃燒、冰凍碎裂、
中毒、雷鏈、迴響或穿透等機制。兩個不同的滿級神賜可融合成 evolved gift；材料
標記為 ascended 並永久離開本 Run 的獎勵池，已完成的融合不能再次產生。只有融合
候選的頁面可略過，避免成長流程無限循環。

Dash Edge 與 Gale Drive 保留為 legacy catalog cards，但標記 `combat_hand = false`，
不進 Deck Builder、預設背包或戰鬥獎勵；其 infusion 仍以
`target_action = "dash"` 暫時投影到玩家固有 Dash，不建立或尋找 Dash 卡。

`MetaState` schema version 5 以 `selected_card_instances` 儲存 instance payload，
同時保留必要的舊 `selected_deck` projection 作 compatibility。舊 card-id 陣列 migration
必須 deterministic、idempotent，修復非法 level 與重複/缺失 instance ID，並提供
migration report。schema 6 另保存 `auto_attack_card_id`、`learned_skill_ids` 與
`active_skill_ids`；auto attack 缺失或無效時 fallback 到已解鎖的有效 attack，
active skill 必須是 learned 的子集。`RunState.card_instances` 是 expedition
期間的同一 identity projection，不另造 card-id 等級表。

### 21.2 Combat 與 skill services

- `CombatStatusController` 是 timed combat status authority。同 source 重放刷新；
  super armor 取最高 tier；damage reduction 合計上限 60%；unblockable damage
  必須繞過 reduction。它也負責 regeneration、lifesteal、retaliation 與 pause。
- 卡牌 taxonomy 不再有 `defense`。原防禦牌是 `combo`，治療牌是綠色
  `healing`，效果分為 immediate restore、regeneration、lifesteal 等明確語意。
- `SkillRecipeManager` 只接收成功且正傷害的 attack card event。count 與 exact
  sequence 都有 8 秒 window；non-attack 不推進，exact sequence 的錯誤 attack
  會重設並允許從第一步重新開始。各 active skill 可同時判定並有獨立 cooldown。
- 已學會 skill 永久保存；active loadout 受 Memory Library capacity
  10/14/18/24/30 限制。初始 `Iron Momentum` 使用 1 memory：五次 attack 觸發
  三秒弱霸體，十秒 cooldown。

### 21.3 成長與 UI ownership

`GrowthChoiceQueue` 將 Elite Divine Gift 與其他 growth event 排成單一 FIFO。
每次 Elite defeat 使用遞增 event key，只能 enqueue 一頁 mandatory Divine Gift；
EXP 優先隨機抽最多五張未滿級 instance 形成 upgrade page，全部滿級後
才提供獨立 fusion page。fusion 消耗兩張材料並加入一張 Lv.1 結果，牌組淨減一。
wave reward page 可由玩家直接 Skip 以維持精簡牌組；選牌後若遇到 16 張上限，
由 `Game` 開啟 replacement modal，原子執行 remove-one/add-one，或再次 Skip。
若沒有合法 upgrade/fusion，
才提供 75 gold、12 wood + 8 stone、或 4 magic shards 的永久 fallback。

`Game` resolve choice、處理單張 upgrade／fallback、同步 Meta DTO 並提交 save。
`CardCollectionService` 驗證共享 CardInstance identity 與 fusion recipe，原子執行
new-card／fusion／exact removal，並提供 collection snapshot／restore 給 save
failure rollback。它不擁有 AP、出牌、cooldown tick 或 UI。

`CardGrowthUI` 只 projection queue page 並 emit choice intent。modal 開啟期間，
`Game` 必須以成對 pause token 暫停 gameplay、AP、status/skill
timers、wave 與 projectile；UI 使用 always process。close/teardown 必須釋放 token。

Autumn 的唯一 combat presentation root 是
`res://scenes/ui/autumn/AutumnHUD.tscn`。它內嵌 card hand，語意樹如下：

```text
AutumnHUD
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

Town HUD 不受影響。Autumn skill toast 最多三筆、顯示約 1.5 秒後淡出；相同 skill
重複觸發刷新既有 toast。HUD 不顯示常駐 recipe progress。
