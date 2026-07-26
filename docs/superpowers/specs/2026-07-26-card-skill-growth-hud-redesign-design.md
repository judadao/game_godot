# 卡牌、Skill、成長系統與秋季 HUD 重製設計

日期：2026-07-26

狀態：已核准，可進入實作規劃

## 1. 目標

以一套一致的戰鬥成長設計，取代目前以 Block 為核心的 Defense 卡、語意不明的卡牌成長對話框、共用等級的卡牌模型，以及容易跑版的秋季 HUD。

本次重製必須：

- 移除 `defense` 卡牌類型與直接給予 Block 的卡牌玩法。
- 加入可重複使用、具有持續時間的防禦型 Combo 卡。
- 讓所有治療卡在視覺上統一為綠色，並可從資料語意上明確辨識。
- 加入具備記憶容量的 Skill 系統；Skill 只會由成功命中的攻擊卡組合觸發。
- 每一張卡牌副本各自保存等級。
- 用單一、會暫停遊戲的成長 UI，整合新卡獎勵、卡牌升級、滿等融合與資源補償。
- 完整替換秋季戰鬥 HUD，不在現有節點上逐步搬動。
- 城鎮 HUD 維持不變。

## 2. 名詞定義

**Skill** 一詞只代表存放於 Skill 記憶背包中的被動攻擊組合配方，不再用來表示普通卡牌類型。

執行期概念如下：

- **卡牌定義（Card definition）**：以 `card_id` 識別的唯讀 catalog 資料。
- **卡牌實例（Card instance）**：玩家實際擁有的一張卡，具有唯一 `instance_id` 與獨立等級。
- **Combo 卡**：手牌中的主動卡，使用後施加具有持續時間的戰鬥效果。
- **Healing 卡**：以綠色呈現，主要效果為恢復生命的手牌。
- **Skill**：已學會的被動配方；監聽成功的攻擊卡，條件完成時自動產生效果。
- **融合（Fusion）**：依配方消耗兩張不同、已滿等的卡牌實例，生成一張高階 Lv.1 卡牌實例。

現有 `skill` 類型卡必須重新分類。Dash Strike 等攻擊型卡改為 `attack`；純位移或輔助卡改為 `utility`；Healing Light 改為 `healing`。

## 3. 卡牌實例模型

每一張非固定卡副本都要獨立成長：

```text
CardInstance
├── instance_id: String
├── card_id: String
└── level: int
```

因此兩張 Cleave 可以同時分別為 Lv.1 與 Lv.3。所有牌堆區域都必須保留實例身分：

```text
玩家擁有的卡牌實例
├── hand
├── draw pile
├── discard pile
├── exhaust pile
└── cooldown pile
```

牌堆內容不得再簡化為共用的 card ID。卡牌 projection 先透過 `card_id` 取得 catalog 資料，再只套用該實例自己的等級。

固定卡 `ember_bolt` 與 `quickstep` 也會取得穩定實例，讓所有牌堆操作使用相同模型。兩者固定鎖定在 Lv.1，不能成為獎勵、升級、融合、移除、合併或個別卡牌成長的對象。

### 3.1 存檔遷移

舊版 card-ID 陣列依原有順序遷移，每一次出現都建立一個新的穩定 instance ID。舊版共用的 `card_levels[card_id]` 會複製到該定義的每一張遷移實例，避免玩家失去既有進度。

無法辨識的卡牌要保留在可復原的 migration report 中，並排除於目前生效牌組之外，不得靜默刪除。

遷移必須具備冪等性：已經是實例格式的存檔再次載入時，不得產生新的 ID。

## 4. 卡牌分類與防禦型 Combo 卡

移除 `defense` 類型與一般 Block 效果。玩家的防禦改由兩種彼此獨立的限時狀態表示：

- `super_armor`：防止硬直、打斷與擊退，但不降低傷害。
- `damage_reduction`：降低生命傷害，但不防止硬直或打斷。

弱霸體會忽略普通敵人的一般受擊反應；強霸體也會忽略重型受擊反應。明確標記為 Boss 不可抵抗的攻擊可以穿透兩種霸體。

不同來源的減傷可以並存，但總減傷上限為 60%。霸體只採用目前最高等級；同一來源的狀態只刷新時間，不與自己疊加。

第一批 Defense 卡轉換如下：

| 現有 ID | 顯示名稱 | 類型 | 費用 | 效果 | 冷卻 |
|---|---|---:|---:|---|---:|
| `guard` | Iron Will | combo | 1 AP | 弱霸體 4 秒 | 8 秒 |
| `iron_skin` | Stone Form | combo | 2 AP | 30% 減傷 5 秒 | 12 秒 |
| `fortress_stance` | Unbreakable Stance | combo | 4 AP | 強霸體與 40% 減傷 4 秒 | 18 秒 |
| `stoneguard_combo` | Counterguard | combo | 3 AP | 25% 減傷與反擊 6 秒 | 14 秒 |

