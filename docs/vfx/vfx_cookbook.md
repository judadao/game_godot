# Reusable 2D Pixel VFX Cookbook

This library is presentation-only. It exposes color, intensity, lifetime, scale, speed,
direction, particle amount, noise and glow, and it never owns damage, targets or status rules.
Every primitive has a runnable scene under `scenes/vfx/demos/`.

## What was extracted from the references

- Particles: `GPUParticles2D` is the advanced 2D system. Use `ParticleProcessMaterial` for
  direction, spread, velocity, gravity, scale and color-over-life; use a particle shader only
  when stateful custom motion is necessary. Sources: [2D particles](https://docs.godotengine.org/en/stable/tutorials/2d/particle_systems_2d.html),
  [ParticleProcessMaterial](https://docs.godotengine.org/en/stable/tutorials/2d/particle_process_material_2d.html).
- Fire: height narrows the silhouette toward the tip, upward animated noise breaks the edge,
  and a heat scalar chooses a compact inner/outer palette. A complete fire is still split into
  core, outer flame, embers, smoke and glow. Sources: [Best 2D Fire](https://godotshaders.com/shader/best-2d-fire/),
  [pixel fire](https://godotshaders.com/shader/simple-pixelated-fireshader/),
  [procedural torch layers](https://godotshaders.com/shader/procedural-torch-candle-shader-fire-smoke-sparks/).
- Lightning: animated noise makes a surface arc; midpoint subdivision makes a deterministic
  A-to-B bolt and branches. The alpha comes from core/glow distance so no black rectangle is
  emitted. Sources: [FBM lightning](https://godotshaders.com/shader/lightning/),
  [2D electric arc](https://godotshaders.com/shader/2d-lightning-electric-arc-plasma/),
  [transparent lightning](https://godotshaders.com/shader/transparent-lightning/),
  [Godot goodies](https://github.com/nezvers/Godot_goodies).
- Water: small noise displacement, independent moving wave bands and a limited deep/body/foam
  palette produce water. Screen refraction is optional and should be reserved for larger water
  bodies; splashes remain particle-driven. Sources: [CanvasItem water](https://godotshaders.com/shader/water-shader-by-hexagonnico/),
  [2D refraction](https://godotshaders.com/shader/2d-water-distortion-effect-godot-4/),
  [wave examples](https://godotshaders.com/shader-tag/wave/).
- Poison: drifting cloud silhouettes reuse layered noise while bubbles need a clear rim and
  transparent center. Corrosion mixes a noise mask with direction, keeps a colored edge band,
  then removes alpha. Sources: [dissolve collection](https://godotshaders.com/shader-tag/dissolve/),
  [advanced 2D dissolve](https://godotshaders.com/shader/more-advanced-simple-2d-dissolve/),
  [bubble collection](https://godotshaders.com/shader-tag/bubble/).
- Ice: mist is a slow continuous drift; shards use radial velocity, angular velocity, gravity,
  a shrinking scale curve and a short glint/impact layer.
- Wind: direction must be visible in the curve and history trail. Several offset tapered lines,
  sparse motes and one decisive slash/burst read better than a translucent single line.

## Initial library

| Element | Reusable primitives | Required composition |
|---|---|---|
| Fire | `fire_loop`, `fire_burst`, `fire_trail` | Glow, FireCore, OuterFlame, Embers, Smoke |
| Lightning | `lightning_bolt`, `electric_arc`, `lightning_impact` | Glow, MainBolt, BranchBolts, Sparks, ImpactFlash |
| Water | `water_stream`, `water_splash`, `wave_arc` | MainBody, Highlight, Foam, Droplets, Mist |
| Poison | `poison_cloud`, `poison_bubble`, `poison_splash` | MainCloud, DarkInnerCloud, Bubbles, Droplets, Corrosion |
| Ice | `ice_mist`, `ice_shard`, `ice_shatter` | Mist, CrystalCore, Shards, Glint, ImpactFlash |
| Wind | `wind_stream`, `wind_slash`, `wind_burst` | Airflow, SlashCore, Trail, Motes, ImpactFlash |

## Assembly rule

Skills compose and arrange these primitives; they do not fork them. A fire skill may combine a
trail during travel, a burst at contact and a loop for residue. The skill supplies timing and
placement only. Gameplay systems remain the authority for hit detection and elemental effects.

## Skill VFX Grammar

Current skills are recipes over fifteen roles: `Core`, `Trail`, `Arc`, `Beam`, `Bolt`, `Ring`,
`Burst`, `Impact`, `Projectile`, `Orbit`, `Rain`, `Aura`, `Ground Zone`, `Afterimage`, and
`Distortion`. `SkillVFXRecipeCatalog` owns one recipe for each of the 13 current series.
`SkillVFXComposer2D` receives the recipe, tier and Blessing overlays, then drives every visual
layer from the same normalized timeline as `NamedSkillVFX`.

The existing transparent series texture is retained as the Core, never treated as a GIF and
never deleted. `skill_vfx_stack.gdshader` is the Core's single combined material pass for palette,
bounded UV distortion, noise, glow and dissolve. Independent geometry/particle children supply
the other roles. This avoids trying to attach several CanvasItem materials to one sprite.

Blessing mutations are a stack of data, not separate redraws. Every supported element can alter
palette, visible copy count, path curvature/forks, trail primitive, impact primitive and ground
residue. Production casts default to currently owned Blessings when a skill has no explicit
overlay projection. This visual stack never changes damage or status authority.

Standalone composition scenes are `slash_vfx_demo`, `fireball_vfx_demo`,
`lightning_strike_vfx_demo`, `area_burst_vfx_demo`, and `moon_wheel_vfx_demo`. They contain no
`AnimatedSprite2D` and exercise the production composer with existing Core art.

Repository study informed the structure but no third-party art was copied. The useful patterns
were GDQuest's multi-node timeline/cleanup, the simple multi-effect decomposition in
`godot-visual-effects`, and VFEZ's single generated shader approach to effect stacking. The
single-particle examples in `GODOT-VFX-LIBRARY` are parameter references, not this project's
quality or layering baseline.
