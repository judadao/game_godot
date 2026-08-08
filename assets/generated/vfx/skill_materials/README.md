# Skill Series Raster Materials

These RGBA plates are presentation-only sources for the production
`SkillVFXComposer2D` stack. Each base plate preserves the visual identity of one
of the 13 skill series. Each Blessing plate contains one canonical elemental
material overlay.

The runtime composes `13 base + 8 element overlays`; it does not duplicate 104
complete Skill × Blessing atlases. Evolved Blessings remain one Gift overlay
while contributing both canonical element plates.

At runtime, each element plate is cropped into separate charge, travel, and
impact sprites. Series-specific scale, rotation, and offset profiles keep those
components aligned with the active skill silhouette.

All generated files use a 1254 × 1254 transparent canvas with three separated
component groups: core/body material, motion/trail material, and contact/debris
material. Artwork must keep transparent corner padding and must not contain
text, logos, frames, characters, or gameplay-readable collision shapes.

Generation mode: built-in image generation, `#00ff00` chroma-key background,
then the imagegen skill `remove_chroma_key.py` helper with despill. The original
three base plates and fire overlay recovered from the interrupted task already
contained true alpha; the remaining files use the same visual contract.

Authoritative paths:

- Series base paths: `data/skill_series_vfx.json`
- Element overlay paths: `scripts/vfx/blessing_vfx_mutation_catalog.gd`
- Runtime presentation: `scenes/vfx/skills/SkillSeriesRasterMaterialVFX2D.tscn`
