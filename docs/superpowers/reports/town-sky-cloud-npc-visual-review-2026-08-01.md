# Town Sky, Cloud, NPC, and Service UI Visual Review — 2026-08-01

> The NPC visual approval in this report is superseded by
> `town-npc-living-animation-visual-review-2026-08-02.md`. Sky, cloud, and service UI
> findings remain current unless separately superseded.

## Scope

- Independent sky and cloud layers, runtime drift, edge cleanup, and golden-hour grading.
- Seven Town NPC world atlases plus the production Autumn seated merchant.
- Animated half-body portraits in Material Yard, Player Blacksmith, Town Hall, Sword Soul
  Blueprint Shop, and Equipment Blueprint Shop.
- Town integration at `1942×720` and service UI at the six required viewport sizes.

## Evidence reviewed

- `.review_town_sky_cloud/`: day and advanced-time full frames, two fixed 3-column × 2-row
  slice sets, cloud-free source, and eight runtime cloud objects at native detail.
- `.review_town_npc/`: idle and showcase full frames, two fixed 3-column × 2-row slice sets,
  the 7-role × 9-state animation sheet, five native cutouts, and seven native animation atlases.
- `.review_town_time/`: golden-hour full frame and one fixed 3-column × 2-row slice set.
- `.review_town_npc_ui/`: six service-page states at `1152×720`, `1280×720`, `1600×900`,
  `1920×1080`, `2560×1080`, and `2560×1440` (36 captures total).

## Iteration findings and fixes

1. Cloud edge review found a purple lower fringe. The cleanup shader was corrected and the
   complete sky/cloud evidence set was regenerated.
2. NPC review found duplicate traveler/grocer identities, static-cutout motion, an Equipment
   Blueprint identity mismatch, and Town lighting that used non-inheriting `self_modulate`.
   Seven distinct 4-frame × 9-state atlases, guard/innkeeper variants, consistent Professor
   Orin identity, and inheriting Town `modulate` were added; all evidence was regenerated.
3. Guard review found a floating spear. The spear was moved behind the hand/forearm grip in all
   36 atlas cells, then the native atlas, Town full frames/slices/state sheet, and golden-hour
   full frame/slices were regenerated and reviewed again.

## Final independent verdict

- Sky/cloud review: **PASS** — 0 Critical, 0 Important, 1 non-blocking Minor.
- NPC/UI/golden-hour review: **PASS** — 0 Critical, 0 Important, 1 non-blocking Minor.
- Non-blocking note: source character detail remains slightly smoother and denser than the Base
  MaterialYard brushwork, but at Town runtime scale it integrates without visible AI artifacts.
- Approved checks include alpha/background cleanup, native object geometry, full-frame
  composition, fixed six-slice composition, z-order, grounding, role identity, all animation
  states, portrait cropping, six-resolution layout, and synchronized golden-hour lighting.
