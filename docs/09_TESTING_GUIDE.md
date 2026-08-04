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

目前工作區可發現 160 個測試腳本，涵蓋卡牌、戰鬥、地圖導航、存檔遷移、城鎮流程、秋季森林
流程、HUD 與多解析度排版。`tools/run_godot_tests.sh` 是 Linux 開發環境的
repository-owned runner，負責發現全部 `tests/*_test.gd`、隔離 user data、
掃描 Godot error markers，並可執行 editor／main smoke。

Inventory／Codex focused coverage：

- `inventory_journal_ui_contract_test.gd`：四個章節、單一 active page、tab icon／32px
  hit target、背包／圖鑑 filters，以及 equipment intent signal/button。
- `inventory_journal_projection_test.gd`：玩家狀態、三個裝備欄位、owned Sword Soul
  instance identity，以及招式／七個 autumn enemies／劍魂／十件裝備圖鑑 projection；
  也從正式 Game 的 `I` 路徑驗證圖鑑資料注入與 13 系列／39 招 runtime rows。
- `inventory_journal_layout_test.gd`：1152×720、1280×720、1600×900、1920×1080、
  2560×1080、2560×1440 的整本等比 frame、page bounds、center gutter 與極值內容；
  `INVENTORY_JOURNAL_CAPTURE_DIR` 只在 graphical renderer 產生四章 review captures。
- `inventory_codex_projection_test.gd`：`skills.json` 的 13 系列、39 招唯一 projection；
  驗證 catalog `skill_series_rank` 與 basic／advanced／master `tier_rank` 順序、各階 13 招、
  中文名稱／引言／只含名稱與順序的三張劍魂組合、招式頁不投影效果數值、退役被動與舊名稱
  不再出現，以及每招暫用的精確 named VFX profile 確實存在。
- `inventory_codex_ui_test.gd`：以反轉輸入驗證 UI 仍重建 13 個不可選系列標題與每組
  基本／進階／大師三列；另驗證 39 招 selection、系列／階級／元素文字、斜體引言→
  劍魂組合的 detail 順序，且系列語彙、特效狀態、效果與數值、逐張劍魂效果與演出流程
  保持隱藏；同時驗證 temporary VFX preview ownership，
  以及退役 concept controls 永遠隱藏、相容入口固定回到 live view。
- `inventory_codex_layout_test.gd`：六解析度 panel/list/active visual/explanation geometry，
  並投影全部 39 招、逐一實例化其唯一暫用動畫，驗證 `190px` 橫向 live frame 的水平完整 travel、
  垂直完整主體、地面錨點與最小可讀占比；world travel 超過 `220px` 時只在 Codex
  壓縮，測試另鎖定實戰距離不得跟著縮短。
  可用 `INVENTORY_CODEX_CAPTURE_ENTRY` 指定任一新 skill ID，
  再搭配 capture path/size 產生 Vulkan 的 live VFX 視覺比較基準；舊的
  `INVENTORY_CODEX_CAPTURE_VIEW` 不得使 concept art 回到玩家畫面。
  實際 Game projection 可用 `INVENTORY_CODEX_PROJECTION_CAPTURE_PATH` 擷取，
  並以 `INVENTORY_CODEX_PROJECTION_SECTION=techniques|enemies|sword_souls|equipment`
  指定圖鑑章節；不得只驗證手寫 UI fixture。

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

### 5.4 Agent headless／顯示政策

代理進行開發與自動驗證時，不得在使用者桌面開啟 Godot editor、遊戲、F6 scene、
preview 或 capture 視窗。Focused tests、資源 import、editor parse、scene smoke 與
main-scene smoke 預設都使用 `--headless`；禁止直接執行裸 `godot` 或非 headless 的
`godot --editor --path .`。

少數依賴 `frame_post_draw` 的 capture 不能使用 dummy headless renderer。這類工作只有
在已配置、且不會顯示到使用者桌面的 offscreen／虛擬顯示環境中才可由代理執行。
若環境沒有這項能力，代理只執行可重現的 headless geometry／behavior contracts，並在
交付報告標記 graphical／互動視覺驗收尚待使用者自行開啟專案確認；不得自行彈出視窗。

