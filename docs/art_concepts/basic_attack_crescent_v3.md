# Premium Basic Attack Crescent V3

## Purpose

`assets/generated/vfx/basic_attack_crescent_quality_atlas_v3.png` 是普通劍氣的
高品質加法混色部件 atlas。它不取代 deterministic v2 silhouette sheets；runtime
以 `PremiumCrescentLayer` 將 atlas 部件疊在 v2 的 release／travel／impact 骨架，
提升流體紋理、刃口亮度、速度拖尾與命中碎裂。

## Atlas contract

Atlas 為純黑底、4×2 等分格；runtime 依 texture 實際尺寸計算 cell，不依賴固定
輸出解析度。

| Cell | Part | Runtime use |
|---:|---|---|
| 0 | outer glow | 蓄勢、飛行外側柔光 |
| 1 | moon core | 白熱空心月牙刃心 |
| 2 | inner current | 與 core 不同相位的青藍能量流 |
| 3 | flow ribbons | 三個歷史位置的速度飄帶 |
| 4 | ground cut | 出劍與命中的貼地切線 |
| 5 | spark debris | 飛行碎光與命中粒子 |
| 6 | contact bloom | 方向性命中爆點 |
| 7 | decay fragments | 命中後破碎月牙與流光 |

黑底是 runtime additive blending 的技術底色，不轉成透明圖；各 cell 不得出現人物、
武器、場景、文字、格線或跨格內容。

## Generation provenance

- tool：built-in image generation
- use case：`stylized-concept`
- reference：使用者提供的高月牙白青藍劍氣概念圖，只作造型、分層與動勢參考
- output：`basic_attack_crescent_quality_atlas_v3.png`

Final prompt：

> Derive a premium flowing crescent sword-energy effect from the reference image,
> but output only isolated reusable VFX components, never the character or
> environment. Use an exact 4 columns by 2 rows atlas on a flat pure black
> background. Cell order: outer crescent aura, white hollow moon core, cyan inner
> currents, backward speed ribbons, ground cut, spark shards, directional contact
> bloom, fading crescent fragments. All parts face right. Preserve the hollow `)`
> silhouette, white/cyan/deep-blue layered anime VFX brushwork, sharp tips and
> luminous flow. Avoid arrows, missiles, flames, solid blobs, full circles,
> characters, weapons, scenery, text, borders and watermarks.
