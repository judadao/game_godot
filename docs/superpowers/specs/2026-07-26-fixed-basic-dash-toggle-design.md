# Fixed Basic Attack, Dash, and Group Toggle Design

Date: 2026-07-26

## Goal

Make the basic attack and pure Dash permanently available as the first two
cards of the first hand group, visually communicate that they are locked, and
change every group-switch input into a toggle. Restrict both fixed cards to
equipment-driven growth, with Dash equipment growth gated by story progress.

## Fixed Cards

The fixed card IDs, order, and shortcuts are:

1. `ember_bolt` — group one slot one — Q
2. `quickstep` — group one slot two — W

Both fixed cards count toward the expedition deck maximum of 16. The deck
builder therefore reserves two cards and allows the player to choose at most
14 additional cards. Deck normalization inserts missing fixed cards, removes
extra copies, and restores the exact fixed order before all selectable cards.

`quickstep` becomes a reusable mobility card with:

- AP cost: 1
- effect: dash 120 pixels and grant 0.2 seconds of evasion
- no card draw

This prevents a permanently retained zero-cost card from becoming an infinite
draw engine.

## Protection Contract

`DeckManager` owns an ordered protected-card collection rather than one
protected ID. It exposes a single membership query used by every consumer.

Protected cards:

- are extracted from the shuffled deck and inserted into hand slots zero and
  one in protected order;
- remain in their original slots after being played;
- survive full-AP redraw and end-turn cycling;
- cannot enter discard or exhaust piles;
- cannot be selected by hand-overflow discard;
- cannot be removed by merchants or other purge paths;
- cannot be selected for card merge, card-level upgrade, or duplicate card
  rewards.

Playing either protected card still spends its AP and resolves its normal
effect. If an invalid or migrated deck omits either card, normalization inserts
it before a run begins.

## Growth Rules

`ember_bolt` and `quickstep` always use their catalog level-one card effects.
They are excluded from run card levels, experience upgrade choices, duplicate
merge logic, evolution recipes, and card-specific permanent level data.

Their only growth path is equipped-item projection:

- `ember_bolt` receives attack-card damage bonuses from equipped weapons and
  other equipment special abilities.
- `quickstep` may receive `dash_distance_bonus` and
  `dash_evasion_bonus` from equipped-item special abilities.

The fixed cards remain visible at level one. Equipment-enhanced values are
applied to the resolved effect and do not mutate card level data.

## Story-Gated Dash Equipment

Persistent meta state gains `dash_upgrade_unlocked: bool`, defaulting to
`false`. Defeating the Heartwood Guardian—the current vertical slice's story
chapter completion—sets it to `true` and saves it.

Before this flag is unlocked:

- base `quickstep` remains usable;
- Dash equipment can still be owned and equipped;
- equipment whose special ability modifies Dash cannot be upgraded;
- `dash_distance_bonus` and `dash_evasion_bonus` do not modify Quickstep;
- UI descriptions state that the Dash enhancement is story-locked.

After it is unlocked, Dash equipment can be upgraded and its equipped bonuses
apply immediately and persist across runs. `InventoryManager` receives the
current progression unlocks through an explicit configuration method and
rejects a Dash-equipment upgrade while the flag is false, so the rule is
enforced below the Town UI. The explicit flag is separate from `boss_defeated`
so a future story implementation can migrate the unlock trigger without
coupling card resolution to a particular boss field.

The existing Swift Ring is the first Dash-growth item. Its dormant cooldown
field is replaced by visible Quickstep distance and evasion bonuses that use
the new consumer.

## Group Toggle Input

The input actions remain:

- `card_group_1`: A and LT
- `card_group_2`: S and RT

Their semantic behavior changes. Either action calls one toggle operation:

```gdscript
toggle_active_group()
```

For two groups, each press changes `0 -> 1` or `1 -> 0`. For one group, the
active group remains zero. Repeated or echo key events remain ignored.

