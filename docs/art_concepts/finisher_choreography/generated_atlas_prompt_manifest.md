# Finisher Atlas Generation Manifest

This manifest records the reproducible visual brief for the final 2.5D finisher
atlases in `assets/generated/vfx/finisher_parts_v4/`. The generated rewrites in
this pass used the built-in `imagegen` mode. Existing source atlases were used
only as palette, material, camera, and scale references; their projectile-like
composition was not treated as choreography.

## Common atlas contract

Apply this common prompt template before the move-specific delta:

> Produce one exact 1536 × 1024 PNG storyboard atlas arranged as a strict 4 × 3
> grid, 12 equal frames in row-major order. Use a pure `#000000` background with
> no drawn grid, text, captions, UI, watermark, magic circles, or decorative
> lines without a physical cause. Keep one stable side-view 2.5D camera, one
> stable hero/ground anchor, and consistent materials across every frame. Build
> a readable continuous action: anticipation, physical construction, travel or
> transfer, exactly one contact climax, then decay and residue. Do not launch a
> flat icon or completed illustration. Every line must define an object edge,
> force path, crack, fluid strand, or sourced particle trajectory. Avoid a
> second climax, reset poses, duplicated explosions, broken geometry, false
> seams, clipped objects, and unexplained material changes.

After generation, inset each storyboard cell proportionally so every cell has a
raw 20-pixel pure-black safety border. This post-process must preserve the atlas
dimensions and frame order. The four legacy 1448 × 1086 atlases retain their
original dimensions and receive the same per-cell 20-pixel border contract.
The same deterministic pass converts every background pixel whose red, green,
and blue channels are all at most 12/255 to opaque `#000000`. This applies to
the entire atlas, not only its outer margin, so faint generated cell rectangles
cannot survive as false seams.

## Authored differentiated atlases

Each row applies the common contract plus the listed move-specific choreography.

| Move | Workspace atlas | Move-specific delta |
| --- | --- | --- |
| Blade Forge | `assets/generated/vfx/finisher_parts_v4/blade_forge_sequence.png` | Nested forged ribs close around an incomplete blade; weld chips mark each join; the hero blade visibly gains length and mass before one strike; end on a cooling scar and slag. |
| Horizon Reversal | `assets/generated/vfx/finisher_parts_v4/horizon_reversal_sequence.png` | A thick horizon slab fixes the stage axis; inward air sheets compress into a reverse prism crescent; the release flips that mass through the target and leaves a split horizon afterline. |
| Blade Rain | `assets/generated/vfx/finisher_parts_v4/blade_rain_sequence.png` | Form staggered wet blade groups at distinct depths, drive them down in a readable sequence, raise one ground crown at contact, and leave embedded tips plus a coherent puddle. |
| Boundary Feather | `assets/generated/vfx/finisher_parts_v4/boundary_feather_sequence.png` | Asymmetric forged feathers split, launch, hinge, and return as solid articulated objects; the single contact leaves a narrow slit and gold chips rather than a generic burst. |
| Wind Lane | `assets/generated/vfx/finisher_parts_v4/wind_lane_sequence.png` | Three tangible air membranes source their dust and leaves from the ground; the membranes establish a lane, close it around the target, then unzip and shed the same debris. |
| Breath Condense | `assets/generated/vfx/finisher_parts_v4/breath_condense_sequence.png` | Indigo breath silk knots around gold nodes, compacts into one reserve pearl, emits one short pulse, and ends as a damp curl and extinguished nodes. |
| Water Resource | `assets/generated/vfx/finisher_parts_v4/water_resource_sequence.png` | Basin plates assemble first, feed a rising water column, spread into a shield skin that visibly dents under one hit, then drain into beads and a wet ground patch. |
| Fire Flow | `assets/generated/vfx/finisher_parts_v4/fire_flow_sequence.png` | Ground cracks feed a low horizontal fire river and wave; it curls once at contact, then cools into crust and smoke. No volcano, diagonal fireball, or second flare. |
| Ice Ground | `assets/generated/vfx/finisher_parts_v4/ice_ground_sequence.png` | Frost plates propagate along the floor, grow into a coffin with sequential cracks, open as hinged slabs, and finish as meltwater around the same anchored ice mass. |
| Sunbearing Dawn | `assets/generated/vfx/finisher_parts_v4/sunbearing_dawn_sequence.png` | Beam slabs gather into cupped leaves, close as a leaf shell, open for one dawn release, and decay into a seed and small sprout. |
| Spirit Lifeline | `assets/generated/vfx/finisher_parts_v4/spirit_lifeline_sequence.png` | Three water-leaf spirits take separate clean routes, converge into one grounded restorative bloom, and settle as mud, water beads, and sprouts. |
| Root Intercept | `assets/generated/vfx/finisher_parts_v4/root_intercept_sequence.png` | Team roots braid into a mother branch that physically intercepts the incoming force; fibers carry captured liquid back along the braid before the roots relax. |
| Plant Growth | `assets/generated/vfx/finisher_parts_v4/plant_growth_sequence.png` | Moss and trunk mass grow first, divide into shield leaves and blade leaves, route sap through a visible curl and sheet, then collapse into a seed. |
| Feather Cadence | `assets/generated/vfx/finisher_parts_v4/feather_cadence_sequence.png` | Establish a red short beat, ivory short beat, then gold long beat; preserve the differing cadence through their echoes and scars and leave one embedded gold shaft. |
| Feather Blade Return | `assets/generated/vfx/finisher_parts_v4/feather_blade_return_sequence.png` | A plow feather opens the ground path; hinged feathers launch in groups of 3, 3, and 2, reverse along the established path, and leave a slit and furrow. |
| Mirror Return | `assets/generated/vfx/finisher_parts_v4/mirror_return_sequence.png` | Three asymmetric active panels assemble a mirror fortress, retain visible stored scars, then release broad glass wedges; end with matching chips and scratches, not an energy ball. |

