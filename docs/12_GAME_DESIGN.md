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
  → 從建築地基開啟材料行、主角鐵匠鋪、村長家、劍魂商服務
  → 進入 Autumn 安全區，在營火休息或向旅商購物
  → 從安全區右側進入 Autumn battle portal
  → Deck Builder 選擇 1–16 張普通遠征牌與一個獨立 auto attack
  → 開始 Autumn Run
  → 四個限時生存階段
  → Guardian 階段
  → Guardian 死亡
  → 從戰鬥區任一端 portal 返回安全區並結算
  → Run Result
  → 回到 Town／進入下一個 layout
```

### 2.2 Run 的開始

進入 Town/hub 的 Autumn portal 只載入安全區。與安全區右側 battle portal 互動時：

1. 先開啟 Deck Builder；
2. 技能配置正規化為剛好一張 Healing 與三張不重複 Combo；
3. 從已解鎖 attack cards 選一個獨立 Basic Attack；
4. 建立新的 `RunState`；
5. Basic Attack ID 鎖定為本 Run 的選擇，戰鬥中不可切換；
6. 建立四張可重複使用的固定手牌與空的 Divine Gift inventory；
7. 載入 `scenes/maps/autumn_battle/AutumnBattleMapV2.tscn`。

### 2.3 Run 的結束

目前有三種可觀察結果：

| 情況 | Runtime 行為 |
|---|---|
| Guardian 後由任一端返回安全區 | 以勝利結束 Run並套用獎勵 |
| Guardian 前由任一端返回安全區 | 以非勝利撤退，保留已記錄的 Run 獎勵 |
| 玩家生命歸零 | 短暫延遲後以非勝利結束並返回 Town |

Guardian 死亡本身不是最終結算點；玩家回到安全區時才完成結算。

## 3. 世界、地圖與導航

### 3.1 Authoritative scenes

| 區域 | Authoritative scene | 現況 |
|---|---|---|
| Game entry | `res://scenes/game/game.tscn` | 已實作 |
| Town | `res://scenes/maps/town/TownMap.tscn` | Hub gameplay |
| Autumn Safe Zone | `res://scenes/maps/autumn_safe/AutumnSafeZoneMap.tscn` | 營火、旅商與出入口 |
| Autumn | `res://scenes/maps/autumn_battle/AutumnBattleMapV2.tscn` | 完整 survival vertical slice |
| Crystal Caves | `res://scenes/maps/layouts/CrystalCavesLayout.tscn` | Layout only |
| Forbidden Graveyard | `res://scenes/maps/layouts/ForbiddenGraveyardLayout.tscn` | Layout only |

舊路徑由 `Game` 正規化到 authoritative scene。新增文件或測試時應引用 authoritative path。

### 3.2 Town

Town 是起始 Hub，現有內容包括：

- Player、地形與碰撞；
- 祭司／Mayor placement、六位常駐居民與 farmer／minstrel 兩位通行 visitor；祭司會從
  Town Hall 前往女巫身旁聊天再回到原點，visitor 則由城鎮一側進入、與居民短聊後由
  另一側離開；
- Material Yard、Player Blacksmith、Town Hall 專用建築 UI；
- Town 商品買賣；
- Autumn、Crystal Caves、Forbidden Graveyard portal；
- Town 內部的入口／尾端 fast travel。

Town 可直接進入 Crystal Caves 與 Forbidden Graveyard，因此 Autumn Guardian 的 forward portal 目前不是全域世界進度鎖。

### 3.3 Autumn

Autumn 場景包含：

- 1,280px 單畫面安全區，左側回 Town、右側進戰鬥；
- 安全區營火與不阻擋路線的兜帽旅商；
- 10,560px 戰鬥區，由 24 個 440px chunks 組合；
- 每次進入依 seed 改變宏觀地形區段與 optional one-way platform groups；
- 可重複延伸的 panorama／rear-tree 背景；
- 戰鬥區兩端皆可回安全區；
- `AutumnRunDirector`、一般敵人與 Guardian。

地形依序組合低地、中台、高台、平原與短 transition chunks；相鄰 transition
不得超過兩個，避免形成連續鋸齒階梯。One-way platforms 以 1–2 chunks 群組與
1–2 chunks 空白交替。站在單向平台時按 ↓ 可向下穿越，continuous floor 永遠
不可穿越。

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
- 敵人追擊以玩家相對位置選擇走或跳：同層一般敵人持續步行，Leap archetype
  只在同層有撲擊距離或玩家位於可達上方平台時跳躍；所有地面敵人落地後都有
  短暫步行判斷期，不會在玩家未換位時連續原地彈跳；
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

