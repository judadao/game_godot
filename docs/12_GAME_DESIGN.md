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
  → 在 battle portal hub 選擇 Autumn portal
  → Deck Builder 固定第 1 格治療，配置後 3 格劍魂與一個獨立 auto attack
  → 直接載入 Autumn battle route 並開始 Autumn Run
  → 四個限時生存階段
  → Guardian 階段
  → Guardian 死亡
  → 從戰鬥區任一端 portal 返回安全區並結算
  → Run Result
  → 回到 Town／進入下一個 layout
```

### 2.2 Run 的開始

與 Town/hub 的 Autumn portal 互動時直接開啟 Deck Builder，不先載入安全區：

1. 先開啟 Deck Builder；
2. 技能配置正規化為第 1 格固定 Healing、後 3 格為不重複公式劍魂；
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
| Crystal | `res://scenes/maps/expedition/CrystalRoute.tscn` | 完整 10,560px 遠征路線 |
| Hell | `res://scenes/maps/expedition/HellRoute.tscn` | 完整 10,560px 遠征路線 |
| Heaven | `res://scenes/maps/expedition/HeavenRoute.tscn` | 完整 10,560px 遠征路線 |
| Regional Boss | `res://scenes/maps/boss/RegionalBossArenaTemplate.tscn` | 1,664 × 900 垂直平台房 |

舊路徑由 `Game` 正規化到 authoritative scene。新增文件或測試時應引用 authoritative path。

### 3.2 Town

Town 是起始 Hub，現有內容包括：

- Player、地形與碰撞；
- 祭司／Mayor placement、六位常駐居民與 farmer／minstrel 兩位通行 visitor；祭司會從
  Town Hall 前往女巫身旁聊天再回到原點，visitor 則由城鎮一側進入、與居民短聊後由
  另一側離開；
- Material Yard、Player Blacksmith、Town Hall 專用建築 UI；
- Town 商品買賣；
- 單一 BattleGateway，通往四槽戰鬥傳送聖所；
- Town 內部的入口／尾端 fast travel。

戰鬥傳送聖所依 `story_state.chapter_id` 投影當前世界世代：

- Chapter 1–2：Autumn、Crystal。
- Hell chapter：Autumn 可選 normal／Hell Autumn，Crystal 可選 normal／Hell Crystal，
  並開放 Hell；舊戰場不會被替換。
- Heaven chapter：Autumn 與 Crystal 各可選 normal／Hell／Heaven，Hell 可選
  Hell／Disorder Hell，並開放 Heaven。

每次成功攻略會取得該精確變體的一片命名碎片；四片組成該變體 Boss 通道鑰匙，
中央 Boss 石門才會提供該 Boss 房。多把鑰匙可同時存在，以直接按鈕選擇，不會
互相阻塞或消耗。Boss 房不會由篇章自動載入；玩家必須靠近並觸發已解封的中央門。
路線與 Boss 嚴格採 Autumn 1 < Crystal 2 < Hell 3 < Heaven／Disorder 4；tier
會提高敵人生命、傷害、密度、spawn batch 與 material bag 倍率；已達到的最高 tier 同時提高鍛造商店
可見圖紙階級，因此裝備與劍魂招式供應會隨 Hell／Heaven 世代提升。
Boss 鑰匙完成後，其他世界仍繼續累積自己的通關、碎片與鑰匙；擊敗 Boss 只完成
並消耗所選變體的鑰匙。

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
enemy 計算 engagement；敵人在玩家前後 680–820px 的近鏡頭外 perimeter、且不超出
route bounds 的位置生成。距離玩家超過 1200px 的一般怪會回收到新的 perimeter
位置。玩家離開外圈後開始六秒警告：

- 在倒數結束前返回會取消重置；
- 倒數結束時，存活敵人恢復生命、位置與狀態；
- 這是 encounter reset，不是 Run 結算。

## 5. 秋季生存關卡與 Guardian

### 5.1 生存倒數

