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
2. 透過 `SaveService.load_meta()` 讀取正式 `meta_progress.json`；目前預設啟用 dev
   mode 時改讀隔離的 `dev_meta_progress.json`。
3. 將 `MetaState.inventory_state`／legacy fields 套入 Inventory runtime state。
4. 將 `MetaState.town_state`／legacy fields 套入 Town runtime state。
5. 載入卡牌、13×3 技能系列與 Combo recipe catalog；實際的 `SkillRecipeManager`、
   `GrowthChoiceQueue` 與成長 UI caller 由 `Game` 組裝。
6. 若 dev mode 啟用，由 `DevModeService` 一次投影全解鎖與測試資源。
7. 連接 `CardEffectRunner.effect_resolved`。
8. 呼叫 `load_current_map(starting_map)`。
9. 將 runtime progression 同步回 `MetaState`。

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
├── StoryDirector
│   └── DialogueRunner
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
- `StoryDirector` 保留 chapter checkpoint／story flag 的正式流程 API，但目前第一章
  只由 Inventory 圖鑑的「劇情回顧」以 read-only review mode 呼叫；載入 Town 不得
  自動觸發。`DialogueRunner` 只依 catalog 將逐句 speaker、文字與情緒投影到既有
  `DialogueUI`，不建立第二套對話畫面；回顧完成不得 mutation `MetaState`。

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
| `skill_recipe_manager` | `SkillRecipeManager` | 13 系列、39 招、基本／進階／大師階級與系列特效 ID 的唯讀 catalog；舊 recipe runtime 僅保留 caller 相容 |
| `skill_series_vfx_catalog` | `SkillSeriesVFXCatalog` | 13 個系列主物體、系列專屬移動路徑，以及單體→單路徑群→多方向多路徑的三階 formation catalog |
| `growth_choice_queue` | `GrowthChoiceQueue` | wave、EXP Blessing、菁英／Boss loot 的單一 FIFO queue |
| `inventory_manager` | unnamed `RefCounted` script | resources/equipment runtime model |
| `town_manager` | unnamed `RefCounted` script | building levels、data-driven upgrade effects、discounted construction cost、village stage |

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
| `res://scenes/maps/crystal_caves.tscn` | `res://scenes/maps/expedition/CrystalRoute.tscn` | `CrystalRoute` |
| `res://scenes/maps/hell_rift.tscn` | `res://scenes/maps/expedition/HellRoute.tscn` | `HellRoute` |
| `res://scenes/maps/heaven_sanctuary.tscn` | `res://scenes/maps/expedition/HeavenRoute.tscn` | `HeavenRoute` |

正式遠征由 `ExpeditionRegionCatalog` 以四個穩定 portal slot 與九個篇章變體管理。
初期開放 Autumn／Crystal；Hell 篇保留兩者並加入 Hell Autumn／Hell Crystal／Hell；
Heaven 篇再加入 Heaven Autumn／Heaven Crystal／Disorder Hell／Heaven。Autumn 與
Crystal 槽位因此可分別顯示 normal／Hell／Heaven 三個直接選擇按鈕，Hell 槽位可選
Hell／Disorder Hell。變體各自保留 clear count、Boss passage fragments、assembled key、
Boss completion 與 power tier，不共用四次攻略進度。舊
Forbidden Graveyard scene 只保留 compatibility，不再是正式遠征入口。

每次成功通關只替該精確變體增加一片對應碎片；四片會組成該變體的 Boss passage
key。中央 Boss 門可同時持有多把可用鑰匙，並以
`ExpeditionVariantSelectUI.tscn` 的直接按鈕選擇對應 Boss 房。完成一把鑰匙不會阻塞
其他變體繼續累積碎片，Boss 勝利只消耗並完成被選中的那一條 progression。
`Game._finish_run()` 是通關寫入點，Hub 只投影 `MetaState`，不自行修改永久進度。

除既有 `AutumnBattleMapV2` 外，長程地圖共用 editor-authored
`ExpeditionRouteTemplate.tscn` 與 runtime `ThemedExpeditionRoute` 生成的 24 個可替換
route chunks；正式路徑寬度均為 10,560。Boss 使用九個薄 wrapper 指向
`RegionalBossArenaTemplate.tscn`，固定為 1,664 × 900 的封閉垂直平台房。中央 Boss
portal 只在當前變體成功攻略四次後取得 target，玩家互動觸發後才載入房間。
Crystal 系列另由 `crystal_cavern_background.png` 與透明
`crystal_terrain_atlas.png` 組成；長地板、三種平台與水晶簇皆為獨立可替換 visual，
碰撞與深色保底地板仍由 route template 擁有，禁止再引用舊 Craftpix 背景作正式畫面。
Hell Autumn、Heaven Autumn、Hell、Disorder Hell、Heaven 也各自持有透明
`*_terrain_atlas.png`，不得退化為共用 atlas 換色。每套 atlas 具有連續地面、三種
平台、端點／橋與四個環境 accent；route 與同變體 Boss room 必須引用同一套視覺
語彙。所有長路線主地表以 Autumn 的 `y=460` 為構圖基準；Boss 主地表為 `y=500`、
Player spawn 為 `y=470`，上方空間留給七個跳台，避免主角落入卡牌 HUD 後方。