Autumn encounter 的 engage radius 為 720，leash radius 為 980。長路線以最近存活
enemy 計算 engagement；敵人在玩家前後 720–1040px 的視野外 perimeter、且不超出
route bounds 的位置生成。距離玩家超過 1500px 的一般怪會回收到新的 perimeter
位置。玩家離開外圈後開始六秒警告：

- 在倒數結束前返回會取消重置；
- 倒數結束時，存活敵人恢復生命、位置與狀態；
- 這是 encounter reset，不是 Run 結算。

## 5. 秋季生存關卡與 Guardian

### 5.1 生存倒數

`SurvivalWaveDirector` 使用單一 600 秒倒數，不再公開或依賴 survival phase。
普通敵人的 alive cap 由 30 連續提高到 120，spawn batch 由 5 提高到 12，
spawn interval 由 0.55 秒連續縮短到 0.12 秒。Enemy role 依經過時間逐步加入
pool，但 HUD 只投影剩餘時間、威脅數與 Final Rush，不顯示隱藏的 unlock threshold。

| 經過時間 | 排程事件 |
|---:|---|
| 45 秒起、每 45 秒至 495 秒 | 各生成一隻 Crimson Grove Elite；擊殺後取得 Divine Gift |
| 300、480 秒 | 生成一隻不負責結算的 Heartwood Harbinger |
| 剩餘 60 秒 | 進入 Final Rush，立即追加 Elite 與 Harbinger |
| Final Rush | 每 15 秒追加 Elite；每 30 秒追加 Harbinger |
| 00:00 | 停止一般排程並生成唯一 completion Guardian |

Final Rush 額外增加 40 alive cap、縮短普通 spawn interval 並提高 batch。
中途 Boss 與 Final Rush Boss 死亡不會提前結算；只有帶
`completion_boss` metadata 的 00:00 Guardian 死亡會完成關卡。

### 5.2 敵人行為

目前 archetype 可表現：

- 近戰追擊，並以 64 像素鄰域 separation steering 展開前後排，不疊在單一座標；
- leap；
- ranged；
- charge；
- elite 行為；
- 追擊高處玩家時主動跳上 one-way platform；
- 撞牆或水平停滯時自動跳躍脫困；
- slow、stun、burn 狀態。

每隻一般敵人死亡至少會產生 2 顆實體 `ExperienceGem`；原本 2–3 XP 的獎勵
拆成等量 1 XP 小寶石，Elite／Boss 則拆成最多 12 顆。
Gem 生成時先向外短暫散射並落回地面，讓範圍技清場直接形成可見的經驗雨；
之後只在 72 像素內吸引玩家、30 像素內收集，移動速度由 180 加速至 520。
大量低價 Gem 的總和才是 Run 經驗成長來源，不得改回少量高價獎勵。
寶石使用高前景層級、青色背光與脈衝亮點，必須能在怪海和秋季地景上清楚辨識。
每次敵人受擊都要在敵人本體上顯示白閃、壓縮回彈與傷害飄字；致死攻擊改為
金色粒子爆散及快速放大淡出，讓範圍清場能逐隻回報命中與擊殺。
每隻 Elite 死亡都會遞增獨立 reward event，並開啟一次 Divine Gift 選擇；
同一倒數內的後續 Elite 不會再被舊 wave／stage key 誤判成重複獎勵。
六種普通敵人維持 4–16 HP、零防禦的 horde contract；未升級的 16 傷
Ember Bolt 就能一擊擊殺任何普通怪，所有範圍攻擊也能直接掃除普通怪群。
Elite 維持 85 HP，基礎大招不能單次擊殺；Guardian 仍是獨立耐久關卡。

普通敵人死亡時有 16% 機率生成 `SurvivalPickup`，掉落採單一權威權重表：

| 掉落 | 掉落池權重 | 效果 |
|---|---:|---|
| Healing Fruit | 45% | 立即恢復 35 HP |
| Experience Magnet | 25% | 立即收集場上所有 ExperienceGem |
| Swift Fruit | 30% | 10 秒內移動速度提高 40% |

Pickup 在 180 像素內會追蹤玩家，未拾取時 18 秒後消失；Elite、Harbinger 與
completion Guardian 不進普通掉落擲骰，保留各自既有獎勵責任。

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

- fixed loadout 必須剛好 4 張：1 Healing 與 3 張不重複 Combo；
- 傳送門前直接顯示 Healing、Combo 1、Combo 2、Combo 3 四格；點格後只列出合法類型；
- 配置畫面即時列出目前三張 Combo 可完成的已學會終結技；
- Basic Attack 在固定技能之外獨立選擇，必須是已解鎖的 `attack` card；
- 固定技能整個 Run 不抽換、不輪巡；
- Meta 預設解鎖 20 張卡；
- `MetaState` 分別保存 selected deck 與 `auto_attack_card_id`。

