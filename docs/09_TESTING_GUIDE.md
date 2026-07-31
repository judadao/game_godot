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

目前測試是直接繼承 `SceneTree` 的 Godot 原生腳本，存放於 `tests/`，全部以
`*_test.gd` 命名並以退出碼表示成功或失敗。專案尚未配置 GUT 或 CI；新增這些
能力前不得在交付報告中宣稱已具備。

目前工作區可發現 118 個測試腳本，涵蓋卡牌、戰鬥、地圖導航、存檔遷移、城鎮流程、秋季森林
流程、HUD 與多解析度排版。`tools/run_godot_tests.sh` 是 Linux 開發環境的
repository-owned runner，負責發現全部 `tests/*_test.gd`、隔離 user data、
掃描 Godot error markers，並可執行 editor／main smoke。

Inventory／Codex focused coverage：

- `inventory_codex_projection_test.gd`：所有已解鎖 card、已學 passive Skill 與
  Finisher 的唯一 projection、完整說明、preview kind，以及命名技能的元素／進化／
  Buff milestone metadata。
- `inventory_codex_ui_test.gd`：分頁、projection、selection、production VFX preview
  ownership、live/concept 切換與 concept crop。
- `inventory_codex_layout_test.gd`：六解析度 panel/list/active visual/explanation geometry。
  可用 `INVENTORY_CODEX_CAPTURE_ENTRY` 指定普通攻擊、Combo、Skill 或 Finisher，
  `INVENTORY_CODEX_CAPTURE_VIEW=live|concept` 選擇展示模式，再搭配 capture path/size
  產生 Vulkan 視覺比較基準。
  實際 Game projection 可用 `INVENTORY_CODEX_PROJECTION_CAPTURE_PATH` 擷取，
  不得只驗證手寫 UI fixture。

## 3. 測試分層

1. 純邏輯測試：不載入完整場景，驗證資料轉換、規則與狀態機。
2. 元件測試：實例化單一 UI、角色、系統或互動物件。
3. 契約測試：檢查節點路徑、群組、signal、資料欄位與場景註冊。
4. 整合測試：驗證 Game、地圖、HUD、CardHandUI 與流程協作。
5. 冒煙測試：以 headless 模式啟動 editor 與主場景，檢查 parser/runtime error。
6. 人工視覺驗證：Godot 編輯器與實際執行畫面的像素、層級、操作與動畫。

### 3.1 生成圖片與整體構圖 Review

生成 raster asset 的品質由獨立 reviewer agent 判斷，不由 `.gd` 測試推測。每一個
最終候選必須提供實際整合畫面，並依序完成：

1. **Object review**：以原始尺寸檢查透明邊、色邊、像素密度、畫風、材質、光向、
   比例、可讀輪廓與是否含不該出現的物件；並檢查糊爛細節、無意義重複、
   材質頻率不一致、錯誤幾何與假接縫等可辨識的 AI 生成感。Town 生成物另以
   Base 材料行為畫風筆觸基準：大型色塊、粗斷線、有限色階、石木筆觸與細節
   密度都需一致；過度平滑、碎裂、寫實或高噪點的生成筆觸視為 finding。
2. **Full-frame review**：檢查焦點、色彩層級、前中後景、遮擋、重複、左右邊界、
   建築後方與貼地空隙。
3. **6-slice review**：將完整畫面等分成 3 欄 × 2 列；逐一檢查 R1C1 到 R2C3，
   不得只放大有問題的局部。每區都需回報 pass 或具體 finding，並確認該區沒有
   與既有場景畫風不一致的 AI 生成痕跡。
4. **Severity**：使用 Critical／Important／Minor。Critical／Important 未修正前
   不得交付。
5. **Re-review**：review 後若修改任何圖片、scale、position、z-index 或排版，
   必須重新檢查生成物件、整張畫面與全部 6 區。

結構測試仍負責 PNG／Texture 可載入、透明度、source path、aspect ratio、
z-order、layout 與 generated Scene parity。圖片迭代過程不為主觀畫風建立大量
硬編碼 GDScript assertions，也不需要每版圖片都跑 full suite；在最終素材整合後
執行 affected focused tests，commit 前再執行一次
`tools/run_godot_tests.sh --suite all --smoke --strict-warnings`。

## 4. 測試命名與結構