## 6. UI 與多解析度驗證

AutumnHUD（含內嵌 CardHandUI）至少驗證以下視窗尺寸：

- 1280×720（專案基準）
- 1600×900
- 1920×1080
- 2560×1440
- 1152×720（較窄比例；現有 guardrail suite）
- 2560×1080（較寬比例）
- 2864×1080（玩家回報的超寬回歸尺寸）

自動測試應檢查安全區、地圖 viewport、卡牌操作區、焦點、遮擋與螢幕邊界。Autumn
HUD 還要檢查 XP 的 current／required／NEXT remaining projection、HP／AP／XP／level
短暫 emphasis 會回復穩定狀態，以及四張 fixed cards 都與等寬 slot 寬高誤差不超過
1px、完整吃滿 `FrontRow`、主插畫至少覆蓋 72% 卡寬與 42% 卡高、12px 以上招式名，以及
Healing／Flame／Volley／Storm visual family。另須以超長公式、終結技與神賜名稱確認
右側 `ActivityFeed` rect 不變，所有單行 projection 均裁切並提供 tooltip。人工驗證則確認
字體清楚、卡牌能先靠 icon/色族判讀、HUD 不阻擋玩法資訊、動畫沒有引發 layout
跳位，以及編輯器所見與執行結果一致。

待施放終結技的長名稱回歸還必須確認：第一行以裸招式名開頭且不含祝福冠名，第二行
完整顯示或裁切祝福冠名，第一行 tooltip 保留「冠名＋招式名」的完整字串。

`combo_card_art_contract_test.gd` 由 32 個終結技 recipe 動態推導 20 張唯一公式劍魂，
檢查每張都有唯一繁中名稱／說明、唯一 generated path、可載入的 256×256 Texture2D，
且 `AutumnBattleCard` 實際投影相同中文與圖片。Generated raster 最終仍須獨立檢查
20 張原生圖、44px contact sheet、六解析度完整畫面與一張完整畫面的固定 3×2 六切片。

`generated_catalog_icon_contract_test.gd` 另檢查完整 38 cards、32 finishers
與 10 equipment（共 80 張）各自擁有依 ID 命名、唯一、可載入的 256×256 generated
icon，並驗證所有 generated card art 在 `AutumnBattleCard` 使用 linear filtering。
新的 39 招目前允許空 `icon_path`；未來只要補入 path，測試就立即要求唯一、可載入且
為 256×256，避免暫時 fallback 被誤寫成正式逐招圖示。
最終視覺審查需看四類 native contact sheet、44／52px 縮圖、實際 Combat HUD 與
Inventory 六解析度 full frames，以及代表 full frame 的固定 3×2 六切片。

`blessing_loot_progression_test.gd` 鎖定 EXP Blessing-only、all-max fallback、
Elite／Boss merge gating、三類敵人的 money roll、Elite／Boss-only material roll、
monster-specific payload 與實體 bag 單次收集。`deck_builder_four_slot_test.gd` 另驗證
候選 keyboard focus 自動捲動，以及 hover／focus 即時效果預覽。

設定 `AUTUMN_HUD_CAPTURE_DIR` 後執行 `autumn_hud_v3_layout_test.gd`，會由七個
exact-size `SubViewport` 輸出 `autumn_hud_<width>x<height>.png`，不受桌面工作區
最大視窗尺寸限制。Windows 擷取需使用非 headless 的 compatibility renderer；dummy
headless renderer 不會送出 `frame_post_draw`，不可把等待超時誤報為 layout failure。

