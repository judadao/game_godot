# Card, Skill, Growth, and Autumn HUD Redesign

Date: 2026-07-26

Status: Approved for implementation planning

## 1. Goal

Replace the current block-oriented Defense cards, ambiguous card-growth
dialogue, shared-level card model, and fragile Autumn HUD with one coherent
combat progression design.

The redesign must:

- remove the `defense` card type and direct Block-card gameplay;
- introduce reusable timed defensive Combo cards;
- make every healing card visually green and mechanically identifiable;
- add a memory-capacity Skill system driven only by successful attack-card
  combinations;
- track the level of every card copy independently;
- unify new-card rewards, card upgrades, full-level fusion, and resource
  fallback in one paused growth UI;
- replace the Autumn battle HUD rather than incrementally moving its current
  nodes;
- leave the Town HUD unchanged.

## 2. Terminology

The word **Skill** is reserved for passive attack-combination recipes stored in
the Skill memory backpack. It no longer describes an ordinary card category.

The runtime concepts are:

- **Card definition**: immutable catalog data identified by `card_id`.
- **Card instance**: one owned copy with a unique `instance_id` and its own
  level.
- **Combo card**: an active hand card that applies a timed combat effect.
- **Healing card**: a green hand card whose primary result restores health.
- **Skill**: a learned passive recipe that observes successful attack cards and
  automatically produces an effect.
- **Fusion**: consuming two different full-level card instances named by a
  recipe to create one higher-tier level-one card instance.

Existing cards with type `skill` must be reclassified. Offensive cards such as
Dash Strike become `attack`; pure movement or utility cards become `utility`;
Healing Light becomes `healing`.

## 3. Card Instance Model

Every non-fixed card copy has independent progression:

```text
CardInstance
├── instance_id: String
├── card_id: String
└── level: int
```

Two Cleave copies may therefore be level one and level three at the same time.
All deck zones retain instance identity:

```text
owned instances
├── hand
├── draw pile
├── discard pile
├── exhaust pile
└── cooldown pile
```

Zone entries must never collapse to a shared card ID. Card projections resolve
catalog data by `card_id`, then apply only that instance's level.

The fixed `ember_bolt` and `quickstep` cards also receive stable instances so
zone operations remain uniform. They stay locked at level one and are excluded
from rewards, upgrades, fusion, purge, merge, and per-card growth data.

### 3.1 Save migration

Old card-ID arrays migrate in their existing order. Each occurrence creates a
new stable instance ID. An old shared `card_levels[card_id]` value is copied to
every migrated instance of that definition so existing progress is not lost.
Unknown cards are preserved in a recoverable migration report and excluded
from the active deck rather than silently deleted.

Migration is idempotent: loading an already instance-based save must not
generate new IDs.

## 4. Card Taxonomy and Defensive Combo Cards

The `defense` type and ordinary Block effects are removed. Player defense is
expressed through two independent timed statuses:

- `super_armor`: prevents interruption and knockback but does not reduce
  damage;
- `damage_reduction`: reduces health damage but does not prevent interruption.

Weak super armor ignores ordinary enemy hit reactions. Strong super armor also
ignores heavy reactions. Explicit boss-unblockable attacks bypass both armor
tiers. Different damage-reduction sources may coexist, but total reduction is
capped at 60 percent. The strongest armor tier wins; the same status source
refreshes its duration and never stacks with itself.

Initial Defense-card conversions are:

| Existing ID | Display name | Type | Cost | Effect | Cooldown |
|---|---|---:|---:|---|---:|
| `guard` | Iron Will | combo | 1 AP | Weak super armor for 4 seconds | 8 seconds |
| `iron_skin` | Stone Form | combo | 2 AP | 30% damage reduction for 5 seconds | 12 seconds |
| `fortress_stance` | Unbreakable Stance | combo | 4 AP | Strong super armor and 40% reduction for 4 seconds | 18 seconds |
| `stoneguard_combo` | Counterguard | combo | 3 AP | 25% reduction and retaliation for 6 seconds | 14 seconds |