- 檔名使用 `<behavior>_test.gd`。
- 測試腳本使用 `extends SceneTree`，保持可由 CLI 單獨執行。
- 測試函式命名描述可觀察行為，例如 `_test_canonical_path_resolves_to_authoritative_scene()`。
- 失敗訊息必須包含預期值、實際值與測試情境。
- 任何建立的節點、暫存檔或 user data 都必須在測試結束時清理或使用隔離目錄。
- 新增行為先寫會失敗的測試，確認失敗原因正確後再實作。

## 5. 執行方式

### 5.1 Focused tests

單一測試仍可直接執行：

```bash
godot --headless --path . --script res://tests/card_system_test.gd
```

更建議使用 runner，讓 user data 隔離與 marker 掃描保持一致：

```bash
tools/run_godot_tests.sh --pattern 'card_system_test'
```

常用 focused suites：

```bash
tools/run_godot_tests.sh --suite ui
tools/run_godot_tests.sh --suite cards --fail-fast
tools/run_godot_tests.sh --suite scene --strict-warnings
tools/run_godot_tests.sh --pattern 'map_registry|quick_save'
tools/run_godot_tests.sh --pattern 'town_building_ui_(contract|behavior|layout|lifecycle)'
tools/run_godot_tests.sh --pattern 'autumn_(safe_zone_contract|modular_route)'
```

### 5.2 Full regression

Linux 全量驗證：

```bash
tools/run_godot_tests.sh --suite all --smoke --strict-warnings
```

上述命令會：

- 依檔名排序執行所有 `tests/*_test.gd`。
- 為每個測試設定隔離 `APPDATA`、`XDG_DATA_HOME`、`XDG_CONFIG_HOME` 與
  `XDG_CACHE_HOME`。
- 掃描 `SCRIPT ERROR`、`Parse Error`、`ERROR:`、`Invalid call`、
  `Previously freed`、`Node not found`，並在 `--strict-warnings` 時也掃描
  `WARNING:`。
- 執行 `--headless --editor --path . --quit`。
- 執行 `--headless --path . --quit-after 300`。
- 顯示 total、failures 與 failing path；失敗時保留 log path。

若 Godot 不在 `PATH`，指定執行檔：

```bash
GODOT_BIN=/home/judd/.local/bin/godot tools/run_godot_tests.sh --suite all --smoke
```

### 5.3 Windows compatibility

Windows 尚未有 repository-owned PowerShell runner。需要在 Windows 執行時，可用
`GODOT_BIN` 等價指定 console executable，或沿用下列手動模式：

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
以退出碼 `0` 表示成功，非零表示失敗。

若舊版 runner 曾在 repository root 留下 `.tmp*`、`.final_*`、
`.test_userdata` 或根目錄 `*.log`，執行：

```powershell
& .\tools\clean_local_test_artifacts.ps1
```

此腳本只處理列名的本機測試／review artifacts，明確保留 `.git` 與 `.godot`。

```text
SCRIPT ERROR
Parse Error
ERROR:
```

不要只依靠程序退出碼判定成功，因為 Godot 有時會在退出碼為零時輸出非致命錯誤。

## 6. UI 與多解析度驗證

AutumnHUD（含內嵌 CardHandUI）至少驗證以下視窗尺寸：

- 1280×720（專案基準）
- 1600×900
- 1920×1080
- 2560×1440
- 1152×720（較窄比例；現有 guardrail suite）
- 2560×1080（較寬比例）

自動測試應檢查安全區、地圖 viewport、卡牌操作區、焦點、遮擋與螢幕邊界。Autumn
HUD 還要檢查 XP 的 current／required／NEXT remaining projection、HP／AP／XP／level
短暫 emphasis 會回復穩定狀態，以及四張 fixed cards 都有至少 48px 的不同 semantic
icon、12px 以上招式名與 Healing／Flame／Volley／Storm visual family。人工驗證則確認
字體清楚、卡牌能先靠 icon/色族判讀、HUD 不阻擋玩法資訊、動畫沒有引發 layout
跳位，以及編輯器所見與執行結果一致。

設定 `AUTUMN_HUD_CAPTURE_DIR` 後執行 `autumn_hud_v3_layout_test.gd`，會由六個
exact-size `SubViewport` 輸出 `autumn_hud_<width>x<height>.png`，不受桌面工作區
最大視窗尺寸限制。