Town canonical content 維持 `1942 × 720` Eternal Forge gameplay world 與
`y=672` baseline。`res://data/town_modular_layout.json` 定義
`1942 × 809` source canvas 上由 layout 列出的可替換物件，
`tools/build_town_modular_scene.py` 將其生成為 editor 與 runtime 共用的
`TownModularVisuals.tscn`；`TownBackdrop/ModularVisuals` 與獨立的
`TownSkyLayer`／`TownCloudLayer` 共同組成目前 presentation authority。核准的 Image #2 保留在 hidden
`TownBackdrop/EternalForgeConcept` 作背景、比例與整體構圖 reference。
`tools/build_town_modular_figma_board.py` 產生單頁 Figma board，並以同一 layout
輸出完整重組預覽與可單獨選取的分件素材庫。
Town 視覺統一採用 `data/town_visual_style.json` 的
`storybook_handdrawn_pixel_v2`：手繪不規則墨線、紙張顆粒、低飽和木石色、
冷苔綠陰影與左上暖蜜色主光。正式排版權威是
`concept/town/main_horizontal_concept/town_style_direction_a_locked.png`。
天空改由 `TownSkyLayer.tscn` 的 cloud-free `town_sky_cloud_free_v1.png` 獨立提供，並以
`set_sky_tint()`／`set_sky_atmosphere()` 提供日照時段調色邊界；Town root 的
`set_time_of_day_progress()` 將 normalized day 映射為時鐘，15:00 漸入、16:00–17:30 維持
golden-hour 峰值、18:00 收在藍色天頂與暖粉橘地平線的 sunset afterglow；此 presentation
只涵蓋夕陽段，不延伸為完整日夜循環。天空 gradient、雲的暖面／冷影、
場景／角色／emissive 分層 tint 與 HUD 下方的 `TownAtmosphere` split-tone grade 由同一 owner
同步；`transition_to_time_of_day_hour()` 提供平滑動態過渡，預設 Town presentation 為 17:00。
`TownAtmosphere` 另以固定左至右、略向下的低角度夕陽光束統一所有 world visuals，並從移動雲物件
取樣三組扁長、破邊的低頻影場，只作用於城鎮表面；shader ray 使用 world offset，Camera 移動只做
1:1 世界換算，不會放大成跟隨玩家的暗球。全域 grade 只做低強度色溫收斂，物件受光改用保黑位的
乘法曝光與亮度材質反應，使石、木、布、樹葉、角色與地面保留原色，同時共享暖亮面／冷背光；
CanvasLayer 10 以上 UI 不受影響。`TownAmbientAnimation` 會接收同一 sunset weight，讓分層秋葉以
獨立 phase 微幅擺動並產生局部暖陽 shimmer，樹幹、樹根與 branch pivot 保持固定。
`TownCloudLayer.tscn` 使用八個可獨立選取的
透明手繪雲物件，以不同水平速度與低幅垂直漂移循環進出地圖。群山則由
`TownModularVisuals/background_mountains` 的透明 `mountain_layer.png` 提供；屋頂後方另疊
`autumn_forest_canopy_base_v2.png` 的繁盛秋林與
`autumn_ancient_tree_base_v2.png` 主樹。前景建築與秋林之間另有 visual-only
`green_ruins_boundary_tower_base_v4.png`、
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
`TownAmbientAnimation.tscn` 以完整古樹作為不位移的穩定基底，另持有八組
枝幹錨定的上冠、外冠與前後景樹冠模組，以及可獨立替換的飄落葉與鳥類
sprite sheets。中央古樹以外的街景秋林另由十組屋頂後方 foliage patches
補足西側、內側與東側可見樹梢；只使用 3 × 2 atlas 中三種輪廓清楚的手繪葉團。
葉團沒有樹幹、枝根或完整樹形，並放在不移動的原始秋林底圖後方。
十個區域都以 `z=-88/-87/-86` 的後、中、前三層實色局部葉團，自固定秋林輪廓
後方僅露出葉梢。三層以尺寸與 sway gain 差異產生深度錯開的微動；固定秋林本身
負責遮住葉團底部，所以不得以透明度掩蓋畫風差異，也不得建立完整小樹或額外樹幹。
前景屋線另有四個方向不同的 house-edge 枝葉錨點；主枝層保持在建築後方
`z=-11`，只讓屋簷、招牌或既有樹幹可遮住的葉梢露出，禁止以水平克隆枝冠
或透明化方式掩蓋浮空根部。
一般狀態下八組中央樹冠以不同週期低幅擺動並穿插稀疏抖葉，覆蓋可見的上冠、
左右外冠、中冠與前後冠。十組街景 foliage patches 以不同週期在隱藏支點上
低幅旋轉；每個 pivot 只形成互相重疊的局部枝端，並由相鄰 pivot 提供相位差。
每個 pivot 的三層葉團再使用不同幅度，
避免動畫層與背景林割裂。原始背景樹、樹幹與整棵樹的位置保持固定，
不使用 UV 水波、整片平移或伸縮。每隔 8–18 秒再由
陣風讓不同相位的樹冠模組明顯受風再回正。二十四個獨立單葉由中央古樹或
house-edge 葉冠出發，單向落到街道、屋頂或建築平台；runtime 統一縮至 authored
scale 的 `0.48`，落地停留後原地淡出，不在半空 loop 或逆向飛。三個米色路緣
另以五片扁平葉組成 `40` 秒淡入、長時間停留、淡出與短暫隱藏的低矮小堆。十六個鳥停棲點分為
十四個屋頂／石座與兩個地面位置，跨西塔、forge、portal 與 clockhouse 分散；
鳥以冷深藍褐側面小剪影等待 `45–72` 秒，預設 scale 為 `0.065`，主要建築停棲點
可由 metadata 提升至 `0.105`；飛離後 `5–8` 秒返回 authored perch。
此 component 只負責 presentation，不建立碰撞、互動、NPC 或玩法 authority。
`TownBuildingAnimation.tscn` 是六棟 Base 建築的唯一局部動畫 authority。
十一組實際可見窗格遮罩保持常亮，只以錯相、低幅的暖色火光變化補足室內生命感；遮罩
必須限制在玻璃內，不得照亮石牆或木框。鐵匠爐使用既有手繪 8 幀火焰與局部
暖光；布料只在固定支點做 1px 整數位移。Town Hall 秒針以整數像素步進，劍魂商
劍徽反光使用手繪逐格透明素材，圖紙商齒輪固定顯示手繪中性幀且不播放旋轉動畫；
兩者不得以向量線條或 runtime 重建取代。此 component 不擁有碰撞、互動或建築
progression。
八塊道路與八塊橋牆組成唯一可見地板。道路視覺面從 `y=660`
開始，與維持在 `y=672` 的角色、建築與互動基準重疊 12 px，避免腳下與地基露出
背景縫隙。建築與道路間另由一張三模組透明 atlas 以五段 source-region crop
組成薄碎石／草街緣；各段高度不超過 `47px`、位於建築基座後方 `z=-11`，入口
保留斷口，禁止重新連成遮住門腳的全寬矮牆。不得再以
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

