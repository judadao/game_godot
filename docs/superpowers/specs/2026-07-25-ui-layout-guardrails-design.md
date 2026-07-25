# UI Layout Guardrails Design

## Goal

Make the combat HUD and card hand visually editable in Godot, preserve per-map
Inspector overrides at runtime, and prevent future changes from reintroducing
viewport-wide fixed-position layout code.

## Evidence and root cause

`CardHandUI.tscn` currently contains only a full-screen root `Control`.
`card_hand_ui.gd::_build_layout()` creates every visible child at runtime, and
`_layout_cards()` positions the safe-area band, AP badge, combo hint, redraw
button, group badge, boss bar, and cards from viewport coordinates. The Scene
editor therefore does not show the authoritative runtime layout.

`HUD.tscn` is authored in the Scene editor and already uses left/right anchors,
but its regression test covers only the default 1280×720 viewport. The
map-specific HUD flow reparents `EditorHUDReference/HUD` and
`EditorHUDReference/CardHandUI` into `Game/HUDLayer`; this correctly preserves
map overrides only when the component scripts do not rebuild their own layout.

## Chosen architecture

`CardHandUI.tscn` becomes the single source of truth for all static layout:

- `CardSafeArea` owns the opaque 184-pixel bottom band.
- `BottomMargin/BottomRow` reserves equal left and right slots around a centered
  `CardFan`.
- `LeftControls` owns redraw and AP controls.
- `CardFan` is the only node that receives runtime card buttons.
- `ComboHint`, `CardGroupBadge`, and the boss display are authored nodes.

`card_hand_ui.gd` binds those nodes with `@onready`, updates text/state, and
creates only the variable number of card buttons. The fan algorithm works in
`CardFan` local coordinates. It may animate card position, rotation, and scale
inside that bounded region, but it must not position the other UI controls.

`HUD.tscn` remains the authoritative static HUD because changing its public node
paths would invalidate map overrides and gameplay callers. Its existing
bottom-left and bottom-right anchored components receive stronger behavioral
tests across viewport sizes rather than a risky node-path migration.

## Per-map editing contract

Each authoritative map scene instances `EditorHUDReference.tscn`. Designers edit
`EditorHUDReference/HUD` and `EditorHUDReference/CardHandUI` through editable
children. `Game.load_hud()` and `Game.load_card_hand()` adopt those exact
instances into the global CanvasLayer. Neither component initialization may
reset root anchors, offsets, position, scale, or map overrides.

The old `scenes/maps/layouts/AutumnForestLayout.tscn` is not an authoritative
entry. The authoritative Autumn scene remains
`scenes/maps/autumn_tree/AutumnTreeMap.tscn`.

## Regression protection

The UI guardrail test instantiates real scenes in several `SubViewport` sizes.
It verifies:

- static card-hand controls exist before runtime content is supplied;
- runtime card buttons are children of `CardFan`;
- the safe area stays attached to the bottom and inside the viewport;
- the four-card group remains centered and fully visible;
- left/right card controls do not overlap the fan;
- HUD status stays in the lower-left, objective/progress stay in the
  lower-right, and all remain inside the viewport;
- map-authored root offsets survive initialization and runtime adoption.

Existing gameplay, card selection, Q/W/E/R shortcuts, A/S group switching,
hover animation, AP display, combo display, boss health, signals, and map
loading remain unchanged.