Autumn map 變更至少需執行 `autumn_safe_zone_contract_test.gd`、
`autumn_modular_route_test.gd`、`battle_map_v2_scene_contract_test.gd`、
`battle_map_v2_spatial_flow_test.gd` 與 `town_autumn_portal_flow_test.gd`。程序路線
必須驗證同 seed 重現、不同 seed 變化、24 個以上 chunks、完整寬度覆蓋、十柱式
無縫地形、至少 96px route relief、24px 最大相鄰高差、至少五種 floor profiles、
6–12 個 flat chunks、最多兩個連續 relief chunks、8–14 個 platform chunks、
最多兩個連續 platform chunks、高層樹冠路線、視野外生怪及兩端 portal 都回安全
區。Safe zone 另需驗證 map width 與 camera right 都是 1280。

Theme 修改需載入受影響 scene，確認 theme、theme variation、font、
StyleBox 與所有互動狀態可解析；Town 功能建築與 Shop frame 共用
`TownServiceFrameTheme.tres`，layout test 會檢查 assignment、variation 名稱、
resolved window StyleBox 與各功能替代狀態；其餘 scene-local override 必須分開
驗證。Animation 修改需
檢查 AnimationPlayer/AnimatedSprite2D 的 library、track target、loop 與完成狀態，
並實際跑過進入、中斷、重播與場景切換。

Combat VFX 修改至少執行
`skill_cast_presentation_test.gd`、`elemental_attack_aura_test.gd`、
`fire_ultimate_vfx_test.gd`、`ice_ultimate_vfx_test.gd` 與
`combat_vfx_integration_test.gd`。大招地面殘留另執行
`elemental_ground_trail_test.gd`，驗證三張四象限 atlas、三種獨立 topology、
路徑端點、visual budget、unscaled fresh／active／decay 與自動清理；大招致死
演出另執行 `ultimate_enemy_defeat_presentation_test.gd`，確認 gameplay／碰撞／
獎勵立即結算，但敵人保留到 Fire／Ice impact delay 後才 dissolve／burst。
命名技能另執行
`named_skill_vfx_test.gd`，驗證五個終結技、四個觸發技各自擁有唯一 atlas row、
五個可拼裝部件、精確 ID、正式 element、九種唯一 archetype、各自不同且遞增的
`beat_pattern`、三級 `evolution_layers` 與對齊的
`stack_milestones`／`stack_traits`。`named_skill_vfx_evolution_test.gd`
另驗證 `play()` 收到 evolution level／buff stacks、Lv.3＋多層 Buff 會增加實際
parts，而不是只放大或加亮同一模板；anticipation／impact／decay 時序仍由
`named_skill_vfx_test.gd` 保護。
元素資料變更另執行 `element_taxonomy_test.gd`，確認唯一正式列表為
water／fire／wind／lightning／ice／poison／light／dark／normal、legacy aliases
只在邊界正規化、每把武器有有效 `primal_element`、base blessing 使用 canonical
element，且融合 blessing 的 `elements` 陣列保留兩個 canonical component IDs。
另以 graphical
Forward+ renderer 確認火／冰
粒子、環線、標題層級、世界中心與自動 cleanup；標題 layout 需跑六解析度矩陣。
火系可用 `FIRE_ULTIMATE_VFX_CAPTURE_PATH` 擷取 impact crown，冰系可用
`ICE_ULTIMATE_CAPTURE_PATH` 與 `ICE_ULTIMATE_CAPTURE_PROGRESS` 分階段擷取；
地面素材可用 `ELEMENTAL_GROUND_TRAIL_CAPTURE_PATH` 擷取三系 contact sheet；
敵人消滅可用 `ULTIMATE_ENEMY_DEFEAT_CAPTURE_PATH` 與
`ULTIMATE_ENEMY_DEFEAT_CAPTURE_DELAY` 擷取 impact 後畫面。截圖必須同時確認
滿版覆蓋、玩家中心可讀性、路徑與招式方向一致，以及敵人不早於視覺命中消失。
普通劍氣另執行 `auto_attack_feedback_test.gd`；可用
`AUTO_ATTACK_FEEDBACK_CAPTURE_ELEMENT=flame|frost` 與
`AUTO_ATTACK_FEEDBACK_CAPTURE_COMBO=0|3|6|9` 分離擷取屬性及 Combo 疊層，
並以 `AUTO_ATTACK_FEEDBACK_CAPTURE_DELAY` 分別擷取 weapon release、blade
travel 與 directional impact；不得只用多元素混合畫面或單一中間幀判定每一
層是否清楚。測試同時要求三段各有八幀 sheet／mask、premium 4×2 additive
parts atlas、前向空心月牙的 leading
edge／hollow center／上下刃尖、前半程至少完成 78% 距離、impact timing signal，
三個 flow ribbon history samples、三層非同步 silhouette deformation，且 primary
procedural stroke count 為零。測試也檢查
`assets/generated/vfx/parts/` 的 core blade、
crescent edge、afterimage、shards 與 impact wedge 部件 sheet，確認普通劍氣由
模組化 2D 素材拼裝，而不是單張火焰圖。deterministic silhouette 重新生成時先執行
`python tools/build_basic_attack_vfx_sheets.py`，再以 editor import 驗證 runtime
texture；premium atlas 的格位與 prompt 依
`docs/art_concepts/basic_attack_crescent_v3.md`。Discovery Codex 另以
`inventory_codex_layout_test.gd` 六尺寸 fixture
檢查 preview-local 起點、向右旅行向量、resize 重建與 neutral Basic Attack
元素投影。