All defensive Combo cards are reusable. After play they enter the cooldown
pile, do not occupy a hand slot, and move to the discard pile only after their
cooldown expires. Cooldowns advance only while gameplay is not paused.

## 5. Green Healing Family

Every card whose primary purpose restores health uses type `healing` and one
shared green visual language:

- dark emerald body;
- brighter green border;
- health-cross, leaf, blood-drop, or spirit icon appropriate to the subtype;
- explicit `restore`, `regeneration`, `lifesteal`, or `healing_summon` tag.

Initial conversions and additions are:

| Card | Healing mode | Lifecycle |
|---|---|---|
| Healing Light | Immediate restore | Exhaust after use |
| Renewal Spirit | Repeated healing pulses | Healing summon contract |
| Blood Pact | Timed lifesteal | Reusable; enters cooldown |
| Verdant Renewal | Timed regeneration | Reusable; enters cooldown |

Immediate restore cards exhaust so AP regeneration and redraw cannot produce
infinite safe healing. Regeneration and lifesteal may cycle, but the same
source only refreshes its duration. It never stacks with itself.

Healing cards may have attack-independent tags for content rules, but they
never count as steps in Skill recipes.

## 6. Skill Memory System

### 6.1 Ownership and capacity

Learned Skills are permanent. The active Skill memory backpack has a point
capacity rather than a fixed slot count:

- initial capacity: 10 points;
- common automatic Skills: 1 point;
- intermediate exact sequences: 2–3 points;
- long or powerful sequences: 4 or more points;
- the Town Memory Library expands permanent capacity through levels with
  capacities 10, 14, 18, 24, and 30.

The backpack may be edited only in Town or another explicit safe area.

Skills are learned from three sources:

- Skill Tomes awarded by bosses, treasure, quests, and special merchants;
- purchases from the Town Memory Library using permanent gold and materials;
- hidden Skills permanently discovered the first time their secret attack
  sequence succeeds.

Learning does not activate a Skill. The player must place it in the memory
backpack and remain within the point budget.

### 6.2 Recipe input

Only a successfully damaging attack card produces a Skill-recipe event. One
resolved card contributes at most one event even when it deals multiple hits.
Missed, cancelled, or zero-damage attacks do not contribute.

Recipes have two supported modes:

1. **Count recipe**: a specified number of successful attack cards within a
   refreshing time window.
2. **Exact sequence recipe**: specific attack card IDs in an exact order.

Count recipes:

- begin their window on the first valid attack;
- refresh the eight-second window after every valid attack;
- ignore non-attack cards;
- reset after triggering or timing out.

Exact sequences:

- contain only explicit attack card IDs;
- reset on an incorrect attack or any successfully played non-attack card;
- treat a mismatching attack as a new first step when it equals the recipe's
  first card;
- never use Healing, Combo, Utility, or generic tag placeholders.

Taking damage does not reset either recipe type.

### 6.3 Parallel tracking and first Skill

Every equipped Skill tracks independently. One attack event may advance many
recipes, and all completed recipes may trigger together. Each Skill has its
own cooldown; completing one never consumes another Skill's progress.

The initial common Skill is:

```text
Iron Momentum
Memory cost: 1
Recipe: any successful attack card ×5
Window: 8 seconds, refreshed per valid attack
Effect: weak super armor for 3 seconds
Cooldown: 10 seconds
```

## 7. Combat Status Ownership

A focused combat-status controller owns:

- weak and strong super armor;
- damage reduction and its 60% cap;
- retaliation;
- regeneration;
- lifesteal;
- status-source identity, duration, refresh, expiry, and pause behavior.

The player controller queries the status controller when resolving hit
reaction and damage. `Game.gd` orchestrates signals but does not own status
math or recipe tracking.

The status controller emits projections for the HUD. Expired states are
removed once, and stale timers cannot clear a newer refreshed state.

## 8. Growth Choice Queue

Autumn Blessing, EXP level-up, and Campfire card-growth logic are replaced by
one queue and one authoritative `CardGrowthUI`.