### 6.3 牌堆與手牌

`DeckManager.start_fixed_hand()` 保存四個 `CardInstance` slot。Q/W/E/R 使用後，
同一 instance 留在原 slot；production 戰鬥不使用 draw、discard、exhaust、
cooldown、redraw 或 overflow。舊 pile API 只保留資料相容性，不是目前 gameplay。

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

卡片 cost 大於目前 AP 時不能打出。成功打出後扣除 cost、執行 effect，卡片留在
原 slot。Basic Attack 永遠免費，不使用 AP/hand 流程。

### 6.5 Fixed-hand invariant

- 四個 slot 在 Run 期間不變；
- exactly one Healing、three unique Combo；
- 沒有 redraw、discard、replacement、overflow 或 Auto Use；
- Basic Attack 不在 hand。

### 6.6 Card focus 與施法節奏

Card focus 會把 `Engine.time_scale` 設為 0.22。成功出牌後先結束 focus，再由
`SkillCastPresentation` 以 unscaled time 顯示放大招式名稱與短暫慢動作；連續施放
使用 generation 防止舊 callback 覆寫，離開 SceneTree 時恢復進入前倍率。普通
Basic Attack 不反覆顯示名稱；只有實際造成傷害且沒有施法演出時才使用短 hit stop。

## 7. Combo、Skill 與 Fusion

### 7.1 Combo cards

`combo` 是固定技能類型。每次使用會永久增加公式用 stack，但該卡提供的 attack
infusion／status 各自只有 1.5 秒基礎持續時間，且彼此獨立倒數。某一效果到期時
只移除自己的修正並立即以剩餘效果重建攻擊 profile；例如 Giant Arc 到期後尺寸
回到正常，仍在倒數的 Quickened Cadence 繼續保留攻速。攻擊次數不會消耗這些
效果。只有 Combo 會進入三格公式；Healing 不進入也不會中斷。三招必須精確
匹配已學會的 AAA 或有順序 ABC 配方，才會排入對應終結技；不再以任意三招
產生同一招式。效果組成為：

```text
recipe Finisher base + matched three-Combo combination + every Divine Gift effect
```

完成的終結技以 FIFO queue 保留，下一發自動水平 Basic Attack 逐一施放。施放後
只移除 queue 第一招，不消耗永久 Combo stacks。

通用 Combo infusion 包含攻擊範圍（Sweeping Reach）、攻擊速度
（Quickened Cadence）、攻擊力（Crushing Momentum）、爆擊率／倍率
（Keen Focus）、彈體數量與展開角度（Echo Volley）與雷屬性硬直
（Storm Charge）；Flame／Frost infusion
則繼續提供火焰與冰霜附加屬性，並讓後續 projectile 分別帶火舌／火星或霜晶／
冷霧纏繞；雙元素可同時顯示。這些卡都只消耗 AP，不使用 card cooldown。
Combo chain 到 3／6／9 時，projectile presentation 分別加入環繞刃光、雙重殘影
與爆發星芒；這些層級只改視覺，不額外建立隱藏傷害。
沒有 Echo Volley 時，Basic Attack 固定為單方向、單發、單目標基本型態。
Echo Volley 增加同一輪的彈體數與可命中目標數，但所有彈體仍沿角色面向的水平
戰鬥走廊前進。攻擊不向最近敵人重新瞄準，也不在飛行途中追蹤；走廊外與角色
背後的敵人不受傷。有合法水平目標時自動射擊；沒有目標時不消耗 cooldown、
公式或已排隊的終結技。

### 7.2 Divine Gifts

每個 stage/wave 的首次菁英擊殺掉落一次必選神賜頁。神賜是 Run-local；最新取得
者是主神賜並為原招式附上稱號，例如 `千刃殺` 變成 `絕對零度的千刃殺`，所有
持有神賜共同提供 mechanics，因此所有不同神賜欄位直接相加、倍率直接相乘，
公式固定為「全部神賜效果＋終結技效果＋前三招 Combo 組合效果」。相同神賜重複
取得時升級，最高 Lv.3；兩個不同 Lv.3 神賜可融合為 evolved gift。融合後保留
兩個材料的部分數值與 mechanics，另依 Lv.1–3 逐步加入 `final_burst`、
`chain_lightning`、`death_spread`、額外 echo、範圍與元素傷害。Evolved gift
會回到後續神賜池繼續由 Lv.1 升至 Lv.3，名稱依序轉為 Awakened／Transcendent，
並使用元素組合專屬名稱與 accent color。融合材料 ascended 後不再進獎勵池，
同一融合不能反覆發生；fusion-only 頁可略過，因此不會形成無限 modal loop。

