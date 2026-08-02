# Town Social Visitors Visual Review - 2026-08-02

## Scope

- Extend the six resident NPC atlases from 4 × 9 to 4 × 13 with authored
  `idle_look`, `idle_stretch`, `greet`, and role-specific `work` loops.
- Add an adult visiting farmer and traveling minstrel with distinct identities,
  full Town-scale atlases, cross-Town routes, and resident greetings.
- Review the resident catalog-driven greet → chat/work → react → farewell flow,
  visitor entry/social/exit flow, grounding, spacing, facing, and z-order.

## Evidence reviewed

- Native detail: all eight final `576 × 1976` resident and visitor atlases under
  `assets/town/npc/characters/`, including rows 9–12 and their de-keyed
  `motion_strips_v3/` sources.
- `.review_town_social_v2/town_life_t12_full.png`, `town_life_t18_full.png`, and
  `town_life_t35_full.png`.
- All six fixed 3-column × 2-row slices in `.review_town_social_v2/t12_slices/`,
  `t18_slices/`, and `t35_slices/`.
- `.review_town_social_v2/npc_states/town_npc_animation_state_sheet.png`, showing
  the priest, six residents, and two visitors across all 13 states.

## Review findings and fixes

1. The first visitor integration used a 24 px foreground offset for the farmer.
   It avoided one crossing overlap but broke the common road baseline. The farmer
   returned to `y = 672`; his start delay and walking cadence were adjusted so the
   reviewed entry, social, and departure samples remain readable without changing
   grounding.
2. The first 9-role state sheet positioned visitors before `_ready()`, after which
   their route initialization moved them off the review grid. The capture now
   disables visitor life before insertion and reapplies the authored grid position
   after initialization. The complete sheet was regenerated.
3. A generated grocer work frame contained an unrelated display plinth. The atlas
   builder replaces that beat with the clean inspection pose, preventing the AI
   artifact from entering the production atlas.
4. The guard's disconnected spear initially confused alpha-projection slicing.
   Generated action strips now fall back to their strict four-column grid when a
   long prop creates extra alpha islands.

## Final independent verdict

- **PASS** — Critical 0, Important 0, Minor 0.
- Adult proportions, hands, legs, feet, props, and character identities remain
  coherent at native detail and Town runtime scale.
- Farmer entry and traveler greeting, minstrel and innkeeper conversation, resident
  role actions, grounding, facing, spacing, and z-order are approved.
- No visible green fringe, fused or extra limbs, false seams, clipping, duplicated
  props, stray generated objects, or noisy AI texture remains in the final evidence.
- The eight characters remain compatible with the Town / Base MaterialYard coarse
  linework, large color-cluster, and limited-value art direction.
