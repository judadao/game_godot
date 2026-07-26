# Project Architecture

本文件描述目前 repository 可驗證的 runtime 架構、ownership、資料流與已知風險。
它不是理想化藍圖。尚未存在的能力以 `TODO` 標示，不得將 Future Extension
當成已完成系統。

## 目錄

1. [文件目的與架構基準](#1-文件目的與架構基準)
2. [Application Entry 與 Composition Root](#2-application-entry-與-composition-root)
3. [Runtime Ownership](#3-runtime-ownership)
4. [Scene 與地圖架構](#4-scene-與地圖架構)
5. [主要 Script 與 Public Contract](#5-主要-script-與-public-contract)
6. [Signal 與跨系統資料流](#6-signal-與跨系統資料流)
7. [State、Inventory 與 Save](#7-stateinventory-與-save)
8. [UI、Pause 與 Input](#8-uipause-與-input)
9. [Combat、NPC、Dialogue、Quest、Audio、Animation](#9-combatnpcdialoguequestaudioanimation)
10. [依賴方向與變更規則](#10-依賴方向與變更規則)
11. [架構風險](#11-架構風險)
12. [Code Examples](#12-code-examples)
13. [Scene Tree Example](#13-scene-tree-example)
14. [Godot Example (Godot 4)](#14-godot-example-godot-4)
15. [Best Practice](#15-best-practice)
16. [Anti Pattern](#16-anti-pattern)
17. [Architecture Checklist](#17-architecture-checklist)
18. [Review Checklist](#18-review-checklist)
19. [Future Extension](#19-future-extension)
20. [Related Documents](#20-related-documents)

## 1. 文件目的與架構基準

### 1.1 技術基準

| 項目 | 現況 |
|---|---|
| Engine | Godot 4.7，`project.godot` 的 feature 為 `4.7` |
| Language | GDScript 2 |
| Application main scene | `res://scenes/game/game.tscn` |
| Base viewport | 1280 × 720 |
| Stretch | `canvas_items` |
| Runtime scenes | `scenes/` |
| Runtime scripts | `scripts/` |
| Static gameplay data | `data/*.json` |
| Autoload | **無**；`project.godot` 沒有 `[autoload]` |

### 1.2 文件中的狀態詞

- **Current**：可由目前 code、Scene、data 或 test 驗證。
- **Known Risk**：現有實作仍能運作，但 ownership 或資料一致性需要特別保護。
- **TODO**：repository 尚未存在，未來若實作需先完成設計、測試與文件同步。
- **Proposed**：只可出現在 Future Extension，不代表已核准。

### 1.3 核心原則

目前架構採 Scene composition，不採全域 singleton。不得在文件、測試或新程式中
假定有 `GameManager`、`QuestManager`、`DialogueManager` 或 `AudioManager`
Autoload。若未來新增 Autoload，必須同時更新本文件、Scene ownership、reset contract、
save boundary 與 scene reload tests。

## 2. Application Entry 與 Composition Root

### 2.1 Main scene

`project.godot`：

```ini
[application]
run/main_scene="res://scenes/game/game.tscn"
```

`scenes/game/game.tscn` 的根 `Game` 掛載
`res://scripts/managers/game.gd`，是目前 application composition root。

```text
Game (Node, scripts/managers/game.gd)
├── MapRoot (Node)
├── HUDLayer (CanvasLayer)
├── MenuLayer (CanvasLayer)
└── CardEffectRunner (Node, CardEffectRunner)
```

### 2.2 Startup order

`Game._ready()` 的 current order：

1. 將 `Game`、`HUDLayer`、`MenuLayer` 設為 `PROCESS_MODE_ALWAYS`。
2. 透過 `SaveService.load_meta()` 讀取 `user://saves/meta_progress.json`。
3. 將 `MetaState.inventory_state`／legacy fields 套入 Inventory runtime state。
4. 將 `MetaState.town_state`／legacy fields 套入 Town runtime state。
5. 載入卡牌、技能與合成 recipe catalog；實際的 `SkillRecipeManager`、
   `GrowthChoiceQueue` 與成長 UI caller 由 `Game` 組裝。
6. 連接 `CardEffectRunner.effect_resolved`。
7. 呼叫 `load_current_map(starting_map)`。
8. 將 runtime progression 同步回 `MetaState`。

Startup 任一步驟的順序改變都可能影響地圖初始 HUD、裝備屬性、存檔 migration
或卡牌 catalog；修改時必須跑 progression、map 與 vertical slice tests。

### 2.3 Game lifecycle signals

`scripts/managers/game.gd` 對外宣告：

```gdscript
signal map_loaded(map: Node)
signal player_registered(player_node: Node)
signal ui_opened(ui_name: String, ui_node: Control)
signal ui_closed(ui_name: String, ui_node: Control)
```

目前 production code 未發現這四個 signals 的外部 consumer，但它們仍是 public
lifecycle contract。刪除或改參數前必須搜尋 tests、tools 與未追蹤工作。

## 3. Runtime Ownership

### 3.1 Ownership tree

```text
Game
├── current_map under MapRoot
│   ├── Player
│   ├── world/collision/portals/NPCs
│   └── encounter-owned runtime enemies and drops
├── HUDLayer
│   └── adopted HUD
│       └── embedded AutumnCardHandUI（僅 Autumn HUD）
├── MenuLayer
│   └── ui_stack managed modal/primary UI
├── CardEffectRunner
└── RefCounted state/services
    ├── MetaState
    ├── RunState
    ├── SaveService
    ├── CardDatabase
    ├── DeckManager
    ├── CardCollectionService
    ├── SkillRecipeManager
    ├── GrowthChoiceQueue
    ├── inventory_manager.gd instance
    └── town_manager.gd instance
```

### 3.2 Node ownership

- `MapRoot` 擁有當前地圖 instance；換圖時舊 children `queue_free()`。
- 地圖 Scene 擁有 Player、spawn、world collision、Portal、NPC 與靜態佈局。
- Encounter director 擁有 runtime-spawned enemy、guardian 與 experience gem。
- `HUDLayer` 擁有 current HUD；Autumn 的手牌是 `AutumnHUD` 內嵌 presentation，
  不得再作為與 HUD 並列的第二個 runtime root。換圖時釋放舊 HUD instance。
- `MenuLayer` 擁有 Inventory、Pause、Dialogue、Shop、TownProgress 等 runtime UI。
- Dynamic damage number、summon visual、boss telegraph 使用短生命週期 Node/Tween，
  建立端同時負責 cleanup。

### 3.3 RefCounted ownership

State/system instances由 `Game` 建立並持有，不加入 SceneTree：

| Instance | Class／Script | Responsibility |
|---|---|---|
| `meta_state` | `MetaState` | 永久 progression save model |
| `run_state` | `RunState` | 一輪 expedition 的 transient state |
| `save_service` | `SaveService` | meta JSON 安全寫入與載入 |
| `card_database` | `CardDatabase` | validated card catalog |
| `deck_manager` | `DeckManager` | CardInstance 的 draw/hand/discard/exhaust/cooldown 與 AP |
| `card_collection_service` | `CardCollectionService` | 協調 MetaState／RunState／DeckManager 的 add／fuse／remove 與 collection snapshot／rollback |
| `skill_recipe_manager` | `SkillRecipeManager` | 已裝備的攻擊 recipe、視窗、進度與 cooldown |
| `growth_choice_queue` | `GrowthChoiceQueue` | wave/EXP 成長事件的單一 FIFO queue |
| `inventory_manager` | unnamed `RefCounted` script | resources/equipment runtime model |
| `town_manager` | unnamed `RefCounted` script | building levels/village stage |

`inventory_manager.gd` 與 `town_manager.gd` 沒有 `class_name`，由 `Game` preload
script 後 `new()`，以 `call()` 溝通。這是 Current，不應在文件中虛構 typed service。

## 4. Scene 與地圖架構

### 4.1 Canonical 與 authoritative path

Portal/content identity 使用 canonical path；runtime/editor 使用 authoritative main scene。
mapping 由純 `RefCounted` `scripts/systems/map_registry.gd` 管理。`Game` preload
該 registry，並保留原有 path constants、`MAP_MAIN_SCENE_PATHS` 與 compatibility
wrappers，讓 portal、HUD、save 與既有測試不需知道實作已抽離：

| Canonical path | Authoritative path | Runtime root |
|---|---|---|
| `res://scenes/maps/town.tscn` | `res://scenes/maps/town/TownMap.tscn` | `TownMap` |
| `res://scenes/maps/autumn_forest.tscn` | `res://scenes/maps/autumn_battle/AutumnBattleMapV2.tscn` | `AutumnBattleMapV2` |
| `res://scenes/maps/crystal_caves.tscn` | `res://scenes/maps/layouts/CrystalCavesLayout.tscn` | `CrystalCaves` |
| `res://scenes/maps/forbidden_graveyard.tscn` | `res://scenes/maps/layouts/ForbiddenGraveyardLayout.tscn` | `ForbiddenGraveyard` |

規則：

- Portal `target_scene_path` 可保留 canonical path。
- `MapRegistry` 只處理 path identity，不載入 scene、不持有 Node/Player/UI/save。
- `Game._resolve_main_scene_path()` 後才 `load()` destination。
- HUD area name與 run/map identity 經 `_canonical_map_scene_path()` 比對。
- Save 的 `map_path` 目前保存 instantiated authoritative
  `current_map.scene_file_path`。
- Registry 抽取不改變 quick-save payload；任何改存 canonical path 的提案都屬
  schema/migration 變更，需另行測試。
- 新地圖若採此 pattern，必須同時加入 mapping、authoritative scene、Portal
  contract、save compatibility與 tests。

### 4.2 Map load flow

```text
Portal.portal_entered
→ Game._on_portal_entered()
→ canonical target
→ Game._resolve_main_scene_path()
→ load PackedScene
→ Game.load_current_map()
   ├── capture transferable Player state
   ├── queue_free old map
   ├── instantiate authoritative map
   ├── adopt HUD（Autumn hand 已內嵌）
   ├── register Player at named spawn
   ├── apply transferred/equipment state
   ├── wire Interactives/EncounterDirectors
   ├── update HUD
   └── map_loaded.emit()
```

`load_current_map()` 不使用 `SceneTree.change_scene_to_*()`；application `Game`
保持存活，只替換 `MapRoot` child。

### 4.3 HUD adoption

Authoritative map 包含 editor-visible `EditorHUDReference`：

```text
EditorHUDReference (CanvasLayer)
└── HUD (Control)
    └── AutumnCardHandUI（僅 Autumn）
```

Runtime 時 `Game.load_hud()` 將 **exact HUD instance** `reparent()` 到
`Game/HUDLayer`。這不是複製，也不是重新 instantiate。Autumn 不再呼叫獨立的
`load_card_hand()` 來建立第二個 root；Town 的既有 HUD 契約不因這次改版改動。

重要 contract：

- reparent 前後 root anchors、offsets、position、scale、metadata 必須保持。
- 換圖時 previous HUD（連同其內嵌 hand）必須釋放。
- Autumn runtime 只允許一個 HUD authority；不得另掛獨立 CardHand root。
- `tests/map_layout_scenes_test.gd` 驗證 exact instance identity。

Scene authoring細節見 `docs/03_SCENE_STRUCTURE.md`。

## 5. 主要 Script 與 Public Contract

### 5.1 State/data

| Class | Source | Public API |
|---|---|---|
| `MetaState` | `scripts/systems/meta_state.gd` | `add_resource`, `can_afford`, `spend`, `apply_run_summary`, `to_dict`, `apply_dict`, `normalize_selected_deck` |
| `RunState` | `scripts/systems/run_state.gd` | `begin_run`, `finish_run`, `add_reward`, `add_experience`, `consume_pending_level` |
| `CardDatabase` | `scripts/systems/card_database.gd` | `load_catalog`, `get_card`, `has_card`, `get_all_cards` |
| `DeckManager` | `scripts/systems/deck_manager.gd` | `start`, `draw_cards`, `play_from_hand`, `regenerate_energy`, `redraw_hand_for_all_energy`, `end_turn` |
| `CardCollectionService` | `scripts/systems/card_collection_service.gd` | `is_configured`, `get_deck_size`, `get_copy_count`, `add_persistent_card`, `fuse`, `remove_instance`, `capture_state`, `restore_state` |
| `CardInstance` | `scripts/systems/card_instance.gd` | `instance_id`, `card_id`, `level`, `is_fixed`, `to_dict`, `from_dict` |
| `SkillRecipeManager` | `scripts/systems/skill_recipe_manager.gd` | `load_catalog`, `configure_loadout`, `record_card`, `tick`, `reset_runtime` |
| `GrowthChoiceQueue` | `scripts/systems/growth_choice_queue.gd` | `enqueue_wave_blessing`, `enqueue_experience_growth`, `peek`, `resolve` |
| `SaveService` | `scripts/systems/save_service.gd` | `save_meta`, `load_meta` |

### 5.2 Combat

| Class | Source | Contract |
|---|---|---|
| `CardEffectRunner` | `scripts/combat/card_effect_runner.gd` | `cast()` 修改 caster/targets，emit `effect_resolved` |
| `CombatStatusController` | `scripts/combat/combat_status_controller.gd` | super armor、damage reduction、lifesteal、regeneration、retaliation 與 timer pause |
| `EncounterDirector` | `scripts/combat/encounter_director.gd` | wave plan、engagement/leash、enemy ownership |
| `SurvivalWaveDirector` | `scripts/combat/survival_wave_director.gd` | timed phases、boss stage、XP gem |
| `EnemyBase` | `scripts/monsters/enemy_base.gd` | archetype、attack、damage、status、reset |
| `AutumnGuardian` | `scripts/monsters/autumn_guardian.gd` | boss phases/pattern profiles |
| `Hurtbox` | `scripts/combat/hurtbox.gd` | `receive_hit()` adapter |
| `ExperienceGem` | `scripts/combat/experience_gem.gd` | configure/attract/collect |

### 5.3 UI

UI 對上層提供 setter/configure API與 typed signals：

- `HUD`：player/resource/area/objective/prompt projection。
- `CardHandUI`：cards/AP/combo/boss presentation；emit selection。
- `DialogueUI`：speaker/text/choices；emit choice/advanced/canceled。
- `ShopUI`：catalog projection；emit mode/quantity/confirmed。
- `InventoryUI`：prototype inventory projection。
- `TownProgressUI`：目前直接接收 Town/Inventory `RefCounted` services。
- `PauseMenu`：emit save/load/settings/quit 等 intent。

UI 不應新增戰鬥、存檔或經濟規則。`TownProgressUI` 直接 mutation 與 runtime layout
是 Known Risk，不是可複製的新模式。

## 6. Signal 與跨系統資料流

### 6.1 Signal direction

```text
leaf Scene / UI
  ── typed signal ──▶ Game orchestrator
                         │
                         ├──▶ RefCounted system mutation
                         ├──▶ Scene lifecycle
                         └──▶ UI projection method
```

下層元件不尋找 `Game`。`Game._connect_if_present()` 對 group-discovered Node
依 signal name連接 handler。

### 6.2 Interaction flow

```text
InteractionArea.body_entered
→ interaction_available(interactive, player)
→ Game.current_interactive
→ HUD.set_interaction_prompt()
→ Input "interact"
→ interactive.interact(player)
→ one of:
   dialogue_requested / shop_requested / portal_entered / chest_opened
→ Game handler
```

只有 `Interactives` group內 Node會被 `_wire_interactives()` 掃描。新增互動場景時，
Scene group、base signals與固定 child contract缺一不可。

### 6.3 Card combat flow

```text
data/cards.json
→ CardDatabase
→ DeckBuilderUI selects 16-card deck + one auto-attack card
→ MetaState selected deck / auto_attack_card_id
→ RunState + DeckManager
→ CardHandUI.set_cards()
→ card_selected(index)
→ Game._on_card_selected()
→ card level + equipment + infusion projection
→ CardEffectRunner.cast(card, player, targets)
→ Player/Enemy public combat API
→ effect_resolved
→ damage visual / camera shake / hit stop
```

### 6.4 Progression flow

```text
combat reward
→ RunState temporary rewards
→ Game._finish_run()
→ MetaState.apply_run_summary()
→ InventoryManager resources
→ Game._sync_progression_to_meta()
→ SaveService.save_meta()
→ HUD / TownProgressUI projection
```

任何直接改 `MetaState.resources` 而未同步 InventoryManager，或只改
`wallet_gold` 而未更新 InventoryManager，皆可能製造漂移。

## 7. State、Inventory 與 Save

### 7.1 Static / runtime / save boundary

```text
Validated static JSON
→ runtime catalog / manager state
→ MetaState or RunState
→ UI projection
→ explicit save serialization
```

資料格式與 validation詳見 `docs/06_RESOURCE_GUIDE.md`。

### 7.2 MetaState vs RunState

| Boundary | `MetaState` | `RunState` |
|---|---|---|
| Lifetime | application/restart persistent | one expedition |
| Save | `meta_progress.json` | 不直接完整保存 |
| Examples | resources、unlocks、deck、equipment、town、shortcuts | level、XP、AP、temporary cards/buffs、run rewards |
| Reset | load/default/migration | `begin_run()`／`finish_run()` |

不得將 `RunState` transient buffs寫入 permanent meta，除非玩法與 schema
明確要求且有 migration test。

### 7.3 Inventory overlap

目前有三份相關狀態：

1. `inventory_manager.gd`：permanent resources/equipment model。
2. `MetaState`：save fields與 legacy compatibility。
3. `Game.wallet_gold`、`Game.player_inventory`、`_merchant_catalogs`：
   prototype merchant/inventory projection。

`Game._sync_progression_to_meta()` 是主要同步點。一般 `InventoryUI` 使用
`player_inventory`；`TownProgressUI` 操作 InventoryManager equipment。治理與 review
必須把它們視為 Known Risk，不得宣稱已是 single source of truth。

### 7.4 Save pipelines

Permanent meta：

- path：`user://saves/meta_progress.json`
- schema：`MetaState.SCHEMA_VERSION == 5`
- service：`SaveService`
- behavior：`.tmp` write → parse validation → backup → rename

Quick save：

- path：`user://saves/quick_save.json`
- schema：1
- owner：`Game._save_quick_slot()`／`_load_quick_slot()`
- payload：authoritative map path、Player position/stats、prototype wallet/inventory/catalog
- limitation：不是完整 `RunState` 或 meta snapshot

兩條 pipeline 的 validation、backup restore與migration不同。不可用「完整存檔系統」
一詞掩蓋差異。

## 8. UI、Pause 與 Input

### 8.1 UI stack

`Game.open_ui()`：

- 防止相同名稱重複 instance。
- instantiate到 `MenuLayer`。
- 記錄 `ui_stack`、name與pause flag。
- 連接 common control/lifecycle signals。
- 呼叫 UI `open()`，設定 focus。
- 依 stack更新 `SceneTree.paused` 與 Player input。

`close_ui()` 負責同步 TownProgress、emit lifecycle signal、queue_free與更新 pause。

### 8.2 Pause

只要 stack中任一 UI的 pause flag為 true，`get_tree().paused = true`。UI root設
`PROCESS_MODE_ALWAYS`，因此 paused時仍能回應。Player input只有在 stack為空時啟用。

### 8.3 Input ownership

| Action | Current consumer |
|---|---|
| move／↑ Jump／Space Dash | `player_controller.gd` |
| interact/inventory/pause/card focus/redraw | `game.gd` |
| card group/slot | `card_hand_ui.gd` |
| UI navigation | individual UI scripts |

Known Risk：A 同時出現在 `move_left` 與 `card_group_1`。專案沒有正式 Input Context
service；修改 mappings或處理順序時須用實際 run驗證。

## 9. Combat、NPC、Dialogue、Quest、Audio、Animation

### 9.1 Combat — Current

- Autumn Forest使用 `SurvivalWaveDirector`。
- director runtime-spawn enemy/guardian/experience gem。
- `Enemies`、`EncounterDirectors` groups用於 target與wiring。
- card effect透過 capability methods，例如 `take_hit()`、`add_block()`、
  `restore_health()`、`apply_status()`。
- Enemy archetype是 runtime-created `Resource`，不是 `.tres` catalog。

### 9.2 NPC — Current

- NPC/Merchant是 `StaticBody2D` + `Interactives` group。
- Town NPC由 `scenes/maps/components/TownNPCs.tscn` 組合。
- 沒有 NPC navigation、schedule、AI movement或persistent NPC state。
- Merchant只發 intent signal；stock/economy由 `Game` 管理。

### 9.3 Dialogue — Partial

Current：

- `dialogue_id`從 NPC signal傳給 `Game`。
- `DialogueUI`支援 speaker、text、choices與 typed signals。
- 少量台詞在 `Game._dialogue_text_for()` hard-code。

TODO：

- dialogue data catalog/Resource
- conversation graph與conditions/effects
- localization keys
- voice/audio integration
- dialogue progress save
- Quest gating

不得宣稱存在 `DialogueManager`。

### 9.4 Quest — TODO

Current只有：

- `HUD.set_objective()` 與 `HUDQuestTracker`
- combat/combo/run訊息投影
- Inventory `"quest"` category與 hard-coded `town_map`

不存在 Quest model、QuestManager、quest lifecycle signals、save schema或
NPC condition integration。`HUDQuestTracker`目前是 objective/status display，
不是正式 Quest 系統。

### 9.5 Audio — TODO

Current只有 `PauseMenu`直接操作 Master bus：

- `AudioServer.get_bus_index("Master")`
- `AudioServer.set_bus_volume_db()`

專案沒有 audio files、`AudioStreamPlayer*`、audio manager或 bus layout resource。
`MetaState.settings.master_volume`尚未接線；不得宣稱音量已持久化。

### 9.6 Animation — Partial

Current：

- Player手動切 Sprite2D texture/hframes/frame。
- AutumnSlime手動更新 frame。
- UI與特效使用 Godot 4 Tween。
- Magic book portal在 `_process()` 用 `sin()` 浮動。

不存在 `AnimationPlayer`、`AnimationTree`、`AnimatedSprite2D`或共用 state graph。

## 10. 依賴方向與變更規則

### 10.1 允許方向

```text
Scene/UI input
→ signals
→ Game orchestrator
→ system/domain API
→ state mutation
→ projection back to Scene/UI
```

- system scripts不得依賴 UI Scene。
- UI不得直接改 static catalog。
- map content不得自行建立第二個 global HUD/save manager。
- lower-level scene不得假定 `/root/Game` absolute NodePath。
-跨邊界 Dictionary使用 validation與 `duplicate(true)`。

### 10.2 架構變更同步

| 變更 | 同步項目 |
|---|---|
| Main scene / Autoload | 02、03、05、09、tests |
| Map path / root / ownership | 02、03、09、Portal/save tests |
| JSON/schema | 02、06、09、migration/content tests |
| Public class/signal | 02、03或06、callers、contract tests |
| UI ownership | 02、03、04、08、layout tests |
| Save payload | 02、06、09、old payload fixture |

## 11. 架構風險

| Severity | Risk | Evidence | Required control |
|---|---|---|---|
| High | Game monolith | `game.gd`約2,108行，仍涵蓋多domain；map path registry已抽離 | 新規則優先放可測system；改動跑跨系統tests |
| High | Inventory多份真相 | manager/meta/prototype dictionaries | 明確同步點與一致性assertion |
| High | Save雙管線 | SaveService vs Game quick save | 分開文件、fixtures與migration |
| High | Map雙路徑 | canonical vs authoritative | registry test、save compatibility |
| Medium | Dynamic string API | `call/get/find_child/signal name` | path/API contract tests |
| Medium | HUD adoption identity | reparent exact instance | identity/layout snapshot tests |
| Medium | Dialogue/Quest命名誤導 | UI存在但domain不完整 | TODO標記、禁止虛構manager |
| Medium | Input overlap | A movement/card group | run-level input validation |
| Medium | UI/domain混合 | TownProgressUI直接mutate services | 不複製此模式，未來抽Presenter |

## 12. Code Examples

### 12.1 Current map path resolution

來源：`scripts/systems/map_registry.gd` 與 `scripts/managers/game.gd`

```gdscript
func resolve(scene_path: String) -> String:
	return String(CANONICAL_TO_AUTHORITATIVE.get(canonical(scene_path), scene_path))

func _resolve_main_scene_path(scene_path: String) -> String:
	return map_registry.resolve(scene_path)
```

### 12.2 Signal-first boundary

來源：`scripts/interaction/portal.gd`

```gdscript
signal portal_entered(
	portal: Node,
	target_scene_path: String,
	target_spawn_name: StringName,
	interactor: Node
)

func interact(interactor: Node = null) -> bool:
	if locked:
		locked_interaction.emit(locked_reason)
		return false
	if not super.interact(interactor):
		return false
	portal_entered.emit(self, target_scene_path, target_spawn_name, interactor)
	return true
```

### 12.3 State projection

來源：`scripts/managers/game.gd`

```gdscript
func _sync_progression_to_meta() -> void:
	wallet_gold = int(inventory_manager.call("get_resource_amount", &"gold"))
	meta_state.inventory_state = inventory_manager.call("to_dict") as Dictionary
	meta_state.town_state = town_manager.call("to_dict") as Dictionary
```

## 13. Scene Tree Example

```text
Game
├── MapRoot
│   └── AuthoritativeMap
│       ├── PlayerSpawn
│       ├── Player
│       ├── WorldCollision
│       ├── Interactives
│       └── EncounterDirector
├── HUDLayer
│   └── HUD
│       └── AutumnCardHandUI（Autumn only）
├── MenuLayer
│   └── [runtime modal UI]
└── CardEffectRunner
```

此 tree表示 runtime ownership；authoritative map在 editor中還含
`EditorHUDReference`，其 HUD children會在 runtime被adopt到 `HUDLayer`。

## 14. Godot Example (Godot 4)

以下示範在目前架構內安全連接 optional signal，不引入 Autoload：

```gdscript
func _connect_if_present(
	source: Node,
	signal_name: StringName,
	callback: Callable
) -> void:
	if not source.has_signal(signal_name):
		return
	if source.is_connected(signal_name, callback):
		return
	source.connect(signal_name, callback)
```

Godot 4 使用 `Signal.connect()`／`Object.connect()`與 `Callable`。不得引用 Godot 3
的字串 method target signature。

## 15. Best Practice

- 以 `Game`作composition root，但將純規則留在小型 `RefCounted` system。
- 使用typed signal表達下層intent，上層決定流程。
- canonical map path與authoritative path同時文件化。
- 將static catalog、runtime state、save DTO、UI projection分開。
- 使用Scene/group/API contract tests保護dynamic wiring。
- save schema變更保留old payload fixture與migration證據。
- 未存在系統明確標 `TODO`。

## 16. Anti Pattern

- 為方便存取直接新增未治理的 Autoload。
- 讓 Portal直接 `change_scene_to_file(canonical_path)`繞過registry。
- 重新instantiate HUD而遺失map-authored override。
- 讓 UI直接修改card catalog或敵人。
- 同一交易只更新wallet或只更新InventoryManager。
- 把quick save描述成完整run snapshot。
- 看到 `HUDQuestTracker`就聲稱已存在Quest system。
- 繼續把新domain規則塞入`game.gd`。

## 17. Architecture Checklist

開始架構相關修改前：

- [ ] 已確認 `project.godot` main scene與Autoload現況。
- [ ] 已找出current owner、caller、signal與cleanup。
- [ ] 已區分canonical/authoritative map path。
- [ ] 已區分static catalog、runtime、meta、run、save、UI projection。
- [ ] 已列出所有被修改的public API與tests。
- [ ] 已辨識Inventory/Save重疊風險。
- [ ] 不存在能力已標 `TODO`，未自行設計玩法。

## 18. Review Checklist

- [ ] Main scene仍為`res://scenes/game/game.tscn`，或已同步全部治理與測試。
- [ ] 沒有未文件化Autoload/global state。
- [ ] Map load保留Player transfer、spawn、camera、HUD adoption。
- [ ] Signal參數與producer/consumer一致。
- [ ] UI只投影與emit intent，沒有新增domain規則。
- [ ] MetaState/RunState lifetime沒有混淆。
- [ ] Save payload/schema/backup/migration有實際測試。
- [ ] Inventory各份狀態在所有mutation path同步。
- [ ] dynamic Node/Signal reference處理null、duplicate connection與cleanup。
- [ ] code、Scene、data、test、docs同步。

## 19. Future Extension

以下均為 Proposed，尚未實作：

1. 分階段抽出Save、Shop、Run Combat、UI Stack coordinator，縮小`Game`。
2. 統一InventoryManager與prototype inventory，建立single source of truth。
3. 將meta/quick save整合到有migration registry的persistence service。
4. 為成熟catalog評估typed Resource；先決定JSON migration與authoring流程。
5. 建立正式Quest、data-driven Dialogue與Audio架構。
6. 建立input context，消除movement/card/UI action衝突。
7. 用ADR記錄Autoload、Resource與save架構決策。

## 20. Related Documents

- `docs/README.md`
- `docs/01_AI_GUIDE.md`
- `docs/03_SCENE_STRUCTURE.md`
- `docs/04_UI_GUIDE.md`
- `docs/05_CODING_STANDARD.md`
- `docs/06_RESOURCE_GUIDE.md`
- `docs/09_TESTING_GUIDE.md`
- `docs/10_DEBUG_GUIDE.md`
- `docs/12_GAME_DESIGN.md`
- `docs/13_ROADMAP.md`
- `docs/rule_1.md`

## 21. Card、Skill、Growth 與 Autumn HUD 契約（2026-07-26）

本節取代本文較早的 Autumn「HUD 與 CardHand 並列」、Defense 卡牌及被動
evolution 描述。`Game` 仍是 composition root，持有 queue、UI、pause 與 save
transaction；跨 MetaState／RunState／DeckManager 的 collection mutation 則集中於
`CardCollectionService`，不得在 UI 或其他 caller 複製三份寫入邏輯。

### 21.1 Instance、牌堆與存檔邊界

`CardInstance` 是 runtime 與持久化卡牌 identity：

```text
CardInstance
├── instance_id: String
├── card_id: String
└── level: int（1..3）
```

`DeckManager` 的 hand、draw、discard、exhaust、cooldown 五個區域都必須保留同一
instance identity。cooldown 到期回 discard；modal pause 時 cooldown 不前進。
expedition deck 是 16 張普通 `CardInstance`；洗牌後抽 8 張，UI 分成兩組各 4 張。
`ember_bolt` 是普通卡，遵循一般抽牌、棄牌、升級、融合與移除規則。`quickstep`
已從正式卡表移除。玩家固有 Dash 由 `PlayerController` 的 Space action 擁有，
不是 `CardInstance`，不進 deck/hand/piles、不花 AP，也不觸發出牌事件。

戰前另由 `DeckBuilderUI` 從已解鎖 attack cards 選一個 auto attack。選擇保存於
`MetaState.auto_attack_card_id`，Run 開始時複製到 run-local lock；戰鬥中不可切換。
auto attack 不建立額外 CardInstance、不進 hand 或任一牌堆、不花 AP，也不送入
`SkillRecipeManager.record_card()`。只有有效敵人進入該 attack 的近距離 range 時
才依 interval 自動施放。

Dash Edge 與 Gale Drive 仍是 Combo cards；其 infusion 以
`target_action = "dash"` 暫時投影到玩家固有 Dash，不建立或尋找 Dash 卡。

`MetaState` schema version 5 以 `selected_card_instances` 儲存 instance payload，
同時保留必要的舊 `selected_deck` projection 作 compatibility。舊 card-id 陣列 migration
必須 deterministic、idempotent，修復非法 level 與重複/缺失 instance ID，並提供
migration report。schema 6 另保存 `auto_attack_card_id`、`learned_skill_ids` 與
`active_skill_ids`；auto attack 缺失或無效時 fallback 到已解鎖的有效 attack，
active skill 必須是 learned 的子集。`RunState.card_instances` 是 expedition
期間的同一 identity projection，不另造 card-id 等級表。

### 21.2 Combat 與 skill services

- `CombatStatusController` 是 timed combat status authority。同 source 重放刷新；
  super armor 取最高 tier；damage reduction 合計上限 60%；unblockable damage
  必須繞過 reduction。它也負責 regeneration、lifesteal、retaliation 與 pause。
- 卡牌 taxonomy 不再有 `defense`。原防禦牌是 `combo`，治療牌是綠色
  `healing`，效果分為 immediate restore、regeneration、lifesteal 等明確語意。
- `SkillRecipeManager` 只接收成功且正傷害的 attack card event。count 與 exact
  sequence 都有 8 秒 window；non-attack 不推進，exact sequence 的錯誤 attack
  會重設並允許從第一步重新開始。各 active skill 可同時判定並有獨立 cooldown。
- 已學會 skill 永久保存；active loadout 受 Memory Library capacity
  10/14/18/24/30 限制。初始 `Iron Momentum` 使用 1 memory：五次 attack 觸發
  三秒弱霸體，十秒 cooldown。

### 21.3 成長與 UI ownership

`GrowthChoiceQueue` 將 wave blessing 與 EXP level-up 排成單一 FIFO。wave 只提供
new card；EXP 提供單一 instance upgrade 或兩張不同 Lv.3 instances 的 fusion。
fusion 消耗兩張材料並加入一張 Lv.1 結果，牌組淨減一。若沒有合法 upgrade/fusion，
才提供 75 gold、12 wood + 8 stone、或 4 magic shards 的永久 fallback。

`Game` resolve choice、處理單張 upgrade／fallback、同步 Meta DTO 並提交 save。
`CardCollectionService` 驗證共享 CardInstance identity 與 fusion recipe，原子執行
new-card／fusion／exact removal，並提供 collection snapshot／restore 給 save
failure rollback。它不擁有 AP、出牌、cooldown tick 或 UI。

`CardGrowthUI` 只 projection queue page 並 emit choice intent。modal 開啟期間，
`Game` 必須以成對 pause token 暫停 gameplay、AP、card cooldown、status/skill
timers、wave 與 projectile；UI 使用 always process。close/teardown 必須釋放 token。

Autumn 的唯一 combat presentation root 是
`res://scenes/ui/autumn/AutumnHUD.tscn`。它內嵌 card hand，語意樹如下：

```text
AutumnHUD
├── TopLeftStack
│   ├── ActiveStatusList
│   └── ObjectivePanel
├── TopCenterStack
│   ├── BossHealth
│   └── SkillToastStack
└── BottomStage
    ├── PlayerVitals
    ├── ActionPoints
    ├── CardStage
    │   ├── CooldownStrip
    │   └── AutumnCardHandUI
    ├── InputGlyphHints
    └── PersonalResources
```

Town HUD 不受影響。Autumn skill toast 最多三筆、顯示約 1.5 秒後淡出；相同 skill
重複觸發刷新既有 toast。HUD 不顯示常駐 recipe progress。