## Independent-review PROC7 regeneration

The independent visual review rejected seven of the initially authored atlases
for object substitution, presentation-slide scaling, discontinuous direction,
or multiple peaks. They were regenerated with built-in `imagegen`; the prior
atlas in each workspace path was a material/camera reference only.

The shared regeneration prompt added these invariants to the common contract:
one level horizontal ground plane, vertical gravity, a fixed right-facing 2.5D
camera, and the exact same named hero object/material/topology from frame 1 to
frame 12. Each frame is a small physical time-step. There is exactly one
contact/recovery peak followed only by decay. Flat picture launching, PPT-like
resizing, plastic capsules, tubular beams, high-frequency debris, unexplained
lines, teleporting, mirroring, and post-impact re-bloom are prohibited.

### Fire Flow regeneration

Path: `assets/generated/vfx/finisher_parts_v4/fire_flow_sequence.png`

Track one orange-red fire spiral, its clockwise hooked crest, and its dark ember
root throughout: ember root; ankle-high first wrap; second low wrap; tightened
heat gather; connected outer turn uncoils right; same spiral stretches along the
floor; one low broad connected ribbon; crest compresses before contact; the only
climax is one right-side bend/strike; recoil into three connected tongues;
vertical ember fall; low root scar, two dying flames, and smoke. The crest may
never mirror, jump, reset, become a fireball, or form a second wave.

### Wind Lane regeneration

Path: `assets/generated/vfx/finisher_parts_v4/wind_lane_sequence.png`

Track one source curl at the left ground scar: it lifts two leaves; lengthens
into three folds; separates into exactly three open parallel lanes; deepens
without enclosing debris; compresses right; the same three lanes converge;
their upstream membranes remain visible; one narrow blade forms at the meeting
point; the only climax is one right-target hit while all three feed lanes remain
connected; pressure releases backward; membranes loosen under vertical gravity;
three faint ground streaks and two fallen leaves remain. No closed pod, capsule,
opaque dirt-filled body, or three unrelated projectiles.

### Sunbearing Dawn regeneration

Path: `assets/generated/vfx/finisher_parts_v4/sunbearing_dawn_sequence.png`

Track one seed husk, central stem, and its persistent nodes: husk splits; the
same shoot straightens into node one; left leaf opens; next stem segment and
right leaf grow; third leaf unfolds; attached leaves cup inward; two more leaves
complete an upward bowl; those same leaves hinge into a sun-bearing shell; the
only climax opens that shell into a broad dawn flare; light falls while leaves
sag; stem bows; the same seed, short stem, and three resting leaves remain. No
tubular light column, pipe elbow, detached replacement sprout, or repeated flare.

### Spirit Lifeline regeneration

Path: `assets/generated/vfx/finisher_parts_v4/spirit_lifeline_sequence.png`

Track one leaf-wrapped water bladder and its rooted lifeline vine: closed bladder
with visible water; one leaf seam opens; one connected stream reaches the flower
base; lower petal layer fills; second layer fills; bladder shrinks by that exact
volume as layer three fills; remaining water reaches the heart; bladder is nearly
empty while the flower is nearly full; the only climax is one blue-green healing
bloom; the same flower half-closes and drains to roots; empty bladder folds and
beads fall; continuous vine, bladder shell, living flower sprout, and quiet
puddle remain. No giant orb, flying pods, double bloom, or unrelated seedlings.

