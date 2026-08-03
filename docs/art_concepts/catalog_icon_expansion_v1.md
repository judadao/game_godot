# 劍魂／招式／裝備圖示補完 v1

## 範圍

- 產圖工具：OpenAI built-in image generation；每個資產各自產生一次，不拼接後裁切。
- 日期：2026-08-03。
- 劍魂卡：`assets/ui/autumn/cards/generated/`，共 38 張；本批補 18 張。
- 招式：`assets/ui/skills/generated/`，共 4 張。
- 終結技：`assets/ui/finishers/generated/`，共 32 張。
- 裝備：`assets/ui/equipment/generated/`，共 10 張。
- 所有 Runtime 成品為 256×256 PNG；名稱、等級與 UI 外框皆由 Godot 排版，不烘進圖示。

## 劍魂與招式共用 prompt

```text
Create one original square 1:1 standalone fantasy game icon for the named
sword-soul card, skill, or finisher. Match the established sword-soul set:
midnight-black ground, antique-gold engraved linework, centered occult tarot
symmetry, Art Nouveau celestial geometry, controlled woodcut hatching, lightly
distressed old-print texture, limited accent colors, one dominant semantic
emblem, strong silhouette and large readable shapes. Artwork fills the canvas.
No outer card frame, UI chrome, text, letters, numbers, pseudo-runes, logos, or
watermark. Keep the primary motif instantly readable at 44 px. Avoid
photorealism, 3D render, noisy micro-detail, meaningless repeated ornaments,
mushy texture, broken geometry, false seams, smooth CGI gradients, and
generated-looking glyphs.
```

每張圖依資料名稱加入單一具體主體，例如 Cleave 使用橫向劍弧、Frost Bind 使用冰封
鎖鏈、Grand Strategy 使用棋盤與指揮劍、Inferno Cremation 使用火葬甕與烈焰劍；配色
只使用能說明元素或功能的少量火紅、冰藍、風綠、雷紫或治療綠。

## 裝備共用 prompt

```text
Create one original square 1:1 isolated fantasy RPG equipment icon for the
named item. Use a hand-painted storybook game-asset style with a strong clean
silhouette, deep ink outline, large material clusters, limited value steps,
coarse broken brushwork, and restrained highlights. Show exactly one complete
item, centered and fully inside the canvas, readable at 44 px. Transparent
background. No scenery, pedestal, UI frame, text, letters, numbers, logo,
watermark, extra equipment, detached fragments, photorealism, smooth CGI, or
noisy micro-detail.
```

裝備依名稱維持清楚材質與類型：鐵劍、獵弓、學徒杖、皮甲、鎖甲、法袍、迅捷戒、
活力護符、專注項鍊與商人印章。生成後以綠幕去背流程保留完整透明度與乾淨邊緣。

## 驗收契約

- 劍魂卡、招式、終結技保持同套暗黑舊金塔羅語彙，44px 仍能由主輪廓互相區分。
- 裝備使用透明背景，44px／52px 仍能分辨物件種類，沒有綠邊或碎片。
- 最終需獨立 reviewer 檢查原生尺寸 contact sheet、實際 HUD／圖鑑全畫面，以及
  1920×1080 固定 3 欄 × 2 列的六切片；任何視覺修改後重新審查。