所有防禦型 Combo 卡皆可重複使用。打出後進入 cooldown pile，不占用手牌位置；冷卻結束後才進入 discard pile。遊戲暫停期間冷卻不得推進。

## 5. 綠色 Healing 卡系

主要用途為恢復生命的卡牌全部使用 `healing` 類型，並共用一致的綠色視覺語言：

- 深翠綠卡身。
- 較明亮的綠色邊框。
- 依子類型使用生命十字、葉片、血滴或靈體圖示。
- 明確標示 `restore`、`regeneration`、`lifesteal` 或 `healing_summon` tag。

第一批轉換與新增內容如下：

| 卡牌 | 治療模式 | 使用後流向 |
|---|---|---|
| Healing Light | 立即回復 | 使用後 Exhaust |
| Renewal Spirit | 多次治療脈衝 | 遵循治療召喚物契約 |
| Blood Pact | 限時吸血 | 可重複使用；進入 cooldown |
| Verdant Renewal | 限時再生 | 可重複使用；進入 cooldown |

立即回復卡使用後 Exhaust，避免 AP 自動回復與重抽形成無限安全治療。再生與吸血可以循環，但同一來源只能刷新持續時間，不能與自己疊加。

Healing 卡可以擁有不依賴攻擊的內容 tag，但永遠不能作為 Skill 配方步驟。

## 6. Skill 記憶系統

### 6.1 所有權與容量

學會的 Skill 是永久進度。啟用中的 Skill 記憶背包使用點數容量，而非固定欄位數：

- 初始容量：10 點。
- 常見自動型 Skill：1 點。
- 中階精確順序 Skill：2–3 點。
- 長連段或強力 Skill：4 點以上。
- 城鎮 Memory Library 透過升級永久擴充容量，容量依序為 10、14、18、24、30。

玩家只能在城鎮或其他明確安全區調整 Skill 背包。

Skill 有三種學習來源：

- Boss、寶箱、任務與特殊商人提供的 Skill Tome。
- 使用永久金錢與素材在城鎮 Memory Library 購買。
- 第一次成功完成秘密攻擊順序時，永久發現隱藏 Skill。

學會不代表啟用。玩家仍須把 Skill 放入記憶背包，且總成本不得超過容量。

### 6.2 配方輸入

只有成功造成傷害的攻擊卡會產生 Skill 配方事件。一張卡即使造成多段傷害，也最多貢獻一次事件。未命中、遭取消或造成零傷害的攻擊不計入。

配方只支援兩種模式：

1. **計數型配方**：在會刷新的時間視窗內，成功使用指定數量的攻擊卡。
2. **精確順序配方**：依照指定的 card ID 順序成功使用攻擊卡。

計數型配方規則：

- 第一次有效攻擊時啟動視窗。
- 每次有效攻擊都把視窗刷新為 8 秒。
- 忽略非攻擊卡。
- 觸發或超時後歸零。

精確順序配方規則：

- 只包含明確指定的攻擊 card ID。
- 使用錯誤攻擊，或成功使用任何非攻擊卡時歸零。
- 若造成錯誤的攻擊剛好是配方第一步，立即把它視為新連段起點。
- 不使用 Healing、Combo、Utility 或泛用 tag 作為替代步驟。

玩家受傷不會重置任何一種配方。

### 6.3 平行追蹤與第一個 Skill

每個已裝備 Skill 都獨立追蹤。同一個攻擊事件可以同時推進多個配方；同時完成的配方可以一起觸發。每個 Skill 有自己的冷卻；完成一個 Skill 不會消耗其他 Skill 的進度。

第一個常見 Skill 為：

```text
Iron Momentum
記憶成本：1
配方：任意成功攻擊卡 ×5
視窗：8 秒；每次有效攻擊刷新
效果：弱霸體 3 秒
冷卻：10 秒
```

## 7. 戰鬥狀態所有權

建立專責的戰鬥狀態控制器，管理：

- 弱霸體與強霸體。
- 減傷與 60% 上限。
- 反擊。
- 再生。
- 吸血。
- 狀態來源身分、持續時間、刷新、到期與暫停行為。

Player controller 在處理受擊反應與傷害時查詢狀態控制器。`Game.gd` 只協調 signal，不擁有狀態數學或配方追蹤。

狀態控制器提供 HUD projection。到期狀態只移除一次；舊 timer 不得清除已被刷新成較新版本的狀態。

## 8. 成長選擇佇列

