# AI Development Guide

## 目錄

1. [目的與適用範圍](#1-目的與適用範圍)
2. [AI Workflow](#2-ai-workflow)
3. [Task Analysis](#3-task-analysis)
4. [Reading Order](#4-reading-order)
5. [Modification Rules](#5-modification-rules)
6. [Review Process](#6-review-process)
7. [Testing SOP](#7-testing-sop)
8. [Risk Analysis](#8-risk-analysis)
9. [Regression Rules](#9-regression-rules)
10. [Forbidden Actions](#10-forbidden-actions)
11. [Reporting Format](#11-reporting-format)
12. [Code Examples](#12-code-examples)
13. [Review Checklist](#13-review-checklist)
14. [Best Practice 與 Anti Pattern](#14-best-practice-與-anti-pattern)
15. [Future Extension](#15-future-extension)
16. [Related Documents](#16-related-documents)

## 1. 目的與適用範圍

本文件約束所有能修改 repository 的 AI。AI 的任務不是快速產生最多程式碼，
而是在保留使用者既有修改、現有玩法與可回歸證據的前提下完成要求。

## 2. AI Workflow

```text
讀治理入口
→ 檢查 Git 狀態
→ 盤點 code/scene/data/test
→ 重現或建立 RED test
→ 最小實作
→ focused tests
→ full regression
→ review
→ docs 同步
→ scoped commit/push
```

### 2.1 開工

1. 讀 `AGENTS.md`、`CLAUDE.md`、本文件、`rule_1.md`。
2. 依 `docs/README.md` 任務矩陣讀專門文件。
3. `git status --short` 區分使用者 dirty changes 與本任務。
4. 用 `rg` 找 caller、NodePath、signal、resource path、tests。
5. commentary 說明證據、根因、最小方案與驗證範圍後直接做。

### 2.2 實作

- Bug／refactor 先有能正確失敗的測試。
- 每個修改單元維持單一責任。
- 不在同一 commit 混入無關格式化、搬檔或使用者修改。
- 遇到意外結果回到證據蒐集，不疊加猜測性 patch。

## 3. Task Analysis

### 3.1 必答問題

- 使用者要的是報告、診斷、修改、部署，還是等待？
- 成功可由哪個命令、Scene、解析度或操作證明？
- 哪些檔案是 authoritative source？
- 哪些 public API、Signal、NodePath、Save schema 不能破壞？
- working tree 中哪些變更不是本任務產生？

### 3.2 任務切分

只有當子任務檔案與狀態可獨立時才並行。多人不得同時修改同一 `.tscn` 或
同一核心 script。整合者必須重新跑測試，不得只信代理報告。

## 4. Reading Order

基礎順序見 `docs/README.md`。至少讀：

```text
AGENTS.md
CLAUDE.md
docs/README.md
docs/01_AI_GUIDE.md
docs/rule_1.md
相關專門文件
```

治理文件重建或新增時再讀 `docs/rule_2.md`。

## 5. Modification Rules

### 5.1 Scope

- 只動完成需求所需檔案。
- 不刪除、reset、checkout 或覆蓋不明 dirty changes。
- 修改 Node 名稱或 path 時先 `rg` 所有引用。
- 靜態 UI 與地圖物件必須可在 Scene editor 看見。
- runtime 只建立真正動態物件，例如敵人、掉落物、卡牌按鈕。

### 5.2 Documentation

架構、資料格式、UI contract、測試命令或玩法改變時，同一任務更新對應文件。
文件落後視為未完成。

### 5.3 Error handling

```gdscript
func load_catalog(path: String) -> bool:
	if not FileAccess.file_exists(path):
		push_error("Catalog not found: %s" % path)
		return false
	# Parse only after the boundary check.
	return true
```

不得空 catch、吞掉錯誤或用預設資料掩蓋壞檔。

## 6. Review Process

### 6.1 Self-review

1. 對照需求逐條查證。
2. 看完整 diff，而不是只看自己記得的修改。
3. 檢查 scope、API、Signal、NodePath、ownership、cleanup。
4. 搜尋 placeholder、重複邏輯與固定 UI 座標。

### 6.2 Independent review

大型功能與 refactor 必須有獨立 reviewer。Critical／Important 必須修正並
re-review；不同意 finding 時用 code/test 證據裁決。

## 7. Testing SOP

### 7.1 Focused

```powershell
& 'D:\game\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe' `
  --headless --path . --script res://tests/ui_layout_guardrails_test.gd
```

測試輸出同時檢查 exit code 與 `SCRIPT ERROR|Parse Error|ERROR:`。

### 7.2 Full regression

- 執行所有 `tests/*_test.gd`，並額外執行目前未符合該 suffix 的
  `tests/test_ui_keyboard.gd`。
- 使用隔離 `APPDATA`，避免 editor cache 影響。
- `--headless --editor --path . --quit`。
- `--headless --path . --quit-after 300`。
- UI 依 `04_UI_GUIDE.md` 做多解析度行為／視覺檢查。

## 8. Risk Analysis

| 風險 | 必查證據 |
|---|---|
| UI 跑版 | Container、anchors、canvas rect、多 viewport |
| Scene override 遺失 | exact instance identity、reparent 前後 snapshot |
| 存檔破壞 | migration test、old payload fixture、backup path |
| Signal 重複 | connection state、重複開關 UI／換圖 |
| Dirty tree 混入 | staged name list、cached diff |
| 資料格式錯誤 | schema validation、missing/invalid fixture |

## 9. Regression Rules

- 修 bug 的測試必須在 fix 前因正確原因失敗。
- 測試 observable behavior，不 grep production source。
- UI 不只測 parser，還測 rect、visibility、z-order、focus 與內容量。
- Scene transition 測來源與目標、spawn、state transfer、cleanup。
- 新測試需有 `.gd.uid`，保持 Godot 資源識別一致。

## 10. Forbidden Actions

- 未讀治理文件就改檔。
- 用固定 viewport 座標重建可 authored 的 UI。
- 為通過測試改弱 assertion。
- 未驗證就說「完成」。
- 擅自設計新玩法、資料或 Roadmap 承諾。
- 對 dirty worktree 使用 destructive Git。
- stage／commit 無關使用者檔案。

## 11. Reporting Format

最終回報包含：

1. 問題根因與證據。
2. 修改檔案與責任。
3. UI layout 變更（沒有也要寫）。
4. 保留的玩法、Signal、資料流。
5. 實際命令、測試數與結果。
6. 未驗證項目。
7. 風險與人工驗收。
8. commit hash 與 push 狀態。

## 12. Code Examples

### 12.1 Scene Tree Example

```text
AuthoritativeMap (Node2D)
├── World content
├── PlayerSpawn (Marker2D)
├── Player (CharacterBody2D)
├── EditorHUDReference (CanvasLayer)
│   ├── HUD (Control)
│   └── CardHandUI (Control)
└── EditorHelpers (CanvasLayer)
```

### 12.2 Signal-first Godot Example

```gdscript
signal card_selected(index: int)

func select_card(index: int) -> void:
	if index < 0 or index >= _cards.size():
		return
	card_selected.emit(index)
```

呼叫端決定戰鬥結果；UI 不直接修改 deck 或敵人。

## 13. Review Checklist

- [ ] 已讀必要文件。
- [ ] 已標記 authoritative files 與使用者 dirty files。
- [ ] RED test 正確失敗。
- [ ] focused tests 通過且無 error markers。
- [ ] full tests、editor、main smoke 通過。
- [ ] UI 已做需要的解析度驗證。
- [ ] docs 與 code 一致。
- [ ] independent review 無未處理 Important。
- [ ] staged files 完全符合 scope。
- [ ] commit／push 已核對遠端。

## 14. Best Practice 與 Anti Pattern

### Best Practice

- 用小而可驗證的修改替代大爆炸重寫。
- 讓 Scene、script、data、test、docs 各自只有清楚責任。
- 以實際命令輸出支撐完成宣告。

### Anti Pattern

- 「應該會過」而不執行。
- 動態建立全部 UI，讓 Inspector 失去權威性。
- 把大型 manager 繼續塞入無關責任。
- 新增第二套 map／HUD／save flow。

## 15. Future Extension

- CI 並行執行 headless tests。
- 自動檢查治理文件中的 `res://` 路徑。
- ADR 記錄大型架構決策。
- 視覺 golden-image 測試（需先定義穩定 renderer 環境）。

## 16. Related Documents

- `docs/README.md`
- `docs/02_PROJECT_ARCHITECTURE.md`
- `docs/04_UI_GUIDE.md`
- `docs/09_TESTING_GUIDE.md`
- `docs/10_DEBUG_GUIDE.md`
- `docs/11_GIT_WORKFLOW.md`