Autumn 現在拆為 safe zone 與 battle route。Town/hub 的 Autumn portal 直接開啟
Deck Builder；確認 loadout 後建立 Run、載入 `AutumnBattleMapV2`，並由
`AutumnRunDirector` 立即啟動 encounter，不再先停留 `AutumnSafeZoneMap`。安全區仍由
左至右配置 Town return、Player spawn、可重複使用的營火、非阻擋坐姿商人及 battle
portal，完整收在單一 1280px gameplay viewport，並作為戰鬥 route 的撤退／結算目的地。戰鬥 route 為
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
| `SkillRecipeManager` | `scripts/systems/skill_recipe_manager.gd` | `load_catalog`, `get_all_series`, `get_all_skills`, `get_series`, `get_skill`, `get_tier_label`, `get_legacy_vfx_id`；`configure_loadout`／`record_card` 保留 caller 相容，未定義新觸發規則 |
| `SkillSeriesVFXCatalog` | `scripts/systems/skill_series_vfx_catalog.gd` | 驗證 13 個系列唯一主物體、透明素材、路徑參數與 basic／advanced／master 數量及方向成長；legacy recipe ID 只負責導向系列，不再選動畫外觀 |
| `GrowthChoiceQueue` | `scripts/systems/growth_choice_queue.gd` | `enqueue_wave_blessing`, `enqueue_experience_blessings`, `enqueue_combat_blessing_reward`, `peek`, `resolve` |
| `ElementTaxonomy` | `scripts/systems/element_taxonomy.gd` | `get_all`, `normalize`, `is_valid`, `get_color`, `get_effect_profile`, `apply_attack_side_effects`, `get_interaction_multiplier`；武器、神賜、戰鬥效果與 VFX 共用的元素規則權威 |
| `ElementalGroundTrailCatalog` | `scripts/systems/elemental_ground_trail_catalog.gd` | 驗證火／冰／毒地面路徑 profile、四象限 atlas 與 visual budget |
| `SaveService` | `scripts/systems/save_service.gd` | `save_meta`, `load_meta` |

### 5.2 Combat

正式招式的 Combo authority 位於 `SkillRecipeManager`。Combo Chain 只記錄成功施放的
Combo／Healing 劍魂身分，並以目前編成招式的 `combo_routes` 比對歷史尾段：基礎、
進階、大師分別固定為 3、4、6 段。每招可接受正向與反向路線；同一序列會回傳所有
符合招式，同招在一條 Combo Chain 內只觸發一次。`combo_finishers.json` 僅保留既有
效果數值與 VFX 相容資料，不再決定正式招式是否成立。

古木系列是第一個具備獨立玩法 contract 的系列：基礎／進階／大師使用 2／4／6
個古木劍氣門。`skills.json.gameplay_effect` 決定實際 relay 次數、距離、尺寸與傷害增幅；
`skill_series_vfx.json` 的 `sword_aura_gate_network` 僅負責入口、出口、根脈接力與中央
太古神木的排列演出。玩家位置不被自動攻擊改寫。

| Class | Source | Contract |
|---|---|---|
| `CardEffectRunner` | `scripts/combat/card_effect_runner.gd` | `cast()` 修改 caster/targets，emit `effect_resolved`；大招致死前先以 `prepare_hit_presentation()` 傳遞元素與真實 impact delay |
| `AutoAttackFeedback` | `scripts/combat/auto_attack_feedback.gd`、`scripts/combat/premium_crescent_layer.gd` | 以 deterministic 月牙 sheet 加上分層 additive atlas 投影普攻蓄勢、流動劍氣、命中、實際傷害與 Combo power；不處理傷害規則 |
| `SkillCastPresentation` | `scripts/combat/skill_cast_presentation.gd` | 以 unscaled Tween 顯示放大招式名稱並管理短暫施法慢動作 |
| Elemental combat VFX | `scenes/combat/vfx/*.tscn` | 火／冰攻擊纏繞與範圍大招的純 presentation；不擁有傷害判定 |
| `ElementalGroundTrail` | `scenes/combat/vfx/ElementalGroundTrail.tscn`、`data/elemental_ground_trail_profiles.json` | 沿元素大招路徑拼裝 Core／Edge／Accent／Debris atlas 部件與連續 ribbon；火、冰、毒使用不同 topology，不擁有傷害判定 |
| `NamedSkillVFX` | `scenes/combat/vfx/NamedSkillVFX.tscn`、`data/named_skill_vfx_profiles.json`、`data/skill_series_vfx.json` | 舊 profile 仍供退役 trigger／相容 caller 使用；現役 39 招改由 `play_series()` 重用各系列唯一主物體。基本階顯示 1 個，中階將同物體排成 1 條路徑，高階增加數量並分成至少 3 條、3 方向；播放器只處理 presentation，不擁有名稱、配方或傷害判定 |
| `StormChargeVFX` | `scenes/combat/vfx/StormChargeVFX.tscn` | 風暴充能專用的原地五節拍 presentation；固定導電主幹由左右地流依序接入雙腳、持劍手與劍身，接觸時只從劍身下游長出有粗細層級的右向分支，高潮後沿同一路徑回縮；不擁有傷害或 buff 規則 |
| `CombatStatusController` | `scripts/combat/combat_status_controller.gd` | super armor、damage reduction、lifesteal、regeneration、retaliation 與 timer pause |
| `EncounterDirector` | `scripts/combat/encounter_director.gd` | wave plan、engagement/leash、enemy ownership |
| `SurvivalWaveDirector` | `scripts/combat/survival_wave_director.gd` | single countdown、90 秒十秒 super horde、Boss defeat 後 rapid-level horde、scheduled Elite/Boss、Final Rush、XP gem、money/material bags |
| `EvolvedBackgroundAttack` | `scenes/combat/vfx/EvolvedBackgroundAttack.tscn` | 昇華神賜專屬背景自動攻擊；10 個配方各自持有可辨識的具體主體（天輪、斬首冰刃、毒羽、潮槍、雙刀、疫冠、雷槍、戰馬、極光槍、死神）與獨立 motion，來源 geometry motif／三拍聖環只作次要節奏層；Combo、等級與支援神賜增加主體數量、尺寸、速度與殘影；傷害仍由 `Game` 與 `CardEffectRunner` 結算 |
| `EnemyBase` | `scripts/monsters/enemy_base.gd` | archetype、attack、damage、status、reset；大招致死立即結算玩法，再以 unscaled `impact_hold → dissolve → burst` 保留可讀消滅演出 |
| `AutumnGuardian` | `scripts/monsters/autumn_guardian.gd` | boss phases/pattern profiles |
| `AutumnSixArmColossusBoss` | `scripts/monsters/autumn_six_arm_colossus_boss.gd` | Autumn regional boss presentation, six-part armature, vertical jaw weak-point exposure; reuses the Guardian combat API |
| `Hurtbox` | `scripts/combat/hurtbox.gd` | `receive_hit()` adapter |
| `ExperienceGem` | `scripts/combat/experience_gem.gd` | configure/attract/collect |

