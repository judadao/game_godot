# 完整地圖編輯入口

## Town

完整 Town 編輯入口：

```text
res://scenes/maps/town/TownMap.tscn
```

在 Godot FileSystem 雙擊 `TownMap.tscn`。這個 Scene 會顯示完整背景、地面、
建築、街道道具、NPC、傳送入口、出生點、碰撞、HUD／卡牌預覽與
`EditorHelpers`。

可直接展開並調整：

- `ParallaxBackground`
- `Buildings` 與各建築
- `Ground`
- `Props`
- `Portals` 與各入口
- `NPCs` 與各 NPC
- `WorldCollision`
- `EditorHUDReference/HUD`
- `EditorHUDReference/CardHandUI`
- `EditorHelpers`

## 秋天樹

完整秋天樹編輯入口：

```text
res://scenes/maps/autumn_tree/AutumnTreeMap.tscn
```

在 Godot FileSystem 雙擊 `AutumnTreeMap.tscn`。這個 Scene 會顯示完整背景、
地形、平台、裝飾、Player、初始敵人、波次控制器、寶箱、營火、捷徑、商人、
回城／前進入口、碰撞、HUD／卡牌預覽與 `EditorHelpers`。

可直接展開並調整：

- `HiddenBranchCache`
- `ForestRest`
- `ShortcutLever`
- `TownPortal`
- `ForwardPortal`
- `WanderingCardMerchant`
- 各物件的 `InteractionArea`
- `EditorHUDReference/HUD`
- `EditorHUDReference/CardHandUI`
- `EditorHelpers`

## 編輯與單獨測試

1. 只使用上面兩個 `*Map.tscn` 作為完整地圖排版入口。
2. 在 Scene Tree 選取實例根節點可調整 Position、Rotation、Scale、Z Index。
3. 已標記 Editable Children 的節點可展開調整碰撞、互動範圍與內部版面。
4. 紅線是完整地圖邊界；黃線是初始／戰鬥相機安全畫面。
5. `EditorHelpers` 與 HUD 參考只在編輯器顯示，正式執行不參與碰撞或輸入。
6. 按 F6 可單獨執行目前主地圖 Scene；Player、Camera 與碰撞均已包含。
7. 正式遊戲會採用主 Scene 內的 HUD／CardHandUI，不會再建立第二份。

`town.tscn` 與 `autumn_forest.tscn` 是可重用內容基底，不是主要編輯入口。
