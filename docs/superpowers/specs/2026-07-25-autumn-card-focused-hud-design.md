# Autumn Card-Focused HUD Design

Date: 2026-07-25

## Goal

Refine the Autumn Battle V2 lower HUD to match the supplied dark-fantasy
concept, with the hand as the visual focus. Preserve the upper 75% world-safe
area, existing battle rules, Q/W/E/R card activation, and A/S plus LT/RT group
switching. Town UI must remain unchanged.

## Current Gap

`AutumnCardHandUI.tscn` uses the shared `card_hand_ui.gd` renderer. That
renderer builds each card as one short `82x78` text button and divides the hand
area into two equal rows. The result communicates the card data but does not
produce the concept's tall card silhouette, layered front/back rows, framed
information hierarchy, or strong active-row state.

## Chosen Approach

Create an Autumn-only card component and an Autumn-only renderer derived from
the existing card-hand controller. Reuse the existing hand data, selection,
energy, redraw, group-switch signals, and keyboard/controller input. Override
only card construction and visual layout behavior.

This keeps gameplay code stable, prevents the Town card hand from changing,
and gives Autumn Battle V2 ownership of its presentation.

## Components

### AutumnBattleCard

New files:

- `res://scenes/ui/autumn/AutumnBattleCard.tscn`
- `res://scripts/ui/autumn_battle_card.gd`

The root remains a `Button`, preserving focus, hover, disabled state, and the
existing selection signal contract. Child controls provide distinct visual
zones:

- top shortcut badge;
- card name;
- card type;
- centered icon or type glyph;
- level;
- AP label and emphasized AP value.

All child controls ignore mouse input so the root button remains the single
interaction target. Code-native `StyleBoxFlat` resources provide dark card
surfaces, type-tinted backgrounds, gold active borders, muted inactive borders,
and focus/hover glow. Existing card icon textures are used when supplied; a
compact type glyph is used when an icon is absent.

### AutumnCardHandUI Renderer

New file:

- `res://scripts/ui/autumn_card_hand_ui.gd`

`AutumnCardHandUI.tscn` uses this script instead of the shared renderer
directly. The script derives from `CardHandUI` and overrides the visual hooks:

- instantiate and configure `AutumnBattleCard`;
- use a tall responsive card footprint;
- overlap the two container-authored rows vertically;
- keep the active row at full scale, bright, interactive, and above the other
  row;
- keep the inactive row visible, dimmed, slightly smaller, non-focusable,
  non-clickable, and behind the active row;
- move hover cards upward without changing sibling layout;
- animate group switching with a short position, scale, and modulation tween.

The containers remain authoritative. No viewport-specific global positions are
stored on individual cards.

## Layout

The lower HUD remains exactly 25% of the viewport. The six-column contract is
unchanged:

`23 status / 8 AP / 40 hand / 10 group guide / 11 objective+combo / 8 economy`

Within the hand column:

- four cards fit at 1280x720 without horizontal clipping;
- cards use a tall target aspect ratio between 0.68 and 0.78;
- the inactive row exposes enough of its header to identify all four cards;
- the active row exposes the complete card face;
- changing groups swaps which row is complete and which row is recessed;
- the hand never enters the upper 75% world-safe area.

The AP badge and group guide receive small spacing and border refinements so
their visual weight supports the hand instead of competing with it. Objective,
Combo, and economy geometry remain functionally unchanged.

## Card States

Each card supports:

- attack, defense, skill, power, status, summon, ultimate, and fallback type
  tint;
- normal active;
- hover/focus;
- unaffordable disabled;
- inactive-row locked;
- selected group transition.

Inactive-row locking is presentation and input behavior only. It must not
overwrite affordability state. When the row becomes active, its cards restore
the correct enabled state from current AP.

## Data Flow

1. Gameplay calls the existing `set_cards(cards, energy)` API.
2. `CardHandUI` retains the card dictionaries and group state.
3. The Autumn renderer instantiates one `AutumnBattleCard` per visible card.
4. Each card receives name, type, icon, level, cost, description, shortcut, and
   affordability.
5. Container sorting establishes base geometry.
6. The Autumn renderer applies active/inactive row scale, z-index, modulation,
   focus, and mouse state.
7. A/S or LT/RT changes the active group and refreshes the row presentation.
8. Q/W/E/R continues to emit the original global card index.

## Responsive Rules

The design is tested at 1280x720, 1600x900, 1920x1080, 2560x1440, ultrawide,
and tall-window layouts. Cards may scale within the hand column but:

- no card may leave the viewport;
- no active card may be clipped by the bottom edge;
- no card may cross the 75% world/HUD boundary;
- card order and four-per-row grouping remain stable;
- hover and group-switch animation must not alter container ordering.

## Testing

Add a failing Autumn card visual contract test before implementation. It will
assert:

- the Autumn card scene and renderer exist and are Autumn-only;
- the Autumn hand instantiates eight structured card buttons;
- cards have tall aspect ratios and distinct child information zones;
- active and inactive rows have different scale, modulation, z-index, mouse,
  and focus states;
- group switching reverses those states;
- active cards stay inside the hand and lower-HUD bounds at every required
  resolution;
- Town still uses the shared renderer.

Existing card selection, group switching, hand overflow, UI keyboard, Autumn
layout, interaction prompt, and full project tests remain regression gates.

## Non-Goals

- No battle-rule changes.
- No deck-size or draw-rule changes.
- No change from A/S to the concept image's A/D labels.
- No Town HUD or Town card-hand redesign.
- No new autoload, theme replacement, or absolute per-card viewport layout.
- No generated bitmap frame is required; existing icons and code-native styles
  are sufficient for this iteration.
