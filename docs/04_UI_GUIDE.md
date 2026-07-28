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
└── CardEffectRunner (Node)
```

Current ownership：

- `HUDLayer`：持有一個 `HUD` authority；Town 的 `CardHandUI` 是相鄰 root，
  Autumn hand 則內嵌在 AutumnHUD。
- `MenuLayer`：持有 `ui_stack` 中的 Inventory、Pause、Dialogue、Shop、
  MaterialYard、PlayerBlacksmith、TownHall、DeckBuilder、CardDiscard、LevelUp、
  RunResult 等 screen。
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
- `scripts/ui/**`：18 個 `.gd`
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

用途：Inventory slots、固定欄數選項。

Current `InventoryUI.tscn`：5 columns、20 authored slots。

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
- `TownHallWindow` minimum 1060×650。
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

`scripts/ui/hud.gd` 提供：

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
建築招牌採 compact floating plaque：高度不超過 `34px`、字級不超過 `16px`、
左側 `4–5px` 色帶、其餘 `1px` 細框、`10px` 圓角與不超過 `5px` 的陰影。
一般／市政使用鍛造金，主設施使用火焰橘，戰鬥傳送門使用魔力藍，劍魂相關
建築使用靈魂紫。招牌寬度不得超過 `200px`，避免壓過背景建築與 NPC。

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
- compact card minimum 為 `82×78`。
- bottom safe area 為 viewport 高度的 25%。
- 四張 Combo／Healing 手牌固定放在 `FrontRow` 並接收 Q/W/E/R；`BackRow` 保持空白。
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

- centered 約 904×554 panel
- 5-column GridContainer
- 20 個 authored `InventorySlot.tscn`
- Header、CategoryTabs、DetailPanel 子場景
- 無 ScrollContainer

`inventory_ui.gd`：

- `set_gold()`、`set_items()`、`set_category()`、`set_selected_item()`
- slot keyboard navigation
- runtime quantity Label

### 12.2 Current gaps

- category 只改 visual 並 emit signal，沒有實際篩選 items。
- slot 數固定 20，無 scroll/pagination。
- component 子場景無 script/signal，父 controller 依賴 deep NodePath。
- empty/max/long localized item 尚無 resolution test。

### 12.3 Inventory rules

- UI 不直接修改 item catalog。
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
  持有量、火炬 Tier、數量與購買。
- Player Blacksmith：左側主角肖像；Forge 依圖紙鍛造 equipment／Sword Soul，
  Workshop Upgrade 解鎖鍛造上限，Sales Table 顯示商品、顧客與 `+GOLD` 回饋。
- Town Hall：左側村長肖像，中欄只保留 Overview／Hall Upgrade，右欄顯示當前
  village stage 或下一級成本。

三者均使用 Full Rect root、dim backdrop、safe margin、center container、semantic
window 與 authored ScrollContainer；Player Blacksmith 的動態 recipe row 必須只放在
既定 `RecipeList`。開啟後 focus 落在可用 action，`ui_cancel` 關閉並釋放 focus，
重開不得重複 controls 或 signals。

Town Hall、Material Yard、Player Blacksmith、Sword Soul Blueprint Shop 與
Equipment Blueprint Shop 使用同一套功能建築大框架。共同 presentation 由
`TownServiceFrameTheme.tres` 擁有，包括 window、portrait、title 與 Close button
variations；各 screen 不得以 local override 改寫這四個共同部分。

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

- Continue、Inventory、Save、Load、Settings、Quit
- Master bus volume
- fullscreen toggle
- settings/button stack focus switching

規則：

- `SceneTree.paused` 只由 Game stack 統一更新。
- UI root 用 `PROCESS_MODE_ALWAYS`，paused 時仍可操作。
- nested screen 開關後 focus 回到合理 owner。
- Save/Load feedback顯示在 footer，但不得假裝 save 成功。
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
├── TopLeftStack
│   └── ObjectivePanel
├── TopRightMeta
├── TopCenterStack
│   └── BossHealth
├── BottomStage
    ├── PlayerVitals
    ├── CardStage
    │   ├── ActionStrip
    │   │   ├── ActionSpacer
    │   │   └── RedrawHand
    │   └── AutumnCardHandUI
    └── ActivityFeed
        └── SkillToastStack
└── FooterRail
```

目前目標固定在左上，金錢與 magic shard 位於右上，Boss health 使用上方中央的暫時空間。
底部從 viewport 的 66% 開始，依序放玩家狀態與即時小數 AP、目前四張牌及右側
activity feed，最下方保留 phase/navigation rail。不可恢復常駐 combo/recipe 或
status progress panel。skill toast 最多三筆、約 1.5 秒淡出；相同技能重複觸發
刷新既有 toast。

### Autumn structured cards

Autumn Battle V2 renders each visible card through
`res://scenes/ui/autumn/AutumnBattleCard.tscn`. The card root is the only
interactive `Button`; its shortcut, name, type, icon stage, level, and AP
labels use `MOUSE_FILTER_IGNORE`.

`res://scripts/ui/autumn_card_hand_ui.gd` owns Autumn hand presentation within
`CardStage`。Scene 只建立單組四張 Combo／Healing card buttons，不再存在 inactive group
或 A/S、LT/RT 切組流程。

Card height is derived from the lower-HUD height and hand-column width. The
renderer preserves a `0.72` width-to-height ratio and updates the negative
card dimensions on viewport resize. Do not add per-resolution card
positions or resize these cards from gameplay code.

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
START／LINK／FINISH 等角色說明。
右側 `ComboSkillRows` 顯示三格 Combo 公式、永久 stacks、持有神賜與 FIFO
終結技 queue；Healing 不進公式。公式完成時必須突出實際招式全名，例如
`絕對零度的千刃殺 · NEXT AUTO SHOT`，後續排隊招式仍須可讀。

Deck Builder 以四個可點選槽位呈現固定手牌，不使用全卡表 `＋／－` 計數器：
第一格是綠色 Healing 專用欄位，後三格是紫色 Combo 1／2／3。點槽位後，下方候選
只顯示該類型，Combo 候選排除另外兩格已選技能。畫面必須即時列出目前三張 Combo
能完成的已學會終結技名稱。另有 Basic Attack selector；它不是四格手牌之一，
UI 必須明示所選 attack 會在 Run 開始後鎖定、免費、自動水平攻擊。

每個 stage/wave 的首次菁英掉落使用既有 `CardGrowthUI` modal shell，但內容是
Divine Gift，不是卡牌升級：顯示 icon、短名稱、等級、最多三點效果，主稱號神賜
標記 `MAIN`。存在兩個不同滿級神賜時，同頁提供融合選項；若頁面只有融合選項則
允許略過，避免 modal 反覆開啟。

### Responsive contract

以下六種 viewport 全部是必要驗證，不是抽樣：

- 1152×720
- 1280×720
- 1600×900
- 1920×1080
- 2560×1080
- 2560×1440

每個尺寸都要確認 top-left stack、top-center stack、bottom stage、兩列 cards、
Combo Chain 清單、四格 Deck Builder、interaction prompt 與 world-safe area
不重疊、不裁切、不超界。
禁止用 gameplay script 為單一解析度寫絕對位置。

## 34. Card Growth Modal

`res://scenes/ui/cards/CardGrowthUI.tscn` 是 wave blessing 與 EXP growth 的單一 modal。
舊 `LevelUpUI` 與 Autumn Blessing popup 不再是這條流程的 authority。

Growth choice card 必須以卡牌類型色、catalog icon、AP／level 關鍵資料協助掃讀。
效果與升級差異採短句項目符號；多個效果或條件不得壓成單段長文。完整原文保留於
tooltip。Icon、顏色與 description 由 queue payload 投影，UI 不反查或修改 catalog。

- wave page 只顯示 new card。
- EXP upgrade page 只隨機顯示最多五張未滿級 instances；全部卡片滿級後才另開
  最多五組合法 Lv.3 fusion page；沒有合法 growth 時才顯示三種永久資源 fallback。
- 五個成長選項固定為上排三張、下排兩張置中，不使用可捲動的全牌清單。
- wave new-card page 一律提供 `Skip Reward`，讓玩家可維持精簡牌組；若玩家選牌但
  已達 16 張上限，則改開 replacement modal，可替換一張現有卡或再次 Skip。
- new-card 選項直接標示 type、AP cost 與基礎效果；upgrade 選項直接標示目前效果
  與下一級變化，不得只把完整說明藏在 tooltip。
- UI 必須清楚標示 instance level、兩張 fusion 材料與 Lv.1 結果。
- `CardGrowthUI` 只 emit choice intent，不能直接改 deck、Meta 或 inventory。
- modal 開啟期間 gameplay clock、AP、skill cooldowns、status、skills、waves 與 projectile
  都必須暫停；UI 保持 always-processing 與可操作 focus。
- queue 逐頁處理；close/teardown 只有在 queue 清空後才釋放 pause token。