### Plant Growth regeneration

Path: `assets/generated/vfx/finisher_parts_v4/plant_growth_sequence.png`

Track one seed, one dark-brown stem, six fixed growth nodes, and six persistent
leaves in clockwise order: stem hook emerges; node one and first nub; nodes two
and three; leaf one lengthens; leaves two and three open; leaves four and five
begin as the same stem bends; all six fixed leaves become visible; the stem closes
into one rooted open ring; the only climax is a single rightward circumferential
leaf-blade sweep; the same six-leaf ring relaxes and sap returns; leaves droop in
their original order; the seed, shortened stem, six attached wilted leaves, and
sap scar remain. No trunk fork, instant leaf fan, detached swarm, or topology
switch.

### Feather Cadence regeneration

Path: `assets/generated/vfx/finisher_parts_v4/feather_cadence_sequence.png`

Track exactly three forged feathers: A is short red, B is short ivory, and C is
long gold. The three colored buds appear together; A reaches its final short
length; B reaches the same short length; C reaches its longer final length; A
accelerates first along one right tangent; B follows without replacing A; C
follows as the long beat; spacing preserves short-short-long rhythm; all three
arrive together without merging; the only climax is one shared-tangent right
cut with three matching colored notches; those same feathers slow and fall
vertically; their three bent shafts remain in red/ivory/gold order beside one
horizontal scar. No disappearing red feather, giant replacement white feather,
vertical planting, pose swap, extra feather, or second impact.

### Mirror Return regeneration

Path: `assets/generated/vfx/finisher_parts_v4/mirror_return_sequence.png`

Track one amber incoming wedge and the same three active smoked-glass panels in
bronze frames: frames hinge up; the three-panel asymmetric fortress locks; the one wedge
enters from left; panel one absorbs it and records its directional crack; the
diminishing same energy reaches panel two and then panel three; all three stored
traces reverse only along those recorded angles; three thin amber wedges exit
and converge as buildup; the only climax is one broad right/outward
counter-cut; same-material chips fall vertically; the three original cracked
panels and their small amber scars remain. No blade before absorption, unrelated
sword, arbitrary crack, bright crossed X, or separate frame-9/frame-11 peaks.

Final tail continuity correction: frames 11 and 12 retain all three original
asymmetric smoked-glass panels. The right active panel is the same authored
panel recovered from the pre-climax sequence, progressively darkened behind the
existing small falling chips; it never swaps wholesale into a shard cloud.
Frame 10 remains the sole brightness/energy peak. Frames 11 and 12 contain only
decreasing light, darker glass, settled scars, and sparse gravity-led residue.

## Content-rewrite prompts

These three atlases were regenerated because the prior versions reset their
objects, fired a finished picture, reversed causality, or repeated the climax.
Use the common contract and these exact frame beats.

### Shield Counter

Path: `assets/generated/vfx/finisher_parts_v4/shield_counter_sequence.png`

1. Six dark iron plates lie as a compact pile around a brass hub.
2. The plates hinge upward; every plate stays traceable.
3. The plates close into one shield body.
4. Brass locks engage and establish a clear right-facing counter axis.
5. Incoming force makes only a dim shallow dent on the left/front face; there
   is no flare or fragment burst.
6. Captured amber force routes quietly around the shield rim.
7. Existing right-side plates pivot into the first attached wedge-ram segment.
8. A second segment telescopes from the first without leaving the assembly.
9. The third nose segment extends to the right along the established axis.
10. The only climax: the ram nose flattens at the right target and sheds iron
    chips and amber sparks.
11. The nose and middle segments visibly telescope halfway back while plates
    and chips fall; no new burst appears.
12. Leave a dim shield stump, one short bent attached ram segment, iron chips,
    brass fragments, and one short ground scratch.

Do not introduce a second explosion, a tongue-shaped loose plate, an ambiguous
attack direction, or unexplained projectiles.

### Ice Fire Bloom

Path: `assets/generated/vfx/finisher_parts_v4/ice_fire_bloom_sequence.png`

