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
7. [Combo、Skill 與 Fusion](#7-comboskill-與-fusion)
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
  → Deck Builder 選擇 1–16 張普通遠征牌與一個獨立 auto attack
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
2. 普通背包結果被正規化為 1–16 張；
3. 從已解鎖 attack cards 選一個獨立 auto attack；
4. 建立新的 `RunState`；
5. auto attack ID 鎖定為本 Run 的選擇，戰鬥中不可切換；
6. 普通背包洗牌後抽 4 張 Combo／Healing 卡，建立 draw/hand/discard piles；
7. 載入 `scenes/maps/autumn_battle/AutumnBattleMapV2.tscn`。

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
| Autumn | `res://scenes/maps/autumn_battle/AutumnBattleMapV2.tscn` | 完整 survival vertical slice |
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
- ↑ 跳躍；
- Space 固有 Dash；
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

`res://data/cards.json` 的有效 gameplay 類型包括：

- attack；
- skill；
- power；
- summon；
- healing；
- status；
- ultimate；
- combo。

`defense` 不再是有效卡牌類型；原防禦牌改為消耗 AP 的 combo status cards。
Healing 卡以綠色呈現，效果明確區分 immediate restore、regeneration 與
lifesteal。卡片資料包含 ID、名稱、類型、cost、tag、effect、icon path 與
level upgrade；六組 fusion recipe 位於 `res://data/evolutions.json`。

### 6.2 Deck Builder

目前規則：

- expedition backpack 最少 4 張、最多 16 張 Combo／Healing 卡；同名卡最多 3 份且各自保存等級；
- auto attack 在背包之外獨立選擇，必須是已解鎖的 `attack` card；
- 同名 Combo／Healing card 最多三張；
- Meta 預設解鎖 20 張卡；
- `MetaState` 分別保存 selected deck 與 `auto_attack_card_id`。

### 6.3 牌堆與手牌

`DeckManager` 管理：

- `draw_pile`；
- `hand`；
- `discard_pile`；
- `exhaust_pile`；
- `cooldown_pile`（DeckManager 相容性路徑；production 戰鬥卡不使用）。

五個牌區都保存 `CardInstance(instance_id, card_id, level)` identity。戰鬥背包
只收 `combat_hand != false` 的 Combo／Healing 卡，最多 16 張；洗牌後抽成單組
4 張手牌，Q/W/E/R 直接打出。不再有 A/S 或 controller LT/RT 切換組別。
戰鬥手牌只以 AP 限制，打出後統一進 discard 並立即補回四張；production
Combo／Healing catalog 不再使用 exhaust／cooldown destination。

`ember_bolt` 是普通卡，可以在背包、手牌與牌堆中出現，也依一般規則升級、
融合、移除與 routing。`quickstep` 已從正式卡表移除。Dash 是玩家固有 action，
不建立 `CardInstance`、不進背包/手牌/牌堆、不耗 AP，也不補抽 replacement card。

### 6.4 AP

玩家 UI 稱為 AP；目前 `DeckManager` 程式欄位沿用 `energy` 命名。

| 規則 | 目前值 |
|---|---:|
| Base max AP | 5.0 |
| Run start AP | 5.0 |
| Base regeneration | 0.95／秒 |
| Energy Cycle | 消耗 1 AP、基礎回復 2 AP |
| Card Tempo | 最多 +0.96 AP／秒，6 秒未出牌後歸零 |

卡片 cost 大於目前 AP 時不能打出。成功打出後扣除 cost、執行 effect、依
destination 離開手牌，補抽一張 replacement，再加上 effect 指定的額外抽牌。
auto attack 永遠免費，不使用這條 AP/hand 流程。

### 6.5 Redraw 與 overflow

- hand 非空時可用 T／D-pad down 棄掉目前四張並補抽四張；
- 棄牌不要求滿 AP，也不消耗 AP；
- 戰鬥手牌統一進入 discard；
- 每次出牌後立即循環牌堆，將 hand 補回 4 張；
- 額外抽牌造成 hand overflow 時開啟 modal discard；
- auto attack 不在 hand，因此不參與 redraw 或 overflow。

### 6.6 Card focus

Card focus 會把 `Engine.time_scale` 設為 0.22，hit stop 也會短暫改變全域 time scale。正常路徑會恢復，但節點中途離開時缺少統一 teardown 保證，列入 TODO。

## 7. Combo、Skill 與 Fusion

### 7.1 Combo cards

`combo` 是卡牌類型，不是另一套非攻擊牌序 manager。原防禦牌以 timed status
combo 形式提供霸體、減傷、反擊或攻擊 infusion；打出後進 discard 並立即補牌。
每次 Combo 疊加全域 Combo Chain 並刷新 2.5 秒窗口：3 層提高攻擊、6 層追加
5% 吸血、9 層追加短暫硬直。相同 infusion 另可疊至 12 層，讓效果持續增強。
右側 HUD 持續列出本次 chain 使用過的技能與各自層數。舊 `ComboManager` 與非攻擊
sequence rules 已移除。

通用 Combo infusion 包含攻擊範圍（Sweeping Reach）、攻擊速度
（Quickened Cadence）、攻擊力（Crushing Momentum）、爆擊率／倍率
（Keen Focus）、彈體數量與展開角度（Echo Volley）與雷屬性硬直
（Storm Charge）；Flame／Frost infusion
則繼續提供火焰與冰霜附加屬性。這些卡都只消耗 AP，不使用 card cooldown。
沒有 Echo Volley 時，自動攻擊固定為單方向、單發、單目標基本型態。Echo Volley
同時增加彈體與方向：Lv.1 是 2 發／90° 扇形、Lv.2 是 4 發／180° 扇形、Lv.3 是
8 發／360° 圓形。Combo Chain 本身只提高傷害、射程與攻擊尺寸，不免費增加方向、
目標數或彈體數；扇形空方向不會把額外傷害重複灌入同一個目標。

### 7.2 Passive attack Skill

Skill recipe 不是卡牌類型，也不由 non-attack card 推進。每次成功且正傷害的
attack card 只產生一個 skill event；multi-hit 仍算一個。active skills 可平行判定：

- count recipe 在 8 秒 window 內累積攻擊次數；
- exact sequence 只接受指定 attack card ID；錯誤 attack 重設，若它也是第一步
  則立即從第一步重新開始；
- non-attack 不推進 recipe；
- 每個 skill 有獨立 cooldown，同一次 attack 可觸發多個 skill。

學會的 skill 永久保留，出發前在安全區/Town 編輯 active loadout。Memory Library
level 的 capacity 是 10/14/18/24/30。初始 `Iron Momentum` 使用 1 memory，五次
attack 觸發三秒弱霸體，cooldown 十秒。

### 7.3 Card upgrade 與 fusion

EXP growth 對個別 `CardInstance` 升級，最高 Lv.3；同 card ID 的兩張卡可有不同
level。fusion 必須明確選兩張不同的 Lv.3 instances，消耗兩張材料並建立一張
Lv.1 結果，牌組淨減一：

| Lv.3 material A | Lv.3 material B | Lv.1 result |
|---|---|---|
| Iron Will (`guard`) | Stone Form (`iron_skin`) | Unbreakable Stance (`fortress_stance`) |
| Dash Edge (`dash_strike`) | Cleave | Gale Drive (`gale_lunge`) |
| Frost Bind | Energy Surge | Time Snare |
| Healing Light | Blood Pact | Renewal |
| Battle Focus | Flame Aura | Overdrive |
| Cleave | Flame Aura | Inferno Orb |

舊「階段 2 自動注入 passive evolution、批次轉換所有同名卡」不再是 gameplay
contract。Dash Edge 與 Gale Drive 標記為 `combat_hand = false`，不再由牌組與
獎勵特別提供；其 legacy infusion 仍以
`target_action = dash` 暫時強化玩家固有 Dash，不指向或建立 Dash 卡。

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
initial_required = 30
next_required = ceil(previous_required * 1.25 + 10)
```

一次取得大量經驗可跨多級，每一級加入 `pending_level_ups`，不會只保留一次升級。

### 8.2 Level-up choices

每一個 pending level-up enqueue 一頁 EXP growth choice：

- 只要存在低於 Lv.3 的 `CardInstance`，隨機抽出最多五張形成獨立升級頁；
- 全部卡片都滿級後，才以另一頁提供最多五組合法 Lv.3 fusion；
- 只有兩者都沒有候選時，改選 75 gold、12 autumn wood + 8 stone、
  或 4 magic shards。

Wave blessing 是另一種 queue source，只提供 new card，不混入 upgrade/fusion；
玩家可直接 Skip，以維持精簡牌組。
牌組已滿 16 張時，選取新卡後必須進入 replacement modal：玩家可移除一張
現有卡換入獎勵，或 Skip 並維持原牌組。
`CardGrowthUI` 把最多五個選項固定排成上三張、下兩張置中的兩列，依 FIFO
一頁一頁處理；舊全牌清單與 max-health/AP-regen/purge fallback 不再是這條
卡牌成長流程的 contract。
New-card 選項必須直接顯示卡牌類型、AP cost 與基礎效果；upgrade 選項必須同時
顯示目前效果與下一級的精確變化，不能只靠 tooltip 或卡牌名稱讓玩家猜測。

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
舊營火 merge/upgrade private method 與直接呼叫它們的測試已移除；所有卡牌成長
只經由 `GrowthChoiceQueue` 與 `CardGrowthUI`。

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
- starting deck compatibility projection、`card_instances`；
- combo count、temporary buffs；
- run gold、materials；
- defeated enemy／elite／boss flags。

`finish_run()` 產生 summary 後重置 transient state。

### 11.2 MetaState

`MetaState` schema version 為 5，保存：

- persistent resources；
- village／building progression；
- unlocked cards 與相容 progression fields；
- `selected_card_instances`（instance ID、card ID、level）；
- legacy `selected_deck` compatibility projection；
- `auto_attack_card_id`；
- `learned_skill_ids` 與 `active_skill_ids`；
- equipment 與 equipment level；
- settings；
- shortcut flags；
- inventory/town nested state；
- boss state。

舊 payload 在載入時 deterministic、idempotent migration；非法 level、重複/缺失
instance ID 必須修復並留下 report。Skill arrays 去重，active 只保留 learned IDs；
auto attack 缺失或無效時在組裝 Run 時 fallback 到有效已解鎖 attack。

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
| Move | A/D 或左右方向鍵 |
| Jump | ↑ |
| Interact | F |
| Inventory | I |
| Pause | Escape |
| Dash | Space／右肩鍵 |
| Card focus | Tab／左肩鍵 |
| Card slots | Q/W/E/R／手把 face buttons |
| Combo hand | Q/W/E/R／手把 face buttons |
| Discard and draw 4 | T／D-pad down |

A/S 僅供移動；`card_group_1` 與 `card_group_2` InputMap actions 已移除。

### 12.2 HUD

現有 HUD／Card Hand 提供：

- health、mana 與玩家資訊；
- 區域、目標與 survival phase；
- enemy alive/cap；
- AP；
- 單組四張 Combo／Healing 手牌；
- 持續顯示總層數、剩餘時間與技能分項的 Combo Chain 清單；
- Guardian health；
- interaction prompt；
- Run Result、Level Up、Discard、Deck Builder modal。

UI 顯示不得宣告 backend 尚未提供的能力。

## 13. Scene Tree Example

以下是目前 runtime ownership 的簡化樹，不是建議新場景：

```text
Game (Node)                         scenes/game/game.tscn
├── MapRoot (Node)
│   └── AutumnBattleMapV2 (Node2D)  runtime instance
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
│   └── HUD (AutumnHUD)
│       └── AutumnCardHandUI (Control)
├── MenuLayer (CanvasLayer)
│   ├── DeckBuilderUI (Control)     created when opened
│   ├── CardGrowthUI (Control)      created while queue is non-empty
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
			ceil(float(experience_required) * 1.25 + 10.0)
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

### Auto attack and Dash

Deck Builder 在戰前從已解鎖 attack cards 選一個 auto attack，與 16 張普通背包
分開保存。Run 開始時鎖定選擇；戰鬥中不可切換。auto attack：

- cost 固定為 0，不進 hand/draw/discard/exhaust/cooldown；
- 只有玩家附近存在有效敵人時才依 catalog range/interval 自動施放；
- 不建立出牌事件，因此不推進 `SkillRecipeManager` 的 count/sequence；
- 可使用所選 attack card 的有效 level/equipment projection；
- 無效選擇 fallback 到已解鎖的有效 attack。

Dash 是玩家固有 action：↑ 只觸發 Jump，Space 觸發 Dash。Dash 不建立
`CardInstance`，不進 backpack/hand/draw/discard/exhaust/cooldown，也不花 AP 或
觸發 `SkillRecipeManager` 的 card sequence。`quickstep` 已從正式卡表移除。
Dash Edge/Gale Drive 是 `combat_hand = false` 的 legacy Combo cards，以 `target_action = dash` 在各自 effect
window 內暫時強化固有 Dash；Combo 本身不直接移動玩家。

The combat hand is one four-card Combo/Healing row. Q/W/E/R play those four cards.
A/S remain movement-only and there is no group-toggle input.

### Timed Combo windows

Combo cards recycle through discard after play and add one independently timed effect
stack. The base window is 2.5 real-time seconds. Fast play can therefore keep
several stacks active at once; when an older stack expires, only that stack is
removed and the displayed level falls accordingly. Eight distinct Combo types
and twelve stacks per type are supported. Evolved Combo effects inherit the
longest remaining time from their consumed ingredients.

The HUD shows the longest remaining Combo timer. Equipment special effects may
modify this loop through:

- `combo_cost_reduction`, applied to Combo cards with a minimum cost of 1 AP;
- `combo_duration_bonus`, added when each new timed stack is created.

Focus Amulet currently provides `-1 Combo AP` and `+0.5 seconds`. Combo effects and
the global Combo Chain are capped at three seconds. Countdown uses real time even
during tactical slowdown, so slowdown cannot extend the window.

### Card tempo and AP flow

Base AP regeneration is `0.95 AP/second`. Low-cost Combo and Healing cards build
a separate six-second card-tempo window so sustained play accelerates the hand
without making high-impact cards self-sustaining:

- a catalog-cost 1 card adds two tempo stacks and immediately refunds `0.35 AP`;
- a catalog-cost 2 card adds one tempo stack and immediately refunds `0.15 AP`;
- tempo is capped at eight stacks and each stack adds `0.12 AP/second`;
- a catalog-cost 3 power card grants no refund and consumes four tempo stacks;
- a catalog-cost 4 or higher power card grants no refund and clears all tempo.

Catalog cost is authoritative for tempo classification. Equipment discounts
still reduce the AP paid, but cannot turn a power card into a tempo-building
card. Playing another low-cost card refreshes the six-second window; letting the
window expire clears every tempo stack.

### Stable AP flow card

`Energy Cycle` is a one-cost Combo card that restores two AP. It is marked
`growth_locked`, always displays `STABLE`, and cannot be offered for an
individual upgrade or any fusion. Its AP amount grows horizontally instead:
each Memory Library level adds one AP and Apprentice Staff adds two AP.

Deck drawing prevents a four-card brick hand when any one-cost or stable flow
card remains in the draw/discard cycle. Wave rewards always include low-cost
choices, and the default expedition deck is twelve cards instead of starting at
the sixteen-card capacity.

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
- [ ] Backpack 維持 1–16 張普通卡，auto attack 獨立且 Run 內鎖定。
- [ ] Hand、draw、discard 與 overflow 的 instance identity 一致。
- [ ] AP cost、regen 與 redraw 行為有測試。
- [ ] XP 跨級 queue 與 CardGrowth upgrade/fusion/fallback 有測試。
- [ ] Combo status cards、passive attack skill、fusion 各自有明確 contract。
- [ ] Equipment 實際 consumer 與文件一致。
- [ ] Campfire／Merchant 的 UI 可到達行為與文件一致。
- [ ] Run result、Meta save、quick save 的能力沒有誇大。
- [ ] 相關 roadmap item 與測試結果已更新。

## 20. Known TODO

以下均為目前證據確認的缺口：

- [ ] Guardian victory 後處理剩餘 gem 與 support enemy。
- [ ] 決定並驗證 `autumn_route_cleared` 重入行為。
- [ ] 讓 Boss 獎勵在定義的持久化時點可靠落盤。
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

## 23. Systematic Combo and Mobility Contract

Combat support cards use `combo_family` as a stable gameplay taxonomy:

- `offense`: damage, attack frequency, travel speed, critical chance, reach,
  and attack size.
- `body`: defense, movement speed, AP regeneration, and maximum AP.
- `element`: fire damage over time, frost slow, lightning stun, and poison
  damage over time.
- `healing`: immediate healing, lifesteal, and regeneration.

Infusion copies stack for their duration and are projected from the run's
temporary effects into attacks, player movement/defense, and DeckManager AP.
Runtime caps prevent unlimited copies from breaking movement or AP economy.

Space Dash is an intrinsic evasive action, not a hand card. It travels over a
short duration, collides with terrain, phases through enemy bodies, is
invulnerable during travel, and retains a post-dash evasion window. Up performs
jump; jump start has a short evasion window. Defeating the progression guardian
unlocks one air jump and continues to enable equipment-based Dash evolution.

### Modal pause authority

`Game` remains `PROCESS_MODE_ALWAYS` so it can route menu input while paused,
but `MapRoot` and `CardEffectRunner` are explicitly `PROCESS_MODE_PAUSABLE`.
Any UI registered with `pause_game = true` pauses the SceneTree before its
`open()` method runs. This contract applies to ESC PauseMenu, card upgrades,
new-card rewards, full-deck replacement, discard, and other combat modals.
Closing the final pausing modal resumes world processing.

### Post-upgrade synthesis and combat readability

When an individual upgrade creates or leaves at least two distinct non-fixed
Lv.3 card instances, growth immediately queues an optional fusion follow-up.
Authored recipes keep their unique results. Any otherwise unmatched Lv.3 pair
can synthesize `Ascendant Combo`, a Lv.1 legendary Combo that combines attack,
body, AP, lifesteal, and elemental bonuses. Skipping preserves both materials.

Every enemy damage event must match a visible warning. Standard enemies and
legacy Autumn Slimes show their attack reach throughout wind-up and a separate
impact flash. Leaving the displayed side or hazard area avoids the hit.
Guardian root, falling-acorn, and radial patterns use directional, targeted, or
radial warning geometry respectively.

Automatic-attack feedback receives a visual profile from all active Combo
infusions. Flame, Frost, Storm, Venom, and lifesteal add distinct colored
layers. Repeated Combo stacks add orbiting particles and scale the projectile
and impact rings, so visual intensity grows with the actual stacked effects.

## 24. Autumn Battle V2 Presentation Contract

Autumn Battle V2 reserves the upper 66% of the viewport for world play. The
remaining space contains the combat dock and footer rail. The camera extends its
bottom limit by 90 pixels so the authored world composition moves upward instead
of being pinned by the original 720-pixel limit. The dock presents character
status, decimal regenerating AP, the single four-card Combo/Healing hand, discard
guidance, a persistent per-skill Combo Chain list, and transient recent-skill feedback.

Q/W/E/R play the single four-card Combo/Healing hand. Played cards refill immediately. T discards and refills the hand
without an AP requirement. A/S and LT/RT do not switch groups. Auto attack
does not occupy a HUD card slot. Intrinsic Space Dash also has no card slot or
AP presentation; `quickstep` is not part of the card catalog.

Autumn interactions use a compact F prompt attached to the current world
object. It follows the object and clamps above the HUD boundary so merchants,
caches, portals, and events do not create a second competing bottom overlay.
Combo 的攻擊提高採每三層一階：每階增加當前基礎攻擊 amount 的 35%，最低 +4。
每階同時增加 45 像素射程與 25% 視覺尺寸；目標數逐階增加，且每兩階增加
一次命中，最高可同時攻擊 8 個目標、每個目標 4 hit。

### Horde-first difficulty

Autumn survival uses enemy density and mixed roles instead of weakening the
player. Concurrent caps grow `14 → 22 → 32 → 44`, spawn batches grow from two
to four, and the boss stage maintains up to thirty supporting enemies. Amber
Moth Swarm adds fragile high-speed pressure while Grove Shaman adds long-range
support, bringing the phase pools to seven archetypes.
自動普攻命中時以世界空間短彈道、命中環、實際傷害數字與 `COMBO ×N / POWER +N`
直接呈現本次強化，讓玩家不必只靠 HUD 判斷是否生效。
