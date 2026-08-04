# Expedition World Generation Manifest

## 1. Scope

This pass generated four opaque production background plates and six transparent
terrain atlases with the built-in `imagegen` workflow. Portal glows, seals,
labels, collisions, actors, and encounter behavior remain separate Godot-owned
objects.

## 2. References

- `concept/town/main_horizontal_concept/town_style_direction_a_locked.png`:
  B2/Town stone, timber, painterly lighting, frontal camera, and authored pixel
  clustering reference.
- `assets/environments/autumn_town_style/generated/autumn_forest_background.png`:
  pixel density, atmospheric depth, and side-view gameplay readability reference.

## 3. Outputs

| Output | Role |
|---|---|
| `assets/environments/expedition/generated/battle_portal_sanctuary.png` | Four empty side alcoves plus one central sealed Boss arch; no baked portal animation |
| `assets/environments/expedition/generated/heaven_sanctuary_background.png` | Heaven, Heaven Autumn, and Heaven Crystal route／arena background module |
| `assets/environments/expedition/generated/hell_rift_background.png` | Hell, corrupted Autumn／Crystal, and Disorder Hell route／arena background module |
| `assets/environments/expedition/generated/crystal_cavern_background.png` | Hand-drawn Crystal cavern depth plate with no baked collision floor |
| `assets/environments/expedition/generated/crystal_terrain_atlas.png` | Transparent long floor, three platform spans, end caps, and crystal clusters |
| `assets/environments/expedition/generated/hell_autumn_terrain_atlas.png` | Scorched-leaf masonry, ember roots, broken bridge, and Hell Autumn platforms |
| `assets/environments/expedition/generated/heaven_autumn_terrain_atlas.png` | Gold-leaf ivory masonry, celestial roots, bridge, and Heaven Autumn platforms |
| `assets/environments/expedition/generated/hell_terrain_atlas.png` | Basalt, magma seams, chains, broken bridge, and Hell Rift platforms |
| `assets/environments/expedition/generated/disorder_hell_terrain_atlas.png` | Violet fractured basalt, void／teal accents, and Disorder Hell platforms |
| `assets/environments/expedition/generated/heaven_terrain_atlas.png` | White-gold floating stone, sacred bridge, and Heaven Sanctuary platforms |

The local image-generation captures used for the five dedicated concept atlases
are retained outside the repository for traceability:

| Runtime output | Local source capture |
|---|---|
| `hell_autumn_terrain_atlas.png` | `/home/judd/.codex/generated_images/019fac8a-5345-7532-9ba4-fb33b8ca1ebd/exec-53bc95e3-dc67-4162-9c13-9f71fab3301b.png` |
| `heaven_autumn_terrain_atlas.png` | `/home/judd/.codex/generated_images/019fac8a-5345-7532-9ba4-fb33b8ca1ebd/exec-b095b936-62ae-4dc7-9b1e-524622a288ef.png` |
| `hell_terrain_atlas.png` | `/home/judd/.codex/generated_images/019fac8a-5345-7532-9ba4-fb33b8ca1ebd/exec-347c142d-4728-431c-8830-e3bbe02b32c3.png` |
| `disorder_hell_terrain_atlas.png` | `/home/judd/.codex/generated_images/019fac8a-5345-7532-9ba4-fb33b8ca1ebd/exec-b2ecd4a3-6ac6-460d-ad3e-59a411e2de5d.png` |
| `heaven_terrain_atlas.png` | `/home/judd/.codex/generated_images/019fac8a-5345-7532-9ba4-fb33b8ca1ebd/exec-4bff6c03-83b5-428e-9079-97c2010afa77.png` |

## 4. Reproduction prompts

All three prompts required a frontal orthographic side-view, softly clustered
hand-painted pixel art, restrained ink edges, irregular masonry, readable depth,
and no characters, text, UI, watermark, glossy gradients, or active portal
effects. The portal prompt requested four symmetric empty alcoves around one
taller sealed central rune door and a clear flat foreground. Heaven requested
cloud layers, floating cathedral ruins, white-gold marble, and a clear gameplay
band. Hell requested basalt ruins, volcanic depth, ember haze, and a clear
foreground without baked gameplay obstacles. Crystal requested the same Town／
Autumn hand-painted pixel clustering with slate cave walls, cyan crystal light,
soft atmospheric depth, and an unobstructed gameplay band. The terrain sheet
requested frontal orthographic slate blocks, cyan seams, three platform sizes,
two end caps, and four crystal clusters on a solid magenta chroma background;
the repository imagegen `remove_chroma_key.py` helper converted that background
to alpha before Godot import. The five later sheets use the same modular
requirements but receive independent concept topology: scorched autumn,
celestial autumn, ordered basalt Hell, destabilized violet／teal Hell, and
white-gold Heaven. They were generated on uniform green chroma and converted
with the same repository helper; runtime does not tint one shared atlas into
these identities.

## 5. Integration contract

- Never use the generated plates as collision truth.
- Long routes repeat the plate behind 24 independently generated chunks.
- Theme variants override palette, accent, encounter multiplier, and progression
  identity without copying Player, HUD, portal, or collision ownership.
- Every non-Autumn route and its matching Boss arena reference the same dedicated
  terrain atlas; only the three Crystal generations intentionally share Crystal.
- Replacing any plate must preserve the frontal horizon and unobstructed bottom
  gameplay band.

## 6. Review checklist

- [x] Opaque source files imported successfully as `Texture2D`.
- [x] Portal apertures and central sealed door remain readable.
- [x] Heaven and Hell plates preserve a flat side-view gameplay band.
- [x] Crystal has independent background, terrain art, fallback floor, and collision.
- [x] Hell Autumn, Heaven Autumn, Hell Rift, Disorder Hell, and Heaven Sanctuary
  have independent concept terrain atlases and transparent modular parts.
- [x] Every regional Boss room uses authored floor and platform art instead of
  exposed fallback polygons.
- [x] 1,280 × 720 and 1,600 × 900 layout contracts pass headless.
- [x] Six route zones expose modular chunk coverage.
- [ ] Independent-agent visual review was not run because this task did not
  authorize delegation; final in-game art approval remains with the user.