`SurvivalWaveDirector` 使用單一 510 秒（8:30）倒數，不再公開或依賴 survival phase。
開場先生成 30 隻普通敵人；alive cap 由 48 連續提高到 170，spawn batch 由 10 提高到 20，
spawn interval 由 0.35 秒連續縮短到 0.08 秒。普通怪死亡時會在 0.05 秒內排入補怪，Enemy role 依經過時間逐步加入
pool，但 HUD 只投影剩餘時間、威脅數與 Final Rush，不顯示隱藏的 unlock threshold。
普通怪的基礎生命倍率在開場為 10.0，依同一條生存時間軸平滑提高，於 8:30 達到
26.0；傷害倍率同時由 1.15 提高到 2.20。Moth 仍是相對脆弱怪，其餘角色即使面對前段 Combo／暴擊也有機會進入
畫面中段，並以連續命中與擊退形成交戰。

| 經過時間 | 排程事件 |
|---:|---|
| 每 60 秒（60–480 秒） | 生成輪替的 Thornling／Charger／Shaman 強敵群；群數隨時間增加 |
| 180、360 秒 | 生成輪替的 Harbinger／Thorn Colossus／Ember Warden；後段為複數 |
| 剩餘 30 秒 | HUD 倒數轉紅並立即追加複數強敵與 Boss |
| Final Rush | 每 7.5 秒追加強敵群；每 15 秒追加複數 Boss |
| 00:00 | 立即停止排程、解鎖出口並發放待結算的大量資源與寶箱 |

Final Rush 額外增加 50 alive cap、縮短普通 spawn interval 並提高 batch。
中途 Boss 與 Final Rush Boss 死亡不會提前結算；玩家只要撐到 00:00 即完成關卡，
不再追加一隻倒數外的 completion Guardian。

### 5.2 敵人行為

目前 archetype 可表現：

- 近戰追擊，並以 64 像素鄰域 separation steering 展開前後排，不疊在單一座標；
- leap；
- ranged；
- charge；
- elite 行為；
- 實體碰撞傷害為 archetype 攻擊力的 35%，沿用玩家防禦、格擋、無敵幀、擊退與反傷；
- 每隻怪有獨立 0.8 秒接觸冷卻；預警期間碰撞仍會受傷，但同一輪招式結算不再重複扣血；
- 普通怪未死亡時保留 0.16 秒短擊退，不會在下一幀立刻被追擊速度覆蓋；
- 追擊高處玩家時主動跳上 one-way platform；
- 撞牆或水平停滯時自動跳躍脫困；
- slow、stun、burn 狀態。

每隻一般敵人死亡只產生 1 顆、價值 1 XP 的實體 `ExperienceGem`；不得因視覺分片
把 1 XP 膨脹成 2 XP。Elite／Boss 仍依總值拆成最多 12 顆。
Gem 生成時先向外短暫散射並落回地面，讓範圍技清場直接形成可見的經驗雨；
之後只在 72 像素內吸引玩家、30 像素內收集，移動速度由 180 加速至 520。
大量低價 Gem 的總和才是 Run 經驗成長來源，但配合高密度怪群必須維持每怪 1 XP。
寶石使用高前景層級、青色背光與脈衝亮點，必須能在怪海和秋季地景上清楚辨識。
每次敵人受擊都要在敵人本體上顯示白閃、壓縮回彈與傷害飄字；致死攻擊改為
金色粒子爆散及快速放大淡出，讓範圍清場能逐隻回報命中與擊殺。
每隻 Elite 死亡都會遞增獨立 reward event，並開啟一次既有神賜升級／融合選擇；
同一倒數內的後續 Elite 不會再被舊 wave／stage key 誤判成重複獎勵。
六種普通敵人的原始 archetype 維持 4–16 HP、零防禦；runtime 開場套用 8 倍生命，
因此 Moth 為 32 HP、Hopper 為 64 HP、Sprout／Thornling 為 80 HP、Shaman 為 96 HP、
Charger 為 128 HP。第一分鐘常見約 40 傷 Combo 普攻只會直接清掉 Moth，其餘角色
需要後續命中並會短暫擊退，不再於畫面邊緣抹除整群。
Elite 維持 85 HP，基礎大招不能單次擊殺；Guardian 仍是獨立耐久關卡。

