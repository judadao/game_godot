# Claude / AI Repository Instructions

本檔與 `AGENTS.md` 共同指向同一套治理文件。任何 AI 修改專案前必須：

## 目錄

- [1. Required Reading](#1-required-reading)
- [2. Non-negotiable Rules](#2-non-negotiable-rules)
- [3. Code Example](#3-code-example)
- [4. Scene Tree Example](#4-scene-tree-example)
- [5. Godot Example](#5-godot-example)
- [6. Checklist](#6-checklist)
- [7. Best Practice](#7-best-practice)
- [8. Anti Pattern](#8-anti-pattern)
- [9. Review Checklist](#9-review-checklist)
- [10. Future Extension](#10-future-extension)
- [11. Related Documents](#11-related-documents)

## 1. Required Reading

1. 完整閱讀 `AGENTS.md`。
2. 完整閱讀 `docs/README.md` 與 `docs/01_AI_GUIDE.md`。
3. 完整閱讀 `docs/rule_1.md`。
4. 依 `docs/README.md` 任務矩陣閱讀所有相關專門文件。
5. 治理文件任務另讀 `docs/rule_2.md`。

## 2. Non-negotiable Rules

- 保留所有不屬於本任務的 dirty worktree 變更。
- 不猜測不存在的玩法、架構、Autoload、Resource 或測試。
- 靜態地圖與 UI 必須可在 Godot Scene editor 中編輯。
- UI 修改必須做多解析度行為／視覺驗證。
- Bug 與 refactor 使用先失敗的回歸測試。
- 完成前執行 focused tests、全部 `tests/*_test.gd`、例外檔
  `tests/test_ui_keyboard.gd`、editor 與 main smoke。
- 架構、資料、UI contract、測試或玩法改變時同步更新 docs。
- commit 前核對 staged files；不得混入使用者變更。

## 3. Code Example

```gdscript
func resolve_dependency(candidate: Node) -> Node:
	if candidate == null:
		push_error("Required dependency is missing.")
		return null
	return candidate
```

## 4. Scene Tree Example

```text
Game
├── MapRoot
├── HUDLayer
├── MenuLayer
└── CardEffectRunner
```

## 5. Godot Example

```gdscript
func _ready() -> void:
	if Engine.is_editor_hint():
		return
	load_starting_map()
```

## 6. Checklist

- [ ] 已依任務矩陣讀取相關文件。
- [ ] 已確認工作區與 authoritative files。
- [ ] 已規劃測試、文件同步與提交邊界。

## 7. Best Practice

用小步、可回歸、可 review 的修改維持 code、Scene、data、test、docs 一致。

## 8. Anti Pattern

不要建立第二套 HUD／map／save flow；不要只為消除錯誤訊息遮蔽根因。

## 9. Review Checklist

- [ ] 已讀相關治理文件。
- [ ] 已找到 authoritative Scene／script／data。
- [ ] 已保留使用者 dirty changes。
- [ ] 已提供測試證據而不是推測。
- [ ] 已同步文件。
- [ ] staged scope 與使用者要求一致。

## 10. Future Extension

若新增其他 AI 入口檔，必須引用本治理索引，不得複製一套不同規則。

## 11. Related Documents

- `AGENTS.md`
- `docs/README.md`
- `docs/01_AI_GUIDE.md`
- `docs/11_GIT_WORKFLOW.md`
