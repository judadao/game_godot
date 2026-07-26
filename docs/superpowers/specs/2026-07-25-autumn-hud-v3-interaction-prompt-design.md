# Autumn HUD 3.0 and Interaction Prompt Design

## Status

Approved from the user-provided HUD concept image and the preceding approval
to replace the conflicting interaction prompt. This specification applies to
the authoritative Autumn Battle V2 map only. Town keeps its existing HUD.

## Problem

The shared `HUDInteractionPrompt` is anchored to the viewport bottom. At
1280x720 it occupies approximately y=624..706, inside the y=540..720 battle
HUD and card region. The existing shared HUD also cannot express the six
separate regions shown in the approved Autumn HUD concept without affecting
Town.

## Architecture

Autumn Battle V2 receives three map-specific UI scenes:

- `AutumnHUD.tscn`: status, objective, economy, and the interaction prompt.
- `AutumnCardHandUI.tscn`: AP, two four-card rows, group guide, combo, and boss
  display.
- `AutumnEditorHUDReference.tscn`: editor-visible composition of the two
  Autumn scenes and the 1280x720 / y=540 guides.

`Game.load_hud()` and `Game.load_card_hand()` continue adopting the exact
instances under `EditorHUDReference`; no new singleton or global UI state is
introduced. The canonical Autumn map identity and gameplay systems do not
change.

## Bottom HUD Layout

The bottom HUD remains exactly the final 25 percent of the viewport:
anchor-top 0.75, anchor-bottom 1.0. Both Autumn HUD siblings use the same
six-column ratio so their controls align:

1. Status: 23 percent.
2. AP: 8 percent.
3. Hand: 40 percent.
4. Group guide: 10 percent.
5. Objective / Combo: 11 percent.
6. Economy: 8 percent.

The status column shows level, class, HP, MP, SP, and compact status-effect
slots. AP shows current/max AP and the full-AP redraw control. Hand shows two
rows of four cards. The active row is full-bright and interactive; the
inactive row is darker, smaller, and non-interactive. Group switching remains
A/S and LT/RT, preserving the already-approved control contract. Objective,
wave progress, Combo, Gold, and EXP remain data-driven through the current
Game APIs.

All layout is authored with Godot Containers. Runtime code may create card
buttons inside the authored row containers but must not position the six
regions.

## Visual Language

The approved dark fantasy presentation uses existing repository resources:
near-black translucent panels, warm gold borders, parchment/brown status
surfaces, blue-violet skill accents, and small pixel icons. Existing RPG UI,
card, and generated HUD assets are sufficient; no bitmap generation is
required unless a final visual capture proves a concrete missing asset.

## Autumn Interaction Prompt

`AutumnInteractionPrompt.tscn` replaces the bottom banner for Autumn only. It
is a compact one-line prompt with a gold keycap and action label. Game passes
the current interactive target to:

```gdscript
set_interaction_prompt(action_text: String, key_text: String = "F", target: CanvasItem = null)
```

When the target is a live CanvasItem, the prompt follows its
`get_global_transform_with_canvas().origin`, centered horizontally and placed
72 pixels above it. The prompt clamps inside:

- x: 16 pixels to viewport width minus 16 pixels.
- y: 16 pixels to `(viewport height * 0.75) - 16 pixels`.

It therefore never enters the bottom HUD or card area. If the target becomes
invalid or the prompt is cleared, it hides. It ignores mouse input and does
not emit interaction actions; F remains handled by Game.

## Editor Contract

Opening `AutumnBattleMapV2.tscn` must display the real Autumn HUD, Autumn card
hand, and the new prompt placeholder. Authors can expand
`EditorHUDReference/HUD` and `EditorHUDReference/CardHandUI`. The main map
must not serialize overrides below those two UI roots.

`CombatLayoutPreview.tscn` uses the Autumn variants and hides the map's own
editor reference so only one HUD composition is visible.

## Testing

Tests must exercise real scene instances and cover:

- Autumn uses the Autumn HUD and card scenes; Town still uses the shared HUD.
- Six column ratios match between HUD and card layers.
- Both card rows contain four cards and group switching remains A/S.
- Interaction prompt follows a real CanvasItem target.
- At all supported viewport sizes, the prompt stays inside the world region
  and never intersects the bottom safe area.
- Clearing or losing the target hides the prompt.
- Runtime adoption preserves the exact map-authored UI instances.
- Existing combat, interaction, map, and keyboard tests remain green.

Supported viewports remain 1152x720, 1280x720, 1600x900, 1920x1080,
2560x1080, and 2560x1440.
