# Game Design

本文件記錄目前專案已實作、可由場景、腳本、資料與測試驗證的遊戲規則。它不是提案文件；未能由目前專案證實的內容一律標記為 `TODO`，不得把 Future Extension 當成已核准玩法。

適用版本：Godot 4.7、目前 `main` 分支的 Town → Autumn survival vertical slice。

## 目錄

1. [文件目的、Authority 與狀態詞](#1-文件目的authority-與狀態詞)
2. [核心遊戲循環](#2-核心遊戲循環)
3. [世界、地圖與導航](#3-世界地圖與導航)
4. [玩家移動與生存狀態](#4-玩家移動與生存狀態)
5. [秋季生存關卡與 Guardian](#5-秋季生存關卡與-guardian)
6. [卡牌、牌組、手牌與 AP](#6-卡牌牌組手牌與-ap)
7. [Combo、Infusion 與 Evolution](#7-comboinfusion-與-evolution)
8. [經驗值、升級與 Run 成長](#8-經驗值升級與-run-成長)
9. [城鎮、資源與裝備](#9-城鎮資源與裝備)
10. [營火、商人、寶箱與捷徑](#10-營火商人寶箱與捷徑)
11. [Run 結算、Meta Progression 與存檔](#11-run-結算meta-progression-與存檔)
12. [輸入、HUD 與回饋](#12-輸入hud-與回饋)
13. [Scene Tree Example](#13-scene-tree-example)
14. [Code Example](#14-code-example)
15. [Godot Example (Godot 4)](#15-godot-example-godot-4)
16. [Best Practice](#16-best-practice)
17. [Anti Pattern](#17-anti-pattern)
18. [Gameplay Change Checklist](#18-gameplay-change-checklist)
19. [Review Checklist](#19-review-checklist)
20. [Known TODO](#20-known-todo)
21. [Future Extension](#21-future-extension)
22. [Related Documents](#22-related-documents)

## 1. 文件目的、Authority 與狀態詞

### 1.1 目的

本文件用於回答：

- 玩家目前能做什麼；
- 一次 Autumn expedition 如何開始、進行與結束；
- 卡牌、AP、Combo、XP、裝備與城鎮進度如何互相連接；
- 哪些規則已由 runtime 實作；
- 哪些設計稿敘述尚未成為遊戲事實。

### 1.2 Authority

發生衝突時，遊戲規則的證據順序為：

1. 目前 runtime 腳本、場景與資料；
2. 目前可重現的自動化與手動驗證；
3. 已核准且仍有效的設計決策；
4. implementation plan 的勾選狀態；
5. 歷史提案或預期。

不得只因 plan 已勾選，就宣稱玩家可在 runtime 使用該功能。

### 1.3 狀態詞

| 狀態 | 定義 |
|---|---|
| 已實作 | 目前 runtime 有可到達的玩家流程，且能從程式或測試找到證據 |
| 已存在但不可到達 | 程式仍有方法或資料，但目前 UI／場景沒有玩家入口 |
| Layout only | 場景可進入與瀏覽，但沒有該區域專屬完整玩法 |
| TODO | 資訊不足、程式與設計不一致，或尚無可驗證實作 |
| Future | 僅為可能方向，不是承諾、排程或已核准玩法 |

## 2. 核心遊戲循環

### 2.1 已實作主循環

目前可驗證的主循環如下：

```text
Town
  → 與 NPC、商店、裝備／城鎮進度互動
  → 進入 Autumn portal
  → Deck Builder 選擇 1–16 張遠征牌
  → 開始 Autumn Run
  → 四個限時生存階段
  → Guardian 階段
  → Guardian 死亡，解鎖本次場景的 forward portal
  → 經 portal 離開並結算
  → Run Result
  → 回到 Town／進入下一個 layout
```

### 2.2 Run 的開始

進入 Town 的 Autumn portal 時：

1. 先開啟 Deck Builder；
2. 選擇結果被正規化為 1–16 張；
3. `ember_bolt` 必須存在且只允許一張；
4. 建立新的 `RunState`；
5. 建立抽牌堆、手牌、棄牌堆與消耗牌堆；
6. 洗牌後確保 `ember_bolt` 在起始手牌；
7. 載入 `scenes/maps/autumn_tree/AutumnTreeMap.tscn`。

### 2.3 Run 的結束

目前有三種可觀察結果：

| 情況 | Runtime 行為 |
|---|---|
| Guardian 後進入 forward portal | 以勝利結束 Run，顯示結果並套用獎勵 |
| Run 進行中返回 Town | 以非勝利結束，保留已記錄的 Run 獎勵 |
| 玩家生命歸零 | 短暫延遲後以非勝利結束並返回 Town |

Guardian 死亡本身不是最終結算點；目前成功是在玩家使用 forward portal 時完成。

## 3. 世界、地圖與導航

### 3.1 Authoritative scenes

| 區域 | Authoritative scene | 現況 |
|---|---|---|
| Game entry | `res://scenes/game/game.tscn` | 已實作 |
| Town | `res://scenes/maps/town/TownMap.tscn` | Hub gameplay |
| Autumn | `res://scenes/maps/autumn_tree/AutumnTreeMap.tscn` | 完整 survival vertical slice |
| Crystal Caves | `res://scenes/maps/layouts/CrystalCavesLayout.tscn` | Layout only |
| Forbidden Graveyard | `res://scenes/maps/layouts/ForbiddenGraveyardLayout.tscn` | Layout only |

舊路徑由 `Game` 正規化到 authoritative scene。新增文件或測試時應引用 authoritative path。

### 3.2 Town

Town 是起始 Hub，現有內容包括：

- Player、地形與碰撞；
- Mayor、村民、守衛、藥水商人、鐵匠與旅店角色；
- 建築進度與裝備進度 UI；
- Town 商品買賣；
- Autumn、Crystal Caves、Forbidden Graveyard portal；
- Town 內部的入口／尾端 fast travel。

Town 可直接進入 Crystal Caves 與 Forbidden Graveyard，因此 Autumn Guardian 的 forward portal 目前不是全域世界進度鎖。

### 3.3 Autumn

Autumn 場景包含：

- `AutumnRunDirector`；
- `HiddenBranchCache`；
- `ForestRest`；
- `ShortcutLever`；
- `WanderingCardMerchant`；
- Town return portal；
- 初始 locked 的 forward portal；
- Player、一般敵人、Guardian 與戰鬥區域。

### 3.4 後續區域邊界

Crystal Caves 與 Forbidden Graveyard 目前只有可走動 layout、portal、碰撞與裝飾物件。不得在遊戲設計、release note 或 review 中將它們描述為已有完整戰鬥、Boss 或獎勵循環。

## 4. 玩家移動與生存狀態

### 4.1 已實作移動

Player 根節點為 `CharacterBody2D`，已實作：

- 水平移動；
- 跳躍；
- dash；
- 朝向切換；
- idle、walk、jump 視覺狀態；
- Camera2D 跟隨；
- 互動偵測與 Hurtbox。

目前基礎數值：

| 屬性 | 基礎值 |
|---|---:|
| Move speed | 260 |
| Gravity | 980 |
| Jump velocity | -420 |
| Dash distance | 150 |
| Dash cooldown | 0.65 秒 |
| Max health | 100 |
| Max mana | 50 |
| Attack | 16 |
| Defense | 3 |

場景中可覆寫 export 值；上表描述 `player_controller.gd` 的基準。

### 4.2 傷害、防禦與 Dash

- 傷害先消耗 block，再由 health 承受；
- defense 會參與目前傷害計算；
- dash 期間有短暫無敵；
- dash 有 cooldown；
- health 歸零時發出 `defeated` signal；
- Campfire 與商人物品可透過既有 public method 恢復 health／mana。

### 4.3 Encounter leash

Autumn encounter 的預設 engage radius 為 650，leash radius 為 760。玩家離開外圈後開始五秒警告：

- 在倒數結束前返回會取消重置；
- 倒數結束時，存活敵人恢復生命、位置與狀態；
- 這是 encounter reset，不是 Run 結算。

## 5. 秋季生存關卡與 Guardian

### 5.1 生存階段

`SurvivalWaveDirector` 依時間推進，不要求先清空上一階段敵人。

| 階段 | 時間 | Spawn interval | Alive cap | Enemy pool |
|---|---:|---:|---:|---|
| 1 | 45 秒 | 2.40 秒 | 8 | sprout、hopper |
| 2 | 45 秒 | 1.80 秒 | 12 | sprout、hopper、thornling |
| 3 | 50 秒 | 1.35 秒 | 17 | hopper、thornling、charger |
| 4 | 55 秒 | 1.00 秒 | 22 | sprout、thornling、charger、elite |
| Guardian | 無固定結束時間 | 3.00 秒 | 16 | thornling、charger，加一隻 Guardian |

每次 spawn interval 最多生成一隻一般敵人，直到 alive cap。進入新階段時可先生成最多三隻。

### 5.2 敵人行為

目前 archetype 可表現：

- 近戰追擊；
- leap；
- ranged；
- charge；
- elite 行為；
- slow、stun、burn 狀態。

一般敵人死亡會產生實體 `ExperienceGem`。Gem 在 180 像素內吸引玩家、30 像素內收集，移動速度由 180 加速至 520。

### 5.3 Guardian

Autumn Guardian 的目前規則：

| 屬性 | 值 |
|---|---:|
| Health | 600 |
| Defense | 6 |
| Phase 2 threshold | health ≤ 66% |
| Phase 3 threshold | health ≤ 33% |

已實作攻擊模式：

- root sweep；
- falling acorns；
- ember burst。

Guardian 死亡後：

- 停止 director；
- 解鎖本場景 forward portal；
- Run 增加 18 autumn wood；
- Run 增加 7 magic shards；
- persistent inventory 增加 1 autumn core；
- 標記 `autumn_route_cleared`；
- 發現 catalog 中第一個尚未擁有的 equipment。

### 5.4 已知 Guardian 邊界

- `drop_emitted` signal 目前沒有 consumer；上述獎勵由 `Game` 直接處理。
- Guardian 死亡後，尚未收集的 gem 不會自動結算或清除。
- Guardian support enemy 在玩家離開地圖前仍可能存活並生成 gem。
- `autumn_route_cleared` 會寫入，但目前沒有重入 Autumn 時恢復 forward portal 狀態的讀取流程。
- Boss 獎勵先存在記憶體，持久化發生在後續 Run finish。

以上是 `TODO`／限制，不得寫成玩家已獲得的保證。

## 6. 卡牌、牌組、手牌與 AP

### 6.1 Card catalog

`res://data/cards.json` 目前有 23 張通過 loader 驗證的卡。有效類型包括：

- attack；
- skill；
- power；
- summon；
- defense；
- status；
- ultimate；
- combo。

卡片資料包含 ID、名稱、類型、cost、tag、effect、icon path 與 level upgrade。六組 evolution recipe 位於 `res://data/evolutions.json`。

### 6.2 Deck Builder

目前規則：

- expedition deck 最少 1 張、最多 16 張；
- `ember_bolt` 必須存在且只允許一張；
- combo card 最多一張；
- 其他一般卡最多三張；
- Meta 預設解鎖 13 張卡；
- 預設 selected deck 有 16 張。

### 6.3 牌堆與手牌

`DeckManager` 管理：

- `draw_pile`；
- `hand`；
- `discard_pile`；
- `exhaust_pile`。

手牌容量為 8，但不足 8 張的 deck 不會憑空補牌。UI 一次顯示最多 4 張，透過兩個 card group 切換。打出一般卡後進入 discard；combo type 卡進入 exhaust。

`ember_bolt` 是 protected card：

- 起始時優先放入 hand；
- 打出後不移出 hand；
- redraw 與 end-turn cleanup 會保留一張；
- overflow discard 不允許選它。

### 6.4 AP

玩家 UI 稱為 AP；目前 `DeckManager` 程式欄位沿用 `energy` 命名。

| 規則 | 目前值 |
|---|---:|
| Base max AP | 5.0 |
| Run start AP | 5.0 |
| Base regeneration | 0.65／秒 |
| Energy Wisp bonus | +0.35／秒 |
| Energy Wisp duration | 6 秒 |

卡片 cost 大於目前 AP 時不能打出。成功打出後扣除 cost 並執行 effect；非
protected card 離開手牌後補抽一張 replacement，再加上卡片 effect 指定的額外
抽牌。Protected `ember_bolt` 保留在手中，因此沒有普通 replacement draw。

### 6.5 Redraw 與 overflow

- 只有 AP 已滿且 hand 非空時可 full-AP redraw；
- redraw 將 AP 設為 0；
- protected card 保留，其餘進入 discard；
- 在可抽牌範圍內把 hand 補至最多 8 張；
- 抽牌造成 hand overflow 時開啟 modal discard；
- protected card 不能被 overflow discard。

### 6.6 Card focus

Card focus 會把 `Engine.time_scale` 設為 0.22，hit stop 也會短暫改變全域 time scale。正常路徑會恢復，但節點中途離開時缺少統一 teardown 保證，列入 TODO。

## 7. Combo、Infusion 與 Evolution

### 7.1 Sequence Combo

`ComboManager` 保留最近三次出牌歷史並比對五條規則：

- Ember Chain；
- Blade Dance；
- Bulwark；
- Storm Step；
- Arcane Cycle。

每條 sequence combo 每個 Run 最多觸發一次，觸發後更新 combo count 與 HUD 顯示。

### 7.2 Combo-type infusion cards

Combo 類型卡與 sequence combo 是兩個不同系統。現有五種 infusion：

- flame；
- frost；
- rhythm；
- stoneguard；
- blood pact。

Combo-type card 打出後進入 exhaust，對本 Run 啟用持續 infusion，最多四種。每個 infusion 可升至 level 3。

目前組合 evolution：

- flame + frost → Thermal Shatter；
- rhythm + stoneguard → War Cadence。

### 7.3 Card evolution

生存階段 2 開始時，六個 evolution passive 會注入本次 Run。符合 recipe 的 base card 到 level 3 時：

- hand 中相同 base card 轉換；
- draw pile 中相同 base card 轉換；
- discard pile 中相同 base card 轉換；
- Meta 記錄 unlocked evolution。

### 7.4 效果語意限制

目前 effect runner 支援 damage、area damage、block、heal、dash、status、power、aura、summon、overdrive 與 infusion。

必須依程式實際語意描述：

- damage aura 目前是一次性 area hit；
- attack-power／overdrive 沒有可見的 duration 到期回復流程；
- 不得把一次性效果寫成持續 tick，除非 runtime 已新增並驗證。

## 8. 經驗值、升級與 Run 成長

### 8.1 Experience

一般敵人死亡產生 ExperienceGem。收集後呼叫 `RunState.add_experience()`。

Run 初始：

- level = 1；
- experience = 0；
- experience required = 40。

下一級門檻公式：

```text
next_required = ceil(previous_required * 1.32 + 12)
```

一次取得大量經驗可跨多級，每一級加入 `pending_level_ups`，不會只保留一次升級。

### 8.2 Level-up choices

目前 choice generator 可提供：

- 升級 Run deck 中低於 level 3 的卡；
- Run deck 少於 16 張時加入已解鎖卡；
- fallback：增加 10 max health；
- fallback：增加 0.10 AP regeneration；
- fallback：移除一張可移除卡。

目前沒有獨立的「升級已啟用 combo」choice。Combo card 若在 deck 中，只能走一般 card upgrade 規則。設計文件若提到 combo-specific choice，必須標記 `TODO`。

## 9. 城鎮、資源與裝備

### 9.1 Persistent resources

目前資源 ID：

- `gold`；
- `autumn_wood`；
- `stone`；
- `magic_shard`；
- `autumn_core`。

`equipment.json` 的初始資源為：

| Resource | Initial amount |
|---|---:|
| gold | 200 |
| autumn_wood | 60 |
| stone | 50 |
| magic_shard | 30 |
| autumn_core | 20 |

### 9.2 Equipment

目前 catalog 有 10 件裝備，slot 為：

- weapon；
- armor；
- accessory。

裝備可購買、裝備、卸下，最高升到 level 3。升級成本由目前 level 計算：

```text
gold = 25 × current_level
autumn_wood = 5 × current_level
magic_shard = 2 × current_level
```

已實際投影到 gameplay 的一般屬性：

- attack；
- defense；
- max health；
- max mana；
- move speed。

已實際投影到 card combat 的特殊屬性：

- AP regeneration；
- card damage；
- card block；
- card healing。

資料中存在但尚未找到 runtime consumer 的屬性：

- critical chance；
- magic power；
- shop discount；
- dash cooldown reduction；
- merchant bonus choice。

這些欄位目前不是有效玩家能力，列為 TODO。

### 9.3 Town progression

目前四個 building ID：

- blacksmith；
- workshop；
- market；
- town hall。

每棟最多三個 level。Village stage 的 total-building-level threshold 為 0、3、7。Mayor interaction 開啟 Town Progress UI。

目前場景只直接改變 MarketStall、EmptyResidence、EmptyTowerHouse 與 Blacksmith 的部分視覺。Manager 產生的其他 visual flag 尚未完整投影，不得宣稱所有升級都有對應外觀。

### 9.4 兩套 inventory/economy

目前同時存在：

1. `InventoryManager` 的 persistent resource／equipment；
2. `Game.wallet_gold` 與 `player_inventory` 的 prototype town shop。

Town 商品包含 bread、map、sword、boots 等 prototype item。交易後會把 gold 同步回 persistent inventory，但 item ownership 仍屬第二套資料。此重疊是已知技術邊界，不應被描述成單一統一 inventory。

## 10. 營火、商人、寶箱與捷徑

### 10.1 Campfire

玩家目前可到達的 Campfire 選項只有：

- Rest；
- Leave。

Rest 每個 Run 只能成功使用一次，會把 health 與 mana 恢復到上限。UI 不提供合卡或升卡。

`Game` 仍保留 private merge／upgrade method，舊測試也會直接呼叫它們；這些屬於「已存在但不可到達」的 dead logic，不是目前玩法。

### 10.2 Wandering merchant

Wandering merchant 使用本次 Run 的 `gold_earned`，不是 Town persistent gold。現有 offer：

| Offer | Cost |
|---|---:|
| Health restore | 25 run gold |
| Mana restore | 20 run gold |
| Ordinary card | 35 run gold |
| Rare/combo card | 70 run gold |
| Purge one removable card | 45 run gold |

Stock 存在 `RunState.temporary_buffs` 中，只對本次 Run 有效。

### 10.3 Hidden cache

`HiddenBranchCache` 目前給予：

- 45 run gold；
- 12 autumn wood。

獎勵先保留在 Run，之後由 finish summary 套用。

### 10.4 Shortcut

`ShortcutLever` 寫入永久 `forest_gate` flag。之後進入 Autumn 時，既有程式可把玩家放在約 `Vector2(1580, 576)` 的 shortcut spawn。

## 11. Run 結算、Meta Progression 與存檔

### 11.1 RunState

`RunState` 是暫時狀態，包含：

- active、level、experience、pending level-ups；
- AP；
- starting deck、temporary cards、card levels；
- combo count、temporary buffs；
- run gold、materials；
- defeated enemy／elite／boss flags。

`finish_run()` 產生 summary 後重置 transient state。

### 11.2 MetaState

`MetaState` schema version 為 2，保存：

- persistent resources；
- village／building progression；
- unlocked cards、evolutions、combos；
- selected deck；
- equipment 與 equipment level；
- settings；
- shortcut flags；
- inventory/town nested state；
- boss state。

`permanent_card_levels` 與 `unlocked_combos` 目前有序列化欄位，但尚未找到 gameplay consumer，列為 TODO。

### 11.3 Meta save

`SaveService` 使用：

```text
user://saves/meta_progress.json
```

寫入流程包含 temporary file、JSON validation、backup 與失敗恢復。這是 persistent progression 的主要存檔。

### 11.4 Quick save

Quick save 使用：

```text
user://saves/quick_save.json
```

目前保存 map path、玩家基本狀態與位置、prototype wallet/inventory、merchant catalog。它不保存足以重建 expedition 的完整狀態，例如：

- deck piles；
- AP 與 active card effects；
- wave timer 與 living enemies；
- Guardian phase；
- pending level-ups；
- Run merchant/buff state。

因此目前 quick save 不能被描述為「可在戰鬥中完整續玩」。

## 12. 輸入、HUD 與回饋

### 12.1 Keyboard/controller mapping

| Action | Input |
|---|---|
| Move | A/D 或方向鍵 |
| Jump | Space／上 |
| Interact | F |
| Inventory | I |
| Pause | Escape |
| Dash | Shift／右肩鍵 |
| Card focus | Tab／左肩鍵 |
| Card slots | Q/W/E/R／手把 face buttons |
| Card groups | A/S／triggers |
| Redraw | T／D-pad down |

實體 A 鍵同時屬於 move-left 與 card-group-1，可能在移動時切換 card group。此衝突尚未有 gameplay regression test，列為 TODO。

### 12.2 HUD

現有 HUD／Card Hand 提供：

- health、mana 與玩家資訊；
- 區域、目標與 survival phase；
- enemy alive/cap；
- AP；
- 兩組卡片的目前 group；
- combo 提示；
- Guardian health；
- interaction prompt；
- Run Result、Level Up、Discard、Deck Builder modal。

UI 顯示不得宣告 backend 尚未提供的能力。

## 13. Scene Tree Example

以下是目前 runtime ownership 的簡化樹，不是建議新場景：

```text
Game (Node)                         scenes/game/game.tscn
├── MapRoot (Node)
│   └── AutumnTreeMap (Node2D)      runtime instance
│       ├── PlayerSpawn (Marker2D)
│       ├── Player (CharacterBody2D)
│       ├── AutumnRunDirector (Node2D)
│       ├── HiddenBranchCache
│       ├── ForestRest
│       ├── ShortcutLever
│       ├── TownPortal
│       ├── ForwardPortal
│       └── WanderingCardMerchant
├── HUDLayer (CanvasLayer)
│   ├── HUD (Control)
│   └── CardHandUI (Control)
├── MenuLayer (CanvasLayer)
│   ├── DeckBuilderUI (Control)     created when opened
│   ├── LevelUpUI (Control)         created when opened
│   └── RunResultUI (Control)       created when opened
└── CardEffectRunner (Node)
```

Player contract：

```text
Player (CharacterBody2D) [group: Player]
├── Visual (Node2D)
│   └── CharacterSprite (Sprite2D)
├── CollisionShape2D
├── InteractionDetector (Area2D)
│   └── CollisionShape2D
├── Hurtbox (Area2D)
│   └── CollisionShape2D
└── Camera2D
```

## 14. Code Example

以下範例直接反映目前 Run XP 的規則。Gameplay 數值修改時，應同步更新本文件與相關測試。

```gdscript
func add_experience(amount: int) -> int:
	if amount <= 0 or not active:
		return 0

	var queued := 0
	experience += amount
	while experience >= experience_required:
		experience -= experience_required
		level += 1
		pending_level_ups += 1
		queued += 1
		experience_required = int(
			ceil(float(experience_required) * 1.32 + 12.0)
		)
	return queued
```

這個 contract 的重點是一次收集大量 XP 時使用 `while`，所有升級都必須排入 queue。

## 15. Godot Example (Godot 4)

Gameplay orchestration 應以 typed signal 連接，而不是讓 director 直接操作 HUD：

```gdscript
func wire_survival_director(director: SurvivalWaveDirector) -> void:
	if not director.phase_time_changed.is_connected(
		_on_survival_phase_time_changed
	):
		director.phase_time_changed.connect(
			_on_survival_phase_time_changed
		)

	if not director.boss_stage_completed.is_connected(
		_on_boss_stage_completed
	):
		director.boss_stage_completed.connect(
			_on_boss_stage_completed
		)


func _on_survival_phase_time_changed(
	phase: int,
	remaining: float,
	alive: int,
	cap: int
) -> void:
	hud.set_objective(
		"SURVIVAL PHASE %d" % phase,
		"%ds   Enemies %d / %d" % [ceili(remaining), alive, cap]
	)
```

這是 Godot 4 signal 語法示例；實際專案由 `Game` 的既有 wiring method 管理連接。

## 16. Best Practice

- 先從 runtime 與測試確認規則，再更新本文件。
- 數值只定義在一個 authoritative data/script location。
- 將 `RunState` 與 `MetaState` 明確分開。
- 將 sequence combo 與 combo-type infusion 分開命名與測試。
- UI 只顯示 backend 已實作的 action。
- Portal、Campfire、Merchant 的玩家入口必須有 scene-level test。
- Save claim 必須由 round-trip test 證明。
- Boss／Run 結算要明確指定「發生事件」與「持久化完成」兩個時點。
- Gameplay 文件中的 Future 一律連到 roadmap 驗收項，不可寫成現況。

## 17. Anti Pattern

- 從概念圖或未完成 plan 推測玩法已存在。
- 把 Crystal Caves／Forbidden Graveyard layout 寫成完成區域。
- 把 `energy` 與 mana 混為同一資源。
- 把 sequence combo 與 infusion card 合併成一套規則。
- 宣稱 Campfire 可合卡／升卡，因為 private method 尚在。
- 宣稱 dormant equipment field 已影響玩家。
- 宣稱 Guardian 死亡已完成持久化結算。
- 宣稱 quick save 可完整恢復 expedition。
- 在多處複製 wave、AP、XP 或 upgrade 數值。
- 修改玩法後只改文件、不跑對應 gameplay test。

## 18. Gameplay Change Checklist

變更任何玩法前：

- [ ] 找到 authoritative script、scene、JSON 與 caller。
- [ ] 確認變更屬於 Run state 或 Meta state。
- [ ] 確認 UI 是否已有可到達入口。
- [ ] 列出受影響的 signal 與 save field。
- [ ] 找到現有測試並先建立失敗案例。
- [ ] 檢查輸入衝突與 pause/time-scale 行為。
- [ ] 檢查死亡、撤退、勝利、重入與讀檔。
- [ ] 檢查舊 save 的 schema/migration。
- [ ] 更新本文件的數值與限制。
- [ ] 依 `docs/rule_1.md` 完成 scene 與 UI 驗證。

## 19. Review Checklist

Reviewer 必須確認：

- [ ] 本次敘述可由目前 code／scene／data 證實。
- [ ] 沒有新增未核准玩法。
- [ ] 所有不確定內容都標記 TODO。
- [ ] Town → Autumn → Guardian → Result 流程未被破壞。
- [ ] Deck 維持 1–16 張與 protected `ember_bolt`。
- [ ] Hand、兩組顯示、discard、exhaust、overflow 規則一致。
- [ ] AP cost、regen 與 redraw 行為有測試。
- [ ] XP 跨級 queue 與 level-up choice 有測試。
- [ ] Sequence combo、infusion、evolution 各自有明確 contract。
- [ ] Equipment 實際 consumer 與文件一致。
- [ ] Campfire／Merchant 的 UI 可到達行為與文件一致。
- [ ] Run result、Meta save、quick save 的能力沒有誇大。
- [ ] 相關 roadmap item 與測試結果已更新。

## 20. Known TODO

以下均為目前證據確認的缺口：

- [ ] Guardian victory 後處理剩餘 gem 與 support enemy。
- [ ] 決定並驗證 `autumn_route_cleared` 重入行為。
- [ ] 讓 Boss 獎勵在定義的持久化時點可靠落盤。
- [ ] 使 combo-specific level-up 設計與 runtime 一致。
- [ ] 移除或正式保留不可到達的 Campfire card-growth logic。
- [ ] 處理 dormant equipment effect consumer。
- [ ] 定義 expedition 中 quick save 的支援邊界。
- [ ] 解決 A 鍵 movement/card-group 衝突。
- [ ] 完成或縮小 Town visual progression 的對外承諾。
- [ ] 處理 `permanent_card_levels`、`unlocked_combos` 未使用欄位。
- [ ] 為全域 `Engine.time_scale` 加入 teardown 驗證。

## 21. Future Extension

本節只定義未來擴充的治理方式，不定義新玩法。

任何新區域、Boss、卡牌類型、Combo、裝備效果、Town building、商人商品或 save 能力，在進入 production 前必須：

1. 有獨立且核准的 design；
2. 說明與現有 Run／Meta state 的關係；
3. 定義 authoritative data 與 scene；
4. 定義可到達 UI／interaction；
5. 定義存檔與 migration；
6. 具備 gameplay、scene 與 regression test；
7. 更新本文件與 `docs/13_ROADMAP.md`。

Future Extension 不等於承諾，不代表已排期，也不可用來填補現況 TODO。

## 22. Related Documents

- `docs/README.md`
- `docs/01_AI_GUIDE.md`
- `docs/02_PROJECT_ARCHITECTURE.md`
- `docs/03_SCENE_STRUCTURE.md`
- `docs/04_UI_GUIDE.md`
- `docs/05_CODING_STANDARD.md`
- `docs/06_RESOURCE_GUIDE.md`
- `docs/09_TESTING_GUIDE.md`
- `docs/10_DEBUG_GUIDE.md`
- `docs/13_ROADMAP.md`
- `docs/rule_1.md`
- `docs/rule_2.md`
- `.superpowers/sdd/2026-07-25-project-governance/gameplay-testing-audit.md`
