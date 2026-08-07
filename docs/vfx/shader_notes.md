# Godot 4.7 VFX Shader Notes

## Pipeline

`canvas_item` shaders draw 2D surfaces. `vertex()` may deform geometry before rasterization;
`fragment()` samples `UV`, textures and `TIME` to determine each pixel. Parameters that an
artist must tune are uniforms, not literals hidden inside effect code. Pixel-art materials
quantize UV or time before sampling and keep texture filtering nearest where applicable.

Particle shaders are simulation programs, not draw shaders. `start()` initializes particle
state while `process()` advances `VELOCITY`, `TRANSFORM`, `COLOR`, `CUSTOM` and other built-ins.
They run only on `GPUParticles2D`; ordinary movement should remain in
`ParticleProcessMaterial`, with a custom particle shader reserved for motion it cannot express.

## Reusable techniques

- Noise: combine a few octaves at decreasing amplitude; expose scale and strength. Noise is a
  mask or displacement source, not the final shape by itself.
- UV distortion: remap noise from `[0, 1]` to `[-1, 1]`, multiply by a small bounded strength,
  and preserve a stable root/edge where the silhouette needs to stay anchored.
- Gradient: map one scalar such as heat, depth, age or distance to a small intentional palette.
- Alpha: author transparent output directly. Additive blending does not repair a colored or
  opaque rectangular background.
- Pixel motion: quantize UV and, selectively, time. Shape changes must remain smooth enough to
  avoid a low-frame-rate GIF impression.
- Dissolve: compare a controllable threshold with noise plus an optional directional gradient;
  derive a narrow edge band separately from the removal mask.
- Glow: render a wider low-alpha pass behind a narrow opaque core. This remains readable with
  WorldEnvironment glow disabled and improves when glow is enabled.

## Particle checklist

Every `GPUParticles2D` declares an amount, lifetime, one-shot state, visibility rect, local/global
coordinate intent and process material. Burst effects use high explosiveness; continuous effects
use preprocess and a low emission spread over time. Velocity, gravity, damping, scale curve and
color ramp describe a particle's full lifetime instead of only its spawn frame.

## Performance guardrails

- Primitive particle counts are capped at 160 per particle layer.
- Visibility rectangles must cover the effect without using map-sized defaults.
- Do not sample the screen texture unless refraction materially helps the effect.
- Keep procedural noise octave counts small and avoid full-screen fire/cloud materials.
- Prefer one reusable material and parameter overrides over per-skill shader copies.

References: [Godot shader introduction](https://docs.godotengine.org/en/stable/tutorials/shaders/introduction_to_shaders.html),
[shader reference](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/), and
[particle shader reference](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/particle_shader.html).