### 5.3 UI

UI 對上層提供 setter/configure API與 typed signals：

- `HUD`：player/resource/area/objective/prompt projection。
- `CardHandUI`：cards/AP/combo/boss presentation；emit selection。
- `DialogueUI`：speaker/text/choices 與左上角色圖集動畫頭像；
  `present_story_line()` 接收已驗證 line/speaker projection，emit choice/advanced/canceled。
- `ShopUI`：圖示化 catalog projection 與結構化商品列；emit
  mode/quantity/confirmed。圖紙商選到已持有且 Lv.5 覺醒的圖紙時，另顯示 authored
  流派改造區，將 `blueprint_school_change_requested` 交由 Game／ForgeService 驗證。
- `InventoryUI`：以單一古老日記呈現四個章節：背包（素材、關鍵道具、裝備）、
  個人狀態與三個裝備欄位、依 `CardInstance` identity 投影的現有劍魂，以及招式／
  敵人／劍魂／裝備／神賜／劇情回顧圖鑑。神賜分類由 `DivineGiftManager` 投影完整
  catalog，不受當前 Run 持有狀態限制；8 個基礎項使用 `blessing:<gift_id>`，10 個昇華項
  使用 `blessing_evolved:<recipe_id>`，並重用正式普通攻擊／背景攻擊主體素材作靜態預覽。
  招式清單由 `Game` 投影 `skills.json` 的 13 系列、39 招，
  每系列固定基本／進階／大師三階；舊普攻、手牌、被動 trigger 與 Finisher 名稱不再
  混成第二份招式權威。每系列從 `skill_series_vfx.json` 取得一個可重複拼裝的主物體；
  同系列三階只以數量、單一路徑與多方向路徑成長，不另換無關動畫。`legacy_vfx_map`
  只保留配方與舊 caller 導向系列的相容用途；敵人章節
  是 `EnemyArchetype.autumn_catalog()` 的靜態參考，不宣稱 discovery 進度。UI 只透過
  `equip_requested` emit 裝備意圖，由 `Game` 驗證後呼叫 `InventoryManager.equip()`、
  重算玩家屬性並同步 Meta save，不擁有 inventory 或戰鬥規則。
- `MaterialYardUI`：Level 0 basic stock、依 workshop level 解鎖的高階鍛造材料／永久工具，
  以及 Level 3 material bundle yield projection。
- `PlayerBlacksmithUI`：初始以舊工業鐵匠鋪前中後景呈現可互動的熔爐、工作台與商店入口；三個圖像 hotspot 具可見鍵盤焦點，玩家選取物件後才展開圖紙鍛造、每張圖紙 Lv.0–5 熟練度／Lv.5 覺醒、blacksmith
  recipe tier／加工費與 Sword Soul 升級。鍛造
  以穩鍛／精煉／急鍛／名匠鍛造選擇成本、成功率與品質風險；販售以親民／公道／
  精品定價，並投影「流言菲語」指定商品、具名顧客與高價倍率。`PlayerMarketUI`
  是獨立 authored 店內 scene，由鐵匠鋪圖像入口進入、返回時回到工坊場景；
  1040×640 authored frame 以 1280×720 為 1× 基準，依 viewport 在 `0.78–2.0×` 內等比置中，
  並以溫暖木造雜貨／花店前中後景呈現主角、既有 Town NPC 顧客、櫃台與實際陳列商品。
  兩位大型顧客沿門口、展示桌、花架與櫃台路線停留，離店後輪替既有 NPC；初始只顯示店內物件；
  點選商品、貨架或招客鈴後只在 `InteriorCanvas` 左側覆蓋 `ContextDock`，不得改變 `StoreInterior` 尺寸。
  玩家只對空貨架補貨並選擇
  親民／公道／精品價格；顧客由系統週期性自行判斷與結帳。Market 建築等級只解鎖
  可購買的家具階級，實際安裝的木製／雪松／鍛鐵／大市集櫃台才提供 2／3／4／6 格。
  高價接受度由 Market 建築效果及已裝備商旅印章加成，UI 不擁有成交亂數或存檔。
  `PlayerMarketUI/StoreInterior/InteriorCanvas` 使用可獨立替換的 background、midground、
  foreground 三層及六格裝潢 atlas；互動 hotspot 保持透明且不被美術層攔截，貨架、
  櫃台商品、顧客、招客鈴與出入口仍由原按鈕／signal contract 擁有。
- `TownHallUI`：village stage、總建築等級，以及五棟建築的選擇、效果、折扣後成本與升級操作；成功後以 signal 交回 `Game` 立即存檔與刷新 projection。
- `PauseMenu`：emit save/load/settings/exit-combat/quit 等 intent；Game 只在 active
  combat Run 啟用退出戰鬥，接收 intent 後以失敗結算保留已得資源並回 Town。
- `DevModeService`：只由 `development/dev_mode_enabled` 控制目前開發建置；啟用時
  在 catalogs 載入後集中投影全資源、裝備、圖紙、工具、劍魂與招式，並提供正式
  route／Boss map entries。`PauseMenu` 只顯示選項並 emit scene path，實際驗證、
  捨棄測試 Run 與載圖仍由 `Game` 擁有。

Dev mode 使用 `dev_meta_progress.json` 與 `dev_quick_save*`，不覆寫正式
`meta_progress.json`／`quick_save*`。以 `--script res://tests/**` 執行 headless tests
時預設停用，只有 dev mode 專用測試透過測試期 project setting 明確開啟。

三個功能建築 UI 都是 editor-authored Full Rect Scene，由
`Game._open_town_service_ui()` 依 `service_id` 選擇，並透過 `set_context()` 與
`set_services()` 接收既有 Town/Inventory `RefCounted` services。它們目前仍直接
呼叫 domain API 完成建築／裝備升級；材料、圖紙、鍛造與販售 intent 交給
`Game` 透過 `ForgeService` 驗證，成功後立即同步 Meta/save。`Game.close_ui()`
仍負責最終同步與 world visual projection。UI 不應新增 domain 規則，直接 service mutation
仍是 Known Risk；舊的通用 Town progression screen 已退役。