正式元素只有 water／fire／wind／lightning／ice／poison／light／dark／normal，
由 `ElementTaxonomy` 統一命名。每個 base 神賜保留一個 canonical `element`；
融合神賜同時保留兩個材料的 canonical `elements`，不會把屬性改名成
`evolved`。Flame、Storm、Frost、Venom 等舊稱只作輸入相容 alias。

### 7.3 Passive attack Skill

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

五個 Combo Finisher 與四個 named trigger 不共用同一 motion 模板。九招分別具有
獨立 archetype 與 3–5 段 beat pattern；Skill 的 Lv.1／2／3 會依
`evolution_layers` 定義逐步增加新部件的身份，永久 Combo／Buff 疊層則依各招
`stack_milestones` 增加結構層，並保留對齊的 `stack_traits` 成長語彙。Runtime 將實際
`evolution_level` 與最強相關 `buff_stacks` 傳給演出，因此成長會改變剪影、
路徑或節拍，而不只是整體縮放與亮度。

### 7.4 火／冰範圍技能

`Crimson Caldera`（stable ID `concussive_shout`）以玩家為中心在 420px 半徑造成大範圍火焰傷害
與 Burn，使用多圈火浪、焦土、火柱和火星。`Glacial Dominion`（stable ID
`frost_bind`）從玩家向外擴散 460px 結冰領域，對範圍內多個敵人施加 Slow，使用冰環、裂紋、
冰晶和冷霧。VFX 半徑取自同一 card effect radius，但不自行判定傷害。

範圍大招另沿玩家面向留下可拼裝地面路徑：火系是兩道弧形燃燒焦痕，冰系是一條
主凍裂加兩條分岔；毒系 profile 使用不規則毒灘，供對應大招或元素進化接入。
Core、Edge、Accent、Debris 四層各自顯現與消退，不能用一張整體火焰動畫換色。
慢動作只放慢角色與戰局，大招本體、地面路徑和致死展示以真實時間對齊。致死傷害、
掉落與碰撞立即結算，但 Fire／Ice 的敵人影像會分別保留到其衝擊點，再依元素色盤
進入 dissolve／burst，讓收尾與招式本體成為同一段動作。

### 7.5 Meta card upgrade 與 fusion

EXP growth 對個別 `CardInstance` 升級，最高 Lv.3；同 card ID 的兩張卡可有不同
level。fusion 必須明確選兩張不同的 Lv.3 instances，消耗兩張材料並建立一張
Lv.1 結果，牌組淨減一：

| Lv.3 material A | Lv.3 material B | Lv.1 result |
|---|---|---|
| Iron Will (`guard`) | Stone Form (`iron_skin`) | Unbreakable Stance (`fortress_stance`) |
| Dash Edge (`dash_strike`) | Cleave | Gale Drive (`gale_lunge`) |
| Glacial Dominion | Energy Surge | Time Snare |
| Healing Light | Blood Pact | Renewal |
| Battle Focus | Flame Aura | Overdrive |
| Cleave | Flame Aura | Inferno Orb |

舊「階段 2 自動注入 passive evolution、批次轉換所有同名卡」不再是 gameplay
contract。Dash Edge 與 Gale Drive 標記為 `combat_hand = false`，不再由牌組與
獎勵特別提供；其 legacy infusion 仍以
`target_action = dash` 暫時強化玩家固有 Dash，不指向或建立 Dash 卡。

### 7.6 效果語意限制

目前 effect runner 支援 damage、area damage、block、heal、dash、status、power、aura、summon、overdrive 與 infusion。

必須依程式實際語意描述：

- damage aura 目前是一次性 area hit；
- attack-power／overdrive 沒有可見的 duration 到期回復流程；
- 不得把一次性效果寫成持續 tick，除非 runtime 已新增並驗證。

## 8. 經驗值、升級與 Run 成長

### 8.1 Experience

一般敵人死亡產生 ExperienceGem。收集後呼叫 `RunState.add_experience()`；經驗只記錄
Run 進度，不再於戰鬥中開啟卡牌升級頁。

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

Autumn combat HUD 必須持續顯示目前 XP、下一級門檻與 `NEXT` 尚缺數量。收集 XP
時以短暫青色脈衝回饋，升級時以金色脈衝突出新等級；這些 presentation 不改變
`RunState` 的門檻計算或 level-up queue。

### 8.2 In-run choices

一般 EXP 與 wave 開始不提供新卡、卡牌升級或卡牌融合。唯一的戰鬥內 build
成長是菁英掉落的 Divine Gift。`CardGrowthUI` 只重用 modal 外殼，神賜頁以
icon、短名稱、等級與最多三點效果呈現；可融合時同頁列出合法 evolved gift。

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

