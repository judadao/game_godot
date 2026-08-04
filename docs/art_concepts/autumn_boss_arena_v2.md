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
- Boss: `autumn_smoke_oni_samurai_v1.png`, transparent skeletal oni samurai with compact spirit smoke.

The room uses a fixed `0.72` overview camera so the central boss stage and all
seven surrounding platforms remain visible above the combat HUD. All raster layers use hard pixel clusters, limited value steps, large readable
color masses, nearest texture filtering, and no smooth gradients or photographic
surface noise.

## Generation Prompt Summary

Built-in image generation used the supplied sunset samurai, torii, battlefield,
oni-mask, skeletal-samurai, and smoke references. The production prompts required
an original haunted Japanese autumn battlefield, indigo/vermilion/gold palette,
crisp pixel clusters, restrained detail frequency, no text or watermark, and a
clear central gameplay silhouette. Transparent layers were generated against a
flat chroma key and converted locally with soft matte and despill.

## Review Evidence

Graphical captures are written to `artifacts/autumn_boss_review/`:

- `autumn_boss_arena_full.png`
- `autumn_boss_arena_r1c1.png` through `autumn_boss_arena_r2c3.png`

Any later asset, scale, platform position, z-order, or composition change requires
another full-frame, native-object, and fixed 3-column by 2-row review.