InventoryManager schema 6 以品質堆疊保存素材與裝備，並保存圖紙 craft count、
熟練等級、awakening／school 與含定價、流言顧客 metadata 的 `sale_slots` escrow；
舊 `sale_slot` 載入時遷移到第一格。鍛造必須選普通／稀有／罕見／傳奇素材品質，
只消耗該品質堆疊，並由 ForgeService 將品質直接投影到成功率與成品品質機率；
ForgeService 是工法、素材特性、品質／失敗結果、圖紙流派改造、Market stock gate
與流言成交的唯一規則 owner。RunState 另保留戰鬥素材袋的品質，回城結算後才寫入
InventoryManager；UI／Game 不自行重算品質。

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
→ DeckBuilderUI fixes Healing in slot 1, selects three formula Sword Souls + one auto-attack card
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

- path：正式 `user://saves/meta_progress.json`；dev `user://saves/dev_meta_progress.json`
- schema：`MetaState.SCHEMA_VERSION == 11`
- service：`SaveService`
- behavior：`.tmp` write → parse validation → backup → rename

Quick save：

- path：正式 `user://saves/quick_save.json`；dev `user://saves/dev_quick_save.json`
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
  distance 以最近存活 enemy 計算，不以 director 原點計算；普通怪使用玩家前後
  `680–820px` 的近鏡頭外 perimeter，超過 `1200px` 時回收。
- 端點附近若單側沒有至少 680px 淨空，spawn 必須改用另一側，不得 clamp 到 Player
  身上。`GeneratedRoute.route_seed` 可供 remote inspector 取得以重現地圖。
- 程序平台段與 flat breathing-room chunk 必須交錯；Player 按 ↓ 時只可穿越
  `one_way_collision` 平台，不得穿越 continuous floor。
- director runtime-spawn enemy/guardian/experience gem。
- `SurvivalWaveDirector` 是 360 秒倒數、開場 30 隻、`48→170` 連續 density curve、
  `10→20` spawn batch、每分鐘強敵群、60 秒小 Boss、180 秒第二 Boss、300 秒複數 Boss 與最後 30 秒 Final Rush
  的唯一 authority；普通怪死亡會立即排入補怪，普通怪 HP 倍率沿 timeline 由
  `10.0→26.0`、傷害由 `1.15→2.20`，00:00 直接完成並解鎖出口。
- 經過 90 秒時另由同一 director 啟動約十秒 super horde：cap 最多追加 70、batch
  追加 28、interval 乘 0.18，尾段平滑消退；每次非 completion Boss defeat 啟動
  十二秒 rapid-level horde，cap 追加 85、batch 追加 34、interval 乘 0.15。
- super horde 的普通怪 XP 倍率為 2，Boss 後 rapid-level horde 為 3；總值仍拆成
  單點 `ExperienceGem`。Gem 拋射落地後固定停留 0.65 秒才開始吸取。
- 同一 director 擲骰並生成實體 reward bag：normal／elite／boss 都有各自 money 與
  material chance，material bag 數量為 1／2／3。material payload 由死亡 enemy archetype 映射，
  收集後只以 `reward_bag_collected` 將明確 resource dictionary 交給 `Game`。
- `EnemyBase` 統一處理玩家實體接觸傷害：使用 `Player.take_hit()` 的完整防禦流程、
  每敵獨立冷卻；`ContactDamageArea` 監聽 Player Hurtbox，預警期間若已接觸命中，
  同一 attack generation 的 impact 不再重複扣血。
- `EnemyBase` 的非致命受擊會進入 0.16 秒 knockback state；這段期間 pursuit 不可覆寫
  水平擊退速度，死亡目標不建立這個狀態。
- `Enemies`、`EncounterDirectors` groups用於 target與wiring。
- card effect透過 capability methods，例如 `take_hit()`、`add_block()`、
  `restore_health()`、`apply_status()`。
- `Game._resolve_combat_vfx_profile()` 是卡牌 tags、Combo elements 與 VFX 的單一
  mapping authority。`CardEffectRunner` 仍是傷害／狀態 authority。
- `ElementTaxonomy` 是正式元素 ID 的單一權威：
  `water/fire/wind/lightning/ice/poison/light/dark/normal`。舊
  flame／earth／storm／frost／venom／neutral 等名稱只可在輸入邊界正規化，
  不得成為新的 catalog identity。元素之間沒有相剋、弱點或抗性倍率；九元素各自
  投影一個可疊加的攻擊附加效果，`CardEffectRunner` 統一套用狀態、擊退與命中恢復。
- `NamedSkillVFXCatalog` 將 `combo_finishers.json` 的 32 個正式 Finisher、
  `finisher_vfx_identities.json` 的逐招視覺身份，以及
  `named_skill_vfx_profiles.json` 的五個 Finisher atlas 基底與四個 trigger profile
  合併為 runtime profiles。每個 Finisher 必須保留與 recipe 完全相同的繁中名稱、
  `icon_path`、`role`，並具有獨立 cadence、beat pattern、geometry／particle／light
  identity；共用 atlas row 只代表可重用素材，不得退化為只換色或只換 motion 名稱。
