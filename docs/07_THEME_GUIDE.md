# Theme Guide

本文件定義 Godot 4 UI Theme、Theme Variation、顏色、字型、圖示、StyleBox 與 spacing
的治理規則。它先記錄目前 repository 的真實狀態，再定義可逐步導入的目標契約。
目前有 Card Growth 與 Town Service 兩個功能域 Theme，沒有 project-global Theme
或 Font resource；所有「Target」或「TODO」內容不代表已實作。

## 目錄

1. [文件目的與狀態](#1-文件目的與狀態)
2. [目前 Theme 稽核](#2-目前-theme-稽核)
3. [Theme Ownership 與 Layer](#3-theme-ownership-與-layer)
4. [Theme Variation](#4-theme-variation)
5. [Color System](#5-color-system)
6. [Typography](#6-typography)
7. [Icons 與 Texture](#7-icons-與-texture)
8. [Button Style](#8-button-style)
9. [Panel Style](#9-panel-style)
10. [StyleBox](#10-stylebox)
11. [Spacing、Padding 與 Margin](#11-spacingpadding-與-margin)
12. [Focus、Disabled 與 Semantic State](#12-focusdisabled-與-semantic-state)
13. [Dark Theme 與 Light Theme](#13-dark-theme-與-light-theme)
14. [Pixel Art 與 Filtering](#14-pixel-art-與-filtering)
15. [Runtime Theme Mutation](#15-runtime-theme-mutation)
16. [Theme Migration Plan](#16-theme-migration-plan)
17. [Code Examples](#17-code-examples)
18. [Scene Tree Example](#18-scene-tree-example)
19. [Godot Example (Godot 4)](#19-godot-example-godot-4)
20. [Best Practice](#20-best-practice)
21. [Anti Pattern](#21-anti-pattern)
22. [Implementation Checklist](#22-implementation-checklist)
23. [Review Checklist](#23-review-checklist)
24. [Future Extension](#24-future-extension)
25. [Related Documents](#25-related-documents)

## 1. 文件目的與狀態

### 1.1 適用範圍

本文件適用於：

- `Control.theme`
- project-level Theme assignment
- `theme_type_variation`
- Theme colors、font sizes、fonts、icons、constants、StyleBoxes
- `LabelSettings`
- runtime `add_theme_*_override()`
- `assets/ui/**`

### 1.2 狀態詞

| 狀態 | 定義 |
|---|---|
| **Current** | repository 可驗證的既有實作 |
| **Known Risk** | 已有具體 duplication、drift 或維護風險 |
| **TODO — Not Implemented** | 本文件定義契約，但檔案/API 尚未建立 |
| **Proposed** | Future Extension 候選，尚未核准 |

## 2. 目前 Theme 稽核

### 2.1 Resource 現況

production path 搜尋結果：

| Resource | 數量 |
|---|---:|
| `.theme` | 0 |
| `.tres` | 2 |
| `.res` | 0 |
| `.ttf` / `.otf` / `.woff` / `.woff2` | 0 |
| project global Theme assignment | 0 |
| 功能域 Theme resource | 2 |

目前 UI 使用 Godot default font，沒有專案字型、fallback chain 或 CJK glyph contract。
`CardGrowthTheme.tres` 提供 `ConfirmButton` variation；
`TownServiceFrameTheme.tres` 提供 Town service window、portrait、title 與 Close
variations。

### 2.2 Scene-local theme data

`scenes/ui/**` 實際有：

- 123 × `StyleBoxFlat`
- 1 × `StyleBoxTexture`
- 1 × `StyleBoxEmpty`
- 14 × `LabelSettings`
- 216 × `theme_override_font_sizes/*`
- 203 × `theme_override_colors/font_color`
- 90 × panel style assignment
- 55 × normal style assignment
- 139 × 一般 `separation` override，另有 4 × `h_separation` 與
  4 × `v_separation`（廣義 spacing override 合計 147）

另有 runtime `StyleBoxFlat.new()`：

- `scripts/ui/cards/card_hand_ui.gd`
- `scripts/ui/results/run_result_ui.gd`

### 2.3 Current reuse

- Inventory、Shop 與 PlayerBlacksmithUI 會從 author node 讀取 StyleBox，再套到
  selected/normal state。
- 同一 scene 內可共用 subresource。
- HUD 子場景有各自 LabelSettings/StyleBox。
- MaterialYardUI、PlayerBlacksmithUI、TownHallUI 與 ShopUI 共用「深色鍛造底、
  金色主框、冷藍資訊區、語意資源色」的視覺語言。共同外框、標題與 Close
  button 由 `scenes/ui/town/TownServiceFrameTheme.tres` 的
  `TownServiceWindow`、`TownServiceTitle`、`TownServiceCloseButton`
  variations 擁有；功能 panel 與 selected state 仍是 scene-local。

這是功能域 Theme，不是全域 Theme layer。

### 2.4 Known Risks

1. 功能 panel、row 與 action button 的相似 StyleBox 仍有重複。
2. 14/16/18/20 等字級散落，無 semantic typography。
3. 非 frame style change 仍可能要改多個 `.tscn` 與 `.gd`。
4. runtime 建立 StyleBox 容易每次 rebuild 產生重複資源。
5. 沒有 Font fallback，無法保證繁中、特殊符號與 controller glyph。
6. 沒有 dark/light mode；不能把目前深色木質風格稱為正式 Dark Theme。

## 3. Theme Ownership 與 Layer

### 3.1 Current

目前沒有 application-wide Theme owner。Town 功能建築 frame 由
`TownServiceFrameTheme.tres` 擁有，其餘 scene/node 仍主要透過 local override
決定外觀。

### 3.2 TODO — Not Implemented target layers

未來導入時採以下優先序：

```text
Godot engine fallback
↓
Project Base Theme
↓
Semantic Theme Variation
↓
Domain-specific asset treatment
↓
Temporary local state override
```

定義：

1. **Project Base Theme**：預設字型、body color、Button/Panel/Label 基礎。
2. **Semantic Variation**：PrimaryButton、DangerButton、PanelHeader 等語意。
3. **Domain treatment**：Shop parchment、HUD frame 等有素材語意的視覺。
4. **Local state override**：資料驅動 card type、transaction success/failure 等少數狀態。

### 3.3 Proposed resource location

下列路徑尚不存在；建立前需獨立任務與測試：

```text
resources/ui/
├── themes/
│   ├── base_theme.tres
│   ├── dark_theme.tres
│   └── light_theme.tres
├── fonts/
│   └── [licensed project font and fallback resources]
└── styles/
    └── [only shared StyleBox resources that cannot live in Theme]
```

不得先建立空殼檔案再宣稱 Theme system 完成。

### 3.4 Ownership rules

- application root 或 UI subtree root 指派 Theme。
- component 不自行 preload 另一套 global Theme。
- variation 名稱是 public visual contract，改名需更新 scenes/tests/docs。
- domain screen 不修改 global Theme resource。
- theme switching 由單一 owner 處理；目前此 owner 尚不存在。

## 4. Theme Variation

### 4.1 目的

Theme Variation 讓語意元件繼承 Godot base type，同時集中差異。例如
`PrimaryButton` 繼承 `Button`，只覆寫 primary colors/styles。

### 4.2 TODO — Not Implemented variation registry

以下名稱是目標 contract，尚未在 repository 建立：

| Variation | Base type | 用途 |
|---|---|---|
| `PrimaryButton` | `Button` | 主要確認／前進 |
| `SecondaryButton` | `Button` | 次要／返回 |
| `DangerButton` | `Button` | 不可逆／危險操作 |
| `PanelHeader` | `PanelContainer` | panel 標題 |
| `ListRow` | `Button` | 可選清單列 |
| `ItemCard` | `Button` | item summary |
| `SkillCard` | `Button` | skill/card summary |
| `QuestRow` | `Button` | quest list row |
| `HealthBar` | `Control` | HP；內含 track/fill/frame/label |
| `ManaBar` | `Control` | MP；內含 track/fill/frame/label |
| `StatusRow` | `HBoxContainer` | label/value/state |
| `TooltipPanel` | `PanelContainer` | tooltip surface |

### 4.3 Rules

- variation 表達語意，不用 `GoldButton2`、`BigRedButton` 等視覺命名。
- variation 只覆寫必要差異，其餘繼承 base type。
- disabled/focus/hover/pressed 必須全部定義或安全繼承。
- 同一 semantic action 不因 screen 不同而換 variation。
- domain texture 可在 component scene 處理，但文字/interaction state 仍遵守 variation。

## 5. Color System

### 5.1 Current

顏色直接寫在 `.tscn` 與 `.gd`。沒有 token 或 single source。

### 5.2 TODO — Not Implemented semantic palette

未來 palette 必須先定 semantic role，再定實際 RGBA：

| Role | 用途 |
|---|---|
| `surface_base` | application/background surface |
| `surface_panel` |一般 panel |
| `surface_elevated` | modal/tooltip |
| `border_default` |一般邊框 |
| `border_focus` | keyboard/controller focus |
| `text_primary` |主要文字 |
| `text_secondary` |次要文字 |
| `text_disabled` |disabled |
| `accent_primary` |主要 action |
| `accent_secondary` |次要 emphasis |
| `semantic_success` |成功 |
| `semantic_warning` |警告 |
| `semantic_danger` |錯誤／危險 |
| `resource_health` |HP |
| `resource_mana` |MP |
| `resource_stamina` |SP |

### 5.3 Color rules

- color role 不等於 gameplay type；card type palette 另由資料視覺投影決定。
- success/danger 同時提供文字/icon，不只靠綠/紅。
- focus border 與 hover state 必須可區分。
- disabled state 保持可讀，不把 alpha 降到無法辨識。
- 同一 semantic role 在 dark/light theme 可能有不同值，但名稱不變。
- 色值調整需做 contrast 與實際畫面驗證。

## 6. Typography

### 6.1 Current

- 使用 Godot default font。
- 無專案 Font resource。
- 無 fallback chain。
- 字級透過 240 個 scene override 及多個 runtime override 設定。

### 6.2 TODO — Not Implemented type scale

未來至少定義：

| Token | 建議用途 |
|---|---|
| `display` |少量大標題 |
| `heading_large` | screen title |
| `heading_medium` | panel title |
| `body` |主要內文 |
| `body_small` |次要內文 |
| `caption` | hint/meta |
| `numeric` |資源/狀態數值 |

實際 pixel size 必須由 UI scale、font metrics、繁中可讀性與 1280×720 baseline 測試
決定；本文件不把現有散落數值直接宣告為已核准 token。

### 6.3 Font requirements

未來字型必須：

- 有明確授權與 source。
- 涵蓋 Latin、數字、標點、繁體中文，或提供 fallback。
- 支援目前使用的 `−`、`•`、`—` 等符號。
- 在 nearest/pixel rendering policy 下保持可讀。
- 有 missing glyph fixture。
- 不把字型檔放在 editor cache。

### 6.4 Text rules

- 不用全大寫作為唯一 hierarchy。
- 動態文字預設可 localization。
- 字級不由 script 每次建立 node 時散落指定。
- heading/body/caption 應透過 Theme type/variation。
- outline/shadow 只用於需要與背景分離的 HUD，不套所有內文。

## 7. Icons 與 Texture

### 7.1 Current assets

`assets/ui/**`：

- `basic_rpg_ui`：19 PNG、13 PSD
- `fantasy_icons_16x16`：258 PNG、1 PSD
- `hud/generated`：17 PNG
- `shop/generated`：7 PNG

總計 301 PNG、14 PSD。301 PNG 均已有 import metadata。

現役 Town building/Shop screen 直接重用 curated runtime icon：

- resource cards：coin、wood、stone、gem/core；
- building/service：ore、forge equipment、research gem、soul gem、Town Hall；
- Shop actions：Buy、Sell、Confirm、Close、quantity、currency；
- Shop item rows：explicit item texture，缺少時由 `shop_ui.gd` 依 identity 選擇
  sword、boots、gem、map 或 supply fallback。

圖示是掃描與辨識輔助，不取代 button text、tooltip、stock/cost/state label。

### 7.2 Icon rules

- icon path 必須來自已授權、已 curated 的 asset。
- 相同 action 使用相同 icon，不在每個 screen 任選。
- icon 必須有 text/tooltip/accessible equivalent。
- 16×16 pixel icon 以整數倍顯示並使用 nearest。
- high-resolution generated frame 與 pixel icon 分開定 filter class。
- destructive、warning、success icon 有 semantic registry。

### 7.3 Texture style rules

- 可伸展 panel 使用 NinePatchRect 或 StyleBoxTexture。
- 不拉伸含文字的圖片。
- atlas region 必須可追溯 source。
- TextureRect 明確 expand/stretch/aspect。
- icon 的 disabled state 不只用低 alpha；搭配文字與 disabled control state。

## 8. Button Style

### 8.1 Required states

每種 Button/variation 必須定義或安全繼承：

- normal
- hover
- pressed
- focus
- disabled

toggle button 另需：

- normal pressed
- hover pressed
- disabled pressed

### 8.2 Semantic button target

**TODO — Not Implemented：**

- PrimaryButton：主要 confirm，一個 panel 通常最多一個。
- SecondaryButton：cancel/back/次要 action。
- DangerButton：quit/delete/不可逆操作；必須明確文案。

Current Pause、Shop、Inventory、Card screens 仍用 local Button styles，未使用上述
variations。

### 8.3 Rules

- focus state不能等同 hover，keyboard 使用者要能辨識。
- pressed state需有明確回饋，不能只位移 1 px 而無色/框差異。
- disabled文字仍可讀。
- button minimum size 由 accessibility/layout contract 決定。
- icon+text alignment 透過 Theme constant 或 child layout，不用空白。

## 9. Panel Style

### 9.1 Panel roles

未來 panel variation 應分：

- base surface
- elevated/modal
- inset/list
- tooltip
- HUD overlay
- domain art panel

### 9.2 Current

Inventory、Shop、Dialogue、Pause、HUD 各自有 StyleBoxFlat；Shop/HUD 另使用 generated
textures。沒有正式 panel registry。

### 9.3 Rules

- content padding由 StyleBox content margin 或 MarginContainer提供。
- border width/corner radius/shadow不能每個 screen任意發明。
- nested panel層次以 surface/contrast表示，不無限加邊框。
- pixel frame角落不得被非等比拉伸。
- modal surface需與 dim backdrop有足夠分離。

## 10. StyleBox

### 10.1 StyleBoxFlat

適用純色/圓角/border/shadow。規則：

- 共享 style放 Theme，不在每個 scene複製。
- runtime修改 shared resource前先 `duplicate(true)`。
- content margin視為 layout contract，改動需做 geometry test。
- shadow不應造成 hit rect誤判或 viewport clipping。

### 10.2 StyleBoxTexture

適用可伸展的 art panel。規則：

- 正確設定 texture margin / patch margin。
- 保護 corner，不拉伸細節。
- source asset與授權可追溯。
- pixel texture遵守 filter/integer scale。

### 10.3 StyleBoxEmpty

用於保留 content margins但不畫背景。不得拿來隱藏原應存在的 focus/selection visual。

### 10.4 Runtime style

Current `CardHandUI` 依 card type runtime 建 style，這是資料驅動例外。應：

- cache 相同 type/state style。
- 不在每 frame new StyleBox。
- selected/disabled/focus state有 deterministic mapping。
- 未來若 Theme導入，card-specific colors可保留在 presentation mapping。

## 11. Spacing、Padding 與 Margin

### 11.1 Current

spacing/margin直接寫在 scenes/scripts，沒有 scale。

### 11.2 TODO — Not Implemented spacing scale

未來可採固定倍數 scale；以下只是 target contract，導入前須視覺驗證：

| Token | Target px | 用途 |
|---|---:|---|
| `space_1` | 4 | icon/text micro gap |
| `space_2` | 8 | row internal gap |
| `space_3` | 12 | control group |
| `space_4` | 16 | panel section |
| `space_5` | 24 | panel padding |
| `space_6` | 32 | screen section |

### 11.3 Definitions

- **Spacing**：siblings 之間距離，通常由 Container separation。
- **Padding**：surface 邊界到 content，通常由 StyleBox content margin。
- **Margin**：component 與外部邊界，通常由 MarginContainer。

### 11.4 Rules

- 不用空 Control 製造 spacing。
- 不在 parent margin與StyleBox content margin重複加同一空間。
- spacing token可因 compact/comfortable mode調整；目前沒有 mode。
- 觸控 minimum target與visual icon size分開。

## 12. Focus、Disabled 與 Semantic State

Theme 必須支援 interaction，不只靜態截圖。

### 12.1 Focus

- focus ring有足夠 contrast。
- focus style不改 control minimum size，避免 layout跳動。
- Shop explicit focus graph的可視 state必須與 navigation一致。

### 12.2 Disabled

- disabled不接受 input。
- disabled原因用 tooltip/description/feedback解釋。
- disabled state不只降低 alpha到不可讀。

### 12.3 Selection

- selected與focused可同時存在。
- Inventory selected slot、Shop selected row不應透過替換 normal style而遺失 focus。
- selection state有文字/icon/outline之一，不只靠背景色。

## 13. Dark Theme 與 Light Theme

### 13.1 Current

沒有 dark/light Theme resources、switcher或持久化。現有深色木質介面只是 local style。

### 13.2 TODO — Not Implemented contract

未來若導入：

- semantic token名稱共享，dark/light只替換值。
- component variation名稱不變。
- texture-based domain panel若無light asset，需定fallback或保持固定 art theme。
- 切換時重驗所有 text/icon/disabled/focus contrast。
- setting owner、save schema與startup apply順序需在 Architecture/Resource docs定義。

### 13.3 禁止

- 以 `modulate` 全畫面變亮冒充 Light Theme。
- runtime逐 node尋找並改 color。
- dark/light各自複製一套 component scene。

## 14. Pixel Art 與 Filtering

### 14.1 Current

- `canvas_items` stretch。
- 沒有 global nearest filter。
- UI只有3個node明確 nearest。
- HUD component有0.75/0.72 scale。

目前不能宣稱 pixel-perfect。

### 14.2 Target rules

- pixel icon nearest + integer scale。
- vector/high-resolution painted asset依素材選linear。
- Theme icon/filter policy需能區分兩類。
- StyleBoxTexture patch margins落在整數pixel。
- font rendering與UI scale一起測。
- Theme migration不可偷偷改 texture filter。

## 15. Runtime Theme Mutation

### 15.1 允許

- data-driven card type state。
- success/failure temporary semantic state。
- selected row/slot state，在尚未有variation時延續現有local override。

### 15.2 規則

- shared Resource mutation前duplicate。
- state恢復時移除override或套回確定style。
- 不在 `_process()` 加theme override。
- 不用runtime color override取代正式variation。
- mutation method短小且只負責presentation。

## 16. Theme Migration Plan

這是治理順序，不表示已排入開發：

1. 建立 screenshot/geometry baseline與style inventory。
2. 選一個低風險screen作pilot，不從全HUD開始。
3. 建立Base Theme與Button/Panel/Label基礎。
4. 建立semantic variations與focus/disabled states。
5. 將pilot screen移除等價local overrides。
6. 跑parser、scene、keyboard、六尺寸與人工視覺驗證。
7. 確認無回歸後逐screen遷移。
8. 最後才移除unused local subresources。

不得用一次全專案替換完成 migration。

## 17. Code Examples

### 17.1 套用已存在 variation

以下是未來 variation 建立後的 component 使用方式：

```gdscript
@onready var confirm_button: Button = %ConfirmButton

func _ready() -> void:
	confirm_button.theme_type_variation = &"PrimaryButton"
```

在 variation 尚未存在前，不可先寫此名稱並假設有style。

### 17.2 安全複製 StyleBox

```gdscript
func make_selected_style(source: StyleBox) -> StyleBox:
	var selected := source.duplicate(true) as StyleBox
	if selected is StyleBoxFlat:
		(selected as StyleBoxFlat).border_color = Color(1.0, 0.82, 0.35)
	return selected
```

### 17.3 移除 temporary override

```gdscript
func clear_feedback(label: Label) -> void:
	label.remove_theme_color_override("font_color")
```

## 18. Scene Tree Example

未來 theme-enabled screen：

```text
ScreenRoot (Control, theme = ProjectBaseTheme)
└── Panel (PanelContainer)
    └── Content (VBoxContainer)
        ├── Header (Label, variation = PanelHeader)
        ├── Rows (VBoxContainer)
        │   └── Row (Button, variation = ListRow)
        └── Actions (HBoxContainer)
            ├── Cancel (Button, variation = SecondaryButton)
            └── Confirm (Button, variation = PrimaryButton)
```

目前 repository 尚無上述 Theme/variations；tree表示目標使用關係。

## 19. Godot Example (Godot 4)

以下示範 Godot 4 Theme API 建立variation的最小概念。正式專案應由 editor-authored
Theme resource提供，不在每次runtime重建：

```gdscript
func build_preview_theme() -> Theme:
	var preview := Theme.new()
	preview.set_type_variation(&"PrimaryButton", &"Button")
	preview.set_color("font_color", &"PrimaryButton", Color.WHITE)
	preview.set_font_size("font_size", &"PrimaryButton", 18)

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.32, 0.18, 0.06)
	normal.border_color = Color(0.92, 0.72, 0.28)
	normal.set_border_width_all(2)
	preview.set_stylebox("normal", &"PrimaryButton", normal)
	return preview
```

此例只供工具/preview理解API，不是目前 production Theme。

## 20. Best Practice

- 先盤點再集中，不在無baseline時重做視覺。
- Theme表達全域base，variation表達semantic component。
- color/type/spacing用role命名。
- focus/disabled/selected與normal同等重要。
- pixel/high-resolution素材分開filter policy。
- domain art與interaction state分層。
- Resource只由owner修改，consumer只讀。
- 每個migration step有geometry、behavior與視覺證據。

## 21. Anti Pattern

- 在每個scene複製相似StyleBoxFlat。
- 在runtime list每row建立相同StyleBox。
- 以實際色名命名semantic variation。
- 只定normal/hover，漏focus/disabled。
- 用字級與全大寫硬做所有hierarchy。
- 用modulate冒充dark/light。
- 在shared Theme resource上runtime改色。
- 把不存在的Theme path寫成Current。
- 未確認字型授權與CJK fallback就加入repo。
- Theme migration同時改layout、logic與assets，無法定位回歸。

## 22. Implementation Checklist

建立/修改 Theme 前：

- [ ] 已盤點受影響 scenes/scripts/local overrides。
- [ ] 已確認是否可重用既有功能域 Theme resource。
- [ ] 已定 semantic role，不用視覺名稱。
- [ ] 已列 normal/hover/pressed/focus/disabled。
- [ ] 已列 dark/light、pixel/filter與font fallback影響。
- [ ] 已確認 shared Resource mutation policy。
- [ ] 已建立before baseline與focused tests。
- [ ] 已限制pilot scope，不一次遷移全專案。

## 23. Review Checklist

- [ ] Current與TODO沒有混寫。
- [ ] Theme owner與assignment path清楚。
- [ ] variation base type與名稱一致。
- [ ] colors使用semantic role。
- [ ] typography支援繁中與missing glyph。
- [ ] icons有source、license、filter與fallback。
- [ ] Button所有interaction states完整。
- [ ] Panel padding沒有重複計算。
- [ ] StyleBox沒有不安全shared mutation。
- [ ] spacing/padding/margin責任清楚。
- [ ] focus/disabled/selection可辨識且不改layout。
- [ ] dark/light不是node-by-node mutation。
- [ ] pixel art在required scale保持清晰。
- [ ] 六尺寸、keyboard、long text、人工視覺已驗證。
- [ ] `docs/04_UI_GUIDE.md`、`08_COMPONENT_LIBRARY.md`與tests同步。

## 24. Future Extension

以下均為 Proposed：

1. 建立project Base Theme與licensed font/fallback。
2. 建立semantic variation registry。
3. 建立dark/light/high-contrast theme。
4. 建立UI scale與typography scale。
5. 將CardHand card-type style做cache/token mapping。
6. 建立icon registry與input glyph resolver。
7. 建立Theme validation test：required variations、states、font、StyleBox。
8. 逐screen移除等價local overrides，保留domain-specific art。

## 25. Related Documents

- `docs/README.md`
- `docs/01_AI_GUIDE.md`
- `docs/02_PROJECT_ARCHITECTURE.md`
- `docs/04_UI_GUIDE.md`
- `docs/05_CODING_STANDARD.md`
- `docs/06_RESOURCE_GUIDE.md`
- `docs/08_COMPONENT_LIBRARY.md`
- `docs/09_TESTING_GUIDE.md`
- `docs/11_GIT_WORKFLOW.md`
- `docs/13_ROADMAP.md`
- `docs/rule_1.md`
