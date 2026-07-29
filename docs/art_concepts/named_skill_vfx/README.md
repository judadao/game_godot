# Named Skill VFX Concept Boards

Generated with the built-in `image_gen` path on 2026-07-29. The four local JPGs
from `/home/judd/Downloads/` were used only as motion-language references
(pixel-art timing, slash arcs, projectile trails, burst/debris rhythm). Do not
copy their characters, poses, sprite layouts, watermarks, text, or exact shapes.

This concept folder follows `data/named_skill_vfx_profiles.json`; if this README
and that JSON disagree, the JSON profile is the authority.

## Output files

| File | Purpose |
|---|---|
| `finishers_concept_board_v1.png` | Five Combo Finisher identities: anticipation, travel/attack, impact, and Lv1/Lv2/Lv3 structural growth. |
| `triggers_concept_board_v2.png` | Four named trigger identities aligned to current profile elements: wind, fire, lightning, water. |
| `element_progression_stack_board_v2.png` | Formal nine-element vocabulary plus reusable Lv/stack layering grammar. |

Removed from workspace because they used the wrong taxonomy:

- `triggers_concept_board_v1.png`
- `element_progression_stack_board_v1.png`

## Formal element taxonomy

Use exactly these element names in concept docs, profile metadata, and future art
notes:

```text
water / fire / wind / lightning / ice / poison / light / dark / normal
```

Do not use `earth`, `wood`, `stone`, `rock`, `soil`, `tree`, `root`, or `leaf`
language for this concept set. `lightning` and `light` are separate elements.
`normal` means pure sword pressure, white-cyan kinetic force, and metal glints;
it must not default to fire.

## Named skill mapping

| ID | Display | Kind | Element | Archetype | Lv1 → Lv2 → Lv3 structure | Stack milestones |
|---|---|---|---|---|---|---|
| `thousand_blade_kill` | 千刃殺 | Finisher | `normal` | `blade_storm_lane` | `cross_cut_seed` → `orbiting_blade_ring` → `thousand_edge_execution` | 0/3/6/9: single execution arc → triple afterimage fan → six-blade crossfire → nine-blade storm crown |
| `inferno_cremation` | 焚天滅 | Finisher | `fire` | `compression_detonation` | `ember_core` → `caldera_ring` → `cremation_pillar` | 0/3/6/9: sealed ember → three flame satellites → sixfold magma fissure → ninefold sunburst |
| `thunder_prison_pierce` | 雷獄穿心 | Finisher | `lightning` | `rail_prison` | `prison_lance` → `lightning_bar_cells` → `judgement_thunder_gate` | 0/3/6/9: single charge spear → three locking sigils → six chain crossbars → ninefold prison break |
| `heavenly_wheel_sever` | 天輪斷 | Finisher | `normal` | `orbiting_wheel` | `half_wheel` → `dual_orbit_wheels` → `celestial_guillotine_halo` | 0/3/6/9: single wheel cut → three orbit marks → six-spoke halo → nine heavenly wheels |
| `frozen_burial` | 霜葬 | Finisher | `ice` | `descending_tomb` | `frost_coffin` → `burial_spikes` → `glacial_mausoleum` | 0/3/6/9: single frost seal → three coffin runes → six grave spikes → ninefold whiteout tomb |
| `iron_momentum` | Iron Momentum | Trigger | `wind` | `armor_lock` | `iron_guard_plate` → `tempered_counter_ring` → `fortress_lock` | 0/2/4/5: single guard flash → double temper band → four-plate bastion → five-hit fortress lock |
| `ember_reprise` | Ember Reprise | Trigger | `fire` | `returning_arc` | `returning_ember` → `echo_flame_arc` → `phoenix_reprise` | 0/2/4/6: single return spark → double echo orbit → fourfold rekindle → sixfold phoenix reprise |
| `battle_tempo` | Battle Tempo | Trigger | `lightning` | `rhythm_pulse` | `tempo_tick` → `syncopated_rhythm_ring` → `war_cadence_overdrive` | 0/2/5/8: single tempo tick → double offbeat echo → five-note acceleration → eight-beat overdrive |
| `grand_strategy` | Grand Strategy | Trigger | `water` | `tactical_ward` | `tactical_node` → `linked_command_grid` → `grand_constellation` | 0/3/6/9: single command node → three linked orders → six-point control grid → ninefold strategy constellation |

