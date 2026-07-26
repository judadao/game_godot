# Project Governance Documentation

本目錄是本 Godot 專案的工程治理入口。文件描述「目前專案如何運作」以及
「修改時必須遵守什麼」，不能用理想架構取代實際程式碼。

## 目錄

1. [文件權威與閱讀順序](#1-文件權威與閱讀順序)
2. [文件索引](#2-文件索引)
3. [任務閱讀矩陣](#3-任務閱讀矩陣)
4. [文件維護流程](#4-文件維護流程)
5. [Best Practice](#5-best-practice)
6. [Anti Pattern](#6-anti-pattern)
7. [Code Example 與 Godot Example](#7-code-example-與-godot-example)
8. [Review Checklist](#8-review-checklist)
9. [Future Extension](#9-future-extension)
10. [Related Documents](#10-related-documents)

## 1. 文件權威與閱讀順序

### 1.1 強制順序

任何修改開始前依序閱讀：

1. 根目錄 `AGENTS.md` 或執行環境對應的代理入口。
2. 根目錄 `CLAUDE.md`，確保不同 AI 使用相同治理規則。
3. `docs/01_AI_GUIDE.md`。
4. `docs/rule_1.md` 的工作與 UI 防跑版規則。
5. 下方任務矩陣列出的相關文件。

`docs/rule_2.md` 是本治理系統的建立需求。治理文件有結構性修改時必須重新
核對它；一般功能任務以本索引與編號文件為操作規範。

### 1.2 衝突處理

優先序為：使用者當前明確要求 → repository `AGENTS.md` → 對應專門文件 →
一般慣例。發現衝突時說明衝突、影響與採用的上位要求，不得靜默違反。

### 1.3 現況與目標

文件中：

- 「現況」只能記錄 repository 可驗證內容。
- 尚未存在的能力使用 `TODO`，不得假裝已完成。
- 「Future Extension」是候選方向，不是已核准需求。

## 2. 文件索引

| 文件 | 權責 |
|---|---|
| `01_AI_GUIDE.md` | AI 工作流、讀取、修改、測試與回報 |
| `02_PROJECT_ARCHITECTURE.md` | runtime 邊界、資料流、主要系統 |
| `03_SCENE_STRUCTURE.md` | Scene 類型、Node Tree、命名與 ownership |
| `04_UI_GUIDE.md` | UI 排版、響應式、互動與防跑版 |
| `05_CODING_STANDARD.md` | GDScript、Signal、錯誤、效能與檔案規則 |
| `06_RESOURCE_GUIDE.md` | JSON、Resource、runtime state 與存檔邊界 |
| `07_THEME_GUIDE.md` | Theme、StyleBox、色彩、字型與 spacing |
| `08_COMPONENT_LIBRARY.md` | 可重用 UI 元件契約與缺口 |
| `09_TESTING_GUIDE.md` | headless、Scene、UI、回歸與效能測試 |
| `10_DEBUG_GUIDE.md` | 重現、根因追蹤、Godot 診斷與修復流程 |
| `11_GIT_WORKFLOW.md` | dirty worktree、commit、push 與 review |
| `12_GAME_DESIGN.md` | 已實作玩法與可驗證規則 |
| `13_ROADMAP.md` | 現況缺口、技術債與可驗證里程碑 |

## 3. 任務閱讀矩陣

| 任務 | 必读文件 |
|---|---|
| 地圖／Portal／碰撞 | 02、03、09、10、12 |
| HUD／卡牌／Popup | 04、07、08、09 |
| 戰鬥／卡牌規則 | 02、05、06、09、12 |
| CardInstance／五牌堆／fixed card | 02、05、06、09、12 |
| Skill recipe／Memory Library | 02、05、06、09、12、13 |
| Card growth／upgrade／fusion | 02、03、04、06、08、09、12 |
| Meta schema 4／Skill loadout migration | 02、06、09、12 |
| Autumn combat HUD／六解析度 | 02、03、04、07、08、09、`rule_1.md` |
| JSON／存檔／進度 | 02、05、06、09 |
| NPC／商店／對話 | 02、03、06、08、12 |
| 架構重整 | 01、02、03、05、09、11、13 |
| 文件治理 | README、01、11、13、`rule_2.md` |

## 4. 文件維護流程

1. 先找出 code、scene、data、test 的實際來源。
2. 修改實作與對應測試。
3. 同一任務同步更新受影響文件。
4. 檢查路徑、API、Node 名稱與數字是否仍正確。
5. 文件與 code 一起 review、commit。

### Checklist

- [ ] 新增／移動 Scene 已更新 02、03。
- [ ] 修改 UI contract 已更新 04、08。
- [ ] 修改資料格式已更新 06。
- [ ] 修改測試命令或覆蓋範圍已更新 09。
- [ ] 修改玩法已更新 12。
- [ ] 新技術債或完成里程碑已更新 13。

## 5. Best Practice

- 用實際 `res://` 路徑、class、signal 與 test 名稱提供可追蹤證據。
- 把「規範」與「現況限制」分開寫。
- 小步更新文件，不等到架構已經過期才重寫。
- Scene Tree 範例必須能對應現有 node ownership。

## 6. Anti Pattern

- 文件聲稱存在 repository 中找不到的 Autoload、Theme 或 Resource。
- 只更新 README，未更新權責文件。
- 把未核准構想寫成既定玩法。
- 複製同一規則到多份文件且內容互相矛盾。

## 7. Code Example 與 Godot Example

### 7.1 Scene Tree Example

```text
Game (Node)
├── MapRoot (Node)
├── HUDLayer (CanvasLayer)
├── MenuLayer (CanvasLayer)
└── CardEffectRunner (Node)
```

### 7.2 Godot Example / GDScript

```gdscript
func open_inventory() -> void:
	var inventory_ui := open_ui("inventory", inventory_scene, true)
	if inventory_ui == null:
		push_error("Inventory UI could not be opened.")
```

文件應說明這段程式所屬責任、失敗行為與測試，而不只貼程式碼。

## 8. Review Checklist

- [ ] 目錄連結與編號正確。
- [ ] 所有路徑存在或明確標記 `TODO`。
- [ ] 範例使用 Godot 4 API 與 GDScript。
- [ ] 沒有把推測寫成現況。
- [ ] Related Documents 能導向真正相依文件。
- [ ] 修改已與 code/test 同步。

## 9. Future Extension

- 文件版本與重大架構決策紀錄（ADR）。
- CI 自動檢查路徑、Markdown link 與 headless tests。
- 自動產生 Scene／Signal 索引，但人工文件仍負責意圖與限制。

## 10. Related Documents

- `AGENTS.md`
- `CLAUDE.md`
- `docs/rule_1.md`
- `docs/rule_2.md`
- `docs/01_AI_GUIDE.md`
