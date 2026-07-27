# Autumn Battle Map + HUD — Figma-ready concept

## Files

- `autumn-hud-redesign-figma.svg`: import this self-contained file into Figma.
- `autumn-hud-redesign-source.svg`: repository build source.
- `autumn-map-background.png`: generated map-only concept layer.
- `autumn-hud-redesign-preview.png`: review preview.
- `build_figma_source.ps1`: rebuilds the self-contained Figma SVG.

## Import

Drag only `autumn-hud-redesign-figma.svg` into a blank Figma page. The root is
clipped to an exact `1920 × 1080` canvas. UI regions, panels, cards, text, icons,
and map overlay remain independently editable.

Do not import `autumn-hud-redesign-source.svg` beside it. That file contains an
external bitmap reference for rebuilding the self-contained artifact.

## Design contract

- Up arrow is Jump.
- Space is intrinsic Dash.
- Q/W/E/R use the fixed Healing plus three Combo/Sword Soul slots.
- Basic Attack is automatic and horizontal.
- AP uses a real-time decimal counter and regeneration bar.
- The map preserves an open horizontal combat lane.

These files are design artifacts only and do not change runtime scenes.
