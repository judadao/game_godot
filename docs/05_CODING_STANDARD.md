# GDScript Coding Standard

## 目錄

1. [基準](#1-基準)
2. [命名與檔案](#2-命名與檔案)
3. [函式與責任](#3-函式與責任)
4. [Signal First](#4-signal-first)
5. [型別與依賴](#5-型別與依賴)
6. [Resource 與狀態](#6-resource-與狀態)
7. [錯誤與 Logging](#7-錯誤與-logging)
8. [Async、生命週期與 Thread Safety](#8-async生命週期與-thread-safety)
9. [Performance 與 Memory](#9-performance-與-memory)
10. [Autoload 規則](#10-autoload-規則)
11. [註解](#11-註解)
12. [Code Example 與 Godot Examples](#12-code-example-與-godot-examples)
13. [Best Practice](#13-best-practice)
14. [Anti Pattern](#14-anti-pattern)
15. [Review Checklist](#15-review-checklist)
16. [Future Extension](#16-future-extension)
17. [Related Documents](#17-related-documents)

## 1. 基準

- Godot 4.7／GDScript 2。
- UTF-8、tab indentation，遵守既有 `.editorconfig`。
- PascalCase：class、node、scene。
- snake_case：檔案、變數、函式、signal。
- UPPER_SNAKE_CASE：常數。

## 2. 命名與檔案

檔案依 domain 放入 `scripts/combat`、`interaction`、`managers`、`maps`、
`monsters`、`npc`、`player`、`systems`、`ui`。一個 script 一個主要責任；
`class_name` 只提供真正跨 domain 使用的型別。

```gdscript
class_name DeckManager
extends RefCounted

signal hand_changed(cards: Array[Dictionary])
```

禁止 `new_manager2.gd`、`temp_ui.gd`、`final_fix.gd`。

## 3. 函式與責任

### 3.1 Early Return

```gdscript
func interact(interactor: Node = null) -> bool:
	if not interaction_enabled:
		return false
	if interactor == null:
		return false
	interacted.emit(self, interactor)
	return true
```

### 3.2 Single Responsibility

- UI：顯示、輸入、focus、signal。
- systems：卡牌、combo、inventory、save、progression 規則。
- manager/orchestrator：連接流程，不應承載所有規則。
- Scene node：擁有與其生命週期一致的行為。

目前 `scripts/managers/game.gd` 同時協調 map、UI、combat、shop、save 等多項
責任，屬已知重整候選；新增功能前優先抽出可測純邏輯，不再擴張它。

大型檔案必須依責任拆分，不得只依行數切成 `part_1`／`part_2`。抽離前先建立
characterization test；抽離後原 owner 只保留 composition、資料轉換或必要相容 wrapper。
功能權威位置與 focused suite 由 `data/maintenance_scope_map.json` 路由，避免為單一修改
載入或改動不相干 domain。

## 4. Signal First

下層元件發 signal，上層協調者決定後果。

```gdscript
signal portal_entered(
	portal: Node,
	target_scene_path: String,
	target_spawn_name: StringName,
	interactor: Node
)
```

連接前檢查重複；釋放後不得保留 stale reference。不要讓 UI 直接搜尋 Game
並修改狀態。

## 5. 型別與依賴

- public method、signal、重要 local 使用明確型別。
- 穩定 Node 使用 `@onready`。
- 可選 Node 用 `get_node_or_null()` 並處理 null。
- 依賴方向：UI → signal/interface；orchestrator → systems；systems 不依賴 UI。
- 禁止在 `_process()` 反覆 `find_child()`／group scan。

## 6. Resource 與狀態

分層：

```text
data JSON / static Resource
→ validated catalog/model
→ mutable MetaState / RunState / manager state
→ UI projection
```

UI 不修改基礎 catalog dictionary。跨邊界時使用 `duplicate(true)` 或明確
projection，詳見 `06_RESOURCE_GUIDE.md`。

## 7. 錯誤與 Logging

- 無法滿足 contract：`push_error()` 並回傳失敗。
- 可恢復但需關注：`push_warning()`。
- 不為正常玩家分支洗 log。
- 錯誤訊息包含 path、id 或 operation。
- JSON／save 解析失敗不得靜默覆蓋原檔。

```gdscript
var parsed: Variant = JSON.parse_string(raw_text)
if not parsed is Dictionary:
	push_error("Expected dictionary catalog: %s" % path)
	return {}
```

## 8. Async、生命週期與 Thread Safety

目前專案主要在 main thread，沒有正式 worker-thread 架構。

- `await` 後重新檢查可能被釋放的 node。
- timer callback 使用 generation/token 防止舊工作覆寫新狀態。
- `queue_free()` 後不要在同一流程假設 node 已離開 tree。
- `@tool` 必須區分 `Engine.is_editor_hint()`，避免 editor 執行 gameplay。
- 未建立執行緒前不要加入 mutex／semaphore 假抽象。

## 9. Performance 與 Memory

- `_process`／`_physics_process` 只做逐幀必要工作。
- catalog、stable node、PackedScene 應 preload 或快取。
- 大量 enemy／effect 生成前先量測，再決定是否 pooling。
- tween、signal、dynamic UI 重建前清掉舊實例。
- `is_instance_valid()` 用於可能延後釋放的 reference。

### Checklist

- [ ] hot path 沒有 filesystem、JSON parse 或 tree-wide search。
- [ ] dynamic child 有 cleanup。
- [ ] signal 不重複連接。
- [ ] save／catalog 不每幀讀取。

## 10. Autoload 規則

目前 `project.godot` 沒有 `[autoload]`。不得把方便存取當成新增全域單例的理由。
新增 Autoload 前必須：

1. 文件化生命週期、ownership 與 reset 方法。
2. 證明不能由 Game／Scene composition 管理。
3. 加 isolation、save migration 與 scene reload tests。
4. 更新 02、03、06、09。

## 11. 註解

註解解釋「為什麼」與 contract，不重述語法。Magic number 應成為命名常數。
公開 workaround 必須附移除條件。

## 12. Code Example 與 Godot Examples

### 12.1 Scene Tree Example

```text
ExperienceGem (Area2D)
├── Sprite2D
└── CollisionShape2D
```

其 script 可擁有吸附與收集，不能管理整輪升級選項。

### 12.2 Safe connection

```gdscript
func _connect_once(source: Object, signal_name: StringName, callback: Callable) -> void:
	if not source.has_signal(signal_name):
		return
	if source.is_connected(signal_name, callback):
		return
	source.connect(signal_name, callback)
```

## 13. Best Practice

- 純邏輯放 `RefCounted` system，容易 headless test。
- Scene-owned 行為跟隨 node lifecycle。
- public contract 小而清楚，資料轉換在邊界完成。
- 用命名常數記錄設計數值並由測試驗證行為。

## 14. Anti Pattern

- 2,000 行 orchestrator 繼續加入所有新規則。
- UI `_ready()` 動態重建全部可 authored layout。
- huge Dictionary 穿越所有層且無 schema validation。
- deep NodePath 散落多檔但沒有 scene contract test。
- 用 `call()` 逃避可建立的型別界面。
- 捕捉錯誤後回傳成功。

## 15. Review Checklist

- [ ] 命名、domain、class responsibility 正確。
- [ ] Early Return 取代深層巢狀。
- [ ] Signal 方向沒有反轉依賴。
- [ ] 型別與 null handling 足夠。
- [ ] 沒有新增 hidden global state。
- [ ] async cleanup 與 node validity 正確。
- [ ] 錯誤可診斷且不破壞原資料。
- [ ] performance-sensitive path 無昂貴操作。
- [ ] 新 public contract 有 test 與 docs。

## 16. Future Extension

- 將 `Game` 的 save、shop、run combat、UI stack 分階段抽成可注入 coordinator。
- 持續依 `docs/14_MAINTENANCE_MAP.md` 將大型 VFX/UI script 拆成具語意且可獨立驗證的責任。
- 導入靜態檢查與 GDScript formatter（需先固定工具版本）。
- 以 typed Resource 取代成熟且高風險的 JSON Dictionary 邊界。

## 17. Related Documents

- `docs/02_PROJECT_ARCHITECTURE.md`
- `docs/03_SCENE_STRUCTURE.md`
- `docs/06_RESOURCE_GUIDE.md`
- `docs/09_TESTING_GUIDE.md`
- `docs/10_DEBUG_GUIDE.md`
