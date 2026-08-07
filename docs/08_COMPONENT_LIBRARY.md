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
| InventoryCodexPreview | Current — Presentation | `scripts/ui/inventory/inventory_codex_preview.gd` |
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
- script：`scripts/ui/dialogue/dialogue_ui.gd`
- class：`DialogueUI`

它是 NPC/campfire/card reward 共用的 dialogue screen，不是通用 confirmation Dialog，
也不是 Godot `Window`/`AcceptDialog`。

### 7.2 Current Scene Tree

```text
DialogueUI (Control, Full Rect)
├── PortraitFrame (Panel, upper-left)
│   ├── PortraitPlaceholder
│   │   └── PortraitInitial
│   └── AnimatedPortrait (TownNPCPortrait)
└── DialoguePanel (Panel)
    ├── SpeakerNamePlate
    │   └── SpeakerName
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
func present_story_line(line: Dictionary, speaker: Dictionary) -> bool
```

`present_story_line()` 會清除一般 NPC choices、投影 speaker/text，並用 speaker 的
validated atlas contract 切換逐幀頭像與 authored emotion。靜態商店肖像仍可沿用
`TownNPCPortrait.set_character_texture()`，兩種模式不可同時顯示。

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

`scripts/ui/cards/card_hand_ui.gd` 在 runtime 建 Button，包含 name/type/level/description/cost，
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

- script：`scripts/ui/inventory/inventory_codex_preview.gd`
- owner：`scenes/ui/inventory/InventoryUI.tscn`
- API：`show_entry()`、`get_active_entry_id()`、`get_preview_kind()`
- reuse：`ElementalAttackAura`、`FireUltimateVFX`、`IceUltimateVFX`、`NamedSkillVFX`、
  `StormChargeVFX`
- boundary：只顯示 projection，不計算傷害、不解鎖 discovery、不 mutation save
- sibling presentation：玩家圖鑑只顯示此 production `LIVE VFX` component；舊
  concept boards 與 tabs 維持隱藏。現役招式 projection 固定來自 13 系列、39 招的
  skill catalog，包含系列、基本／進階／大師階級、定位、描述與動畫節拍
- compatibility：39 招暫時以 `legacy_vfx_map` 重用既有 named VFX；component 只播放
  `named_vfx_id`，不得用 profile display name 或舊 trigger 類型改寫招式資料
- fit contract：live frame 使用 `190px` 橫向施放舞台，人物位於左側並縮小、招式在
  同一平地向右施放；命名終結技以 authored diameter、
  完整 travel 與 `0.82` ground anchor 計算縮放／起點，不受舊 `preview_scale` 縮小上限
  限制；圖鑑可把 world directional travel 壓到最多 `220px`，但不可改戰鬥移動距離，
  所有主體和軌跡須放到最大安全尺寸並留在 clip rect
- storm contract：`preview_kind = storm_charge` 時實例化 production 專用 scene，位置固定
  為預覽水平中央與 floor y，不得退回 attack aura 或玩家攻擊 sheet
- tooltip/quantity/selection由父層注入。
- 無 empty/disabled/locked state API。
- 20 slots固定。

### 12.8 禁止事項

- 不在其他 screen 直接假設 Quantity runtime child 一定存在。
- 不把 visual-only scene描述成完整 reusable API。
- 不讓slot直接改 inventory model。

### 12.9 InventoryJournal owner contract

- owner：`scenes/ui/inventory/InventoryUI.tscn`
- chapter modes：`bag`、`status`、`sword_souls`、`codex`
- authored parts：open-journal background、四個 icon tabs、四個 page containers、filters、
  lists、status/equipment slots、detail panels、equip action
- filter contract：Bag 與 Codex 的 `Filter` 都是常駐 `GridContainer` Button 集合，
  以 `metadata/filter_id` 保存 stable category；Inventory subtree 不得出現 `OptionButton`
- Codex filter IDs：`techniques`、`enemies`、`sword_souls`、`equipment`、`blessings`、
  `story_review`；`blessings` 顯示完整 8 個 base＋10 個 evolved catalog，Run ownership
  只影響右頁狀態文案
- public projection API：`set_items()`、`set_player_status()`、
  `set_equipment_entries()`、`set_sword_souls()`、`set_codex_entries()`
- technique ordering：`set_codex_entries()` 對 39 招使用 projection 的
  `skill_series_rank`／`tier_rank` 重建 13 組 catalog 順序；系列標題列不可選，
  每組招式列固定為基本／進階／大師，且 row-to-entry mapping 必須保持 keyboard、
  programmatic selection 與 scroll-to-selection 正確
- series header state：深色底條搭配亮金文字，不設 disabled；只用 non-selectable
  保留完整對比並阻止 selection
- technique detail order：`description` 直接以書名號與斜體顯示 1～2 句引言，
  `recipe_summary` 只顯示三張劍魂名稱與順序，不帶持有或編成狀態；招式頁不投影或顯示
  `effect_summary`，也不顯示系列語彙、特效狀態、逐張劍魂效果或演出流程。
  `Recipe` 是 editor-authored Label，不由 runtime 重建
- action boundary：`equip_requested(item_id)`；父 Game 驗證、mutation、save 與 refresh
- story review boundary：`story_review_requested(sequence_id)` 只要求父 Game 以既有
  `DialogueUI` 啟動 read-only review；完成後返回 `story_review` 分類，不修改 story flags
- empty/selection/focus：每頁 deterministic initial focus；同一時間恰好一個 page visible
- safe area：底部保留 32px page-curl inset；Codex Info 的 Panel 內嵌 vertical
  ScrollContainer、26px unpainted footer 與 scroll-content BottomInset
- visual boundary：招式使用 `InventoryCodexPreview`；敵人／劍魂／裝備／神賜使用 static icon；
  神賜 icon 必須直接採用正式 base attack object 或 evolved subject asset；
  劇情回顧不偽造技能 VFX，而顯示播放動作與文字摘要

## 13. HealthBar

### 13.1 狀態

**Partial — Unused candidate + active duplicated subtree。**