設定 `CARD_GROWTH_CAPTURE_DIR` 後執行 `card_growth_ui_layout_test.gd`，會輸出七種
`card_growth_divine_<width>x<height>.png`。神賜頁必須人工確認大型符印、三張卡等寬、
2–3 條具體效果、selected／focus 差異與 `SelectionSummary`；1152×720 不得裁字，
1920／2864 寬螢幕則由 responsive modal 使用可用空間。

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
命名動畫 library 另執行 `named_skill_vfx_test.gd` 與 `named_skill_vfx_evolution_test.gd`，
保護五個 atlas Finisher 基底、四個退役 trigger profile、五個可拼裝 parts、正式 element、
archetype、beat pattern、三級 evolution、stack progression 與收尾時序。
`storm_charge_vfx_test.gd` 另驗證專用 scene 的五個依序節拍、至少十條固定語意導電
路徑、10/4/1.4px 主幹與 6/3/1px 次分支三層光階、原地 anchor、水平位移零、
劍身相連的右向 contact、單一高潮與同路徑單調回縮，以及 level 1–3 只增加有界
粒子／結構細節。舊卡牌 combat VFX integration 仍需確認 `storm_charge` 的專用
`special_vfx_id`／preview kind；新的 39 招圖鑑不把該舊卡或四個 trigger profile
重新列為現役技能。
Graphical 5-beat contact sheet 是必要視覺證據；只有結構 PASS、但仍呈現細線菱形／鋸齒
或泛用 projectile 時，不得接受。
`finisher_named_vfx_catalog_test.gd` 再由 `combo_finishers.json` 動態驗證全部 32 招：
每個 recipe 都能解析 profile，繁中名稱／icon path／role 完全一致，geometry／particle／
light identity 完整且組合可區分，粒子 count 維持 1–256；每招還必須有唯一
`material_path`、存在的 `storyboard_path` 與非空 `semantic_object`。Runtime scene 能
播放並回傳精確 identity、`presentation_mode = "2_5d"`、有意義輪廓以及 legacy atlas／
icon echo 關閉狀態；另必須解析可載入的 4×3 手繪物件 sequence、十二個 authored frames、
固定 `ground_anchor_ratio = 0.82`、source position 為原點、source rotation 為零，並回報
`procedural_flat_object = false` 與 `crossfade_slideshow = false`。
`FinisherGeometryCore` 固定隱藏七個完整 material／semantic planes，只顯示三個手繪
物件 body／chromatic glow layers 與三個 particle layers，基底共六層；最多三個實際
持有祝福各自再增加一個 source particle 與一個 `PointLight2D`，融合／進化祝福仍只算
一個 overlay，總可見層上限十二。Source atlas 每格四邊必須保留 20px 純黑安全留白；
runtime frame 使用無 mipmap 的 linear filtering，並再將每格邊緣內縮至少 6px，必須
排除 registration guide、相鄰格與 glow shader 4px footprint 造成的黑線切斷。
Charge／Attack／Trail／Impact／Debris 只供 trigger，
不得混入 Finisher。結構測試另驗證每張 material plate 可解碼、至少 1024×1024 正方形、
四角維持 additive 用純黑留白且畫面內確實存在可讀亮部；這些檢查不取代人工美術審查。
`auto_attack_feedback_test.gd` 另要求 `combo_visual_profile.finisher = true` 時共通劍氣、
premium crescent 與元素 projectile layers 全部關閉，只保留命中 timing 與文字回饋。

每招的 `profile.choreography` 另是多部件連續動作的資料 authority，必須包含
`family`、`spawn_primitives`、`piece_count`、`formation`、`paths`、`impact` 與
`residue`。Catalog contract 要求至少六個 choreography families、至少十二種不重複的
出生／路徑／接觸／餘韻 signature，且每招資料至少列出三個語意組成部件。Runtime
diagnostics 必須在 anticipation／travel／contact／afterglow 四段回傳不同
`phase_signature`，並證明 `full_plate_travel = false`；單張完整 semantic plate 整體搬移、
只做縮放或 opacity 變化都不符合這項合約。