Keeping both InputMap actions preserves existing keyboard and controller
bindings while removing their old "select a specific group" meaning. HUD copy
becomes:

`A / S / LT / RT  TOGGLE GROUP`

## Card Presentation

Fixed Autumn cards receive a `fixed` presentation state from their card data:

- a lock badge in the upper-right corner;
- a persistent gold border glow;
- a subtle gold pulse that does not move or resize neighboring cards;
- tooltip text stating that the card is permanently fixed and equipment-grown;
- normal AP unaffordable styling remains visible without removing the lock.

The glow is stronger than an ordinary active-card border but weaker than hover
or keyboard focus. Inactive-group dimming does not remove the lock icon.

The shared Town card renderer receives only the semantic fixed marker needed
for behavior tests; the new lock badge and pulse remain Autumn-specific.

## Affected Systems

### Deck selection and normalization

- `DeckBuilderUI` reserves one `ember_bolt` and one `quickstep`.
- `MetaState.normalize_selected_deck()` preserves both in order.
- `Game._normalize_expedition_deck()` preserves both in order.
- Migrated decks remain capped at 16 after insertion.

### Run and hand lifecycle

- `Game._begin_autumn_run()` configures both protected IDs.
- `DeckManager` retains both across play, redraw, cycling, and draw-pile
  reshuffles.
- `Game._refresh_card_hand()` marks both card dictionaries as fixed.

### Removal and growth

- hand overflow accepts a protected-ID collection;
- merchant purge rejects either fixed ID;
- campfire merge and card upgrade reject either fixed ID;
- card rewards do not offer or add fixed-card duplicates.

### Equipment and story

- equipment data declares Dash distance/evasion bonus fields;
- equipment data marks Dash-growth items with the
  `dash_upgrade_unlocked` upgrade requirement;
- `InventoryManager` rejects their upgrade until the requirement is active;
- `Game._apply_combo_infusions_to_card()` projects allowed equipment bonuses;
- Heartwood Guardian completion persists `dash_upgrade_unlocked`;
- meta serialization and migration default safely to `false`.

## Error Handling and Migration

- Unknown protected IDs are ignored by `DeckManager.start()`, but run
  normalization supplies both known fixed IDs before that boundary.
- A deck containing duplicate fixed cards is normalized to exactly one of each.
- A 16-card migrated deck missing both fixed cards drops its last two
  non-fixed cards before inserting the fixed cards.
- A deck containing only one fixed card is valid and receives the other.
- Save data without `dash_upgrade_unlocked` migrates from the existing
  `boss_defeated` flag, so players who already completed the story keep the
  unlock.
- If only one hand group exists, toggle input is consumed without changing the
  active index.

## Testing

Tests must prove:

- deck normalization produces `[ember_bolt, quickstep, ...]`, exactly once
  each, with no more than 16 cards;
- opening hands always place fixed cards at indices zero and one, even after
  deck shuffle;
- playing, redrawing, and cycling retain both in those slots;
- overflow and merchant purge reject both fixed cards;
- merges, card XP upgrades, evolution, and duplicate rewards reject both;
- Quickstep costs 1 AP and no longer draws cards;
- base Dash works before story completion;
- Dash equipment bonuses do not apply before unlock and do apply afterward;
- the story flag survives save/load;
- A, S, LT, and RT each toggle both directions;
- a one-group hand does not leave group zero;
- Autumn fixed cards expose lock badges and persistent glow without leaving the
  lower HUD at all supported viewport sizes;
- Town behavior outside the fixed-card contract remains unchanged.

## Non-Goals

- No independent legacy basic-attack or skill buttons.
- No cooldown system for Quickstep.
- No change to Q/W/E/R card activation.
- No change to maximum deck size or maximum visible hand size.
- No change to ordinary card XP, merge, reward, or evolution rules.
- No generated bitmap lock asset; the lock badge and glow use code-native UI.