舊 `HUDStatusBar.tscn` prototype 已於 scene cleanup 移除；目前沒有獨立
HealthBar scene，production HUD 仍使用內嵌 subtree。

現役 health bar：

- `scenes/ui/hud/HUDStatus.tscn` 的 `HPBar`
- 由 `scripts/ui/hud/hud.gd::set_health()` 更新

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
- `scripts/ui/hud/hud.gd::set_mana()`

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
- script：無；由 `scripts/ui/hud/hud.gd` 操作
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

皆由 ShopUI 使用；interaction與商品資料綁定仍由父controller管理。
`ShopItemRow` 已是 icon/name/stock/price 的結構化 row；`ShopDetailPanel` 提供
preview、可捲動描述、quantity 與 total；`ShopMerchantPanel` 提供 merchant
portrait、dialogue 與操作提示。其 `MerchantPortrait` instance 下述
`TownNPCPortrait`，而不是自行擁有 atlas region 或動畫 controller。

### 21.6.1 TownNPCPortrait

- Scene：`scenes/ui/town/TownNPCPortrait.tscn`
- Script：`scripts/ui/town/town_npc_portrait.gd`
- Consumers：`ShopMerchantPanel`、`MaterialYardUI`、`PlayerBlacksmithUI`、`TownHallUI`
- API：`set_character_texture()`、`play_state()`、`advance_animation()`、
  `get_active_state()`、`get_supported_states()`
- Responsibility：在共同 `218×252` Town service portrait frame 中裁切新 NPC 半身，
  並以 5 FPS 離散 cadence 呈現 idle、聊天、說笑與情緒 pose。
- Boundary：只擁有人物 texture、裁切與 presentation transform；姓名、台詞、商店
  context、交易與 focus 仍由各 screen owner 管理。

### 21.7 Town building service screens

- `scenes/ui/town/MaterialYardUI.tscn`
- `scenes/ui/town/PlayerBlacksmithUI.tscn`
- `scenes/ui/town/TownHallUI.tscn`
- `scenes/ui/town/TownServiceFrameTheme.tres`

三者是 domain screen，不是 generic component。它們共用 Full Rect modal、
safe-margin centered window、圖示化 header/resource/status/action pattern，並與
`ShopUI` 共用 `TownServiceFrameTheme` 的 window/portrait/title/Close variations；各自保留
獨立 script/API 與 service semantics。穩定 controls 在 Scene author；
PlayerBlacksmithUI 只在 authored `RecipeList` 動態建立 recipe row，並在 authored
`SaleCandidateList` 動態建立品質販售 row。不得抽成一個以 mode Dictionary重建
所有 layout 的通用 screen。Forge method、pricing strategy、RumorBoard 與
ShopDetailPanel 的 BlueprintSchoolPanel 均為 editor-authored controls；runtime 只更新
狀態、文字、選項與 focus，不建立第二套彈窗或動態幾何。

### 21.8 PauseMenu dev map selector

- Scene：`scenes/ui/system/PauseMenu.tscn`
- Script：`scripts/ui/system/pause_menu.gd`
- Owner：`Game/MenuLayer`
- Status：Current — Used（dev mode only）
- API：`configure_dev_mode(enabled, map_entries)`
- Intent：`dev_map_requested(scene_path: String)`
- Responsibility：以預設 hidden 的 `DevMapPanel` 投影 Game 注入的地圖名稱與 path，
  並維持 ButtonStack／SettingsPanel／DevMapPanel 三者互斥與 focus 返回。
- Boundary：不得讀取 ProjectSettings、MapRegistry、RunState 或直接載入 map；測試
  Run 捨棄、路徑驗證、戰鬥 Run 建立與 save isolation 全由 Game／DevModeService 擁有。

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
- Script contract: `res://scripts/ui/autumn/autumn_combat_hud.gd`
- Owner: Autumn Battle V2 only
- Responsibility: the sole Autumn combat HUD authority. It owns
  `TopLeftStack`, `TopRightMeta`, `TopCenterStack`, `BottomStage`, `FooterRail`,
  and the embedded hand.

Required semantic children:

- `TopLeftStack/ObjectivePanel`
- `TopRightMeta`
- `TopCenterStack/BossHealth`
- `BottomStage/PlayerVitals`
- `BottomStage/PlayerVitals/VitalsMargin/VitalsRows/IdentityRow/Identity/ExperienceHeader`
- `BottomStage/PlayerVitals/VitalsMargin/VitalsRows/IdentityRow/Identity/XPProgress`
- `BottomStage/ActivityFeed/FeedMargin/FeedRows/ComboSkillRows`
- `BottomStage/CardStage/ActionStrip/RedrawHand`
- `BottomStage/CardStage/AutumnCardHandUI`
- `BottomStage/ActivityFeed/FeedMargin/FeedRows/SkillToastStack`
- `FooterRail`
- `FooterRail/FooterRow/DashHint`

`ComboSkillRows` 是固定高度、會裁切溢位的 projection viewport；最多只投影最近
三種 Combo 能力。`ComboSummary`、`ComboMilestones` 與所有 runtime rows 必須設定
`clip_text` 與 ellipsis，並以 tooltip 保留完整字串；技能或終結技名稱不得回推並放大
`ActivityFeed` 或 `BottomStage`。有待施放終結技時，`ComboSummary` 只投影招式名稱，
`ComboMilestones` 另行投影祝福冠名；完整冠名名稱只放在 tooltip。

`ActionStrip` 是為既有 scene path 保留的隱藏 compatibility subtree，不占 runtime
高度。`SPACE 衝刺` 必須由 `FooterRail/FooterRow/DashHint` 投影，讓手牌吃滿
`CardStage` 的上緣到下緣。

`AutumnCardHandUI` 是 HUD 內的 presentation subtree，不是可被 map 或 `Game`
另外 adopt 的 sibling authority。其 `FrontRow` 固定含四個等寬 slot，compatibility
`BackRow` 必須 hidden 且不參與垂直 stretch；slot 負責橫向分布，card renderer 以
`EXPAND_FILL` 同時吃滿 slot 寬高，不鎖定牌面比例；黑金塔羅
框與滿版主插畫跟著 slot 響應，hover 只上浮、不橫向放大侵入相鄰格。

