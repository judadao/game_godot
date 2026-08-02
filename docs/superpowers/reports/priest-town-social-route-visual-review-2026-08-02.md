# Priest Town Social Route Visual Review - 2026-08-02

> Superseded later on 2026-08-02 after user runtime screenshots invalidated the
> underlying modular priest atlas. Route behavior remained valid, but the visual
> approval in this report is historical and does not approve the replacement asset.

## Scope

- Replace the stable `NPCs/Mayor` world presentation with the approved modular priest.
- Keep the external Town node and dedicated scene paths compatible.
- Run a deterministic loop: wait at home, walk to the witch, chat beside her,
  walk home, and wait before repeating.
- Synchronize the witch's chat state only while the priest is beside her.

## Final runtime route

- Home anchor: `(1130, 672)` with `front_idle`.
- Outbound: right-facing `side_walk`, entering a 28 px foreground road lane.
- Conversation: witch position plus 95 px on the right, left-facing `side_chat`.
- Return: left-facing `side_walk` through the same foreground lane.
- Arrival: exact home anchor, shared NPC z-order, and `front_idle` restored.

## Evidence reviewed

- `.review_priest_route/review2_route_temporal_contact_sheet.png`: eight actual
  Town playback samples covering the complete 30-second loop.
- `.review_priest_route/review2_conversation_full.png`: final conversation
  composition from the graphical Godot renderer.
- `.review_priest_route/review2_conversation_r1_c1.png` through
  `.review_priest_route/review2_conversation_r2_c3.png`: the complete fixed
  3-column by 2-row conversation slice review.
- `.review_priest_animation/priest_animation_atlas_native_on_slate.png`: the
  unchanged approved native-detail priest animation atlas.

## Iteration finding and fix

1. Initial integration used `Visual.scale = Vector2(0.25, 0.25)`. Independent
   review found a 143-146 px visible height, roughly 25-30 percent taller than
   the witch and nearby adult NPCs.
2. Runtime scale was reduced to `Vector2(0.21, 0.21)`, producing an approved
   visible height of approximately 118-122 px. The collision remains at least
   100 px tall and is protected by the behavior regression test.
3. The complete route movie, conversation full frame, and all six slices were
   regenerated after the scale change and independently reviewed again.

## Final independent verdict

- **PASS** - Critical 0, Important 0, Minor 0.
- Home anchors at 0 and 27 seconds match; outbound and return facings are correct.
- Foreground-lane travel is grounded, draws in front of stationary NPCs, and has
  no body intersections, floating, teleporting, or z-order pops.
- The priest stops approximately 95 px to the witch's right, faces her, and does
  not overlap her; the witch's chat marks are synchronized.
- Conversation composition, runtime adult scale, full temporal sequence, and all
  fixed review slices are approved with no remaining required fixes.
