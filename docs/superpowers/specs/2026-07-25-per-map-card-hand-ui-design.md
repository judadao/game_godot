# Per-Map Card Hand UI Design

## Goal

Make the card UI visible and editable inside `AutumnForestLayout.tscn`, with the
same layout instance used during gameplay.

## Design

`EditorHUDReference.tscn` contains both the shared HUD and `CardHandUI`. Every map
layout can store independent overrides for those instances. `CardHandUI` runs as
a tool script and displays a stable four-card Q/W/E/R sample in the editor; the
sample is never used at runtime.

When `Game` loads a map, it adopts both embedded UI instances into `HUDLayer`.
The card UI reconnects its selection and redraw signals after every map change.
If a legacy map lacks an embedded card UI, `Game` instantiates the exported
fallback scene. Active run data is refreshed after adoption.

## Safety

- Card behavior and deck state remain owned by `Game`.
- Editor sample cards are presentation-only.
- Existing user changes in Autumn scenes and HUD interaction UI remain intact.

## Verification

- Regression tests require every authoritative layout to contain a card UI.
- Runtime tests require `Game` to adopt the layout card UI on startup and map change.
- Card layout, combat integration, portal flow, full suite, editor parse, and
  main-scene runtime must pass.
