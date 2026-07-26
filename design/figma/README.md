# Autumn Battle Map + HUD — Figma-ready concept

## Files

- `autumn-hud-redesign-figma.svg`: the only file that should be imported into Figma.
- `autumn-hud-redesign-source.svg`: build source for repository maintenance; do not
  import this second file into the same Figma page.
- `autumn-map-background.png`: generated map-only concept layer.

## Import

Drag only `autumn-hud-redesign-figma.svg` into a blank Figma page. The imported
root is clipped to an exact 1920×1080 canvas so drop shadows cannot expand its
bounds. UI regions, panels, cards, text, icons, and map overlay remain independently
editable. The bitmap map is intentionally isolated as the bottom layer. The map
bitmap, enemy state, player marker, and interaction prompt are grouped under
`01_WORLD_VIEWPORT` and shifted upward by 130 px as one world-space composition.
Screen-space HUD, missions, meta controls, and the Dash hint remain fixed.

Do not import `autumn-hud-redesign-source.svg` beside it. That file contains an
external bitmap reference for rebuilding the self-contained artifact and creates a
second similarly named group in Figma. When replacing an older mockup, delete the
old imported group and import the new self-contained file at 100% scale.

## Contract represented by the mockup

- Up arrow is Jump.
- Space is intrinsic Dash.
- Dash is not a card and does not consume AP.
- Q/W/E/R play the current four-card group.
- A/S switches between the two groups.
- Automatic attack is shown as a passive loadout status, not a hand card.
- Redraw lives in the card action strip instead of the player vitals panel.
- AP uses a decimal real-time counter (`3.7 / 5.0`) with regeneration rate and a
  continuously filling progress bar; HP remains the only persistent resource bar.
- Skill/Combo activation uses a three-row fading feed on the lower right.
- The large top-left Combo panel is removed to preserve combat visibility.
- The map preserves an open combat lane on the left, merchant/camp landmark in the
  middle, and portal landmark on the right.

## Design tokens

- Canvas: 1920×1080
- Gameplay safe area: y=0–705
- Combat dock: y=712–1000
- Footer/phase rail: y=1010–1064
- Panel background: `#0B1114` at 94%
- Panel inner background: `#11191C`
- Bronze border: `#A97A3C`
- Primary text: `#F6E6C2`
- Secondary text: `#BDA983`
- AP green: `#65B84B`
- HP red: `#C64632`
- SP blue: `#3D83C5`
- Attack: `#9F3F25`
- Skill/Combo: `#68509B`
- Healing: `#397D45`
- Status: `#236E88`

The SVG is a design artifact only. It does not change runtime scenes or scripts.