Autumn Blessing、EXP 升級與 Campfire 卡牌成長邏輯，統一改由一個 queue 與一個權威 `CardGrowthUI` 處理。

成長項目依來源限制功能：

- **Wave Blessing**：只開啟「取得新卡」頁面。
- **EXP Level Up**：開啟「升級」與「滿等融合」頁面。
- 多個待處理項目一次只處理一筆。

每個成長項目只能完成一個操作。

### 8.1 取得新卡

玩家從候選卡牌定義中選擇一張，生成新的 Lv.1 實例。固定卡永遠不會出現。

### 8.2 升級

玩家選擇一張低於 Lv.3 的非固定卡實例。只有該實例提升一級；其他同名副本保持不變。

### 8.3 滿等融合

融合配方必須指定兩種不同的卡牌定義。玩家需各選擇一張 Lv.3 實例。兩張被選中的實例都會被消耗，並加入一張 Lv.1 結果實例，因此牌組張數淨減 1。

第一批融合配方調整如下：

| 第一張 Lv.3 卡 | 第二張 Lv.3 卡 | 生成的 Lv.1 卡 |
|---|---|---|
| Iron Will（`guard`） | Stone Form（`iron_skin`） | Unbreakable Stance（`fortress_stance`） |
| Dash Strike | Cleave | Gale Lunge |
| Frost Bind | Energy Surge | Time Snare |
| Healing Light | Blood Pact | Renewal |
| Battle Focus | Flame Aura | Overdrive |
| Cleave | Flame Aura | Inferno Orb |

移除舊版以 passive 為條件的 evolution 契約。固定卡 Ember Bolt 永遠不能作為融合材料。

### 8.4 資源補償

若 EXP Level Up 沒有合法升級，也沒有可用融合，該次成長改為永久資源三選一：

- 75 gold。
- 12 autumn wood 與 8 stone。
- 4 magic shards。

只有明確設定的 Boss 階級可以用 Autumn Core 替換其中一個選項。玩家選擇後立即存入永久 Meta／Inventory 經濟；即使之後 Run 失敗也會保留。

## 9. 卡牌成長 UI

完成 caller 遷移後，移除目前的 Autumn Blessing 對話框與舊 LevelUpUI。新 UI 是置中、可響應尺寸的 modal，包含：

- 明確的來源標題。
- 只顯示該來源允許的頁面。
- 可捲動的卡牌 grid。
- 每張卡都顯示該實例自己的等級 badge。
- 比較目前效果與升級／融合後效果的詳細面板。
- 先選取、再明確確認的操作流程。
- 鍵盤、控制器與滑鼠一致的 focus 行為。
- 清楚的空狀態與禁用原因。
- 不使用說話者頭像、對話語意或裝飾性 `A` 方塊。

UI 開啟時取得 gameplay pause token。敵人、投射物、波次、AP 回復、卡牌冷卻、Combo 狀態時間與 Skill 視窗全部停止。UI 本身使用 always-processing 模式。

只有當 queue 已清空，且沒有其他 modal 持有 pause token 時，遊戲才會恢復。

關閉 UI、切換 scene 或選擇無效項目時，不得消耗待處理的成長項目。

## 10. 全新秋季戰鬥 HUD

秋季 HUD 重新建立為一個 editor-authored 權威場景。既有秋季 HUD 不採逐步搬移，也不能保留為平行權威。城鎮 HUD 維持不變。

新 Scene Tree 如下：

```text
AutumnCombatHUD
├── TopLeftStack
│   ├── ActiveStatusList
│   └── ObjectivePanel
├── TopCenterStack
│   ├── BossHealth
│   └── SkillToastStack
├── BottomStage
│   ├── PlayerVitals
│   ├── ActionPoints
│   ├── CardStage
│   │   ├── CooldownStrip
│   │   └── AutumnCardHandUI
│   ├── InputGlyphHints
│   └── PersonalResources
```

各區責任如下：

- 左上狀態列顯示效果名稱、圖示與剩餘時間，效果到期後消失。
- 目前目標位於狀態列正下方。
- 只有 Boss 存在時，Boss 血條才占用上方中央。
- Skill 觸發通知顯示在 Boss 區域下方，最多堆疊三列，1.5 秒後淡出。
- 同一個仍可見的 Skill 再次通知時，只刷新原有列。
- 左下顯示頭像、等級、HP、MP、SP。
- 下方中央顯示 AP、冷卻中的卡與兩排手牌。
- 手牌旁只放精簡的牌組切換與全 AP 重抽輸入圖示。
- 右下只保留 gold、EXP 與個人資源資訊。

面板使用半透明深色背景與穩定的 authored Container。HUD 不顯示永久 Skill 配方或進度；玩家必須依靠記憶。

支援的 viewport：