Dedicated Town building UI 與 Shop redesign 的最低驗證矩陣：

| Test | Contract |
|---|---|
| `town_building_ui_contract_test.gd` | 四個 screen 可載入；Full Rect、PROCESS_MODE_ALWAYS、class/API/signal/semantic nodes |
| `town_building_ui_behavior_test.gd` | Material offer intent；blacksmith 升級／recipe intent；Town Hall 精確升級；一般 Shop quantity 與圖紙商 buy-only |
| `town_building_ui_layout_test.gd` | 六解析度的 window/controls/text/icon 邊界，以及共同 Theme、1040×640 frame、58px header、218／270px 欄寬與 Close variation |
| `town_building_ui_lifecycle_test.gd` | open/close/ui_cancel signals、focus release/restore、重開不重複 controls |
| `shop_system_test.gd` / `ui_keyboard_test.gd` | 交易 ownership、方向 focus、quantity controls 與 player input lock |
| `forge_catalog_test.gd` / `forge_service_test.gd` | offer/recipe schema、Tier gate、購買、鍛造與 sale escrow |
| `forge_game_integration_test.gd` | 圖紙＋工具購買後鍛造 equipment／Sword Soul、升級、上桌販售、gold 與 meta save |

Layout test 另外要求每個 screen 顯示至少三種 distinct functional icon；Button
必須有文字、icon 或 tooltip，且可見 hit target 不小於 32×32。
設定 `TOWN_BUILDING_UI_CAPTURE_DIR` 的 PNG capture 需要 graphical Godot renderer，
只產生 1280×720 人工比對圖；headless runner 負責六解析度 geometry/behavior，
不等待 `frame_post_draw`。

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

Scene directory changes must run these permanent contracts:

- `tests/scene_cleanup_contract_test.gd`：retired zero-reference scenes stay absent.
- `tests/scene_feature_directory_test.gd`：UI/dev/test fixtures remain in their owner folders.
- `tests/town_residence_ui_layout_test.gd`：住宅資訊 UI 在六個基準解析度內不裁切。
- `tests/town_scene_path_structure_test.gd`：Town active and legacy linked scenes keep their classified paths.
- `tests/town_building_perspective_contract_test.gd`：六棟 B2 建築共用同一透視
  profile，locked-A 背景與 B2 地標 source 精確，visible 街景只使用 B2、浮空旗幟
  保持 hidden。
- `tests/town_landmark_composition_contract_test.gd`：舊背景疊層與東側立面遮擋物
  保持 hidden；古樹、火炬與傳送門使用 modular-v3 source 並把比例失真限制在 2%。
- `tests/town_location_label_proximity_test.gd`：六個建築木牌位於建築輪廓上方，
  只接受 Player 進出完整地基 Area 的 signal，離開後全部 hidden。
- `tests/map_registry_test.gd` and `tests/quick_save_migration_test.gd`：stable and legacy map paths remain loadable.

Any scene move must also run `scene_registry_test.gd`, `content_validation_test.gd`,
headless editor scan, main-scene smoke, and the affected feature tests.