每把 weapon 另有一個 canonical `primal_element`，目前 Iron Sword／Hunter Bow／
Apprentice Staff 分別為 normal／wind／water。InventoryManager 驗證其屬於正式
九元素並可投影目前裝備武器的原初屬性；目前沒有證據表示此欄位會自行轉換傷害，
因此不得把武器身份資料描述成額外 elemental damage。

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

目前五個 building ID：

- blacksmith；
- workshop；
- market；
- town hall；
- memory library。

除 memory library 有四級外，其餘建築最多三級。Village stage 的
total-building-level threshold 為 0、3、7。Town 六棟建築的互動範圍皆覆蓋各自
完整地基；材料行、主角鐵匠鋪、村長家、劍魂圖紙商與裝備圖紙商提供服務，
最東側民宅只顯示住宅資訊。NPC 不觸發這些建築 UI。

功能建築 UI 的玩家可見責任：

- Material Yard：以 gold 購買鍛造材料 bundle 與永久工具；高階 stock 隨 Eternal
  Torch 對應的 village stage 解鎖。
- Player Blacksmith：依已購圖紙鍛造 equipment／Sword Soul、升級 blacksmith
  解鎖 recipe Tier、升級 Sword Soul，並將 crafted equipment 放到單格販售桌，
  顧客結帳後顯示 `+GOLD`。
- Town Hall：查看 village stage、總建築等級、資源與 Town Hall 升級成本。
- Sword Soul Shop／Equipment Blueprint Shop：buy-only 圖紙 catalog；持有後不能
  重複購買，實際成品只能回玩家工坊鍛造。

舊通用 Town progression UI 已退役；三個 dedicated screen 關閉時由 Game
同步 Meta save、Town visual 與 equipment stats。

目前場景只直接改變 ItemShop、EmptyResidence、EmptyTowerHouse 與 Blacksmith 的部分視覺。Manager 產生的其他 visual flag 尚未完整投影，不得宣稱所有升級都有對應外觀。

