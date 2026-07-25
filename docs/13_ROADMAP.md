# Project Roadmap

本文件以目前 repository audit、runtime code、scene、data 與測試證據建立維護路線。它不是新玩法提案；所有項目都必須有可觀察驗收標準，Future/Later 不構成承諾或日期保證。

基準日期：2026-07-25
基準範圍：Town → Autumn survival → Guardian → Run Result vertical slice。

## 目錄

1. [文件目的與 Roadmap 原則](#1-文件目的與-roadmap-原則)
2. [Current Baseline](#2-current-baseline)
3. [優先級與狀態定義](#3-優先級與狀態定義)
4. [Now：玩家狀態與結算正確性](#4-now玩家狀態與結算正確性)
5. [Next：系統一致性與可維護性](#5-next系統一致性與可維護性)
6. [Later：交付、效能與長期治理](#6-later交付效能與長期治理)
7. [依賴與執行順序](#7-依賴與執行順序)
8. [Scene Tree Example](#8-scene-tree-example)
9. [Code Example](#9-code-example)
10. [Godot Example (Godot 4)](#10-godot-example-godot-4)
11. [Best Practice](#11-best-practice)
12. [Anti Pattern](#12-anti-pattern)
13. [Roadmap Item Checklist](#13-roadmap-item-checklist)
14. [Review Checklist](#14-review-checklist)
15. [Future Extension](#15-future-extension)
16. [Related Documents](#16-related-documents)

## 1. 文件目的與 Roadmap 原則

### 1.1 目的

本 roadmap 用於：

- 把已確認缺口轉成可驗收工作；
- 區分立即 correctness、下一步 consistency 與長期 governance；
- 避免 plan checkbox 取代 code/runtime 證據；
- 讓每項完成聲明都能連回測試、場景或量測輸出；
- 防止 Future 項目被誤讀為產品承諾。

### 1.2 非目標

本文件不：

- 發明新區域、敵人、卡牌或經濟；
- 決定尚未核准的遊戲設計；
- 提供日期或版本承諾；
- 把 Crystal Caves／Forbidden Graveyard layout 宣稱為完成玩法；
- 以「測試應該會過」代替執行證據。

### 1.3 證據順序

Roadmap item 的建立與關閉依序使用：

1. runtime code／scene／data；
2. 最新自動化與手動驗證；
3. 已核准 current design；
4. implementation plan；
5. 歷史設計稿。

如文件與 runtime 不一致，先保留 item 為 open，直到選擇「修 code」或「修 claim」並完成驗收。

## 2. Current Baseline

### 2.1 已驗證功能

- Town 為起始 Hub；
- 進入 Autumn 前有 1–16 張 Deck Builder；
- protected `ember_bolt` 會進入起始手牌；
- Autumn 有四個 timed survival phase 與 Guardian phase；
- 卡牌使用 real-time AP，hand capacity 為 8、UI 分兩組各顯示最多 4 張；
- sequence combo、combo-type infusion 與 card evolution 已存在；
- ExperienceGem、跨級 XP queue 與 level-up modal 已存在；
- Campfire accessible UI 為 Rest／Leave；
- Wandering merchant 使用 run gold；
- Guardian 後可透過 portal 完成 Run Result；
- Meta save 與 quick save 是兩條不同 pipeline；
- Town building、resource 與 equipment progression 已存在。

### 2.2 驗證基線

Gameplay/testing audit 在隔離 `user://` 的 project copy 中記錄：

| Check | Baseline |
|---|---|
| `*_test.gd` | 46/46 passed |
| `tests/test_ui_keyboard.gd` | passed |
| Total standalone test scripts | 47/47 passed |
| Second pass Godot error markers | 0 |
| Editor parse | exit 0，0 markers |
| Main-scene smoke | 300 frames，exit 0，0 markers |

此基線不包含 F6 視覺檢查、完整互動 walkthrough、profiler、memory monitor 或長時間 soak。

### 2.3 Current constraints

- `scripts/managers/game.gd` 為 2,114 行 central coordinator；
- 無 central test runner；
- 無 CI；
- 無 performance/memory budget；
- `tests/*_test.gd` glob 會漏掉 `test_ui_keyboard.gd`；
- working tree 在治理建立期間不是 clean release candidate。

## 3. 優先級與狀態定義

### 3.1 Time horizon

| Horizon | 定義 |
|---|---|
| Now | 直接影響玩家狀態、獎勵、存檔或現有設計 truth 的 correctness |
| Next | 不必先新增玩法即可完成的系統一致性、dead logic 與 ownership 改善 |
| Later | 需要先有基線或前置拆分的效能、CI、文件與長期交付能力 |

Now／Next／Later 是相對順序，不是日期、sprint 或 release promise。

### 3.2 Item status

每個 item 只能使用：

- `Open`：缺口仍可重現；
- `In Progress`：有明確 owner 與 active change；
- `Blocked`：有具體外部依賴；
- `Verified`：驗收命令與手動證據均已附上；
- `Removed`：經核准決定不再支援，code/data/docs/test 已同步清理。

不得以「程式已寫」取代 `Verified`。

## 4. Now：玩家狀態與結算正確性

### 4.1 Guardian 後 ExperienceGem 與 support enemy

**Status:** Open

**Evidence**

- 一般敵人死亡會生成無 lifetime／cap 的 `ExperienceGem`。
- Guardian 死亡停止 director 並解鎖 portal，但不收集或清除剩餘 gem。
- Support enemy 在離開地圖前仍可能存在。
- 最新玩法敘述與 runtime 不一致。

**Scope**

只協調現有 Guardian-complete、gem、support enemy 與 Run XP 結算。不得藉此新增 drop type 或新 Boss reward。

**Acceptance Criteria**

- [ ] 有 focused regression test 重現 Guardian 死亡時存在未收集 gem。
- [ ] Runtime 對剩餘 gem 採取已核准且唯一的 grant／cleanup 行為。
- [ ] Guardian 完成後不再有 support enemy 繼續產生未定義 reward。
- [ ] XP、pending level-up 與 Run Result 不重複計算。
- [ ] F6／main flow 實測 Guardian → portal → result。
- [ ] `docs/12_GAME_DESIGN.md` 與測試描述相同。

### 4.2 Autumn clear-state reload

**Status:** Open

**Evidence**

- `autumn_route_cleared` 與 `boss_defeated` 會寫入。
- Autumn scene 每次 instance 時 forward portal 初始 locked。
- 沒有找到 map load 時讀取 route-clear flag 的流程。

**Scope**

先確認既有 flag 的預期；只在「恢復現有 claim」與「移除無效 claim」之間做核准決策，不新增世界進度玩法。

**Acceptance Criteria**

- [ ] 文件明確定義 clear-state 在 save/reload/re-entry 的行為。
- [ ] Scene integration test 覆蓋新檔、已通關檔與舊 schema 檔。
- [ ] Portal lock、boss spawn 與 Run start 不互相矛盾。
- [ ] 若保留 flag，重新進入 Autumn 可觀察到定義的狀態。
- [ ] 若移除 flag，code、schema、test、文件沒有殘留 claim。

### 4.3 Boss reward durability

**Status:** Open

**Evidence**

- Guardian death 在記憶體增加 core、equipment discovery 與 meta flags。
- Persistent save 發生在後續 Run finish。
- Boss death 與使用 portal 之間中斷 process 可能遺失該狀態。

**Acceptance Criteria**

- [ ] 定義 reward earned 與 reward persisted 的單一邊界。
- [ ] Process interruption／reload test 覆蓋 Guardian death 後、portal 前。
- [ ] Reward 不遺失、不重複，也不因重入重複發現 equipment。
- [ ] Save failure 有可觀察 error，舊 save 可恢復。
- [ ] Run Result 顯示與 persistent inventory 相符。

### 4.4 Combo upgrade choice truth

**Status:** Open

**Evidence**

- Current level-up generator 有 card upgrade、add card 與三種 fallback。
- 沒有 active-combo-specific upgrade choice。
- 部分最新設計敘述提到該選項。

**Acceptance Criteria**

- [ ] 先由 current design 決定「移除 claim」或「實作既有 claim」。
- [ ] Level-up choice generator 與玩家可見 UI 只有一種 truth。
- [ ] Focused test 覆蓋有／無 active combo、deck full、無 eligible card。
- [ ] Combo card 普通升級與 infusion level 不被混為同一規則。
- [ ] `docs/12_GAME_DESIGN.md` 更新為驗證後行為。

### 4.5 Expedition save scope

**Status:** Open

**Evidence**

Quick save 不保存 deck piles、AP、active effects、wave、living enemy、Guardian phase、pending level-up 或 Run merchant/buff state，且檔案替換流程弱於 `SaveService`。

**Acceptance Criteria**

- [ ] UI／文件只宣稱實際可 round-trip 的 save scope。
- [ ] 不支援 expedition save 時，戰鬥中入口被明確禁止或提示。
- [ ] 支援 expedition save 時，所有宣稱欄位有 round-trip test。
- [ ] Invalid JSON、rename failure 與 backup restore 有 failure-path test。
- [ ] 測試使用隔離 `user://`，不得覆寫開發者真實 save。

## 5. Next：系統一致性與可維護性

### 5.1 Campfire dead logic

**Status:** Open

**Evidence**

- 玩家可到達 UI 只有 Rest／Leave。
- `_merge_card_at_campfire()`、`_upgrade_card_at_campfire()` 與 choice renderer 仍存在。
- 舊測試直接呼叫 private method，造成假性 gameplay coverage。

**Acceptance Criteria**

- [ ] Current design 明確維持 restoration-only。
- [ ] 不可到達的 card-growth code/test 被移除；或有明確 current caller 與 contract。
- [ ] Scene-level test 只從 Campfire 玩家入口操作。
- [ ] Campfire 不會在未宣告下改變 deck 或 card level。

### 5.2 Dormant equipment consumers

**Status:** Open

**Evidence**

以下 data/API field 存在，但沒有 gameplay consumer：

- critical chance；
- magic power；
- shop discount；
- dash cooldown reduction；
- merchant bonus choice。

**Acceptance Criteria**

- [ ] 每個欄位有逐項 decision record：consumer、移除或明確 non-functional。
- [ ] 保留的效果有 behavior test，而非只測 JSON 可載入。
- [ ] 移除時有 schema/default/舊 save 相容處理。
- [ ] Inventory UI 不顯示尚未生效的能力為有效 bonus。

### 5.3 Inventory/economy ownership

**Status:** Open

**Evidence**

`InventoryManager` persistent resource/equipment 與 `wallet_gold`／`player_inventory` prototype shop 並存，只同步部分 gold。

**Acceptance Criteria**

- [ ] 文件指定 gold、equipment 與 prototype item 的唯一 owner。
- [ ] Buy、sell、save、reload、new profile 有 integration test。
- [ ] 交易失敗不會只更新其中一套資料。
- [ ] Quick save 與 meta save 不互相覆蓋較新的 gold。

### 5.4 Town progression projection

**Status:** Open

**Evidence**

Town manager 產生的 visual flag 多於 `Game` 實際套用的四個 scene node。

**Acceptance Criteria**

- [ ] 文件列出的每個 visible upgrade 都能在 scene 中定位。
- [ ] Save/reload 後 visual projection 與 building state 相同。
- [ ] 若縮小範圍，移除未使用 flag 與過度 claim。
- [ ] 依 [Testing Guide](09_TESTING_GUIDE.md#6-ui-與多解析度驗證) 的基準、
  窄與寬比例提供 before/after screenshot。

### 5.5 Duplicate/unused progression fields

**Status:** Open

**Evidence**

- Legacy `building_levels` ID 與 current four-building `town_state` 不一致。
- `permanent_card_levels`、`unlocked_combos` 被序列化但未使用。

**Acceptance Criteria**

- [ ] 舊 schema fixture 可 migration 到唯一 current representation。
- [ ] 每個 persistent field 都有 producer、consumer 與 test。
- [ ] 無 consumer 的 field 經 migration 後安全移除或明確保留理由。
- [ ] Meta save round-trip 不遺失 inventory/town/evolution state。

### 5.6 Input 與 global time-scale safety

**Status:** Open

**Evidence**

- Physical A 同時映射 move-left 與 card-group-1。
- Card focus 與 hit stop 都改變 `Engine.time_scale`。
- 未找到 node teardown 統一恢復保證。

**Acceptance Criteria**

- [ ] Automated input test 加上 manual gamepad/keyboard walkthrough。
- [ ] 向左移動不會非預期切換 card group，或文件/UI 明示核准行為。
- [ ] 強制換場景、關閉 UI、玩家死亡與 pause 後 `Engine.time_scale == 1.0`。
- [ ] 多個 slow/hit-stop owner 不會互相覆寫錯誤狀態。

### 5.7 Game manager responsibility split

**Status:** Open

**Evidence**

`scripts/managers/game.gd` 2,114 行，同時負責 map、UI、combat、cards、shops、save、inventory、town 與 result。

**Boundary candidates from current ownership**

```text
Game composition root
├── MapFlowCoordinator
├── UIFlowCoordinator
├── ExpeditionCoordinator
├── TownCommerceCoordinator
└── SaveCoordinator
```

以上名稱是責任分組示意，不是已核准 class 或 scene。

**Acceptance Criteria**

- [ ] 先建立 caller/signal/ownership map，避免循環依賴。
- [ ] 每次只移動一個可獨立測試的責任。
- [ ] `Game` 保留 composition root，不以 autoload 取代依賴設計。
- [ ] Existing 47-test baseline 與 affected scene tests 全數通過。
- [ ] Map/HUD adoption、Run result、save 與 Town transaction 行為不變。
- [ ] 新檔責任與架構文件同步。

## 6. Later：交付、效能與長期治理

### 6.1 Central test runner

**Status:** Open

**Evidence**

46 個 `*_test.gd` 加上一個命名例外 `test_ui_keyboard.gd` 必須逐一執行；標準 glob 會漏測。

**Acceptance Criteria**

- [ ] 一個 documented command 發現全部 47 個現有 test。
- [ ] 任一 test 非零 exit 時 runner 非零 exit。
- [ ] Summary 顯示 total、passed、failed 與 failing path。
- [ ] 新 test 依命名規則自動被發現。
- [ ] Runner 不讀寫真實 gameplay save。

### 6.2 CI

**Status:** Open

**Acceptance Criteria**

- [ ] Clean checkout 使用明確 Godot 4.7 版本。
- [ ] CI 執行 parser/editor check、全部 tests 與 main-scene smoke。
- [ ] Godot error marker 會使 job 失敗。
- [ ] Artifact 保留 test summary 與必要 log。
- [ ] CI 不提交 `.godot/`、export artifact 或 credential。

### 6.3 Performance and memory baseline

**Status:** Open

**Evidence**

- Encounter director 每 frame 搜尋 Player group。
- Equipment special totals 每 frame 重新聚合。
- Survival director 重建 enemy array 並高頻更新 HUD。
- ExperienceGem 無 lifetime／cap／pool。
- Combat labels、warnings、summons 無 pooling。
- 現有 300-frame smoke 不是 performance measurement。

**Acceptance Criteria**

- [ ] 定義可重播的四階段＋Guardian profile scenario。
- [ ] 在同一硬體、debug build、1280×720，以相同輸入重播完整四階段＋Guardian，
  每 60 秒記錄 frame time、entity/gem count、memory 與 allocation baseline。
- [ ] 移除 per-frame tree lookup，改為可驗證 cached reference。
- [ ] Equipment totals 只在 equipment state 改變時重算，或以 profiler 證明成本可接受。
- [ ] Gem population 有可測量上界或 deterministic cleanup。
- [ ] 連續完成三次 scenario 後 orphan node 為 0；每次 cleanup 後 node/object
  數回到首次 cleanup 的 ±5%，且三個 cleanup 採樣點沒有單調 memory growth。

### 6.4 Diagnostics

**Status:** Open

**Evidence**

多個 data/state API 對 malformed data 或 missing ID 只回傳 false/empty，缺少 path/ID context。

**Acceptance Criteria**

- [ ] Invalid fixture 產生包含 path 或 ID 的 actionable error。
- [ ] Release flow 不因可恢復資料錯誤直接 crash。
- [ ] Save migration/fallback 有明確 category 與結果。
- [ ] Test summary 能區分 assertion failure 與 Godot parser/runtime error。

### 6.5 Documentation truth and delivery workflow

**Status:** Open

**Evidence**

- 舊 plan checkbox 與 runtime 不完全一致。
- Local repository 有 64 commits 與 `v0.1.0`，但舊 guidance 曾聲稱沒有 history。
- 無本地證據可證明 branch protection 或 required review。

**Acceptance Criteria**

- [ ] Governance 文件只保留 current repository facts。
- [ ] 每個完成 claim 連到 command output、scene check 或 screenshot。
- [ ] PR/branch policy 由 repository setting 或 checked-in policy 證明。
- [ ] Gameplay change 同步更新 `12_GAME_DESIGN.md` 與相關指南。
- [ ] 大型功能維持 Design → Plan → Build traceability，且拆成可 review 變更。

### 6.6 Later-region documentation

**Status:** Open

Crystal Caves 與 Forbidden Graveyard 目前是 layout only。

**Acceptance Criteria**

- [ ] 對外與內部文件都標示 current layout-only 狀態。
- [ ] 在專屬 runtime、scene test、result/progression contract 完成前，不標記為 gameplay complete。
- [ ] 任何未來玩法先走獨立 design approval，不由本 roadmap 推測。

## 7. 依賴與執行順序

### 7.1 建議依賴圖

```text
Guardian gem/support cleanup
  └── Boss reward durability
      └── Autumn clear-state reload

Expedition save scope
  └── Save diagnostics
      └── CI round-trip coverage

Campfire dead logic
Equipment consumer audit
Input/time-scale safety
  └── Game manager ownership map
      └── Incremental manager split

Central test runner
  ├── CI
  └── Performance/memory baseline
```

此圖只描述風險依賴，不代表固定 sprint。

### 7.2 執行規則

1. Now item 先建立 failing regression evidence。
2. 選擇最小一致性修正。
3. 執行 affected tests、full suite、scene smoke。
4. UI／場景變更依 `rule_1` 做指定解析度視覺檢查。
5. 更新 `12_GAME_DESIGN.md`。
6. 只有附上 evidence 後才把 item 標為 Verified。

## 8. Scene Tree Example

Roadmap 工作不得破壞目前 composition boundary：

```text
Game (Node)
├── MapRoot
│   └── CurrentMap
│       ├── Player
│       ├── EncounterDirectors
│       └── Interactives
├── HUDLayer
│   ├── HUD
│   └── CardHandUI
├── MenuLayer
│   └── Runtime modal UI
└── CardEffectRunner
```

未來拆分 manager 時，建議先保持同一 scene tree，以 plain Node/RefCounted coordinator 分離責任；是否新增 child node 必須另行 review。

Performance item 的觀察樹：

```text
AutumnTreeMap
├── Player
├── AutumnRunDirector
│   ├── spawned EnemyBase nodes
│   └── spawned AutumnGuardian
└── spawned ExperienceGem nodes
```

Profiler／soak 必須同時觀察 enemy 與 gem，而不是只看 director alive cap。

## 9. Code Example

Roadmap item 應使用可機器檢查的 acceptance result，而非只輸出文字。以下是 Godot `SceneTree` regression test 的專案慣例：

```gdscript
extends SceneTree

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var run_state := RunState.new()
	run_state.begin_run(["ember_bolt"])

	var queued := run_state.add_experience(200)
	_expect(queued > 1, "Large XP grants must queue every earned level")
	_expect(
		run_state.pending_level_ups == queued,
		"Queued count must match pending level-ups"
	)

	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
```

範例使用 Godot 4 `SceneTree` script 與非零 exit code，適合作為 roadmap acceptance 的自動化證據。

## 10. Godot Example (Godot 4)

以下是 performance item 可採用的 Godot 4 cached-reference contract。它示範方向，不表示目前 code 已完成：

```gdscript
var _player: Node2D


func register_player(player: Node2D) -> void:
	_player = player


func _process(delta: float) -> void:
	if not is_instance_valid(_player):
		return
	advance_encounter(delta, _player.global_position)
```

驗收時必須同時證明：

- map reload 後會重新註冊；
- freed player 不留下 invalid reference；
- 不再每 frame 呼叫 `get_first_node_in_group("Player")`；
- encounter leash 行為未改變。

## 11. Best Practice

- 每個 roadmap item 只處理一個可觀察問題。
- Acceptance Criteria 先於 implementation。
- Correctness issue 先建立 regression test。
- 效能工作先量測，再決定是否修改。
- Manager 拆分以 ownership/caller map 開始，不以行數作唯一目標。
- Save 測試使用隔離 `user://`。
- 文件中的數值與路徑由 script/data 驗證。
- Item 完成時附 command、exit code、failure count 與手動檢查。
- 移除功能與新增功能一樣要同步 code、data、test、docs。
- Later/Future 明示非承諾。

## 12. Anti Pattern

- 用日期或樂觀估計代替驗收標準。
- 把 Future item 當成已核准 scope。
- 一次同時修 Boss、save、inventory 與 manager split。
- 只看 test exit code，不掃描 Godot error markers。
- 用 mock-only test 宣稱 scene flow 已完成。
- 用 plan checkbox 宣稱玩家流程可到達。
- 在沒有 profiler baseline 前重寫 combat loop。
- 以 autoload 隱藏 manager dependency。
- 拆分 `Game` 後保留雙重 owner。
- 為了通過測試而直接呼叫玩家不可到達的 private method。
- 在真實 `user://` 上執行破壞性 save test。

## 13. Roadmap Item Checklist

新增或開始 item 前：

- [ ] 有 current code／scene／test evidence。
- [ ] 問題可在目前 revision 重現。
- [ ] Scope 沒有新增未核准玩法。
- [ ] 有單一 owner。
- [ ] Acceptance Criteria 可觀察、可重跑。
- [ ] 已列出 affected tests 與 scenes。
- [ ] 已列出 save、input、UI、performance 風險。
- [ ] 已確認是否需要 migration。
- [ ] 已確認相關治理文件。

完成 item 前：

- [ ] Focused regression test 通過。
- [ ] 所有 affected tests 通過。
- [ ] Full runner／現有全測試流程通過。
- [ ] Parser/editor check 無 error marker。
- [ ] Main scene 或 affected F6 flow 已驗證。
- [ ] UI 解析度檢查完成。
- [ ] Performance claim 有 profiler evidence。
- [ ] 文件更新完成。
- [ ] Working tree 沒有混入無關變更。
- [ ] Review evidence 已附在交付報告。

## 14. Review Checklist

Reviewer 必須確認：

- [ ] Now item 都源自玩家狀態、獎勵或 save correctness。
- [ ] Next item 都有明確 current-system evidence。
- [ ] Later item 沒有被寫成日期承諾。
- [ ] 每項都有獨立 Acceptance Criteria。
- [ ] Guardian gem、combo choice、clear reload 均有追蹤。
- [ ] Campfire dead logic 與 equipment consumer 均有追蹤。
- [ ] Expedition save scope 與 failure handling 均有追蹤。
- [ ] Performance item 包含量測，不只是重構。
- [ ] `Game` split 保留 composition root 且分階段驗證。
- [ ] Central runner、CI、docs truth 均有追蹤。
- [ ] Scene path、數值與 test count 已重新查證。
- [ ] 所有 code fence 成對，GDScript 使用 Godot 4 API。
- [ ] Related Documents link 指向存在或本治理批次預定文件。

## 15. Future Extension

Future Extension 只建立 intake 規則：

- 新 gameplay 先建立 design，不直接加入 Later。
- 新區域先證明 scene、runtime、save、result 與 test contract。
- 新 card/equipment effect 必須先有 consumer 與 data validation。
- 新 persistence field 必須同時有 migration 與 round-trip test。
- 新 performance target 必須有同一硬體／場景的 baseline。
- 新 CI/export target 必須說明 engine version 與 artifact policy。

任何 Future 項目在未經核准前：

- 不代表承諾；
- 不代表排期；
- 不代表目前 scope；
- 不得寫入 `docs/12_GAME_DESIGN.md` 的已實作章節。

## 16. Related Documents

- `docs/README.md`
- `docs/01_AI_GUIDE.md`
- `docs/02_PROJECT_ARCHITECTURE.md`
- `docs/03_SCENE_STRUCTURE.md`
- `docs/04_UI_GUIDE.md`
- `docs/05_CODING_STANDARD.md`
- `docs/06_RESOURCE_GUIDE.md`
- `docs/09_TESTING_GUIDE.md`
- `docs/10_DEBUG_GUIDE.md`
- `docs/11_GIT_WORKFLOW.md`
- `docs/12_GAME_DESIGN.md`
- `docs/rule_1.md`
- `docs/rule_2.md`
- `.superpowers/sdd/2026-07-25-project-governance/gameplay-testing-audit.md`
