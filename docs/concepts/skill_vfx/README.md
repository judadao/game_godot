# Named Skill VFX Concept Bible

The painted base-part contract is `data/named_skill_vfx_profiles.json`; the
complete 32-Finisher identity contract is
`data/finisher_vfx_identities.json`. Concept boards define silhouette and material
language; the detailed continuous-action authority is
`docs/art_concepts/finisher_choreography/`. Runtime Finishers hide all five legacy
atlas parts and use one twelve-frame painted object sequence plus a pure CanvasItem
2.5D choreography stack, without embedding a 3D SubViewport.

The 2.5D stack uses front/mid/back z-depth, directional parallax, semantic contour
shading, rim/back light, foreground fragments, and physical residue. All frames share a
horizontal ground anchor with zero whole-sprite rotation; grounded objects travel horizontally,
gravity objects move vertically, and depth comes from scale, overlap, spacing and z-order. The twelve-frame authored
object must be readable before secondary light and particles are added. Generic
ground sigils, concentric rings, clock ticks, radial grids, and pasted icons are
forbidden because they do not explain the move's object or force.

## Finishers

The authoritative list contains 32 distinct Finishers, not the five rows from the
retired concept board. Each move has its own semantic object and continuous
anticipation → travel → contact deformation → residue choreography. Read the
complete specification in `docs/art_concepts/finisher_choreography/README.md`
and its three linked batches; keep the identity mapping synchronized with
`data/finisher_vfx_identities.json`.

## Named triggers

| Skill | Readable silhouette | Three-beat timing |
| --- | --- | --- |
| Iron Momentum | Forged-steel forward chevrons | Five ticks → momentum drive → armor lock |
| Ember Reprise | Repeated red-white sword traces and phoenix crest | Echo phrase → crossing reprise → wing crest |
| Battle Tempo | Five timing ticks and action-point diamond | Beat rail → synchronized pulse → AP resolve |
| Grand Strategy | Tactical diamond grid and navy-gold ward | Four paths → folded crest → protective shell |

The only fire-dominant identities are 焚天滅 and Ember Reprise. Other profiles
must retain metallic, lightning, celestial-geometric, frost-crystal, rhythm, or
tactical silhouettes even if later Combo mutations add a secondary element.

Generated concept boards:

- `finishers_concept_v1.png`
- `passive_triggers_concept_v1.png`

Generated modular atlases:

- `res://assets/generated/vfx/named_skills/finisher_parts_atlas_v1.png`
- `res://assets/generated/vfx/named_skills/passive_parts_atlas_v1.png`
