# 09 Testing Guide

## 目錄

- [1. 目的與適用範圍](#1-目的與適用範圍)
- [2. 現況基線](#2-現況基線)
- [3. 測試分層](#3-測試分層)
- [4. 測試命名與結構](#4-測試命名與結構)
- [5. 執行方式](#5-執行方式)
- [6. UI 與多解析度驗證](#6-ui-與多解析度驗證)
- [7. Scene 與資料契約](#7-scene-與資料契約)
- [8. 測試隔離](#8-測試隔離)
- [9. 回歸策略](#9-回歸策略)
- [10. Checklist](#10-checklist)
- [11. Best Practice](#11-best-practice)
- [12. Anti Pattern](#12-anti-pattern)
- [13. Code Example](#13-code-example)
- [14. Scene Tree Example](#14-scene-tree-example)
- [15. Godot Example](#15-godot-example)
- [16. Review Checklist](#16-review-checklist)
- [17. Future Extension](#17-future-extension)
- [18. Related Documents](#18-related-documents)

## 1. 目的與適用範圍

本文件定義本專案的自動測試、場景冒煙測試、UI 排版回歸與人工驗收方式。任何行為修改、重構、資料格式變更或 Scene Tree 調整都必須依風險選擇對應驗證。

## 2. 現況基線

目前測試是直接繼承 `SceneTree` 的 Godot 原生腳本，存放於 `tests/`，多數以 `*_test.gd` 命名並以退出碼表示成功或失敗。專案尚未配置 GUT、統一測試執行器與 CI；新增這些能力前不得在交付報告中宣稱已具備。

現有測試涵蓋卡牌、戰鬥、地圖導航、存檔遷移、城鎮流程、秋季森林流程、HUD 與多解析度排版等範圍。`tests/test_ui_keyboard.gd` 不符合目前主要的檔名慣例，應在建立統一 runner 時一併納入或改名，避免漏跑。

## 3. 測試分層

1. 純邏輯測試：不載入完整場景，驗證資料轉換、規則與狀態機。
2. 元件測試：實例化單一 UI、角色、系統或互動物件。
3. 契約測試：檢查節點路徑、群組、signal、資料欄位與場景註冊。
4. 整合測試：驗證 Game、地圖、HUD、CardHandUI 與流程協作。
5. 冒煙測試：以 headless 模式啟動 editor 與主場景，檢查 parser/runtime error。
6. 人工視覺驗證：Godot 編輯器與實際執行畫面的像素、層級、操作與動畫。

## 4. 測試命名與結構

- 檔名使用 `<behavior>_test.gd`。
- 測試腳本使用 `extends SceneTree`，保持可由 CLI 單獨執行。
- 測試函式命名描述可觀察行為，例如 `_test_canonical_path_resolves_to_authoritative_scene()`。
- 失敗訊息必須包含預期值、實際值與測試情境。
- 任何建立的節點、暫存檔或 user data 都必須在測試結束時清理或使用隔離目錄。
- 新增行為先寫會失敗的測試，確認失敗原因正確後再實作。

## 5. 執行方式

Windows 範例：

```powershell
$godot = "D:\game\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe"
$test_user_root = Join-Path (Get-Location) ".test_userdata"
$original_app_data = $env:APPDATA
try {
	$env:APPDATA = $test_user_root
	& $godot --headless --path . --script tests/card_system_test.gd
} finally {
	$env:APPDATA = $original_app_data
}
```

上述 `APPDATA` 覆寫只存在於目前 PowerShell process，用來把 Godot
`user://` 導向 repository 內的隔離位置；不得永久改寫系統設定。單一測試必須
以退出碼 `0` 表示成功，非零表示失敗。全量測試應逐一執行所有
`tests/*_test.gd`，並額外執行 `tests/test_ui_keyboard.gd`。執行輸出除了退出碼，
也必須掃描：

```powershell
$test_files = @(Get-ChildItem tests -Filter *_test.gd | Sort-Object FullName)
$test_files += Get-Item tests/test_ui_keyboard.gd
$test_failures = @()
$original_app_data = $env:APPDATA
try {
	$env:APPDATA = Join-Path (Get-Location) ".test_userdata"
	foreach ($test_file in $test_files) {
		$test_output = @(& $godot --headless --path . --script $test_file.FullName 2>&1)
		$test_output | Write-Output
		if ($LASTEXITCODE -ne 0 -or
			($test_output -join "`n") -match "SCRIPT ERROR|Parse Error|ERROR:") {
			$test_failures += $test_file.FullName
		}
	}
} finally {
	$env:APPDATA = $original_app_data
}
if ($test_failures.Count -gt 0) {
	throw "Godot tests failed: $($test_failures -join ', ')"
}
```

```text
SCRIPT ERROR
Parse Error
ERROR:
```

不要只依靠程序退出碼判定成功，因為 Godot 有時會在退出碼為零時輸出非致命錯誤。

## 6. UI 與多解析度驗證

HUD 與 CardHandUI 至少驗證以下視窗尺寸：

- 1280×720（專案基準）
- 1600×900
- 1920×1080
- 2560×1440
- 1152×720（較窄比例；現有 guardrail suite）
- 2560×1080（較寬比例）

自動測試應檢查安全區、地圖 viewport、卡牌操作區、焦點、遮擋與螢幕邊界。人工驗證則確認字體清楚、卡牌可讀、HUD 不阻擋玩法資訊，以及編輯器所見與執行結果一致。

Theme 修改需載入受影響 scene，確認 theme、theme variation、font、
StyleBox 與所有互動狀態可解析；本專案尚無共用 Theme resource，因此現有
scene-local override 與未來 Theme migration 必須分開驗證。Animation 修改需
檢查 AnimationPlayer/AnimatedSprite2D 的 library、track target、loop 與完成狀態，
並實際跑過進入、中斷、重播與場景切換。

## 7. Scene 與資料契約

Scene 測試至少檢查：

- `PackedScene` 可載入與實例化。
- 控制器依賴的節點路徑存在。
- 需要持久化或搜尋的節點群組存在。
- map canonical path 與 authoritative scene 的解析一致。
- JSON 可解析，必要欄位與型別正確。
- 可選節點缺少時採用明確 fallback，而不是產生連鎖錯誤。

修改 `.tscn`、JSON schema、節點名稱或 signal 時，應先找到相應契約測試；不存在時先補測試。

Parser 驗證先執行 `--headless --editor --path . --quit`，並將任何
`Parse Error`／`SCRIPT ERROR` 視為失敗。Signal 測試應實例化 emitter/receiver，
確認連接只建立一次、emit payload 型別正確、釋放後不殘留 callable。Resource
測試需實際 `load()` scene/script，JSON 則由 production loader 解析與驗證，
不得只搜尋文字推測可載入。

效能修改必須以同一場景、波次、視窗與時間範圍記錄修改前後的 Godot
Profiler/Monitor 數據，至少包含 process、physics、draw calls 與 node/object
數。記憶體驗證需重複執行開關 UI、切換場景或生成／清除波次，確認 node、
object、orphan node 與記憶體不持續成長。專案尚無自動 performance/memory
門檻；在建立基線前，這些屬於必做的可重現量測而非 CI pass/fail。

## 8. 測試隔離

測試不得讀寫玩家真實存檔。CLI 測試使用專案內隔離的 user data 位置，例如 `.test_userdata/`，並避免與平行執行的測試共用可變檔案。對時間、亂數或輸入敏感的測試應注入可控制的值。

目前尚無平行安全的統一 runner，因此預設逐一執行 SceneTree 測試。若未來平行化，必須先隔離存檔路徑、DisplayServer 與共享資源。

## 9. 回歸策略

修復 bug 時，測試必須重現原始失敗。重構時先建立或確認 characterization test，保持外部行為不變。驗證順序：

1. 新增或受影響的單一測試。
2. 同領域測試。
3. 所有自動測試。
4. editor headless 冒煙測試。
5. 主場景 headless 冒煙測試。
6. 影響視覺時進行人工檢查。

## 10. Checklist

- [ ] 已先建立可重現需求或 bug 的測試。
- [ ] 已確認測試在實作前因正確原因失敗。
- [ ] 已執行受影響領域與全量測試。
- [ ] 已掃描 Godot error 輸出。
- [ ] 測試沒有污染真實 user data。
- [ ] UI 修改已驗證四個基準尺寸與窄／寬比例。
- [ ] Scene/JSON 變更已更新契約測試。
- [ ] 文件與實際執行指令一致。

## 11. Best Practice

- 測試可觀察行為，不綁定不必要的內部實作。
- 每個測試只描述一個主要失敗原因。
- 使用最小場景與純邏輯物件縮短回饋時間。
- 對回歸問題保留永久測試。
- 在提交前保存完整、最新的驗證證據。

## 12. Anti Pattern

- 寫完實作後才補一個永遠會通過的測試。
- 只跑單一測試就宣稱全專案通過。
- 只檢查退出碼而忽略 Godot error log。
- 測試依賴執行順序、真實存檔或不可控亂數。
- 用字串搜尋取代應實際載入場景的行為驗證。
- 因為測試不穩定而直接刪除，不先找根因。

## 13. Code Example

```gdscript
extends SceneTree

var _failures := 0
const GAME_SCRIPT := preload("res://scripts/managers/game.gd")

func _init() -> void:
	var game := GAME_SCRIPT.new()
	_expect_equal(game.call("_canonical_map_scene_path", "res://scenes/maps/town/TownMap.tscn"),
		"res://scenes/maps/town.tscn", "town canonical path")
	game.free()
	quit(0 if _failures == 0 else 1)

func _expect_equal(actual: Variant, expected: Variant, context: String) -> void:
	if actual == expected:
		return
	_failures += 1
	push_error("%s: expected %s, got %s" % [context, expected, actual])
```

上例使用目前 `Game` 已存在的 path contract；若該責任被重構，測試應改驗證新的
public owner，同時保留 Game compatibility coverage。

## 14. Scene Tree Example

```text
Game
├── MapRoot
│   └── CurrentMap (AutumnForest)
├── HUDLayer
│   ├── HUD
│   └── CardHandUI
└── MenuLayer
```

整合測試應確認 HUD 與 CardHandUI 掛在預期 CanvasLayer 下，地圖切換不會複製或遺失這些共用 UI。

## 15. Godot Example

```gdscript
var packed := load("res://scenes/ui/CardHandUI.tscn") as PackedScene
if packed == null:
	push_error("CardHandUI scene failed to load")
	quit(1)
	return

var instance := packed.instantiate()
root.add_child(instance)
await process_frame
if not instance.is_inside_tree():
	push_error("CardHandUI was not added to SceneTree")
instance.queue_free()
```

## 16. Review Checklist

- [ ] 測試名稱與失敗訊息能說明需求。
- [ ] 測試確實會在回歸時失敗。
- [ ] 沒有依賴私有實作到阻礙安全重構。
- [ ] 所有載入的節點與資源都有清理。
- [ ] 非同步流程有明確等待條件與逾時策略。
- [ ] 測試命令可從 repository root 重現。
- [ ] 報告清楚區分自動驗證與人工驗證。

## 17. Future Extension

- TODO：新增統一測試 runner，明確納入所有測試檔。
- TODO：評估導入 GUT；導入前保留既有 SceneTree 測試可執行性。
- TODO：建立 CI，執行全量測試、editor 與主場景冒煙測試。
- TODO：建立可重現的截圖比較流程，避免跨 GPU 的脆弱像素比對。
- TODO：將目前人工量測升級為效能預算、記憶體成長與長時間波次自動測試。
- TODO：建立 coverage/需求追蹤表，但不得用數字取代行為驗證。

## 18. Related Documents

- [AI Guide](01_AI_GUIDE.md)
- [Scene Structure](03_SCENE_STRUCTURE.md)
- [UI Guide](04_UI_GUIDE.md)
- [Coding Standard](05_CODING_STANDARD.md)
- [Debug Guide](10_DEBUG_GUIDE.md)
- [Git Workflow](11_GIT_WORKFLOW.md)