普通敵人死亡時有 16% 機率生成 `SurvivalPickup`，掉落採單一權威權重表：

| 掉落 | 掉落池權重 | 效果 |
|---|---:|---|
| Healing Fruit | 45% | 立即恢復 35 HP |
| Experience Magnet | 25% | 立即收集場上所有 ExperienceGem |
| Swift Fruit | 30% | 10 秒內移動速度提高 40% |

Pickup 在 180 像素內會追蹤玩家，未拾取時 18 秒後消失；Elite、Harbinger 與
completion Guardian 不進普通掉落擲骰，保留各自既有獎勵責任。

錢袋與素材袋沿用相同的實體追蹤／拾取生命週期，但使用獨立擲骰。普通怪、Elite、
Boss 的錢袋機率分別為 6%、65%、90%；三者的素材袋機率分別為 10%、45%、85%，
單袋素材數量依序為 1、2、3。素材袋 payload 由死亡 archetype 決定：Sprout／Thornling 為
`autumn_wood`，Hopper／Charger 為 `stone`，Moth／Shaman 為 `magic_shard`，
Crimson Elite／Guardian 為 `autumn_core`。拾取後才加入 Run reward summary；同一袋
只能結算一次。死亡結算保留全部已拾取金袋與素材袋；成功通關則在兩類袋裝獎勵上
統一加成 15%，四捨五入為整數後寫入永久資源。

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

秋霖區域 Boss 房以 `AutumnSixArmColossusBoss` 投影相同 Guardian phases 與傷害 API。
Boss 是平台後層的巨物，不參與平台碰撞；六隻握刀手負責後續攻擊動畫，玩家可攻擊的
特殊弱點只在下顎沿 Y 軸張開後出現於口腔青燐核心。舊
`AutumnSmokeOniBoss` 資產與 scene 保留，預定之後作為 Elite 先行登場。

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

- fixed loadout 必須剛好 4 張不重複公式劍魂，第 1 格固定為 Healing，後 3 格組成招式；
- 招式選擇列出與圖鑑相同的 39 個正式招式名稱，經 `legacy_vfx_id` 對應配方後，把
  `required_skills` 聯集填入後 3 格；聯集仍可容納的招式維持可選，超過
  三格或缺少已解鎖劍魂的招式保留在列表並反灰；
- 四格卡槽保持在主流程前段，後方只用一個 workspace 互斥切換劍魂替換與招式配置，
  不同清單不得同時堆疊；
- 招式配置依正式 13 系列分區，每區由左至右固定排列基礎／進階／大師三階；
- 配置畫面即時列出目前四張技能可完成的已學會終結技；
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
原 slot。Basic Attack 永遠免費，不使用 AP/hand 流程。四張卡的視覺框固定，不因
繁中長名稱或多段神賜前綴改變尺寸；成功打出時對應卡片播放短元素光暈脈衝，AP 不足
或其他拒絕狀態不播放。所有 20 張能參與終結技的 Combo／Healing 劍魂具有獨立
暗黑塔羅卡圖，以中央技能圖騰、元素色與舊金星盤在縮圖尺寸先行傳達能力；中文卡名、
類型、等級、AP 與契印狀態保持 live UI，不得烘進圖像。

### 6.5 Fixed-hand invariant

- 四個 slot 在 Run 期間不變；
- slot 1 固定 Healing，slot 2–4 為三格不重複公式劍魂；
- 沒有 redraw、discard、replacement、overflow 或 Auto Use；
- Basic Attack 不在 hand。

### 6.6 Card focus 與施法節奏

