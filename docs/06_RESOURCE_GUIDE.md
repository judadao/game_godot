# Resource and Data Guide

本文件定義目前專案的靜態資料、runtime state、Meta/Run state、UI projection與save
serialization邊界。名稱中的「Resource」同時涵蓋Godot `Resource`概念與專案資料治理；
目前repository **沒有 gameplay `.tres`／`.res`檔案**，不可把未實作的typed Resource
pipeline描述成Current。

## 目錄

1. [目的、現況與術語](#1-目的現況與術語)
2. [資料分層與 Ownership](#2-資料分層與-ownership)
3. [現有九個 JSON Catalog](#3-現有九個-json-catalog)
4. [Card Data 與 CardDatabase](#4-card-data-與-carddatabase)
5. [Fusion Recipe 與 EvolutionManager](#5-fusion-recipe-與-evolutionmanager)
6. [Equipment Data 與 Inventory Runtime State](#6-equipment-data-與-inventory-runtime-state)
7. [Town Upgrade Data 與 Town Runtime State](#7-town-upgrade-data-與-town-runtime-state)
8. [Godot Resource 現況](#8-godot-resource-現況)
9. [Runtime、MetaState 與 RunState](#9-runtimemetastate-與-runstate)
10. [Save Data Boundary](#10-save-data-boundary)
11. [UI Projection 與 Mutation Rules](#11-ui-projection-與-mutation-rules)
12. [Validation、Error Handling 與 Migration](#12-validationerror-handling-與-migration)
13. [檔案與 ID 規則](#13-檔案與-id-規則)
14. [Code Examples](#14-code-examples)
15. [Scene Tree Example](#15-scene-tree-example)
16. [Godot Example (Godot 4)](#16-godot-example-godot-4)
17. [Best Practice](#17-best-practice)
18. [Anti Pattern](#18-anti-pattern)
19. [Data Change Checklist](#19-data-change-checklist)
20. [Review Checklist](#20-review-checklist)
21. [Future Extension](#21-future-extension)
22. [Related Documents](#22-related-documents)

## 1. 目的、現況與術語

### 1.1 Current inventory

| 類型 | 數量 | Path |
|---|---:|---|
| Gameplay JSON | 10 | `res://data/*.json` |
| Gameplay `.tres` / `.res` | 0 | 無 |
| `resources/` content | 0；空目錄不保留 placeholder | 無 |
| Runtime Resource class | 1個主要enemy model | `EnemyArchetype` |
| Scene sub-resources | 多個 | StyleBox、Shape等內嵌於`.tscn` |
| Generated VFX texture | 24 | `res://assets/generated/vfx/` |
| Town NPC transparent cutout | 5 | `res://assets/town/npc/characters/` |
| Town NPC world animation atlas | 7 | `res://assets/town/npc/characters/*_animation_atlas.png` |

十個 JSON：

- `res://data/cards.json`
- `res://data/evolutions.json`
- `res://data/skills.json`
- `res://data/equipment.json`
- `res://data/town_upgrades.json`
- `res://data/divine_gifts.json`
- `res://data/combo_finishers.json`
- `res://data/forge_catalog.json`
- `res://data/named_skill_vfx_profiles.json`
- `res://data/elemental_ground_trail_profiles.json`

Generated combat presentation：

- `tools/build_basic_attack_vfx_sheets.py` 是普通劍氣 deterministic silhouette
  authority。它以
  code-native 2D parts 產生 core blade、crescent edge、afterimage、shards 與
  impact wedge，再拼成 weapon release、blade travel、directional impact 三組
  runtime sheet。
- `assets/generated/vfx/parts/basic_attack_*_sheet_v2.png` 是可檢查、可替換的
  模組化部件素材；`basic_attack_*_sheet_v2.png` 與對應 mask 是 runtime 合成輸出。
  普通劍氣 runtime 不再依賴整張來源圖裁切。
- `AutoAttackFeedback` 以三組八幀 sheet 交疊完成近身前向空心月牙預備、水平高速
  切割波與放大的方向性命中月牙。基準節奏為 42 ms 蓄勢、105 ms shockwave travel
  與 180 ms impact；旅行使用前重後輕的 ease-out 位移，不能用飛彈式慢起步。前幀
  殘像、元素雙輪廓、Lifesteal 與 Combo 疊層全部使用同幀
  silhouette mask；中性普通攻擊不帶 Flame/Frost/Storm/Venom 層，火焰感只在對應
  火系 Combo infusion 後由元素 mask pass 加上。texture 本身不擁有 gameplay hitbox
  或 damage。
- `basic_attack_crescent_quality_atlas_v3.png` 是參考概念圖生成後保存的 4×2
  additive parts atlas；`PremiumCrescentLayer` 將 outer glow、moon core、
  inner current、flow ribbons、ground cut、spark debris、contact bloom 與
  decay fragments 分開控制。三個流動歷史 sample 與三層非同步形變只強化材質與
  動勢，不改變 v2 sheet 的前向空心月牙 authority。素材格位與 generation prompt
  記錄於 `docs/art_concepts/basic_attack_crescent_v3.md`。
- 普通劍氣 release、travel、impact 三段都必須維持朝移動方向凸出的 `)` 型空心月牙
  silhouette；「水平」指旅行方向，不是把月牙壓成扁長箭頭。預備動作不得退回
  直立上挑弧、火焰 plume 或有長尾的 projectile。
- `FireUltimateVFX` 與 `IceUltimateVFX` 使用 editor-authored scene 加上
  Godot 原生 drawing、Line2D、Polygon2D 與 bounded GPUParticles2D，不依賴
  一次性影片。兩者都採五段演出、限制 visual bounds／particle budget，並在
  玩家中心保留 readability hole；火系由聚火、點燃、擴散、火冠至餘燼，冰系
  由蓄勢、徑向凍結、晶柱爆發、碎裂亮邊至冷霧消散。兩者以 unscaled timeline
  維持 contact timing，並統一收束為 impact snap、cohesive decay、tail hold。
- `assets/generated/vfx/ground/*_ground_path_parts_v1.png` 是三張 1536×1024 RGBA
  四象限圖集：左上 Core、右上 Edge、左下 Accent、右下 Debris。
  `ElementalGroundTrailCatalog` 驗證 atlas 尺寸、region 邊界及不重疊；
  `ElementalGroundTrail` 沿路徑逐段組裝素材並以 unscaled fresh／active／decay
  timeline 播放。火痕、凍裂、毒灘各有獨立 topology，不得只換 tint。象限與
  generation contract 記錄於 `docs/art_concepts/elemental_ground_paths_v1.md`。
- `SkillCastPresentation` 只以透明元素洗色、短促 impact flash、能量導線與
  可換行大字表現出招，不使用實心中央 UI 卡片。Major cast 才啟用邊緣壓暗，
  一般 Combo 維持正常時間流速。
- `NamedSkillVFXCatalog` 驗證五個 Finisher 與四個 trigger 的獨立資料身份。
  每招由 anticipation、attack、trail、impact、debris 五個 atlas parts 拼裝，
  並以唯一 archetype、beat pattern、三級 evolution layers 與 stack traits
  控制動畫拓樸和成長，不以單一模板只換 motion 名稱。

Town NPC presentation：

- `tools/build_town_character_cutouts.gd` 是 deterministic 背景分離工具；輸入固定為
  `concept/characters` 的女巫、村長、瘋狂科學家、路人與雜貨店大叔，輸出固定為
  `assets/town/npc/characters/*_cutout.png`。
- 輸出必須保留來源 pixel-art 幾何與服裝設計，具有透明背景、無彩色殘邊，且不得把
  concept 漸層背景帶入 Town 或人物半身框。重新產生後必須重跑 native-detail、Town
  full-frame、固定 3 × 2 slices 與六解析度服務 UI 視覺審查。
- `tools/build_town_npc_animation_atlases.gd` 將五張 cutout 縮至 Town 的粗像素頻率，
  產生初版一般 Town NPC 的 `576×1368` RGBA atlas。每張固定 4 columns × 9 rows，row 順序為
  idle、walk、sit、chat、laugh、happy、sad、surprised、angry；guard 與 innkeeper
  必須保留獨立 palette/accessory variant，禁止重新指向 traveler／grocer atlas。
- 本機、git-ignored 的 `assets/town/npc/characters/source_motion_v2/` 可保存六位角色的
  原始 chroma generation；版本化的 `motion_strips_v2/` 保存去背後 4 columns × 3 rows
  完整姿勢動作帶，row 固定為
  front idle、side walk、side chat。`tools/art/build_town_npc_full_pose_atlases.py` 依透明
  間隔擷取每格、統一 132 px 人物高度與 `y=144` 腳底線，覆寫正式 atlas 的 row 0／1／3；
  sit row 另統一為 120 px（包含清楚椅凳）以保留成人頭身，laugh／情緒 row 從
  `procedural_v1/` 保留。守衛的 retained row 會同步轉為核准的 charcoal uniform。
  任何來源或 normalization 改動後，
  必須重建六張 atlas 並重做原尺寸、Town full-frame、時序與固定 3 × 2 slices 審查。
- 祭司 runtime 使用 `assets/town/npc/priest/pose_strips_v2/` 的四組完整成人骨架動作帶，
  由 `tools/art/build_priest_animation.py` 依透明間隔擷取完整人物、統一 448 px 原生高度與
  腳底線，再輸出 `priest_animation_atlas.png` 的 8 columns × 4 rows atlas；row 順序固定為
  front idle、front chat、side walk、side chat。`parts/` 舊分件只保留為來源紀錄，不得再
  直接拼成 runtime 幀，以免不同頭身比例或相鄰肢體混入。

### 1.2 術語

- **Static catalog**：repository中的authoritative JSON，runtime不應回寫。
- **Validated model**：loader驗證後快取的duplicate Dictionary/Array或Resource。
- **Runtime state**：目前application/run中可變狀態。
- **Meta state**：跨run與restart保存的永久進度。
- **Run state**：單次expedition transient state。
- **Save DTO**：序列化到`user://`的Dictionary。
- **UI projection**：為顯示而產生的copy，不是catalog owner。
- **Godot Resource**：繼承`Resource`的Godot object；不等同所有JSON資料。

### 1.3 核心邊界

```text
Static JSON / Scene sub_resource
→ parse + validation
→ runtime catalog/model
→ mutable manager / MetaState / RunState
→ UI projection
→ explicit save DTO
```

逆向寫回只允許save DTO到`user://`。UI或runtime manager不得改寫`res://data/*.json`。

## 2. 資料分層與 Ownership

### 2.1 Layer table

| Layer | Owner | Mutable | Persistence |
|---|---|---:|---|
| JSON catalog | repository | 否（runtime） | version control |
| Catalog cache | Card/Evolution/Inventory/Town loader | loader-controlled | reload from JSON |
| Inventory/Town runtime | manager instances owned by Game | 是 | projection into MetaState |
| MetaState | Game-owned `MetaState` | 是 | `meta_progress.json` |
| RunState | Game-owned `RunState` | 是 | finish summary only；非完整save |
| DeckManager piles/AP | Game-owned `DeckManager` | 是 | quick save不完整保存 |
| Card collection coordination | Game-owned `CardCollectionService` | 是（協調 mutation，不新增 authority） | 由 MetaState／RunState／DeckManager 各自邊界保存或投影 |
| Prototype inventory/shop | Game dictionaries | 是 | quick save部分保存 |
| UI projection | UI instance | 顯示狀態 | 不直接保存 |

### 2.2 Dependency direction

```text
data/*.json
  ↓
systems loader
  ↓
runtime state/service
  ↓
Game orchestration
  ↓
UI setter/configure API
```

禁止：

- static loader依賴UI Scene。
- UI持有並修改catalog中的base Dictionary。
- save loader直接改Scene node而不經validation/application boundary。
- system從`/root`尋找不存在的Autoload。

### 2.3 Copy boundary

跨layer時使用：

- `Dictionary.duplicate(true)`
- `Array.duplicate()`或typed projection
- getter回傳copy
- `to_dict()`／`apply_dict()`

如果getter回傳catalog內部reference，consumer可能污染所有後續讀取。Current
`CardDatabase.get_card()`與`get_all_cards()`已回傳deep copies。

## 3. 現有九個 JSON Catalog

| JSON | Loader | Root field | Current validated content |
|---|---|---|---|
| `cards.json` | `CardDatabase` | `cards` | 24 cards |
| `evolutions.json` | `EvolutionManager` | `fusion_recipes` | 6 recipes |
| `skills.json` | `SkillRecipeManager` | `skills` | attack-only passive skill recipes |
| `equipment.json` | `inventory_manager.gd` | `resource_order`, `starting_resources`, `equipment` | 5 resources, 10 equipment |
| `town_upgrades.json` | `town_manager.gd` | `buildings`, `village_stages` | 4 buildings × 3 levels, 3 stages |
| `divine_gifts.json` | `DivineGiftManager` | `gifts` | 6 個三級 Run-local 神賜 |
| `combo_finishers.json` | `ComboFinisherCatalog` | `recipes` | 5 個精確三招終結技配方 |
| `forge_catalog.json` | `ForgeCatalog` | `material_offers`, `equipment_recipes`, `sword_soul_recipes` | Town 鍛造 offer 與 recipe |
| `named_skill_vfx_profiles.json` | `NamedSkillVFXCatalog` | `profiles` | 5 個 Finisher＋4 個 trigger 的差異化模組 VFX |
| `elemental_ground_trail_profiles.json` | `ElementalGroundTrailCatalog` | `profiles` | 火焰路徑、冰裂分岔與毒灘的四槽 atlas 拼裝資料 |

數量與重要cross-reference由`tests/content_validation_test.gd`驗證。新增內容時，
測試中的固定數量若代表產品contract需一起更新；不得只為通過測試放寬assertion。

### 3.1 JSON parsing rules

- 使用`FileAccess`與`JSON.parse_string()`。
- top-level必須是`Dictionary`。
- expected array/object field必須驗證type。
- ID不得空白或重複。
- cross-reference必須指向存在ID。
- asset path使用`ResourceLoader.exists()`。
- 任一entry破壞catalog contract時，loader回傳false或保持`_loaded == false`。

### 3.2 Schema version現況

- `cards.json`：`schema_version = 3`
- `evolutions.json`：`schema_version = 2`
- `skills.json`：目前沒有 schema_version field
- `equipment.json`：目前沒有schema_version field
- `town_upgrades.json`：目前沒有schema_version field
- `divine_gifts.json`：目前沒有 schema_version field
- `combo_finishers.json`：目前沒有 schema_version field

Loader目前不以schema version分派migration。新增／更改schema前，必須先建立version
policy與old fixture，不能只提高number。

### 3.3 Formal element taxonomy

`scripts/systems/element_taxonomy.gd` 的 `ElementTaxonomy` 是武器、神賜與戰鬥 VFX
共用的唯一正式元素權威，canonical IDs 固定為：

```text
water
fire
wind
lightning
ice
poison
light
dark
normal
```

Compatibility aliases 只在 `normalize()` 邊界轉換，例如 flame→fire、
earth→wind、storm／thunder／wood→lightning、frost→ice、venom→poison、
neutral→normal。新 catalog 不得保存 alias。`equipment.json` 的每個 weapon
必須提供一個有效 `primal_element`；`divine_gifts.json` 的 base gift `element`
也必須是 canonical ID。兩個 Lv.3 神賜融合後，dynamic entry 的 `elements`
陣列保留去重後的 canonical component elements，`element` 只投影第一個 primary
element；不得用 `evolved` 等新字串取代材料屬性。

### 3.4 Named Skill VFX profile contract

`data/named_skill_vfx_profiles.json` 的每筆 profile 除 atlas、crop、motion 與 timing
外，必須包含：

- `element`：正式 ElementTaxonomy ID。
- `archetype`：九招之一的唯一動畫拓樸；catalog 不接受重複或未支援值。
- `beat_pattern`：3–5 個介於 0..1 且嚴格遞增的節拍。
- `evolution_layers`：恰好三個不重複字串，依 Lv.1／2／3 逐步解鎖。
- `stack_milestones`：由 0 開始、嚴格遞增的非負整數。
- `stack_traits`：與 milestones 等長的獨立視覺語彙。

九種 supported archetypes 依五個 Finisher、四個 trigger 的 catalog 順序為：

```text
blade_storm_lane
compression_detonation
rail_prison
orbiting_wheel
descending_tomb
armor_lock
returning_arc
rhythm_pulse
tactical_ward
```

Catalog 採 all-or-nothing validation，getter 回傳 deep copy。Runtime
`NamedSkillVFX.play()` 接收 `evolution_level` 與 `buff_stacks`，再以 profile 的
archetype、beat pattern 與 milestone tier 增加 presentation parts、節拍與拓樸；
`evolution_layers`／`stack_traits` 同時提供經 validation 的招式成長 identity
signature。這些資料不修改 gameplay damage/status authority。

## 4. Card Data 與 CardDatabase

### 4.1 Authoritative path與loader

- Data：`res://data/cards.json`
- Loader：`scripts/systems/card_database.gd`
- Class：`CardDatabase extends RefCounted`
- Default path：`CardDatabase.DEFAULT_CATALOG_PATH`

### 4.2 Required fields

`CardDatabase.REQUIRED_FIELDS`：

```text
id
name
type
rarity
level
max_level
cost
description
icon_path
combo_tags
effect
upgrade_effects
play_destination
cooldown_seconds
```

Fusion recipes are owned only by `data/evolutions.json`. Card rows must not
carry the removed passive `evolution_condition` or `evolution_result` fields.

JSON另有`tags`，但它不在current required list。治理與validator要區分required與optional。

### 4.3 Valid types

Current：

- `attack`
- `skill`
- `power`
- `summon`
- `healing`
- `status`
- `ultimate`
- `combo`

新增type時至少同步：

- `CardDatabase.VALID_TYPES`
- `CardEffectRunner` effect handling
- Game card/equipment/infusion projection
- CardHandUI presentation
- content/combat integration tests
-本文件與Game Design

### 4.4 Validation

Current loader檢查：

- required fields存在。
- `id`與`name`非空。
- type在allowlist。
- cost非負。
- rarity非空。
- `level >= 1`，`max_level >= level`。
- `combo_tags`是非空Array。
- `effect`是非空Dictionary。
- `upgrade_effects`是Array。
- 至少有level 3 upgrade帶visible `mechanic_change`。
- icon path非空且`ResourceLoader.exists()`。
- card ID不可重複。

`get_card()`回傳deep copy。UI與combat可以加入runtime level/effect projection，但不能
回寫`_cards_by_id`。

### 4.5 Effect boundary

Card JSON的`effect.kind`交由`CardEffectRunner.SUPPORTED_EFFECTS`解析。Catalog
validator目前沒有直接檢查kind是否被runner支援，這是Known Risk。新增kind時需同步：

1. data entry
2. runner support與behavior
3. target capability
4. integration test
5. UI description

## 5. Fusion Recipe 與 EvolutionManager

### 5.1 Authoritative path與loader

- Data：`res://data/evolutions.json`
- Loader：`scripts/systems/evolution_manager.gd`
- Class：`EvolutionManager`

`EvolutionManager` 是既有 class/file 名稱的 compatibility 命名；它目前只驗證與
查詢 fusion recipe，不再代表被動 evolution。

### 5.2 Required recipe fields

```text
id
name
left_card_id
right_card_id
result_card_id
```

Validation：

- recipe ID非空且唯一。
- left/right/result ID 非空。
- left 與 right 必須是不同材料 ID。
- CardDatabase存在時，兩張材料與 result card 都必須存在。

### 5.3 Runtime application

`EvolutionManager` 只查詢 recipe，不直接 mutation deck。`GrowthChoiceQueue`
建立 EXP fusion choice；`Game` 驗證 Growth choice、管理 pause 與 save transaction。
`CardCollectionService.fuse()` 再驗證 recipe 與三個 authority 的共享 identity，
原子移除兩張不同 Lv.3 材料並加入一張 Lv.1 result；任一步失敗都 restore
collection snapshot。這個 ownership 不可移入 UI。

## 6. Equipment Data 與 Inventory Runtime State

### 6.1 Authoritative path與loader

- Data：`res://data/equipment.json`
- Loader：`scripts/systems/inventory_manager.gd`
- Script type：unnamed `RefCounted`

### 6.2 Root fields

```text
resource_order
starting_resources
equipment
```

Current resource IDs：

- `gold`
- `autumn_wood`
- `stone`
- `magic_shard`
- `autumn_core`

Current equipment slots：

- `weapon`
- `armor`
- `accessory`

### 6.3 Equipment entry

Current fields：

- `id`
- `name`
- `slot`
- weapon 專用 `primal_element`
- `purchase_cost`
- `effects`
- `special_ability`

Loader validation：

- root arrays/dictionaries非空。
- 每個resource ID在starting resources中存在。
- starting amount是非負整數值。
- equipment ID非空且唯一。
- slot在`VALID_SLOTS`。
- weapon 的 `primal_element` 必須通過 `ElementTaxonomy.is_valid()`。
- effects與purchase cost非空。
- cost是正整數值。
- effect value是int或float。

`special_ability`目前由data提供且content test要求非空，但
`inventory_manager._load_data()`沒有完整schema validation每個ability field。
新增ability key時必須檢查Game consumer，不能假設任意key生效。

### 6.4 Runtime state

InventoryManager持有：

```text
_resources
_equipment_catalog / _equipment_by_id
_owned_equipment
_equipment_levels
_equipped { weapon, armor, accessory }
```

Persistence API：

- `to_dict()`
- `apply_dict(data)`

Mutation API：

- resource add/set/spend
- equipment add/purchase/equip/unequip/upgrade

UI不得直接改以上private dictionaries。

### 6.5 Known overlap

除InventoryManager外，還有：

- `MetaState.resources/equipment/equipment_levels/inventory_state`
- `Game.wallet_gold/player_inventory/_merchant_catalogs`

InventoryUI 以只讀 projection 合併 `player_inventory` consumables、
InventoryManager resources/equipment，以及 MetaState discovery fields；
MaterialYardUI、PlayerBlacksmithUI 與 TownHallUI 操作
InventoryManager/TownManager。任何 transaction 仍要追蹤所有同步點。

## 7. Town Upgrade Data 與 Town Runtime State

### 7.1 Authoritative path與loader

- Data：`res://data/town_upgrades.json`
- Loader：`scripts/systems/town_manager.gd`
- Script type：unnamed `RefCounted`
- Dependency：InventoryManager-like service

### 7.2 Root fields

```text
buildings
village_stages
```

Current building IDs：

- `blacksmith`
- `workshop`
- `market`
- `town_hall`

每棟三個upgrade levels，entry包含：

- `level`
- `cost`
- `visual_flag`

Current village stages：

- `settlement`
- `growing_village`
- `prosperous_town`

### 7.3 Validation

TownManager檢查：

- buildings非空。
- stages恰好3個。
- building ID非空且唯一。
- upgrades非空。
- upgrade level依array index連續為1..N。
- cost非空。
- visual flag非空。
- stage ID非空。
- stage threshold嚴格遞增。
- stage visual flags非空。

目前loader沒有逐一驗證cost value型別與resource ID是否存在InventoryManager。
這是Known Risk，data review必須交叉檢查。

### 7.4 Runtime state與projection

TownManager持有building levels並提供：

- next cost/can upgrade/upgrade
- total levels
- village stage/id
- visual projection
- `to_dict()`／`apply_dict()`

`Game._apply_town_visual_progress()`目前直接找到Town building nodes並改modulate；
`TownManager.get_visual_projection()`的完整flags尚未成為通用Scene binding。
不得宣稱所有visual flags已有runtime consumer。

## 8. Godot Resource 現況

### 8.1 `.tres` / `.res`

Current：

- gameplay `.tres`：0
- gameplay `.res`：0
- `resources/`：目前不存在；新增第一個外部 Resource 時再建立

因此：

- cards不是CardResource。
- equipment不是EquipmentResource。
- quest resource不存在。
- dialogue resource不存在。
- audio resource catalog不存在。
- shared Theme resource現況另見Theme稽核／文件。

### 8.2 Runtime Resource class

`scripts/monsters/enemy_archetype.gd`：

```gdscript
class_name EnemyArchetype
extends Resource
```

`EnemyArchetype.autumn_catalog()`以`EnemyArchetype.new()`建立runtime objects；
不是從`.tres`載入。`EnemyBase.configure_archetype()`取得catalog並套用。

這種runtime factory是Current；不要在文件範例寫成
`load("res://resources/enemies/*.tres")`。

### 8.3 Scene sub_resource

`.tscn`內的`StyleBoxFlat`、Shape等`sub_resource`由Scene擁有。修改時：

- 同Scene專用可保留sub_resource。
- 多Scene重複樣式應先查Theme/component pattern。
- 不要在runtime改共享Resource造成所有instance一起變更。
- 需要per-instance mutation時使用duplicate。

## 9. Runtime、MetaState 與 RunState

### 9.1 MetaState

`MetaState.SCHEMA_VERSION = 7`。

主要fields：

```text
resources
village_level / building_levels
unlocked_cards / selected_card_instances / selected_deck compatibility projection
auto_attack_card_id
learned_skill_ids / active_skill_ids
equipment / equipment_levels
boss_defeated / shortcuts
settings
inventory_state / town_state
```

`auto_attack_card_id` 是戰前 loadout 選擇，必須解析為已解鎖的 attack card；
無效時由 composition root 選擇有效 fallback。`active_skill_ids` 必須是
`learned_skill_ids` 的子集。migration 會去重、移除未知 active entry，並確保初始
`iron_momentum` 已學會且至少有一個 active skill。
`inventory_state`與`town_state`是current manager DTO；其他equipment/building fields
同時保留legacy compatibility。

`selected_deck`／`selected_card_instances` 的 production loadout 固定為四個 unique
instances：剛好一個 Healing 與三個 Combo。舊存檔可帶較大的 legacy list，
但 Deck Builder 與 Run start 必須正規化成此 invariant。

### 9.2 RunState

Transient fields：

```text
active
level / experience / pending_level_ups
energy / max_energy
starting_deck / temporary_cards / card_levels
combo_count / temporary_buffs
gold_earned / materials_earned
defeated_enemies / elite_defeated / boss_defeated
```

`finish_run()`產生summary後reset transient state。不要把RunState直接serialize成meta，
除非產品需求明確改成run resume並完成migration/tests。

### 9.3 DeckManager

`DeckManager.start_fixed_hand()` 持有四張 hand instances 與 energy/max energy。
production fixed mode 的 draw/discard/exhaust/cooldown piles 永遠為空；出牌不移動
instance。Basic Attack 只以 `MetaState.auto_attack_card_id` 與 run-local lock
表示，不建立 CardInstance、不加入 DeckManager。

### 9.4 DivineGiftManager

`data/divine_gifts.json` 每筆資料包含 `id`、`name`、`description`、`icon`、
`prefix`、`element`、`finisher_mutations` 與三筆 `effects_by_level`。每級效果
必須對 Combo 或終結技有可觀察影響；主神賜的稱號前綴與原終結技名稱組合，所有
持有神賜的 mechanics 則合併套用。Manager inventory 只存在於 Run，重複 ID 升級
至 Lv.3。兩個不同 Lv.3 融合後建立 dynamic evolved entry；材料標記 ascended，
不再回到本 Run 的一般獎勵池，同一融合配方也不能重複建立。Base `element` 必須是
canonical ElementTaxonomy ID；融合結果的 `elements` 陣列保留兩個材料的 canonical
元素，並以第一項投影相容的 primary `element`。

`data/combo_finishers.json` 每筆 recipe 包含 `id`、`name`、精確三項 `sequence`、
`required_skills` 與 `base_effect`。`ComboFinisherCatalog` 只匹配相同順序的完整
三招；AAA 與 ABC 都是合法配方，但任何 required skill 未學會時不得排入終結技。

跨 authority 的 add／fuse／exact removal 不再由 `Game` 分別呼叫
`MetaState`、`RunState` 與 `DeckManager` mutation API，而統一經
`CardCollectionService`。三者仍保有各自的資料責任；service 只協調同一
`CardInstance` object identity 與失敗 rollback。

### 9.5 Static、runtime、UI例

```text
cards.json "ember_bolt" base card
→ CardDatabase immutable copy
→ RunState card level
→ Game applies level/equipment/infusion effect
→ CardHandUI receives display Dictionary
→ CardEffectRunner receives cast Dictionary
```

UI改description或disabled state不應回寫CardDatabase。

## 10. Save Data Boundary

### 10.1 Permanent meta save

Path：`user://saves/meta_progress.json`

Owner：

- DTO：`MetaState.to_dict()`
- IO：`SaveService.save_meta()`／`load_meta()`
- orchestration：`Game`

Write flow：

```text
sync managers into MetaState
→ JSON stringify to .tmp
→ read-back parse validation
→ copy old file to .bak
→ replace target by rename
→ remove backup after success
```

Load flow：

```text
open target
→ parse top-level Dictionary
→ MetaState.apply_dict()
→ return normalized MetaState.to_dict()
→ apply manager DTO / legacy fallback
```

Growth choice 的永久 save transaction 由 `Game` 擁有。snapshot 包含完整 Meta
DTO、`CardCollectionService.capture_state()`、Inventory DTO 與 wallet；mutation
或 `SaveService.save_meta()` 失敗時，`Game` 依序 restore Meta、collection 與
inventory，保留原本 pile 順序、cooldown 時間與 instance identity。

### 10.2 Quick save

Paths：

- `user://saves/quick_save.json`
- `user://saves/quick_save.tmp`
- `user://saves/quick_save.json.bak`

Owner：`scripts/managers/game.gd`，不經`SaveService`。

Schema 1 payload：

| Field | Current content |
|---|---|
| `schema_version` | 1 |
| `saved_at` | system datetime string |
| `map_path` | canonical map identity；legacy authoritative paths於 load 時經 `MapRegistry` migration |
| `player` | position + selected player stats |
| `wallet_gold` | prototype wallet |
| `inventory` | prototype player inventory |
| `merchant_catalogs` | runtime shop stock |

Not included：

- full MetaState
- full InventoryManager/TownManager DTO
- full RunState
- DeckManager piles/AP
- card levels/temporary buffs
- encounter/director state

所以quick save不是完整run resume。

Quick-load 必須先以 `MapRegistry.resolve()` 正規化 `map_path`，再檢查
`ResourceLoader.exists()`。Legacy
`res://scenes/maps/autumn_tree/AutumnTreeMap.tscn` 會遷移至 Autumn Forest
canonical identity，再載入 `AutumnBattleMapV2.tscn`；不得直接刪除 path alias。

### 10.3 Backup差異

Meta SaveService在成功後移除backup。Quick save自行copy backup，但load不fallback到
backup。修改其中一條pipeline時不可假定另一條自動同步。

### 10.4 Save安全規則

- 只寫`user://`，不寫`res://`。
- 先寫temporary file並驗證，再replace。
- parse失敗不得覆蓋原存檔。
- migration不得丟失未知但仍需保留的current fields。
- load後每個nested field做type/範圍sanitization。
- save path或map registry變更需old payload test。

## 11. UI Projection 與 Mutation Rules

### 11.1 UI只接projection

| UI | Data source |
|---|---|
| CardHandUI | Game從CardDatabase + RunState產生card copies |
| HUD | Player、RunState、wallet與objective setters |
| InventoryUI | Game `_inventory_projection()` + `_inventory_codex_projection()` |
| ShopUI | Game catalog/owned count projection |
| MaterialYardUI | TownManager workshop + InventoryManager resources |
| PlayerBlacksmithUI | TownManager blacksmith/memory library + InventoryManager equipment/resources |
| TownHallUI | TownManager village/town hall + InventoryManager resources |

UI可以：

- format text/number
- select/filter/page
- emit intent
- keeptemporary selection/focus

UI不可以：

- 修改base catalog
- 直接寫save file
- 決定reward/economy規則
- 自行提升building/equipment而不經domain API

### 11.2 Dedicated Town building UI boundary

Current `Game._open_town_service_ui()` 將同一份 TownManager/InventoryManager
注入三個建築 UI，並把 ForgeService 注入 MaterialYardUI／PlayerBlacksmithUI：

- Material Yard：emit `purchase_requested`，由 ForgeService 驗證火炬 Tier、gold、
  材料 bundle 與永久工具。
- Player Blacksmith：emit craft/list/resolve/Sword Soul upgrade intent；鍛造依
  owned blueprint、required tools、blacksmith level 與 resource cost 驗證。
- Town Hall：`upgrade_building("town_hall")`。

`data/forge_catalog.json` 是 offers/recipes authority。Inventory DTO 額外保存
`equipment_counts`、`owned_blueprints`、`owned_tools` 與單格 `sale_slot` escrow；
legacy `owned_equipment` 載入時遷移為 count。Forge 交易成功時立即同步 manager
DTO 至 Meta 並儲存；關閉 UI 時仍執行最終同步與世界投影。

### 11.3 Projection copy

```gdscript
func get_card(card_id: String) -> Dictionary:
	if not _cards_by_id.has(card_id):
		return {}
	return (_cards_by_id[card_id] as Dictionary).duplicate(true)
```

Consumer可改copy中的runtime `level`或`effect`，不污染catalog。

## 12. Validation、Error Handling 與 Migration

### 12.1 Boundary validation checklist

每個catalog loader至少驗證：

- file exists/open成功
- JSON parse成功
- top-level type
- required root fields
- entry type
- required entry fields
- ID non-empty/unique
- numeric range與whole-number需求
- enum allowlist
- cross-reference
- resource path exists
- 空catalog policy

### 12.2 Failure behavior

Current loader多以`false`／empty result表示失敗。新增或修改loader時，錯誤訊息應包含：

- source path
- entry ID/index
- failed field
- expected type/range

不得parse失敗後默默用部分catalog繼續。Catalog若採all-or-nothing，遇到invalid entry
應clear partial cache。

### 12.3 Schema migration

Current缺少集中migration registry。Schema變更前：

1. 保存舊JSON/save fixture。
2. 定義from/to version。
3. 先寫舊資料載入失敗或behavior test。
4. 實作純migration function。
5. validate migrated result。
6. 保留backup與失敗復原。
7. 更新本文件與Game Design。

不要只在`apply_dict()`塞更多fallback而沒有version判斷。

### 12.4 Test sources

- `tests/content_validation_test.gd`
- `tests/card_system_test.gd`
- `tests/progression_state_test.gd`
- `tests/quick_save_migration_test.gd`
- `tests/town_progression_test.gd`
- `tests/shop_system_test.gd`
- `tests/deck_builder_test.gd`
- `tests/card_combat_integration_test.gd`

## 13. 檔案與 ID 規則

### 13.1 Path

- runtime path使用`res://`。
- save path使用`user://`。
- 不依賴OS absolute path作gameplay identity。
- asset/data move前`rg`所有string references。
- canonical map path與authoritative path都需migration考量。

### 13.2 Stable ID

- ID使用lower snake_case，例如`ember_bolt`, `autumn_wood`。
- display name可改，ID不可任意改。
- ID rename等同save/content migration。
- 不使用array index當persistent identity。
- cross-catalog reference先驗證存在。

### 13.3 Numbers

- cost/resource count：非負或正整數，依domain contract。
- level：有明確min/max。
- ratio/duration：定義範圍與單位。
- UI不得自行改clamp rule；domain owner負責。

### 13.4 Sensitive/local data

不要commit：

- `user://` saves
- `.test_userdata`
- editor cache
- credentials/signing keys
- exported build

## 14. Code Examples

### 14.1 Current JSON dictionary loader

來源：`scripts/systems/card_database.gd`

```gdscript
func _read_json_dictionary(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed as Dictionary if parsed is Dictionary else {}
```

### 14.2 Current catalog copy

```gdscript
func get_all_cards() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for card in _ordered_cards:
		result.append(card.duplicate(true))
	return result
```

### 14.3 Current state DTO

來源：`scripts/systems/inventory_manager.gd`

```gdscript
func to_dict() -> Dictionary:
	return {
		"resources": _resources.duplicate(true),
		"owned_equipment": _owned_equipment.keys(),
		"equipment_levels": _equipment_levels.duplicate(true),
		"equipped": _equipped.duplicate(true),
	}
```

## 15. Scene Tree Example

資料不應由UI Scene擁有；Scene只持有presentation與runtime Node：

```text
Game
├── CardEffectRunner
├── MapRoot
│   └── Map
│       ├── Player
│       └── EncounterDirector
├── HUDLayer
│   ├── HUD
│   └── CardHandUI
└── MenuLayer
    └── MaterialYardUI / PlayerBlacksmithUI / TownHallUI

Game-owned RefCounted state (not Scene children)
├── CardDatabase
├── InventoryManager
├── TownManager
├── MetaState
└── RunState
```

`RefCounted`不是Scene child。文件圖需明確區分SceneTree ownership與object reference。

## 16. Godot Example (Godot 4)

### 16.1 Proposed typed Resource shape（TODO，非Current）

只有在核准Resource migration後才可採用：

```gdscript
class_name CardDefinition
extends Resource

@export var id: StringName
@export var display_name: String
@export_range(0, 99, 1) var cost: int
@export var effect: Dictionary
```

此範例使用Godot 4 `Resource`與typed exports，但目前cards仍以JSON為authority。
導入前必須決定：

- JSON是否保留
- importer/authoring流程
- stable ID與cross-reference
- duplicate/local-to-scene semantics
- save compatibility
- content validation tests

### 16.2 Safe file boundary

```gdscript
func read_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("Data file does not exist: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(
		FileAccess.get_file_as_string(path)
	)
	if not parsed is Dictionary:
		push_error("Expected JSON object: %s" % path)
		return {}
	return (parsed as Dictionary).duplicate(true)
```

## 17. Best Practice

- 先validation，再建立runtime catalog。
- static definition與mutable state分開。
- getter回傳copy，不暴露internal dictionary。
- ID穩定，display name可變。
- MetaState與RunState依lifetime分離。
- 所有save write使用temporary/validation/backup策略。
- UI只收projection並emit intent。
- data/schema改動與tests/docs同一任務完成。
- 未存在Resource/Quest/Dialogue/Audio data明確標TODO。

## 18. Anti Pattern

- 把不存在的`.tres`寫成current source of truth。
- runtime/UI回寫`res://data/*.json`。
- huge Dictionary跨所有layers且無schema。
- 用array index當save ID。
- parse失敗後保存default覆蓋原檔。
- 同一gold transaction只更新其中一份state。
- 把quick save當完整Meta/Run snapshot。
- 新增effect/data key但不查consumer。
- 未migration就rename ID或map path。
- shared Resource直接mutation造成所有instance一起改。

## 19. Data Change Checklist

修改JSON／Resource／save前：

- [ ] 已確認authoritative path與loader。
- [ ] 已列required/optional fields。
- [ ] 已確認ID uniqueness與cross-reference。
- [ ] 已確認數值type、range、unit。
- [ ] 已找出所有consumer與UI projection。
- [ ] 已區分static、runtime、Meta、Run、save。
- [ ] 已準備valid/invalid/old-version fixture。
- [ ] 已確認失敗不覆蓋原存檔。
- [ ] 已更新content/migration/integration tests。
- [ ] 已同步02、06、09、12等相關文件。

## 20. Review Checklist

- [ ] 九個 JSON 仍可由 current loader 成功載入。
- [ ] Catalog count與ID contract符合產品需求。
- [ ] Card icon與cross-reference paths存在。
- [ ] Equipment cost/effect/special ability consumer一致。
- [ ] Town cost resource IDs有效，stage thresholds遞增。
- [ ] Getter沒有洩漏可變internal reference。
- [ ] UI沒有直接修改base catalog。
- [ ] Inventory/Meta/prototype state在mutation後一致。
- [ ] Meta save與quick save schema沒有混稱。
- [ ] Old/malformed payload可安全處理。
- [ ] `.tres/.res`、Quest、Dialogue、Audio等不存在能力未被虛構。
- [ ] Git diff沒有save/cache/build artifact。

## 21. Future Extension

以下為Proposed／TODO：

1. 為equipment/town JSON加入明確schema version與集中validator。
2. 對card effect kind建立data-to-runner allowlist validation。
3. 建立save migration registry，統一meta/quick的IO與backup policy。
4. 統一InventoryManager、Meta legacy fields與prototype inventory。
5. 對成熟catalog評估typed Resource與editor authoring。
6. 建立Quest／Dialogue data前先定義ID、condition、effect與save boundary。
7. 建立Audio catalog前先定義bus、stream ownership與settings persistence。
8. 在CI中驗證JSON schema、resource paths與governance文件path。

## 22. Related Documents

- `docs/README.md`
- `docs/01_AI_GUIDE.md`
- `docs/02_PROJECT_ARCHITECTURE.md`
- `docs/03_SCENE_STRUCTURE.md`
- `docs/05_CODING_STANDARD.md`
- `docs/09_TESTING_GUIDE.md`
- `docs/10_DEBUG_GUIDE.md`
- `docs/12_GAME_DESIGN.md`
- `docs/13_ROADMAP.md`
- `docs/rule_1.md`

## 23. Card Instance Save Contract

Card definitions remain static catalog records keyed by `card_id`. Every owned
or runtime copy is a `CardInstance` with a unique string `instance_id`, its
`card_id`, and an independent level from 1 through 3. `MetaState` schema 6
serializes these copies as `selected_card_instances`; `selected_deck` is kept
only as a card-ID compatibility projection. `permanent_card_levels` is accepted
only while migrating schema-2 saves and is never written as the new authority.

Schema-2 card-ID arrays migrate in source order to deterministic IDs
`legacy-000001`, `legacy-000002`, and so on. Duplicate IDs in schema-3 payloads
are repaired deterministically；schema-3 numeric instance IDs are normalized to
stable strings without dropping cards. `MetaState.get_last_migration_report()` /
`SaveService.get_last_migration_report()` expose conversion and repair counts.
Applying an already migrated payload must be idempotent.

Schema 6 also serializes `auto_attack_card_id`, `learned_skill_ids`, and
`active_skill_ids`. Both skill arrays
are unique string IDs; active is normalized to a subset of learned. Legacy
payloads receive the initial `iron_momentum` learned/active defaults, and an
already migrated schema-6 payload round-trips without changing order or IDs.
The auto-attack ID is a loadout choice, not a selected-deck instance.

`DeckManager` keeps `CardInstance` objects authoritative in hand, draw,
discard, exhaust, and cooldown piles. The legacy string arrays are projections
for callers during integration and must not be mutated. Catalog fields
`play_destination` (`discard`, `exhaust`, or `cooldown`) and
`cooldown_seconds` control post-play routing. Cooldown completion returns the
same instance to discard; paused cooldown clocks do not advance. `ember_bolt`
follows the ordinary `CardInstance` lifecycle. `quickstep` is not a catalog
card and must not be materialized as a `CardInstance`.

Dash is a player-owned action, not card data. Dash Edge and Gale Drive remain
legacy Combo card records with `combat_hand = false`; deck building and rewards
must not prioritize or insert them. If legacy data resolves either card, its
`target_action = "dash"` infusion may temporarily enhance the intrinsic Space
Dash without creating a Dash card in the selected deck, hand, or any pile.

`CardCollectionService` is the cross-authority mutation boundary. New rewards
use `add_persistent_card()`；fusion uses `fuse()`；merchant purge uses
`remove_instance()`. These methods keep the exact `CardInstance` object shared
by MetaState, RunState, and every runtime pile. `capture_state()` /
`restore_state()` include instance levels, unlocked fields, hand/draw/discard/
exhaust/cooldown piles and cooldown timing so partial mutation or save failure
cannot leave only one authority changed.
初期 auto attack balance baseline：Ember Bolt Lv.1 為 16 damage／0.75 秒，
Sprout 與 Hopper 應在未加成時兩發內擊殺。Combo power 每三層提升一階，
每階為當前基礎 attack amount 的 35%，最低 +4，並同步增加射程與尺寸。
彈體數與方向展開都只由 Echo Volley 提供；Lv.1／2／3 分別投射 2／4／8 發，
並由 90° 扇形逐級展開至 360° 圓形。未啟動時維持單方向、單發、單目標；
方向中心固定取玩家當下朝向，不以敵人座標自動瞄準或追蹤；扇形中沒有敵人的方向
視為未命中，不重複命中同一目標。`growth_locked` 卡維持 Lv.1、不可升級或合成；其效果
只能由場外建築與裝備加成。