## Modular part breakdown

Keep runtime assembly modular. Each named skill can be decomposed into these
atlas-friendly parts:

1. `anticipation`: cue shape before power release. Examples: blade funnel,
   ember core, lightning cage, frost seal, water command node, wind guard flash.
2. `primary_shape`: the readable main silhouette. Examples: crescent, wind
   armor plate, lightning rail, wheel, coffin slab, water tactical ward.
3. `trail`: motion smear, wind streak, fire echo lane, lightning beat rail, or
   water command ribbon.
4. `impact`: hit star, crossed blades, burst crown, shatter, fortress lock, or
   ward close.
5. `debris`: sparks, ice shards, poison droplets, dark void motes, water
   droplets, wind shear fragments.
6. `level_overlay`: Lv2/Lv3 structural additions such as second ring, extra
   cage line, mirrored slash, enclosing shell, linked command grid, or
   overdrive diamond.
7. `stack_overlay`: stack pips/echo lanes/aura density. Stack overlays must add
   readable layers without replacing the base silhouette.
8. `element_overlay`: one of the nine formal elements.
9. `silhouette_mask`: same-frame mask for tint, combo, and buff overlays.

Recommended runtime row model:

```text
row = named_vfx_id
columns = anticipation / primary_shape / trail / impact / debris
overlays = level_overlay + stack_overlay + element_overlay + silhouette_mask
```

## Prompt record

### Finishers v1 prompt

Create an original high-polish pixel-art VFX concept board on a dark neutral
game-preview background. Show five distinct finisher rows, each with three beats
(anticipation, attack/travel, impact) plus Lv1/Lv2/Lv3 structure. Identities:
Thousand Blade Kill as metallic horizontal blade storm; Inferno Cremation as
solar core and fire execution crescent; Thunder Prison Pierce as lightning
prison and straight spear; Heavenly Wheel Sever as interlocking celestial rings
and diagonal sever; Frozen Burial as frost seal, closing coffin, and shatter.
No readable labels, no copying references, no watermark.

### Triggers v2 prompt

Create an original high-polish pixel-art VFX concept board on a dark neutral
game-preview background. Show exactly four horizontal rows, one per trigger
profile, each row with cue/anticipation, trigger pulse, resolve, and stack
layering thumbnails for stack 1, stack 2, stack 3+. Use profile identities
exactly: `iron_momentum` is `wind` with cyan-green wind-pressure armor plates and
air-shear chevrons; `ember_reprise` is `fire` with compact returning ember,
echo flame arc, and phoenix reprise; `battle_tempo` is `lightning` with
purple-blue electric beat ticks, rhythm ring, and overdrive rails;
`grand_strategy` is `water` with blue-cyan fluid tactical ward, command droplets,
linked water-line grid, and grand constellation ripples. No wood, no earth, no
stone, no rocks, no soil, no trees, no roots, no leaves, no readable labels, no
copying references, no watermark.

### Element/progression v2 prompt

Create an original pixel-art board defining exactly nine element swatches in a
3x3 grid, ordered left-to-right and top-to-bottom:
`water/fire/wind/lightning/ice/poison/light/dark/normal`. Do not include wood
or earth. Show bottom strips for Lv1/Lv2/Lv3 structure and stack 1/2/3+
overlays. `lightning` is purple-blue electric rails and jagged beat ticks;
`light` is gold-white diamonds, rays, pulse rings, and starbursts; `normal` is
white-cyan sword pressure and metallic kinetic crescents. No readable labels, no
watermark.

## Implementation notes

- Fire-dominant identities are only `inferno_cremation` and `ember_reprise`.
- `normal` should stay white-cyan and metallic so sword pressure remains
  readable after element overlays.
- `wind` should use speed lines, air-shear ribbons, pressure plates, and
  negative space; never dust piles, soil, rocks, leaves, or branches.
- `water` should use ripples, droplets, fluid links, and blue-cyan tactical
  nodes for `grand_strategy`.
- `lightning` should stay purple-blue and jagged/rail-like.
- `light` should stay gold-white and geometric/radiant.
- `dark` should be a navy-purple underlay or void-mote accent unless a future
  profile explicitly becomes dark-primary.
- Keep every Lv/stack addition additive and mask-compatible so gameplay buffs
  can layer without changing damage authority.