Card focus 會把 `Engine.time_scale` 設為 0.22。成功出牌後先結束 focus，再由
`SkillCastPresentation` 以 unscaled time 顯示放大招式名稱與短暫慢動作；連續施放
使用 generation 防止舊 callback 覆寫，離開 SceneTree 時恢復進入前倍率。普通
Basic Attack 不反覆顯示名稱；只有實際造成傷害且沒有施法演出時才使用短 hit stop。

## 7. Combo、Skill 與 Fusion

### 7.1 Combo cards

`combo` 與 catalog 收錄的 `healing` 都可作為終結技公式材料。每個劍魂的 Combo
基礎上限與全域硬上限皆為 10 層；舊裝備與神賜的 cap bonus 保留相容資料，但不得再
把有效上限提高到 10 以上。傷害 chain、限時效果、
永久公式 stack、卡面層數與 HUD 提示皆讀取同一有效上限。Combo 每次使用會永久增加公式用 stack，但該卡提供的 attack
infusion／status 各自維持 1.5 秒，且彼此獨立倒數。某一效果到期時
只移除自己的修正並立即以剩餘效果重建攻擊 profile；例如 Giant Arc 到期後尺寸
回到正常，仍在倒數的 Quickened Cadence 繼續保留攻速。攻擊次數不會消耗這些
效果。Healing 若出現在已定義配方也會進入三格公式。三招必須精確匹配 32 個已學會的
AAA 或有順序 ABC 配方，才會排入對應終結技；不再以任意三招
產生同一招式。效果組成為：