設定 `FINISHER_VFX_CAPTURE_DIR` 後，`finisher_vfx_visual_capture_test.gd` 會輸出四張
1920×1080 review sheets；每張以 4×2 顯示八招，每格並排 anticipation／travel／
contact／afterglow，並附 recipe icon、繁中名、role 與 ID。相同 capture directory 的
`native/` 另輸出 128 張 `720×405` 的
`<finisher_id>_<anticipation|travel|contact|afterglow>_native.png`；每張使用
`preview = false` 的實戰 scale、Lv.3／9 stacks 與深色戰鬥背景，保留不遮住效果的小型
繁中名／ID 標籤。Capture test 會比較相鄰關鍵幀的 sampled pixel difference、效果
centroid、bounds 與 12×6 occupancy，要求每段都有可見影像差異與語意剪影變化；只檢查
「非空」不算通過。四張 sheets 只負責跨招式／跨時序比較，不能取代這 128 張
native-detail sequence evidence。無 env 時此測試 headless PASS；真正擷取不得使用
`--headless`，因 dummy
renderer 不會送出 `frame_post_draw`。Windows 範例：

相同 capture directory 的 `motion/` 另輸出 32 張 1440×810 的
`<finisher_id>_motion_12f.png`。每張固定 4×3 排列完整十二格 runtime 時序；capture
會驗證十二個 authored frame index 全部出現。獨立 reviewer 必須檢查每一張，確認
接地線水平、整體未旋轉、動作連續且沒有用單一斜線 lane 代替透視。

每張 sheet 同時輸出 `<sheet_name>_slices/`，內容固定為 3 欄×2 列的六張等分原像素
slice；獨立 reviewer 必須逐張檢查，不能只看縮小後的完整 sheet。

```powershell
$env:FINISHER_VFX_CAPTURE_DIR = 'D:\tmp\finisher_vfx_review'
& 'D:\JUDD\game\game_godot_with_git_20260802_233641\godot\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe' `
  --path . --rendering-method gl_compatibility `
  --script res://tests/finisher_vfx_visual_capture_test.gd
Remove-Item Env:FINISHER_VFX_CAPTURE_DIR
```

### 6.1 Finisher VFX 原創品質門檻

「高階 2D JRPG／Octopath-level」在本專案只表示品質門檻：清楚的 anticipation
silhouette、受控的環境壓暗、具材質層次的能量匯聚、單一明確 impact 焦點、節制的
volumetric light 與可讀 afterglow。它不是複製特定作品的授權；禁止重製任何角色、
徽記、招式構圖、鏡位、逐幀 timing、粒子輪廓、配色序列或其他受保護視覺資產。
本專案的實作門檻固定為純 CanvasItem 2.5D：review 必須先看得到由線條／幾何構成的
由手繪 sprite poses 組成的具體語意物件，再看到 construction、travel、contact、transformation、residue 的連續
因果；同時保有一致的 z-depth、前中後景 scale／parallax、rim light 與 back light。
主要運動、裂痕與殘留必須沿地圖地面的水平基準；垂直分量只能來自物件本身合理的
升起、墜落或生長。整張 sprite 禁止旋轉，遠近只能以 scale、遮擋、間距與 z-order
表示。十二格必須是連續重畫的動作，不得以照片 cross-fade 或單一斜線 lane 代替動畫。
Generic ground sigil、同心圓、鐘面刻度、放射網格、icon echo 與無來源線條都視為失敗，且不得出現
Node3D／Camera3D／3D mesh 或 SubViewport 離屏渲染依賴。

獨立 reviewer 必須逐格檢查四張 sheets 的 32 招與四個連續時間點，再逐張檢查
`native/` 的 128 個實戰比例關鍵幀與 `motion/` 的 32 張十二格 runtime sheets，並確認：

- 名稱、圖示、storyboard 的具體物件、粒子物理來源、palette 與 light motif 語意一致。
- 每條線屬於物件輪廓、運動路徑或受力結果；不可只是填空的幾何裝飾。
- 只看剪影與節奏仍可分辨同基底招式，不能只靠換 hue。
- anticipation 不提前爆白；impact 有主次光階；afterglow 能清楚收束而非突然消失。
- travel 明確移動或組裝語意部件，contact 明確變形／破壞；四格不得只是同一張完成圖
  的縮放、淡入與粒子 dissolve。
- bloom、粒子與細線沒有淹沒玩家／敵人輪廓，也沒有噪點、假接縫、破碎幾何或
  無意義重複。
