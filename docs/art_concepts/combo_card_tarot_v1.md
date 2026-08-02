# Combo／Healing 劍魂卡圖：暗黑塔羅 v1

## 產圖模式與用途

- 工具：OpenAI built-in image generation。
- 日期：2026-08-02。
- 用途：20 張能參與 `combo_finishers.json` 公式的 Combo／Healing 劍魂卡圖。
- Runtime 成品：`assets/ui/autumn/cards/generated/<card_id>.png`，256×256 PNG。
- 文字、快捷鍵、等級、AP 與外框均由 Godot 即時排版，不烘進卡圖。

## 使用者參考圖

- `C:\Users\harry\Downloads\21fda9e00d3c6c8f02b692d8732c57b9.jpg`
- `C:\Users\harry\Downloads\f5572998b52ef175402c28f34685bc1d.jpg`
- `C:\Users\harry\Downloads\87453f89f1be7bfc1923b2cffebb4dd0.jpg`
- `C:\Users\harry\Downloads\5704525fd1729b4e3e834d2031ce6044.jpg`

四張只作高階風格參考：深色底、舊金線刻、中軸塔羅構圖、Art Nouveau 天體幾何與
限色裝飾畫。所有主體與構圖皆重新設計，不複製參考圖中的狼群、星盤、神像或字樣。

## 共用 prompt

```text
Create one original square 1:1 standalone fantasy game card illustration for
the named sword-soul skill. Use the supplied images only as high-level style
references: midnight-black ground, antique-gold engraved linework, centered
occult tarot symmetry, Art Nouveau celestial geometry, controlled woodcut
hatching, lightly distressed old-print texture, a limited palette, one dominant
semantic emblem, strong silhouette and large readable shapes. Artwork fills the
canvas. No outer card frame, UI chrome, text, letters, numbers, pseudo-runes,
logos, or watermark. Keep the primary motif instantly readable at 44 px. Avoid
photorealism, 3D render, noisy micro-detail, excessive radial spokes,
meaningless repeated ornaments, mushy texture, broken geometry, false seams,
smooth CGI gradients, generated-looking glyphs, and unrelated props.
```

## 每張卡的 subject／palette prompt set

| ID | 中文名 | Subject | Palette |
|---|---|---|---|
| `battle_rhythm` | 強攻律動 | 直劍擊中戰鼓，三圈清楚節拍衝擊環 | 鐵鏽紅、赭褐、舊金 |
| `sweeping_reach` | 橫掃延伸 | 小劍居中，單一道巨大水平月牙斬橫跨畫面 | 靛藍、象牙、舊金 |
| `quickened_cadence` | 加速節拍 | 節拍針、主劍與三層錯位劍影 | 深藍、銅橘、舊金 |
| `giant_arc` | 巨型弧斬 | 巨型上弦月刃壓過小型直劍，表現尺度差 | 黑紫、灰藍、舊金 |
| `echo_volley` | 回聲齊射 | 一把中央劍分出兩道 90° 劍氣，背後三圈回聲 | 藍紫、煙灰、舊金 |
| `guard` | 鋼鐵意志 | 單劍、圓盾與單層封閉護環 | 鐵灰、深褐、舊金 |
| `iron_skin` | 石之形 | 五塊大型互鎖石甲包覆暗色核心 | 岩灰、灰褐、暗金 |
| `iron_bone` | 鐵骨 | 劍形鐵脊與三對完整肋拱 | 炭黑、骨白、舊金 |
| `fleet_footwork` | 疾風步 | 古護脛、單翼與兩道連續風帶 | 墨綠藍、鼠尾草、舊金 |
| `arcane_breath` | 奧術吐息 | 單一龍首向中央法球吐出紫藍雙螺旋 | 深紫、青藍、舊金 |
| `deep_reservoir` | 深層蓄能 | 無底深井／蓄能容器、青藍能量柱與三圈容量環 | 群青、青藍、舊金 |
| `stoneguard_combo` | 反擊守勢 | 石銅圓盾承受紅色斬擊，再反射一道金色斬擊 | 石灰、暗鏽紅、舊金 |
| `flame_imbue` | 烈焰灌注 | 單劍被三束橙紅火舌螺旋灌注 | 深紅、餘燼橘、舊金 |
| `frostburst_imbue` | 霜爆灌注 | 單劍核心與對稱六向冰晶爆發 | 灰藍、冰白、舊金 |
| `storm_charge` | 風暴充能 | 單劍、上方雷球、兩道主閃電與電環 | 靛藍、冷白、舊金 |
| `venom_edge` | 劇毒刃 | 一條頭尾清楚的蛇纏住單劍，四枚毒滴 | 墨綠、暗黃綠、舊金 |
| `healing_light` | 治癒之光 | 金綠四瓣葉形聖光與翠綠核心 | 象牙、淡金、青綠 |
| `renewal` | 復甦之靈 | 無臉葉焰精靈、雙葉翼與三圈治療漣漪 | 鼠尾草綠、乳白、舊金 |
| `blood_pact_combo` | 血之契約 | 兩股生命流締結非解剖式紅寶石心核 | 酒紅、骨白、舊金 |
| `verdant_renewal` | 翠綠復甦 | 金色種子長出正好五片分離翠葉與生命螺旋 | 苔綠、嫩葉綠、舊金 |

## 審查證據

- 最終 256px contact sheet：`artifacts/combo_card_final_review/combo_card_contact_256.png`
- 44px 縮圖：`artifacts/combo_card_final_review/combo_card_contact_44.png`
- 六解析度完整 HUD：`artifacts/combo_card_final_review/full_frames/`
- 1920×1080 固定 3×2 六切片：`artifacts/combo_card_final_review/slices_1920x1080/`

獨立 reviewer 檢查 full-frame、最終原生尺寸、44px 與六切片，項目包含假字、重複
填充、材質頻率漂移、破損幾何、假接縫、糊爛紋理、卡意誤讀及同套美術一致性。