1. One frost root and one ember share a single ground anchor.
2. Two ice sepals grow around that same ember.
3. A closed six-petal ice bud forms while violet toxin gathers inside it.
4. A fire stem rises inside the closed bud, never as a separate column.
5. Heat enters the petal veins and turns their inner edges into meltglass.
6. The still-connected bud partially opens as one fused ice-fire body.
7. The same body widens, half ice crystal and half molten glass.
8. It becomes a nearly open flower without shattering or resetting.
9. The only climax: the same connected flower reaches full bloom and delivers
   the strike.
10. The flower decays in place; petals crack and sag instead of blooming again.
11. Two plates detach into a puddle while the root remains visible.
12. Leave a five-lobed violet puddle, blue melt plates, and one orange scar.

Do not shatter at frame 8 and rebuild at frame 9, separate the fire into an
unrelated column, or create multiple blooms.

### Shield Exchange

Path: `assets/generated/vfx/finisher_parts_v4/shield_exchange_sequence.png`

1. A dark metal ground anchor fixes the exchange axis.
2. The shield frame rises from that anchor.
3. Two shield halves assemble around one internal channel.
4. The shield closes and the channel clearly runs left to right.
5. Incoming force makes only a small dim red dent on the left face; there is no
   impact flare or fragment burst.
6. Captured red-gold energy moves from the left face to the center.
7. The same energy continues from the center to the right outlet.
8. It mechanically extrudes the first short segment of one solid right-facing
   red-bronze slug at the outlet.
9. Two more slug segments telescope only to the right while a thin bronze rail
   keeps the mass physically attached to the channel.
10. The only climax occurs at the right target, producing red crystal and bronze
    fragments in a one-sided fan.
11. The shield dims and matching fragments fall; no returning beam appears.
12. Leave a dented shield, right-side red/bronze fragments, and one red-gold
    ground scratch with no white droplets.

Do not create a bidirectional beam, reverse transfer, tail-end white particles,
or a second impact.

## Count-continuity correction

### Lightning Prison

Path: `assets/generated/vfx/finisher_parts_v4/lightning_prison_sequence.png`

The built-in image generator supplied the purple-lightning/copper-material
rewrite, followed by a deterministic safety-border pass. Frames 1–6 show
exactly five copper bases and five lightning columns, with fixed left-to-right
fork/ring/cone/ring/fork top silhouettes. The outer pair hinge inward while the
center three stay visible; all five bodies then slide on rails into five
separable cannon subassemblies around one chamber. Frame 11 contains the only
right-facing lightning-spear climax. Frame 12 must retain exactly five scorched
base pits and five bent copper remnants. Do not change the pillar count, hide a
support during the gun transformation, or reduce the prison to a generic
rectangle.

## OLD7 continuity rewrites

### Bone Forge

Path: `assets/generated/vfx/finisher_parts_v4/bone_forge_sequence.png`

Six paired ribs stay connected to one vertebral armature. The same bones rotate
on brass pivots into an open forearm cage, connect into a wrist and palm, then
unfold five continuous finger chains. Each phalanx curls progressively into the
same fist. Frame 10 is the only target impact; frame 11 holds the cracked target
while the fist retracts, and frame 12 relaxes the same traceable hand. Never
replace the rib cage with a disembodied hand or swap an open hand directly for a
finished fist.

### Moon Descent

Path: `assets/generated/vfx/finisher_parts_v4/moon_descent_sequence.png`

Retain the existing connected moon formation, descent, ground contact, fracture,
and rubble choreography at the original 1448 × 1086 native size. Apply the
whole-atlas near-black normalization so every former RGB 5–6 cell rectangle is
pure black. Do not add a second impact or change the moon's material between
descent and residue.

### Poison Orchid

Path: `assets/generated/vfx/finisher_parts_v4/poison_orchid_sequence.png`

One rooted dark-violet orchid opens in place. Purple toxin routes through its
left roots while green healing dew routes through its right roots as two
subordinate branches of the same release. Both sides grow together and feed one
central frame-10 pressure pulse, the only climax. The same petals then fold and
the same vines sag into connected purple/green residue. Do not stage separate
left and right attacks or leave a gray background panel.

### Stream Collection

Path: `assets/generated/vfx/finisher_parts_v4/stream_collection_sequence.png`

Three water ropes rise from three visible ground springs and travel only left to
right. The same ropes braid into one low basin, rise as one complete contained
water column, and fold into one connected water wall. Frame 11 is the sole
right-target impact; frame 12 drains the same mass into a grounded puddle. No
arrows, gold stars, UI symbols, reversed flow, parallel diagram lines, clipped
column, or instant wave-image replacement are allowed.

## Legacy pass-only atlases

