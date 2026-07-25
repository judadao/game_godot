# Campfire Growth, Real-Time AP, and Encounter Leash Design

## Goal

Make the real-time card combat easier to read and more tactical by exposing most of each resting card, moving card growth to the forest campfire, regenerating AP over time, and resetting encounters when the player fully disengages.

## Chosen Design

This combines four related changes:

1. Resting cards expose 154 of their 168 pixels instead of 108.
2. Combat rewards add card copies without automatically leveling an owned card.
3. A forest campfire provides one successful action per run: rest, merge, or upgrade.
4. AP regenerates continuously, while encounters enforce a visible five-second leash countdown.
5. The hand is limited to four cards with Q/W/E/R and X/Y/A/B slot controls.

The alternative of retaining automatic card levels was rejected because it makes the campfire decision meaningless. A discrete turn-based AP refill was rejected because the game otherwise remains real-time. Instant enemy resets were rejected because they would give the player no chance to dodge outside the arena and return.

## Card Hand Visibility

- Full cards remain 132 by 168 pixels.
- Resting cards expose 154 pixels; only 14 pixels may sit below the viewport.
- Edge cards may sit at most eight pixels lower due to the fan curve.
- Hover still raises the focused card by 75 pixels and shows it in full.
- The hand remains overlapping and has no full-width background panel.

## Real-Time AP

- AP replaces the turn-refill interpretation of energy.
- Maximum AP is 5.0.
- Base regeneration is 0.65 AP per second while a run is active and gameplay is not paused.
- Card costs remain whole numbers and are subtracted immediately.
- Ordinary cards cost 0–2 AP, major powers cost 3–4 AP, and ultimate cards may cost 5 AP.
- A card cannot be played unless current AP covers its cost.
- The hand does not discard and redraw merely because AP reaches zero.
- After a card is played, one replacement card is drawn when hand size permits.
- The energy wisp adds 0.35 AP regeneration per second for six seconds.
- The HUD displays AP with one decimal place and updates disabled card states without rebuilding the hand each frame.

## Four-Card Input Layout

- Hand size is exactly four.
- Keyboard slots one through four use Q, W, E, and R.
- Joypad slots one through four use X, Y, A, and B.
- The original basic attack, mana skill, HP potion, and MP potion actions are removed.
- All attacks, skills, movement techniques, defense, healing, and combat recovery come from cards.
- Joypad dash moves from A to right shoulder so it cannot also play slot three.
- Card faces show their Q/W/E/R shortcut instead of 1–5.
- No slot is reserved for a basic attack card; all four cards are drawn from a shuffled run deck.
- At full AP, keyboard T, joypad D-pad Down, or a compact button spends all AP to discard and redraw four cards.

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
- Consumes extra copies of the selected card, one at a time.
- Each consumed copy raises that card ID's run level by one, to a maximum of level three.
- A single merge action processes enough available copies to reach level three, so three level-one copies can become one level-three card.
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

## Persistent Combo Infusions

- Combo cards use a separate two-slot belt and never enter hand, draw pile, or discard pile.
- Combo slots use keyboard C/V and joypad D-pad Left/Right, and remain mouse-clickable.
- Activating a combo card spends AP directly and permanently enables its infusion for the current run.
- `Flame Imbue` costs 3 AP; subsequent attack cards gain four damage and apply a short burn.
- `Frostburst Imbue` costs 3 AP; subsequent attack cards gain two damage and apply a 30% slow.
- When both infusions are active, attack cards gain an additional two damage and briefly stun.
- An active combo card cannot be paid for twice.
- Combo cards do not solve ordinary deck congestion: the four-card hand is still drawn from the chosen run deck.

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
- Four-card hand size and Q/W/E/R plus X/Y/A/B input mappings.
- Combo belt activation, AP costs, non-hand ownership, and attack infusion effects.

Runtime verification loads the editor and runs the main game for 300 frames without script or scene errors.

## Out of Scope

- Respawning enemies already defeated in the current wave.
- A separate flee button or confirmation dialog.
- New campfire artwork.
- Drag-targeted cards.
