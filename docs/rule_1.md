# Godot 專案開發規則

本文件是每次開發工作的強制前置規則。開始修改前必須完整閱讀，並依照
「開始工作檢查表 → 最小修改 → 實際驗證 → 完成回報」執行。

除非缺少必要權限、外部資源，或不同選擇會改變需求方向，否則不要停下詢問；
能從專案、測試、文件與既有模式查到的內容，直接查明並完成。

## 1. 最高優先原則

1. UI 不得跑版。
2. 不得破壞現有玩法、資料流、Signal、存檔與場景切換。
3. 優先修正根本原因，不使用只遮住症狀的補丁。
4. 只修改任務必要檔案，不順便重構無關系統。
5. 延續既有命名、資料夾、Scene、Theme、Resource 與元件模式。
6. 保留使用者尚未提交的修改，不得覆蓋或混入提交。
7. 完成後必須實際執行受影響流程，不得只檢查 Parser Error。

## 2. 開始工作檢查表

### 2.1 專案與檔案

- 列出根目錄重要檔案與本次涉及的功能資料夾。
- 搜尋相關 `.tscn`、`.gd`、`.tres`、`.res`、Theme、字型與圖片。
- 閱讀相關 Scene Tree、腳本與文件，不得只看單一檔案推測架構。
- 搜尋既有相同功能、共用 UI、Theme Variation、Resource 或工具函式。
- 檢查 Git 狀態，辨識並保留使用者既有修改。

### 2.2 依賴與資料流

- 找出呼叫端、NodePath、Signal、Group、Autoload 與跨場景依賴。
- 找出 Scene 繼承、Instance、Editable Children 與 Owner 關係。
- 確認靜態 Resource、Runtime 狀態與 UI 顯示的資料流。
- 確認是否影響 Save Data、動畫、音效、輸入、Pause 或場景切換。
- 找出 `_ready()`、`_process()` 或工具腳本中會建立或改動版面的程式碼。

### 2.3 實作前說明

在 commentary 先簡短輸出：

1. 相關檔案。
2. 現有運作方式。
3. 已確認的根因或功能缺口。
4. 最小修改方案。
5. 預計修改檔案。
6. 可能影響與驗證範圍。

輸出後直接實作，不等待再次確認；只有需求方向無法從專案判斷，且選擇會造成
明顯不同結果時才停止。

## 3. 修改範圍與檔案結構

- 場景、腳本與 UI 延續既有 `scenes/<domain>/`、`scripts/<domain>/` 結構。
- 靜態遊戲資料優先使用既有 Resource 模式。
- 共用元件建立可重用 Scene，不複製相同 Scene Tree。
- 不建立 `temp`、`new`、`test2`、`final_final` 等無意義名稱。
- 不為小功能增加無必要的資料夾或抽象層。
- 不任意移動、重新命名、刪除檔案或更換 Scene 根節點。
- 修改 Node 名稱、路徑或資源路徑時，同步更新所有引用與測試。
- 地圖版面物件必須存在於 `.tscn` 或子 Scene Instance；短暫敵人、特效與掉落物
  可以由流程在 Runtime 建立。

Scene 必須維持單一責任：

- 遊戲世界使用 `Node2D`／物理節點。
- UI 使用 `CanvasLayer` 與 `Control`。
- UI 邏輯不得混入角色移動、戰鬥計算或地圖生成。
- 不用無意義節點增加過深結構。

## 4. UI 不跑版規則

### 4.1 排版方式

排列多個 UI 元件時優先使用 `MarginContainer`、`VBoxContainer`、
`HBoxContainer`、`GridContainer`、`CenterContainer`、`PanelContainer`、
`ScrollContainer`、`AspectRatioContainer` 或 `FlowContainer`。

禁止：

- 用腳本逐一設定 UI `position`／`global_position`。
- 用索引乘固定高度排列動態列表。
- 用大量固定 Offset 拼出整個介面。
- 用空白或手動換行對齊文字。
- 把主要 UI 放在世界 `Node2D` 座標系。

固定值只用於有設計意義的間距、Margin、最小點擊尺寸、圖示與標準元件尺寸。
世界物件、Editor Helper、特效與明確 HUD 疊加定位可使用座標，但必須說明理由。

### 4.2 Anchor、Offset 與 Size Flags

- 全螢幕 UI 根 `Control` 使用 Full Rect。
- Anchor 與 Offset 不得互相衝突。
- 置中使用 `CenterContainer`、Anchor 或 Container Alignment。
- 需要剩餘空間的元件使用 Expand + Fill。
- 固定內容區塊不得錯誤 Expand。
- 逐一確認主要 Control 的水平與垂直 Size Flags。

### 4.3 尺寸、文字與列表

- Minimum Size 只保證可讀與可操作，不用過大數值強撐版面。
- 長文字設定 Autowrap、Overrun、Clip、Alignment 或 Tooltip。
- 動態名稱、數值、中文與較長英文都不得破壞版面。
- 動態列表加入 Container；可能超出畫面的內容加入 ScrollContainer。
- 空資料與最大資料量都必須可用。

### 4.4 圖片、Popup 與 Theme

- `TextureRect` 明確設定 Expand Mode、Stretch Mode、Keep Aspect 與 Minimum Size。
- Pixel Art 避免非整數縮放，除非既有設計如此。
- Popup、Tooltip、Modal 與 Dialog 不得超出視窗。
- 優先使用現有 Theme、Theme Variation、Font 與 StyleBox。
- 不散落重複顏色、字型大小與相似 StyleBox。

