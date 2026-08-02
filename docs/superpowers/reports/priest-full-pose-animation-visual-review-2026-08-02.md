# Priest Full-Pose Animation Visual Review - 2026-08-02

## Scope

- Replace the invalidated modular/chibi runtime atlas with one consistent adult priest.
- Preserve the priest's white／gold／blue identity and Town runtime height near 120 px.
- Provide four eight-frame actions: front idle, front chat, side walk, and side chat.
- Keep the Town route from home to the witch, synchronized conversation, return, and wait.

## Final asset contract

- Runtime atlas: `assets/town/npc/priest/priest_animation_atlas.png`, 3072 × 2048,
  eight columns × four rows, 384 × 512 per frame.
- Full-pose sources: `assets/town/npc/priest/pose_strips_v2/`.
- Reproducible builder: `tools/art/build_priest_animation.py`.
- `Mayor.tscn` uses a 0.268 visual scale, yielding an approximately 120 px adult silhouette.
- Legacy modular parts remain source history only and are not composed into runtime frames.

## Evidence reviewed

- Native atlas and all four full-pose source strips at original detail.
- `.review_priest_human_v2/animation_frame_0.png` through `animation_frame_7.png`:
  eight runtime phases from the dedicated animation preview.
- `.review_priest_human_v2/town_wait_home_full.png`, `town_walk_to_witch_full.png`,
  `town_chat_with_witch_full.png`, and `town_walk_home_full.png`.
- `.review_priest_human_v2/chat_slices/town_chat_with_witch_r1_c1.png` through
  `town_chat_with_witch_r2_c3.png`: fixed three-column × two-row integrated review.

## Iteration findings and fixes

1. The first replacement gait lacked a sufficiently clear opposite-leg contact cycle. The
   side-walk source was regenerated with explicit contact／down／passing／up phases and a
   stable foot baseline.
2. Initial chat candidates changed hand intent between frames. Front and side chat were
   regenerated as one continuous raise／present／lower gesture arc.
3. Every action was rebuilt from a complete adult body per frame; mixed-scale head, torso,
   hand, and leg fragments from the invalidated modular atlas were removed from runtime.

## Final independent verdict

- **PASS** - Critical 0, Important 0, Minor 0.
- Adult anatomy, silhouette, foot contact, costume identity, alpha edges, and runtime scale pass.
- Side walk exposes all eight readable phases; both chat actions read as continuous gestures.
- Town home, travel, witch conversation, return, facing, spacing, and z-order pass in the
  integrated full frames and all six fixed review slices.
- This report supersedes the visual approval portions of
  `priest-modular-animation-visual-review-2026-08-01.md` and
  `priest-town-social-route-visual-review-2026-08-02.md`.
