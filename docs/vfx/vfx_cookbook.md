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

Lightning has two distinct topologies and they must not be conflated. A chain hop is a short-lived
conductive event between two real gameplay endpoints: a narrow moving head reveals the displaced
path, then glow, colored body and white-hot core coincide for one discharge before disappearing.
It is not a persistent trail. A residual mark does not draw the route at all; several short arcs
crawl around each marked body's local silhouette while a single focus and bounded spark burst jump
rapidly between marks. The delayed sky strike is authored separately as `pre-ionization → top-down
main bolt → secondary branch → white contact exposure → sparks → ground-crawling residue → fade`.
Its actual spawn remains owned by the controller's `final_strike` signal. The reusable lightning
shader combines transparent additive core/glow distance with quantized current noise; procedural
path regeneration supplies silhouette change, while particles supply detached sparks. This keeps
shader noise, Line2D geometry, and GPUParticles2D in separate visual roles. Moving residual marks
receive presentation-only target positions every frame. Their 0.22-second sparks use a bounded,
world-space emitter pool sized from `duration / (target_count × hop_count)`, so a fast focus jump
cannot restart or drag the previous burst. Chain events spawn only `lightning_bolt`; only the delayed
`final_strike` event spawns `lightning_impact`, whose sparks remain disabled until ground contact.
Bolt length is derived from the complete gameplay endpoint distance without clamping; only lateral
noise and thickness are bounded. Residual targets retain the gameplay controller's nearest-first node
ordering; only after selection are Hurtbox centers converted through the presentation root's inverse
transform, so target caps stay synchronized while mirrored and non-unit skill scales cannot move the
visible current away from the target.
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

## Attack rhythm and visual-quality rule

The reference tutorials were reviewed as timing and composition studies, not as effects to
copy. Their useful common structure is that a readable silhouette appears before decoration,
and contact is split into four visible beats instead of making every layer expand together:

1. `contact_flash`: a short, high-value core establishes the exact hit point.
2. `shape_expansion`: the main slash, ring, flame body, bolt or splash establishes direction and
   element.
3. `secondary_debris`: sparks, droplets, shards, embers or corrosion fragments inherit the
   impact direction with controlled randomness.
4. `residual_fade`: smoke, mist, ground scar, afterglow or dissolve closes the motion without a
   hard GIF-like disappearance.

`LayeredVFXPrimitive2D` offsets these layer phases and gives flash, body and residue different
scale and alpha envelopes. More particles are not a substitute for these beats. Each skill is
reviewed in this order: main-object silhouette, gameplay cadence, contact placement, material
flow, then secondary decoration. Iteration must fix the earliest failing layer before increasing
counts or glow.

Sources studied: [stylized fire](https://youtu.be/R3xMwfrlTI8),
[explosions](https://youtu.be/tjSxICUXMmM), [slash](https://youtu.be/Q3V5HIrO11Y),
[hits and impacts](https://youtu.be/uDjR7F-aOsc), and
[Godot 2D particles](https://docs.godotengine.org/en/stable/tutorials/2d/particle_systems_2d.html).

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

Sword Rain is the first series-specific renderer over this grammar. The generic Composer still
owns its recipe and Blessing projection, but suppresses generic `Rain`, `Trail`, `Ring`, and
`Impact` drawing because connecting blade positions into one polyline produced meaningless
geometry. `SwordRainMaterialVFX2D` instead keeps every authored sword texture readable and gives
each blade an animated energy-edge material, a three-layer trail (outer energy, colored body,
white cutting core), and its own insertion stack (directional contact flash, shards, ground scar,
sword afterglow, pooled sparks). Its timeline is explicitly staged as staggered summon, orbit
gather, lock charge, snap release, insertion hold, and afterglow decay. Sword Rain uniquely starts
at ten blades; its 10/15/20 growth is grouped into two/three/four five-blade volleys rather than
arbitrary scatter. Runtime playback takes a live enemy provider, aims at Hurtbox centers, and
retargets a surviving nearby enemy when a locked target leaves the tree. Generic `Projectile` is
also suppressed so no unrelated blue connector survives beside the authored blade trails.

Feather is the second series-specific renderer. `FeatherHaloMaterialVFX2D` suppresses generic
`Projectile`, `Trail`, `Afterimage`, `Ring`, and `Impact` drawing while preserving the authored
sacred-feather silhouette. Each root faces the player as the cores enter a player-owned halo one
at a time, rotate with two independent arc trails and an energy aura, then dissolve during a
configurable tail window. Recasting Feather refills that halo instead of stacking another
short-lived effect. Lifetime, fade, summon stagger, orbit speed and all three tier radii remain
catalog data; an authored two-layer full ring and thicker per-feather trails keep the contact area
readable. The separate gameplay controller periodically damages and pushes Hurtboxes that touch
the ring; feathers never home or fly at targets. This component owns presentation only.

Blessing mutations are a stack of data, not separate redraws. Every supported element can alter
palette, visible copy count, path curvature/forks, trail primitive, impact primitive and ground
residue. Production casts default to currently owned Blessings when a skill has no explicit
overlay projection. This visual stack never changes damage or status authority.

`SeriesImpactVFXRouter` reconnects those primitives to gameplay truth. It listens to controller
signals such as pillar eruption, chain hop, residual sky strike, wave contact, thorn volley,
swamp pulse, drone shot/crash, Black Hole detonation and healing pulse. Fire/Dragon use
`fire_burst`; Lightning uses an A-to-B `lightning_bolt` plus `lightning_impact`; Water uses
`water_splash`; Thorn/Swamp use `poison_splash`; Moon/Feather/DR. Stone/Dawn/Shared Branch use
palette-authored wind slash/burst components. Blessing overlays mutate the spawned primitive's
palette, noise, density and glow. Fixed normalized-timeline decorations must not impersonate a
real hit.

Standalone composition scenes are `slash_vfx_demo`, `fireball_vfx_demo`,
`lightning_strike_vfx_demo`, `area_burst_vfx_demo`, and `moon_wheel_vfx_demo`. They contain no
`AnimatedSprite2D` and exercise the production composer with existing Core art.

Moon Wheel is an exception to the usual history-trail recipe. Its readable body is the concrete
silver crescent, so the travel path must never be drawn as a permanent `Line2D`. The specialized
renderer uses bounded, piecewise-linear pinball reflection: alternating wheels launch from opposing
sides, reflect independently from the upper/lower and left/right bounds, and retain only two short
material afterimages measured at fixed 22/44px world distances, so faster tiers do not stretch the
echoes into duplicate projectiles. Every wheel owns a close shader aura plus a broader radial bloom; both light
layers follow that exact wheel rather than sharing a stationary scene glow. A boundary contact
briefly compresses the wheel and brightens both carried lights, then emits a white-hot diamond,
directional moon chips, and a per-wheel pooled particle burst before the wheel accelerates away.
Particle bursts trigger only when that wheel crosses a horizontal rebound segment, so vertical
flashes can add motion without continuously restarting the residue. Gameplay contacts use a
staggered rebound volley instead of resolving every wheel on one frame; overdue contacts remain in
a bounded backlog and release across later frames. The authored
cadence is `materialize → accelerate → wall contact → rebound release → residual dissolve`; visible
guide arcs, rebound rails, and full-path ribbons are forbidden.

Repository study informed the structure but no third-party art was copied. The useful patterns
were GDQuest's multi-node timeline/cleanup, the simple multi-effect decomposition in
`godot-visual-effects`, and VFEZ's single generated shader approach to effect stacking. The
single-particle examples in `GODOT-VFX-LIBRARY` are parameter references, not this project's
quality or layering baseline.