Town presentation 維持 `1942 × 720` gameplay world 與單一中央不滅火炬；
核准的 Base 分件組圖已取代 Image #2 完整構圖成為 runtime presentation。
`data/town_modular_layout.json` 以 `1942 × 809` source canvas 定義可替換物件，
並生成 visible 的 `TownModularVisuals.tscn` 供 runtime、Figma 與
Scene editor 共用。地點由左至右仍為材料行、
主角鐵匠鋪、不滅火炬、戰鬥傳送門、村長家、劍魂商、裝備圖紙商與東郊民宅。
NPC、建築入口、Portal、碰撞與
progression 仍是獨立 scene authority。替換房屋、地板、火炬或街道 props
只改變 presentation，不代表新增服務、互動或玩法。
所有 Town 分件採 `storybook_handdrawn_pixel_v2`：低飽和苔綠、木褐、砂岩與
陶瓦為主色，冷苔炭色作環境陰影、暖蜜色作左上主光，藍紫魔法只保留為局部功能
焦點。背景依 locked A 排版拆成可獨立調色的 cloud-free 天空、八個持續錯速進出畫面的
透明手繪雲物件、透明群山、繁盛的中景秋林、西側粗像素
破敗石塔、橫向綠色灌木殘骸帶、右緣針葉樹殘牆群，以及中央秋樹；三個 ruins
layers 只補邊界、貼地與前景建築後方的淺色空隙，並保持在最大秋樹後方；
不滅火炬和藍紫旋渦門保留功能辨識度；兩者都使用 refined Base v5 靜態塔身。
非魔法表面共用材料行的大型不規則石塊、粗斷線、有限明暗與
中性光照；Base v5 不滅火炬以約 4× source-to-display pixel density 對齊鄰近
Base 建築的石材、銅件與木旗精細度，並與連續石橋獨立疊放。其靜態 Base 不含
頂部火焰及中央符文光；`TownEternalFlameAnimation.tscn` 的 `FireLayers`
以火盆接觸線為縮放軸，使用三個相位錯開的 8 幀、4.5 FPS 火焰層，形成外焰、亮芯
與柔和餘光；同源 `BrazierFrontOccluder` 重畫火盆前緣，使火根保持在盆腔內，
不可用移動火焰高度代替正確圖層。`RuneCharge` 使用 8 幀、4 FPS 的自動循環充能發光，並由 2 秒連續
`RunePulse` 補足幀間亮度與縮放變化。火焰獨立分件是後續放大或換色的
presentation 邊界；兩組不得重新烘焙進 Base，也不改變 Eternal Torch 的
village-stage progression。傳送門 Base v5 不含門洞旋渦、紫色內緣光或頂部
晶石 emission；`TownBattlePortalAnimation.tscn` 以精確門洞遮罩疊加完整
暗紫 underpaint 與兩組
12 幀手繪逐格主旋渦／次光，兩層以 6 FPS 播放 2 秒 loop 並保留相位差；
符文呼吸只改變 presentation，不改變 `BattleGateway` 的 interaction、
collision 或 hub route。`TownBuildingAnimation.tscn` 為六棟 Base 建築補上局部
生活感：十一組實際可見窗格持續亮著，只以錯相低幅暖光微閃；鐵匠爐使用八幀手繪火焰
與拱室內暖光；布料自由端只移動 1px；Town Hall 秒針使用整數像素步進；劍魂商
劍徽反光使用透明手繪逐格素材，圖紙商齒輪固定顯示手繪中性幀且不旋轉。這些效果不得改動建築輪廓、覆蓋
NPC、照亮牆面或建立新的互動權威。`TownAmbientAnimation.tscn` 以完整古樹的偶發徐風、
八組上冠／外冠／前後景樹冠、四組根部藏在屋後的局部枝葉、二十四個單向落地
單葉、三個可淡出的低矮路緣小堆及十六個鳥停棲點補足
悠閒城鎮氛圍。完整古樹保持固定，八組獨立樹冠模組平時已有不同步的低幅擺動
與稀疏抖葉，覆蓋可見上冠、左右外冠、中冠與前後冠；陣風中才從枝根增加順風擺幅；
中央樹以外另有十組藏在屋頂後方的局部秋林區域，每區以後、中、前三層無樹幹
實色 patch 疊在低解析度固定秋林後方；固定秋林遮住葉團底部，只讓不同深度與
擺幅的葉梢越過原冠線，使動畫讀成樹梢葉面的局部微動。葉團各自迎風晃動，
但原始秋林底圖與整棵樹
保持固定，不做水波、整片位移或完整小樹旋轉；
落葉由中央／屋後樹冠出生，分別抵達街道、屋頂或建築平台後停留再淡出；路緣
小堆以暗褐底與橘紅高光逐漸消失。鳥以十四個屋頂／石座與兩個地面位置跨西塔、
forge、portal、clockhouse 分散，長時間左右待機／啄食，只有 Player 靠近或
自然等待結束才起飛並稍後返回；所有環境動畫都不提供傷害、掉落、互動、碰撞
或 progression。道路視覺
頂緣為 `y=660`，與不變的 `y=672` gameplay baseline 重疊 12 px，讓角色腳部及
建築地基確實貼地。不使用暖色整張城鎮圖作底層。六棟前景建築使用材料行
Base 的中性分件；東側四棟採 MaterialYard-style Base v3，以約 4×
source-to-display pixel density 保留相同細節密度並對齊 `y=672`。
Base 只保留結構 AO，
日照與大面光影留給 Godot 疊加層。六棟建築採核准 B2 筆觸並共用正面＋右側窄面的
正交偽三分之四視角。候選市場攤、生活器具、花木與路面痕跡全部使用
B2，只提升街景熱鬧程度，不新增交易、NPC、碰撞或互動規則；舊 modular-v1
街具、浮空旗幟，以及遮住東側建築立面的六個大型 dressing 不顯示。
六棟建築名稱木牌位於各自最高輪廓上方，預設隱藏；Player 走進該建築完整地基
範圍時只顯示目前建築，離開後立刻回到無木牌狀態。NPC 經過不觸發。

Town 九個 display-only NPC placement 使用各自 world texture identity；六位 residents 與
兩位 visitors 的 atlas 都有 idle、walk、sit、chat、laugh、happy、sad、surprised、angry、
idle_look、idle_stretch、greet、work 共 13 個 presentation states。八位角色的 row 4–8
使用各自 authored emotion strips，人物統一 132 px、腳底 `y=144`；runtime 不額外縮放、
bob 或旋轉情緒幀。女巫 directional source 原生朝左，移動時依 requested facing 正確翻面。
祭司以 `y=672`／`z_index=0` 固定路線走到女巫左側 95 px，祭司朝右、女巫朝左聊天後再沿
同一 baseline 回 Town Hall；舊的前景繞行不再使用。其餘六位居民會在各自店面／街區附近
待機、表達情緒、做符合身份的悠閒工作、坐下休息或短距離散步；社交時先保留 partner、
走到 catalog 指定距離，
依序打招呼、聊天／談工作、產生情緒反應、道別，再回到精確 home。初次見面偏好 greet；
熟人可依角色選擇 discuss_work，golden hour 可一起 watch_sky。familiarity 與 cooldown 都是
session-local，不形成持久 schedule。散步區域依相鄰 home anchor 切開，至少保留一個人物
寬度，避免同基準線互相穿入。

