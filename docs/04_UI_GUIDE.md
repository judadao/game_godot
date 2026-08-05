# UI Guide

本文件定義本專案 Godot 4 UI 的 ownership、Scene Tree、排版、互動、響應式與驗證
契約。它同時記錄目前 repository 的真實狀態與後續治理目標。不得以理想架構取代
現況；標為 TODO 的能力尚未實作。

## 目錄

1. [文件目的與狀態詞](#1-文件目的與狀態詞)
2. [目前 UI 架構](#2-目前-ui-架構)
3. [CanvasLayer 與 Control](#3-canvaslayer-與-control)
4. [Container 排版系統](#4-container-排版系統)
5. [Anchor 與 Offset](#5-anchor-與-offset)
6. [Size Flags 與 Minimum Size](#6-size-flags-與-minimum-size)
7. [圖片與 TextureRect](#7-圖片與-texturerect)
8. [Theme 使用規則](#8-theme-使用規則)
9. [Popup、Modal 與 Dialog](#9-popupmodal-與-dialog)
10. [HUD](#10-hud)
11. [CardHand 與 Battle UI](#11-cardhand-與-battle-ui)
12. [Inventory](#12-inventory)
13. [Shop](#13-shop)
14. [Quest UI](#14-quest-ui)
15. [Pause 與 Menu Stack](#15-pause-與-menu-stack)
16. [Responsive Design](#16-responsive-design)
17. [Pixel Perfect](#17-pixel-perfect)
18. [Animation Rules](#18-animation-rules)
19. [Dynamic UI 與生命週期](#19-dynamic-ui-與生命週期)
20. [Long Text 與數值](#20-long-text-與數值)
21. [Localization](#21-localization)
22. [Accessibility 與輸入](#22-accessibility-與輸入)
23. [Code Examples](#23-code-examples)
24. [Scene Tree Examples](#24-scene-tree-examples)
25. [Godot Example (Godot 4)](#25-godot-example-godot-4)
26. [Best Practice](#26-best-practice)
27. [Anti Pattern 與 Common Mistakes](#27-anti-pattern-與-common-mistakes)
28. [Forbidden Practices](#28-forbidden-practices)
29. [Implementation Checklist](#29-implementation-checklist)
30. [UI Review Checklist](#30-ui-review-checklist)
31. [Future Extension](#31-future-extension)
32. [Related Documents](#32-related-documents)

## 1. 文件目的與狀態詞

### 1.1 適用範圍

本文件適用於：

- `scenes/ui/**`
- `scripts/ui/**`
- `scenes/game/game.tscn` 的 `HUDLayer`、`MenuLayer`
- authoritative map 中的 `EditorHUDReference`
- UI 圖片、Theme、Font、StyleBox、LabelSettings
- UI geometry、keyboard/controller focus、Pause 與 modal lifecycle

### 1.2 狀態詞

| 狀態 | 定義 |
|---|---|
| **Current** | 可由目前 Scene、script、setting 或 test 驗證 |
| **Partial** | 有可用實作，但 contract 或覆蓋不完整 |
| **Known Risk** | 現在可能可運作，但已有具體維護或回歸風險 |
| **TODO — Not Implemented** | repository 尚無此能力；本文件只定義未來契約 |
| **Proposed** | 僅供 Future Extension 評估，不代表已核准 |

### 1.3 核心原則

1. UI 必須在 `CanvasLayer`／`Control` 座標系，不得放入世界 `Node2D` 充當 screen。
2. 全螢幕 screen root 使用 Full Rect `Control`。
3. 多元件排列優先用 Container，不用空白字元、索引乘固定高度或大量固定座標。
4. UI 只投影資料、接收操作與 emit intent；戰鬥、經濟、存檔與 AI 規則留在上層。
5. 動態內容必須處理 empty、normal、maximum、long text 與 repeated open/close。
6. UI 修改必須做 headless geometry/behavior 驗證及實際視覺驗收。

## 2. 目前 UI 架構

### 2.1 Composition root

`scenes/game/game.tscn`：

```text
Game (Node, scripts/managers/game.gd)
├── MapRoot (Node)
├── HUDLayer (CanvasLayer, layer = 10)
├── MenuLayer (CanvasLayer, layer = 20)
├── SkillCastPresentation (CanvasLayer, layer = 40)
└── CardEffectRunner (Node)
```

Current ownership：

- `HUDLayer`：持有一個 `HUD` authority；Town 的 `CardHandUI` 是相鄰 root，
  Autumn hand 則內嵌在 AutumnHUD。
- `MenuLayer`：持有 `ui_stack` 中的 Inventory、Pause、Dialogue、Shop、
  MaterialYard、PlayerBlacksmith、TownHall、DeckBuilder、CardDiscard、LevelUp、
  RunResult 等 screen。
- `SkillCastPresentation`：不攔截輸入的全螢幕招式名稱層，以 Container 保持六種
  基準解析度置中。
- `Game.open_ui()`：instantiate、加入 stack、設定 pause flag、連 lifecycle、呼叫
  `open()`、設定 focus。
- `Game.close_ui()`：呼叫 `close()`、移除 stack、更新 pause、emit lifecycle、
  `queue_free()`。

### 2.2 HUD adoption

Authoritative map 透過 map-specific editor reference author HUD。Town 使用
`scenes/maps/town/editor/TownEternalForgeEditorHUDReference.tscn`；其他非 Autumn map
使用 `scenes/ui/hud/editor/SharedEditorHUDReference.tscn`：

```text
EditorHUDReference (CanvasLayer, editor-visible authoring layer)
├── ViewportBoundary
├── CardStageGuide
├── HUD
└── CardHandUI（Town only；runtime sibling authority）
```

Runtime 時 `Game.load_hud()` 將 exact HUD instance `reparent()` 到
`Game/HUDLayer`；Town 同時 adopt sibling hand，Autumn hand 則隨 HUD 移動且不另成
第二個 root。原 reference layer
仍進入 runtime tree，但由
`editor_hud_reference.gd` 隱藏。不得在 `_ready()` 重設 root anchor、offset、
position 或 scale，否則會破壞 map-authored override。

### 2.3 現況數量

- `scenes/ui/**`：33 個 `.tscn`
- `scripts/ui/**`：19 個 `.gd`
- `scripts/ui/` mirrors `scenes/ui/` feature ownership (`autumn/`, `cards/`,
  `dialogue/`, `hud/`, `inventory/`, `results/`, `shop/`, `system/`, `town/`)
- `scenes/ui/` root scene：0 個；screen 全部位於 feature folders
- authored UI `ScrollContainer`：5 個
- runtime-created `ScrollContainer`：DeckBuilder 1 個

## 3. CanvasLayer 與 Control

### 3.1 CanvasLayer

`CanvasLayer` 決定 UI 與世界、不同 UI 平面的繪製層級。本專案的 application layer
由 `Game` 統一建立，reusable UI scene 不應自行新增另一個 root CanvasLayer。

規則：

- HUD 顯示放 `HUDLayer`。
- modal/menu screen 放 `MenuLayer`。
- editor preview 的 `EditorHUDReference` 只在 editor hint 顯示。
- 新 CanvasLayer 必須有明確 ownership、layer 值、Pause 與 cleanup contract。
- 不用 CanvasLayer 修補錯誤 z-index；先找出實際 ownership 與 sibling order。

### 3.2 Control

全螢幕 screen root：

```gdscript
extends Control

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
```

但 HUD 有 map-authored root override，因此它的 `_ready()` 不得重套 Full Rect。
AutumnCardHandUI 的 geometry 由 AutumnHUD 內的 `CardStage` container 擁有。

### 3.3 Mouse filter

- 純顯示 HUD：`MOUSE_FILTER_IGNORE`，避免擋住世界輸入。
- modal backdrop：`MOUSE_FILTER_STOP`，阻止 click-through。
- 實際 Button/slot：`MOUSE_FILTER_STOP` 並設定 focus。
- 不可只把 parent 設 ignore 就假設所有 child 行為正確；逐層檢查。

## 4. Container 排版系統

### 4.1 Container 共通規則

Container 擁有 child 的 position/size。child 在 Container 中時：

- 不手動設定 `position`。
- 以 size flags、minimum size、alignment、theme separation 控制。
- 動態 child 一律 `add_child()` 到對應 Container。
- list 超出可視範圍時由 ScrollContainer 管理。

### 4.2 MarginContainer

用途：screen safe margin、panel content padding、統一外框留白。

Current：

- CardHand 的 `BottomMargin`
- Inventory 的 `MainMargin`
- Shop 的 `WindowMargin`

規則：

- margin 值優先來自 Theme constant。
- 不用空 Control 或空白 Label 製造 padding。
- 四邊不同值必須有視覺理由。

### 4.3 VBoxContainer

用途：垂直 stack、menu buttons、detail fields、list rows。

Current：

- Pause button stack
- Dialogue choices
- HUD progress/quest rows
- runtime DeckBuilder list
- MaterialYard、PlayerBlacksmith、TownHall 的 authored workspace/list containers

規則：

- 長列表外層加 ScrollContainer。
- 可變高文字使用 autowrap，避免固定 row height 截斷。
- footer 若需固定在底部，讓中間內容 `SIZE_EXPAND_FILL`，不要用 spacer offset。

### 4.4 HBoxContainer

用途：header/action bar、欄位列、左右內容區、數值控制。

Current：

- CardHand bottom row
- Inventory content row
- Shop mode/content/action rows
- HUD gold/EXP rows

規則：

- 需要佔用剩餘空間的 child 設 horizontal Expand + Fill。
- 固定 icon/button 不要錯誤 Expand。
- 不用大量空白拼 name/stock/price；建立獨立欄位 child。

### 4.5 GridContainer

用途：固定欄數選項；Inventory 已改用可捲動 `ItemList`，不再使用固定 slot grid。

規則：

- columns 是 responsive 決策，不是隨意常數。
- 大量/可變 slot 必須配 ScrollContainer 或 pagination。
- keyboard navigation 必須使用同一 columns 值，不重複 hard-code。
- empty slot 仍須可辨識、可聚焦或明確不可聚焦。

### 4.6 ScrollContainer

用途：任何可能超過 viewport 或設計容量的內容。

Current：

- `deck_builder_ui.gd` runtime card list。

Known Risk：

- Inventory、Dialogue choices、CardDiscard、RunResult 沒有 scroll policy。

規則：

- ScrollContainer child 通常設定 horizontal Expand + Fill。
- 確認 wheel、keyboard、controller 與 scrollbar 可操作。
- focus 移動到不可見 child 時必須自動 scroll into view。
- nested scroll 需要明確 input ownership。

### 4.7 PanelContainer

用途：將 panel StyleBox 的 content margin 與 content layout 合併。

規則：

- visual panel 優先 `PanelContainer`，不要用 `Panel` 後再手算 content offsets。
- panel padding 應由 StyleBox content margin 或 MarginContainer 提供。
- modal panel 不得靠巨大 minimum size 強撐版面。

### 4.8 CenterContainer

用途：置中 modal、icon、loading/empty state。

Current：

- Shop window
- CardHand boss/group badge

規則：

- 置中優先用 CenterContainer，不用每次手算負半寬/半高。
- centered child 仍須限制 max/min size，窄畫面不得超出 parent。

### 4.9 AspectRatioContainer

**TODO — Not Implemented：**目前 `scenes/ui/**` 沒有 AspectRatioContainer。

未來用途：

- 固定比例 portrait、preview、minimap viewport。
- 需要 keep-aspect 的圖像 content frame。

禁止用它包一般文字或 list；AspectRatioContainer 只處理有真實比例需求的 child。

### 4.10 FlowContainer

**TODO — Not Implemented：**目前 UI 沒有 FlowContainer。

未來適合可換行 chip/tag/技能圖示。若導入：

- 必須驗證窄/寬 viewport 的 wrapping order。
- keyboard traversal 順序需與視覺順序一致。
- 不可用 FlowContainer 取代需要穩定欄位的 GridContainer。

## 5. Anchor 與 Offset

### 5.1 Anchor

Anchor 是相對 parent rect 的比例：

- Full Rect：left/top 0，right/bottom 1。
- bottom HUD：top/bottom anchor 1，offset 向上。
- centered modal：anchor 0.5，或使用 CenterContainer。

Current examples：

- `CardSafeArea`：`anchor_top = 0.75`，固定使用 viewport 底部 25%，容納單組四張 Combo／Healing 卡牌。
- HUD status/quest/progress：bottom corners。
- DialoguePanel：使用 viewport 比例 anchors。

### 5.2 Offset

Offset 是 anchor 解算後的 pixel adjustment。規則：

- 固定 offset 只用於 design margin、標準元件尺寸、HUD edge placement。
- 不用大量 offset 拼出整個 responsive screen。
- 改 anchor 時重新檢查四個 offsets。
- root override 必須在 map adoption 前後保留。

### 5.3 Anchor/offset 檢查順序

1. 確認 parent 是 Control 或 Container。
2. 確認 child 是否受 Container 管理。
3. 確認 anchors preset 與實際 anchor 值一致。
4. 確認 offsets 沒有反向或固定過大。
5. 確認 grow direction。
6. 以窄、基準、寬 viewport 實測。

## 6. Size Flags 與 Minimum Size

### 6.1 Size flags

Godot 4 常用：

- Fill：填滿 Container 分配的空間。
- Expand：參與剩餘空間分配。
- Shrink Begin/Center/End：不要求剩餘空間。

規則：

- 中央內容/list 使用 Expand + Fill。
- icon、固定按鈕、badge 不要錯誤 Expand。
- HBox 中 spacer 可 Expand，但應有具名用途。
- ScrollContainer 唯一 child 通常 horizontal Expand + Fill。

### 6.2 Minimum size

Minimum size 用來保證可讀/可操作，不是畫布尺寸。

Current Known Risks：

- `ShopWindow` minimum 1040×640。
- `PlayerBlacksmithWindow` minimum 1080×650。
- `TownHallWindow` 使用共同 1040×640 frame。
- `MaterialYardWindow` 的 authored wrapper minimum 1024×620。
- Pause Menu minimum 320×590。
- 其餘 script-built modal 仍有固定 660–1040 寬與 460–620 高。

規則：

- minimum size 必須能在 required narrow viewport 內解算。
- 文字可變時以 autowrap/scroll 優先，不無限放大 minimum。
- 按鈕需維持可點擊尺寸，但不以 100% 固定 screen 高度換取。

## 7. 圖片與 TextureRect

每個 TextureRect 必須決定：

- texture filter
- expand mode
- stretch mode
- keep aspect 行為
- minimum size
- clipping

Current assets：

- `assets/ui/basic_rpg_ui/**`
- `assets/ui/fantasy_icons_16x16/**`
- `assets/ui/hud/generated/**`
- `assets/ui/shop/generated/**`

規則：

- pixel icon 使用 nearest，避免任意非整數 scale。
- portrait/preview 通常 keep aspect centered/covered。
- nine-patch frame 優先 `NinePatchRect` 或 StyleBoxTexture，不拉伸角落。
- atlas region 必須明確記錄 source 與 region。
- 圖片不應承載必須 localization 的文字。

## 8. Theme 使用規則

Current：

- 沒有 project-global Theme 或 Font resource。
- `CardGrowthTheme.tres` 與 `TownServiceFrameTheme.tres` 分別提供成長畫面與
  Town 功能建築的小範圍 Theme Variations；其餘 UI 仍有大量 local
  StyleBox/font/color override。
- 詳細現況與未來 token contract 見 `docs/07_THEME_GUIDE.md`。

修改現有 UI 時：

- 優先延續同一 scene 已有 StyleBox，避免再新增近似顏色。
- 不宣稱不存在的 `PrimaryButton` variation 已可用。
- 若任務正式引入 Theme，必須以小範圍 screen migration、before/after test 與
  fallback 計畫進行，不一次改寫所有 UI。

## 9. Popup、Modal 與 Dialog

### 9.1 Current

專案沒有 `Popup`、`PopupPanel`、`PopupMenu`、`Window`、`AcceptDialog`、
`ConfirmationDialog` 或 `FileDialog`。

Current modal 是：

```text
MenuLayer
└── Full Rect Control
    ├── DimBackground
    └── centered/custom Panel
```

`DialogueUI.tscn` 是自製 Full Rect Control + Panel，不是 Godot Dialog。
劇情對話的 `PortraitFrame` 固定在左上、`DialoguePanel` 固定在其下方；頭像以
`TownNPCPortrait.configure_animation_atlas()` 播放既有角色情緒列，不得再用單一
字母或整張角色圖的廉價晃動代替。六個標準解析度都必須驗證頭像在左側、位於對話框
上方，且兩者不超出 viewport。

### 9.2 Modal contract

- 由 `Game.open_ui(name, scene, pause_game)` 開啟。
- 同名 UI 不重複 instance。
- primary UI 開啟時關閉其他 primary UI。
- pause flag 由 caller 決定。
- close/canceled signal 回到 `Game.close_ui()`。
- 開啟後 focus 必須落在有效 control。
- backdrop 擋 click-through。

### 9.3 未來 Popup

若使用 Godot 4 Popup/Window：

- 記錄 transient parent、exclusive、initial position、viewport clamping。
- Popup 不得自行改 `SceneTree.paused`。
- close request 必須回到 owner，不得產生第二套 stack。
- 必須測試窄/寬、全螢幕與多次開關。

## 10. HUD

### 10.1 Shared/Town-compatible tree

```text
HUD
├── HUDStatus
├── HUDProgressPanel
├── HUDQuestTracker
├── HUDHotbar (hidden)
├── hidden legacy status/area/quest nodes
└── InteractionPanel
```

`scripts/ui/hud/hud.gd` 提供：

- `set_health()` / `set_mana()` / `set_stamina()`
- `set_player_level()` / `set_player_class()`
- `set_currency()` / `set_experience()`
- `set_objective()`
- `set_interaction_prompt()` / `clear_interaction_prompt()`

Town 以 `scenes/ui/town/TownEternalForgeHUD.tscn` 重新 author 此 NodePath/API
contract，並由 `scenes/ui/town/TownCardHandUI.tscn` 提供 Eternal Forge theme。
兩者只取代 Town presentation，不修改 shared HUD，也不直接讀寫 town managers。

Town 世界內的八個地點名稱由
`scenes/maps/town/components/TownEternalForgeIdentity.tscn/LocationLabels` author。
六棟建築招牌使用
`assets/town/modular_v2/ui/building_label_plaque.png` 的 B2 手繪像素木牌：
高度不超過 `34px`、字級不超過 `16px`、寬度不超過 `200px`，位置必須高於
建築最高輪廓。它們預設 hidden；`scripts/maps/town_location_labels.gd` 只在
Player 進入對應 `TownBuildingEntrances` 完整地基 Area 時顯示目前建築，離開即
隱藏。非 Player body、NPC 或 UI 開關不得揭露招牌。不滅火炬與戰鬥傳送門是
landmark identity；Image #2 畫風 review 期間不疊加世界常駐標籤，避免遮住
核准構圖。傳送門靠近時仍由 HUD interaction prompt 顯示操作與目的地。

### 10.2 HUD rules

- HUD 保持 display-only，mouse filter ignore。
- 不在 HUD script 計算傷害、EXP、經濟或 quest state。
- bar ratio 接收 current/maximum 後 clamp。
- 大數值用一致 formatter。
- objective 是 status projection，不代表存在 Quest system。
- 同一資訊不得同時在 legacy subtree 與現役 component 顯示。

### 10.3 Current gaps

- `interaction_prompt_accepted` signal 有宣告與 Game connection，但 HUD 不 emit。
- hidden legacy subtree 尚未清理。
- HUDNavigationGroup/HUDStatusBar scene 目前無 production reference。
- HUDStatus/HUDQuestTracker 放在五欄 Container 的縮放 proxy 中，保持模組原始比例。

## 11. CardHand 與 Battle UI

### 11.1 Current

專案沒有獨立 `BattleUI.tscn`。Town 使用 Eternal Forge presentation；Autumn Battle UI 是
單一 HUD root：

```text
HUDLayer
└── AutumnHUD
    ├── TopLeftStack
    ├── TopCenterStack
    └── BottomStage
        └── CardStage
            └── AutumnCardHandUI
```

### 11.2 Card layout exception

`card_hand_ui.gd` 手動排 fan position/rotation/scale，這是明確 HUD overlay 動畫例外。
修改時必須保留：

- 每組最多 4 張 visible cards。
- shared Town compact card minimum 為 `82×78`；Autumn fixed hand 使用
  `148–320px` 的最低高度，實際寬高直接跟隨等分 slot，不鎖定牌面比例。
- bottom safe area 為 viewport 高度的 25%。
- 四張 Combo／Healing 手牌固定放在 `FrontRow` 的四個等寬 `MarginContainer`
  slot 並接收 Q/W/E/R；不使用的 `BackRow` 必須 hidden 且不得保留任何垂直 stretch
  空間，讓 `FrontRow` 從 `CardStage` 頂緣一路填到底緣。寬螢幕不得把四張卡重新聚成中央一團。
- Autumn 每張 card 以覆蓋至少 72% 卡寬、42% 卡高的主插畫作為掃讀焦點；名稱不得
  小於 12px，Healing／Flame／Volley／Storm 以插畫與小面積元素色保留辨識度。
- hover 仍在 viewport 內。
- cards 不遮 HUD status/quest/progress。
- viewport size change 重新 layout。

### 11.3 Battle UI rules

- combat state 由 Game/system 傳入，不由 CardHand 計算。
- selection 透過 `card_selected(index)`。
- boss placeholder editor 可見、runtime 預設隱藏。
- battle camera safe area 與 card stage 變更必須一起驗證。
- 不另外建立第二套 battle HUD。

## 12. Inventory

### 12.1 Current

`InventoryUI.tscn`：

- centered 1020×680 native open-journal frame，整本等比縮放且維持 1.5 aspect
- 背包／狀態／劍魂／圖鑑四個有 icon 與明確 focus state 的章節分頁；第四章的
  玩家可見名稱固定只顯示「圖鑑」，不附加 `CODEX`／`COMPENDIUM`
- 背包依素材／關鍵道具／裝備／補給品篩選；背包與圖鑑分類都使用常駐、可直接點擊的
  editor-authored Button grid，不得退回需要展開才能選擇的 `OptionButton`。裝備詳細頁提供至少 32px 的
  `裝備 · EQUIP` intent button，已裝備項目顯示 disabled `已裝備 · EQUIPPED`
- 狀態頁同時顯示 personal status 與 weapon／armor／accessory 三個權威裝備投影
- 劍魂頁逐一保留 `CardInstance.instance_id` 與獨立 level，不用 card id 合併持有實例；
  左頁使用雙欄劍魂格填滿書脊前的可用空間，右頁只呈現 Game projection 提供的
  `bonus_type_label` 與短中文 `ability_summary`，UI 不自行推算攻擊／防禦／治療／
  元素／機動／AP 類型
- 圖鑑依招式／敵人／劍魂／裝備／劇情回顧篩選；劍魂章列出 `cards.json` 全部 38 個正式劍魂，
  不得只列四個鍛造圖紙，並分別標示解鎖、持有、等級與取得狀態；敵人是 catalog
  reference，不是假造 discovery
- 所有章節內容保留 32px painted page-curl safe inset；圖鑑長內容在固定 detail viewport
  內捲動，viewport 下方另保留 26px 無繪製 footer 與內容 BottomInset，不讓最後一行
  落入書頁捲邊或顯示半行
- 圖鑑招式章左側固定列出 `skills.json` 的 39 招，依 catalog 的 13 個正式系列順序
  分組；每組先顯示不可選取的「系列」標題，再固定排列基本／進階／大師三列。
  系列標題使用不透明深色底條、亮金文字與菱形符號；只設為不可選，不可使用
  disabled 灰化而失去與列表背景的對比。
  UI 必須依 `skill_series_rank`／`tier_rank` 排序，不能依輸入順序或招式名稱碰巧排列。
  列表不再混列目前普攻、四格手牌、舊 passive trigger 或 32 個 Finisher recipe 名稱；
  右側只顯示現役 `LIVE VFX`，退役 concept boards 不得重新進入玩家圖鑑
- 詳情區投影系列、基本／進階／大師階級與正式元素；招式內容固定依「斜體引言
  → 三張劍魂組合」排列。引言直接以書名號和斜體置頂，不另設標題；
  `RichTextLabel` 必須使用高對比深棕色 `default_color`，不可沿用無效的 `font_color`
  而退回白字；
  劍魂組合只顯示配方名稱與順序，持有／未持有／編成狀態只留在劍魂專頁。招式頁不顯示
  系列語彙、特效狀態、效果與數值、逐張劍魂效果或演出流程
- `InventoryCodexPreview` 等待 Container 提供有效尺寸後才生成 production VFX；
  劍氣使用 preview-local 起點／終點，resize 時重建，不能混入 viewport stretch
  座標或逃出 `clip_contents`。Live frame 使用 `190px` 橫向施放舞台，人物縮小並位於
  左側、招式在同一平地向右施放，為下方敘述保留較大空間；命名終結技依
  `380px` authored diameter、完整水平 travel 與 `0.82` ground anchor 自動縮放、
  左移方向性起點並貼齊預覽地面；Codex fit 不受舊 `preview_scale` 的縮小上限限制，
  世界方向位移在圖鑑中最多壓縮為 `220px`（不改戰鬥距離），並在安全範圍內放到最大，
  不能只放大外框後繼續裁掉或縮小招式
- 每招依 `legacy_vfx_map` 投影精確 `named_vfx_id`，暫時重用既有
  `NamedSkillVFX.tscn` profile，並由同 ID 的正式 Combo recipe 提供劍魂順序與 mechanics；
  舊 profile 的 display name／trigger 類型不可改寫新招式名稱、系列、引言或演出內容
- 39 招即使尚未有獨立 icon 也不能從列表消失；空 `icon_path` 使用既有 curated journal
  fallback。未來加入正式圖示時由 catalog path 覆蓋，不在 UI 以名稱硬編 icon
- 劇情回顧由 `StoryDirector.get_review_entries()` 投影章節；選擇一節後以
  `播放本節` 按鈕開啟既有 `DialogueUI`。回顧模式不接入地圖正式流程、不寫 story flag
  或 checkpoint；完成後回到同一圖鑑分類與原選取節點。目前只有第一章 1-1 可播放。
- 劇情對話頭像固定半身裁切，每句 emotion 動作以不高於 3.5 FPS 播放一次並停在末幀，
  不循環成 GIF；沒有 choice 時隱藏整欄並讓本文使用右側空間。

`inventory_ui.gd`：

- 素材與裝備列的 stats 顯示各品質庫存；狀態頁的已裝備名稱顯示實際裝備品質，
  不再只顯示 catalog 基礎品質。

- `set_gold()`、`set_items()`、`set_player_status()`、`set_equipment_entries()`、
  `set_sword_souls()`、`set_codex_entries()`、`set_mode()`
- `equip_requested(item_id)` 只送出使用者意圖；`Game` 是唯一 mutation owner，成功後
  重新注入背包、狀態、裝備與圖鑑 projection
- `set_codex_view_mode()` 僅保留舊 caller 的相容入口，任何傳入模式都固定回到
  production live VFX；concept tab、crop 與舊效果板不可重新顯示
- inventory category 與 codex category 的常駐按鈕都執行實際篩選
- `ItemList` 提供 mouse/keyboard selection

### 12.2 Current gaps

- consumable compatibility state 仍與 InventoryManager 分離。
- 敵人尚無獨立 discovery state，因此圖鑑只能標示為完整 archetype reference catalog。
- storm／venom infusion 已沿用 attack-bound aura contract；它們的獨立 Ultimate
  尚未實作。
- component 子場景無 script/signal，父 controller 依賴 deep NodePath。

### 12.3 Inventory rules

- UI 不直接修改 item catalog。
- 裝備操作只 emit intent，不直接呼叫 InventoryManager 或寫 save。
- category filtering 必須定義 projection index 與 source index mapping。
- empty slot、selected slot、disabled slot、quantity 的 visual state 要分開。
- 超過容量時使用 scroll/pagination，不靜默丟棄。
- detail text autowrap，必要時加 ScrollContainer。

## 13. Shop

### 13.1 Current

`ShopUI.tscn`：

- `ShopWindow.custom_minimum_size = Vector2(1040, 640)`
- 8 個 authored `ShopItemRow.tscn` 作為初始列，較長 catalog 會動態補列
- 商品列位於 `ScrollContainer`，鍵盤 focus 會將選取列捲入可視區
- Buy/Sell、quantity、Confirm/Close 都有圖示、文字與 tooltip
- `set_shop_context()` 讓劍魂商使用 `SWORD SOUL BLUEPRINTS` 建築標題，其餘商店保留
  `TRADE COUNTER`
- 商品列使用 icon、name、stock/owned 與 unit price 的獨立欄位
- detail panel 使用 88px preview、可捲動 RichTextLabel、quantity/total icons
- explicit focus navigation，以及 selected／hover／focus 分離的視覺狀態

`shop_ui.gd` emit `mode_changed`、`confirmed` 等 intent；交易由 Game 處理。

### 13.2 Current gaps

- item list 無 empty state、loading state、error state component。
- 動態列目前沿用 `ShopItemRow.tscn`，尚未加入 virtualized list。

### 13.3 Shop rules

- UI 顯示 quote，不自行扣款或改庫存。
- confirm signal 帶 item、quantity、mode，上層重新驗證。
- rows 使用欄位 Container，不用空白對齊。
- list 必須 scroll，focus 移動時保持 selected row 可見。
- buy/sell mode 切換後重建 projection、價格、庫存與 focus。
- feedback 不能只用顏色，需有文字。

### 13.4 Dedicated Town building screens

`MaterialYardUI`、`PlayerBlacksmithUI`、`TownHallUI` 共用 Shop 的深色鍛造介面語言，
但各自擁有功能專屬資訊架構：

- Material Yard：左側店長肖像，中欄 Materials／Forge Tools offers，右欄商品、
  持有量、Material Yard level、數量與購買。
- Player Blacksmith：進場先顯示幾何熔爐、工作台與商店門，不能把服務功能直接列成選單；
  點選熔爐後才依圖紙鍛造 equipment／Sword Soul，
  Workshop Upgrade 解鎖鍛造上限；recipe detail 顯示該圖紙熟練度、品質機率與
  Lv.5 覺醒狀態。四個 authored 工法按鈕依序顯示 icon／名稱／tooltip，選擇後必須
  在按下 Forge 前更新成本、成功率、品質與素材特性預覽；普通／稀有／罕見／傳奇
  四個 authored 素材品質按鈕必須同步更新精確庫存需求、成功率與成品品質機率。
  點選商店門進入獨立 `PlayerMarketUI` 店內 scene，不能把商店經營塞回鐵匠鋪 detail 欄；
  店內使用置中 1040×640 service frame；上方緊湊狀態列呈現櫃台、陳列商品、主角店主、
  顧客與入口；初始只顯示店內幾何物件，不能直接列出庫存／貨架／流言功能。點商品展示位
  才顯示庫存與對應貨架，點牆面貨架只顯示貨架管理，點招客鈴才顯示流言資訊。顧客使用既有 Town NPC，會自動
  逛店、評估價格與結帳，不提供手動「完成交易」按鈕；拒絕高價時商品仍留在架上等待
  下一位客人。親民價成交率最高但單件收入最低，精品價反之；流言顧客、Market 裝潢
  及商旅印章可提高高價接受度。Market 建築 Lv.0／1／2／3 只決定可購買的櫃台階級，
  購買並安裝家具後才依序取得 2／3／4／6 個實際貨架，低等建築不得購買高階櫃台。
  Market Lv.1 前不投影裝備買家。返回鐵匠鋪時必須保留先前圖紙、工法與素材品質選擇。
- Blueprint Shop：一般購買流程維持 buy-only；只有選到已持有且已覺醒的圖紙才顯示
  流派選擇與 Rework action，費用、流派說明與「熟練度保留」必須可直接讀到。
- 武器裝備列與圖鑑效果摘要必須同時顯示原初屬性及其獨立附加效果；神賜選擇卡的
  類別行使用「屬性 · 效果／用途」，不得顯示或暗示剋制箭頭、弱點倍率或抗性倍率。
- Town Hall：左側村長肖像，中欄保留 Overview／Town Development；右欄以五個 authored
  project button 切換 Town Hall、Blacksmith、Material Yard、Market、Memory Library，
  顯示下一級實際效果與折扣後成本。

三者均使用 Full Rect root、dim backdrop、safe margin、center container、semantic
window 與 authored ScrollContainer；Player Blacksmith 的動態 recipe row 必須只放在
既定 `RecipeList`。開啟後 focus 落在可用 action，`ui_cancel` 關閉並釋放 focus，
重開不得重複 controls 或 signals。

Town Hall、Material Yard、Player Blacksmith、Sword Soul Blueprint Shop 與
Equipment Blueprint Shop 使用同一套功能建築大框架。共同 presentation 由
`TownServiceFrameTheme.tres` 擁有，包括 window、portrait、title 與 Close button
variations；各 screen 不得以 local override 改寫這四個共同部分。

四種 screen 的人物框都 instance `TownNPCPortrait.tscn`。此 component 以同一套
`concept/characters` 透明角色圖呈現固定半身裁切，提供 5 FPS idle／chat／laugh 與
happy／sad／surprised／angry pose cadence；`ShopUI.set_shop_context()` 只切換角色 texture
與 presentation state，不得動態重建 portrait hierarchy。Material Yard 使用雜貨店大叔、
Player Blacksmith 使用瘋狂科學家、Town Hall 使用村長、Sword Soul／Equipment Blueprint
分別使用女巫／瘋狂科學家。

共同 geometry 為 `1040×640` window、`58px` header、header 下方 `10px` 間距、
`218px` 左側人物欄、`218×252` 人物框與 `270px` 中間功能／catalog 欄；欄間距
固定 `12px`，剩餘寬度由右側 detail/action 欄使用。Blueprint Shop 的 buy-only
mode 不顯示額外模式列，Close 固定於右上 header。各 screen 可依功能調整中欄
內容與右側 workspace，但不得另建較小 modal、縮小人物層級或在 header 與三欄
內容之間插入 screen-local toolbar。

## 14. Quest UI

### 14.1 Current

目前只有：

- `HUDQuestTracker.tscn`
- `HUD.set_objective(text, progress)`
- Inventory `"quest"` category

沒有 Quest model、QuestManager、Quest screen、QuestRow、lifecycle signal 或 save schema。

### 14.2 TODO — Not Implemented contract

未來若建立 Quest UI：

- source 必須是正式 quest runtime model，不是 HUD 文字反向解析。
- QuestRow 顯示 title、state、objective、progress。
- active/completed/failed/locked state 有文字與 icon，不只靠顏色。
- list 支援 empty、many、long/localized text。
- tracking intent emit 到 owner，由 owner 更新 model，再投影回 UI。

## 15. Pause 與 Menu Stack

Current `PauseMenu`：

- Continue、Inventory、Save、Load、Exit Combat、DEV 地圖、Settings、Quit
- Master bus volume
- fullscreen toggle
- settings／dev-map／button-stack focus switching

規則：

- `SceneTree.paused` 只由 Game stack 統一更新。
- UI root 用 `PROCESS_MODE_ALWAYS`，paused 時仍可操作。
- nested screen 開關後 focus 回到合理 owner。
- Save/Load feedback顯示在 footer，但不得假裝 save 成功。
- Exit Combat 永遠保留在 ButtonStack；只有 active Run 且位於正式戰鬥地圖時
  可操作，其他地圖使用真正的 `disabled` 狀態反灰。tooltip 必須說明這是放棄戰鬥、
  本局掉落全部失去；觸發後由 Game 以 `abandon` 結算並直接載入 Town，PauseMenu
  不直接存取 RunState。走到地圖實體出口才是保留全部掉落的 `safe_retreat`。
- `DEV 地圖` 只在集中式 dev mode 啟用時顯示。子頁接收 Game 注入的正式 route、
  world variant 與 Boss 房清單，選擇後只 emit `dev_map_requested(scene_path)`；
  Game 捨棄目前測試 Run、不結算攻略進度，再建立必要的測試 Run 與載入 map。
- DEV 子頁為固定三個 controls 的 authored layout；22 筆 map 名稱由 `OptionButton`
  承載，避免把長列表撐高 Pause panel。返回後 focus 回 `DEV 地圖`。
- 音量目前未確認持久化，文件不得聲稱設定會跨啟動保存。

## 16. Responsive Design

### 16.1 必測尺寸

任何 UI 變更至少測：

- 1280×720
- 1600×900
- 1920×1080
- 2560×1440
- 一個較窄視窗
- 一個較寬視窗

建議固定 regression fixtures：

- narrow：1152×720
- wide：2560×1080

wide fixture 是 Proposed test value；實際新增前同步 `docs/09_TESTING_GUIDE.md`。

### 16.2 必測內容

- windowed / fullscreen
- empty data
- normal data
- maximum data
- long English
- Traditional Chinese
- maximum/minimum numeric value
- repeated open/close
- scene change
- Pause
- keyboard/controller focus

### 16.3 Current coverage

generic `tests/ui_layout_guardrails_test.gd` 與 Autumn 專用 geometry tests 合併覆蓋：

- 1152×720
- 1280×720
- 1600×900
- 1920×1080
- 2560×1080
- 2560×1440

這仍不是其他 top-level screens 的 responsive certification；Autumn 改版必須另有
`autumn_hud_v3_*` 與 `card_growth_ui_layout_test.gd` 的完整證據。

## 17. Pixel Perfect

### 17.1 Current

- base viewport 1280×720
- stretch mode `canvas_items`
- 無 project-level nearest/integer scale contract
- UI 只有 3 個節點明確 `texture_filter = 1`
- HUD 有 0.75/0.72 scale

因此目前是 **Partial**，不能宣稱全專案 pixel-perfect。

### 17.2 規則

- 16×16 等 pixel icon 使用 nearest。
- pixel-art 不使用 0.72、0.75 等非整數縮放，除非已核准且有視覺證據。
- frame 若需伸展，使用 NinePatch/StyleBoxTexture，保護 corner。
- position/size 最終落在整數 pixel。
- UI scale、stretch、texture filter 必須一起 review。
- generated painterly/high-resolution UI 可使用 linear，但須明確區分 asset class。

## 18. Animation Rules

### 18.1 Current

- CardHand hover 使用 Tween position/scale/rotation。
- potion feedback 使用 timer 隱藏。
- 專案沒有共用 UI AnimationPlayer 或 motion token。

### 18.2 規則

- 動畫不改變 layout source of truth；Container layout 後動畫 visual property。
- repeated hover/open 必須 kill/replace 舊 Tween。
- screen close 時不得留下 callback 操作 freed node。
- duration/easing 應集中治理，未集中前沿用同 screen 既有值。
- 重要操作不能只靠動畫傳達。
- Pause 下需要繼續的 UI 使用正確 process mode。

### 18.3 Accessibility

**TODO — Not Implemented：**reduced motion setting。導入後至少要能停用大幅位移、
scale pulse、screen shake，不應停用功能狀態更新。

## 19. Dynamic UI 與生命週期

### 19.1 建立

- static layout 優先 author 在 `.tscn`。
- data-dependent rows/cards 可 runtime 建立。
- runtime node 有 descriptive name。
- 建立後連 signal 一次。
- 若 editor 要保存 node，設定正確 `owner`。

### 19.2 更新

- clear 舊內容後再重建。
- `queue_free()` 後不要保留可再次操作的 stale reference。
- dynamic source 先 `duplicate(true)`，避免 UI 修改 caller dictionary。
- 可能 freed 的 UI 用 `is_instance_valid()`。
- 不在 `_process()` 重建 list 或搜尋 group。

### 19.3 關閉

- emit intent/lifecycle 後由 owner 關閉。
- Game stack 是目前唯一 menu ownership。
- repeated close 必須 idempotent。
- close 後更新 pause 與 player input。

## 20. Long Text 與數值

每個動態文字決定：

- `autowrap_mode`
- `text_overrun_behavior`
- clipping
- minimum/maximum width
- tooltip
- alignment
- scroll

規則：

- 不用手動換行或空白對齊欄位。
- RichTextLabel 接收外部字串時確認 BBCode policy。
- item/card description 使用 wrap，不能假定英文短句。
- 數值 formatter 要一致，並測負值、0、大數。
- title 不可因全大寫而失去 localization flexibility。

Current gaps：

- LevelUp fixed buttons 未設定 long-text policy。
- Shop row 使用單字串欄位。
- RunResult dynamic material lines 無 scroll。
- Dialogue dynamic choices 無 scroll。

## 21. Localization

### 21.1 Current

- translation catalog：0
- `TranslationServer`：0
- `tr()`：0
- locale project setting：0
- 可見文字多為 hard-coded English

### 21.2 TODO — Not Implemented contract

導入 localization 時：

- UI 接收 translation key 或已翻譯 presentation text，責任需一致。
- 不以 English text 判斷 action；使用 metadata/action id。
- 數量、日期、貨幣與 key hint 分開格式化。
- Font fallback 必須涵蓋繁體中文。
- 測試 long English、繁中、缺 key、缺 glyph。
- 圖片不得嵌入需翻譯文字。

## 22. Accessibility 與輸入

### 22.1 Current

- Shop 有 explicit focus graph。
- Inventory 處理四方向與 accept。
- Dialogue/Pause 在 open/state switch 時 grab focus。
- Game 對其他 UI 聚焦第一個 enabled Button。
- CardHand 支援 keyboard/controller InputMap actions。

### 22.2 Current gaps

- key hint Q/W/E/R/T/F/Esc/Start hard-code，不反映 remap/device。
- 沒有 UI scale、高對比、color-blind、reduced motion。
- 沒有 screen-reader metadata 或 narration。
- `tests/ui_keyboard_test.gd` 覆蓋目前 keyboard/controller focus baseline。

### 22.3 規則

- 每個可操作 screen 都有 deterministic initial focus。
- 方向 navigation 不進入 hidden/disabled control。
- focus visual 明顯且不只靠顏色。
- 所有 mouse action 有 keyboard/controller 等價路徑。
- feedback 同時使用文字/icon/狀態，不只紅綠色。
- modal 關閉後 focus 回 owner。
- input hint 從 InputMap/device resolver 產生；在 resolver 尚未實作前標為 Current limit。

## 23. Code Examples

### 23.1 安全重建動態列表

```gdscript
func rebuild_rows(items: Array[Dictionary]) -> void:
	for child in rows.get_children():
		child.queue_free()

	for item in items:
		var row := ITEM_ROW_SCENE.instantiate() as Control
		rows.add_child(row)
		row.call("set_data", item.duplicate(true))
```

### 23.2 防止重複 signal

```gdscript
func connect_once(button: Button, callback: Callable) -> void:
	if button.pressed.is_connected(callback):
		return
	button.pressed.connect(callback)
```

### 23.3 Clamp bar

```gdscript
func set_bar(bar: ProgressBar, current: int, maximum: int) -> void:
	var safe_maximum := maxi(1, maximum)
	bar.max_value = safe_maximum
	bar.value = clampi(current, 0, safe_maximum)
```

## 24. Scene Tree Examples

### 24.1 Responsive modal

```text
ScreenRoot (Control, Full Rect)
├── DimBackground (ColorRect, Full Rect)
└── SafeMargin (MarginContainer, Full Rect)
    └── Center (CenterContainer)
        └── Panel (PanelContainer)
            └── Content (VBoxContainer)
                ├── Header (HBoxContainer)
                ├── Scroll (ScrollContainer, Expand + Fill)
                │   └── Rows (VBoxContainer, Expand + Fill)
                └── Actions (HBoxContainer)
```

### 24.2 HUD

```text
HUDLayer (CanvasLayer)
└── AutumnHUD (Control, Full Rect)
    ├── TopLeftStack
    ├── TopCenterStack
    └── BottomStage
        └── CardStage
            ├── ActionSpacer
            └── AutumnCardHandUI
```

## 25. Godot Example (Godot 4)

以下示範不覆寫 map-authored root layout，僅在 viewport change 後更新明確的 local
overlay：

```gdscript
@onready var back_row: HBoxContainer = %BackRow
@onready var front_row: HBoxContainer = %FrontRow

func _ready() -> void:
	var viewport := get_viewport()
	if not viewport.size_changed.is_connected(_on_viewport_size_changed):
		viewport.size_changed.connect(_on_viewport_size_changed)

func _on_viewport_size_changed() -> void:
	if is_inside_tree():
		_capture_resting_layouts.call_deferred()
```

Godot 4 使用 typed signals、`Control.PRESET_*`、`size_flags_*` 與
`TextServer.AUTOWRAP_*`。不得引用 Godot 3 的 API 名稱。

## 26. Best Practice

- application 提供 CanvasLayer，screen 提供 Full Rect Control。
- static structure 放 scene，dynamic data rows 放 Container。
- data change 由 signal/API 投影，不由 UI 直接改 domain state。
- anchor、offset、size flag、minimum size 一起 review。
- list 先定 empty/max/scroll，再做視覺。
- focus、Pause、close 與 cleanup 視為 screen contract。
- 用 geometry test 保護 layout，再用人工視覺確認 texture/filter/contrast。
- Current、Known Risk、TODO 分開文件化。

## 27. Anti Pattern 與 Common Mistakes

- 用 `position = index * row_height` 排動態列表。
- 用大量空白讓 Shop name/price 看似對齊。
- 在 Container child 上手動改 position。
- 設 Full Rect anchors 後保留衝突的大 offsets。
- 所有 child 都設 Expand。
- 以巨大 minimum size 解決 overflow。
- TextureRect 沒有 stretch/filter policy。
- UI `_process()` 每幀 `find_child()`。
- dynamic rebuild 重複 connect。
- 把 HUD objective 誤寫為完整 Quest system。
- 把 DialogueUI 誤寫為 Godot Dialog。
- 把已存在 scene 誤寫為 production-used component。

## 28. Forbidden Practices

- 主要 UI 放在世界 Node2D。
- 另建第二套 HUD/Menu stack。
- UI 直接執行交易、傷害、存檔或 quest rule。
- 覆寫 map-authored HUD root 或把 Autumn hand 拆成第二個 root。
- 用空白或手動換行對齊欄位。
- 超出 viewport 的內容沒有 scroll/clamp。
- 只測 parser 就宣稱 UI 完成。
- 沒有視覺證據就宣稱 pixel-perfect。
- 沒有 catalog/font/fallback 就宣稱已 localization。
- 未更新 04/07/08/09 就改 UI ownership、Theme 或 component contract。

## 29. Implementation Checklist

開始 UI 修改前：

- [ ] 已讀 `docs/rule_1.md`、本文件、Theme、Component、Testing 文件。
- [ ] 已找出 scene、script、caller、signal、owner CanvasLayer。
- [ ] 已記錄 parent、anchor、offset、size flags、minimum size。
- [ ] 已檢查 Theme/StyleBox/Font/texture。
- [ ] 已找出 dynamic build 與 viewport resize code。
- [ ] 已列 empty/normal/max/long-text states。
- [ ] 已確認 keyboard/controller focus。
- [ ] 已列 required resolution 與人工視覺項目。

## 30. UI Review Checklist

- [ ] Root ownership 與 CanvasLayer 正確。
- [ ] Full-screen Control 為 Full Rect。
- [ ] Container child 無不必要手動 position。
- [ ] Anchor/offset/grow direction 一致。
- [ ] Size flags 與 minimum size 有理由。
- [ ] Dynamic list 可 scroll，empty/max 可用。
- [ ] 長英文與繁中不重疊、不裁切。
- [ ] TextureRect filter/stretch/aspect 明確。
- [ ] Mouse 不 click-through；HUD 不擋世界輸入。
- [ ] 初始 focus、方向 focus、關閉後 focus 正確。
- [ ] repeated open/close 無 duplicate node/signal。
- [ ] Pause 與 Player input 恢復。
- [ ] 六種 required resolution 已實測。
- [ ] geometry tests、相關行為 tests 通過。
- [ ] 視覺驗證有截圖或明確人工紀錄。
- [ ] 文件與 component/theme contract 同步。

## 31. Future Extension

以下均為 Proposed，尚未實作：

1. 建立全域 Theme、semantic variations 與 typography/color/spacing tokens。
2. 將 script-built modal 的穩定 layout 搬回 scene，保留 data row runtime build。
3. 為 Inventory/Dialogue/Result 增加 responsive scroll/empty/error states，並為 Shop
   補上 empty/loading/error states。
4. 建立 Input Hint resolver，支援 remap 與 device switching。
5. 建立 UI scale、high contrast、reduced motion。
6. 將 HUD duplicated bars 收斂為 reusable status bar。
7. 將所有 primary screen 納入六尺寸 headless geometry test 與人工 capture。
8. 建立正式 Quest model 後再擴充 Quest screen/rows。

## 32. Related Documents

- `docs/README.md`
- `docs/01_AI_GUIDE.md`
- `docs/02_PROJECT_ARCHITECTURE.md`
- `docs/03_SCENE_STRUCTURE.md`
- `docs/05_CODING_STANDARD.md`
- `docs/06_RESOURCE_GUIDE.md`
- `docs/07_THEME_GUIDE.md`
- `docs/08_COMPONENT_LIBRARY.md`
- `docs/09_TESTING_GUIDE.md`
- `docs/10_DEBUG_GUIDE.md`
- `docs/12_GAME_DESIGN.md`
- `docs/13_ROADMAP.md`
- `docs/rule_1.md`

## 33. Autumn Battle V2 HUD

Autumn Battle V2 不共用 Town presentation。Town HUD 由獨立 Eternal Forge scenes
管理；Autumn runtime 與
editor preview 只採用一個 authority：

- `res://scenes/ui/autumn/AutumnHUD.tscn`
- `res://scenes/ui/autumn/AutumnInteractionPrompt.tscn`
- `res://scenes/maps/autumn_battle/editor/AutumnEditorHUDReference.tscn`

`AutumnHUD.tscn` 內嵌 `AutumnCardHandUI`，不允許 sibling CardHand root。靜態 layout
必須使用 scene-authored containers：

```text
AutumnHUD
├── MapTitleOverlay（畫面中央、入場後自動淡出）
├── TopLeftStack（compatibility path，runtime hidden；不得顯示 MISSIONS）
├── TopRightMeta
├── TopCenterStack
│   └── BossHealth
├── BottomStage
    ├── PlayerVitals
    ├── CardStage
    │   ├── ActionStrip（legacy authored subtree；runtime hidden）
    │   └── AutumnCardHandUI
    └── ActivityFeed
        └── SkillToastStack
└── FooterRail
    ├── SurvivalTimerLabel
    ├── DashHint（SPACE 衝刺）
    └── NavigationHints
```

左側不再常駐目標／MISSIONS；每次傳送或載入戰鬥地圖只在畫面正中央短暫顯示地圖名，
經淡入、停留與淡出後完全隱藏。右上只顯示金錢與選單提示；素材數量留在背包與鍛造相關 UI，
不在戰鬥 HUD 顯示意義不明的 SHARD 縮寫。Boss health 使用上方中央的暫時空間。
底部從 viewport 的 66% 開始，依序放玩家狀態、目前／門檻／距離下一級的 XP、
即時小數 AP、目前四張牌及右側
activity feed，最下方保留 survival countdown／Space Dash／navigation rail。舊
`ActionStrip` 保留 authored compatibility path 但 runtime 隱藏，手牌因此直接延伸到
`CardStage` 頂端。倒數使用 `MM:SS`，
最後 30 秒切換紅橙色 `FINAL RUSH`，00:00 顯示 `FINAL BOSS`。不可恢復常駐 combo/recipe 或
status progress panel。skill toast 最多三筆、約 1.5 秒淡出；相同技能重複觸發
刷新既有 toast。viewport 寬度低於 1200px 時，Boss panel／bar 會縮為 312／280px，
確保 1152×720 的中央 Boss 資訊不與右上 GOLD／SETTINGS 面板重疊。

### Expedition world selector

`res://scenes/ui/expedition/ExpeditionVariantSelectUI.tscn` 是戰鬥聖所同槽多世界與
中央多 Boss 鑰匙的唯一選擇 UI。全螢幕 root 與 `CenterContainer` 負責置中，
`PanelContainer` 內使用 `MarginContainer`／`VBoxContainer`／`ScrollContainer`；
每個已開放世界建立一個直接 `Button`，不得換成下拉選單。按鈕顯示世界名、嚴格
強度階級，以及該變體自己的碎片 `n/4`／鑰匙完成狀態。九個 Boss 通道同時可用時
仍必須能捲動，1152×720、1280×720、1600×900、1920×1080、2560×1440 與
2560×1080 均不得超出 viewport。

### Autumn structured cards

Autumn Battle V2 renders each visible card through
`res://scenes/ui/autumn/AutumnBattleCard.tscn`. The card root is the only
interactive `Button`; its shortcut, name, type, icon stage, level, and AP
labels use `MOUSE_FILTER_IGNORE`.

`res://scripts/ui/autumn/autumn_card_hand_ui.gd` owns Autumn hand presentation within
`CardStage`。Scene 只建立單組四張 Combo／Healing card buttons，不再存在 inactive group
或 A/S、LT/RT 切組流程。

Card minimum height is derived from the lower-HUD height. The renderer does not
preserve a card aspect ratio: four authored equal-width slots consume the full hand region,
and each card uses `EXPAND_FILL` to match its parent slot in both axes. Hover feedback may
rise vertically but must not scale horizontally into an adjacent slot. Autumn cards use a
`148–320px` responsive minimum height.
Healing／Flame／Volley／Storm identification stays in the artwork, category tab, and restrained accent,
not a saturated full-card frame. 所有 38 張正式 card 都使用
`assets/ui/autumn/cards/generated/<card_id>.png` 的獨立 256×256 暗黑塔羅插畫，
並在縮放到 HUD 時使用 linear filtering，避免雕刻線稿出現 nearest 鋸齒。插畫必須填滿
卡面主視覺區，不可退化為中央小 icon；四張戰鬥牌共用
1173×1341 的 7:8 透明塔羅參考稿提供比例；runtime 外框由
`battle_card_geometric_frame.gd` 以可調整的雙層金線、橢圓拱弧、側柱、銘牌與圓章繪製。
烏鴉、藤蔓煙霧維持同尺寸獨立透明層，元素色只節制地投射到右上種類符號，不額外畫表格框或霓虹邊框。
主圖使用黑底 key shader，讓 360° 金色 sacred-geometry sunburst 從圖騰後方透出而不疊在主體上；
戰鬥卡不顯示 `CelestialHalo` 同心光暈。烏鴉只用於迴響族，藤蔓煙霧只用於生息族，不能把相同
三層 stamp 到四張牌。卡框外不得鋪滿不透明元素色 `ColorRect`，四卡相接時仍須保有塔羅剪影。
舊金幾何外框以全域單調時間軸讓單一道亮帶沿拱弧與側柱持續循環充能；主圖背後另有 60 根 360° 粗金線日芒、
同心圓、六角與十二角幾何，兩組不同頻率的正弦波讓每根射線像環形音樂視覺化一樣連續伸縮。
四張牌必須用 card id 錯開相位，不能同步機械閃爍；日芒波形使用不強制歸零的連續時間值，
外框亮帶跨過拱弧終點時同時繪製尾端與起點，不能在循環接縫抖動。出招後即使手牌重新投影，
也必須接續全域相位而不是歸零重播。
Do not add per-resolution card
positions or resize these cards from gameplay code.

卡面文字使用 `Noto Serif TC` 優先的繁中襯線字族；短招式名以 17–18px 顯示，長名稱最低 12px，獨占帶深墨底的底部卷軸名牌。
左上 Q／W／E／R 使用 32–36px 高、至少 18px 字級的圓形按鍵章；右上圓章顯示可辨識的種類 icon；
右下 AP 圓章只顯示至少 20px 的數字，不重複顯示 `AP` 文字。分類以
「生息治療／業火連段／迴響連段／雷霆連段」放在名牌上方至少 60% 卡寬、四邊舊金框的暖墨 tab。
戰鬥卡面不顯示永久層數；主插畫必須在卷軸名牌上緣前結束，名稱不得再覆蓋圖片。

技能名稱由 AP 圓章位置動態計算專屬銘牌右界，短名稱保持大字、長名稱固定在兩行文字區內 wrap，
超出時以省略號截斷，tooltip 保留完整名稱；任何繁中長名稱、神賜疊加
前綴或字型 fallback 都不得改變卡框尺寸。成功施放後由 Game 在 AP 扣除與效果確認後
呼叫 HUD 的 `show_card_cast_feedback(card_id)`；Hand 只對相符卡片播放約 0.42 秒的
最上層元素色儀式弧光、12 根短放射刻線、三圓章閃光與主圖 punch。動畫不得使用近透明矩形 panel，
也不得重置底層日芒／外框的全域循環。AP 不足、未知 ID 或拒絕施放不能播放，重複施放則安全重啟
同一 tween。這是 presentation feedback，不是 cooldown 或第二套戰鬥狀態。

`PlayerVitals` owns the always-visible XP projection. `set_experience(current,
required)` must show both values plus `NEXT <remaining>` and update the cyan
bar without querying `RunState` from the HUD. Damage pulses HP red, AP recovery
pulses AP green, XP gain pulses the remaining value cyan, and level-up pulses
the new level gold. Each scale/color emphasis settles to the stable layout in
about 0.38 seconds and must be safe while the SceneTree is paused.

### Combo／Healing hand input contract

Autumn hand 顯示單組 4 張 Combo／Healing 卡。Healing 保持綠色；Q/W/E/R 直接打出對應卡；A、S 僅負責
移動，不再有 LT、RT 或任何 group toggle operation。`ember_bolt` 沒有手牌 slot、
LOCK badge 或永久邊框，僅作為戰前選定的自動普攻。`quickstep` 已從正式
卡表移除；玩家 Space Dash 是固有 action，不建立手牌 slot、不顯示 AP cost，
也不透過 Q/W/E/R 操作。

Combat has one fixed card row and no group-toggle operation. A/D remain movement;
Q/W/E/R reuse the same four skills. Basic Attack fires automatically and only
checks the horizontal corridor in the player's facing direction.

equipment-modified AP cost 必須在 affordability 與 input check 前 projection 到 card。
戰鬥卡只由 AP 限制，打出後留在原 slot；HUD 不顯示 draw、discard、redraw 或
Auto Use control。卡片以短類型、icon、AP 與永久 stack 為主，不顯示
START／LINK／FINISH 等角色說明。AP 消耗是決策核心，必須使用至少 18px 數字、
高對比深底金框 badge，不能降回與等級同尺寸的次要文字。
右側 `ComboSkillRows` 顯示三格終結技公式、永久 stacks、持有神賜與 FIFO
終結技 queue；被 catalog 收錄的 Healing 也能進入公式。輸入一至兩招時可顯示
最多三個仍可能完成的配方，但必須明示這是候選提示而非已完成招式。公式完成時，
第一行必須先顯示不含冠名的招式名稱（例如 `千刃殺 · 下一次自動攻擊`），第二行才顯示
祝福冠名（例如 `祝福冠名 · 絕對零度的`）；後續排隊招式仍須可讀。完整冠名招式名保留在
tooltip，不得讓長前綴先占滿第一行而把招式名稱裁成 ellipsis。
`ActivityFeed`、公式標題、公式步驟與 runtime rows 都是固定欄寬的單行 projection；
超長中文名稱使用 ellipsis 並把完整內容放在 tooltip，不得把右欄或 `BottomStage` 撐寬。

Deck Builder 以四個可點選槽位呈現固定手牌，不使用全卡表 `＋／－` 計數器：
第 1 格固定為 Healing 且只接受 Healing 替換，後 3 格是不重複的招式劍魂。新增招式
選擇欄，依圖鑑順序列出 39 個正式招式名稱，點選後經 `legacy_vfx_id` 把配方
`required_skills` 聯集填入後 3 格；仍可容納的招式名稱使用正常
暖金文字，缺少已解鎖劍魂或聯集超過三格者保留在清單並以灰字 disabled 呈現。
招式清單不得放在四格卡槽上方，也不得和劍魂候選同時常駐；四格卡槽之後使用單一
selection workspace，由同列的「劍魂替換／依招式配置」切換鈕一次只顯示一份清單。
招式模式以 13 個不可選系列標題分區，每區下一列固定由左至右顯示基礎／進階／大師，
階級文字不得只藏在 tooltip；系列與三階順序必須直接沿用 `SkillRecipeManager` catalog。
點任一卡槽時回到劍魂替換模式，下方候選排除另外三格已選技能。畫面必須以中文名稱
與說明即時列出目前四張技能能完成的已學會終結技，並用 `×3` 或箭頭保留精確順序。
槽位與候選列都直接顯示 catalog 圖示；Healing 使用綠色十字與綠框，Combo 使用紫色
類型標籤及元素 accent。選中槽位使用明亮金框，槽位背景持續播放雙框、環形刻度與
巡行亮點組成的 code-native 金色幾何動畫。面板在 1280×720 以上依 viewport 等比放大，
上限 1.75 倍，避免高解析度畫面退化成難讀的小視窗。
候選列的 mouse hover 與 keyboard focus 都必須立即更新下方效果預覽；鍵盤上下移動到
ScrollContainer 可視範圍外時，清單必須自動捲動讓焦點項完整可見。
另有 Basic Attack selector；它不是四格手牌之一，
UI 必須明示所選 attack 會在 Run 開始後鎖定、免費、自動水平攻擊。

每次角色升等使用既有 `CardGrowthUI` modal shell，內容只包含新神賜或既有神賜升級；
菁英與 Boss 戰利品頁則只包含既有神賜升級或合法昇華融合。`DivineGiftChoiceCard`
以大型符印、短名稱、等級變化、
中文效果分類、短 lore 與 2–3 條具體 next effect／終結技 mechanics 呈現；選中項使用
實心 badge、粗金框與金色光暈，並在確認鈕上方同步「已選」效果摘要。只有菁英／Boss
來源且存在兩個不同滿級神賜時才可提供融合；一般 EXP 頁永不提供融合。所有可取得
神賜都滿級且沒有新選項時，EXP 頁改顯示金錢或素材 fallback。

合法融合必須顯示獨立的「昇華融合・專屬背景自動攻擊」section，不得混在一般升級列
或隱藏。每張融合卡直接顯示由兩個來源名稱組成的融合名稱、專屬背景攻擊名稱、interval、target count 與
「繼承劍魂」說明；完整 tooltip 仍保留 description。背景攻擊必須投影兩個來源的幾何 motif
與發光色，不能退化成只挑幾個數值屬性。五選項上限套用到升級與融合的總和。

玩家可見文案使用「神賜／菁英祝福／昇華」，名稱、說明、階級與融合名稱皆為繁中。
Autumn HUD 固定容納並顯示四個神賜 slot；滿四項時選擇頁只列既有神賜升級，不得用
未持有神賜覆蓋任一 slot。四項前綴與效果都持續累加，主要神賜標記只表示最近取得，
不代表其他神賜失效。

### Responsive contract

以下六種 viewport 全部是必要驗證，不是抽樣：

- 1152×720
- 1280×720
- 1600×900
- 1920×1080
- 2560×1080
- 2560×1440

另以玩家回報的 2864×1080 超寬視窗作為回歸尺寸，確認四個 slot 確實橫向填滿
CardStage，右側長文字不會反推中央欄位。

每個尺寸都要確認 top-left stack、top-center stack、bottom stage、單列四張 cards、
Combo Chain 清單、四格 Deck Builder、interaction prompt 與 world-safe area
不重疊、不裁切、不超界。
禁止用 gameplay script 為單一解析度寫絕對位置。

## 34. Card Growth Modal

`res://scenes/ui/cards/CardGrowthUI.tscn` 是 wave reward、EXP Blessing 與菁英／Boss
Blessing loot 的單一 modal。
舊 `LevelUpUI` 與 Autumn Blessing popup 不再是這條流程的 authority。

Growth choice card 必須以卡牌類型色、catalog icon、AP／level 關鍵資料協助掃讀。
效果與升級差異採短句項目符號；多個效果或條件不得壓成單段長文。完整原文保留於
tooltip。Icon、顏色與 description 由 queue payload 投影，UI 不反查或修改 catalog。

- wave page 只顯示 new card。
- EXP page 只隨機顯示最多三項新神賜／既有神賜升級；全部神賜皆無可用成長時才顯示
  三種金錢／素材 fallback。
- Elite／Boss page 只顯示既有神賜升級與合法 Lv.3 神賜融合，不得加入未持有的新神賜。
- 五個成長選項固定為上排三張、下排兩張置中，不使用可捲動的全牌清單。
- wave new-card page 一律提供 `Skip Reward`，讓玩家可維持精簡牌組；若玩家選牌但
  已達 16 張上限，則改開 replacement modal，可替換一張現有卡或再次 Skip。
- new-card 選項直接標示 type、AP cost 與基礎效果；神賜選項直接標示目前效果
  與下一級變化，不得只把完整說明藏在 tooltip。
- UI 必須清楚標示神賜 level、兩項融合材料與 Lv.1 昇華結果。
- `CardGrowthUI` 只 emit choice intent，不能直接改 deck、Meta 或 inventory。
- modal 開啟期間 gameplay clock、AP、skill cooldowns、status、skills、waves 與 projectile
  都必須暫停；UI 保持 always-processing 與可操作 focus。
- queue 逐頁處理；close/teardown 只有在 queue 清空後才釋放 pause token。