- `NamedSkillVFX` 的 Charge／Attack／Trail／Impact／Debris atlas parts 與 evolution
  icon echoes 只供 trigger 使用；Finisher 播放時全部隱藏。每招先由
  `docs/art_concepts/finisher_choreography/` 的連續動作分鏡定義具體物件、因果、命中
  變形與殘留，再由 `assets/generated/vfx/finisher_parts_v4/` 的 4×3、十二格逐格手繪
  sprite sequence 成為物件 silhouette／連續變形 authority；Runtime 不做相片 cross-fade。
  `<id>_material.png` 只保留為材質設計參考，七個完整 material planes 在 Finisher
  Runtime 必須全部隱藏，避免疊出第二高潮、黑色板塊或改變地面透視。
  `FinisherGeometryCore` 以單格 body、tight glow、wide glow，加上 Source／Contact／
  Residue 三個 bounded `CPUParticles2D` layers，組成六個可見演出層。
  Edge 由材質輪廓取樣產生，只能描繪實際物件，禁止 generic 圓環、刻度、放射網格、
  icon echo 或無來源線條。所有 instance 共用
  `shaders/combat/finisher_semantic_material.gdshader`，每層只保有獨立參數；profile 的
  particle flow 會解析成實際發射方向，light energy／motif 也必須進入 runtime diagnostics
  與材質能量。所有逐格圖共用水平接地基準，整張物件 `rotation = 0`；
  `FinisherSemanticPiece` 會從每列四格的有效亮部下緣解析列基準，將非垂直動作的
  第二、三列對齊第一列，避免 4×3 接觸表換列後整招逐步浮高；`descending`／`rainy`／
  `upward`／`vertical` 保留逐格升降而不套校正。沿地動作只可水平前進，方向性招式
  通過 contact 後仍保留短距離 follow-through，不得在固定進度硬停成隱形牆。遠近只由
  scale、間距、遮擋與 z-order 表示，
  禁止把整條招式傾斜來假造透視。全部 Finisher 統一為純 `CanvasItem` 2.5D：透過明確
  `z_index`、前後層 scale／parallax、材質遮擋、rim light 與 back light 製造空間感；不得引入
  `Node3D`、`Camera3D`、3D mesh 或 SubViewport 離屏合成建立第二套 rendering authority。
  Runtime profile／diagnostic 使用 `presentation_mode = "2_5d"` 鎖定這個邊界。
  v4 逐格物件使用自身水平接地點，會清除 legacy atlas 的負 Y target lift；千羽相應、
  守一共脈與滄海回瀾另以 motion-family playback map 排除素材內畫出的垂直邊界／石牆格，
  但維持十二格 timeline 與原本 radial／grounded／forward identity。已有專屬
  Finisher 動作時，`AutoAttackFeedback` 只保留命中事件與傷害文字，必須隱藏共通劍氣。
  `NamedSkillVFX.play(profile_id, direction, intensity, preview, evolution_level,
  buff_stacks)` 將等級限制在 1–3，並依非負疊層里程碑增加 accent parts。
  元素 mutation 只能疊加，不得把原始金屬、雷牢、天輪、冰棺、節拍或戰術剪影
  替換成泛用火焰。
- 手動施放顯示中央招式名稱並短暫慢動作；普通自動攻擊不反覆觸發標題。火／冰
  projectile 使用 `ElementalAttackAura`，範圍技使用自動清理的 Fire／Ice VFX。
- `storm_charge` 是明確例外：profile 投影 `special_vfx_id = storm_charge`，戰鬥與
  Discovery Codex 都實例化同一個 `StormChargeVFX`，不得退回泛用 attack aura、水平
  projectile 或任意線條動畫。scene 固定在 cast anchor；十一條固定語意導電路徑以
  主幹／次分支三層光階依節拍 reveal/retract，level 只增加有界粒子／光層細節，
  不改變由地面接至劍身的英雄輪廓或生成第二個高潮。
  大招本體與 `ElementalGroundTrail` 都使用 unscaled timeline：火系生成兩道掃掠
  焦痕、冰系生成一條主裂隙與兩條分岔、毒系保留不規則毒灘 profile。玩法傷害仍
  即時結算；致死敵人的碰撞與獎勵也立即結算，但 sprite 會保留到對應招式 impact
  delay 後才元素化消散，避免慢動作期間在視覺命中前先消失。
- Enemy archetype是 runtime-created `Resource`，不是 `.tres` catalog。

### 9.2 NPC — Current

- 通用 NPC/Merchant scene可使用 `StaticBody2D` + `Interactives` group。
- Town NPC由 `scenes/maps/town/components/TownNPCs.tscn` 組合，且是
  display-only；Town 互動由 `TownBuildingEntrances` 負責。
- `TownNPCs.tscn` 現有九個 Town placement：祭司、六位常駐居民，以及由左右城鎮邊界
  進出的 farmer／minstrel 兩位 visitor。六位居民根節點為
  `AnimatableBody2D` + `TownNPCLife`；兩位 visitor 使用相同視覺樹，但由
  `TownVisitorLife` 單獨管理通行生命週期。九位角色各自保有 dedicated scene 與 texture
  identity，不會把 traveler／grocer atlas 當成守衛、旅店主人或 visitor 的替代品。
- 六套居民與兩套 visitor world atlas 都是 `144×152` cell、4 columns × 13 rows；row
  固定為 idle、walk、sit、chat、laugh、happy、sad、surprised、angry、idle_look、
  idle_stretch、greet、work。八位角色的 row 4–8 全部來自各自身份一致的 authored
  laugh／happy／sad／surprised／angry 完整姿勢動作帶，和其他生成 row 一樣統一為
  `132 px` 人物高度與 cell `y=144` 腳底線；runtime 不再對這些情緒 row 額外做逐幀縮放、
  上下 bob 或旋轉來假造動作。居民 sit row 維持 120 px 成人坐姿與清楚椅凳；runtime
  不再引用舊 `town_npcs_atlas_v2.png`。
- 穩定 placement `NPCs/Mayor` 現由祭司角色呈現：`Mayor.tscn` 保留外部 scene/path
  compatibility，但根節點是 `AnimatableBody2D`，由 `PriestTownBehavior` 驅動
  wait-home、walk-to-witch、chat-with-witch、walk-home 循環；`Visual` 使用獨立
  8 columns × 4 rows 完整姿勢祭司 atlas；每個 row 由獨立的 8 幀成人骨架動作帶組成，
  舊版異同比例分件不得再直接組成 runtime 幀。祭司全程與居民共用 `y=672` baseline 與
  `z_index=0`；由 Town Hall 原點直走至女巫左側 `95 px` 的 approach anchor，祭司朝右、
  女巫朝左互相面向聊天，再沿同一 baseline 返回原點正面等待。現行 route offset 為 `0`，
  舊的前景繞行與較高 depth layer 都不是 active contract。女巫的 ambient state 只在
  對話期間暫停並於離開時恢復。
- `TownNPCVisual` 以 5 FPS 離散手繪 cadence 播放上述 13 states，並只負責 atlas row、
  frame 與面向。方向判定會比較移動方向與 atlas 原生方向；女巫 directional rows 原生朝左，
  其餘目前角色原生朝右，因此不得再以全角色共用的 `facing_sign < 0` 判斷翻面。
  `TownNPCLife` 是六位居民的位置／社交 authority：除散步、休息與
  角色化 work／look／stretch 待機外，會從 `TownNPCInteractionCatalog` 查詢角色／archetype
  合法互動，依序執行靠近、greet、chat／work topic、情緒 reaction、farewell，再返回精確
  home anchor。配對全程保留 partner、雙方互相面向並套用 catalog 距離與 cooldown；
  familiar count 只存在本次 session。