`PlayerVitals` projects HP, AP, level, and XP supplied by `Game`. XP displays
`current / required · NEXT remaining` with a cyan progress bar. HP loss, AP
recovery, XP gain, and level gain use short restartable scale/color emphasis;
the HUD never reads gameplay state directly.

### AutumnInteractionPrompt

- Scene: `res://scenes/ui/autumn/AutumnInteractionPrompt.tscn`
- Script: `res://scripts/ui/autumn/autumn_interaction_prompt.gd`
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
- Script: `res://scripts/ui/autumn/autumn_battle_card.gd`
- Owner: `AutumnCardHandUI`
- Public methods:
  - `configure(card: Dictionary, shortcut: String, affordable: bool)`
  - `set_row_active(active: bool, affordable: bool)`
  - `set_affordable(affordable: bool)`
  - `set_hovered(hovered: bool)`
  - `get_visual_family() -> String`
- Responsibility: present a structured dark-fantasy card while keeping
  the root `Button` as the single input and focus owner. The fixed Autumn hand
  maps every formal card to generated 256×256 text-free source art under
  `res://assets/ui/autumn/cards/generated/`, composes it with aligned 1173×1341
  celestial-halo, spectral-raven, and vines/smoke layers, adds an adjustable code-native
  geometric frame with globally timed gold charge and a 60-ray 360-degree sacred-geometry
  sunburst behind black-keyed card art（combat hides the concentric halo layer）, stretches that 7:8 composition to the authored battle slot, and exposes
  Healing／Flame／Volley／Storm visual families.
- Filtering: generated card paths use linear filtering at HUD scale; curated pixel-art
  fallbacks remain nearest-filtered.
- Typography: `CardName`／metadata／shortcut／AP 共用 `Noto Serif TC` 優先的繁中
  襯線 stack；短招式名以 17–18px 顯示，長名稱最低 12px 且獨占底部卷軸名牌，類型顯示「連段／治療」而不是
  `COMBO／HEALING`。
- Input/AP hierarchy: `Shortcut` 使用左上 32–36px、至少 18px 的圓形鍵印；右上圓章
  顯示依 Healing／Flame／Volley／Storm 上色且可辨識的種類 icon；`CostRow`
  使用右下 34–38px 圓章且只顯示至少 20px 的 AP 數字，不重複 `AP` 文字。`Level` 在戰鬥卡面隱藏，不投影永久層數。
  `IconStage` 必須在中文分類框上緣前結束；中文分類使用四邊舊金框的暖墨 tab 且至少佔 60% 卡寬。
  `CardName` 銘牌右界依 AP 圓章位置計算，最多兩行、超出省略，完整名稱保留於 tooltip。四張牌不得新增
  表格分隔線、全卡不透明色塊或元素色霓虹外框。
- Cast feedback: 成功施放後只有相符 card id 的卡片播放約 0.42 秒最上層儀式弧光、
  12 根短放射刻線、三圓章閃光與主圖 punch；不得使用矩形遮罩，也不得重置日芒或外框的全域相位。

### AutumnCardHandUI renderer

- Script: `res://scripts/ui/autumn/autumn_card_hand_ui.gd`
- Owner: `AutumnHUD/BottomStage/CardStage`
- Responsibility: create AutumnBattleCard instances in the single active
  scene-authored `FrontRow`, keep the compatibility `BackRow` hidden with no reserved height, distribute
  four equal `MarginContainer` slots across the entire hand width, calculate a
  responsive `148–320px` minimum height without an aspect-ratio lock, and apply
  affordability/hover presentation
- Input contract: Q/W/E/R play the single four-card Combo／Healing hand；no group-toggle input
- Exclusion: auto attack is not a card button and has no hand/global index
- Exclusion: intrinsic Space Dash is not a card button；`quickstep` is absent
  from the catalog and hand
- Isolation: Town continues to use `res://scripts/ui/cards/card_hand_ui.gd`; Autumn
  visual changes must not be added to the shared renderer

### DeckBuilderUI loadout

- Scene: `res://scenes/ui/cards/DeckBuilderUI.tscn`
- Script: `res://scripts/ui/cards/deck_builder_ui.gd`
- Signals:
  - `loadout_confirmed(deck_ids: Array[String], auto_attack_card_id: String)`
  - legacy `deck_confirmed` remains compatibility-only
- Responsibility: keep one fixed Healing in slot 1, select three unique formula
  Sword Souls in slots 2–4, plus one independent unlocked auto-attack card
- Rule: auto attack does not consume a deck slot；the selector is unavailable
  during an active Run
- Presentation: catalog icons、green Healing／purple Combo cues、selected gold
  state and animated double-frame／ring／traveling-light geometry；the centered
  panel scales from 1.0 to 1.75 across the required viewports
- Interaction: candidate hover or keyboard focus previews the exact Sword Soul
  effect immediately；focus navigation owns explicit two-column neighbors and
  calls `ScrollContainer.ensure_control_visible()` when moving off-screen. Deferred
  visibility requests must first verify that the target remains a live descendant
  of that scroll container. Recipe selection rebuilds the dynamic list, then
  restores the previous scroll region and transfers focus to the replacement
  button resolved by stable skill ID. The
  named-skill selector lists the same 39 official skills as the Codex, resolves
  `legacy_vfx_id`, and unions each selected recipe's `required_skills` into
  slots 2–4；compatible recipes remain normal/interactive, while missing or
  over-capacity recipes stay visible with disabled grey text. The slots remain
  above one exclusive selection workspace；`SwordSoulSelector` and
  `SkillRecipeSelector` switch through `SelectionModeBar` and never stack
  simultaneously. Recipe choices render 13 catalog-ordered series sections；
  each section exposes basic／advanced／master as one three-column tier row

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

### CombatVFXFoundation

- Script: `res://scripts/combat/combat_vfx_foundation.gd`
- Owner: runtime `NamedSkillVFX` instance
- Status: Compatibility — instantiated only when current recipe configuration fails
- Contract: two independently scrolling slash passes plus flash, flare, shockwave and
  sparks at the shared impact beat; Fire also enables dissolve, flame, smoke, ember and
  explosion layers
