# Exploration and Survival Combat Loop Design

## Objective

Replace the short fixed encounter sequence with a two-layer expedition loop:

1. Exploration maps remain open and navigable.
2. Combat gates lead to survival-style battle stages.
3. Battle stages continuously add enemies through escalating timed waves.
4. Enemies drop physical experience gems.
5. Level-ups pause combat and let the player strengthen cards.
6. The stage exit stays locked until its boss is defeated.

The existing card-only combat, eight-card held hand, AP regeneration, Combo
abilities, deck building, encounter disengagement, and permanent discoveries
remain compatible with this loop.

## Immediate Blocker: Town to Autumn Tree

The real town interaction path must receive its own regression test. The test
must use the actual `TownForestPortal` instance, interaction-area registration,
`Game._try_interact()`, deck-builder confirmation, and final scene transition.
Synthetic calls to `Game._on_portal_entered()` are insufficient.

Entering the portal opens the expedition deck builder. Confirming any valid
deck of one to sixteen cards that contains the protected basic attack loads
`autumn_forest.tscn`, starts the run, and places the player at `PlayerSpawn`.
Invalid or migrated save data must be normalized instead of leaving the player
behind an unresponsive confirmation button.

## World Structure

Maps have one of two roles:

- **Exploration:** Town, forest paths, caves, graveyard paths, camps, merchants,
  events, treasure, and navigation portals. Exploration has no locked arena and
  no continuously increasing enemy population.
- **Battle stage:** A bounded survival arena connected between exploration
  destinations. The entrance closes when the stage begins. The exit points to
  the next exploration or battle map and unlocks only after boss victory.

Exploration is not tied to one map. The map graph may branch, and a completed
battle stage becomes a traversable connection. This vertical slice converts
Autumn Forest into the first battle stage while retaining the town as its
preceding exploration hub. The same interfaces will support later forest-path,
cave, and graveyard exploration maps.

## Survival Wave Model

The battle director changes from “spawn a fixed list and wait until empty” to a
timed pressure curve inspired by *Vampire Survivors*:

| Phase | Duration | Spawn interval | Alive cap | Enemy mix |
|---|---:|---:|---:|---|
| 1 | 45 s | 2.4 s | 8 | sprout, hopper |
| 2 | 45 s | 1.8 s | 12 | add thornling |
| 3 | 50 s | 1.35 s | 17 | add charger |
| 4 | 55 s | 1.0 s | 22 | mixed swarm and elites |
| Boss | Until defeated | 3.0 s support | 16 | guardian plus support enemies |

The director replenishes enemies while a phase timer is active, up to its alive
cap. A phase advances when its timer expires; the player does not need to clear
every remaining enemy first. At the boss phase, the guardian spawns exactly
once. Support enemies continue spawning until the guardian dies.

The HUD displays phase, remaining phase time, living enemies, player level, and
experience. Paused level-up selection freezes phase and spawn timers.

## Experience Gems and Level-Ups

Every defeated non-boss enemy drops one physical experience gem at its death
position. Gem value comes from the enemy archetype experience reward. A gem is
collected by touching it; a modest attraction radius pulls nearby gems toward
the player.

`RunState` is the authority for run level and experience. Experience thresholds
start at 40 and grow by `ceil(previous * 1.32 + 12)`. One large pickup may cause
multiple queued level-ups.

Each level-up pauses the game and presents three distinct choices generated
from the current run deck:

- Upgrade an owned card below level three.
- Add a discovered ordinary card when fewer than sixteen run-deck cards exist.
- Improve a currently active Combo ability when a valid Combo choice exists.

Card upgrades no longer occur at campfires. Upgrade choices update
`run_state.card_levels`, run evolution checks, and refresh the held-card UI.
If all owned cards are maxed, choices fall back to max health, AP regeneration,
or card removal. Multiple queued level-ups resolve one selection at a time.

## Campfire and Wandering Merchant

A campfire has one purpose: restore player health and mana to their current
maximum values. Each campfire may be used once per expedition.

Every battle-stage camp has a Wandering Cardwright beside it. The merchant uses
run gold and offers:

- Health potion: restores 40 HP, price 25.
- Mana potion: restores 30 MP, price 20.
- One ordinary discovered card, price 35.
- One rare or Combo card, price 70.
- Remove one non-protected run-deck card, price 45.

Potions are merchant supplies used immediately from the merchant screen; they
do not restore the removed combat potion hotkeys or the retired non-card attack
system. Merchant stock is generated once per expedition and persists while the
run remains active.

## Stage Completion and Progression

Normal phase completion never ends the stage. The battle exit remains disabled
until the boss emits `defeated`. Boss victory:

1. Stops all spawning.
2. Collects or grants the value of remaining experience gems.
3. Marks the battle-stage route unlocked in permanent progress.
4. Grants a new card or equipment discovery when available.
5. Enables the exit portal and updates its prompt to identify the destination.

Leaving through a retreat portal before boss victory ends the current run as a
failure and does not unlock the route.

## Component Boundaries

- `SurvivalWaveDirector`: timed phases, spawn budget, alive cap, boss lock, and
  stage-complete signal. It does not own player experience or reward UI.
- `ExperienceGem`: movement toward the player and one-shot value collection.
- `RunState`: experience thresholds, queued levels, and run card levels.
- `LevelUpUI`: displays exactly three choices and emits one selected choice.
- `Game`: wires gems to `RunState`, generates upgrade choices, applies merchant
  transactions, controls portals, and updates the HUD.
- `Campfire`: remains an interaction routed through `Game`, with no card-level
  mutation.

## Failure Handling

- A missing enemy scene skips that spawn without stopping the phase timer.
- A missing portal target leaves the exit locked and logs an explicit error.
- An invalid saved deck is normalized to a protected basic attack plus valid
  discovered cards, never to an empty deck.
- A level-up with fewer than three card choices fills remaining slots with
  deterministic stat choices.
- Experience gems ignore repeated collection after their first signal.
- Merchant actions are rejected without changing state when run gold, healing
  capacity, or removable cards are insufficient.

## Verification

Headless tests must cover:

- Actual town portal interaction reaches Autumn Forest.
- Timed phases replenish enemies, increase alive caps, and spawn one boss.
- The exit remains locked before boss death and unlocks afterward.
- Defeated enemies create gems; collection applies exact experience.
- Large experience gains queue multiple level-ups.
- Level-up choices upgrade cards and never use campfire state.
- Campfire restores HP/MP but cannot merge or upgrade cards.
- Merchant potions, ordinary/rare card stock, and removal use run gold.
- Existing card, Combo, hand overflow, AP, leash, save migration, and map tests
  continue passing.

The final verification runs every `tests/*.gd` script with isolated D-drive
`APPDATA`, parses the project in headless editor mode, runs the main scene for
300 frames, and scans output for parser, script, or runtime errors.