- `data/town_npc_interactions.json` 是九種 presentation interaction 的靜態 authority：
  greet、chat、laugh、gossip、comfort、share_goods、discuss_work、watch_sky、farewell。
  `TownNPCInteractionCatalog` 只驗證／查詢 selector、雙方動畫 sequence、duration、social
  distance、cooldown 與 deterministic weight，不擁有移動、配對或 gameplay dialogue。
- `TownVisitorLife` 讓 visitor 在 offscreen wait 後由一側進鎮，走到 authored greeting
  stop，若偏好居民可用便先 greet、短聊，再走到另一側離鎮並等待下一輪；visitor 使用
  `town_visitors` group，不加入 `town_life_npcs`，也不成為居民社交或建築互動 authority。
- `TownNPCLife` 是 session-local presentation simulation，不使用 NavMesh、不進入存檔，
  不新增建築互動或對話權威。祭司與 visitor 需要居民配合時都透過
  `set_external_interaction()` 鎖住居民；lock 會取消既有配對且避免第三人搶走 partner，
  釋放後回到 idle。祭司仍由 `PriestTownBehavior` 單獨控制。
- Merchant只發 intent signal；stock/economy由 `Game` 管理。
- Production Autumn safe-zone 的 `SeatedTrailMerchant` 與 compatibility
  `scenes/npc/Merchant.tscn` 也使用相同 atlas animation hierarchy；前者固定為 sit，
  並保留原有 interaction/shop signal authority。

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
第 1 格固定 Healing，後 3 格是不重複的公式劍魂。固定手牌只受 AP 限制；使用後留在原 slot，
不進 draw／discard／exhaust／cooldown，也不提供 redraw 或輪抽。
傳送門前的 `DeckBuilderUI` 直接投影四個固定槽位；第 1 格只接受 Healing，後 3 格接受
已解鎖且不重複的公式劍魂。招式選擇投影 `SkillRecipeManager` 的 39 個正式名稱，經
`legacy_vfx_id` 找到 `ComboFinisherCatalog.required_skills` 後，以聯集自動填入
後 3 格。四格卡槽下方只有一個 selection workspace，以「劍魂替換／依招式配置」
雙模式切換，兩份長清單不得同時常駐或插在卡槽上方；招式模式依 catalog 順序建立
13 個系列區，每區固定排列基礎／進階／大師三階；仍能與已選招式共存的名稱保持
正常顏色，缺少劍魂或聯集超過三格者反灰。畫面同步列出
目前四張技能可完成的已學會 named Finisher recipes。確認順序就是戰鬥
Q／W／E／R 的固定順序。
`ember_bolt` 僅作為獨立 Basic Attack，不進入手牌、棄牌或 Combo 抽牌循環。`quickstep`
已從正式卡表移除。玩家固有 Dash 由 `PlayerController` 的 Space action 擁有，
不是 `CardInstance`，不進 deck/hand/piles、不花 AP，也不觸發出牌事件。

戰前另由 `DeckBuilderUI` 從已解鎖 attack cards 選一個 Basic Attack。選擇保存於
`MetaState.auto_attack_card_id`，Run 開始時複製到 run-local lock；戰鬥中不可切換。
Basic Attack 不建立額外 CardInstance、不進 hand 或任一牌堆、不花 AP，也不送入
舊 `SkillRecipeManager.record_card()` recipe engine。有效敵人進入角色面向的水平走廊時自動施放；
沒有合法目標時不消耗 cooldown、Combo 公式或終結技。

只有被 `ComboFinisherCatalog` 收錄為配方材料的 Combo／Healing 技能會記入三格公式；
Healing 因此可參與治療、防禦與支援型終結技。catalog 以 `data/combo_finishers.json`
驗證 32 個精確且已學會的三招配方，支援 AAA 重複招式與有順序的 ABC 複合招式，
並可依一至兩格 prefix 提供不保證完成的候選提示。未學會配方所需的任一技能時不能
形成終結技。完成的終結技進入 FIFO queue，下一發自動 Basic Attack 逐一施放；
效果為「配方終結技基底＋該三招的當前等級效果＋裝備 projection＋所有 Divine Gift 效果」。
純治療／防禦／支援配方的基礎傷害為零，仍透過同一次合法自動攻擊觸發其支援效果。
施放後只消耗 queue 的第一招，不消耗永久 Combo stacks。

Combo 卡本身提供的 infusion／status 不屬於永久公式狀態：每張卡各自持有 1.5 秒
基礎倒數，時間到只移除該張卡的 runtime modifier，並由剩餘效果重建攻擊 profile。
因此尺寸、速度、射程與元素等重疊效果可在不同時間獨立恢復。技能觸發用 Combo
Chain 使用依總 Combo 收緊的獨立接續視窗，不受卡片效果到期影響：1–3 層為 2.0 秒，
第 4 層為 1.3 秒，之後每層減少 0.1 秒，最低 0.6 秒；專注護符最後加上 0.5 秒。

`DivineGiftManager` 是 Run-local 神賜權威。每個 EXP level 排入一個新神賜／既有
神賜升級頁；每次菁英與 Boss defeat 則排入一個既有升級／融合 loot page。
神賜最高三級；所有持有神賜依取得順序共同提供招式稱號，
例如 `千刃殺` 可疊加成多段中文前綴名稱，並共同加入燃燒、冰凍碎裂、
中毒、雷鏈、迴響或穿透等機制。兩個不同的滿級神賜可融合成 evolved gift；材料
標記為 ascended 並永久離開本 Run 的獎勵池，已完成的融合不能再次產生。一般 EXP
頁不得出現融合；融合只屬於菁英／Boss loot source。