### 4.5 UI 必測解析度

涉及 UI 時至少驗證：

- 1280 × 720
- 1600 × 900
- 1920 × 1080
- 2560 × 1440
- 一個較窄視窗
- 一個較寬視窗

並檢查視窗／全螢幕、長文字、空資料、大量資料、最大／最小數值、重複開關、
場景切換與 Pause。不得出現重疊、裁切、漂移、超出視窗、圖示變形或無法捲動。

## 5. GDScript、Signal 與生命週期

- 函式短小、單一責任、Early Return，避免深層巢狀與隱藏副作用。
- UI 腳本只負責顯示、操作、Signal 與視覺狀態。
- 戰鬥、經濟、存檔、AI 與大型資料管理不得放入 UI 腳本。
- 優先使用 `@onready` 快取穩定 Node 引用。
- 不在 `_process()` 重複搜尋 Node 或 Group。
- 操作節點前確認存在；可能釋放的節點使用 `is_instance_valid()`。
- 動態 UI 避免重複 Signal、重複內容、舊節點未釋放與殘留引用。
- 資料變更用 Signal 驅動 UI；連接前確認未重複連接。
- `@tool` 腳本處理 `Engine.is_editor_hint()`、`is_inside_tree()` 與重新載入。
- 需要保存的動態編輯器節點設定正確 `owner`；可用靜態 Scene 節點時優先使用。

## 6. Resource 與資料邊界

必須區分：

```text
靜態 Resource
↓
Runtime 狀態
↓
UI 顯示
```

- 道具、技能、Buff、敵人與角色基礎設定優先使用既有 Resource。
- 不用巨大 Dictionary 取代正式資料結構。
- UI 不直接修改應保持不變的基礎 Resource。
- 新增資料格式前先搜尋現有資料模型。

## 7. UI 問題處理流程

### Step 1：列出證據

記錄 Scene、問題節點、父節點類型、Anchor、Offset、Size Flags、Minimum Size、
Theme、字型、圖片，以及腳本是否控制位置或尺寸。

### Step 2：找根因

依序檢查 Container、Anchor／Offset、Size Flags、Minimum Size、文字、圖片、
腳本 Layout 覆寫、動態重新排版、Full Rect 與世界／UI 座標系。

### Step 3：最小修正

優先修正 Container → Anchor → Size Flags → Minimum Size → 文字／圖片 →
移除腳本手動定位；必要時才調整 Scene Tree。

保留既有 Node 名稱、Signal、資料來源、視覺風格與玩法。

## 8. 測試與驗證

任何修改至少確認：

1. Godot 專案與受影響 Scene 可載入。
2. 無 Parser Error、Invalid NodePath、Missing Resource、Signal 錯誤。
3. 相關自動測試通過。
4. 原有流程仍可操作。
5. 動態內容不重複生成。
6. Scene／UI 關閉後無殘留狀態。
7. 沒有新增無關警告。
8. Git diff 只包含任務必要檔案。

地圖另驗證主 Scene 編輯器載入、F6、Main、Portal、Spawn、Camera、Collision 與
HUD 不重複。UI 另驗證第 4.5 節的解析度與內容狀態。

能自動化的驗證必須自動化；仍需人工視覺判斷的項目明確列出，不得假裝已驗證。
生成圖片與整體 map composition 的人工判斷必須依
`docs/09_TESTING_GUIDE.md` 第 3.1 節交給獨立 agent：檢查生成物件、整張實際
整合畫面，以及固定 3 × 2 共 6 個等分區域。任何後續圖片或排版修改都必須重做
整張與 6 區 review；review 與修正也必須消除糊爛細節、無意義重複、材質頻率
不一致、錯誤幾何與假接縫等可辨識的 AI 生成感。Town 生成圖以 Base 材料行
作為畫風筆觸基準，需對齊大型色塊、粗斷線、有限色階、石木筆觸與細節密度；
過度平滑、碎裂、寫實或高噪點的生成筆觸也必須修正。`.gd` 測試只保護可載入、
alpha、path、aspect、z-order 與
Scene/layout parity，不得取代美術審查。

## 9. 禁止事項

- 未盤點架構就開始改。
- 用固定座標或空白字元補 UI。
- 為小問題重建整套 UI／狀態管理。
- 任意改玩法、Autoload、全域狀態、根節點、資源路徑或無關檔案。
- 複製既有功能建立第二套系統。
- 在 `_process()` 做昂貴搜尋。
- 只測 Parser Error 就宣告完成。
- 沒有實際視覺或行為驗證就宣告 UI 修復完成。
- 覆蓋、刪除或提交無法確認歸屬的使用者修改。

## 10. 完成回報格式

### 問題根因

說明證據與真正原因。

### 修改檔案

逐一列出路徑與修改內容。

### UI Layout 修改

若涉及 UI，列出 Container、Anchor、Offset、Size Flags、Minimum Size、Scroll、
文字行為與移除的固定定位；未修改也要說明。

### 保留的既有行為

列出未改變的玩法、Signal、資料來源與場景流程。

### 測試結果

只列出實際執行過的命令、場景、解析度與結果。

### 尚未驗證項目

列出仍需人工判斷或環境不允許的項目；若無則寫「無」。

### 可能風險

說明剩餘風險，不用「應該沒問題」取代證據。

### 建議人工驗收步驟

提供可在 Godot 中重現的清楚步驟。
