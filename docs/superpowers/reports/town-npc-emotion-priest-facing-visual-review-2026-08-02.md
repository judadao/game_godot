# Town NPC Emotion and Facing Visual Review - 2026-08-02

## Scope

- Keep the priest on the shared Town road baseline and make the priest and witch
  face one another during their scheduled conversation.
- Correct the witch's directional animation so her native left-facing atlas does
  not make her appear to walk backward.
- Replace procedural whole-body emotion stretching with authored four-frame
  `laugh`, `happy`, `sad`, `surprised`, and `angry` poses for six residents and
  two visitors.
- Remove duplicate runtime emotion marks while retaining the three-dot chat cue.

This review supersedes the older foreground-lane priest route and the earlier
emotion-row findings recorded on 2026-08-02.

## Evidence reviewed

- All eight final `576 x 1976` NPC atlases and their final authored emotion strips
  under `assets/town/npc/characters/`.
- `.review_town_social_v4/town_life_t09_full.png`, `town_life_t12_full.png`,
  `town_life_t18_full.png`, and `town_life_t35_full.png`.
- All 24 fixed slices under `.review_town_social_v4/t09_slices/`,
  `t12_slices/`, `t18_slices/`, and `t35_slices/`.
- `.review_town_social_v4/npc_states/town_npc_animation_state_sheet.png` plus the
  final idle and showcase full frames and slices.
- The final traveler and grocer source strips under
  `.review_town_social_v4/generated_strips/` at native resolution.

## Review findings and fixes

1. The priest's old 46 px foreground lane put her below the other residents and
   on a different z layer. The route now remains at `y = 672`, `z_index = 0`,
   stops 95 px left of the witch, and explicitly faces the pair toward one another.
2. The witch atlas is natively left-facing. Directional playback now compares the
   desired direction with that native sign, preventing backward-looking travel.
3. The previous emotion rows used runtime scale, bob, shear, or rotation instead
   of limb-authored motion. All eight characters now use full-pose emotion strips,
   a common foot baseline, a 132 px target adult height, no runtime whole-body
   emotion transform, and no duplicate runtime emotion symbols.
4. The first review rejected a one-frame lute teleport, one-frame apples in the
   grocer and farmer happy loops, and an innkeeper laugh frame with an 11 px height
   jump. Those frames were redrawn, the alpha backgrounds were cleaned, and the
   atlas builder was rerun.
5. The proportion regression now limits each emotion loop to a 4 px height spread
   and also checks head and torso core stability. This caught and corrected one
   additional scientist sad-pose edge case before the final capture.
6. Follow-up screenshots `111941` and `112001` exposed a chibi traveler angry
   pose and a vertically compressed grocer laugh pose that the first review had
   missed. The grocer emotion sheet was regenerated against the adult motion
   reference. The traveler emotions were regenerated as five independent 1 x 4
   strips and composed with fixed row spacing so every frame retains adult torso,
   leg, and foot proportions without clipping.
7. The proportion regression now also compares every emotion frame's head-core
   area with that character's median adult idle reference, with a maximum ratio
   of `1.33`. Both screenshot regressions fail this check on their old assets and
   pass with the final v4 atlases.

## Final independent verdict

- **PASS - Critical 0, Important 0, Minor 0.**
- The v4 review supersedes the v3 evidence. The reviewer inspected all four
  traveler and grocer frames in every emotion row against their adult idle,
  walk, and talk rows at native resolution, four final Town frames, all 24
  slices, and the complete 9 x 13 state sheet.
- Priest and witch grounding, spacing, facing, and z-order are approved. Witch
  travel direction, visitor routes, and resident interactions read naturally.
- Adult proportions, feet, hands, limbs, clothing, transparency, and prop
  continuity are coherent. No checker fringe, malformed anatomy, false seams,
  clipping, AI mush, or duplicate emotion marks remain.
- The final characters remain compatible with the Town's coarse pixel brushwork,
  large color clusters, limited value steps, and established material density.

## Verification

- `town_npc_pose_proportion_test.gd`
- `town_npc_emotion_overlay_test.gd`
- `town_npc_facing_direction_test.gd`
- `town_npc_animation_test.gd`
- `town_npc_visual_transform_test.gd`
- `town_npc_life_test.gd`
- `town_life_preview_test.gd`
- `priest_town_behavior_test.gd`
- Full repository suite with editor and main-scene smoke checks.