- 任何 geometry、particle count、palette、scale、位置、z-order 或 timing 修改後，
  四張 sheets、128 張 native sequence、32 張 motion sheets 與實際戰鬥 full-frame 都必須重新 review；
  Critical／Important finding 清零前不得提交。

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
- `tests/town_eternal_flame_animation_test.gd`：不滅火炬 Base v5、三層火焰、
  同源火盆前緣遮擋、充能循環與火盆接觸線 pivot 保持獨立且可重建。
- `tests/town_battle_portal_animation_test.gd`：傳送門 Base v5、門洞遮罩與
  完整 underpaint、
  core/highlight 各 12 幀手繪逐格、6 FPS／2 秒 loop、次光相位差、符文呼吸，
  以及 `BattleGateway` presentation 邊界保持一致。
- `tests/town_ambient_animation_test.gd`：`TownBackdrop` 的 ambient instance、
  完整古樹固定基底、八區枝根固定且在 calm／gust 均可見擺動的樹冠模組、
  十組 position／scale／skew 固定的屋後局部葉團、六種無樹幹 atlas region、
  三張 12 幀透明 atlas、
  五組單向落葉、
  十個群組／零散鳥停棲點與起飛 presentation contract。
- `tests/town_building_animation_test.gd`：`TownBackdrop` 的 building-animation
  instance、十一組對齊可見玻璃格且錯相低幅微閃的窗光、八幀手繪爐火、七組低幅
  布料、Town Hall 步進秒針、手繪劍光與不播放旋轉動畫的靜態手繪齒輪
  presentation contract。
- `tests/town_sky_cloud_animation_test.gd`：cloud-free 天空的覆蓋與 tint API、八個透明
  手繪雲物件、邊緣假接縫清理 shader、錯速低幅漂移、完整離場回繞，以及
  sky／cloud／mountain z-order contract。視覺驗證需比較兩個時間點的完整畫面、各自固定
  3 × 2 六區、cloud-free 天空原圖及八個實際套用 shader 後的原尺寸雲物件。
- `tests/town_npc_animation_test.gd`：九個 Town placement 的 dedicated scene link、
  concept-derived 透明 cutout、stable Visual hierarchy、六位 residents 與兩位 visitors 的
  `AnimatableBody2D` contract、4 columns × 13 rows 的 idle／walk／sit／chat／laugh／happy／
  sad／surprised／angry／idle_look／idle_stretch／greet／work、生成 frame 的非空／無裁切／
  pose 差異、祭司四組 8 幀完整姿勢成人比例動畫、九個不同 world texture identity、Autumn
  seated merchant 與 compatibility Merchant，以及 display-only／interactive 邊界。視覺驗證需檢查
  idle/showcase 兩張 Town full-frame、兩組固定 3 × 2 slices、八張原尺寸 resident／visitor
  atlas、living-Town 時序 full-frame 與 13-state sheet；其中 row 4–8 要確認八份 authored
  emotion strips 都維持 132 px／`y=144` normalization，runtime 沒有額外縮放或 bob。
- `tests/town_npc_interaction_catalog_test.gd`：十一份 gameplay JSON 中的 Town interaction
  catalog schema、九種 stable IDs、role／archetype 與 visitor eligibility、directional
  share-goods、雙方 sequence、distance／duration／cooldown、deep-copy boundary，以及 caller-roll
  deterministic weighted selection。
- `tests/town_npc_life_test.gd`：六個自主 NPC 的 group／home anchor、reserved partner、catalog
  interaction、social-greet → chat／work → react → farewell sequence、雙向面向、familiarity／
  cooldown、角色化 work activity、取消／external lock 與完成後返回精確原位。
  行為參數改動後必須以 `TownLifePreview.tscn` 擷取 idle、walk、social sequence、return-home
  時點，並在最後整合畫面重做固定 3 × 2 六區審查。
- `tests/town_npc_facing_direction_test.gd`：女巫 atlas 原生朝左、預設角色原生朝右，並驗證
  `set_facing_direction()` 的 `flip_h` 與 `TownNPCLife` 實際左右位移方向一致，避免角色倒退走。