- Boundary: receives only series/tier/timeline presentation data and never decides hits,
  damage, Combo state or player movement

### SkillVFXComposer2D

- Scene: `res://scenes/vfx/SkillVFXComposer2D.tscn`
- Scripts: `skill_vfx_composer_2d.gd`, `skill_vfx_recipe_catalog.gd`,
  `blessing_vfx_mutation_catalog.gd`
- Owner: static child of `NamedSkillVFX`
- Status: Current — production renderer for all 13 series / 39 skills
- Contract: composes the 15-role Skill VFX Grammar, preserves the current series texture as
  Core, exposes deterministic `set_progress()`, and resolves stacked Blessings into palette,
  count, trajectory, trail, impact and residue changes
- Boundary: visual geometry never decides gameplay target, hit, damage, status or player motion;
  one combined Core shader is used instead of stacking unsupported CanvasItem materials
- Review: five pure-VFX scenes under `scenes/vfx/demos/` exercise the production component

### SwordRainMaterialVFX2D

- Scene: `res://scenes/vfx/skills/SwordRainMaterialVFX2D.tscn`
- Script: `res://scripts/vfx/sword_rain_material_vfx_2d.gd`
- Shaders: `sword_rain_energy.gdshader`, `sword_rain_trail.gdshader`
- Owner: static child of `NamedSkillVFX`; active only for `sword_rain`
- Contract: preserve the sword Core silhouette; synchronize staggered summon, separated concentric
  orbit groups, 0.8-second lock charge, grouped snap release, insertion hold, and decay; give every
  blade two sword-shaped aura layers, three independent material trails, and one six-role impact
  stack; the 10/15/20 formations release as two/three/four five-blade volleys
- Boundary: replaces generic Rain/Projectile/Trail/Ring/Impact presentation only; live target input
  may update visual Hurtbox centers and retarget after node removal, but hit, damage, Combo, tier
  ownership, and Blessing gameplay remain outside this component

### FeatherHaloMaterialVFX2D

- Scene: `res://scenes/vfx/skills/FeatherHaloMaterialVFX2D.tscn`
- Script: `res://scripts/vfx/feather_halo_material_vfx_2d.gd`
- Shaders: `feather_halo_energy.gdshader`, `feather_halo_trail.gdshader`
- Owner: static child of `NamedSkillVFX`; active only for `feather`, while the live effect instance
  is the player's unique `ActiveFeatherHaloVFX`
- Contract: point every feather root inward, stagger entry into a rotating 3/7/15-feather halo,
  expose catalog-driven lifetime/fade/stagger/speed/radii, layer an energy aura and two arc trails
  per feather plus a two-layer readable light wheel, replenish the existing halo on repeated casts,
  and dissolve individual feathers sequentially across the final duration window
- Boundary: replaces generic Projectile/Trail/Afterimage/Ring/Impact presentation only; gameplay
  remains the sole owner of contact checks, periodic damage, knockback and Combo

### FeatherHaloDamageController

- Scene: `res://scenes/combat/FeatherHaloDamageController.tscn`
- Script: `res://scripts/combat/feather_halo_damage_controller.gd`
- Owner: player's unique runtime child while a Feather halo has been activated
- Contract: query current enemies every 0.18 seconds, use Hurtbox-aware radial contact, repeatedly
  damage and push only enemies touching the halo, and refresh the same controller on a fast recast;
  3/7/15 feathers use progressively longer 4.8/6.4/8.8-second fields
- Boundary: no homing, projectile travel or visual nodes; emits contact positions so the separate
  material renderer can show impact feedback

### LayeredVFXPrimitive2D

- Scene roots: `res://scenes/vfx/primitives/<element>/<primitive>.tscn`
- Script: `res://scripts/vfx/layered_vfx_primitive_2d.gd`
- Support primitives: `ParticleBurst2D`, `LightningGenerator2D`, `TrailHistory2D`
- Status: Current — Reusable presentation library used by Skill VFX impact composition
- Contract: 火／雷／水／毒／冰／風各三個原語，每個至少五個語意 layer；公開 color、
  intensity、lifetime、scale、speed、direction、particle amount、noise、glow、
  `play()`、`stop()`、visual bounds 與 particle budget
- Boundary: 不接 target、damage、status、Combo 或 card data；正式招式只負責排列、時序
  與參數化，不複製 shader／粒子實作
- Review: 每個 primitive 對應 `scenes/vfx/demos/*_demo.tscn`，全庫總覽使用
  `VFXLibraryDemo.tscn`

### PremiumCrescentLayer

- Scene owner: `res://scenes/combat/AutoAttackFeedback.tscn`
- Script: `res://scripts/combat/premium_crescent_layer.gd`
- Texture: `res://assets/generated/vfx/basic_attack_crescent_quality_atlas_v3.png`
- Status: Current — Used
- Responsibility: 以 additive blend 拼裝普通劍氣的外光、白核、內流、三重拖尾、
  貼地切線、碎光、接觸爆點與破碎消散
- Boundary: 只讀 parent 提供的 travel／impact progress、方向、scale 與 Combo tier；
  不擁有 hitbox、damage、target 或元素規則

### CardGrowthUI

- Scene: `res://scenes/ui/cards/CardGrowthUI.tscn`
- Script: `res://scripts/ui/cards/card_growth_ui.gd`
- Owner: `Game/MenuLayer` while the growth queue is non-empty
- Signal: `choice_confirmed(choice_id: String)`
- Responsibility: render one `GrowthChoiceQueue` page and expose a single
  selected choice; EXP pages show new／upgraded Blessings, elite／boss pages show
  owned Blessing upgrades／merges, and all-max EXP pages show resource fallback.
  It does not mutate Blessing inventory, fusion materials, Meta or resources
- Layout: at most five normal growth choices, centered as three cards above two cards；
  Divine Gift 的三個直接選項則等寬填滿第一列
- Responsive modal: width follows the safe viewport up to 1580px；height stays within
  620–680px so wide／high displays do not create an unfinished empty gulf below the cards
