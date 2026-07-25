# Campfire Growth, Real-Time AP, and Encounter Leash Design

## Goal

Make the real-time card combat easier to read and more tactical by exposing most of each resting card, moving card growth to the forest campfire, regenerating AP over time, and resetting encounters when the player fully disengages.

## Chosen Design

This combines four related changes:

1. Resting cards expose 154 of their 168 pixels instead of 108.
2. Combat rewards add card copies without automatically leveling an owned card.
3. A forest campfire provides one successful action per run: rest, merge, or upgrade.
4. AP regenerates continuously, while encounters enforce a visible five-second leash countdown.

The alternative of retaining automatic card levels was rejected because it makes the campfire decision meaningless. A discrete turn-based AP refill was rejected because the game otherwise remains real-time. Instant enemy resets were rejected because they would give the player no chance to dodge outside the arena and return.

## Card Hand Visibility

- Full cards remain 132 by 168 pixels.
- Resting cards expose 154 pixels; only 14 pixels may sit below the viewport.
- Edge cards may sit at most eight pixels lower due to the fan curve.
- Hover still raises the focused card by 75 pixels and shows it in full.
- The hand remains overlapping and has no full-width background panel.

## Real-Time AP

- AP replaces the turn-refill interpretation of energy.
- Maximum AP is 3.0.
- Base regeneration is 0.65 AP per second while a run is active and gameplay is not paused.
- Card costs remain whole numbers and are subtracted immediately.
- A card cannot be played unless current AP covers its cost.
- The hand does not discard and redraw merely because AP reaches zero.
- After a card is played, one replacement card is drawn when hand size permits.
- The energy wisp adds 0.35 AP regeneration per second for six seconds.
- The HUD displays AP with one decimal place and updates disabled card states without rebuilding the hand each frame.

## Campfire Card Growth

The existing `forest_rest` landmark becomes a campfire menu.

### Action Limit

- The campfire may perform one successful action per run.
- Leaving the menu does not consume the campfire.
- After use, interacting again explains that the embers are spent.

### Rest

- Fully restores health and mana.
- Consumes the campfire action.

### Merge

- Available only for card IDs with at least two copies across hand, draw pile, and discard pile.
- Consumes one copy of the selected card.
- Raises that card ID's run level by one, to a maximum of level three.
- Runs the existing evolution check after reaching level three.

### Upgrade

- Available for any owned card below level three.
- Does not consume a card copy.
- Raises the selected card ID's run level by one.
- Runs the existing evolution check after reaching level three.
- Consumes the campfire action.

### Combat Rewards

- Selecting a card reward always adds a playable copy.
- A duplicate reward no longer raises the shared card level.
- New card IDs initialize at level one.

## Dodge, Escape, and Encounter Leash

- The existing Shift dash remains the dodge action and retains its brief invulnerability.
- Escaping is spatial: the player can run away from an engaged encounter.
- An encounter becomes engaged when the player enters 650 pixels of its origin.
- No disengagement countdown runs before first engagement.
- Moving beyond 760 pixels starts a five-second warning.
- Returning within 760 pixels cancels the warning immediately.
- The HUD shows `DISENGAGING — return in N` during the countdown.
- When the countdown reaches zero, every living enemy in the active wave:
  - returns to its recorded spawn position;
  - restores maximum health;
  - clears slow and stun;
  - stops its attack and movement.
- The encounter returns to an unengaged state and can be approached again.
- Defeated enemies remain defeated; only living active enemies reset.

## Component Responsibilities

### `DeckManager`

- Stores AP as a float.
- Validates and spends card costs.
- Regenerates AP through `regenerate_energy(delta, rate)`.
- Retains deterministic draw and discard behavior.

### `Game`

- Ticks AP during active gameplay.
- Applies temporary AP regeneration buffs.
- Opens campfire menus and applies merge, upgrade, or rest actions.
- Translates encounter leash signals into HUD warnings.

### `EncounterDirector`

- Owns engagement distance, leash distance, countdown, and active-wave reset.
- Emits engagement, warning, cancellation, and reset signals.
- Records each spawned enemy's local spawn position.

### `EnemyBase`

- Exposes `reset_encounter(spawn_position)` to restore combat state safely.

## Testing

Automated tests cover:

- 154-pixel resting card visibility.
- Fractional AP spending, regeneration, and maximum clamping.
- Duplicate rewards remaining separate copies.
- Campfire merge consuming one copy and leveling the card.
- Campfire upgrade leveling without consuming a copy.
- One successful campfire action per run.
- Leash countdown start, cancellation, timeout, position reset, health restoration, and status clearing.
- Existing card selection, combat, map transition, and save tests.

Runtime verification loads the editor and runs the main game for 300 frames without script or scene errors.

## Out of Scope

- Respawning enemies already defeated in the current wave.
- A separate flee button or confirmation dialog.
- New campfire artwork.
- Drag-targeted cards.