- 1152×720。
- 1280×720。
- 1600×900。
- 1920×1080。
- 2560×1080。
- 2560×1440。

窄畫面會縮短文字與間距，但不得遮擋戰鬥安全區，或把面板移出螢幕。

## 11. 資料與元件邊界

實作將新增或重構下列權威：

- `CardInstance`：穩定身分與序列化。
- `DeckManager`：卡牌實例區域與 cooldown pile。
- `SkillRecipeManager`：已學／啟用 Skill、記憶容量、配方 tracker、冷卻與隱藏發現。
- `CombatStatusController`：限時生存與治療效果。
- `GrowthChoiceQueue`：依來源限制的待處理成長與 pause 所有權。
- `CardGrowthUI`：成長顯示與選擇 signal。
- `AutumnCombatHUD`：僅供秋季使用的排版與狀態 projection。

靜態內容維持資料驅動：

- `data/cards.json`：重新分類的卡牌定義與效果欄位。
- `data/skills.json`：Skill 成本、取得方式、配方、效果與冷卻。
- `data/evolutions.json`：兩張滿等卡的融合配方。
- `data/town_upgrades.json`：Memory Library 等級與資源成本。

UI 只接收不可變 projection 並發出選擇 signal，不得直接修改卡牌實例、Skill 背包、狀態或永久資源。

## 12. 錯誤處理

- 無效卡牌實例必須回報 instance ID 與 catalog ID，並從生效牌堆中排除，但不得刪除其序列化記錄。
- 無效 Skill 配方或記憶成本在 catalog 載入時拒絕。
- 重複 instance ID 必須讓 migration validation 失敗，並取得記錄於 migration report 的 deterministic 替代 ID。
- 融合在實際修改前，必須再次驗證兩張被選中的實例。
- 成長操作失敗時，queue 項目保持待處理，並顯示可理解的錯誤。
- Pause token 使用 reference count，避免一個 modal 恢復另一個 modal 暫停的遊戲。
- Scene teardown 必須清除 HUD subscription 與狀態 callback，不得套用尚未確認的 queue 操作。

## 13. 測試

自動化契約必須證明：

- 卡牌副本擁有獨立等級，且 ID 經過存檔／載入後保持穩定。
- 舊共用等級存檔可以 deterministic、idempotent 地遷移。
- 每個牌堆區域都保留卡牌實例身分。
- 冷卻卡離開手牌，只在遊戲運作時倒數；暫停期間凍結，完成後透過 discard 回歸。
- 驗證後的卡牌分類不再包含 Defense。
- Healing 卡使用綠色語意類型與正確 lifecycle。
- 霸體與減傷彼此獨立、可正確刷新，且遵守 60% 上限。
- 計數型與精確順序型 Skill 分別遵守自己的中斷規則。
- 一次攻擊可推進多個 Skill；同時完成時會觸發所有合法效果。
- 非攻擊卡不重置計數型配方，但會重置精確順序配方。
- Growth 頁面依來源受到限制。
- 升級只修改被選中的單一卡牌實例。
- 融合只消耗兩張被選中的 Lv.3 實例，並建立一張 Lv.1 結果。
- 無法進行 EXP 卡牌成長時會提供永久資源選擇。
- 固定卡不會出現在獎勵、升級或融合候選中。
- 排隊中的成長會暫停所有 gameplay clock，且只有所有 modal owner 釋放 pause 後才恢復。
- 新秋季 HUD 適用所有支援 viewport，且 Town HUD identity 不變。

人工驗證必須擷取 1280×720 與 2560×1440 下的兩個作用中牌組、作用中狀態列、堆疊 Skill toast、冷卻卡、每一個 Growth UI 頁面、長卡牌文字、控制器 focus 與資源補償。

## 14. 非目標

- 不重製 Town HUD。
- 不建立自由格式 Combo DSL、可選步驟、分支配方，或計數／精確卡牌順序以外的輸入時序。
- 戰鬥中不顯示 Skill 進度條或永久配方提示。
- 不允許沒有 authored recipe 的任意卡牌融合。
- 固定卡不能升級或融合。
- 不改變 Q/W/E/R 卡牌啟動方式。

## 15. 完成條件

只有在下列條件全部成立時，才算完成重製：

- 舊秋季 HUD、Blessing 對話成長、共用卡牌等級權威與過時 LevelUpUI 都沒有 runtime caller。
- Code、scene、catalog、save、test 與治理文件描述相同契約。
- Focused 與 full regression 全部通過，且沒有 Godot error marker。
- Editor、main scene、秋季地圖、Growth UI 與 combat preview smoke check 通過。
- 所有必要 viewport capture 都已人工檢查。
- 沒有重複 UI 權威或暫時 capture script。
