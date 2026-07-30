# Elemental Ground Paths V1

## Purpose

Ultimate ground residue is assembled from reusable 2D parts instead of playing one
full-effect image. Runtime damage remains owned by `CardEffectRunner`; these atlases
are presentation only.

## Atlas contract

Every atlas is 1536×1024 RGBA and uses the same non-overlapping 2×2 layout:

| Slot | Region | Role |
|---|---|---|
| Core | `(0, 0, 768, 512)` | ground footprint |
| Edge | `(768, 0, 768, 512)` | raised or active boundary |
| Accent | `(0, 512, 768, 512)` | cracks, veins, or secondary flow |
| Debris | `(768, 512, 768, 512)` | sparks, shards, droplets, or mist |

Runtime assets:

- `fire_ground_path_parts_v1.png`: charred bed, flame rim, molten cracks, embers.
- `ice_ground_path_parts_v1.png`: frozen plate, crystal ridge, frost fractures,
  snow and ice splinters.
- `poison_ground_path_parts_v1.png`: toxic pool, bubbling slime edge, corrosive
  veins, droplets and spores.

## Shape language

- Fire forms two opposing sweeping scars that follow the caldera wave.
- Ice forms one forward rift and two asymmetric branches.
- Poison forms irregular connected pools and must not reuse a flame silhouette.
- Core, Edge, Accent, and Debris reveal independently along sampled path segments.
  A low-alpha procedural ribbon may bridge segments, but cannot replace the atlas.

## Generation and cleanup

The source prompt requests an orthographic 2D action-RPG VFX atlas with four isolated
modules, generous padding, no character, weapon, text, UI, or full-screen
illustration. Fire used a uniform green chroma background; ice and poison used
uniform `#ff00ff` to protect their blue and green palettes. Chroma removal used:

```bash
python <imagegen-skill>/scripts/remove_chroma_key.py \
  --input <source.png> \
  --out <runtime.png> \
  --auto-key corners \
  --soft-matte \
  --transparent-threshold 8 \
  --opaque-threshold 72 \
  --edge-contract 1 \
  --edge-feather 0.7 \
  --spill-cleanup
```

Any replacement atlas must retain the dimensions and regions above or update the
profile catalog, runtime tests, and this document together.
