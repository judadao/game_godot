# Town NPC Living Animation Visual Review - 2026-08-02

## Scope

- Use the approved full-pose priest as the proportion and animation-quality baseline.
- Add generated front idle, side walk, and side chat poses to traveler, witch, guard,
  grocer, scientist, and innkeeper while retaining distinct character identities.
- Let the six NPCs wander locally, sit, emote, meet a neighbor, face and chat, then
  return to their exact authored home positions.
- Preserve the priest's dedicated Town Hall → witch → Town Hall route without competing
  with the witch's autonomous behavior.

## Final runtime contract

- Six `576 × 1368` RGBA atlases use 144 × 152 cells, four columns × nine state rows.
- Generated full-pose rows are idle, walk, and chat; sit is normalized to 120 px including
  a readable stool, while laugh and emotions retain the same approved identity.
- The guard keeps one charcoal-and-white uniform and one spear in every active state;
  the scientist keeps a recognizable purple potion across generated and retained states.
- `TownNPCLife` owns session-local idle／rest／emote／wander／social-walk／social-chat／
  return-home presentation. Adjacent wander zones preserve one body width and social
  partners stop approximately 100 px apart.
- The priest travels on a 46 px foreground lane at z-index 2 and uses an external lock
  for the witch during their dedicated conversation.

## Evidence reviewed

- Native detail: all six final `assets/town/npc/characters/*_animation_atlas.png` files and
  their de-keyed `motion_strips_v2/*_motion.png` sources.
- `.review_town_life/final_v4/town_life_t00_full.png`, `t06`, `t12`, `t18`, and `t24`:
  deterministic runtime samples covering idle, walk, rest, chat, return, and continuation.
- `.review_town_life/final_v4/t12_slices/town_life_t12_r1_c1.png` through `r2_c3.png`:
  the complete fixed three-column × two-row integrated review.
- `.review_town_life/final_v4/npc_states/town_npc_animation_state_sheet.png` plus idle and
  showcase Town full frames and both complete six-slice sets.

## Iteration findings and fixes

1. The first living-Town pass allowed the guard's spear and dark uniform to pop between
   generated and retained states. Guard motion was regenerated with the spear in all
   twelve new frames, retained states were normalized to the charcoal uniform, and the
   final runtime import was independently checked.
2. The scientist's purple flask appeared only in retained states. Idle, walk, and chat
   were regenerated with continuous belt／hand flask placement.
3. Initial autonomous roam ranges allowed unrelated NPCs to share the same body space.
   Neighbor-aware wander bounds now preserve 80 px between adjacent zones.
4. Retained sit poses were too small and could read as children. Every sit frame is now
   normalized to 120 px with an explicit stool while standing poses remain 132 px.
5. The priest crossed the traveler at the ordinary baseline. The route now uses a 46 px
   foreground lane, coherent z-order, and adjusted travel timing; all full frames and six
   slices were regenerated after the route change.

## Final independent verdict

- **PASS** - Critical 0, Important 0, Minor 0.
- Adult proportions, limbs, feet, pixel-art cadence, alpha edges, identity and prop
  continuity pass at native detail and Town runtime scale.
- t00 → t06 → t12 → t18 → t24 clearly presents a living loop without fused bodies,
  same-baseline collisions, z-order pops, false seams, green fringes, or AI texture noise.
- Priest／traveler foreground crossing, priest／witch spacing and facing, all seated adult
  scales, guard spear continuity, scientist potion continuity, and all fixed review slices
  are approved with no remaining required fixes.
