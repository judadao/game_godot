# 10 Debug Guide

## 目錄

- [1. 目的與原則](#1-目的與原則)
- [2. 問題分類](#2-問題分類)
- [3. 系統化除錯流程](#3-系統化除錯流程)
- [4. Godot CLI 診斷](#4-godot-cli-診斷)
- [5. Scene Tree 與生命週期](#5-scene-tree-與生命週期)
- [6. UI 排版除錯](#6-ui-排版除錯)
- [7. 地圖與導航除錯](#7-地圖與導航除錯)
- [8. 資料與存檔除錯](#8-資料與存檔除錯)
- [9. 效能與記憶體](#9-效能與記憶體)
- [10. Checklist](#10-checklist)
- [11. Best Practice](#11-best-practice)
- [12. Anti Pattern](#12-anti-pattern)
- [13. Code Example](#13-code-example)
- [14. Scene Tree Example](#14-scene-tree-example)
- [15. Godot Example](#15-godot-example)
- [16. Review Checklist](#16-review-checklist)
- [17. Future Extension](#17-future-extension)
- [18. Related Documents](#18-related-documents)

## 1. 目的與原則

本文件提供可重現、可驗證、低風險的 Godot 除錯流程。核心原則是先收集證據與定位根因，再提出或實作修正；不要用隱藏錯誤訊息或擴大 fallback 來掩蓋問題。

## 2. 問題分類

- Parser/載入錯誤：GDScript 語法、型別、資源路徑、循環依賴。
- Scene Tree 錯誤：節點尚未進樹、已被釋放、路徑或 owner 錯誤。
- 狀態錯誤：Game、存檔、地圖、戰鬥或 UI 持有不一致資料。
- UI 錯位：anchor、offset、Container、minimum size、CanvasLayer 或 viewport 不一致。
- 輸入錯誤：焦點、mouse filter、InputMap、鍵盤與手把映射。
- 效能錯誤：每幀配置、過量節點、重複載入、未釋放 signal/timer。
- 環境錯誤：editor cache、user data、import metadata 或平台差異。

## 3. 系統化除錯流程

1. 精確描述預期與實際行為。
2. 建立最短、穩定的重現步驟。
3. 讀取完整錯誤、stack trace 與第一個失敗位置。
4. 比較最近變更與同類正常路徑。
5. 一次只驗證一個根因假設。
6. 以最小自動測試重現問題。
7. 實作最小、架構一致的修正。
8. 執行 focused、domain、full、smoke 驗證。
9. 更新治理文件或契約，避免同類錯誤重現。

若問題無法穩定重現，先增加診斷資訊，不要直接大改程式。

## 4. Godot CLI 診斷

```powershell
$godot = "D:\game\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe"
$test_user_root = Join-Path (Get-Location) ".test_userdata"
$original_app_data = $env:APPDATA
try {
	$env:APPDATA = $test_user_root
	& $godot --headless --editor --path . --quit
	& $godot --headless --path . --quit-after 120
} finally {
	$env:APPDATA = $original_app_data
}
```

輸出至少搜尋：

```text
SCRIPT ERROR
Parse Error
ERROR:
Invalid call
Previously freed
Node not found
```

使用隔離 user data，避免玩家舊存檔讓結果不可重現。`120` frame 是快速診斷；
交付驗證使用至少 `300` frame，並掃描完整 log。若 editor smoke 正常但主場景失敗，
優先檢查 `_ready()`、場景切換與 runtime reparent；若 editor 就失敗，優先處理
parser、resource path 與 tool script。

## 5. Scene Tree 與生命週期

`CanvasItem.get_rect()`、`get_viewport_rect()`、signal 連接與全域座標通常要求節點已進入 SceneTree。遇到 `!is_inside_tree()` 時，先追查呼叫時機，而不是忽略錯誤。

檢查：

- 節點何時 instantiate、add_child、reparent、queue_free。
- `_enter_tree()`、`_ready()`、deferred call 的先後。
- `owner` 是否讓節點能保存至正確 scene。
- signal 是否重複連接或在 emitter 釋放後仍被呼叫。
- map 切換後共用 HUD/CardHandUI 是否只存在一份。

## 6. UI 排版除錯

先識別座標系與所有權：

1. 專案 viewport 與 stretch 設定。
2. 地圖顯示區與 UI 安全區。
3. CanvasLayer。
4. Control anchor 與 offset。
5. Container 排版與 custom minimum size。
6. runtime script 是否覆寫 editor-authored 值。

編輯器修改沒有反映到執行畫面時，搜尋 `set_anchors*`、`offset_*`、`position`、`size`、`reparent` 與 runtime instantiate。確認實際載入的是 canonical scene 還是 authoritative layout scene，不要只編輯舊的相似檔案。

## 7. 地圖與導航除錯

地圖問題要記錄：

- 請求的 scene path。
- canonical path。
- 實際載入的 authoritative path。
- current map node 名稱與 scene file path。
- 入口 portal ID、spawn ID 與傳遞狀態。

本專案的 Game 管理地圖載入與共用 UI。若 Town 無法進入 Autumn Forest，先檢查 portal target、scene registry/path resolution、場景可載入性與玩家出生點；不要直接在 portal 裡複製換圖邏輯。

## 8. 資料與存檔除錯

JSON 與存檔問題依序檢查：

- 檔案是否存在且 UTF-8 可解析。
- root 型別、版本號、必要欄位與預設值。
- 數字/字串/陣列型別是否符合 consumer。
- migration 是否冪等。
- quick save 與 meta progression 是否各自保存預期範圍。

不得以刪除玩家存檔作為預設修正。需要測試 migration 時，複製最小 fixture 到隔離 user data。

## 9. 效能與記憶體

使用 Godot Profiler、Monitors 與 Remote Scene Tree 觀察：

- Node/Object 數是否隨波次持續上升。
- Process/Physics 時間。
- draw calls 與 CanvasItem 數。
- orphan node。
- signal、Timer、Tween 與 Callable 生命週期。

先量測再最佳化。對怪物波次、經驗寶石與卡牌 UI，優先找持續配置、未清理物件與每幀全樹搜尋。效能修正也需要行為回歸測試。

## 10. Checklist

- [ ] 有最短且穩定的重現步驟。
- [ ] 記錄 Godot 版本、場景、輸入與資料狀態。
- [ ] 已讀完整第一個錯誤與 stack trace。
- [ ] 根因假設有證據支持。
- [ ] 修正前有失敗測試或最小重現。
- [ ] 未用 suppress/fallback 掩蓋真正錯誤。
- [ ] 已執行相關、全量與 smoke 驗證。
- [ ] UI 問題已檢查 runtime 覆寫與實際載入 scene。

## 11. Best Practice

- 保留可重現案例作為永久回歸測試。
- 在系統邊界記錄穩定 ID 與狀態摘要，避免輸出敏感或巨大資料。
- 從第一個錯誤開始修，後續錯誤可能只是連鎖結果。
- 使用 Remote Scene Tree 驗證 runtime 真實節點，而非只看 editor。
- 修正責任邊界，不在多個 caller 加相同 workaround。

## 12. Anti Pattern

- 看見錯誤就加 `is_instance_valid()`，卻不追查為何過早釋放。
- 以 `await process_frame` 當作所有生命週期問題的通用解答。
- 在 `_process()` 每幀重建 UI 或載入資源。
- 同時修改多個系統，讓根因不可辨識。
- 只在單一解析度確認 UI。
- 清除 `.godot`、存檔或 import cache 後就宣稱修好。

## 13. Code Example

```gdscript
func attach_hud(hud: Control, target: CanvasLayer) -> void:
	if hud == null:
		push_error("Cannot attach HUD: dependency is null")
		return
	if target == null or not target.is_inside_tree():
		push_error("Cannot attach HUD: target layer is not inside SceneTree")
		return
	if hud.get_parent() != target:
		hud.reparent(target)
```

這個範例在系統邊界明確失敗，而不是讓後續 `get_rect()` 產生難以理解的連鎖錯誤。

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

若 Runtime Remote Tree 出現兩個 HUD，或 CardHandUI 位於 CurrentMap／
MenuLayer 之下，表示 scene ownership/reparent 流程與預期契約不一致。

## 15. Godot Example

```gdscript
func debug_map_resolution(requested_path: String) -> void:
	var canonical := _canonical_map_scene_path(requested_path)
	var resolved := _resolve_main_scene_path(requested_path)
	print("map request=%s canonical=%s resolved=%s" % [
		requested_path,
		canonical,
		resolved,
	])
```

診斷 log 應在問題解決後移除，或改為預設關閉的明確 debug 選項，避免污染正常輸出。

## 16. Review Checklist

- [ ] 修正對應已證實的根因。
- [ ] 沒有吞掉 error 或降低契約強度。
- [ ] 新診斷訊息不包含憑證、完整存檔或玩家敏感資料。
- [ ] 生命週期與 scene ownership 清楚。
- [ ] 沒有在 hot path 加入不必要配置或 log。
- [ ] 測試會在原問題回歸時失敗。
- [ ] 已更新相關架構、場景、UI 或測試文件。

## 17. Future Extension

- TODO：建立統一的結構化 debug logger 與可關閉分類。
- TODO：加入 CI 保存 Godot error log 與失敗測試 artifact。
- TODO：建立效能基線與長時間波次 soak test。
- TODO：為存檔 migration 建立版本化 fixture。
- TODO：建立 UI debug overlay，顯示 safe area、viewport 與 Control rect。
- TODO：在開發模式顯示 map request/canonical/authoritative path。

## 18. Related Documents

- [Project Architecture](02_PROJECT_ARCHITECTURE.md)
- [Scene Structure](03_SCENE_STRUCTURE.md)
- [UI Guide](04_UI_GUIDE.md)
- [Coding Standard](05_CODING_STANDARD.md)
- [Testing Guide](09_TESTING_GUIDE.md)
- [Git Workflow](11_GIT_WORKFLOW.md)