`town_npc_interactions.json` 提供九種悠閒小鎮 presentation interaction：greet、chat、laugh、
gossip、comfort、share_goods、discuss_work、watch_sky、farewell。Catalog 只決定合法候選與
雙方動畫 sequence；實際 partner、movement、external lock、relationship count 與 completion
仍由居民 life controller 擁有。farmer／minstrel visitor 各自從相反方向進鎮，在 authored
stop 優先找指定居民 greet／chat，之後穿越整個小鎮離開並等待下一輪；visitor 不成為商店、
建築或居民社交 authority。這些行為只營造活城鎮，
不擁有 NavMesh、持久 schedule、gameplay dialogue 或建築互動。Autumn safe-zone seated merchant 與 compatibility
Merchant 也已換成新 atlas hierarchy，仍保留原商店互動。服務 UI 的人物框同步換成這批角色的動態
半身像。Town root 提供 day／golden-hour 光色同步 API；golden hour 在 normalized
progress 0.65 後才開始，會一起調整天空、雲、場景物件、NPC、Portal 與 Player，
但目前沒有自動時鐘，實際時間推進仍由未來 gameplay owner 決定。

Town 不再直接排列各戰區傳送門，也不保留東西 fast travel。唯一的
`BattleGateway` 進入 `battle_portal_hub.tscn`：大廳左右各兩個戰區入口，中央
保留未來尾王 Portal 空位。Autumn、Crystal Caves、Forbidden Graveyard 已接線；
第四戰區入口目前可見但鎖定，因為第四張正式戰鬥 map 尚未存在。

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

### 10.2 Autumn survival route

秋林戰鬥 route 不放置固定商人、寶箱或捷徑開關。既有存檔中的
`forest_gate` 相容旗標仍可讀取，但不再改變新 route 的出生點。

地板輪廓與平台組件由獨立 catalog 拼裝；每次進場 seed 不同，但所有 chunk 接縫
保持連續。Generator 先規劃低、中、高地與平原區段，只在高度區段交界使用短坡，
並限制浮空平台群組長度。怪物從玩家視野外持續補入，遠離玩家的一般怪會回收到新
視野外位置，避免舊怪占滿密度預算。

階段只依累積存活秒數推進，擊殺數與場上存活數不參與階段判斷。`density_cap`
只用於效能與畫面密度控制；最終 Guardian 擊敗後才完成戰鬥。

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
- survival countdown 與 living enemies；
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
| Basic Attack | 自動；依角色面向的水平走廊 |
| Interact | F |
| Inventory | I |
| Pause | Escape |
| Dash | Space／右肩鍵 |
| Card focus | Tab／左肩鍵 |
| Card slots | Q/W/E/R／手把 face buttons |
| Combo hand | Q/W/E/R／手把 face buttons |

S／↓ 不負責攻擊；`card_group_1` 與 `card_group_2` InputMap actions 已移除。

### 12.2 HUD

現有 HUD／Card Hand 提供：

- health、mana 與玩家資訊；
- 區域、目標、`MM:SS` survival countdown 與 Final Rush 狀態；
- enemy alive/cap；
- 目前／門檻／距離下一級的 XP bar；
- AP；
- 單組四張 Combo／Healing 手牌；每張以大型 semantic icon、招式名與
  Healing／Flame／Volley／Storm 色族協助即時辨識；
- 持續顯示總層數、剩餘時間與技能分項的 Combo Chain 清單；
- Guardian health；
- interaction prompt；
- Run Result、Level Up、Discard、Deck Builder modal。

UI 顯示不得宣告 backend 尚未提供的能力。
HP loss、AP recovery、XP gain 與 level gain 可使用短暫 scale/color emphasis，
但必須回到穩定排版，不能使 `BottomStage` 越過 66% gameplay boundary。

## 13. Scene Tree Example

以下是目前 runtime ownership 的簡化樹，不是建議新場景：

```text
Game (Node)                         scenes/game/game.tscn
├── MapRoot (Node)
│   └── AutumnBattleMapV2 (Node2D)  runtime instance
│       ├── PlayerSpawn (Marker2D)
│       ├── Player (CharacterBody2D)
│       ├── GeneratedBackdrop (Node2D)
│       ├── GeneratedRoute (Node2D)
│       │   └── RouteChunk00..23
│       ├── AutumnRunDirector (Node2D)
│       ├── WestSafePortal
│       └── EastSafePortal
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
	if not director.survival_time_changed.is_connected(
		_on_survival_time_changed
	):
		director.survival_time_changed.connect(
			_on_survival_time_changed
		)

	if not director.boss_stage_completed.is_connected(
		_on_boss_stage_completed
	):
		director.boss_stage_completed.connect(
			_on_boss_stage_completed
		)


func _on_survival_time_changed(
	remaining: float,
	total: float,
	alive: int,
	cap: int,
	final_rush: bool
) -> void:
	hud.set_objective(
		"FINAL RUSH — SURVIVE" if final_rush else "SURVIVE UNTIL DAWN",
		"THREAT %d / %d" % [alive, cap]
	)
	hud.set_survival_timer(remaining, total, final_rush)
```

