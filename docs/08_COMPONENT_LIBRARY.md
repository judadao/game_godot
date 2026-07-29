# UI Component Library

本文件是本專案 UI 元件的真實 catalog 與未來 contract。它區分 production-used
scene、partial candidate、unused prototype 與尚未實作的 TODO。看到名稱相近的
scene 不代表元件已完成；只有實際 path 與引用者可驗證時才可標為 Current。
其中 `Current — Used` 另要求行為 contract 可驗證；沒有獨立 API/signal 的
production subtree 必須明確標為 `Current — Visual Only`，不得暗示為完整元件。

## 目錄

1. [文件目的與成熟度](#1-文件目的與成熟度)
2. [元件共同契約](#2-元件共同契約)
3. [目前 Component Map](#3-目前-component-map)
4. [PrimaryButton](#4-primarybutton)
5. [SecondaryButton](#5-secondarybutton)
6. [DangerButton](#6-dangerbutton)
7. [Dialog](#7-dialog)
8. [ItemCard](#8-itemcard)
9. [SkillCard](#9-skillcard)
10. [QuestRow](#10-questrow)
11. [Tooltip](#11-tooltip)
12. [InventorySlot](#12-inventoryslot)
13. [HealthBar](#13-healthbar)
14. [ManaBar](#14-manabar)
15. [StatusRow](#15-statusrow)
16. [PanelHeader](#16-panelheader)
17. [ListRow](#17-listrow)
18. [LoadingView](#18-loadingview)
19. [EmptyView](#19-emptyview)
20. [ErrorView](#20-errorview)
21. [其他 Current Domain Components](#21-其他-current-domain-components)
22. [Unused / Prototype / Disabled Legacy Components](#22-unused--prototype--disabled-legacy-components)
23. [Code Examples](#23-code-examples)
24. [Scene Tree Example](#24-scene-tree-example)
25. [Godot Example (Godot 4)](#25-godot-example-godot-4)
26. [Best Practice](#26-best-practice)
27. [Anti Pattern](#27-anti-pattern)
28. [Component Implementation Checklist](#28-component-implementation-checklist)
29. [Review Checklist](#29-review-checklist)
30. [Future Extension](#30-future-extension)
31. [Related Documents](#31-related-documents)

## 1. 文件目的與成熟度

### 1.1 成熟度定義

| 狀態 | 定義 |
|---|---|
| **Current — Used** | production screen 實際 instance/use，path 與 caller 可驗證 |
| **Current — Visual Only** | scene 被使用，但無自己的 script/signal/API，行為由父層注入 |
| **Partial — Candidate** | 有相近 scene/subtree，但未形成通用或 production-used contract |
| **Unused — Prototype** | scene 存在但沒有 production reference |
| **TODO — Not Implemented** | repository 沒有此元件；本文件提供未來 contract |

### 1.2 Catalog 原則

- 不用「有 scene」等同「有元件」。
- 不用「有 subtree」等同「可重用」。
- 不把 runtime 建立的 Button 說成 scene component。
- 不把 domain-specific screen 說成 generic component。
- TODO contract 是規格，不是完成狀態。

## 2. 元件共同契約

每個正式元件至少必須定義：

1. 用途與禁止用途。
2. Scene path 與 root type。
3. Scene Tree 與穩定 node names。
4. script path / `class_name`。
5. public setters/configure methods。
6. typed signals。
7. Theme Variation / icon / StyleBox。
8. focus、mouse、disabled、selected state。
9. empty/long/max/localized content。
10. cleanup 與 repeated configure。
11. direct component test。

### 2.1 依賴方向

```text
domain data / presentation model
→ component configure/setters
→ visual state

user input
→ typed intent signal
→ screen/controller/Game
→ domain mutation
→ projection back to component
```

Component 不得直接找 `/root/Game`、修改 save、扣款、造成傷害或改 static catalog。

### 2.2 命名

- Scene / root / class：PascalCase。
- script / method / variable：snake_case。
- signal：過去式或 intent，例如 `pressed`、`selected`、`retry_requested`。
- semantic variation：PascalCase，例如 `PrimaryButton`。
- node name描述角色，不用 `Panel2`、`Label3`。

## 3. 目前 Component Map

### 3.1 Rule 2 元件總覽

| 元件 | 狀態 | 實際對應 |
|---|---|---|
| PrimaryButton | TODO | 無 reusable scene / variation |
| SecondaryButton | TODO | 無 reusable scene / variation |
| DangerButton | TODO | 無 reusable scene / variation |
| Dialog | Partial | `scenes/ui/dialogue/DialogueUI.tscn` 是 domain screen |
| ItemCard | TODO | 無 |
| SkillCard | Partial | CardHand runtime Button，非 scene component |
| QuestRow | TODO | 無；只有 HUD quest tracker |
| Tooltip | TODO | 只有 `tooltip_text` |
| InventoryCodexPreview | Current — Presentation | `scripts/ui/inventory_codex_preview.gd` |
| HealthBar | TODO | 舊 `HUDStatusBar.tscn` prototype 已移除；現役 HUD 有內嵌 HP bar |
| ManaBar | Partial subtree | `HUDStatus.tscn/MPBar`，無獨立 scene |
| StatusRow | TODO | 無 |
| PanelHeader | Partial domain | screens 各自 editor-authored，非 generic |
| ListRow | Partial domain | `ShopItemRow.tscn`，無 script/API |
| LoadingView | TODO | 無 |
| EmptyView | TODO | 無 |
| ErrorView | TODO | 無 |

### 3.2 Production-used visual subscenes

- `scenes/ui/shop/ShopItemRow.tscn`
- `scenes/ui/shop/ShopDetailPanel.tscn`
- `scenes/ui/shop/ShopMerchantPanel.tscn`
- `scenes/ui/hud/HUDStatus.tscn`
- `scenes/ui/hud/HUDProgressPanel.tscn`
- `scenes/ui/hud/HUDQuestTracker.tscn`
- `scenes/ui/hud/HUDInteractionPrompt.tscn`
- `scenes/ui/hud/HUDHotbar.tscn`（由 HUD instance，但目前 hidden）

這些多為 visual-only scene；父 screen controller 依賴其 deep NodePath。

## 4. PrimaryButton

### 4.1 狀態

**TODO — Not Implemented。**

目前所有 confirm/continue/buy buttons 使用 scene-local StyleBox 或 Godot default
Button；沒有 `PrimaryButton` scene、class 或 Theme Variation。

### 4.2 用途

- 每個 panel 的主要確認/前進 action。
- 例如 Shop Confirm、Run Result Return、DeckBuilder Enter Forest。

### 4.3 Target Scene Tree

```text
PrimaryButton (Button, variation = PrimaryButton)
```

優先只使用 base `Button` + Theme Variation；若沒有額外 child，不需要建立薄 scene。

### 4.4 Target script/API

通常不需要 script。若需 async/loading state，未來可定：

```gdscript
class_name PrimaryButton
extends Button

func set_busy(is_busy: bool) -> void
```

此 class/path 尚未建立。

### 4.5 Target signals

沿用 `BaseButton.pressed`。不得另包一個同義 `clicked` signal。

### 4.6 Target Theme

- `theme_type_variation = &"PrimaryButton"`
- normal/hover/pressed/focus/disabled 完整。
- focus 不可只等同 hover。

### 4.7 使用時機

- 明確主要 action，通常一個 action group 只一個。

### 4.8 禁止事項

- 不把所有 Button 都標 primary。
- 不用 primary 表示 destructive action。
- variation 尚未建立前不可聲稱已採用。

## 5. SecondaryButton

### 5.1 狀態

**TODO — Not Implemented。**

### 5.2 用途

- Cancel、Back、Close、次要 action。

### 5.3 Target Scene Tree

```text
SecondaryButton (Button, variation = SecondaryButton)
```

### 5.4 Target script/API

預設無 script，沿用 Button API。

### 5.5 Target signals

沿用 `pressed`。

### 5.6 Target Theme

- `SecondaryButton` variation。
- 視覺權重低於 Primary，但 focus/disabled 仍清楚。

### 5.7 使用時機

- modal cancel/back。
- 與 primary 同 action bar 的次要選項。

### 5.8 禁止事項

- 不用低 contrast 讓它看似 disabled。
- 不把所有 CloseButton 複製一套 StyleBox。

## 6. DangerButton

### 6.1 狀態

**TODO — Not Implemented。**

Current `PauseMenu/Quit` 是一般 Button，沒有 Danger variation。

### 6.2 用途

- Delete、Quit without save、不可逆重置等危險 action。

### 6.3 Target Scene Tree

```text
DangerButton (Button, variation = DangerButton)
```

### 6.4 Target script/API

預設無 script。危險操作的 confirmation flow 由 screen owner 管理。

### 6.5 Target signals

沿用 `pressed`，不得由 component 直接執行刪除/quit。

### 6.6 Target Theme

- danger semantic color。
- normal/focus/disabled 都可讀。
- icon/文字輔助，不只紅色。

### 6.7 使用時機

- 只有真正高風險操作。

### 6.8 禁止事項

- 不將一般 Cancel 標 Danger。
- 不讓 Button 直接改 save/delete file。

## 7. Dialog

### 7.1 狀態

**Partial — Domain Screen。**

實際 path：

- scene：`scenes/ui/dialogue/DialogueUI.tscn`
- script：`scripts/ui/dialogue_ui.gd`
- class：`DialogueUI`

它是 NPC/campfire/card reward 共用的 dialogue screen，不是通用 confirmation Dialog，
也不是 Godot `Window`/`AcceptDialog`。

### 7.2 Current Scene Tree

```text
DialogueUI (Control, Full Rect)
└── DialoguePanel (Panel)
    ├── SpeakerNamePlate
    │   └── SpeakerName
    ├── PortraitFrame
    │   └── PortraitPlaceholder
    │       └── PortraitInitial
    ├── DialogueText (RichTextLabel)
    ├── ChoicesContainer (VBoxContainer)
    │   ├── ChoiceOne
    │   ├── ChoiceTwo
    │   └── ChoiceThree
    └── NextArrowIndicator
```

### 7.3 Current API

```gdscript
func open() -> void
func close() -> void
func toggle() -> void
func set_speaker_name(display_name: String) -> void
func set_dialogue_text(text: String) -> void
func set_choices(new_choices: Array) -> void
func set_portrait_initial(initial: String) -> void
```

### 7.4 Current signals

```gdscript
signal opened
signal closed
signal toggled(is_open: bool)
signal advanced
signal choice_selected(index: int, text: String, metadata: Dictionary)
signal canceled
```

### 7.5 Current Theme

7 個 scene-local `StyleBoxFlat`，無 Theme Variation。

### 7.6 使用時機

- NPC text/choices。
- campfire choices。
- wandering merchant card choices。
- card reward choices。

### 7.7 Current limits

- choices 無 ScrollContainer。
- hard-coded English placeholder。
- 無 localization catalog。
- 不是 generic confirm/error dialog。

### 7.8 TODO generic Dialog contract

未來 generic Dialog 應與 DialogueUI 分開：

```text
DialogScreen (Control, Full Rect)
├── DimBackground
└── Center
    └── DialogPanel
        └── Content
            ├── Header
            ├── Body
            └── Actions
```

Target signals：

```gdscript
signal confirmed
signal canceled
signal closed
```

### 7.9 禁止事項

- 不把 DialogueUI 改成承擔所有 error/confirm/loading。
- 不由 Dialog 自行 pause tree。
- 不解析顯示文字決定 action；使用 metadata/action id。

## 8. ItemCard

### 8.1 狀態

**TODO — Not Implemented。**

Inventory 現有的是 icon slot + detail panel，沒有 ItemCard。

### 8.2 用途

- 顯示 item icon、name、rarity/type、quantity、簡短 stats。
- 用於 inventory list、reward、shop preview 等需要 summary card 的場合。

### 8.3 Target Scene Tree

```text
ItemCard (Button)
└── Content (HBoxContainer)
    ├── IconFrame (AspectRatioContainer)
    │   └── Icon (TextureRect)
    └── Text (VBoxContainer)
        ├── Name (Label)
        ├── Metadata (Label)
        └── Quantity (Label)
```

### 8.4 Target API

```gdscript
class_name ItemCard
extends Button

func set_item(item: Dictionary) -> void
func set_selected(is_selected: bool) -> void
func clear() -> void
```

### 8.5 Target signals

```gdscript
signal item_selected(item_id: StringName)
```

### 8.6 Target Theme

- `ItemCard` variation。
- selected/focus/disabled 分開。
- rarity 不只靠顏色。

### 8.7 使用時機

- 需要比 InventorySlot 更多摘要內容。

### 8.8 禁止事項

- 不直接修改 item Dictionary。
- 不把交易按鈕或 equip rule 放進 card。
- 不在每次 configure 重複 connect。

## 9. SkillCard

### 9.1 狀態

**Partial — Runtime presentation，不是 component。**

`scripts/ui/card_hand_ui.gd` 在 runtime 建 Button，包含 name/type/level/description/cost，
但 repository 沒有 `SkillCard.tscn` 或 `SkillCard` class。

### 9.2 Current runtime contract

- compact minimum `82×78`，由 `BackRow`／`FrontRow` Container 分配實際尺寸
- `clip_text = true`
- word-smart autowrap
- tooltip = description
- pressed → `CardHandUI.select_card(global_index)`
- hover position/scale/rotation由 CardHand管理

### 9.3 Target Scene Tree

若未來抽出 component：

```text
SkillCard (Button)
└── Content (VBoxContainer)
    ├── Header (HBoxContainer)
    │   ├── Shortcut
    │   └── Cost
    ├── Name
    ├── TypeAndLevel
    ├── Icon
    └── Description
```

### 9.4 Target API

```gdscript
class_name SkillCard
extends Button

func configure(card: Dictionary, shortcut: String) -> void
func set_affordable(is_affordable: bool) -> void
func set_selected(is_selected: bool) -> void
```

### 9.5 Target signals

```gdscript
signal card_requested(card_id: String)
signal hover_changed(is_hovered: bool)
```

CardHand仍擁有fan layout，不把全域position animation放進card component。

### 9.6 Target Theme

- `SkillCard` variation + card type semantic palette。
- focus/hover/disabled state。

### 9.7 使用時機

- card presentation需要跨DeckBuilder/reward/hand重用時。

### 9.8 禁止事項

- 不宣稱目前 runtime Button 已是 SkillCard。
- 不在 component 計算AP或執行card effect。
- 不讓component自行決定fan position。

## 10. QuestRow

### 10.1 狀態

**TODO — Not Implemented。**

Current 只有 `HUDQuestTracker.tscn`，且沒有 Quest model。

### 10.2 用途

- 正式 Quest screen 中顯示單一 quest summary。

### 10.3 Target Scene Tree

```text
QuestRow (Button)
└── Content (HBoxContainer)
    ├── StateIcon (TextureRect)
    └── Text (VBoxContainer)
        ├── Title (Label)
        ├── Objective (Label)
        └── Progress (Label)
```

### 10.4 Target API

```gdscript
class_name QuestRow
extends Button

func configure(quest_view: Dictionary) -> void
func set_tracked(is_tracked: bool) -> void
```

### 10.5 Target signals

```gdscript
signal quest_selected(quest_id: StringName)
signal tracking_requested(quest_id: StringName)
```

### 10.6 Target Theme

- `QuestRow` variation。
- active/completed/failed/locked 以 icon+text+style 表示。

### 10.7 使用時機

只有正式 Quest model/data flow 建立後。

### 10.8 禁止事項

- 不從 HUD objective text 反向建立 quest id。
- 不在 UI 直接完成 quest或寫save。
- 不把 HUDQuestTracker 說成 QuestRow。

## 11. Tooltip

### 11.1 狀態

**TODO — Not Implemented。**

Current 只有 Button/slot 的 `tooltip_text`，沒有 scene、controller 或 custom tooltip。

### 11.2 用途

- item/card/disabled action 的補充說明。
- 支援 mouse hover 與 keyboard/controller focus。

### 11.3 Target Scene Tree

```text
Tooltip (PanelContainer)
└── Margin (MarginContainer)
    └── Content (VBoxContainer)
        ├── Title (Label)
        └── Body (RichTextLabel)
```

### 11.4 Target API

若需 custom tooltip：

```gdscript
class_name Tooltip
extends PanelContainer

func configure(title: String, body: String) -> void
```

Godot `_make_custom_tooltip(for_text)` 可由 source control 回傳此 scene。

### 11.5 Target signals

一般無 signal。Tooltip 不接收 gameplay action。

### 11.6 Target Theme

- `TooltipPanel` variation。
- viewport-clamped elevated surface。

### 11.7 使用時機

- 原生 tooltip text 無法表達 title/icon/rich content 時。

### 11.8 禁止事項

- 不讓 tooltip 超出 viewport。
- 不只支援 mouse hover。
- 不在 tooltip 放唯一可操作按鈕。

## 12. InventoryCodexPreview

**Current — Domain-specific presentation component。**

- script：`scripts/ui/inventory_codex_preview.gd`
- owner：`scenes/ui/inventory/InventoryUI.tscn`
- API：`show_entry()`、`get_active_entry_id()`、`get_preview_kind()`
- reuse：`ElementalAttackAura`、`FireUltimateVFX`、`IceUltimateVFX`
- boundary：只顯示 projection，不計算傷害、不解鎖 discovery、不 mutation save
- tooltip/quantity/selection由父層注入。
- 無 empty/disabled/locked state API。
- 20 slots固定。

### 12.8 禁止事項

- 不在其他 screen 直接假設 Quantity runtime child 一定存在。
- 不把 visual-only scene描述成完整 reusable API。
- 不讓slot直接改 inventory model。

## 13. HealthBar

### 13.1 狀態

**Partial — Unused candidate + active duplicated subtree。**

舊 `HUDStatusBar.tscn` prototype 已於 scene cleanup 移除；目前沒有獨立
HealthBar scene，production HUD 仍使用內嵌 subtree。

現役 health bar：

- `scenes/ui/hud/HUDStatus.tscn` 的 `HPBar`
- 由 `scripts/ui/hud.gd::set_health()` 更新

### 13.2 Candidate Scene Tree

```text
HUDStatusBar (Control)
├── Fill (ColorRect)
├── Frame (TextureRect)
└── Value (Label)
```

### 13.3 Script/API

現役 HUD 由父 script 直接改內嵌 bar：

```gdscript
func set_health(current: int, maximum: int) -> void
```

### 13.4 Signals

無。HealthBar 是 display-only。

### 13.5 Theme

- candidate 使用 texture frame + direct colors/font override。
- 無 HealthBar variation。

### 13.6 使用時機

目前使用 `HUDStatus/HPBar`；不要使用無引用 candidate，除非任務正式遷移並補測試。

### 13.7 TODO reusable contract

```gdscript
class_name HealthBar
extends Control

func set_value(current: int, maximum: int) -> void
func set_preview(delta: int) -> void
```

`set_preview` 只有玩法確認需要預覽時才實作。

### 13.8 禁止事項

- 不重新引入未被 owner 使用的獨立 HealthBar prototype。
- 不由bar修改Player health。
- 不用raw width超出0..1 ratio。

## 14. ManaBar

### 14.1 狀態

**Partial — Active subtree，無獨立 component。**

實際位置：

- `scenes/ui/hud/HUDStatus.tscn` → `MPBar`
- `scripts/ui/hud.gd::set_mana()`

### 14.2 Current Scene Tree

```text
MPBar (Control)
├── Track (ColorRect)
├── Fill (ColorRect)
├── Frame (TextureRect)
└── Value (Label)
```

### 14.3 Script/API

沒有獨立 script。父 HUD API：

```gdscript
func set_mana(current: int, maximum: int) -> void
```

### 14.4 Signals

無，display-only。

### 14.5 Theme

direct colors、texture frame、font overrides；無 ManaBar variation。

### 14.6 TODO reusable contract

與 HealthBar 共用一個可配置 `StatusBar` base 或不同 semantic variation，避免複製
scene/script：

```gdscript
func set_value(current: int, maximum: int) -> void
func set_label(text: String) -> void
```

### 14.7 使用時機

當 HUD 與其他至少一個 screen 需要相同 MP 顯示 contract 時，再抽成共用
StatusBar；目前維持 HUD 內的 active subtree。

### 14.8 禁止事項

- 不由 ManaBar 修改玩家 MP。
- 不為只有顏色差異複製另一套 bar script。
- 不再複製第四套 bar subtree。
- 不由 ManaBar 消耗mana。

## 15. StatusRow

### 15.1 狀態

**TODO — Not Implemented。**

HUDProgressPanel 有 Gold/EXP HBox rows，但沒有通用 StatusRow scene/API。

### 15.2 用途

- label + value + optional icon/semantic state 的一致 row。

### 15.3 Target Scene Tree

```text
StatusRow (HBoxContainer)
├── Icon (TextureRect, optional)
├── Label (Label)
├── Spacer (Control, Expand)
└── Value (Label)
```

### 15.4 Target API

```gdscript
class_name StatusRow
extends HBoxContainer

func configure(label_text: String, value_text: String, icon: Texture2D = null) -> void
func set_value(value_text: String) -> void
```

### 15.5 Target signals

無，預設 display-only。

### 15.6 Target Theme

- typography/spacing來自 Theme。
- semantic value state可用variation或限定override。

### 15.7 使用時機

- Gold/EXP/stats等真正相同結構重複三處以上時。

### 15.8 禁止事項

- 不為只有一處使用建立抽象。
- 不以空白字串對齊 value。

## 16. PanelHeader

### 16.1 狀態

**Partial — Domain-specific visual scene。**

實際 candidate：

- Inventory header 已 inline 到唯一 owner `InventoryUI.tscn`；舊 domain scene 已退役。

### 16.2 Current Scene Tree

```text
HeaderPanel (PanelContainer)
└── HeaderMargin
    └── HeaderRow
        ├── Title
        ├── CurrencyDisplay
        └── CloseButton
```

### 16.3 Script/API

無 component script。`inventory_ui.gd` 透過 deep NodePath 操作 CurrencyDisplay 與
CloseButton。

### 16.4 Signals

無 wrapper；父層連 `CloseButton.pressed`。

### 16.5 Theme

scene-local StyleBoxFlat + LabelSettings；無 PanelHeader variation。

### 16.6 TODO generic contract

```text
PanelHeader (PanelContainer)
└── Content (HBoxContainer)
    ├── Icon (optional)
    ├── Title (Label)
    ├── Subtitle/Spacer
    └── CloseButton (optional)
```

```gdscript
signal close_requested
func set_title(value: String) -> void
func set_subtitle(value: String) -> void
func set_close_visible(is_visible: bool) -> void
```

### 16.7 使用時機

當 Inventory/Shop/Pause 等至少三個 header contract收斂後。

### 16.8 禁止事項

- 不把 CurrencyDisplay 硬編進generic header。
- 不讓header直接close screen；emit request給owner。

## 17. ListRow

### 17.1 狀態

**Partial — Domain-specific visual scene。**

實際 path：

- `scenes/ui/shop/ShopItemRow.tscn`
- 引用者：`ShopUI.tscn` 內 8 個 authored instances，長清單由 controller 動態補列

### 17.2 Current Scene Tree

```text
ShopItemRow (Button)
└── RowMargin (MarginContainer, mouse ignore)
    └── RowLayout (HBoxContainer)
        ├── ItemIcon (TextureRect)
        ├── ItemText (VBoxContainer, Expand)
        │   ├── ItemName
        │   └── Stock
        └── PriceGroup (HBoxContainer)
            ├── CoinIcon
            └── Price
```

Button root 是唯一 input/focus owner；icon、name、stock/owned 與 price 已是獨立
semantic children，不再以空白字元拼成單一 `text`。

### 17.3 Script/API

無 script/API。`shop_ui.gd`：

- cache rows
- bind index
- 依 catalog 長度 instantiate 缺少的 rows
- 更新 icon、name、stock/owned、price、tooltip與style
- 建 focus graph

### 17.4 Signals

沿用 Button signals，父層綁 index。

### 17.5 Theme

4 個 scene-local StyleBoxFlat，分別提供 normal、hover、pressed/selected 與 focus；
仍無 generic ListRow variation。

### 17.6 Current limits

- 尚未 virtualize 大型 catalog。
- 無empty/loading/error。
- 無獨立 component script/configure API；資料綁定仍由父 `ShopUI` controller 擁有。

### 17.7 TODO generic contract

```text
ListRow (Button)
└── Content (HBoxContainer)
    ├── LeadingIcon (optional)
    ├── PrimaryText (Label, Expand)
    ├── SecondaryText (Label)
    └── TrailingValue (Label)
```

```gdscript
signal row_selected(row_id: StringName)
func configure(view: Dictionary) -> void
func set_selected(is_selected: bool) -> void
```

### 17.8 使用時機

當 Shop、Inventory 或未來 Quest 中至少兩個清單需要相同 row/focus contract
時建立；在此之前保留 domain-specific row。

### 17.9 禁止事項

- 不把價格、庫存或 quest state 寫死在 generic component。
- 不以固定八列取代可捲動的動態清單。
- 不宣稱 ShopItemRow 已是generic ListRow。
- 不用空白對齊欄位。
- 不讓row執行交易。

## 18. LoadingView

### 18.1 狀態

**TODO — Not Implemented。**

### 18.2 用途

- async/loading 狀態的明確回饋。

### 18.3 Target Scene Tree

```text
LoadingView (CenterContainer)
└── Content (VBoxContainer)
    ├── Indicator (TextureRect or ProgressBar)
    └── Message (Label)
```

### 18.4 Target API

```gdscript
class_name LoadingView
extends CenterContainer

func set_message(value: String) -> void
func set_progress(value: float, maximum: float) -> void
```

### 18.5 Target signals

無；若可取消，使用明確 `cancel_requested` 並顯示 Button。

### 18.6 Target Theme

- LoadingView spacing/typography。
- animation遵守reduced motion。

### 18.7 使用時機

只有實際 async/loading 流程，不用假 loading遮延遲。

### 18.8 禁止事項

- 不無限轉圈且無訊息/timeout。
- 不阻擋所有輸入卻沒有cancel/失敗路徑。

## 19. EmptyView

### 19.1 狀態

**TODO — Not Implemented。**

Current Inventory/Shop 用空slot或"No Item Selected"字串，沒有通用 view。

### 19.2 用途

- list/collection為空時提供原因與下一步。

### 19.3 Target Scene Tree

```text
EmptyView (CenterContainer)
└── Content (VBoxContainer)
    ├── Icon (TextureRect, optional)
    ├── Title (Label)
    ├── Description (Label)
    └── Action (Button, optional)
```

### 19.4 Target API

```gdscript
class_name EmptyView
extends CenterContainer

func configure(title: String, description: String) -> void
func set_action(label: String, visible: bool) -> void
```

### 19.5 Target signals

```gdscript
signal action_requested
```

### 19.6 Target Theme

- EmptyView typography/icon spacing。
- Action使用Primary/Secondary variation依語意。

### 19.7 使用時機

- shop無stock、inventory filter無結果、quest list空。

### 19.8 禁止事項

- 不把error當empty。
- 不只顯示空白panel。

## 20. ErrorView

### 20.1 狀態

**TODO — Not Implemented。**

### 20.2 用途

- 可恢復錯誤的訊息、重試、返回。

### 20.3 Target Scene Tree

```text
ErrorView (CenterContainer)
└── Content (VBoxContainer)
    ├── Icon
    ├── Title
    ├── Message
    └── Actions (HBoxContainer)
        ├── Back
        └── Retry
```

### 20.4 Target API

```gdscript
class_name ErrorView
extends CenterContainer

func configure(title: String, message: String, can_retry: bool) -> void
```

### 20.5 Target signals

```gdscript
signal retry_requested
signal back_requested
```

### 20.6 Target Theme

- semantic danger/warning surface。
- 不只紅色；含icon與文字。

### 20.7 使用時機

- load/network/resource失敗且使用者可回復。Current project目前無network UI。

### 20.8 禁止事項

- 不顯示敏感path/stack trace給player。
- 不由view自行重試domain operation。
- 不把validation empty state當system error。

## 21. 其他 Current Domain Components

### 21.1 HUDStatus

- path：`scenes/ui/hud/HUDStatus.tscn`
- used by：`scenes/ui/hud/HUD.tscn`
- script：無；由 `scripts/ui/hud.gd` 操作
- content：portrait、level/class、HP/MP/Stamina bars
- status：Current — Visual Only

### 21.2 HUDProgressPanel

- path：`scenes/ui/hud/HUDProgressPanel.tscn`
- used by：HUD
- tree：PanelContainer → VBox → Gold/EXP HBox rows
- script/signals：無
- status：Current — Visual Only

### 21.3 HUDQuestTracker

- path：`scenes/ui/hud/HUDQuestTracker.tscn`
- used by：HUD
- tree：Control → TextureRect + VBox labels
- API：父 HUD 的 `set_objective()`
- status：Current — Visual Only；不是 Quest system

### 21.4 HUDInteractionPrompt

- path：`scenes/ui/hud/HUDInteractionPrompt.tscn`
- used by：HUD
- tree：Control → Banner/PromptRow → Keycap + PromptText
- API：父 HUD 的 `set_interaction_prompt()`
- status：Current — Visual Only

### 21.5 Inventory domain components

Inventory static header、tabs、lists 與 detail panels 由唯一 owner
`InventoryUI.tscn` editor-authored；可重複動態行為集中在
`InventoryCodexPreview`。

### 21.6 Shop domain components

- `ShopDetailPanel.tscn`
- `ShopMerchantPanel.tscn`
- `ShopItemRow.tscn`

皆由 ShopUI 使用，無獨立 script/API；interaction由父controller管理。
`ShopItemRow` 已是 icon/name/stock/price 的結構化 row；`ShopDetailPanel` 提供
preview、可捲動描述、quantity 與 total；`ShopMerchantPanel` 提供 merchant
portrait、dialogue 與操作提示。

### 21.7 Town building service screens

- `scenes/ui/town/MaterialYardUI.tscn`
- `scenes/ui/town/PlayerBlacksmithUI.tscn`
- `scenes/ui/town/TownHallUI.tscn`
- `scenes/ui/town/TownServiceFrameTheme.tres`

三者是 domain screen，不是 generic component。它們共用 Full Rect modal、
safe-margin centered window、圖示化 header/resource/status/action pattern，並與
`ShopUI` 共用 `TownServiceFrameTheme` 的 window/portrait/title/Close variations；各自保留
獨立 script/API 與 service semantics。穩定 controls 在 Scene author；
PlayerBlacksmithUI 只動態建立 recipe row。不得抽成一個以 mode Dictionary重建
所有 layout 的通用 screen。

## 22. Unused / Prototype / Disabled Legacy Components

本節同時記錄沒有 production reference 的 prototype，以及仍被 production
scene 引用但 runtime 停用的 legacy 元件。每項必須以 status 明確區分。

### 22.1 Retired HUD prototypes

`HUDNavigationGroup`、`HUDCompass`、`HUDMinimap` 與 `HUDStatusBar` 因無
production owner 已移除。需要 navigation 或獨立 status bar 時，先建立明確
consumer/API 與測試，再新增 feature-owned component。

### 22.3 HUDHotbar

- path：`scenes/ui/hud/HUDHotbar.tscn`
- 被 HUD instance，但 HUD override為hidden；Attack/Skill也hidden。
- status：Current scene，runtime功能停用/legacy。

## 23. Code Examples

### 23.1 Screen 使用 visual-only InventorySlot

Current pattern：

```gdscript
func cache_slot(slot: PanelContainer, index: int) -> void:
	slot.mouse_filter = Control.MOUSE_FILTER_STOP
	slot.focus_mode = Control.FOCUS_ALL
	slot.focus_entered.connect(_on_slot_focused.bind(index))
	slot.gui_input.connect(_on_slot_gui_input.bind(index))
```

這說明行為在父controller，不表示slot有自己的API。

### 23.2 未來 component configure

```gdscript
func show_item(row: ItemCard, item: Dictionary) -> void:
	row.set_item(item.duplicate(true))
	if not row.item_selected.is_connected(_on_item_selected):
		row.item_selected.connect(_on_item_selected)
```

`ItemCard` 目前尚未實作；此例定義預期使用方式。

### 23.3 Intent signal

```gdscript
signal retry_requested

func _on_retry_pressed() -> void:
	retry_requested.emit()
```

Component emit intent，由owner決定重試。

## 24. Scene Tree Example

一個完整、可獨立測試的 future component：

```text
ItemCard (Button, class_name ItemCard)
└── Content (HBoxContainer)
    ├── IconFrame (AspectRatioContainer)
    │   └── Icon (TextureRect)
    └── Details (VBoxContainer)
        ├── Name (Label)
        ├── Metadata (Label)
        └── Quantity (Label)
```

必要契約：

- Button root處理focus/pressed。
- Container處理layout。
- script只投影與emit。
- Theme Variation處理states。
- test覆蓋empty/long/selected/disabled。

## 25. Godot Example (Godot 4)

以下是 future `ListRow` 的 Godot 4 typed component範例：

```gdscript
class_name ListRow
extends Button

signal row_selected(row_id: StringName)

@onready var primary_text: Label = %PrimaryText
@onready var secondary_text: Label = %SecondaryText

var _row_id: StringName

func configure(row_id: StringName, title: String, detail: String) -> void:
	_row_id = row_id
	primary_text.text = title
	secondary_text.text = detail

func _ready() -> void:
	pressed.connect(_emit_selection)

func _emit_selection() -> void:
	if _row_id.is_empty():
		return
	row_selected.emit(_row_id)
```

此 script/path 尚未存在；正式建立時必須有 scene、Theme與test同步。

## 26. Best Practice

- 先證明重用需求，再抽component。
- scene承擔layout，script承擔projection/intent。
- typed API取代父層deep NodePath。
- component資料輸入使用presentation model/duplicate。
- owner處理domain mutation。
- semantic Theme Variation取代複製StyleBox。
- focus/selected/disabled是獨立states。
- component有direct test與screen integration test。
- unused/prototype明確標示，不混入production catalog。

## 27. Anti Pattern

- 每個screen複製一個近似Button/Panel scene。
- 為單一node建立只有名字不同的薄scene。
- component直接找Game/manager。
- component解析顯示文字決定action。
- 用Dictionary卻不validate required keys。
- configure每次重複connect。
- 父screen修改component深層child而沒有contract。
- 將unused scene說成已上線。
- 將TODO tree/path說成已存在。
- 為了抽component同時重寫玩法。

## 28. Component Implementation Checklist

建立新元件前：

- [ ] 已搜尋相同scene/script/variation。
- [ ] 至少有明確重用或獨立測試價值。
- [ ] 已定用途與禁止用途。
- [ ] 已定root type與Scene Tree。
- [ ] 已定public methods與typed signals。
- [ ] 已定Theme Variation與所有interaction states。
- [ ] 已定empty/long/max/localized behavior。
- [ ] 已定focus/mouse/accessibility。
- [ ] 已定owner與cleanup。
- [ ] 已列direct/integration/resolution tests。
- [ ] 已同步本catalog與相關UI/Theme文件。

## 29. Review Checklist

- [ ] 狀態標籤與實際引用一致。
- [ ] path實際存在，或清楚標TODO target。
- [ ] Scene Tree與實際node一致。
- [ ] script/class/API實際存在，或清楚標未實作contract。
- [ ] signal producer/consumer一致。
- [ ] component沒有domain mutation。
- [ ] Theme/variation狀態誠實。
- [ ] focus/selected/disabled可並存。
- [ ] dynamic configure不重複node/signal。
- [ ] long/empty/max/localized content可用。
- [ ] mouse/keyboard/controller都有路徑。
- [ ] direct test與screen integration test存在。
- [ ] unused/prototype未被誤列production。
- [ ] Rule 2全部17個元件都有條目。

## 30. Future Extension

以下均為 Proposed：

1. Theme導入後先建立Primary/Secondary/Danger variations，不急著建立薄scene。
2. 將InventorySlot由visual-only提升為有typed API的component。
3. 將HUD三條duplicated bar收斂為StatusBar base + semantic variations。
4. 為 Shop dynamic ListRow 補上 generic configure API 與 empty/loading/error states。
5. 正式Quest model完成後建立QuestRow。
6. 建立通用Empty/Loading/Error states並在Inventory/Shop導入。
7. 建立custom Tooltip，支援focus與viewport clamp。
8. 若Card跨多screen真正需要共用，再抽SkillCard而保留CardHand fan layout ownership。
9. 新 component 必須先有 production owner，不讓 prototype 永久漂移。

## 31. Related Documents

- `docs/README.md`
- `docs/01_AI_GUIDE.md`
- `docs/02_PROJECT_ARCHITECTURE.md`
- `docs/03_SCENE_STRUCTURE.md`
- `docs/04_UI_GUIDE.md`
- `docs/05_CODING_STANDARD.md`
- `docs/06_RESOURCE_GUIDE.md`
- `docs/07_THEME_GUIDE.md`
- `docs/09_TESTING_GUIDE.md`
- `docs/10_DEBUG_GUIDE.md`
- `docs/12_GAME_DESIGN.md`
- `docs/13_ROADMAP.md`
- `docs/rule_1.md`

## 32. Autumn Battle UI Components

### AutumnHUD

- Scene: `res://scenes/ui/autumn/AutumnHUD.tscn`
- Script contract: `res://scripts/ui/autumn_combat_hud.gd`
- Owner: Autumn Battle V2 only
- Responsibility: the sole Autumn combat HUD authority. It owns
  `TopLeftStack`, `TopRightMeta`, `TopCenterStack`, `BottomStage`, `FooterRail`,
  and the embedded hand.

Required semantic children:

- `TopLeftStack/ObjectivePanel`
- `TopRightMeta`
- `TopCenterStack/BossHealth`
- `BottomStage/PlayerVitals`
- `BottomStage/ActivityFeed/FeedMargin/FeedRows/ComboSkillRows`
- `BottomStage/CardStage/ActionStrip/RedrawHand`
- `BottomStage/CardStage/AutumnCardHandUI`
- `BottomStage/ActivityFeed/FeedMargin/FeedRows/SkillToastStack`
- `FooterRail`

`ComboSkillRows` 是固定高度、會裁切溢位的 projection viewport；最多只投影最近
三種 Combo 能力，技能數量不得回推並放大 `ActivityFeed` 或 `BottomStage`。

`AutumnCardHandUI` 是 HUD 內的 presentation subtree，不是可被 map 或 `Game`
另外 adopt 的 sibling authority。

### AutumnInteractionPrompt

- Scene: `res://scenes/ui/autumn/AutumnInteractionPrompt.tscn`
- Script: `res://scripts/ui/autumn_interaction_prompt.gd`
- Owner: the Autumn HUD
- Responsibility: display the F interaction affordance near the active
  `CanvasItem`, follow moving targets, clamp to horizontal margins, and remain
  above the bottom-HUD boundary

### AutumnEditorHUDReference

- Scene: `res://scenes/maps/autumn_battle/editor/AutumnEditorHUDReference.tscn`
- Owner: `AutumnBattleMapV2.tscn`
- Responsibility: expose the exact runtime HUD instance in the map editor.
  Runtime adoption reparents this instance（連同內嵌 hand）；不得 recreate、
  normalize geometry 或再掛獨立 hand。

### AutumnBattleCard

- Scene: `res://scenes/ui/autumn/AutumnBattleCard.tscn`
- Script: `res://scripts/ui/autumn_battle_card.gd`
- Owner: `AutumnCardHandUI`
- Public methods:
  - `configure(card: Dictionary, shortcut: String, affordable: bool)`
  - `set_row_active(active: bool, affordable: bool)`
  - `set_affordable(affordable: bool)`
  - `set_hovered(hovered: bool)`
- Responsibility: present a tall, structured dark-fantasy card while keeping
  the root `Button` as the single input and focus owner

### AutumnCardHandUI renderer

- Script: `res://scripts/ui/autumn_card_hand_ui.gd`
- Owner: `AutumnHUD/BottomStage/CardStage`
- Responsibility: create AutumnBattleCard instances, keep card groups in
  two stable scene-authored rows of four, calculate responsive card dimensions,
  overlap the rows, and apply active/inactive group presentation
- Input contract: Q/W/E/R play the single four-card Combo／Healing hand；no group-toggle input
- Exclusion: auto attack is not a card button and has no hand/global index
- Exclusion: intrinsic Space Dash is not a card button；`quickstep` is absent
  from the catalog and hand
- Isolation: Town continues to use `res://scripts/ui/card_hand_ui.gd`; Autumn
  visual changes must not be added to the shared renderer

### DeckBuilderUI loadout

- Scene: `res://scenes/ui/cards/DeckBuilderUI.tscn`
- Script: `res://scripts/ui/deck_builder_ui.gd`
- Signals:
  - `loadout_confirmed(deck_ids: Array[String], auto_attack_card_id: String)`
  - legacy `deck_confirmed` remains compatibility-only
- Responsibility: select 1–16 ordinary backpack cards and one independent
  unlocked attack card for auto attack
- Rule: auto attack does not consume a deck slot；the selector is unavailable
  during an active Run

### CombatStatusController

- Scene: `res://scenes/combat/CombatStatusController.tscn`
- Script: `res://scripts/combat/combat_status_controller.gd`
- Owner: Player
- Responsibility: timed super armor, damage reduction, lifesteal,
  regeneration and retaliation; emit status projection for HUD
- Rule: same source refreshes, strongest armor tier wins, reduction caps at
  60%, and timer pause must follow the growth modal pause token

### Elemental combat VFX

- Scenes: `res://scenes/combat/vfx/ElementalAttackAura.tscn`,
  `FireUltimateVFX.tscn`, `IceUltimateVFX.tscn` and
  `SkillCastPresentation.tscn`
- Status: Current — Used
- Owner: `Game` maps card data to VFX; `CardEffectRunner` retains damage authority
- Contract: fire/frost aura layers stack, ultimate radius mirrors gameplay radius,
  screen title ignores time scale, and short-lived world effects clean themselves up
- Rule: callers configure reusable APIs; they do not duplicate particles or infer
  gameplay damage from visual geometry

### CardGrowthUI

- Scene: `res://scenes/ui/cards/CardGrowthUI.tscn`
- Script: `res://scripts/ui/card_growth_ui.gd`
- Owner: `Game/MenuLayer` while the growth queue is non-empty
- Signal: `choice_confirmed(choice_id: String)`
- Responsibility: render one `GrowthChoiceQueue` page and expose a single
  selected choice; it does not mutate deck, fusion materials, Meta or resources
- Layout: at most five growth choices, centered as three cards above two cards
- Replaces: Autumn Blessing popup and `LevelUpUI` in the card-growth flow
- Choice presentation: semantic card color、catalog icon、compact AP/level header，
  current/next effects use bullet lines; tooltip retains the complete display text.

### SkillToastStack

- Owner: `AutumnHUD/TopCenterStack`
- Responsibility: transient “used skill” projection only
- Contract: maximum three entries; duplicate skill refreshes; each entry fades
  after about 1.5 seconds; no permanent recipe-progress rows

## 33. Town Eternal Forge UI Components

### TownEternalForgeHUD

- Scene: `res://scenes/ui/town/TownEternalForgeHUD.tscn`
- Script contract: `res://scripts/ui/hud.gd`
- Owner: Town only
- Responsibility: display only the compact Eternal Forge area title and active
  interaction affordance in Town. The unused Flame Keeper, Soul Network,
  player-resource, commission, and ledger panels remain hidden while their
  compatibility NodePaths stay available to `hud.gd`.
- Layout: Full Rect; the area title is compact at top center and the interaction
  prompt uses a narrow bottom safe area without reserving a persistent lower HUD.
- Data boundary: this scene only accepts Game projections through the existing
  HUD API. It does not invent an Eternal Flame progression value or query
  `TownManager`.

### TownCardHandUI

- Scene: `res://scenes/ui/town/TownCardHandUI.tscn`
- Base: `res://scenes/ui/cards/CardHandUI.tscn`
- Script contract: `res://scripts/ui/card_hand_ui.gd`
- Owner: Town's sibling card-hand authority
- Responsibility: preserve CardHandUI signals, methods, NodePaths, and fan
  layout while applying the Eternal Forge iron/ember/gold presentation.

### TownEternalForgeEditorHUDReference

- Scene: `res://scenes/maps/town/editor/TownEternalForgeEditorHUDReference.tscn`
- Owner: `res://scenes/maps/town/TownMap.tscn`
- Runtime contract: `Game.load_hud()` adopts its exact `HUD` and sibling
  `CardHandUI` instances into `HUDLayer`; other maps continue using their own
  editor references.
- Verification: HUD layout and prompt reservation are contract-tested at
  1152×720, 1280×720, 1600×900, 1920×1080, 2560×1080, and 2560×1440.
