# Named Skill VFX Concept Boards

Generated with the built-in `image_gen` path on 2026-07-29. The four local JPGs
from `/home/judd/Downloads/` were used only as motion-language references
(pixel-art timing, slash arcs, projectile trails, burst/debris rhythm). Do not
copy their characters, poses, sprite layouts, watermarks, text, or exact shapes.

Current gameplay skill names, series, tiers, roles, and descriptions come only from
`data/skills.json` schema 2. The four trigger IDs documented below are retired as
skills and remain only as animation-library compatibility profiles for
`legacy_vfx_map`; future design work must not use them as a skill roster.

The five atlas-base identities in this folder follow
`data/named_skill_vfx_profiles.json`. The complete 32-Finisher runtime identity
set follows `data/finisher_vfx_identities.json` and the detailed continuous-action
storyboards under `docs/art_concepts/finisher_choreography/`; runtime data is the
authority when a shared atlas base and a Finisher-specific geometry identity
differ.

## Output files

| File | Purpose |
|---|---|
| `finishers_concept_board_v1.png` | Five Combo Finisher identities: anticipation, travel/attack, impact, and Lv1/Lv2/Lv3 structural growth. |
| `triggers_concept_board_v2.png` | Four named trigger identities aligned to current profile elements: wind, fire, lightning, water. |
| `element_progression_stack_board_v2.png` | Formal nine-element vocabulary plus reusable Lv/stack layering grammar. |

The five Finisher rows are legacy reference underlays, not the complete runtime
catalog and not visible during a Finisher. Each final move resolves a twelve-frame painted
object sequence under `assets/generated/vfx/finisher_parts_v4/`; this is the visible
construction, deformation, impact, and residue authority. Its square semantic material
plate is a design reference and stays hidden at runtime. Every contour must belong to the named object;
generic rings, ticks, grids, icon echoes, and decorative line fill are prohibited.

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

## Retired trigger animation profiles

The five Finisher rows formerly listed here are retired concept-board records.
They are not runtime identities and must not be used as construction guidance.
All 32 current Finishers are enumerated in
`data/finisher_vfx_identities.json`; their exact silhouettes and continuous
actions are specified in `docs/art_concepts/finisher_choreography/`.

| ID | Display | Kind | Element | Archetype | Lv1 → Lv2 → Lv3 structure | Stack milestones |
|---|---|---|---|---|---|---|
| `iron_momentum` | Iron Momentum | Trigger | `wind` | `armor_lock` | `iron_guard_plate` → `tempered_counter_ring` → `fortress_lock` | 0/2/4/5: single guard flash → double temper band → four-plate bastion → five-hit fortress lock |
| `ember_reprise` | Ember Reprise | Trigger | `fire` | `returning_arc` | `returning_ember` → `echo_flame_arc` → `phoenix_reprise` | 0/2/4/6: single return spark → double echo orbit → fourfold rekindle → sixfold phoenix reprise |
| `battle_tempo` | Battle Tempo | Trigger | `lightning` | `rhythm_pulse` | `tempo_tick` → `syncopated_rhythm_ring` → `war_cadence_overdrive` | 0/2/5/8: single tempo tick → double offbeat echo → five-note acceleration → eight-beat overdrive |
| `grand_strategy` | Grand Strategy | Trigger | `water` | `tactical_ward` | `tactical_node` → `linked_command_grid` → `grand_constellation` | 0/3/6/9: single command node → three linked orders → six-point control grid → ninefold strategy constellation |

## Legacy trigger modular part breakdown

This atlas-friendly row model applies only to the four retired trigger animation profiles. Finishers
must not use it: they use the exclusive ten-layer semantic-material choreography
described in `docs/art_concepts/finisher_choreography/README.md`.

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

Recommended trigger runtime row model:

```text
row = named_vfx_id
columns = anticipation / primary_shape / trail / impact / debris
overlays = level_overlay + stack_overlay + element_overlay + silhouette_mask
```

## Prompt record

### Archived Finishers v1 prompt

Historical prompt record only. It is not a runtime or art-direction authority.

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