- Replaces: Autumn Blessing popup and `LevelUpUI` in the card-growth flow
- Choice presentation: semantic card color、catalog icon、compact AP/level header，
  current/next effects use bullet lines; tooltip retains the complete display text.

### DivineGiftChoiceCard

- Scene: `res://scenes/ui/cards/DivineGiftChoiceCard.tscn`
- Script: `res://scripts/ui/cards/divine_gift_choice_card.gd`
- Owner: `CardGrowthUI` 的 Divine Gift page only
- Responsibility: 以近黑褐卡身、舊金雙框、環形秘儀紋與大型符印呈現一項神賜；
  顯示中文名稱、等級變化、效果類型、短 lore 與 2–3 條由 `next_effects`／
  `finisher_mutations` 投影的具體數值或 mechanics。
- Selection contract: selected card 使用實心「已選」badge、4px 金框與至少 10px
  金色光暈；hover／keyboard focus 不得偽裝成已選狀態。`SelectionSummary` 同步顯示
  所選名稱與前兩項效果，完整資訊保留在 tooltip。
- Boundary: component 只格式化 queue 已提供的 projection，不讀 catalog、不計算或套用
  Divine Gift 戰鬥效果。

### SkillToastStack

- Owner: `AutumnHUD/TopCenterStack`
- Responsibility: transient “used skill” projection only
- Contract: maximum three entries; duplicate skill refreshes; each entry fades
  after about 1.5 seconds; no permanent recipe-progress rows

## 33. Town Eternal Forge Components

### TownNPCLife / TownNPCVisual

- Scripts：`res://scripts/npc/town_npc_life.gd`、`res://scripts/npc/town_npc_visual.gd`
- Consumers：Town traveler、witch、guard、item merchant、blacksmith、innkeeper scenes
- Status：Current — Active Runtime Presentation
- Responsibility：`TownNPCLife` 在 authored home 附近選擇待機、休息、情緒、角色化
  work／look／stretch、散步與鄰居社交；社交依序執行靠近、greet、chat／work、reaction、
  farewell、return-home。每個本地活動完成後先進入 configured idle recovery，無事件 ambient
  emotion 只允許 friendly states，且不得連續重複相同活動／情緒。`TownNPCVisual` 播放共同
  4 × 13 atlas state 與左右面向；walk 維持 5 FPS，chat 為 2 FPS，idle／sit 為 1 FPS，
  look／stretch／greet／work／emotion gesture 則以 2 FPS one-shot 播放後停留，不得短循環成
  GIF。女巫與科學家可由各自 4 × 17 atlas 追加
  角色專屬工作 state。專屬四幀以 2 FPS one-shot 播放、短暫 hold 後回到 1 FPS 細微待機，
  不能在長工作期間反覆播放或凍結最後一格。
  八位 resident／visitor 的 authored emotion row 4–8 都是 132 px、腳底 `y=144`，runtime
  不再額外縮放或 bob 這些幀。女巫 directional source 原生朝左，flip 必須依 requested
  facing 與 native facing 的差異計算。
- Coordination：`town_life_npcs` group 只用於尋找可用鄰居；配對持有 partner、catalog
  preferred distance、session familiarity、per-partner cooldown 與較少互動者優先的公平選擇。
  角色 profile 的雙方 allowlist 交集限制可選 interaction。祭司或 visitor 使用
  external-interaction lock 時，既有配對會安全取消，第三位 NPC 不得搶走居民。meeting
  targets 與第三位 NPC 的 current／home／reserved social position 至少相隔 120 px；找不到
  安全位置時取消本次邀請，不得退回會重疊的 midpoint。
- Cadence：一般 idle 預設 5.5–10 秒；profile role activity 後 recovery 預設 10–16 秒；
  greet／reaction／farewell 約 1.8／1.8／1.4 秒，chat 基準 7 秒並有小幅 deterministic RNG
  變化，最近 partner 冷卻預設 75 秒。女巫主動機率為 12%，所有 autonomous／external chat
  後至少保留 150 秒全域社交 recovery。測試可縮短 export，但正式 scene 不得壓回快速輪播。
- Boundary：不擁有建築互動、商店、gameplay dialogue、NavMesh、quest 或 persistent
  schedule；TownBuildingEntrances 與既有 Game controller 仍是互動 authority。

### PriestTownBehavior / PriestAnimatedSprite

- Scripts：`res://scripts/npc/priest_town_behavior.gd`、`res://scripts/npc/priest_animated_sprite.gd`
- Consumer：`res://scenes/npc/town/Mayor.tscn`（外部 compatibility name）
- Status：Current — Active Runtime Presentation
- Responsibility：wait-home 可進入 profile-driven prayer／bless／comfort／share-goods
  home activity；只有 noon／afternoon／evening、visit cooldown 結束且女巫可社交時才執行
  walk-to-witch → chat-with-witch → walk-home。home 與 route 共用 Town NPC
  `y=672`／`z_index=0`。祭司停在女巫左側 95 px，祭司朝右、女巫朝左聊天。
  wait-home 會在 front idle 與既有 side-chat row 的 calm 三分之四 `side_idle` 間交替；side idle
  只做一次輕微轉向後停在非正面姿勢，不得循環成聊天 GIF。
- Event boundary：courage 動畫只由明確危險／保護事件呼叫，不得放進無事件 ambient schedule。
  科學家的 malfunction 同樣只由明確試機失敗事件呼叫；inspiration 使用正向完成姿勢，
  不得先播放冒煙故障。
- Boundary：route offset 為 `0`；舊的前景繞行／較高 z layer 不是 current contract。
  女巫只由 external-interaction lock 暫停，祭司不得接管她的 autonomous state。

### TownNPCInteractionCatalog

- Data：`res://data/town_npc_interactions.json`
- Script：`res://scripts/npc/town_npc_interaction_catalog.gd`
- Consumers：`TownNPCLife`；visitor eligibility 也由相同 selector contract 查詢
- Status：Current — Static Presentation Catalog
- Responsibility：all-or-nothing 驗證並以 deep copy 回傳 greet、chat、laugh、gossip、
  comfort、share_goods、discuss_work、watch_sky、farewell 九種 interaction；每筆定義
  兩名 participant 的 role／archetype、animation sequence、duration、social distance、
  cooldown、weight、priority、visitor eligibility 與 directionality。
