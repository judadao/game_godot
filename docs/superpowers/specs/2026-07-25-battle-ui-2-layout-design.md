# Battle UI 2.0 Layout Design

## Goal

Rebuild the Autumn combat presentation so the world remains fully visible in
the upper 75–80% of the viewport and every combat control lives in an opaque
bottom HUD occupying no more than 25% of the viewport.

## Approved Reference

The user-provided “Battle UI 2.0” concept image is the visual authority. The
runtime layout keeps the existing art, data, input actions, combat rules, and
public script methods; this change only reorganizes presentation.

## Layout

The bottom HUD uses the same five proportional columns in `HUD.tscn` and
`CardHandUI.tscn`:

1. Player status: portrait, level, HP, MP, and SP.
2. AP: redraw action and compact AP badge.
3. Hand: two complete rows of four cards.
4. Combat information: group selector, combo state, and objective.
5. Progress: gold and experience.

The bottom band starts at 75% viewport height and ends at the bottom edge.
All persistent HUD elements must be enclosed by that band and must not
intersect neighboring columns.

## Card Groups

- The hand capacity remains eight.
- `BackRow` and `FrontRow` are scene-authored `HBoxContainer` children of a
  `VBoxContainer`.
- The active group is always rendered in `FrontRow`; the inactive group is
  rendered in `BackRow`.
- A/S switches groups without changing card order or combat behavior.
- Q/W/E/R selects slots 1–4 in the active group.
- Group one slot one remains the protected basic attack `ember_bolt`.
- Cards use container sizing, not manual resting-position fan calculations.
- Hover uses a 108% scale and a temporary 10-pixel rise, without moving
  neighboring cards or leaving the bottom band.

## Responsive Constraints

- Required test sizes: 1152×720, 1280×720, 1600×900, 1920×1080,
  2560×1080, and 2560×1440.
- The world/HUD boundary is proportional, not a hard-coded pixel height.
- Cards may shrink to their authored compact minimum but never overflow the
  hand column or viewport.
- Persistent controls use Godot `Container` layout. Runtime code may only
  apply the temporary hover transform to a card.

## Scope

No combat formulas, player/enemy logic, card data, inventory, saving, map
content, global state, themes, or reusable StyleBoxes are changed.

## Verification

- Layout guardrails assert the 25% boundary, authored container structure,
  eight cards, column separation, and viewport containment at every required
  resolution.
- Card tests assert active/inactive row placement and A/S switching.
- HUD tests assert all status, objective, and progress panels remain inside
  the bottom band without overlap.
- The authoritative Autumn preview is captured through Godot for visual
  inspection.
- The complete test suite, editor smoke check, and main-scene smoke check run
  without parser or runtime errors.
