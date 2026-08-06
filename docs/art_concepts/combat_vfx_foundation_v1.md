# Combat VFX Foundation v1

本文件記錄現役戰鬥特效的共用製作流程。教學是最低結構基準，不是最終造型模板；
系列主物體、路徑、配色、爆心形狀與材質節奏仍須依 13 系列分化。

## Public tutorial references

- [Stylized Fire Effect Tutorial](https://youtu.be/R3xMwfrlTI8)：靜態火焰粒子 → Visual Shader → billboard → dissolve → 動態火舌 → 煙 → 漂浮火星。
- [Easy Explosions Effect Tutorial](https://youtu.be/tjSxICUXMmM)：火花 → bright flash → 火焰粒子 → 煙；命中敵人與撞地共用模組，但方向、重力與殘留不同。
- [Slash Effect Tutorial](https://youtu.be/Q3V5HIrO11Y)：斬擊面 → 暗色厚拖尾 → 明亮細核心 → scrolling material → stretched particles。
- [Hits and Impacts Effect Tutorial](https://youtu.be/uDjR7F-aOsc)：flash → flare → shockwave → sparks，以接觸瞬間為共同時間錨點。

原教學以 Godot 3D 粒子為主；本專案保留相同分層與時間流程，轉成 side-view 2D
`Line2D`、`Polygon2D`、`CPUParticles2D` 與 canvas shader，不照搬付費 texture。

## Runtime composition

`CombatVFXFoundation` 是 `NamedSkillVFX.play_series()` 的 presentation child：

1. `dark_slash_trail` 提供厚暗外輪廓，避免亮線漂浮。
2. `bright_slash_core` 使用更快的 UV scroll，建立速度與鋒利接觸點。
3. `impact_flash` 與 `impact_flare` 只在真實 impact beat 短促出現。
4. `impact_shockwave` 交代力量擴散，`impact_sparks` 延續實際攻擊方向。
5. 火系額外疊 `flame_body`、dissolve shader、煙與漂浮火星；爆心再獨立疊火焰與煙，
   之後可用同一 attachment API 套在角色、單一招式物件或 Town 火炬。

## Series differentiation

共用 layer 只解決基本完整度；不可讓 13 系列共用一種輪廓。各系列仍由
`skill_series_vfx.json.motion_family` 決定主物體軌跡，並以不同 impact style 呈現：
垂直劍星、月牙交叉、羽星、根脈門、地面碎裂、正面盾衝、火焰開花、分叉雷光、
浪冠、荊棘花、龍息錐、朝陽十字與雙源交叉。

## Timing contract

- anticipation：只有蓄勢與極低亮度材質，不先爆光。
- execution：暗拖尾先出，亮核心後追，主物體保持最清楚。
- impact：flash／flare 先峰值，shockwave 與 sparks 緊接；火焰爆心稍晚展開。
- decay：核心先滅、煙與碎屑後收；所有 layer 必須由 owner 自動清理。
- VFX 不擁有傷害、目標、Combo 或玩家移動權威。
