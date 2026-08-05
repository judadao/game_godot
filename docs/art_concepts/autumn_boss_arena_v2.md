# Autumn Rain Boss Arena V2

The authoritative footprint is a 1920 x 1664 room with full-height vertical play. The far layer is a
sky-only plate; shrine walls, torii, maples, lanterns, sword graves, and stairs
are independent alpha sprites assembled in the scene. The floor uses three
native-width atlas segments (416 + 416 + 416 + 416 + 256 pixels) without horizontal stretch.

## Intent

The Autumn Rain regional boss room uses a clear central combat stage with seven
reachable perimeter platforms: one crown platform and three stepping platforms
on each side. Platform positions and widths use a fixed seed so the authored
composition remains reproducible while stone and timber surfaces, mirroring,
width, and small offsets vary.

## Layer Contract

- Background: `autumn_boss_background_v3.png`, opaque tapered shrine courtyard composed to the room-proportion reference.
- Midground: `autumn_boss_midground_v2.png`, transparent shrine ruins, lanterns, and grave markers.
- Gameplay: continuous floor, seven reachable perimeter platforms, player, and boss.
- Floor: `autumn_boss_floor_v2.png`, split into four contiguous native-scale atlas tiles with no runtime stretching.
- Foreground: `autumn_boss_foreground_v2.png`, transparent wet grass, stones, and broken swords.
- Boss: `AutumnSixArmColossusBoss.tscn`, assembled from independent upper skull/kabuto,
  lower mandible, torso, pelvis, six upper arms, six forearms, six gripping sword hands,
  eye fire, mouth core, and ghost-fire sprites. It renders behind gameplay platforms and
  does not collide with them.

The room uses a fixed `0.72` overview camera so the central boss stage and all
seven surrounding platforms remain visible above the combat HUD. All raster layers use hard pixel clusters, limited value steps, large readable
color masses, nearest texture filtering, and no smooth gradients or photographic
surface noise.

## Generation Prompt Summary

Built-in image generation used the approved
`autumn_six_arm_oni_key_concept_v2_redlight_ghostfire.png` as the boss identity and
material authority. Production prompts generated a strict body-part atlas, left/right limb
atlas, ghost-fire atlas, six-socket torso with no baked arms, an anatomical single-row
lower mandible, a closed shoulder bearing, and a separate bone-and-iron elbow/wrist knuckle.
Prompts required realistic non-chibi skeletal proportions, black iron, oxidized bronze,
muted crimson cord, crisp controlled pixel clusters, no labels or scenery, and flat chroma
backgrounds. Key sources are preserved beside the transparent production PNGs under
`assets/enemies/bosses/autumn_colossus/`; transparent outputs use soft matte and despill,
then nearest-neighbor clustering reduces microtexture in the runtime copies.

The former `AutumnSmokeOniBoss.tscn` and its generated assets remain intact as a future
elite candidate. The arena only changes `RegionalBossDirector.guardian_scene` to the new
colossus scene.

## Review Evidence

Final graphical captures are written to `artifacts/autumn_colossus_review_final6/`:

- `autumn_colossus_native.png`
- `autumn_boss_arena_full.png`
- `autumn_boss_arena_r1c1.png` through `autumn_boss_arena_r2c3.png`
- `autumn_boss_camera.png`

Any later asset, scale, platform position, z-order, or composition change requires
another full-frame, native-object, and fixed 3-column by 2-row review.