- `tests/town_visitor_life_test.gd`：兩個 visitor scene／atlas／group contract、左右相反的
  offscreen entry、整鎮 crossing、偏好居民 greet／chat external lock、opposite-edge exit、
  pass／greeting count 與下一輪 wait。
- `tests/town_life_preview_test.gd`：deterministic preview 會停用 resident／visitor process，
  以 0.05 秒 fixed-step 對非保留居民呼叫 `advance_life()`、對兩位 visitor 呼叫
  `advance_visitor()`；指定 12 秒擷取進鎮、
  16 秒附近擷取 visitor-resident interaction、60 秒確認兩位 visitor 已離鎮。
- 本輪 Town social review evidence 固定輸出到 `.review_town_social_v3/`：包含祭司與女巫
  對話中的 t09、t12／t18／t35 full frames、每個時間點固定 3 × 2 slices、`npc_states/`
  13-state sheet 與原尺寸檢查。
  Reviewer 要求修改任何 visitor baseline、atlas、scale、position、z-order 或 composition 後，
  必須覆寫同一 versioned evidence 集並重新檢查全部 full-frame／native-detail／六區；最終
  verdict 由獨立 review report 記錄，不由測試或本 guide 代替。
- `tests/priest_town_behavior_test.gd`：祭司 wait-home → walk-to-witch → chat-with-witch →
  walk-home 循環、全程共用 `y=672`／`z_index=0`、女巫左側 95 px conversation anchor、
  祭司朝右與女巫朝左的雙方面向、四組動畫切換，以及女巫
  ambient/chat state 的暫停與恢復。行為或停靠位置改動後，需用 graphical renderer 擷取
  起點、去程、對話、回程與返家畫面，再重做 full-frame 與固定 3 × 2 六區審查。
- `tests/town_npc_portrait_animation_test.gd`：`TownNPCPortrait` 的 reusable scene/API、
  四個 Town service/shop consumer、new-character texture path 與動態 state contract。
  `town_building_ui_layout_test.gd` 設定 `TOWN_BUILDING_UI_CAPTURE_DIR` 時會輸出所有六種
  required resolutions；人物或裁切改動後必須重審全部輸出。