- Determinism：catalog 固定排序；weighted selection 的 normalized roll 由 caller 注入，
  catalog 不持有 RNG、relationship、movement、partner 或 interaction state。

### TownNPCCharacterProfileCatalog

- Data：`res://data/town_npc_character_profiles.json`
- Script：`res://scripts/npc/town_npc_character_profile_catalog.gd`
- Consumers：`TownNPCLife`、`PriestTownBehavior`
- Status：Current — Static Presentation Rhythm Catalog
- Responsibility：all-or-nothing 驗證祭司、女巫、科學家的連續六時段資料、logical locations、
  最短停留、角色專屬 ambient actions 與 partner interaction allowlist；getter 一律 deep copy。
- Boundary：只驅動 Town 的短期 presentation rhythm，不擁有 quest、dialogue、NavMesh、存檔或
  persistent simulation；movement speed、scene path 與 gameplay authority 不得寫入此 catalog。
  Profile 角色不得隨機播放 generic sit；坐下必須由有座位與專用姿勢的 authored event 觸發。

### TownVisitorLife

- Script：`res://scripts/npc/town_visitor_life.gd`
- Consumers：`VisitorFarmer.tscn`、`VisitorMinstrel.tscn`
- Status：Current — Active Runtime Presentation
- Responsibility：在 initial delay 後由 authored town edge 進場，走到 greeting stop，
  向可用偏好居民 greet／chat，再走到相反 edge；完成一輪後 offscreen wait 再循環。
- Groups：保留 `NPCs`／`town_visitors`，不得加入 `town_life_npcs` 或 `Interactives`。
- Boundary：只記錄 session-local pass／greeting count；不擁有建築 interaction、schedule
  save、gameplay dialogue、quest 或 resident movement。

### TownModularVisuals

- Scene：`res://scenes/maps/town/components/TownModularVisuals.tscn`
- Owner：`TownBackdrop`
- Data contract：`res://data/town_modular_layout.json`
- Generator：`tools/build_town_modular_scene.py`
- Status：Current — Active Runtime Presentation
- Responsibility：將同一個 `1942 × 809` source canvas 上 layout-defined background、
  ground、facility、landmark 與 street-prop entries 組成 editor-visible 的
  `Sprite2D` children。每個 child 保留穩定 object ID、source path、position、
  target size、z-index 與 interaction-owner metadata，方便逐件替換。
- Runtime boundary：此 component 是 runtime
  presentation authority；六個建築入口仍由
  `TownBuildingEntrances.tscn` 擁有，戰鬥門仍由
  `TownPortalSet/BattleGateway` 擁有，碰撞、NPC 與 progression 不移入此 scene。
- Visual style：`res://data/town_visual_style.json` 定義
  `storybook_handdrawn_pixel_v2` 的手繪墨線、紙張顆粒、木石色盤與統一光向；
  `town_style_direction_a_locked.png` 是正式構圖基準。獨立天空、透明手繪雲、群山、
  生成的繁盛秋林 canopy、西側粗像素破敗石塔、橫向灌木殘骸帶、右緣針葉樹
  殘牆群與中央秋樹，共用
  `a_locked_autumn_green_ruins_layers_v3` 素材規則；專用綠色 ruins layer
  位於秋林之前、主樹之後；古塔靠近西側邊界，殘骸帶補滿貼地空隙，右緣群組
  封住最右房屋後方的淺色楔形空隙，
  舊綠色 legacy/parallax forest 仍不得顯示。
  不滅熔爐與旋渦門遵循 `base_material_yard_landmarks_v3` style profile；
  不滅火炬與旋渦門都使用 refined Base v5 靜態塔身。
  兩者保留火盆、符文塔與旋渦門辨識輪廓，並使用與材料行一致的灰藍石塊、
  粗斷裂線稿、有限明暗、中性 Base 光與結構 AO。Base v5 不滅火炬另以約 4× source-to-display pixel
  density 對齊相鄰建築的石縫、銅件與木旗精細度；禁止糊大塊、密集規整磚列與
  微小紋理噪點；其頂部火焰與中央符文光不得烘焙在靜態 Base。上述分件與 16 塊道路／橋牆
  各自可見，禁止再以
  `town_eternal_forge_v1.png` 暖色整張城鎮圖充當背景。東側四棟建築使用以
  材料行為 style reference 的 Base v3
  source，以約 4× source-to-display pixel density 保留相同細節密度。六棟建築以
  `b2_front_right_orthographic` metadata 共用 B2 正面＋右側窄面視角。已登錄
  unique sources 中包含 18 個 visual-only B2 街景 dressing；道路頂緣固定
  `y=660`，與 `y=672` gameplay baseline 重疊 12 px；會重畫地面的
  `road_patch`、`curb_grass`、`fallen_leaves`、`drain_grate`、亮綠
  `small_tree` 與六個東側大型遮擋物保留 hidden。舊 modular-v1 街具與浮空
  旗幟只保留 hidden stable entries，不得進入 runtime composition。
- Runtime authority：`TownBackdrop/ModularVisuals` 顯示 layout 中所有核准分件；
  `TownBackdrop/EternalForgeConcept` 保持 hidden，不得與分件同時顯示。
- Design handoff：`tools/build_town_modular_figma_board.py` 讀取同一 JSON 與分件
  source，產生單頁 board；第一區鎖定 Image #2，第二區才放重組候選及可選取
  素材庫。候選未經核准不得切回 runtime。

### TownSkyLayer / TownCloudLayer

- Scenes：`res://scenes/maps/town/components/TownSkyLayer.tscn`、
  `res://scenes/maps/town/components/TownCloudLayer.tscn`
- Scripts：`res://scripts/maps/town_sky_layer.gd`、
  `res://scripts/maps/town_cloud_layer.gd`