Growth entries are source-aware:

- **Wave Blessing** opens only the New Card page.
- **EXP Level Up** opens Upgrade and Full-Level Fusion.
- multiple pending events are processed one at a time.

Each event grants exactly one completed action.

### 8.1 New Card

The player chooses one offered card definition. The result is a new level-one
instance. Fixed cards never appear.

### 8.2 Upgrade

The player chooses one owned non-fixed instance below level three. Only that
instance gains one level. Same-name copies remain unchanged.

### 8.3 Full-level fusion

A fusion recipe requires two different named card definitions, and the player
must select one level-three instance of each. Both chosen instances are
consumed. One level-one result instance is added, so the deck count decreases
by one.

The initial recipe migration is:

| First Lv.3 card | Second Lv.3 card | Result Lv.1 card |
|---|---|---|
| Iron Will (`guard`) | Stone Form (`iron_skin`) | Unbreakable Stance (`fortress_stance`) |
| Dash Strike | Cleave | Gale Lunge |
| Frost Bind | Energy Surge | Time Snare |
| Healing Light | Blood Pact | Renewal |
| Battle Focus | Flame Aura | Overdrive |
| Cleave | Flame Aura | Inferno Orb |

The old passive-gated evolution contract is removed. Fixed Ember Bolt never
acts as fusion material.

### 8.4 Resource fallback

If an EXP Level Up has no legal upgrade and no available fusion, it becomes a
permanent resource choice:

- 75 gold;
- 12 autumn wood and 8 stone;
- 4 magic shards.

An Autumn Core may replace one choice only for an explicitly configured boss
tier. Selected resources are saved immediately to the permanent
Meta/Inventory economy and survive later Run failure.

## 9. Card Growth UI

The current Autumn Blessing dialogue and old LevelUpUI are removed after
caller migration. The replacement is a centered, responsive modal with:

- an explicit source title;
- only the pages allowed by that source;
- a scrollable card grid;
- an instance-level badge on every card;
- a detail panel comparing current and resulting effects;
- an explicit selection followed by confirmation;
- keyboard, controller, and mouse focus parity;
- clear empty-state and disabled-reason text;
- no speaker portrait, dialogue affordance, or decorative `A` tile.

Opening the UI acquires a gameplay pause token. Enemies, projectiles, waves,
AP regeneration, card cooldowns, Combo status timers, and Skill windows stop.
The UI itself uses always-processing mode. Gameplay resumes only after the
queue is empty and no other modal owns a pause token.

Closing, scene replacement, or invalid selection must not consume the pending
growth entry.

## 10. New Autumn Combat HUD

The Autumn HUD is rebuilt as one editor-authored authoritative scene. The
existing Autumn HUD is not incrementally rearranged and does not remain as a
parallel authority. Town rendering remains unchanged.

The new layout is:

```text
AutumnCombatHUD
├── TopLeftStack
│   ├── ActiveStatusList
│   └── ObjectivePanel
├── TopCenterStack
│   ├── BossHealth
│   └── SkillToastStack
├── BottomStage
│   ├── PlayerVitals
│   ├── ActionPoints
│   ├── CardStage
│   │   ├── CooldownStrip
│   │   └── AutumnCardHandUI
│   ├── InputGlyphHints
│   └── PersonalResources
```

Responsibilities:

- top-left status rows show effect name, icon, and remaining duration and
  disappear on expiry;
- the objective sits directly below statuses;
- boss health occupies top center only while a boss is active;
- Skill activation toasts appear below the boss region, stack to at most three
  rows, and fade after 1.5 seconds;
- repeated notification of the same visible Skill refreshes its row;
- bottom-left shows portrait, level, HP, MP, and SP;
- bottom-center shows AP, cooldown cards, and both card rows;
- compact input glyphs beside the hand show group toggle and full-AP redraw;
- bottom-right contains only gold, EXP, and personal resource information.

Panels use translucent dark backgrounds and stable authored containers. The
HUD has no permanent Skill recipe or progress display; players rely on memory.

The supported viewport matrix is:

- 1152×720;
- 1280×720;
- 1600×900;
- 1920×1080;
- 2560×1080;
- 2560×1440.

Narrow layouts shorten text and spacing but never overlap the battle-safe
viewport or move panels outside the screen.

## 11. Data and Component Boundaries

The implementation introduces or refactors these authorities:

- `CardInstance`: stable identity and serialization;
- `DeckManager`: instance zones and cooldown pile;
- `SkillRecipeManager`: learned/active Skills, memory budget, recipe trackers,
  cooldowns, and hidden discovery;
- `CombatStatusController`: timed survival and healing effects;
- `GrowthChoiceQueue`: source-aware pending growth and pause ownership;
- `CardGrowthUI`: growth presentation and selection signals;
- `AutumnCombatHUD`: Autumn-only layout and status projections.

Static content remains data-driven:

- `data/cards.json`: reclassified card definitions and effect fields;
- `data/skills.json`: Skill cost, acquisition, recipe, effect, and cooldown;
- `data/evolutions.json`: two-card full-level fusion recipes;
- `data/town_upgrades.json`: Memory Library levels and resource costs.

UI receives immutable projections and emits selections. It never mutates card
instances, Skill loadouts, status state, or permanent resources directly.

## 12. Error Handling

- Invalid card instances are reported with instance and catalog IDs and are
  excluded from active zones without deleting their serialized record.
- Invalid Skill recipes or memory costs are rejected during catalog load.
- Duplicate instance IDs fail migration validation and receive deterministic
  replacements recorded in the migration report.
- A fusion revalidates both selected instances immediately before mutation.
- A failed growth action leaves the queue entry pending and shows a readable
  error.
- Pause tokens are reference-counted so one modal cannot resume another
  modal's paused gameplay.
- Scene teardown clears HUD subscriptions and status callbacks without
  applying queued actions.

## 13. Testing

Automated contracts must prove:

- card copies have independent levels and stable IDs across save/load;
- old shared-level saves migrate deterministically and idempotently;
- every deck zone preserves instance identity;
- cooldown cards leave the hand, wait while gameplay runs, freeze while
  paused, and return through discard;
- Defense no longer exists in the validated card taxonomy;
- Healing cards use the green semantic type and correct lifecycle;
- super armor and reduction are independent, refresh correctly, and respect
  the 60% cap;
- count and exact-sequence Skills obey their distinct interruption rules;
- one attack advances multiple Skills and simultaneous completion triggers all
  eligible effects;
- non-attack cards do not reset count recipes but do reset exact sequences;
- Growth pages are restricted by source;
- upgrade changes one selected instance only;
- fusion consumes exactly two selected level-three instances and creates one
  level-one result;
- unavailable EXP growth yields a permanent resource choice;
- fixed cards are absent from reward, upgrade, and fusion candidates;
- queued growth pauses every gameplay clock and resumes only after all modal
  owners release pause;
- the new Autumn HUD fits every supported viewport and Town HUD identity is
  unchanged.

Manual validation must capture both active card groups at 1280×720 and
2560×1440, active status rows, stacked Skill toasts, cooldown cards, each
Growth UI page, long card text, controller focus, and resource fallback.

## 14. Non-Goals

- No Town HUD redesign.
- No free-form combo DSL, optional steps, branching recipes, or input timing
  beyond count and exact-card sequences.
- No Skill progress meter or persistent recipe hint in combat.
- No arbitrary fusion between cards without an authored recipe.
- No fixed-card leveling or fusion.
- No change to Q/W/E/R card activation.

## 15. Completion Criteria

The redesign is complete only when:

- old Autumn HUD, Blessing dialogue growth, shared card-level authority, and
  obsolete LevelUpUI have no runtime callers;
- code, scenes, catalogs, saves, tests, and governance docs describe the same
  contracts;
- focused and full regression suites pass without Godot error markers;
- editor, main scene, Autumn map, Growth UI, and combat preview smoke checks
  pass;
- all required viewport captures have been visually inspected;
- no duplicate UI authority or temporary capture script remains.