## 8. 測試隔離

測試不得讀寫玩家真實存檔。CLI 測試使用專案內隔離的 user data 位置，例如 `.test_userdata/`，並避免與平行執行的測試共用可變檔案。對時間、亂數或輸入敏感的測試應注入可控制的值。

目前 runner 預設逐一執行 SceneTree 測試。若未來平行化，必須先隔離存檔路徑、
DisplayServer 與共享資源。

## 9. 回歸策略

修復 bug 時，測試必須重現原始失敗。重構時先建立或確認 characterization test，保持外部行為不變。驗證順序：

1. 新增或受影響的單一測試。
2. 同領域測試。
3. 所有自動測試。
4. editor headless 冒煙測試。
5. 主場景 headless 冒煙測試。
6. 影響視覺時進行人工檢查。

生成圖片任務的第 6 步必須使用第 3.1 節的獨立 agent full-frame／object／
6-slice protocol；任何後續視覺修改都要重做整套 review。

## 10. Checklist

- [ ] 已先建立可重現需求或 bug 的測試。
- [ ] 已確認測試在實作前因正確原因失敗。
- [ ] 已執行受影響領域與全量測試。
- [ ] 已掃描 Godot error 輸出。
- [ ] 測試沒有污染真實 user data。
- [ ] UI 修改已驗證四個基準尺寸與窄／寬比例。
- [ ] Scene/JSON 變更已更新契約測試。
- [ ] 文件與實際執行指令一致。
- [ ] 生成圖片已完成獨立 agent 的 object、full-frame 與 6-slice review。
- [ ] 最後一次視覺修改後已重新 review，而非沿用舊結論。

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
- 用 GDScript assertions 取代畫風、構圖與像素密度的獨立視覺 review。
- 只看整張縮圖或單一問題 crop，未檢查固定 12 等分區域。

## 13. Code Example

```gdscript
extends SceneTree

var _failures := 0
const MAP_REGISTRY_SCRIPT := preload("res://scripts/systems/map_registry.gd")

func _init() -> void:
	var registry := MAP_REGISTRY_SCRIPT.new()
	_expect_equal(registry.canonical("res://scenes/maps/town/TownMap.tscn"),
		"res://scenes/maps/town.tscn", "town canonical path")
	quit(0 if _failures == 0 else 1)

func _expect_equal(actual: Variant, expected: Variant, context: String) -> void:
	if actual == expected:
		return
	_failures += 1
	push_error("%s: expected %s, got %s" % [context, expected, actual])
```

上例直接驗證目前的純 `MapRegistry` owner；另以
`tests/map_registry_test.gd` 保護 `Game` compatibility wrappers。

## 14. Scene Tree Example

```text
Game
├── MapRoot
│   └── CurrentMap (AutumnForest)
├── HUDLayer
│   └── HUD
│       └── AutumnCardHandUI
└── MenuLayer
```

整合測試應確認 Autumn 只有一個 HUD root 掛在預期 CanvasLayer 下，手牌位於
HUD 的 `CardStage` 內；地圖切換不會複製或遺失 HUD subtree。

## 15. Godot Example