- Owner：`TownBackdrop`
- Status：Current — Active Runtime Presentation
- Sky contract：`TownSkyLayer/Sky` 是唯一 cloud-free 天空物件，覆蓋 `1942 × 720`
  gameplay world；`set_sky_tint(Color)` 只做乘色，`set_sky_atmosphere(...)` 同步驅動
  `town_sky_grade.gdshader` 與保留原筆觸的半透明 `town_sky_wash.gdshader`。Town root 的
  `set_time_of_day_progress()`／`set_time_of_day_hour()`／`transition_to_time_of_day_hour()`
  是同步 owner；只呈現 15:00–18:00 夕陽段：15:00 漸入、16:00–17:30 full-gold plateau、
  18:00 暖粉橘 afterglow。未來時間系統不得分別搜尋各 layer。
- Lighting contract：`TownAtmosphere` 固定在 CanvasLayer 5，使用 luminance split tone 讓亮部偏金、
  暗部偏冷紫，並保持在 HUD layer 10／Menu layer 20 下方。場景、actor 與 portal/flame emissive
  使用不同 tint，禁止回退為全 Town 同一橘色乘色。低角度 sunset shafts 的方向固定為左→右下，
  ray pattern 以 world offset 錨定；`refresh_cloud_shadows()` 從 live clouds 取樣三組扁長、破邊的低頻冷影，
  Camera 只做 1:1 世界換算。陰影覆蓋樹冠、建築、角色、道具與街道，但以 sky-blue／emissive rejection
  排除天空、Portal 與 flame，且不得形成硬邊、黑球、貼紙輪廓、跟隨玩家或遮住 HUD。全域 grade／palette
  balance 必須保持次要；主要受光使用保黑位的材質乘法曝光，保留石、木、布、葉片與白袍的辨識色。
- Foliage lighting contract：`AmbientAnimation.set_sunset_lighting_strength()` 接收 Town root 的夕陽權重，
  古樹與分層 foliage 使用獨立 phase 的微風與葉面 shimmer；只調整既有暖色葉片，禁止抬黑、整片同步閃黃、
  移動樹幹／樹根或 branch pivot。
- Cloud contract：八個獨立 `Sprite2D` 重用四張核准透明手繪雲，使用至少四種
  `7–18 px/s` 速度、`0–4 px` 垂直漂移與畫面外回繞，禁止退化成同步移動的整張雲幕。
  後四朵必須以自然的小尺度輪廓變體形成至少六種可辨 silhouette；禁止巨大內凹、刀切直線、尖三角或假 seam。
  `res://shaders/cloud_edge_cleanup.gdshader` 只在透明素材左右邊緣移除孤立碎點與過薄的
  水平假接縫，不得平滑、重繪或切斷主雲色塊。
  `set_cloud_tint(Color)` 由 Town 全域 time-of-day API 同步呼叫。
- Layering：`Sky z=-100`、`Clouds z=-98`、透明群山 `z=-95`；雲必須在天空前、
  山稜後，且不得建立 collision、interaction、NPC 或 progression authority。

### TownEternalFlameAnimation

- Scene：`res://scenes/maps/town/components/TownEternalFlameAnimation.tscn`
- Owner：`TownBackdrop`
- Status：Current — Active Runtime Presentation
- Responsibility：在 Base v5 不滅火炬靜態塔身上疊加彼此獨立的
  `FireLayers` 與 `RuneCharge`。`FireLayers` 內含 `FireGlow`、`TopFire`、
  `InnerFire` 三個 `AnimatedSprite2D`；`RunePulse` 只提供中央符文的連續光暈。
- Playback contract：三層火焰共用固定火根、圓弧外焰、橙色中焰與淡黃核心的
  v2 逐格素材；各使用 8 幀、4.5 FPS、loop、自動播放，並以不同 frame 與
  frame progress 錯開相位；`RuneCharge` 使用 8 幀、4 FPS、loop、
  自動播放，`RunePulse` 以 2 秒 loop 連續插值 alpha 與 scale。循環邊界不得
  產生位置跳動、尺寸突變、明顯亮度斷點或可感知的卡頓。
- Layer boundary：`FireLayers` 必須保持獨立並把原點固定在火盆接觸線，供後續
  整組火焰放大或換色而不下沉；`BrazierFrontOccluder` 從 Base v5 同源裁切火盆
  前緣並位於主火焰之前，使火根由盆腔內冒出，禁止以調整火焰高度掩蓋分層錯誤。
  `RuneCharge` 只負責持續充能循環。兩組不得重新
  烘焙進 Base v5，也不擁有 interaction、collision、Town progression 或火炬
  Tier 狀態。

### TownBattlePortalAnimation

- Scene：`res://scenes/maps/town/components/TownBattlePortalAnimation.tscn`
- Owner：`TownBackdrop`
- Status：Current — Active Runtime Presentation
- Responsibility：在 Base v5 傳送門石框內疊加完整暗紫 `PortalUnderpaint`、
  `PortalCore` 主旋渦、
  `PortalHighlights` 次光筆觸與 `PortalRuneGlow` 頂部晶石呼吸。
- Asset contract：`portal_aperture_mask.png` 與 800 × 960 Base 精確對位，
  並產生完整填滿門洞的 underpaint，再把 core 候選量化為約五階大像素色塊，
  派生 highlight，輸出兩組 12 幀、`800x960` runtime cels；
  旋渦或 emission 不得重新烘焙進 Base。
- Motion contract：`PortalCore` 與 `PortalHighlights` 自動播放 12 幀、
  6 FPS、2 秒 `vortex` loop，次光從第 3 幀起保持相位差；`PortalPulse`
  只連續插值次光 alpha 與頂部符文 alpha／scale。禁止以單張貼圖 shader 旋轉
  取代手繪逐格形變。
- Boundary：此 Scene 只擁有 presentation。`TownPortalSet/BattleGateway` 繼續
  擁有 interaction、collision 與 `battle_portal_hub.tscn` route。

### TownBuildingAnimation

