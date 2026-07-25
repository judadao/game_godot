# Slay-the-Spire-Inspired Card Hand Design

## Goal

Replace the current large opaque Play Card panel with a compact bottom hand that keeps the map visible while preserving fast keyboard and mouse card play.

## Approved Direction

Use a Slay-the-Spire-inspired fanned hand:

- Remove the full-width opaque background panel.
- Anchor the hand to the bottom center of the viewport.
- Fan and overlap up to five cards so their resting footprint is shallow.
- Raise and enlarge the hovered card so its complete text is readable.
- Keep number-key shortcuts 1–5 and mouse selection.
- Present energy, combo, and boss information as separate compact overlays rather than as part of a large panel.

## Layout

### Resting Hand

- The hand occupies at most 125 pixels of visible height while no card is hovered.
- Cards are 132 by 168 pixels at full size.
- Resting cards are shifted downward so only the upper 100–110 pixels remain visible.
- Adjacent cards overlap horizontally by approximately 30–40 pixels.
- Cards rotate around the bottom center in a shallow fan, capped at roughly six degrees.
- The hand remains centered for one to five cards.

### Hover and Focus

- Hovering a card raises it by approximately 75 pixels.
- The hovered card scales to 1.08 and moves in front of adjacent cards.
- Full name, description, type, level, and energy cost remain readable on the raised card.
- Other cards stay in their resting positions; the hand does not reflow.
- Disabled cards remain visible but use lower saturation and cannot be selected.

### Compact Overlays

- Energy appears as a small circular or rounded badge immediately left of the hand.
- Combo information appears as a narrow translucent label immediately right of the hand.
- Boss name and health bar remain at the top center of the viewport.
- No opaque container spans the width behind the cards.

## Interaction

- Clicking a card emits the existing `card_selected(index)` signal.
- Number keys 1–5 retain their current behavior.
- Tactical slowdown remains controlled by the existing card-focus input.
- Hover animation uses short tweens and must ignore stale tweens when the hand refreshes.
- The root UI remains display-only outside card hit areas, so the map continues receiving input.

## Component Boundaries

`CardHandUI` remains responsible for:

- Receiving card dictionaries and current energy.
- Creating card controls.
- Positioning and fanning cards.
- Hover/focus animation.
- Compact energy, combo, and boss displays.
- Emitting selection signals.

The game manager continues to own deck state, energy spending, card execution, and modal-UI restrictions. No combat rules move into the visual component.

## Error and Edge Handling

- An empty hand hides the card controls but keeps the energy badge available during an active run.
- More than five cards still fit by increasing horizontal overlap instead of expanding beyond the safe width.
- Missing card icons fall back to text-only cards.
- Very long descriptions wrap and clip within the card body.
- Layout recalculates when the viewport size changes.

## Testing

Automated UI tests will verify:

- No large opaque full-hand panel is created.
- The resting hand footprint stays within 125 pixels of visible height.
- Five cards overlap and remain centered.
- Hover raises a card and gives it the highest draw order.
- Energy, combo, and boss displays remain available.
- Existing mouse and number-key selection contracts still pass.

Runtime verification will load the main game for 300 frames and check for script or scene errors.

## Out of Scope

- New card illustrations.
- Drag-and-drop targeting.
- Changing card costs, deck rules, or encounter balance.
- Rebuilding the rest of the HUD.