```gdscript
var packed := load("res://scenes/ui/autumn/AutumnHUD.tscn") as PackedScene
if packed == null:
	push_error("AutumnHUD scene failed to load")
	quit(1)
	return

var instance := packed.instantiate()
root.add_child(instance)
await process_frame
if not instance.is_inside_tree():
	push_error("AutumnHUD was not added to SceneTree")
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

## 17. Card、Skill、Growth 與 Autumn HUD 必測矩陣

| Area | Minimum contract evidence |
|---|---|
| CardInstance | 五牌堆 identity 不變；個別 level；Ember 遵循普通卡 lifecycle；Quickstep 不存在於 catalog/runtime instances |
| CardCollectionService | add／fusion／exact removal 同步 Meta／Run／Deck 且共享同一 object；partial failure restore pile order、cooldown timing、level 與 unlocked fields |
| Migration | schema v6 會移除 retired Quickstep，且舊 payload deterministic、idempotent；card/skill/auto-attack 修復可驗證 |
| Cooldown/exhaust | cooldown 到期回 discard；exhaust 不回收；pause 時 timer 不動 |
| Status | source refresh、最高 armor tier、reduction cap 60%、unblockable bypass、regen/lifesteal |
| Enemy pursuit | 玩家同層時一般 archetype 步行；Leap 近身不連跳、遠距可撲跳、玩家在可達上方才爬台跳；落地有重新判斷緩衝 |
| Skill recipe | attack-only、multi-hit 一次 event、8 秒 window、count/exact sequence reset、獨立 cooldown |
| Memory Library | capacity 10/14/18/24/30；learned 與 active loadout 分離 |
| Growth queue | wave new-card 可直接 skip；滿 16 張可 replace/skip；EXP upgrade 五選一、全滿後獨立 fusion；無候選才 fallback；FIFO 不漏頁 |
| Fusion | 精確選兩張不同 Lv.3 instances；消耗兩張、產生 Lv.1、淨減一 |
| Deck/hand | 傳送門前四格直選；Healing 專用格＋3 unique Combo；候選依格篩選並預覽終結技；QWER 使用後保留原 slot |
| Basic Attack | 戰前獨立選 attack；Run lock；0 AP；不進牌堆；有水平走廊目標時自動攻擊；不向上／下追蹤；無目標不消耗 cooldown 或公式 |
| Combo formula | 只有 Combo 記錄且 Healing 不打斷；精確已學會 AAA/ABC 配方；多招 FIFO 排隊；下一發自動水平攻擊逐一施放；formula stacks 不消耗；各卡效果獨立 1.5 秒，單一效果到期只撤銷自己的 modifier；Combo Chain 維持獨立 2.5 秒 |
| Divine Gifts | 每 stage/wave 一個必選頁；主神賜提供稱號；全 inventory 合併 mechanics；Lv.3 融合材料退出獎勵池；fusion-only 可 skip |
| Growth card readability | upgrade/new/fusion choice 顯示 icon、類型色、AP/level；多效果使用 bullets；六解析度不裁切 |
| Dash | ↑ 只觸發 Jump；Space 觸發玩家固有 Dash；不進牌庫/手牌、不耗 AP；Dash Combo infusions 使用 `target_action=dash` |
| Pause | gameplay/AP/card/status/skill/wave/projectile timer 全停；UI 可操作；token 成對釋放 |
| HUD authority | Autumn 只有一個 HUD root；hand 在 `CardStage`；Town HUD identity 不變 |
| HUD projection | status/objective 左上、boss/toast 上中、bottom stage 完整；toast max 3/1.5 秒/duplicate refresh |

六解析度 geometry test 要逐一 assert：

- semantic node rect 在 viewport 內；
- top-left 與 top-center 不互蓋；
- bottom stage 不蓋 world interaction prompt；
- 四張 Combo／Healing cards、large semantic icons、XP、AP、Combo Chain 清單與
  resources 不裁切；
- 1152×720 與 2560×1080 仍保持相同 ownership，不生成替代 layout；
- modal choice grid、繁中/英文長字、focus navigation 與 confirm button 可用。

建議 focused entrypoints 應以 repository 實際存在檔名為準，至少涵蓋
`card_instance_*`、`card_collection_service_test.gd`、`combat_status_controller_test.gd`、
`skill_recipe_manager_test.gd`、`growth_choice_queue_test.gd`、
`card_growth_ui_*` 與 `autumn_hud_v3_*`。最後仍需執行全量 SceneTree tests、
editor smoke、main smoke 與人工六尺寸截圖/操作檢查。

## 18. Future Extension

- TODO：新增 Windows PowerShell wrapper，與 Linux runner 使用相同 suite 與 marker 規則。
- TODO：評估導入 GUT；導入前保留既有 SceneTree 測試可執行性。
- TODO：建立 CI，執行全量測試、editor 與主場景冒煙測試。
- TODO：建立可重現的截圖比較流程，避免跨 GPU 的脆弱像素比對。
- TODO：將目前人工量測升級為效能預算、記憶體成長與長時間波次自動測試。
- TODO：建立 coverage/需求追蹤表，但不得用數字取代行為驗證。

## 19. Related Documents

- [AI Guide](01_AI_GUIDE.md)
- [Scene Structure](03_SCENE_STRUCTURE.md)
- [UI Guide](04_UI_GUIDE.md)
- [Coding Standard](05_CODING_STANDARD.md)
- [Debug Guide](10_DEBUG_GUIDE.md)
- [Git Workflow](11_GIT_WORKFLOW.md)