```text
recipe Finisher base + matched three-card current-level effects + equipment projection + every Divine Gift effect
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
沒有 Echo Volley 時，Basic Attack 固定為單方向、單發的貫穿劍氣；同一個
劍氣形狀沿途掃過的每個敵人各受傷一次。Echo Volley 增加同一輪的彈體數，
但重疊劍氣不會讓同一敵人重複承受基礎傷害。攻擊不向最近敵人重新瞄準，
也不在飛行途中追蹤；劍氣形狀外與角色背後的敵人不受傷。有合法目標時
自動射擊；沒有目標時不消耗 cooldown、
公式或已排隊的終結技。

`風暴充能` 施放瞬間不是一顆高速飛行物：左右地面雷流先匯入雙腳，再沿雙腿、持劍手
與整把劍依序接成一條可追蹤電路；唯一高潮只從劍身主幹的中後段長出右向分叉，沒有
離體彈頭。高潮後所有分支沿同一路徑回縮並留下短暫貼身餘電。整段固定在玩家周圍；
後續攻擊附雷仍由原 Combo infusion 規則處理，presentation 不自行造成傷害或暈眩。

### 7.2 Divine Gifts

每次角色升等都開啟一次必選神賜頁，可選未持有的新神賜或升級既有神賜。菁英與 Boss
擊殺則開啟戰利品頁，只列既有神賜升級或合法融合，不提供新品。神賜是 Run-local；最新取得
者標記為主神賜，而所有持有神賜都依取得順序為原招式附上中文稱號並共同提供
mechanics，因此所有不同神賜欄位直接相加、倍率直接相乘，
公式固定為「全部神賜效果＋終結技效果＋前三招 Combo 組合效果」。相同神賜重複
取得時升級，最高 Lv.3；兩個不同 Lv.3 神賜可融合為 evolved gift。融合後保留
兩個材料的部分數值與 mechanics，另依 Lv.1–3 逐步加入 `final_burst`、
`chain_lightning`、`death_spread`、額外 echo、範圍與元素傷害。Evolved gift
會回到後續神賜池繼續由 Lv.1 升至 Lv.3，名稱依序轉為 Awakened／Transcendent，
並使用元素組合專屬名稱與 accent color。融合材料 ascended 後不再進獎勵池，
同一融合不能反覆發生；一般 EXP 頁永遠不提供融合。

神賜 inventory 固定三格。未滿三格時可選新神賜或升級已持有神賜；滿三格後獎勵池
只保留三格內尚未滿級的升級，不能以新神賜覆蓋舊神賜。融合消耗兩項滿級神賜並生成
一項昇華神賜，因此會釋出一格。三格內所有 mechanics 與中文稱號前綴持續疊加；
「主神賜」只標示最近取得者，不取消較早神賜。基礎與昇華神賜名稱、說明皆使用繁中。

正式元素只有 water／fire／wind／lightning／ice／poison／light／dark／normal，
由 `ElementTaxonomy` 統一命名。每個 base 神賜保留一個 canonical `element`；
融合神賜同時保留兩個材料的 canonical `elements`，不會把屬性改名成
`evolved`。Flame、Storm、Frost、Venom 等舊稱只作輸入相容 alias。

### 7.3 技能系列 catalog

`data/skills.json` 是現役技能名稱與分類的唯一權威。技能分成 13 個系列，每系列固定
三招：第一招為 basic（基本）、第二招為 advanced（進階）、第三招為 master（大師）。

| 系列 | 基本 | 進階 | 大師 |
|---|---|---|---|
| 劍雨 | 戰律希聲 | 萬劍垂天 | 驟雨繁音 |
| 月輪 | 月輪垂光 | 扶搖月輪 | 月蝕重輪 |
| 羽毛 | 千羽相應 | 希聲繁羽 | 天羽萬象 |
| 古木 | 古根纏行 | 年輪護生 | 萬古森羅 |
| 巨石 | 靜岳無移 | 石環守一 | 群岳歸一 |
| 巨盾 | 守一返照 | 守一共脈 | 天門不破 |
| 火焰 | 流火照夜 | 霜蘭流火 | 天火燎原 |
| 雷電 | 綿息雷音 | 流火雷音 | 九霄震律 |
| 水流 | 扶搖泉湧 | 靈泉不窮 | 滄海回瀾 |
| 植物攻擊 | 蘭芷成蝕 | 荊庭穿心 | 萬華噬野 |
| 龍息 | 奧術吐息 | 龍脈迴響 | 萬象龍臨 |
| 朝陽生息 | 朝光載陽 | 春庭載陽 | 青庭長春 |
| 同枝共生 | 春靈來復 | 同枝共脈 | 同脈來復 |

每招資料至少包含穩定 ID、繁中名稱、系列 ID／名稱、階級、定位、完整描述與連續動畫
節拍。`萬劍垂天` 取代舊稱 `天際流光`；`天羽萬象` 取代舊稱 `天光回羽`。四個舊被動
`iron_momentum`、`ember_reprise`、`battle_tempo`、`grand_strategy` 已退役，不能再由
存檔、圖鑑或 runtime 當成可學技能。

本階段只核准名稱、系列、階級、定位與招式描述；傷害、AP、解鎖、施放、升級與系列
機制尚未定案，不得從名稱或舊被動 recipe 外推。為讓目前遊戲仍可預覽招式，39 招先以
`legacy_vfx_map` 對應最接近的既有 named VFX。這些 profile 只是暫時動畫 library，
不能反向覆寫技能名稱、分類或描述；後續逐招特效完成時再替換 mapping。

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

### 7.5 Legacy card fusion service

`EvolutionManager` 與 `CardCollectionService.fuse()` 仍保留舊資料相容與原子交易測試，
但 production EXP／菁英／Boss growth 不再投影 card fusion。正式戰鬥內的 merge 指
Divine Gift 昇華，且只從菁英／Boss loot page 可到達。舊 recipe 資料如下：

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
Run 進度；每次跨級都增加 `pending_level_ups` 並依序開啟 Blessing 成長頁。

Run 初始：

- level = 1；
- experience = 0；
- experience required = 100。

下一級門檻公式：

```text
initial_required = 100
next_required = ceil(previous_required * 1.30 + 25)
```

一次取得大量經驗可跨多級，每一級加入 `pending_level_ups`，不會只保留一次升級。

Autumn combat HUD 必須持續顯示目前 XP、下一級門檻與 `NEXT` 尚缺數量。收集 XP
時以短暫青色脈衝回饋，升級時以金色脈衝突出新等級；這些 presentation 不改變
`RunState` 的門檻計算或 level-up queue。

### 8.2 In-run choices

一般 EXP 不提供新卡、卡牌升級或融合，而是每一級從新神賜／既有神賜升級中選一項。
當所有可用神賜都滿級時，該頁改抽金錢或素材。菁英與 Boss 戰利品只列既有神賜
升級／合法 evolved gift 融合。`CardGrowthUI` 以來源標籤、符印、短名稱、等級與最多
三點效果呈現，同一 FIFO 逐頁處理跨級事件。

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

Iron Sword、Leather Armor、Vitality Charm 是普通品質的基礎成品，可在裝備商以純
gold 直接購買。其他裝備只能先取得圖紙，再以普通怪／Elite／Boss 對應強度素材和
加工費於 Player Blacksmith 打造。裝備品質固定分為普通（common）、稀有（rare）、
罕見（exceptional）；品質越高，配方素材階級、加工費與 `base_sale_value` 越高，
裝備能力仍由各自 `effects`／`special_ability` 定義。

裝備可購買或鍛造、裝備、卸下，正式持久化上限為 level 15。目前可執行的精確成本與
效果曲線只實作到 level 3；Lv.4–15 不外推數值，等 OB 補齊中間素材 authority 與曲線後再開放。現有成本為：

玩家可在古老日記式 InventoryUI 的背包裝備分類檢視持有物並直接送出裝備意圖；
狀態章節同時呈現 weapon／armor／accessory 的目前結果。該 UI 不建立第二套裝備狀態，
仍由 InventoryManager 驗證 ownership 與 slot，Game 重算屬性並同步 Meta save。

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

- Material Yard：Level 0 保留 basic stock；Level 1 解鎖 elite、Level 2 解鎖 boss-grade
  材料與工具，Level 3 令所有購入 material bundle 數量增加 25%。
- Player Blacksmith：依已購圖紙、素材與 gold 加工費鍛造 equipment／Sword Soul、升級 blacksmith
  解鎖 recipe Tier；Level 2／3 各降低 5% 加工費。玩家可升級 Sword Soul，並將 crafted equipment 放到單格販售桌，
  顧客結帳後顯示 `+GOLD`。
- Market：三級累計提供 10% 購買折扣與 20% 裝備販售加成。
- Town Hall：查看 village stage、總建築等級與資源，集中選擇並升級五棟建築；
  Town Hall 三級累計降低其他建築 10% 建設成本。
- Memory Library：由基礎 10 格起，四級依序增加 4／4／6／6 格，最高 30 格。
- Sword Soul Shop：buy-only 圖紙 catalog；持有後不能重複購買。
- Equipment Blueprint Shop：基礎普通裝備直接販售；其餘只販售不可重複購買的圖紙，
  高階成品必須回玩家工坊鍛造。

舊通用 Town progression UI 已退役；Player Blacksmith 與 Town Hall 升級成功時由
Game 立即同步 Meta save、鍛造／商店 economy modifiers、Town visual 與 equipment stats；
關閉 dedicated screen 時仍執行相同同步作為保險。

五條升級線會投影到權威 `TownModularVisuals` 的 Material Yard、Player Blacksmith、
Town Hall、Sword Soul Shop 與 Equipment Blueprint Shop；runtime metadata 記錄 building ID
與 level，並以克制的暖亮度呈現進度。資料內 visual flags 仍是未來替換分級素材的 contract，
不得宣稱目前每級已有獨立建築貼圖。

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
bob 或旋轉情緒幀。女巫與科學家另有四列角色專屬工作姿勢；女巫 directional source 原生
朝左，移動時依 requested facing 正確翻面。祭司的八列 atlas 另含祈禱、祝福、安慰／遞物與
緊張到鼓起勇氣；courage 只供明確危險／保護事件使用，不是 ambient。她在清晨／夜間優先
留在 home 執行平靜設定動作，只在中午至傍晚、冷卻結束且
女巫空閒時，以 `y=672`／`z_index=0` 走到女巫左側 95 px；兩人面對面聊天後沿同一 baseline
回 Town Hall，舊的前景繞行不再使用。其餘六位居民會在各自店面／街區附近
待機、表達情緒、做符合身份的悠閒工作、坐下休息或短距離散步；社交時先保留 partner、
走到 catalog 指定距離，且兩個 meeting targets 與第三位 NPC 的目前、home 或已預留社交位置
至少保持 120 px；附近沒有安全位置時放棄邀請，不在其他居民面前重疊聊天。
依序打招呼、聊天／談工作、產生情緒反應、道別，再回到精確 home。初次見面偏好 greet；
熟人可依角色選擇 discuss_work，golden hour 可一起 watch_sky。familiarity 與 cooldown 都是
session-local，不形成持久 schedule。每次本地活動後有明確 idle recovery，無事件環境不會
隨機生氣／難過／驚訝；近期 partner 與重複動作有 cooldown。女巫與科學家可跨街區走到共同
會面點，但仍受雙方角色 allowlist 限制；兩者不隨機切入 generic sit，坐下只由有座位的角色
事件觸發。科學家的專屬動作播放一次、短暫停在完成姿勢後回到慢速細微待機，day-period work
仍至少停留 14–20 秒，
malfunction 只供明確失敗事件；一般居民 idle 為 5.5–10 秒、role recovery 為 10–16 秒，
社交聊天基準約 7 秒且最近 partner 冷卻 75 秒。一般 idle／sit 為 1 FPS，look／stretch／
greet／work／emotion gesture 以 2 FPS 播放一次後停留；idle 只有約 28% 機率做一次非正面
look，避免反覆轉頭。守衛執勤使用 calm lookout，不使用容易讀成受擊的 work row；祭司在
front idle 與 calm side idle 間交替。女巫主動社交率為 12%，任何 autonomous／external chat
後至少休息 150 秒，營造悠閒而非狀態輪播的節奏。散步區域依
相鄰 home anchor 切開，至少保留一個人物
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
為可同時持有多把通道鑰匙的區域 Boss Portal。四個固定入口為 Autumn、Crystal、
Hell、Heaven；篇章只增加同槽可選世界，不移除前一世代。

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

`finish_run()` 產生 summary 後重置 transient state，並由 `outcome` 明確區分四種結算：
走到實體出口為 `safe_retreat`、全額保留；死亡為 `death`、保留 65%；Pause 的
Exit Combat 為 `abandon`、本局掉落全失；00:00 完成為 `victory`、全額加 15% 並兌現
待結算寶箱。summary 保留 `base_gold`／`base_materials` 供結算 UI 說明來源。

### 11.2 MetaState

`MetaState` schema version 為 9，保存：

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
- story chapter、下一段 sequence checkpoint 與 stable story flags；
- boss state。

舊 payload 在載入時 deterministic、idempotent migration；非法 level、重複/缺失
instance ID 必須修復並留下 report。Skill arrays 去重，active 只保留 learned IDs；
schema 8 另移除四個退役被動 ID，且不補入舊 `Iron Momentum` 預設；
auto attack 缺失或無效時在組裝 Run 時 fallback 到有效已解鎖 attack。

第一章正史場景 1-1「城鎮廣場」目前只作為圖鑑「劇情回顧」vertical slice：玩家從
I 選單直接選取章節後播放 21 句對話，左上半身頭像依 line-authored emotion 低速播放
一次並停在末幀。載入 Town 不自動播放，回顧完成也不寫
`protagonist_town_routine_established` 或前進 checkpoint。正式接入主線前，1-2～1-5
仍由同一 StoryDirector／DialogueRunner 擴充，不得用另一套 UI。

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
- 每張 Combo 卡的分類框顯示該劍魂自己的 `目前層數/有效上限`；
- 每次個別劍魂 Combo 增加時，左側玩法區短暫顯示「中文劍魂名 ×N」；字級由 18px
  隨次數緩升、最高 26px，並在 0.95 秒內小幅放大、上浮與淡出；
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
│       ├── ComboPopupAnchor (Control)
│       │   └── ComboPopup (Label)
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
			ceil(float(experience_required) * 1.30 + 25.0)
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
- 不建立出牌事件；退役的 `SkillRecipeManager` count/sequence engine 不再推進；
- 可使用所選 attack card 的有效 level/equipment projection；
- 固定沿玩家面向發射；方向劍氣使用與 106px 主刃高度、Combo 尺寸、stack
  及 Combo spectacle 同源的前向膠囊掃掠形狀，沿途每個 hurtbox 只結算一次；
- 圓形爆發使用 radius 與 hurtbox 圓形相交，Dash 攻擊使用起終點膠囊相交；
- 無效選擇 fallback 到已解鎖的有效 attack。

Dash 是玩家固有 action：↑ 只觸發 Jump，Space 觸發 Dash。Dash 不建立
`CardInstance`，不進 backpack/hand/draw/discard/exhaust/cooldown，也不花 AP 或
觸發退役的 `SkillRecipeManager` card sequence。`quickstep` 已從正式卡表移除。
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
entire Run, while each card's attack infusion or status has its own 1.5-second timer.
Expiration removes only that card's modifiers, so later overlapping effects
continue normally. Healing enters the formula when it is part of a catalog recipe. An exact learned
three-card recipe queues its named Finisher for a later automatic horizontal shot;
multiple Finishers resolve FIFO. The HUD shows formula slots, persistent stacks,
owned Divine Gifts, Gift-modified names, and the queued ready state.

具名 Finisher 會同時讀取本 Run 實際持有的所有 Divine Gifts，而不是只讀目前標記的
primary Gift。最多三項 Gift 依取得順序各自增加一組元素來源粒子與對應光色；同一 Gift
不得重複疊層。evolved Gift 以單一昇華層保留其 component elements、等級與融合強調色，
已被融合移除的 base Gifts 不再另外顯示。這些疊層只改變 presentation，不建立第二套
傷害、狀態或融合 authority。

All twenty formula-eligible Sword Souls use a shared base cost of `2 AP`. Equipment
may still apply `combo_cost_reduction` to Combo cards, with a minimum final cost of
`1 AP`; Healing cards keep their catalog cost.

The Combo Chain uses a separate pressure curve based on total active Combo stacks. Counts
one through three receive a 2.0-second continuation window; count four starts at 1.3
seconds, then each additional count removes 0.1 seconds down to a 0.6-second floor.
Legacy `combo_duration_bonus` is added after that curve. Focus Amulet therefore adds 0.5
seconds to the current chain window and extends the independent card effect to 2.0 seconds.

### Card tempo and AP flow

Base AP regeneration is `0.95 AP/second`. Low-cost Combo and Healing cards build
a separate six-second card-tempo window so sustained play accelerates the hand
without making high-impact cards self-sustaining:

The normal four-slot Sword Soul hand therefore follows the catalog-cost 2 branch:
each successful play adds one tempo stack and immediately refunds `0.15 AP`.

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
- [ ] XP 跨級 Blessing queue、菁英／Boss merge gating 與 all-max fallback 有測試。
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

### Elite/Boss Blessing synthesis and combat readability

Only elite or boss loot may expose synthesis. Two distinct Lv.3 Divine Gifts
can merge into one Lv.1 evolved gift; EXP level-up pages never enqueue a fusion
follow-up. If every Blessing is already maxed, EXP offers money/material draws.

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
player. The ten-minute countdown opens with 24 enemies, continuously grows concurrent
caps `40 → 140` and spawn batches `8 → 16`; Final Rush adds another 40 cap plus scheduled Elites and
Harbingers. Amber Moth Swarm adds fragile high-speed pressure while Grove
Shaman adds long-range support. Normal roles stay defense-free; their `8.0 → 20.0`
timeline health scale preserves fragile early crowds while letting later survivors
absorb follow-up hits and show knockback. Elite is never part of the random normal pool.
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
