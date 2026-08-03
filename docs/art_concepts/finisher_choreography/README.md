# Finisher 2.5D Choreography Bible

This folder is the mandatory visual pre-production authority for all 32 Combo
Finishers. A Finisher does not enter asset generation or runtime integration
until its written sequence makes the named action, object, material, and impact
readable without relying on UI text.

## Authorship order

1. Read the exact Combo name, icon, description, role, sequence, and base effect.
2. State one concrete dramatic idea. Avoid generic goals such as "more epic" or
   "stronger glow".
3. Define a recognizable semantic object built from geometry and authored
   strokes: flame, ice coffin, dragon, lunar blade, mountain, orchid, feather,
   thunder spear, shield, wellspring, blood link, or another name-bound object.
4. Describe its continuous anticipation, construction, travel, contact,
   transformation, and residue. Each beat must causally follow the previous one.
5. Assign front, middle, ground, and rear planes. Depth must support the object;
   it cannot be simulated by unrelated rings or random line density.
6. Assign key, rim, reflected, and residual light to real emitting or reflecting
   material in the sequence.
7. Name the physical source of every particle family. A particle with no source
   is removed.
8. Generate or author the 4×3 twelve-frame sprite sequence only after the sequence is approved.
9. Build the semantic object first, apply body/tight/wide glow second, and
   add impact fragments last.
10. Review the moving sequence at gameplay scale. A still impact frame, parse
    pass, or high layer count cannot approve choreography.

## Runtime piece choreography contract

The written timeline is implemented through the 32 one-to-one profiles in
`data/finisher_vfx_identities.json::choreography_profiles`. The implementation
must resolve the listed semantic pieces into one continuous twelve-frame painted object
sequence. Runtime displays one authored frame at a time without cross-fade. Every frame
shares the same horizontal ground anchor and zero whole-sprite rotation; grounded travel is
horizontal and gravity travel is vertical. Depth comes from scale, overlap, spacing and z-order,
never from tilting the entire lane. Generated material plates stay hidden and must never
translate, rotate, scale, or reveal the complete square plate as a second actor.

Every profile owns these runtime fields, also mirrored under its
`geometry_identity` so the effect core can consume them directly:

- `choreography_family`: a unique construction and motion family;
- `spawn_mode` / `spawn_primitives`: what concrete pieces appear, and in what
  causal order;
- `piece_count`: authored hero-piece counts, not a generic particle count;
- `formation`: the readable arrangement before travel;
- `travel_path` / `paths`: ordered paths for the independent pieces;
- `impact_mode` / `impact`: material-specific contact deformation;
- `residue_mode` / `residue`: physical matter left after the strike.

`piece_specifications.md` is the compact visual checklist for all 32 profiles.
The batch documents remain the frame-by-frame authority when a compact entry and
the detailed timeline need to be read together.

## Meaningful geometry rule

Geometry and strokes are welcome when they construct a readable object or show
motion and force. A crescent is a moon or blade only when its construction,
motion, lighting, and contact behavior support that reading. A closed polygon is
a shield only when it blocks, deforms under impact, and redirects the stored
force. The following are prohibited as universal decoration:

- concentric rings that do not construct the named object;
- clock ticks, radial spokes, and grids added only to fill negative space;
- pasted icon echoes;
- a white center flash that hides the main object at contact;
- the same burst, orbit, or magic circle recolored across unrelated Finishers;
- simultaneous fade-ins that read as independent presentation-slide elements.

## Required entry fields

Every Finisher entry in the batch documents must include:

- dramatic intent;
- environmental response;
- semantic-object construction from lines and geometry;
- continuous action and 2.5D plane choreography;
- contact deformation or destruction;
- concrete residual material;
- light, material, and color progression;
- particle sources;
- prohibited shortcuts;
- one impact-material generation prompt.
- one matching entry in `piece_specifications.md` and
  `choreography_profiles`, with no fallback to whole-plate movement.

The batch documents cover the recipes in the order used by
`data/combo_finishers.json`. The complete set must contain exactly 32 unique IDs
before implementation resumes.