- Scene：`res://scenes/maps/town/components/TownBuildingAnimation.tscn`
- Script：`res://scripts/maps/town_building_animation.gd`
- Owner：`TownBackdrop`
- Status：Current — Active Runtime Presentation
- Responsibility：在六棟 MaterialYard-style Base 建築上疊加十一組可見窗格微光、
  鐵匠爐暖光與手繪火焰、七組布料自由端、Town Hall 秒針、劍魂商劍徽反光與
  圖紙商齒輪。`TownWindowGlow.tscn` 只遮罩玻璃格；窗戶保持常亮，以不同週期和
  相位進行約 10–15% 的暖色微閃，不可同步明滅或照亮牆面。
- Asset contract：鐵匠爐沿用八幀手繪火焰；劍徽反光使用
  `assets/town/modular_v3/animation/building/` 下的透明手繪逐格素材，齒輪只使用同目錄
  的手繪中性幀。兩者維持 nearest filtering 與固定像素 pivot，禁止以 `Line2D`、
  `Polygon2D` 或平滑 shader 代替 raster 素材。
- Motion contract：布料只允許固定上緣後的 1px 整數位移；秒針以整數像素位置
  跳動；齒輪保持靜態且不得播放旋轉動畫；劍光為短促事件且大部分時間 hidden。
- Boundary：只擁有 presentation，不建立 collision、interaction、NPC、
  service route 或 Town progression。

### TownAmbientAnimation

- Scene：`res://scenes/maps/town/components/TownAmbientAnimation.tscn`
- Script：`res://scripts/maps/town_ambient_animation.gd`
- Owner：`TownBackdrop`
- Status：Current — Active Runtime Presentation
- Responsibility：以完整且不位移的 `autumn_ancient_tree_base_v2.png`、
  八區透明樹冠模組、一張 3 × 2 街景 atlas 中三種核准實色葉團、四個屋後
  branch anchors，以及三張 4 × 3、12 幀透明 atlas 組合古樹、左右秋林、
  獨立單葉、路緣小堆、鳥類待機與起飛／飛行。
- Motion contract：完整古樹永遠保持固定；一般狀態下八組樹冠以
  `4.3–5.6` 秒不同週期低幅擺動，並以 `5.7–7.8` 秒週期穿插短暫稀疏抖葉。
  建築間露出的左右外冠另保留 `1.8×` calm gain，確保一般遊玩可見。
  每隔 8–18 秒，八組樹冠再以不同相位、約 0.05–0.22 秒延遲跟隨
  3.2–4.8 秒徐風，枝根固定，
  各樹叢只以約 `0.045–0.085 rad` 的枝根 pivot 旋轉產生清楚搖動，不做
  UV 波動、剪切或伸縮，也不永久播放 GIF loop。中央古樹外的十組街景區域
  各以後、中、前三層實色葉團疊在固定的低解析度背景林後方，使用
  `z=-88/-87/-86` 與 `0.35/0.65/1.0` sway gain；固定秋林遮住葉團底部，
  只允許葉梢越過既有冠線，透明度不得用來掩蓋畫風差異。各區域以不同 `4.2–5.6` 秒 calm 與
  `5.8–7.6` 秒 rustle 週期在隱藏支點低幅旋轉。pivot position／scale／skew
  固定，只讓局部樹梢表面不同步晃動，不移動
  原始背景樹或形成同步水波。四個 house-edge pivot 只使用兩層方向不同的枝端，
  主枝保持在建築後方 `z=-11`，根部必須由屋簷／招牌遮住。二十四個獨立單葉
  由中央樹冠或屋後樹冠出生，只向下移動到街道、屋頂或建築平台；runtime scale
  為 authored scale 的 `0.48`，停留後原地淡出。三個路緣小堆各由五片扁平葉
  組成，使用 40 秒淡入／長時間停留／淡出／短暫隱藏週期。十六個鳥停棲點分為
  十四個屋頂／石座與兩個地面位置；鳥只循環側面站姿列，使用冷深藍褐剪影，
  預設 scale 為 `0.065`，主要建築停棲點由 metadata 提升至 `0.105`；等待
  45–72 秒或 Player 靠近才
  起飛，同群以 0.12 秒錯時依序離開，飛離後 5–8 秒返回 authored perch。
- Composition contract：完整古樹保留正確樹幹方向並位於建築後方；額外樹冠
  必須鎖在中央樹的可追溯枝幹接點，前後層配色一致，不得形成邊界浮空斷枝。
  十組街景 foliage patches 必須沒有可見樹幹、枝根或完整圓形樹冠，並嵌入
  屋頂後方的既有秋林。三層葉團必須互相重疊，禁止長水平底緣、楔形尖頭或
  窄頸漂浮葉帶；不得成為浮在天空中的獨立灌木或整棵搖動的小樹，也不得新增
  樹幹。固定秋林必須遮住動態葉團底部，只留下有根據的局部葉梢 sway。
  落葉保持稀疏且 y 單調下降，不得半空消失或往左上倒飛；單葉可讀尺寸不得
  退化為大型貼紙，路緣堆必須保持低矮且避開 NPC／UI。鳥的 authored perches
  必須跨 west tower、forge、portal 與 clockhouse 可讀，不得只集中西側。
  整體氛圍應悠閒而非暴風。
- Boundary：只擁有 presentation。不得新增 collision、interaction、NPC、
  reward、save state 或 Town progression。

### TownLocationLabels

- Scene owner：`TownEternalForgeIdentity/LocationLabels`
- Script：`res://scripts/maps/town_location_labels.gd`
- Trigger authority：`TownBuildingEntrances` 的六個完整地基 Area
- Presentation：六個建築名稱使用
  `res://assets/town/modular_v2/ui/building_label_plaque.png`，固定在建築最高輪廓
  上方；Player 進入時只顯示目前建築，離開後 hidden。
- Boundary：只接受 `Player` group interactor，不擁有 interaction、UI route、
  collision 或 service state。Image #2 review 期間不滅火炬與戰鬥傳送門標籤
  hidden。

### TownEternalForgeHUD

- Scene: `res://scenes/ui/town/TownEternalForgeHUD.tscn`
- Script contract: `res://scripts/ui/hud/hud.gd`
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
- Script contract: `res://scripts/ui/cards/card_hand_ui.gd`
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