These three atlases retained their existing choreography and received only the
deterministic per-cell safety-border pass; no image-generation prompt was
applied in this task:

- `assets/generated/vfx/finisher_parts_v4/stone_mountain_sequence.png`
- `assets/generated/vfx/finisher_parts_v4/stone_orbit_counter_sequence.png`
- `assets/generated/vfx/finisher_parts_v4/root_marker_chain_sequence.png`

## Review contract

Review every final atlas at full/native detail and as six equal image slices in
a fixed 3-column × 2-row grid. Reject mushy texture, meaningless repetition,
broken geometry, false seams, inconsistent material frequency, uncaused lines,
flat-icon launching, object resets, or more than one climax. Any image change
invalidates the previous visual approval and requires both reviews again.

## MATERIAL12 material-plate corrections

All twelve plates retain the repository-native 1254 × 1254 canvas. After the
content operation, the whole plate is proportionally inset into the same canvas
with a deterministic 32 px pure-black safety border. The final outer 20 px must
remain exact RGB (0, 0, 0).

### Enduring Arcane Breath

Path: `assets/generated/vfx/finishers_v2/enduring_arcane_breath_material.png`

Built-in image-generation round-two replacement from a blank composition.
Exactly four thick, materially distinct breath bodies reverse-flow right to
left: a far-back cold mist-cloth band, rear-mid refractive liquid pipe,
front-mid chunky braided arcane rope, and foreground glass-silk tube with only a
few embedded gold veins. Their broad surfaces, unequal thickness, and major
occlusions establish separate depths. All four feed through visible necks into
one irregular, asymmetric, multifaceted teardrop breath bead on the left; the
bead uses unequal facets, a chipped short edge, off-centre point, and gold repair
seams instead of a sphere, diamond, star, or logo. No repeated decorative
ribbons, fine line web, symmetry, wings, bright-dot field, droplet shower,
magic circle, text, or UI.

### Horizon Stream

Path: `assets/generated/vfx/finishers_v2/horizon_stream_material.png`

Built-in image-generation rewrite. One thick, horizontal dark-metal cutting
platform carries a compressed gold-white plasma edge. Exactly one solid reverse
crescent metal cutter physically bites into it at an off-centre contact point,
with molten scoring, one coherent impact wedge, and restrained depth-separated
smoke and metal chips. No abstract crossing lines, brush explosion, starburst
logo, duplicate crescent, magic circle, text, or UI.

### Returning Shared Pulse

Path: `assets/generated/vfx/finishers_v2/returning_shared_pulse_material.png`

Built-in image-generation round-two replacement from a blank composition.
Exactly three solid organic blood-vessel/root conduits enter from left-back,
left-mid, and left-front. Each has a thick external shell, visible lumen and cut
wall, scar ridges, unequal depth/diameter, and its own physical collar joint.
Exactly one continuous gold pulse band remains inside each tube cavity; it is
not an overlaid capsule, leaf, or projectile. The three collars plug into one
obliquely tilted, single-leaf ceramic healing core on the right. Its long upper
edge, torn shorter lower edge, chipped ivory wall, off-centre spirit cavity, and
gold-repaired wound make the silhouette deliberately asymmetric. No polygon
web, wireframe, random filament, heart, symmetric seed, multi-petal emblem,
magic circle, text, or UI.

### Margin-only retained material plates

No image-generation prompt or content rewrite was applied to the following
plates. Their existing object, material, geometry, colour, and composition are
retained; only the deterministic whole-image 32 px proportional inset was
applied:

- `assets/generated/vfx/finishers_v2/evergreen_court_material.png`
- `assets/generated/vfx/finishers_v2/falling_moon_arc_material.png`
- `assets/generated/vfx/finishers_v2/frost_orchid_flame_material.png`
- `assets/generated/vfx/finishers_v2/guarding_shared_pulse_material.png`
- `assets/generated/vfx/finishers_v2/heavenly_wheel_sever_material.png`
- `assets/generated/vfx/finishers_v2/inferno_cremation_material.png`
- `assets/generated/vfx/finishers_v2/returning_spring_spirits_material.png`
- `assets/generated/vfx/finishers_v2/still_mountain_material.png`
- `assets/generated/vfx/finishers_v2/thunder_prison_pierce_material.png`

Final review inspected all twelve integrated plates at full/native detail and as
six equal spatial slices in a fixed 3-column × 2-row grid after the last pixel
change. The review also checked the three rewrites for concrete physical cause
and effect, single-subject hierarchy, meaningful depth, clean geometry, and the
absence of AI-style repetition or false seams.