這是 Godot 4 signal 語法示例；實際專案由 `Game` 的既有 wiring method 管理連接。

### Basic Attack and Dash

Deck Builder 在戰前從已解鎖 attack cards 選一個 Basic Attack，與四張固定技能
分開保存。Run 開始時鎖定選擇；戰鬥中不可切換。Basic Attack：

- cost 固定為 0，不進 hand/draw/discard/exhaust/cooldown；
- 有合法水平目標時依 catalog interval 自動發射；
- 不建立出牌事件，因此不推進 `SkillRecipeManager` 的 count/sequence；
- 可使用所選 attack card 的有效 level/equipment projection；
- 固定沿玩家面向發射，傷害只判定在可見彈道的水平窄射線走廊內；
- 無效選擇 fallback 到已解鎖的有效 attack。

Dash 是玩家固有 action：↑ 只觸發 Jump，Space 觸發 Dash。Dash 不建立
`CardInstance`，不進 backpack/hand/draw/discard/exhaust/cooldown，也不花 AP 或
觸發 `SkillRecipeManager` 的 card sequence。`quickstep` 已從正式卡表移除。
Dash Edge/Gale Drive 是 `combat_hand = false` 的 legacy Combo cards，以 `target_action = dash` 在各自 effect
window 內暫時強化固有 Dash；Combo 本身不直接移動玩家。

The combat hand is one fixed four-card Combo/Healing row. Q/W/E/R reuse those cards.
Basic Attack fires automatically; there is no vertical attack or group-toggle input.
Playing a Combo or Healing card keeps normal gameplay speed and uses one compact
18px world-space label above the player instead of the centered cast title. Elemental
feedback remains active. Slow motion is reserved for triggered named skills,
elemental ultimates, and queued formula Finishers; a queued Finisher starts its
presentation only after a legal horizontal target confirms that the shot will fire.

### Persistent Combo formula and timed card effects

Combo cards remain in their slot after play. Formula history and stacks persist for the
entire Run, while each card's attack infusion or status has its own 1.5-second base
timer. Expiration removes only that card's modifiers, so later overlapping effects
continue normally. Healing does not enter or interrupt the formula. An exact learned
three-Combo recipe queues its named Finisher for a later automatic horizontal shot;
multiple Finishers resolve FIFO. The HUD shows formula slots, persistent stacks,
owned Divine Gifts, Gift-modified names, and the queued ready state.

`combo_cost_reduction` still applies with a minimum cost of 1 AP. Legacy
`combo_duration_bonus` extends both the separate 2.5-second Combo Chain window and
the 1.5-second card-effect timer, capped at 3.0 and 2.0 seconds respectively.

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

The fixed loadout and AP regeneration prevent a dead hand; Energy Cycle remains a
stable flow option, and Divine Gift rewards may add global AP refunds.

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

Q/W/E/R reuse the single fixed four-card Combo/Healing hand. Cards never rotate
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
player. The ten-minute countdown continuously grows concurrent caps `30 → 120`
and spawn batches `5 → 12`; Final Rush adds another 40 cap plus scheduled Elites and
Harbingers. Amber Moth Swarm adds fragile high-speed pressure while Grove
Shaman adds long-range support. Normal roles stay low-health and defense-free so
area ultimates erase a crowd at once. Elite is never part of the random normal pool.
自動普攻命中時以世界空間短彈道、命中環、實際傷害數字與 `COMBO ×N / POWER +N`
直接呈現本次強化，讓玩家不必只靠 HUD 判斷是否生效。
中性普通攻擊的主形狀是朝前方凸出的白青色 `)` 型空心月牙劍氣，由 core blade、
crescent edge、afterimage、shards 與 impact wedge 等 2D 部件拼裝。它在短蓄勢後
瞬間掠過大部分射程，命中月牙放大並在 `impact_reached` 時同步短 hit stop 與鏡頭
震動；premium atlas 另以非同步 outer glow／moon core／inner current、三重 flow
ribbon、地面切線與 contact bloom 補足流體分層，不能退化成整張貼圖平移。不得
表現成慢速飛彈。Flame/Frost/Storm/Venom 視覺層只能由對應 Combo
infusion 或 Finisher profile 額外套上，不得因 Basic Attack 卡片本身的元素 tag
成為預設外觀。