- `tests/town_time_of_day_lighting_test.gd`：15:00 onset、17:00 peak、18:00 dusk、天空
  zenith／horizon gradient、雲暖面／冷影、Town split-tone atmosphere，以及
  左→右低角度夕陽、live cloud shadow movement、建築／環境／NPC／Portal／Player 同步光色。
  設定 `TOWN_TIME_OF_DAY_CAPTURE_DIR` 時輸出多個時鐘節點的 full-frame、固定 3 × 2 六區、
  15 分鐘 contact sheet、同一 17:00 下的五段雲影與三段 foliage-breeze 序列、sunlight／cloud-shadow
  diagnostic mask，以及由 `game.tscn` 載入真正 `TownMap.tscn` 的 runtime full-frame／六區／contact sheet／
  洋紅 world-shadow layer diagnostic。Runtime 雲影需同時輸出 t00／t10（短期無閃爍）與 t60／t120
  （長期慢速跨越建築區）；不得為了短序列可讀而加速或加深，也不得以 isolated Town 截圖取代主流程驗收。
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
| Enemy pursuit | 玩家同層時所有 archetype 都先步行貼近並進入攻擊；Leap 不以撲跳起手；navigation recovery 必須從 slide collider 排除 Player／Enemies，只有真實地形障礙、卡住或玩家在可達上方時才跳，且 stalled 門檻依 `velocity × delta` 計算；落地有重新判斷緩衝 |
| Enemy contact damage | EnemyBase 的 `ContactDamageArea` 以 layer 0／mask 8 持續監聽 Player Hurtbox；實體接觸傷害為 archetype attack damage × 0.35，必須經 `Player.take_hit()` 套用防禦、格擋、無敵幀、擊退與反傷；每敵 0.8 秒獨立冷卻，預警期間接觸仍會命中，但同一 attack generation 的 impact 不得重複扣血 |
| Survival pressure | 開場 24 隻；alive cap 40→140、batch 8→16、interval 0.40→0.09 秒；普通怪死亡後 0.05 秒內排入補怪；生成／回收使用玩家前後 680–820px perimeter，1200px 外回收且每 0.35 秒檢查 |
| Enemy durability/knockback | 普通怪 HP 倍率沿 600 秒 timeline 由 8.0 平滑提高到 20.0；開場 runtime HP 為 Moth 32、Hopper 64、Sprout／Thornling 80、Shaman 96、Charger 128，使第一分鐘約 40 傷 Combo 普攻只直接清掉 Moth；只有未死亡目標建立 0.16 秒 hit-knockback state，且 pursuit／navigation recovery 不得在下一幀覆寫水平擊退 |
| Run XP pacing | 六種普通怪各只提供 1 XP，1 XP 不得因最小 gem shard 數膨脹成 2；Run 首級門檻 100，後續為 `ceil(previous × 1.30 + 25)`，大量 XP 仍以 while 完整排入 level-up queue |
| Skill recipe | attack-only、multi-hit 一次 event、8 秒 window、count/exact sequence reset、獨立 cooldown |
| Memory Library | capacity 10/14/18/24/30；learned 與 active loadout 分離 |
| Growth queue | wave new-card 可直接 skip；EXP 每級必開新／升級神賜且不得融合；神賜全滿才 fallback；菁英／Boss 只列既有神賜升級／融合；FIFO 不漏頁 |
| Fusion | 只由菁英／Boss loot page 提供兩項不同 Lv.3 神賜融合；材料退出獎勵池並生成 Lv.1 evolved gift |
| Deck/hand | 傳送門前第 1 格固定 Healing、後 3 格為 unique 公式劍魂；四格後方的單一 workspace 以「劍魂替換／依招式配置」互斥切換，招式清單不得插在卡槽上方或與劍魂清單同時常駐；招式選擇自動填入 `required_skills` 聯集，相容名稱保持正常色、缺卡或超過三格者保留並反灰；手動候選排除重複並預覽終結技；圖示、類型色與金色幾何動畫可辨；hover／keyboard focus 即時預覽效果，向下越界自動捲動；面板於高解析度等比放大；QWER 使用後保留原 slot |
| Card readability/feedback | 繁中長技能名固定兩行、超出省略且 tooltip 保留完整名稱，不撐寬四卡框；七解析度不重疊；compatibility `BackRow` hidden 且不保留高度，code-native 7:8 金色幾何框與條件式透明裝飾層由 CardStage 頂緣到底緣雙軸填滿四等分 slot、主插畫占主要視覺；hover 不橫向放大；combat halo hidden，外框亮帶持續沿可調拱弧／側柱充能、主圖背後 60 根粗且保有留白的 360° sacred-geometry 日芒以雙頻波形大幅伸縮、維持圓形整體輪廓且四卡相位錯開；日芒使用不歸零的連續時間值，外框跨界亮帶同時繪製尾端與起點，循環接縫不得抖動；兩者使用全域時間軸，出招重投影不得歸零；右側長公式固定欄寬 ellipsis；只有成功施放的相符 card id 播放約 0.42 秒最上層儀式弧光、12 根短放射刻線、三圓章閃光與主圖 punch，無矩形遮罩且不重置底層循環；重複呼叫重啟、未知 ID 無作用、0.5 秒內回穩；透明裝飾素材另檢查 1173×1341、alpha 與共享對位 |
| Combat input hierarchy | 隱藏舊 `ActionStrip`；`SPACE 衝刺` 位於 FooterRail；手牌頂緣貼齊 CardStage；二十張公式劍魂的 catalog 基礎 AP 統一為 2，裝備只可把 Combo 投影降至最低 1；卡面共用 Noto Serif TC 優先的襯線 stack，短招式名保持大字、長名稱最低 12px 且獨占暖墨底部卷軸，插畫在分類框上緣前結束；Q/W/E/R 位於左上 32–36px 圓章且至少 18px；右上顯示種類 icon；AP cost 位於右下 34–38px 圓章且只顯示至少 20px 的數字；中文分類使用四邊舊金框暖墨 tab 且至少 60% 卡寬，Combo 卡在同一 tab 顯示自己的 `目前層數/有效上限`，不另加 stack seal；不得新增表格線、全卡不透明色塊或霓虹外框 |
| Attack geometry | 戰前獨立 Basic Attack、Run lock、0 AP、不進牌堆；方向劍氣以 53px 半高、Combo／stack 1–3 倍 size clamp 與 1.00／1.10／1.22／1.36 spectacle scale 建立前向膠囊掃掠形狀，依 hurtbox 中心／半徑相交並讓沿途每個唯一敵人受傷一次；每方向 VFX 只追到最遠合法目標；圓形攻擊以 radius 與 hurtbox 相交，Dash 以移動線段膠囊相交；形狀外、角色背後不受傷；無目標不消耗 cooldown 或公式 |
| Combo formula | catalog 合法 Combo／Healing 都可記錄；32 個精確已學會 AAA/ABC 配方；順序錯誤不觸發；純治療／防禦支援為零基礎傷害；多招 FIFO 排隊；下一發自動水平攻擊逐一施放；formula stacks 不消耗；各卡效果維持獨立 1.5 秒，單一效果到期只撤銷自己的 modifier；Combo Chain 依總 Combo 動態收緊：1–3 層為 2.0 秒，第 4 層為 1.3 秒，之後每層減少 0.1 秒，最低 0.6 秒；專注護符最後加上 0.5 秒；每個劍魂基礎上限 5，裝備／神賜可提高但全域硬上限 10，效果數、增傷 chain、卡面與提示必須共用同一有效上限 |
| Divine Gifts | 每個 EXP level 必選新／升級；菁英／Boss 必選既有升級／融合；最多 3 slot；全 inventory 的中文前綴與 mechanics 依序累加；Lv.3 融合材料退出獎勵池並釋出一格；選擇頁與 HUD 不得露出英文名稱／說明 |
| Reward bags | normal／elite／boss 各自有可測 money roll；只有 elite／boss 有 material roll；素材 ID 由 monster archetype 決定；實體 bag 收集只 emit／結算一次 |
| Growth card readability | upgrade/new/fusion choice 顯示 icon、類型色、AP/level；神賜使用 88px 符印、中文效果分類、2–3 條 next effect/mechanics、獨立 selected badge 與摘要；七解析度不裁切 |
| Dash | ↑ 只觸發 Jump；Space 觸發玩家固有 Dash；不進牌庫/手牌、不耗 AP；Dash Combo infusions 使用 `target_action=dash` |
| Pause | gameplay/AP/card/status/skill/wave/projectile timer 全停；UI 可操作；token 成對釋放 |
| HUD authority | Autumn 只有一個 HUD root；hand 在 `CardStage`；Town HUD identity 不變 |
| HUD projection | status/objective 左上、boss/toast 上中、bottom stage 完整；toast max 3/1.5 秒/duplicate refresh |
| Combo popup | 個別劍魂 Combo 每次遞增時左側顯示「中文劍魂名 ×N」；1 次為 18px、隨次數平方根成長且上限 26px；位置永遠在左側 30% 與 66% gameplay boundary 上方，0.95 秒內小幅 punch、上浮、淡出並可安全重啟；達上限後重複施放不得再假裝遞增 |

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
`skill_series_catalog_test.gd`、`skill_recipe_manager_test.gd`、`growth_choice_queue_test.gd`、
`card_growth_ui_*` 與 `autumn_hud_v3_*`。本輪 OB／神賜補全另以
`combat_ob_completion_contract_test.gd`、
`combat_ob_finisher_runtime_contract_test.gd` 與 `divine_gift_capacity_contract_test.gd`
鎖定 32 配方、支援型實際施放、Lv.15 存檔邊界及三格神賜規則。最後仍需執行
全量 SceneTree tests、editor smoke、main smoke 與人工六尺寸截圖/操作檢查。

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