每項 evolved gift 同時保存一個依兩項材料名稱與特徵組成的 `background_attack` profile。
8 個 base Blessing 各自定義唯一的 `fusion_stem`、`fusion_motif`、`accent_color` 與普攻狀態；第一批只開放
10 個 authored fusion recipe，其中部分還要求已裝備指定觸媒。融合 profile
固定保留兩個來源狀態與發光色，但 runtime 不繪製抽象聖環、節點或幾何線；特殊元素組合改由
fire-blade growth、shadow recall、poison bloom、lightning blink、feather fan、frost rise、tide boomerang、sunfall
及 10 種 evolved subject motion 表達。`Game` 為每個 profile 維持獨立 timer，以 0 AP、不中斷 Basic
Attack cooldown 的方式呼叫 `CardEffectRunner`；建卡時先經
`_apply_combo_infusions_to_card()`，因此目前劍魂與全部持有神賜的傷害、元素、狀態與投射數會同時繼承到
普通攻擊、傷害招式與背景攻擊。背景攻擊 runtime profile 再依 Combo、神賜數與總等級提高
`size_scale`、`instance_count`、`rhythm_speed`、target count 與 damage scale，從單一具體主體成長為多重陣列；
視覺主體同屏最多兩個，單次動作至少 1.25 秒，避免角色、敵人與 contact point 被遮住，傷害與 target 成長不受此視覺上限影響。
每個 base Blessing 另以 `attack_vfx_asset_path` 指向具體小型攻擊物件；
`BlessingAttackOverlay` 將持有神賜投影到普通攻擊路徑，Lv.1 從單一小物件開始，等級、
Combo 與 stack 逐步增加數量、尺寸、分流與殘影。三槽高成長時同屏具體物件總數最多六個、
單體寬度為 84–176px；持有 Blessing 時具體主體直接取代通用劍氣幾何，讓普通攻擊在軌跡、出現方向、
成長、變色與消失方式上產生可見質變。10 個融合 recipe 的
`subject_asset_path`／`subject_motion` 是背景攻擊主體權威，不得退回一張通用幾何素材。

Run 同時最多持有三項神賜。未滿三項時獎勵可出現新神賜或既有神賜升級；滿三項時
只能出現目前持有且未滿級的升級選項，直到兩項滿級神賜融合並釋出空位。加入或升級
任一神賜不得覆蓋其他 slot；效果與中文稱號前綴都依取得順序合併投影，HUD 必須顯示
三個 slot，不能只顯示最後一項或前兩項。
每個 base reward 同時投影所有 authored `fusion_hints`，包含搭配神賜、結果名稱、
目前是否持有搭檔及裝備門檻。只要三選候選池存在能與持有神賜形成指定配方的項目，
`get_reward_choices(3)` 就先保留至少一項這類融合路線，再補其他升級或新神賜。

Dash Edge 與 Gale Drive 保留為 legacy catalog cards，但標記 `combat_hand = false`，
不進 Deck Builder、預設背包或戰鬥獎勵；其 infusion 仍以
`target_action = "dash"` 暫時投影到玩家固有 Dash，不建立或尋找 Dash 卡。

`MetaState` schema version 9 以 `selected_card_instances` 儲存 instance payload，
同時保留必要的舊 `selected_deck` projection 作 compatibility。舊 card-id 陣列 migration
必須 deterministic、idempotent，修復非法 level 與重複/缺失 instance ID，並提供
migration report。schema 6 起另保存 `auto_attack_card_id`、`learned_skill_ids` 與
`active_skill_ids`；schema 8 會移除 `iron_momentum`、`ember_reprise`、
`battle_tempo`、`grand_strategy` 四個退役被動 ID，且不再自動補入舊預設。
schema 9 新增 `story_state`，保存 chapter ID、下一段 sequence checkpoint 與去重後的
stable story flags；schema 8 與更舊存檔一律安全初始化在第一章城鎮廣場。
auto attack 缺失或無效時 fallback 到已解鎖的有效 attack，active skill 必須是 learned
的子集。`RunState.card_instances` 是 expedition
期間的同一 identity projection，不另造 card-id 等級表。

### 21.2 Combat 與 skill services

- `CombatStatusController` 是 timed combat status authority。同 source 重放刷新；
  super armor 取最高 tier；damage reduction 合計上限 60%；unblockable damage
  必須繞過 reduction。它也負責 regeneration、lifesteal、retaliation 與 pause。
- 卡牌 taxonomy 不再有 `defense`。原防禦牌是 `combo`，治療牌是綠色
  `healing`，效果分為 immediate restore、regeneration、lifesteal 等明確語意。
- `SkillRecipeManager` 現在只以 `skills.json` schema 2 載入 13 個系列與 39 招，
  並驗證每系列恰有 basic／advanced／master 三階、中文名稱、定位與動畫節拍。
- 新招式的傷害、AP、解鎖、施放與升級規則尚未核准，composition root 不得從名稱
  猜測。舊 count／sequence trigger engine 已退役；`record_card()` 僅為既有 caller
  保留並回傳空結果。
- `skill_series_vfx.json` 是現役招式 presentation 權威：每系列只有一個透明主物體，
  basic 為單體、advanced 為同物體單一路徑群、master 為更多物體的多方向多路徑群。
  `legacy_vfx_map` 只保留配方與 caller 相容，不再選擇現役招式外觀；
  實戰舊 Finisher recipe ID 必須先由目前配置的正式招式消歧義，才能取得該招自己的
  `series_vfx_id` 與 `tier_rank`；同一舊 recipe 的相容存檔若留下多個正式招式，固定由
  active list 最後一項決定 presentation。
  `named_skill_vfx_profiles.json` 的四個舊 trigger ID 不再是可學技能或分類權威。

### 21.3 成長與 UI ownership

`GrowthChoiceQueue` 將 EXP Blessing、Elite/Boss Blessing loot 與其他 growth event
排成單一 FIFO。每次 EXP level 必須 enqueue 一頁新神賜／既有升級；所有神賜都沒有
可用成長時，才提供 75 gold、12 wood + 8 stone、或 4 magic shards fallback。
每次 Elite/Boss defeat 則只 enqueue 既有神賜升級與合法 Lv.3 神賜融合，不提供新品。
wave reward page 可由玩家直接 Skip 以維持精簡牌組；選牌後若遇到 16 張上限，
由 `Game` 開啟 replacement modal，原子執行 remove-one/add-one，或再次 Skip。

`Game` resolve choice、處理 Divine Gift／fusion／fallback；Divine Gift inventory 保持
Run-local，fallback 仍同步 Meta DTO 並提交 save。
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
├── MapTitleOverlay（換圖時中央短暫顯示地圖名；透明底，只保留上下亮線）
├── TopLeftStack（compatibility path，runtime hidden）
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
重複觸發刷新既有 toast。Combo chain 每次遞增時由 `Game._record_combo_chain()` 依
中文劍魂名稱分開計數，再呼叫 HUD 的 `show_combo_popup(skill_name, count)`；左側以
18–26px 顯示該劍魂與自己的層數，並於 0.95 秒上浮淡出。卡面分類框同步顯示
`目前層數/有效上限`；HUD 不顯示常駐 recipe progress。
