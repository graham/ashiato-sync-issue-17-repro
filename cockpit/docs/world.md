# cockpit — the world it is flown over

Part of [`agents.md`](../agents.md), which carries the rules every one of these files assumes and an
index of the rest. **The ground, the sky, the scenery and its cost, the levels, and the places
built on it.**

## THE RAILWAY

**A train is a 1D problem wearing a 3D costume.** That sentence is lifted from
`../../previous_projects/august-15-train`, which put it better than I would have, and the whole
design follows from it: a train owns one scalar position along the railway and one scalar
speed, and everything else -- where it is, which way it faces, how it leans -- is read back
off the track from those two numbers.

So a train's entire replicated state is **thirty bits instead of a hundred and sixty**. The
pose is not on the wire at all: every peer builds the same railway from the same data, so
every peer can work out where the train is from how far along it has got. Measured, both
clients place a moving locomotive within 0.0 m of the server without being sent a position.

### The railway is a list of WAYPOINTS, and one function poses everything on it

A waypoint is a place the rail passes through **and how far the track is rolled where it
does**. Both halves matter. A bare curve stores position and no twist, so there is nowhere
on it to say a corner is banked, and -- more to the point -- nothing that both the drawn
track and the train riding it can agree to read.

`rail_pose(track, distance, bogie_spacing, lift)` is the only way anything is placed on a
railway. The rails go through it, the sleepers go through it, the locomotive is driven
through it and the carriages are hung from it. Two calculations of the same pose disagree,
and disagreeing was exactly what the track and the trains were doing.

**Bank is one angle about the tangent**, keyed by distance and eased between waypoints --
never an orientation to interpolate. Two waypoints on a hard corner face nearly opposite
ways, and the short way round between two such orientations tips over the top;
`../../previous_projects/august-15-train` has a spur that came out leaning 40 degrees with no
roll authored anywhere, which is what that mistake looks like. `Terrain.rail_bank()` reads
the radius of the circle through each waypoint and its neighbours and returns
`atan(v^2/gR)`, so the bank is a property of the track and survives reshaping the loop. On
kilometre radii that is under a degree, and the machinery matters more than the number.

**Up is world up squared off against the direction of travel**, then rolled by the bank, and
never anything the interpolation hands back. A frame carried along a curve rolls over
through a tight bend and takes the train with it.

**Two bogie samples, never one.** A car rides on its bogies and hangs between them, so its
body spans the CHORD of a curve -- cutting the inside and overhanging the outside -- rather
than bending along the arc. Sample the middle and point along the tangent and you get a
train made of bananas. Measured: a 40 m wheelbase sits 0.023 m inside the arc.

### Three things that had every train facing north

**A mirrored basis is not a rotation.** The rail basis was built with `right = up x nose`,
which is the mirror of the right-handed one, so its determinant was -1. Read back through
`from_axes` -- whose trace formula assumes a rotation -- every one of them collapsed to the
identity, and every locomotive on the loop faced due north wherever it actually was. It is
`nose x up`. The smoke test now walks the whole loop rather than checking one place,
because at the one point where the track happens to run north it looked perfect.

**The waypoints are the railhead, not the middle of a train.** A body placed with its
centre on them is buried to the waist in its own embankment, with the cab floor a metre
underground and the driver looking at ballast. `ride_height` lifts it by half its own body,
along the TRACK's up so a banked corner leans it out rather than floating it vertically off.

**The closing segment was unreachable.** It runs from the final waypoint back to the first
and its length is in no table, so a binary search over the others cannot find it: a train in
the last forty metres of the loop was extrapolated off the end of the segment before. It is
handled first now, before the search.

**A train is not a free body**, so it has its own simulation job and never reaches the
flight models. `read_from_physics` skips it too: its pose came off the railway a moment ago,
and reading it back out of Box3D would replace it with wherever gravity had dropped the
collision hull. The hull is still moved with it, so an aeroplane can hit a train.

It is an ordinary vehicle in every other respect -- four seats, a crew, a command bus -- so
the take-the-next-craft button walks into the cab like anything else and a player can simply
drive it. Full regulator gives 25 m/s in ten seconds; full brake takes it back to a stand.

### The permanent way, and the five things wrong with the old one

`PermanentWay` (`world/permanent_way.gd`) owns every dimension of the track -- the 136RE rail, standard
gauge, the AREMA mainline tie at 19 1/2 in centres, the ballast and the bank -- and builds the three
meshes the level instances round the loop. **The railhead is y = 0 in its frame and the railhead is the
waypoint**, so everything else is measured DOWN from it, and `Boxcar` and the locomotive put their wheel
treads at `RAIL_CENTRES / 2` by asking it. `tests/track_drawn.gd` reads all of it back off the drawn
instances, at the sharpest bend, and ten mutants each turn one check red.

What it replaced (the user, 2026-09-19: *"the tracks also seem to be not aligned correctly"*), all five
of them green in every suite because nothing had ever read the drawn railway back:

1. **The rails were drawn in dashes.** Each piece was sized with `facing.scaled(...)`, and `Basis.scaled`
   is a GLOBAL scale, so a rail's 12 m went along the world's z whichever way the track ran: a rail
   heading east came out 0.12 m long. It is `scaled_local`. That is the third time this bug has been
   found here -- the towns' road marks and the runways were the first two.
2. **The wheels stood 16 cm down inside the rails**, which were drawn UP from the waypoints.
3. **The ties were 2.44 x 3.6 m slabs, one every 12 m.** A tie is 0.23 m wide and there is one every
   0.495 m; they are their own layer, drawn to 600 m, because past that one is under a pixel and there
   are 46,000 of them. Beyond it the ballast's own dark middle band carries the look of them.
4. **The railway floated 3 m over the grass** on nothing. The ballast and the bank now go down to the
   ground, and **the bank is LEVEL while the track on it leans**: a railway is superelevated by packing
   the ballast, not by tipping the embankment, and a bank tipped with the rails put its toes 13 cm in the
   air on one side at the sharpest bend's 1.1 degrees.
5. **The rails were 1.44 m apart between centres.** Standard gauge is 1.435 between the heads' INSIDE
   faces, so the centres are a head's width further apart, 1.510.

The track the trains ride is **the same loop sampled every 10 m** (`Terrain.RAIL_LAID_EVERY`), and a
length of rail is drawn from one waypoint to the next, so the drawn rail IS the chord the wheels ride
rather than a sample of the curve beside it. The 40 m `RAIL_STEP` survey stays exactly as it was, because
the scenery's corridor and the street lamps' clearance were laid round it. Each joint then turns 0.245
degrees at the tightest bend against about four times that at 40 m.

### The locomotive: an EMD SD40-2

`RoadDiesel` (`objects/vehicles/road_diesel.gd`) draws it and `train_shape()` collides it, each typing the published
figures separately so `tests/road_diesel.gd` and `tests/train_models.gd` can hold the two to each other: 20.98 x 3.127 x
4.753 m over couplers, grabirons and hood, 167 t, truck centres 43 ft 6 in, truck wheelbase 13 ft 7 in, 40 in wheels on
two three-axle HT-C trucks. It replaced an F7A built out of seven boxes, which was drawn to published figures with **no
drawing behind it at all** -- Commons has no orthographic reference for an EMD carbody unit, and the two references that
look most like roster broadsides are paintings.

**One photograph settles the layout, and it corrected the model twice.** NS 3275 is the only true broadside of an SD40-2
among the 964 files in Commons' category and its 85 sub-categories. Its walkway sill stripe fits over 1,757 columns at
3.5 px rms and runs 3,073 px end to end, which at a 19.90 m deck makes it 154.4 px a metre. Then:

- the walkway is **1.06 m** over the railhead, not the 1.37 first typed -- at 1.37 the long hood would stand 5.06 m up,
  taller than the type is published to be. It is built at 1.14, because a 40 in wheel's top is 1.016 m and the frame
  passes over it;
- **THE CAB ROOF SITS BELOW THE LONG HOOD** on an EMD Dash-2, and the published 15 ft 7 1/8 in is the HOOD's height. A
  cab built as the tallest thing on the locomotive reads as a switcher. The photograph's roofline runs flat at 4.70-4.79
  m and drops to 4.52-4.58 over the cab;
- **a published overall height is the top of EVERYTHING**: built with the roof at 4.753 the model came out 4.96 m tall,
  because the stacks and the brake blister stand on that roof.

**The photographed unit is a HIGH short hood**, the Southern and N&W variant. Everything aft of the cab front is shared
with a standard unit and comes from it; the low nose comes from three-quarter views as a proportion, and the running
gear could not be measured at all -- wheels, trucks, rails and shadow are one black at that exposure -- so the trucks are
the published figures. `craft/train/sources.md` says all of this, with the licences.

**The model draws with y = 0 at the RAILHEAD** and `VehicleView` hangs it half a box down, because that is where a wheel
stands and what the track publishes, while a craft's origin is the middle of its collision box.

**A train nobody is driving holds its speed.** `run_on_rails` applies a drawbar pull only when a seat is occupied and
the island spawns its trains empty, so the resistance took 22 m/s off one in about ten minutes and the island quietly
filled with stopped trains. An unmanned train now cancels its own resistance and nothing more: no target speed is
stored, because one would have to live where BOTH peers can read it -- `RailCar` is replicated, so a field on it is a
wire change, and a server-only figure would have the client decelerating and being corrected every tick. `train_runs`
drives it in a world of its own and holds it.

### The rake that jumped a tick at a time

**A locomotive is drawn between its two simulated poses and every boxcar was placed from the current
tick's distance**, so a rake stood still through a tick and jumped 0.183 m at its end -- 22 m/s at
120 Hz -- while the engine pulling it moved smoothly. Measured: **the coupling opened and closed by
182 mm, once a tick.** `Sim.rail_distance(entity, alpha)` is the answer, and it is `vehicle_transform`'s
job for the one thing in the game that is not posed from a vehicle state: the tick's distance carried
back by the train's own speed over the part of the tick not yet drawn. **No second captured state**: a
train's speed is constant across a tick, so the distance follows from it, and a lerp between two captured
distances would have to unwrap the lap as well. Afterwards the coupling moves **13 mm**, and the train's
per-frame step varies 6.6 per cent against an aeroplane's 6.3 in the same run, which is the frame clock
and not the drawing (`tests/train_shot.gd -- --jitter=300`; the user, 2026-09-19: *"train position is not
100% critical but smoothness is"*).


**No tight turns is a curvature calculation**, not a matter of taste. The loop's radius
wanders by two gentle harmonics only, and the smoke test measures the circle through every
three consecutive points: the sharpest bend anywhere on 22 km of railway is 2588 m across.
A third harmonic would make it a slalom that a fifty-metre train cannot take.

The line gets a **corridor in the terrain generator's clearances**, exactly as the gates and
the spawns do. Laid at its first radius it ran straight through the ring of mountains, which
is a tunnel, and there are no tunnels here.

### The brake that pushed the train backwards

Resistance was clamped only when the speed CHANGED SIGN, which looks equivalent to the
clamp everything else in the file uses and is not: at exactly zero there is no sign to
change, so a held brake found nothing to oppose and pushed the train gently out of the
platform at 0.064 m/s. Slow enough to miss, wrong enough to matter. The brake, the rolling
resistance and the drag now go through one clamp together, capped at what would bring it to
exactly zero this step.

## THE SURFACES ARE PROCEDURAL, AND THAT IS A BUDGET

Rock, grass and ocean are shaders in `world/shaders/`, with **no textures anywhere**. A
headset is fill-rate bound long before it is ALU bound, every one of these surfaces covers a
large part of the screen, and a handful of multiply-adds is cheaper than a fetch while
costing no memory and no bandwidth at all.

**ONE EXCEPTION: THE SEA'S TWO RIPPLE MAPS (team-lead, 2026-09-15).** Seven octaves of noise worked out per pixel for the
sea's ripples cost a headset's two eyes up to +1.09 ms against a +0.3 ms budget: a handful of multiply-adds times seven
octaves is not a handful. So `WindSea.ripple_maps` makes two normal maps when a sea is first built -- seamless fractal
noise (`FastNoiseLite.get_seamless_image`), turned into a normal map and mipmapped -- and the sea reads them. Nothing is
imported; nothing ships but the code that makes them. See "THE SEA'S SURFACE, PAINTED FROM THE WEATHER".

Three things make them affordable:

**The scenery is axis-aligned boxes**, so the rock shader can CHOOSE its projection from the
face normal instead of blending three. Triplanar's cost without triplanar's cost.

**Everything fine fades out with range.** This is not a quality setting. Detail smaller than
a pixel does not average out, it sparkles, and a sparkling ocean filling half of both eyes
is genuinely unpleasant. Each scale of noise has a distance at which it stops being drawn.

**Every high-frequency lookup wraps the world position first.** The world is 14 km across
and shader floats are 32-bit: a coordinate of 7000 at frequency 5 is an argument of 35000,
where a float has about a centimetre of resolution and fine detail turns into stair-steps.
The wrap repeats every few hundred metres and is invisible under the low-frequency variation
on top of it.

**The sea's only height is the simulation's.** Both ocean shaders lift SeaSwell's eye-following sheet by the standing
swell every hull floats on (see "A wrap is seamless only if the swell is periodic in it"), and FINE adds its small
travelling chop. Everything else that makes it read as a sea -- a wind-sea of four sines, six octaves of noise ripples
under them, whitecaps and light through the crests -- is a normal, a roughness and a colour, painted from the ships'
weather and band-limited by the pixel (see "THE SEA'S SURFACE, PAINTED FROM THE WEATHER"). Both are opaque: no
transparency, no refraction, no screen or depth texture, which are the expensive things in a water shader, and
`tests/lint.gd` lets no shader but the spatial mist read the depth texture.

## THE SCENERY HAS TWO FINISHES

**MEASURED ON A DESKTOP, NOT IN A HEADSET.** Every number in this section is from
`tests/scenery_shot.gd` on 2026-09-12: stock Godot 4.7.2, d3d12, an RTX 5080, ONE view in a
1600x900 window at 3D scale 1.40. A headset draws two views, foveated, on its own GPU, and nothing
here has been timed in one -- which is why a headset starts PLAIN. The suites (`scenery`, `clipboard`,
`lint`, `smoke`, `docs`, `air`, `builder`, `feel`) passed on it, and every fine shader has compiled
and rendered with no shader error. The renderer then was Mobile; every view was drawn again on Forward+
on 2026-09-14 (see "Forward+ since 2026-09-14", below).

PLAIN and FINE. `Finish` (the autoload; the class is `SceneryFinish`) holds which, and nothing
else does. It is changed by four things only: the backslash key on a desk (a row in
`PilotRig.DESK_KEYS`, so it is on the HELP page), the FINE SCENERY switch beside LABELS on the
clipboard (the one a headset can reach), the same key in the watch camera, and
`--finish=plain|fine`. Every surface with two finishes listens to `changed` and swaps its own
material, mesh or node; `FlightLevel.finish_worn` reads back what each surface is ACTUALLY
drawn with, and it is what the tests ask -- never the tier.

**PLAIN IS THE GAME AS IT WAS, less one thing.** `grass` and `ocean.gdshader` and the
cone-and-sphere fires are untouched; FINE is a separate shader file
beside each, sharing the noise include. A `uniform bool fine` would have been one file and a
branch on every pixel of both tiers, and the plain tier would have got slower for having a fine
one. The exceptions are the new lights, which PLAIN draws as steady opaque dots, and the clouds, which
PLAIN has lit by the time of day since 2026-09-13 (see "A cloud has one base, a shape of its own, and the sky's
light", below), and the rock, which both finishes light as the mountainside it is part of since 2026-09-14 (see "A
mountain is lit as a mountainside, and is still the boxes you hit", below).

**A HEADSET STARTS PLAIN, AND FINE HAS NEVER BEEN TIMED IN ONE.** There is no headset on the
machine this was written on. `Finish.suit_the_display` moves an unchosen tier to
`HEADSET_DEFAULT` when the rig enters VR and back when it leaves; a tier somebody chose is never
overruled. That hook has no test: it runs in `PilotRig.enter_vr`, which needs a runtime.

### Multisampling is part of the finish, and for months there was none

`project.godot` said `rendering/anti_aliasing/quality/msaa_3d=2` under `[rendering]`, and a key
inside a section is read with the section's name in front of it -- so Godot read
`rendering/rendering/anti_aliasing/...`, which is not a setting, and ignored it. The viewport
reported `msaa_3d 0` on both engines on 2026-09-12, and nothing in the game set it in code. The
"four times multisampling" in "SHARPER IN THE HEADSET" below was never on.

The key is `anti_aliasing/quality/msaa_3d=0` now, which is PLAIN and what the game really ran
with. `Finish` sets the ROOT viewport -- the one `PilotRig` turns stereo on, and so the one the
headset renders through -- to off on PLAIN and 4x on FINE, at start and on every change, before
`changed` is emitted. The viewport GPU timer reads it at 0.03 to 0.11 ms a view on the desktop (the
table below says what that timer can and cannot tell you); its cost in a headset is unmeasured.

### What each finish draws

| | PLAIN | FINE |
|---|---|---|
| lights (`VehicleLights`, `world/shaders/beacon.gdshaderinc`) | steady opaque dots holding about 0.05 degree, dimming with distance | the same opaque dot in the same colour a third larger, strobes flashing, and a blended halo pass round it (`next_pass`) that never covers the dot |
| runway (`Terrain.runway_lights`) | edge, threshold, approach and PAPI lights, steady | the same, with the approach strobes running |
| clouds (`PuffSky`, since 2026-09-17) | transparent ellipsoids integrated exactly, one octave of world noise | the same puffs, three octaves and a finer one; LiftYard's lumps below are `--clouds=lumps` now |
| clouds (`LiftYard`, `--clouds=lumps`) | twenty-four spheres a cloud, laid out by its own thermal as one of five kinds (`CloudTuning.TYPES`), cut level at the cloud's one base, lit per vertex from the time of day, and a hashed soft rim (`world/shaders/cumulus_plain.gdshader`) | the same lumps displaced by noise, lit per pixel by the same include, a lining against the sun, and a wide dithered rim that frays in clumps; near the eye, fog (`CloudBank`) |
| sea (`SeaSwell`, `WindSea`) | the eye-following sheet lifted by the simulated swell; a wind-sea of four sines and six octaves of noise ripples painted as a normal, band-limited by the pixel into roughness; whitecaps as the weather says; light through the crests | the same on four Gerstner waves near the eye, their normal worked out per pixel; cat's paws in two octaves; wind streaks past Beaufort 7 |
| grass | three scales of colour | + gusts rolling downwind, lit hummocks, and blades within 36 m (`GrassBlades`) |
| mountains | faceted ranges, one tone a facet, strata, scrub, scree, gully shade, rims and creeks, snow by slope, the grass at the foot, their own haze thinner with height and a far blue (`world/shaders/mountain.gdshaderinc`; see "A mountain is a range of triangles") | + fine grain near the eye, creeks that meander |
| rock | only what is still a box: no box carries a peak since 2026-09-18, so its stepped-slope light lights nothing (`world/shaders/rock_slope.gdshaderinc`) | + edges lit as bevels, stains down each wall |
| fire (`FireYard`) | cones and blended spheres | noise flames on upright quads, rising blended lit puffs with a grain on the puff, embers |
| multisampling | off | 4x |

### Forward+ since 2026-09-14

Asked for on 2026-09-14: "convert to the forward+ renderer so we can implement these new features" -- clouds in
FogVolumes, which Mobile does not draw (Godot's renderer comparison: volumetric fog "Not supported" on Mobile), and map
streaming. `project.godot` says `forward_plus` and its feature tag `Forward Plus`, and nothing else changed: no shader, no
material, no environment. `--rendering-method mobile` on the command line still runs the old renderer from the same tree
(the start-up line reads "Forward Mobile" rather than "Forward+"), which is how both columns below were drawn.

**What Godot says against it.** The same comparison page rates XR on Forward+ "Supported, but poorly optimized. Use Mobile
or Compatibility instead." The game is played as PC VR through Virtual Desktop on the RTX 5080 all of this was measured
on, and NOTHING HERE HAS BEEN TIMED IN A HEADSET, on either renderer.

**What it looks like: the same picture.** `tests/scenery_shot.gd --still --time=day,evening,night`, the sixteen views (the
eleven and `--views=scenery`'s five) on both finishes, Mobile against Forward+: 96 pairs, looked at side by side and
compared pixel by pixel. No shader error on either renderer, and nothing missing or broken on any view -- clouds, smoke,
fires, lights, sea, woods, towns and lit windows are all as they were. At evening and night at most 0.05 % of pixels
differ by more than 8 of 255 in any channel, except the evening grass, runway and coast views (0.5 to 13 %). By day
Forward+ is a shade lighter and bluer everywhere: mean luminance +1.0 to +2.7 of 255, blue +2.1 to +4.7, and 5 to 24 % of
pixels past that step, most on `grass`. The one difference an eye finds is at night, and it is better: Mobile's ground and
sea show dark contour blotches, round the sea's reflected light and across the grass, where Forward+ is smooth. That fits
the colour buffers the comparison page gives, RGB10A2 on Mobile and RGBA16F on Forward+; the cause was not proved further.
Pictures: `godotgames-drafts/2026-09-14/cockpit-forward/` (`mobile/`, `forward/`, `diff/`, and `sheets/`, one per view).

**The night floors did not move.** The same run's `_hold_the_night` readings, Mobile then Forward+, PLAIN: ground 0.0542 /
0.0562, mountains 0.0649 / 0.0665, forest (`forest_low`) 0.0208 / 0.0235, towns (`town_approach`) 0.2185 / 0.2194; FINE
within 0.005 of the same. Every reading is a little higher on Forward+, by day 1 to 4 %, and every floor and every red-light
gate passed on both. No threshold changed.

**What it costs the GPU timer: up to 0.22 ms a view more, on the desktop.** Interleaved A B A B, A Mobile and B Forward+,
`--hold-fires`, the sixteen views, 240 frames after 60 to settle, vsync off, 3D scale 1.40, ONE view, WITH OTHER LANES'
SUITES AND RENDERS RUNNING, so only B minus A is read. GPU timer medians, ms, A the mean of its two launches:

| view | PLAIN A | PLAIN B-A | FINE A | FINE B-A |
|---|---|---|---|---|
| runway | 0.228 | +0.092 | 0.465 | +0.142 |
| runway_base | 0.241 | +0.095 | 0.485 | +0.122 |
| traffic | 0.234 | +0.089 | 0.472 | +0.105 |
| traffic_near | 0.255 | +0.044 | 0.502 | -0.024 |
| clouds | 0.205 | +0.076 | 0.373 | +0.105 |
| coast | 0.120 | +0.056 | 0.265 | +0.155 |
| sea | 0.119 | +0.058 | 0.204 | +0.199 |
| grass | 0.253 | +0.073 | 0.428 | +0.117 |
| fields | 0.253 | +0.117 | 0.543 | +0.146 |
| mountains | 0.228 | +0.066 | 0.406 | +0.033 |
| fire | 0.254 | +0.132 | 0.573 | +0.204 |
| forest_low | 0.247 | +0.107 | 0.601 | +0.116 |
| forest_high | 0.247 | +0.136 | 0.573 | +0.220 |
| town_approach | 0.240 | +0.116 | 0.523 | +0.174 |
| town_street | 0.258 | +0.039 | 0.491 | +0.001 |
| town_night_lights | 0.232 | +0.078 | 0.522 | +0.161 |

A's own spread between its two launches was 0.000 to 0.012 ms, so every difference but `traffic_near` and `town_street`
on FINE is the renderer. The largest share is FINE's sea, which doubled (0.204 to 0.403). The CPU timer rose 0.03 to 0.26
ms on most views, against A spreads of up to 0.12 on the quiet views and 0.76 on the noisy ones; the wall clock moved -3.9
to +1.7 ms and is the load, not the renderer. PLAIN's draw calls are identical on both; FINE's differ by -27 to +21 (most on
the sea and coast views), not looked into.

**What is now possible, and not built:** volumetric fog and FogVolumes, TAA and FSR2, SSAO, SSR and SSIL, and omni and spot
lights by the cluster rather than eight a mesh -- each "Supported" on Forward+ and not, or capped, on Mobile by the comparison
page -- and the engine's visibility-range fade modes (`GeometryInstance3D`). No rule below was loosened by the switch; each
that rested on Mobile says so where it stands, and so do the comments in the code that gave the mobile renderer as a
reason (`VehicleLights`, `Burst`, `FireYard`, `BurstTuning.LIGHTS_AT_ONCE`, the beacon, smoke and ocean shaders,
`Woodland`, and `PilotRig`'s foveation note, which keeps the two sets that act only on Compatibility and says so).

### Back to Mobile on 2026-09-15, and the engine patch that made it possible

Asked for on 2026-09-15: "let's move back to the mobile renderer, disable all volumetrics and turn clouds back into
solid objects, if we can preserve the fact that the user can't see out of them when inside that would be great. My goal
is to remove features that the mobile renderer doesn't support and get back some of the lost framerate." And, while it
was being done: "do what you can to preserve the code, if you can simply disable those features that would be best."

**THE MOBILE RENDERER COULD NOT COMPILE A SHADER ON THIS ENGINE, AND IT WAS GODOT'S BUG, NOT OURS.** The section above
records that `--rendering-method mobile` on the double editor failed 594 vertex shaders on 2026-09-14 and says no more.
It is two characters. `scene_forward_mobile.glsl` declares `void vertex_shader(..., in vec3 model_precision, in vec3
view_precision, ...)` under `USE_DOUBLE_PRECISION` and then calls it with `scene_data_block.data.inv_view_precision`,
which `scene_data_inc.glsl` declares a **vec4**; the Forward+ shader writes `.xyz` at the same place
(`scene_forward_clustered.glsl`, `vec3 view_precision = scene_data.inv_view_precision.xyz`). GLSL reports it as
`'vertex_shader' : no matching overloaded function found`, every vertex shader in the renderer fails, and nothing draws.
It bites ONLY on a `precision=double` build, which is why stock Godot has never met it and why the game ran Mobile
happily until the day it went double.

**The fix is tracked, and the build applies it.** `_tools/src/` is gitignored, so an engine edited by hand exists on one
machine and nowhere else -- and a clean checkout would rebuild the engine WITHOUT it and get a renderer that draws
nothing, silently. So it lives in `tools/godot-patches/0001-forward-mobile-double-precision.patch`, and both
`tools/build_godot_double.ps1` and `.sh` apply every patch in that folder before scons, checked reversed first so a
rebuild is idempotent, and FATAL if one neither applies nor is already in. Rebuilt in 4 min 38 s on the workstation;
`extension_api.json` came out identical to the tracked copy, so nothing about the library binding moved. The binaries it
replaced are in `_tools/godot-4.7.2-double/pre-mobile-fix-2026-09-15/`.

**What it costs the GPU timer: Mobile is 0.07 to 0.13 ms a view CHEAPER**, which is the 2026-09-14 table read backwards
and agrees with it. Stock paths, d3d12, RTX 5080, 1600x900 at 3D scale 1.40, `tests/scenery_shot.gd --level=watch`, 120
frames after the settle, two launches each interleaved A B A B. GPU timer medians, ms, each renderer the mean of its two
launches; each launch's own spread from its twin was 0.000 to 0.010:

| view | finish | Mobile | Forward+ | Mobile - Forward+ |
|---|---|---|---|---|
| clouds | PLAIN | 0.267 | 0.365 | -0.097 |
| clouds | FINE | 0.565 | 0.694 | -0.129 |
| runway | PLAIN | 0.522 | 0.642 | -0.119 |
| runway | FINE | 0.834 | 0.906 | -0.072 |
| cloud_inside | PLAIN | 0.249 | 0.327 | -0.078 |
| cloud_inside | FINE | 0.589 | 0.714 | -0.125 |

(`cloud_inside` is one launch each.) The wall clock moved -0.2 to +0.2 ms, which is nothing. **NOTHING HERE IS A HEADSET
FIGURE**, on either renderer, and the reason to want Mobile is Godot's own comparison page rating XR on Forward+
"Supported, but poorly optimized. Use Mobile or Compatibility instead." That remains unmeasured here.

**Every one of the sixteen views still draws.** Pictures both ways in
`godotgames-drafts/2026-09-15/cockpit-mobile/` (`mobile/`, `forward/`, and the second pair beside them).

**The volumetrics are off, and NOT ONE LINE OF THEM IS DELETED.** `CloudBank.asked_for` is the single predicate in
front of the whole FogVolume path: a level builds no bank, so `CloudBank._dress_the_air` never runs and the
environment's `volumetric_fog_enabled` is never switched on, on any renderer. `--clouds=fog` brings all of it back on a
Forward+ run, so every measurement in "A cloud you can fly into" can be taken again. The default is off on EVERY
renderer rather than falling out of `can_draw()`, so what a run draws does not depend on which renderer it started with.
`CloudBank.also_wanted` is how a suite asks, since a test cannot put a word on the command line of the process running
it -- the seam `DeskRoom.starts_steam` and `Net.draw_code` already are.

**And you still cannot see out of a cloud, because that was never the fog's job.** `LiftYard.eye_in_cloud` ->
`FlightLevel._on_eye_in_cloud` -> `Daylight.show_in_cloud` drives the DEPTH fog to `CloudTuning.WHITEOUT_DENSITY` in the
cloud's own colour, which is what PLAIN has done since the fog was written and what any renderer without volumetric fog
already got. With no bank on either finish, FINE gets it too -- `fog_does_it` is false because `clouds` is null.
`tests/air.gd` holds it on BOTH finishes now
(`_a_level_with_no_fog_asked_for_builds_none_and_whites_out_on_both_finishes`): the level builds no bank, the froxels
are off, the lumps are told a fog share of nothing and are drawn whole, and the eye at the core of the first zone's
cloud reads depth >= 0.9 with the depth fog past 0.05 in the cloud's colour. The section above it, which is about what
the fog does when it IS there, now asks for it with `CloudBank.also_wanted`.

**What a FINE player loses:** the crossfade from mesh to fog near a cloud, and the fog's own inside. What they keep: the
mesh cloud whole at every distance, and the whiteout. Pictures of the inside on both renderers and both finishes are in
the drafts folder above; PLAIN and FINE now look alike from in there, as they did on PLAIN before.

### The Mobile/PCVR best-practice brief, checked line by line against this game (2026-09-15)

A "Godot 4 Mobile Renderer -- PCVR High-FPS" brief was handed over on 2026-09-15 to be reviewed rather than applied.
Most of it this game already does, and it says so below with where. **Three things it recommends are worth having, one
of them is already in, and two of its recommendations are WRONG FOR THIS MACHINE and the measurement is here.**

**Already true, and where.** One shadowed `DirectionalLight3D` with `directional_shadow_max_distance` 400 m
(`world/sky.tscn`); no glow, no `hdr_2d`, no SSAO/SSR/SSIL/SDFGI/VoxelGI anywhere; `Viewport.vrs_mode = VRS_XR` on the
viewport the headset renders through (`PilotRig._apply_display_mode`, with the note on why `foveation_level` is kept and
does nothing); vsync disabled while XR is up and restored after (`PilotRig`); `Engine.physics_ticks_per_second` set to
the simulation's 120 Hz (`Sim`); per-mesh light budget respected deliberately for Mobile (`BurstTuning.LIGHTS_AT_ONCE`
is 2, and `VehicleLights`, `Burst` and `FireYard` each name the mobile renderer as the reason); no screen texture, no
depth texture and no FRAGCOORD on world materials (a house rule with its own section, older than the brief); and
volumetric fog off (this session).

**The one number the brief is right about and this game hard-coded: the render scale.** `PilotRig.RENDER_SCALE` is
**1.4**, which is TWICE the pixels of 1.0 -- larger than the renderer, the volumetrics and the finish put together --
and until 2026-09-15 it could be changed only by editing that file. The brief's escalation order is
"lower `render_target_size_multiplier`, shadow distance, MSAA, particle count -- in that order", and the first of those
was unreachable. It is now `--render-scale=` after the bare `--`, 0.5 to 2.0, **default unchanged at 1.4** so every
picture and frame time already written down stays true. Outside the range is REFUSED with a warning and the default
used, not clamped, and the start-up line says which it used and whether it was asked for. It cannot be a switch on the
clipboard: it sizes the swapchain, which is made once when the interface initialises. `tests/smoke.gd`
(`_test_the_render_scale_knob`) holds seven cases including the three refusals.

**WRONG FOR THIS MACHINE: "prefer Vulkan over D3D12 on Windows."** Measured the same day, same binary, Mobile both
ways, `tests/scenery_shot.gd --level=watch`, 120 frames after the settle, GPU timer medians in ms:

| view | finish | D3D12 | Vulkan | Vulkan - D3D12 |
|---|---|---|---|---|
| clouds | PLAIN | 0.267 | 0.353 | +0.086 |
| clouds | FINE | 0.565 | 0.632 | +0.067 |
| runway | PLAIN | 0.522 | 0.542 | +0.020 |
| runway | FINE | 0.834 | 0.842 | +0.008 |

and the wall clock was +0.6 ms on every view. So Vulkan costs here and `rendering_device/driver.windows="d3d12"` stays.
**The brief's reason for Vulkan is not speed, though -- it is a right-eye-black XR bug on Mobile + D3D12, which this
machine cannot test, having no headset.** If the right eye is ever black in the headset, that line is the first thing to
change, and it costs the table above. Nothing else in the game depends on the driver.

**A CLI trap found while measuring it:** `--rendering-driver vulkan` ALONE starts Forward+, ignoring
`renderer/rendering_method` in `project.godot`. `--rendering-driver vulkan --rendering-method mobile` is what actually
runs Vulkan on Mobile. A measurement taken with the first form is a measurement of the wrong renderer, and the start-up
banner is the only thing that says so -- read it.

**Still open, and honestly untested:**
- **PSSM splits.** The brief says Mobile supports 2 and this project sets none, so the light is on Godot's default of 4.
  Whether the Mobile renderer silently uses 2 anyway was NOT determined; it is a `directional_shadow_mode` away and
  wants an A/B on the runway and town views before anybody believes it.
- **`thread_model = Separate`.** Not set, so the game is on Godot's default. The brief recommends it for OpenXR + Vulkan
  and says to treat it as "test and keep if stable". Untested here; it is a project setting and a full suite run.
- **MSAA.** PLAIN has none and a headset starts PLAIN (`Finish.HEADSET_DEFAULT`), so the brief's "start at 2x" costs a
  headset nothing as things stand. FINE's 4x has never been timed in a headset, which is the note `Finish` already
  carries.

**Does not apply, and why.** LightmapGI and baked ambient: this world is generated and streamed by the kilometre
(`WorldMap`, `SceneryYard`), so there is nothing to bake and no bake would survive the next seed. Occluder baking: an
open-air flight sim over an island has almost nothing that occludes anything, and the towns are already drawn by
distance. Impostor LODs for trees: `Woodland` already draws the far woods as a picture. "Combine static meshes so fewer
lights reach them": the per-mesh light cap is already the reason the burst lights are capped at 2.

### Rules these follow, each for a reason

- **No screen texture, no depth texture, no FRAGCOORD.** The first two were ruled out on the Mobile
  renderer, which pays for them with a pass. The game is Forward+ since 2026-09-14; Godot's renderer
  comparison lists both textures as supported on Mobile and Forward+ alike and says nothing of their
  cost, so what reading one costs here is UNMEASURED, not free. The first shader that reads one is timed
  with `tests/scenery_shot.gd` against the same view without it, A B A B, before it lands. The third
  stands on any renderer: FRAGCOORD is a pattern on the panel, which lands on different pixels in each
  eye and crawls with the head.
- **The dither is on the object.** Cloud edges discard where a hash of the fragment's cell in the
  OBJECT's own frame exceeds the coverage, with the cell sized from the distance to the midpoint of
  the eyes; smoke is blended, and its grain is keyed to the puff the same way. The engine's alpha hash was rejected: its
  input is object space but its cells are sized by screen derivatives, which is a per-eye
  pattern again (read from `scene_forward_mobile.glsl`).
- **Anything turned to face the viewer faces `CAMERA_POSITION_WORLD`**, the midpoint of the
  eyes, so a flame is one quad in both eyes rather than two.
- **Nothing that moves a boat.** The waves are pictures; buoyancy is against a flat SEA_LEVEL on
  every peer, and a wave that lifted a hull on one machine is a desync.
- **Nothing that moves a mountain.** Its triangles are also the collision ("A mountain is a range of triangles"): the shader
  colours and lights them and never moves a vertex.

### What it costs, and what it looks like

**The probe and its clocks.** `tests/scenery_shot.gd` renders from fixed viewpoints computed from
`Terrain`, 240 frames after 60 to settle, vsync off, and reads three clocks: the viewport's GPU and
CPU timers (`RenderingServer.viewport_get_measured_render_time_*`, medians) and the wall clock
between frames. Since Stage 1 it also cuts every timed frame into physics scripts, process scripts,
its own camera work, the renderer (`frame_pre_draw` to `frame_post_draw`, presenting included) and
the remainder, from its own clock stamps, with `world/stopwatch.gd` naming blocks inside the
scripts; every frame goes to a CSV beside its picture. Flags: `--paused-sim`, `--stopwatch=off`,
`--pose-every-frame`, `--hold-fires`, `--still`, `--parade`. `before` is cockpit at 7c24c50, the
parent of the commit that added the finishes -- its `project.godot` has the multisampling key at
line 37 inside `[rendering]` (line 32), where Godot ignores it, so `before` really is multisampling
off. PLAIN is off too; FINE is 4x. Desktop RTX 5080, d3d12, ONE view, 1600x900 at 3D scale 1.40 --
**not a headset.**

| view | GPU timer: before / PLAIN / FINE / FINE no MSAA (ms) | wall clock per frame: before / PLAIN / FINE (ms) |
|---|---|---|
| runway (short final) | 0.241 / 0.230 / 0.502 / 0.392 | 4.49 / 4.70 / 4.49 |
| runway_base | 0.246 / 0.242 / 0.498 / 0.411 | 4.85 / 5.04 / 4.72 |
| traffic | 0.245 / 0.243 / 0.485 / 0.392 | 4.86 / 5.04 / 4.80 |
| traffic_near | 0.231 / 0.227 / 0.457 / 0.396 | 4.86 / 4.99 / 4.79 |
| clouds | 0.236 / 0.210 / 0.374 / 0.312 | 5.17 / 5.34 / 5.19 |
| coast | 0.120 / 0.119 / 0.270 / 0.211 | 5.05 / 5.30 / 4.97 |
| sea | 0.124 / 0.124 / 0.212 / 0.180 | 5.41 / 5.45 / 5.06 |
| grass | 0.264 / 0.260 / 0.443 / 0.381 (no blades 0.398) | 5.89 / 6.15 / 5.37 |
| fields | 0.272 / 0.272 / 0.550 / 0.460 (no blades 0.518) | 6.21 / 6.30 / 5.34 |
| mountains | 0.259 / 0.258 / 0.483 / 0.422 | the probe's own cost, not the game's -- see below |
| fire | 0.249 / 0.247 / 0.495 / 0.415 | 6.11 / 6.57 / 5.38 |

**By the GPU timer PLAIN costs what the game cost** (-11 % to 0 % against `before`) and **FINE reads
+0.09 to +0.28 ms**, of which 4x multisampling is 0.03 to 0.11 ms and the grass blades 0.03 to 0.05.
The `fine-nomsaa` and `fine-bare` columns exist so multisampling and the blades can each be dropped
on their own if they are what costs.

**THE GPU TIMER IS NOT FRAME COST ON THIS DESKTOP, and the frame is bound by main-thread work that
neither viewport timer sees** (a hypothesis when written, confirmed in Stage 1). The wall clock is
4.2 to 6.6 ms on every view and does not rise on FINE -- often it falls. Both viewport timers
together account for only 1.2 to 1.6 ms of it. Re-run GPU-bound at 3840x2141 at 2.00 (about twelve
times the pixels; 2.00 is as far as the engine lets the scale go, and it clamps silently) the two
still disagree: the GPU timer reads FINE +0.58 to +2.12 ms over PLAIN and the wall clock reads it
0.13 to 0.32 ms *faster*, while the wall clock sits at 4.1 to 5.3 ms whatever the scale. The GPU
timer scales like fill-rate work (6 to 7 times the milliseconds for twelve times the pixels), which
makes it plausible but does not make it frame cost. Refresh pacing was tested and rejected: the
4.2 ms floor looked like 1/240 s, but the monitor runs at 60 Hz (`Win32_VideoController`). The cause
is that the simulation runs at 120 Hz, so under `--fixed-fps 60` every drawn frame carries two ticks
of 73 vehicles, and the level, the lift wisps and the fire yard run every frame too; GPU work runs
alongside and does not lengthen the frame until it outgrows it -- 3.6 ms still fits inside a 4.5 ms
frame. **The CPU timer reads lower on FINE than on PLAIN on every view** (fields 1.385 against
1.006 ms), written down as measured, not explained. **Nothing here says what FINE costs a frame on a
fill-rate-bound headset, which is why a headset starts PLAIN.**

**Traps the timing work found, each of which voids numbers taken without it:**

- **The probe can be the cost.** The mountains view's 17 to 19 ms was `Terrain.boxes()`, which the
  probe called to find the tallest rock and which builds every box on the island, on every frame. It
  was written here as a game cost with three candidates and was none of them. Asking the pose every
  frame is 16.25 ms against 5.71 ms asking once, 11.04 ms of the difference the probe's own time;
  asked once, mountains is 1.00 times the other views' median. `--pose-every-frame` puts the old
  behaviour back.
- **The fire front spreads through a run, and PLAIN's frame grows with it.** Views are timed in table
  order; in one PLAIN run the fire yard's script went 0.27 ms (first view) to 0.62 ms (ninth) and the
  renderer 1.89 to 3.07 ms, rising with it (r = 0.86; 2.55 ms of renderer per ms of fire script),
  against FINE's r = 0.28. With the simulation paused the front holds and PLAIN's renderer stays at
  1.16 to 1.53 ms. `before` grows like PLAIN. **So every live per-view number above depends on where
  its view fell in the run**, the wall-clock column and FINE's faster wall clock included. Time with
  `--hold-fires`.
- **Two launches of one build do not draw the same picture.** PLAIN against PLAIN: runway 0 pixels,
  every other view 35 thousand to 980 thousand of 1.44 million, because the traffic and the fires are
  never in the same state twice. A picture gate needs a world held still.
- **A whole launch can run a few tenths of a millisecond slow, on every view and in every part of the
  frame at once.** Four PLAIN launches of one build had all-view means from 4.26 to 4.68 ms; a
  reversed-order launch averaged +0.13 ms PLAIN and +0.20 FINE over the views, spread over the
  renderer, physics scripts, process scripts and the rest, with the GPU at -0.01. **Two launches that
  happen to agree set a threshold on the noise floor that a third launch breaks** -- which is what made
  Stage 2 reject a change that was real (below).
- **`TIME_PROCESS` and `TIME_PHYSICS_PROCESS` are not per-frame numbers.** Over 240 frames each took
  three values (process 10.3, 13.2 and 275.1 ms against a 6.38 ms wall-clock median): they hold a
  value for about a second. Read the probe's own stamps instead.

**THE TIMING RULE (Stage 2c, and every A/B from there on): EIGHT LAUNCHES, ALTERNATED A B A B A B A B**,
under a keep rule the lead sets before any number it judges. For each view and finish the noise is the
range of the four A launches' medians: `T_med = max(0.10 ms, that range)`, `T_p95 = max(0.25 ms, the
range of their p95s)`. A view counts as changed only if the median of the four B medians differs by
more than `T_med` (or the p95s by more than `T_p95`), **and a finish counts as changed at all only if
the mean over its views of B - A is larger than the range of the four A launches' all-view means** --
otherwise it is noise there, whatever a single view says. Hold the fires, and check the machine is
idle at the start of every launch: a window in which a separate game used about ten cores is void,
and one has been (19:14 to 19:32 on 2026-09-12, every frame about three times as long).

**THE PICTURE RULE.** `--still` pauses the simulation, hides every vehicle, round, carriage and line
of text, draws the island's nine fires and holds the yards' clocks. Two `--still` launches of one
build: PLAIN 0 pixels on all 11 views; **FINE 19 to 258 pixels on nine views (0 on coast and sea),
every one on the fine clouds' stippled rims, by 1 to 5 levels of 255** -- an open finding, cause
unproven, but rounding in the blended rim or the 4x resolve varying from launch to launch would fit.
So a *count* of differing pixels cannot tell a FINE change from noise (runway: 53 pixels between two
launches of one build, 69 between two builds differing in a file that touches nothing in those
clouds), and a *magnitude* can. As used: **PLAIN 0 pixels; FINE judged against a per-pixel envelope
from three launches of the build before, and no pixel by more than 2 levels.** A change the still
picture cannot reach -- one that only reorders code behind hidden objects -- gates instead on PLAIN 0
pixels both ways plus run_all, chosen before the run and recorded.

**What the rules then settled:**

- **The simulation bounds this desktop's frame.** `--paused-sim` took 1.65 to 3.39 ms off the PLAIN
  wall-clock median on every view (fields 3.39, sea 3.00, fire 3.32), leaving 2.70 to 3.14 ms. A live
  PLAIN frame by means: physics scripts 1.23 to 1.31 ms (the simulation's laps 1.19 to 1.25), process
  scripts 1.40 to 1.85 (vehicles 0.72 to 0.78, fires 0.27 to 0.62, riders 0.25), renderer 1.89 to
  3.07, the rest 0.20 to 0.29. **The ashiato extension is not the main cost**: its five state calls
  are 0.24 to 0.27 ms, 4 to 5 per cent of a frame (0.97 to 1.01 ms with both ticks), and the largest
  part of the frame on no view.
- **What FINE costs with the simulation paused**, PLAIN to FINE, wall clock against GPU timer, median
  ms. GPU-bound: sea -0.308 / +0.585, fields +0.632 / +2.167, fire +0.518 / +1.992. At the headset's
  scale: sea -0.242 / +0.086, fields -0.123 / +0.262, fire -0.299 / +0.245. **GPU-bound the wall clock
  moves the GPU timer's way on fields and fire, about a quarter of what the GPU timer reads, so FINE
  does cost frame time when the GPU is what a frame waits on.** At the headset's scale FINE is no
  slower on this desktop. A headset is still unmeasured.
- **THE FIRE YARD CHANGE IS KEPT (6207771): about half a millisecond a PLAIN frame.** PLAIN's `_tint`
  now sets a flame's, puff's or glow's colour only when it differs, and the cull margin and shadow
  setting go once at build instead of to every mesh of every fire on every frame -- each of those
  three setters reaches the RenderingServer whether or not the value changed
  (`BaseMaterial3D::set_albedo`, `GeometryInstance3D::set_extra_cull_margin` and
  `set_cast_shadows_setting` in 4.7.2). Under the eight-launch rule: the four launches before had
  all-view means of 4.25 to 4.34 ms and the four after 3.72 to 3.85 -- every one after quicker than
  every one before -- a mean change of -0.515 ms over the views against a spread of 0.095. Ten of
  eleven views count faster by 0.45 to 0.57 ms (fire, -0.67, sat inside its own 1.23 ms of noise) and
  every p95 fell by 0.40 to 1.44 ms; PLAIN's renderer time over FINE's fell by 97 to 148 per cent of
  itself on every view. FINE: -0.054 against a spread of 0.074, noise, no view either way.
  **Stage 2 had REJECTED this same change on two launches a side**, because its thresholds sat inside
  launch-to-launch noise and its first three views looked slower for no reason the change had (tested
  separately: a cost paid at the start of a launch was measured not to exist). Eight alternated
  launches measured the noise and the change stood clear of it. That is why the rule is eight, not two.
- **The stopwatch's laps inside the simulation tick came out (511864a); the rest stay.** Priced twice
  before the rule existed and failed both times on noise -- first on the fire front, then on
  launch-to-launch spread (four of the six failing views had the stopwatch ON *faster*, and the
  physics scripts the laps live in were within 0.07 ms on against off, while the thresholds came from
  two launches as close as 0.003 ms, narrower than two off launches were from each other). Under the
  eight-launch rule the remaining laps are noise: PLAIN all-view means spread 0.102 ms, mean change
  with it off -0.034 ms, no view counts.
- **An untested hypothesis, parked: a 600-frame untimed warm-up may make launches less noisy.**
  Splitting each launch into a whole-launch offset and a per-view remainder, four launches without it
  had SDs of 0.196 and 0.193 ms (FINE 0.329 and 0.266) against 0.064 and 0.140 (FINE 0.107 and 0.095)
  for three with it -- about half. But that is three launches, on a different tree, against a group
  with one outlier (all-view mean 4.68 ms against about 4.30), so **the warm-up is not in the probe**:
  it did not pass its proof, and what it was added for was measured not to be there. The views that
  move six or more places between a normal and a reversed order differ by +0.08 PLAIN and +0.10 FINE
  on average; the three that move two or fewer, by +0.30 and +0.32, and coast is sixth in both and
  differs by +0.45 and +0.37 -- the opposite of a cost paid at the start. If the warm-up is ever
  wanted the test is a window of its own: one tree, four launches with against four without,
  alternated, comparing launch-offset SDs, under a rule decided before it runs.

**V1 (ec1d37e): where the vehicles lap goes.** The vehicles loop is three passes with a lap each --
every vehicle drawn, then every spotting box, then the reaping -- which draws the same frame, because
a box reads only its own vehicle's place and the eye. Four launches, fires held, both finishes:
drawing **0.697 ms a PLAIN frame** (0.700 FINE), spotting 0.021 (0.022), reaping 0.004 (0.004),
together 0.723 (0.726). That is not guaranteed to equal Stage 1's 0.72 to 0.78 ms for the whole loop
-- a split loop is a different loop, and Stage 1 ran with the front spreading where these held it.
**Nearly all of it is the drawing**: `VehicleView.draw` for 73 vehicles, which interpolates each pose
from two dictionaries and sets a transform that reaches every node under it.

**WHERE THE PERFORMANCE WORK STOPPED (2026-09-12), so the next session does not start from the
beginning.** The target is that 0.697 ms of drawing for 73 vehicles.

- **(d3), attribution inside `VehicleView.draw`, is prepared and has produced no number.** Three laps
  per kind -- reading the interpolated pose, writing the transform (which reaches every node under the
  view), and the rest (sound, turrets, nacelles) -- named once per craft in `setup`, with the probe
  printing the fleet's kinds so a lap can be read per craft. Its gate is run_all plus PLAIN held-still
  pictures at 0 pixels both ways (vehicles are hidden there, so FINE is recorded and does not gate),
  then four launches with the fires held, and an estimate of what the laps themselves cost at 73
  vehicles by comparing the outer drawing lap with V1's. A window was started and stopped before any
  timed launch; nothing from it counts. Both versions of its patch -- on the tree before `--parade`
  and on the tree after -- are kept outside the repository.
- **Waiting on (d3), each needing a keep rule set before its window:** (d1) reading a vehicle's state
  once per frame instead of per call; (d2) setting position and rotation instead of a composed
  transform. **Parked:** (c2) skipping `transform =` when a craft's pose has not changed -- it helps
  only craft that stand still, and nearly all 73 are moving traffic.
- **Closed, with their numbers:** the spotting boxes' early return (0.021 ms) and skipping the reaping
  (0.004 ms); neither reaches the 0.10 ms that earns a timing window.

**What the pictures say, effect by effect, with the before, PLAIN and FINE frames side by side:**

- **Grass: better.** PLAIN and `before` are flat colour; FINE's blades read as a field you are standing
  in. Three tries: black spikes (back faces lit by a flipped normal), then blades matched so closely to
  the ground that they vanished, then roots at half and straw tips.
- **Clouds: better.** Lumped cumulus instead of stacked ellipsoids. Close under the deck the frayed rim
  shows a little speckle, more with multisampling off.
- **Smoke: better.** Dense continuous columns where PLAIN's are strings of beads at the base. FINE's
  smoke is very dark. A stippled version read as a swarm of flies and was replaced.
- **Lights: better, and measured** -- see the gate below. PLAIN has them too; `before` had none.
- **Mountains: a modest gain.** More rock detail and relief; still stepped boxes.
- **Sea: NOT clearly better.** From 45 m the fine sea looks much like PLAIN's: no seam, but still two
  soft light streaks, more with multisampling off. What it adds (a shape near the eye) shows only close
  to the water, and no view here is close enough to show it. Its 0.06 to 0.15 ms buys little that can
  be seen from these viewpoints.
- **Runway, short final, 120 m out and 8 m up**: legible -- threshold, edge rows and approach bars --
  but the strip sits low near the horizon rather than filling the lower frame.

### How it was proved

`tests/scenery.gd` is a headless suite: the real key and the real switch, and every surface read back.
`tests/scenery_shot.gd` is the probe that renders (above). It ran on the STOCK engine while the double
build's own Forward Mobile vertex shader would not compile and Forward+ drew the runway lights wrong;
**both of those are fixed and it runs on the double editor now** (see "Back to Mobile on 2026-09-15"
for the engine patch, and the eye note for the lights).

### The lights are held to PLAIN by a number, not by eye

**Half the size and dimmer far away, on both finishes, because the user asked (2026-09-12).** Played in the
headset, the lights read as too big and as bright at five kilometres as at the next stand. `beacon.gdshaderinc`,
which PLAIN and FINE both include, now multiplies the dot's radius by `size_scale` (0.5) and its colour, core and
halo alike, by a brightness that eases from 1 at `dim_from` (300 m) to `far_bright` (0.35) at `dim_to` (5 km).
That deliberately gives up the old aim of "as easy to spot as they were"; it does NOT give up the gate below. What
the gate asks is still that FINE is no harder to find than PLAIN, and because both finishes are halved and dimmed
by the same lines of the same file, the gate compares like with like.

On the new size (2026-09-13, stock 4.7.2, d3d12, 1600x900 at 3D scale 1.40), two `--parade --no-spotting` launches,
110 red lights on screen in every view, both launches identical to the hundredth: red pixels a light PLAIN / FINE --
runway 0.65 / 1.04, runway base 2.64 / 3.23, traffic 2.71 / 2.85, traffic near 1.31 / 1.92; the reddest pixel
0.514 to 0.522 on both finishes. The gate holds on every view. A light is now under a pixel of pure red on PLAIN
at the runway view: that is what "half the size" costs, and it is what was asked for.

**Smaller again, dim by day and soft at the edge -- AIRCRAFT lights only -- because the user asked (2026-09-13):** "let's
make sure that the plane lights are less visible in day, and dithered a bit more, let's make them smaller again as
well." The goal changed a second time and the gate did not: FINE no harder to find than PLAIN, at DAY and at NIGHT.

- **Two materials, same shaders.** `VehicleLights.paint()` is every aircraft's and `runway_paint()` the runway's, so
  the runway keeps the size (0.5), brightness and edge it had; each is still one shader swap on a finish change. Every
  number either is drawn with is set on the material from `VehicleLights` or `DaylightTuning`, never left to a uniform
  default -- `tests/scenery.gd` reads them back, and RED, the size typed into the shader's default instead read back
  null.
- **Smaller:** an aircraft dot is 0.35 of its size, and keeps 0.42 of the least angle (`least_scale`, split from
  `size_scale` for this) so a light a few kilometres off is still a dot.
- **Dim by day:** `DaylightTuning`'s "aircraft_lights", 0.45 by day, 0.75 at evening, 1 at night, handed to
  `VehicleLights.show_daylight` by the level once per change, core and halo. RED, a call every frame: 120 writes in 60
  frames.
- **Soft edge:** the dot's outer band (0.2 of the radius on PLAIN, 0.35 on FINE) is thinned by a hash of the cell in
  the dot's own frame and the light's phase. No TIME and no FRAGCOORD, so it is the same in both eyes and still.
- **What the gate found.** With the FINE rim at 0.45 and the FINE core at 1.35, FINE fell short of PLAIN BY DAY on three
  views (`--parade --no-spotting --time=day`; PLAIN run twice, identical): runway base 0.56 against 0.67 red pixels a
  light, traffic 0.83 against 0.98, traffic near 0.46 against 0.52. At NIGHT FINE led on all four. A rim of 0.35 or 0.25
  fixed traffic and traffic near, and left runway base at 0.61 at both -- so the rest was the dot, not the rim: a smaller
  dot dimmed to 0.45 loses its edge pixels to FINE's multisampling, the fault 1.35 was measured in for at half size. The
  aircraft's FINE core is 1.5 now (`fine_core`, the halo scaled with it so it stays off the core); the runway's is 1.35.
  With that, the same launch: red pixels a light FINE / PLAIN by DAY -- runway 0.46 / 0.30, runway base 1.09 / 0.67,
  traffic 1.76 / 0.98, traffic near 0.82 / 0.52 -- and at NIGHT 2.30 / 1.34, 5.26 / 3.24, 4.93 / 3.05, 4.46 / 2.14; FINE's
  reddest pixel at or above PLAIN's on all eight. The gate holds at both times of day.

### An aircraft's lights by distance

**By day a far aircraft light fades and shrinks; at night it is as it was** -- asked for on 2026-09-13: "the lights on
planes are still too bright in the daytime, dim them at distance more." The brightness fade with distance was the same
at every time of day, and the least angle kept a far light a dot of fixed size whatever the light, which is what made a
far aeroplane by day a bright point. Now each preset in `DaylightTuning` says how far a light fades to
(`aircraft_dim_to`), how dim (`aircraft_far_bright`) and how much of its least angle it keeps (`aircraft_far_least`), all
eased over the one fade from `VehicleLights.DIM_FROM` (300 m), in the shader, from the camera's position -- the same in
both eyes, no TIME. `VehicleLights.show_daylight` takes all four numbers, every one given at the call, once per change.

| | DAY | EVENING | NIGHT |
|---|---|---|---|
| fades by | 2000 m | 3500 m | 5000 m |
| to brightness | 0.12 | 0.25 | 0.35 |
| keeping of its least angle | 0.7 | 0.85 | 1 |

NIGHT is the numbers the shader had before, and `tests/scenery.gd` holds it to them typed out, not only to the preset:
lights are how an aeroplane is found at night. The runway never fades by time of day. A light inside 300 m keeps its
size, so an aeroplane near enough to be seen as one looks as it did. RED: the three checks read null off both materials
before `VehicleLights` set them.

**The brightness takes a far light out of sight, not the size.** Swept by day at keeping 0.35, 0.7 and 1 of the least
angle: red pixels a light 2.6 km off fell from 0.98 PLAIN and 1.69 FINE to 0.00 at all three. What the size did was the
FINE finish's reddest pixel: a dot shrunk under a pixel is averaged into the sky by FINE's multisampling, 0.196 against
PLAIN's 0.259 at 0.35, 0.247 at 0.7 and 0.251 at 1. So 0.7. Read by range (`lights_by_range`, below), the lights of an
aeroplane 150 m off (`traffic_close`, 12 of them inside 300 m) were 0.25 PLAIN and 0.42 FINE by day before and at every
setting after.

**THE RUNWAY HAD BEEN WEARING THE AIRCRAFT'S LIGHTS.** The two-materials change above said the runway kept its size,
brightness and edge, and its checks passed -- on `runway_paint()`, a material nothing was drawn with: `VehicleLights.build`
took `on_aircraft` and gave every set of lights `paint()` anyway. So from fd842f5 the runway's lights were an aircraft's:
0.35 of the size, 0.45 bright by day, dithered. Found 2026-09-14 because a `--still` picture of the runway, every vehicle
hidden, changed by day when only the aircraft's fade did: 64 pixels at the far end, the red and green end lights gone
dark. `build` gives the runway `runway_paint()` now, and `the_runway_wears_the_runways_lights_and_an_aeroplane_the_aircrafts`
asks the level's own `RunwayLights` node and an aeroplane's `Lights` node what they wear; RED on HEAD, "runway the
aircraft's". By day the runway's lights are back to the size and brightness that change meant them to keep.

**`tests/scenery_shot.gd` reads the red lights by range as well** (`lights_by_range`: under 300 m, to 2 km, beyond),
because a view's 110 parade lights stand from a hundred metres to kilometres off, and `traffic_near`, named for 420 m,
had not one light within 300 m. And `traffic_close` stands 150 m off the same airliner.

**Measured 2026-09-14**, stock 4.7.2, d3d12, 1600x900 at 3D scale 1.40, `--parade --no-spotting`, HEAD's four lights files
against this change. Red pixels a light, PLAIN / FINE:

| view | day | evening | night |
|---|---|---|---|
| traffic, 2.6 km | 0.98 / 1.62 -> 0.08 / 0.03 | 1.63 / 2.36 -> 0.78 / 1.16 | 3.05 / 5.08 -> 3.02 / 5.06 |
| traffic_near, 420 m (all 300 m to 2 km) | 0.52 / 0.82 -> 0.35 / 0.48 | 1.35 / 2.33 -> 1.47 / 2.07 | 2.14 / 4.43 -> 2.18 / 4.44 |
| traffic_close, the 12 lights inside 300 m | 0.25 / 0.42 -> 0.25 / 0.42 | 1.17 / 1.58 -> 1.17 / 1.58 | 1.33 / 2.08 -> 1.33 / 2.08 |
| runway_base | 0.67 / 1.07 -> 0.17 / 0.03 | 1.41 / 1.96 -> 0.95 / 1.26 | 3.24 / 5.13 -> 3.18 / 5.00 |

Far by day, 92 per cent down on PLAIN and 98 on FINE; the lights of an aeroplane inside 300 m exactly as they were at
every time of day. The few per cent the night numbers move is the runway: its lights are full size again and stand inside
the 9x9 boxes of aircraft parked on it, which is also why a still runway picture now differs from HEAD's by day and by
night (108 to 307 pixels over 20 of 255 on the runway views, every vehicle hidden) -- that is the runway's material
coming back, not the aircraft fade.

**THE FINE-AGAINST-PLAIN GATE IS NOT GREEN BY DAY FAR OFF, and it is left so on purpose.** At 2.6 km by day FINE reads
0.03 red pixels a light and PLAIN 0.08, and FINE's reddest 0.424 against 0.435; on `runway_base` 0.03 against 0.17. Both
finishes are under a tenth of a pixel a light there, which is what was asked for -- a far aeroplane by day is not meant
to be found by its lights -- and FINE falls short of a number that is nearly nothing because its multisampling averages
a faint dot into the sky. At evening and night, and near at every time, FINE leads on every view.

**The rim's hash reads a flat seed** (2026-09-14). The dithered rim discards a pixel by `fract(sin(dot(...)) * 43758.5453)`
of its cell and the light's phase, and the phase reached the fragment as an ordinary varying -- the windows' flicker
exactly (8054cd0, "The window did not know whether it was lit"). `varying flat` now. `tests/scenery_shot.gd --drift`
counts the lights on the parade views (`LIGHT_SHIMMER_VIEWS`), every pixel of the box round each red light, red by the
measure's own rule, because the town's measure -- every second pixel, luminance over 0.25 -- reads nothing there.
Measured lightly, since the reason is the windows' and already proven: `traffic_close` at night, `--parade --no-spotting
--drift=0.25`, one launch of each shader, taken under load from other lanes. **The toggle count did not move**: 6.5 to
6.7 a frame on PLAIN and 6.4 to 6.6 on FINE, with 110 red lights on screen at 0.7 and 1.2 red pixels each -- a dot that
small is rarely a pixel whose centre the rim's hash decides. With the camera still, 0 toggles in both. The still
pictures are not byte for byte HEAD's: 2 pixels on PLAIN and 17 on FINE moved by more than 8 of 255, every one a light's
own red, green or white inside the lights' boxes -- rim pixels the drifting hash had decided the other way -- where two
launches of HEAD differed by none. It is kept on the windows' argument, not on a number it moved.

**Measure the lights with the spotting boxes OFF.** The first measurement on the new size used `--parade`, which
switches the boxes on: red wireframes, counted by the 9x9 box round every light. The traffic view read 58 red
pixels a light out of 81, FINE fell 2 to 8 per cent short of PLAIN, and HEAD's lights failed the same way, because
thin lines lose pixels to FINE's multisampling whatever the lights do. `--no-spotting` exists for this.

A visibility light on FINE must be at least as findable as on PLAIN, and eyes disagreed about
whether it was, so `tests/scenery_shot.gd` measures it. Every red light on every aircraft in frame
is projected to the screen, and a 9x9 box round it is read out of the saved picture: how many
pixels are RED (red over half, and more than 1.8 times the larger of green and blue) and how red
the reddest is. THE GATE, decided before the numbers it judges: FINE red pixels per light at least
the lower of two PLAIN runs less the spread between them -- one PLAIN run against another is how
much a view moves on its own -- and FINE's reddest pixel within 0.005 of PLAIN's.

It caught two faults that looked fine at a glance:

- render_check_3 (2026-09-12): PLAIN 5.8 to 13.4 red pixels a light, FINE 0.00 on every view.
  PLAIN's core pixel was (255, 124, 102); FINE's was about (255, 150, 136) on every light -- one
  fixed shift, which is a colour and not multisampling. It was 8 % of white mixed into the core,
  enough to lift green and blue past the test, with a blended halo on top. So FINE became two
  passes: the PLAIN opaque dot in the PLAIN colour, and a halo pass (`next_pass`) kept off it.
- render_check_4: FINE's reddest pixel was 0.514 on every view, the same as PLAIN. Red pixels a
  light passed on seven views; the clouds view missed by 0.30 inside its own spread of 0.58, and
  the base-leg view -- lights at about 1.5 km -- missed by 0.89 against a spread of 0.44, because
  FINE multisamples and a small dot's edge pixels soften below the test. The core went from 1.2
  to 1.35 times the PLAIN dot.

### Found while looking, and NOT fixed here

- **The PLAIN ocean has a straight seam across it.** `ocean.gdshader` wraps world position every
  2048 m (`tile`) before its wavelets, and a wavelet's phase is not periodic over 2048 m, so the
  phase jumps at every tile edge and draws a straight line on the water (coast view, first
  render check, 2026-09-12). It predates this work and PLAIN is kept byte-identical, so it is
  still there. `ocean_fine.gdshader` does not wrap, and has no seam; the same change would fix
  PLAIN and would change PLAIN's picture.
- **Rock and grass drew straight-edged seams along their noise lattice, on both finishes and both editors -- FIXED
  2026-09-14.** Rock's coarse shape (`fbm3(flat_uv * 0.010)`) showed them from about 2 km out, and grass's clumps beside
  the runway, where the `tile(world_pos.xz, 4096.0)` then in front of them put the view at cell 107. THE HASH COLLAPSES AT LARGE INDEX: `hash21`
  multiplies a corner by 123.34 and 456.21 and float32 loses the fraction, so neighbouring corners come out near-equal.
  It is NOT a corner rounded two ways: one corner hashed from either side matched at every index from 5 to 600, on stock
  and double. Each integer corner is now wrapped symmetrically every 128 cells before it is hashed
  (`terrain_noise.gdshaderinc`, `wrap_cell` and the `*_wrapped` lookups; `value_noise_d_wrapped` in
  `terrain_relief.gdshaderinc` for grass_fine's hummocks). Within half a period of the origin the pattern is unchanged.
  Measured: seams at 2.2, 8.1 and 32.1 km gone; rock at 128 m unchanged; every night picture of the scenery sweep
  unchanged past 8/255 and every night floor passing. By day the grass view changed most (37.5 % of pixels on PLAIN),
  because it was drawn from the collapsed stretch.
  - **AND THE TILE IN FRONT OF IT WENT TOO.** Grass read its clumps through `tile(world_pos.xz, 4096.0)`, which jumps from
    cell 143.36 to 0 (not a multiple of the period) and drew an older straight seam at every multiple of 4,096 m. That
    includes world x = 0 and z = 0 beside the airfield: looking along x = 0 from 520 m, FINE by day showed it as a line to
    the horizon. The wrap already bounds the index, so both grass shaders read `world_pos.xz * clump_scale` untiled.
    Measured on the double editor, one base: the line is gone, and the seam view moved by 0.59 % of pixels past 8/255 on
    PLAIN and 0.75 % on FINE. The five scenery views moved by at most 2.6 % by day (fields, FINE), 0.9 % on the grass
    view, 0 on forest_low, and 0 in every night picture. Every night floor passes; the grass ground went from 0.0533 to
    0.0508 on PLAIN and from 0.0507 to 0.0479 on FINE, against 0.030.
- **Fields fanned and streaked along the grass noise's lattice lines -- FIXED 2026-09-14.** Value noise's smoothstep
  lattice creases along x and z: from 300 m the 625 m patches drew fans converging on the vanishing point, and from 40 m
  FINE's 28.6 m clumps drew streaks and tiles. The terrain probe proved each by holding that noise still (`--patches=off`,
  `--clumps=off`). The patches (grass, grass_fine, grass_blades), the clumps and the hummocks are now Perlin gradient
  noise, each fbm octave turned by its own fixed angle, every corner through `wrap_cell` (`fbm3_turned`, `fbm2_turned`
  and `gradient_noise_d_wrapped`).
  - **The same shares, measured, not guessed.** Over 60,000 island points the gradient fbm's spread is the value fbm's
    (0.140 against 0.141, 0.160 against 0.160), so it is lifted by 0.5 and not scaled: lush grass 38.1 % against 38.2 %,
    bare earth 4.3 % against 4.5 %. The hummocks' slope is scaled by 0.58, since gradient noise's is steeper (0.81
    against 0.47).
  - **The A/B** (`tests/scenery_shot.gd --still`, double editor, godotgames-drafts/.../cockpit-terrain/noise_ab): two
    launches of either build differ by at most 2 pixels of one step. Between the builds about half of each ground
    changed, and nothing above the horizon. The fields view's bands and fans are gone. The low grass view stands in a
    drier patch, since the pattern moved, so its ground at night went up rather than down: 0.0757 on PLAIN and 0.0700 on
    FINE against the 0.030 floor, from 0.0508 and 0.0479.
- **Flat translucent discs floated in the air under the clouds, on both finishes -- FIXED 2026-09-14.** They were
  `LiftYard`'s wisps: seven puffs climbing each lift column, 8 by 4 spheres squashed to 0.35 of their width and faded by
  height, which from most angles read as flat octagons over the fields and peaks rather than as rising air, some in front of
  a mountain (the lead asked what they were). Each is now a 16 by 8 sphere at 0.7 of its width (`LiftYard.WISP_ROUND`,
  153 vertices a wisp against 45), faded out with distance from the eye, whole within 600 m and gone by 2500 m
  (`LiftYard.WISP_SEEN`, through `LiftYard.wisp_alpha`), measured from the camera the viewport draws with -- the midpoint of
  the eyes in a headset.
  - **A WISP FADED TO NOTHING IS NOT DRAWN.** `_process` packs the visible wisps at the front of the batch and sets
    `visible_instance_count`, written only when the count changes; a faded wisp was still 153 vertices of work in both eyes.
    RED, faded wisps kept: 140 of 140 drawn from 200 km up; with them skipped, 0 of 140, and 19 from inside the first column.
  - **HAZE, NOT A LENS.** The first round wisps were one alpha all over, and close to they read as large hard-edged pale
    ellipses, one across a peak like a glass lens (the lead, on the first pictures). `world/shaders/wisp.gdshader` thins
    the alpha towards the silhouette by how squarely the surface faces the eye (`WISP_RIM`) and fades in the bottom of each
    puff (`WISP_SOFT_BOTTOM`). One material, no new nodes. The bottom fade is in the puff's own space, NOT against the rock:
    the one thing that knows where a hillside behind a wisp is, is the depth texture, which nothing here reads.
  - **NOT A DEPTH FAULT.** The wisp material does not turn the depth test off and has no render priority, so a wisp seen
    in front of a peak was between the eye and the peak; the distance fade is what removes those. `tests/air.gd` holds the
    flags, the fade and the skipping. RED, a fade that ignored distance: 1.000 at 300 m and still 1.000 at 2600 m.
  - Cost, A (HEAD) and B interleaved A B A B on the clouds and mountains views by day, 240 frames, WITH
    OTHER LANES' SUITES AND RENDERS RUNNING, so only B minus A is read: GPU timer medians -0.002 to +0.001 ms on both views
    and both finishes, against A's own spread of 0.000 to 0.003 -- flat, rim and all. Draw calls unchanged. Primitives +896
    on the clouds view, and -1,984 (FINE) and -1,696 (PLAIN) on the mountains view, where no wisp is near enough to draw; the
    first round wisps, drawn faded, were +29,120 on every view. The look (2026-09-14): from the clouds view the far scatter
    is gone and the near wisps are soft -- the one that lay across a peak like a lens is a white mist over its summit -- but
    close to they keep an oval puff's shape, soft haze more than moving air. From the mountains view there were none left
    to remove: those discs were the ridge columns' wisps, and there is no ridge lift in still air (`Terrain.WIND`).
### Rejected

- Raymarched clouds: the right answer for a cloud you fly through, and a cloud you fly through
  fills both eyes.
- Alpha-card grass: cut-outs lose the early depth test on a tiled GPU, which is a standalone headset's.
  The desktop GPU the game is played through (Virtual Desktop, Forward+) is not tiled, and a field of
  cards is still overdraw in both eyes. Not re-measured on Forward+.
- OmniLights for nav lights: a slideshow, and invisible at the range they are for.
- Blended soft-particle smoke: needs the depth texture (a pass on Mobile, untimed on Forward+), and
  blended overdraw in a smoke column, which no renderer takes away.
- A slider per effect: what a player can decide in a headset is "this is too slow".

### The clouds are puffs: six kinds at their own heights, flown into and out of (2026-09-17)

Asked for on 2026-09-17: "perhaps transparent spheres in the right orientation will feel like clouds, i'd like to have more
variations on clouds and have them at different altitudes so planes can fly through, around them". After the pictures
(`screenshots/2026-09-17/cockpit-clouds2-*`) the user said: "all clouds look good". The reasoning, the other games' ways and
the costs are in `research/clouds_2.md`.

- **A PUFF IS A TRANSPARENT ELLIPSOID INTEGRATED EXACTLY.** `world/shaders/puff.gdshaderinc` works out each pixel's optical
  depth through the ellipsoid in closed form, with density 1 - r^2, and takes Beer's law of it. The mesh is drawn by its back
  faces, so the eye can be inside it. Overlapping puffs sum in any order, so there is no sorting. Each chord is cut at the
  cloud's one base and at the depth buffer's surface.
- **THE SKY IS `PuffSky.level_sky`**, from `FlightLevel.PUFF_SEED` and `Terrain.lift_zones()`, identical on every peer, with
  no cloud on the wire. `Net.clouds_on` is still the host's whole say. Every thermal keeps its cloud: flat-based over a
  strong column and fair-weather over a weak one, its base at the column's top. It is keyed by `LiftYard.cloud_key`, so the
  eye test and the probes name it as they always did. LiftYard keeps the rings and wisps and draws no lumps.
  `--clouds=lumps` puts the lumps back.
- **LAYERS WITH CLEAR AIR BETWEEN** (`PuffCloud.CLEAR_AIR`): cumulus 1.0 to 1.5 km, stratocumulus 2.2 to 2.5 km,
  altocumulus 4.2 to 4.8 km, cirrus 8.2 to 9.4 km, with the towering cumulus climbing through. Every base clears the ground
  under every puff by `PuffCloud.CLEARANCE`. `tests/puff_sky.gd` holds all of it.
- **INSIDE, THE PUFFS GIVE WAY TO THE WHITEOUT.** Deep in a cloud every puff holding the eye covers both eyes (1.333 ms at
  2880x1620). So from `PuffSky.GIVE_WAY` those puffs fade out, and `Daylight.show_in_cloud` takes exactly the share they
  gave up (`PuffSky.give_way`).
- **DRAWN STRAIGHT AFTER THE MIST, BEFORE EVERY OTHER SEE-THROUGH THING** (`PuffSky.DRAWN_AT`). A puff writes no depth, so
  anything blended before it was painted over, even in front of the cloud. OPEN: a light or a contrail BEHIND a cloud now
  shows through it (team-lead's ruling: the lesser fault; picture `cockpit-clouds2-40`, where LiftYard's additive rings
  show through the cloud at night and the aircraft's opaque lights do not). `tests/scenery_shot.gd` no longer looks for a
  red light behind 1 or more of cloud (`LIGHT_CLOUDED`), and FAILS a view with traffic in frame that counts fewer than
  `LIGHTS_CLEAR_LEAST` lights clear of it. A check that excused every light would visit nothing: the first cloud views
  did exactly that, with their camera stood inside a neighbouring cumulus. They now come in from the clear heading that
  sees the most traffic (70 and 38 lights at night), and only `cloud_inside`, whose eye is meant to be in the cloud, is
  excused.
- **LIT LIKE A PAINTED CUMULUS (clouds3, 2026-09-18)**, after a Porco Rosso still: near-white crowns, blue-grey shade,
  a line between them, crisp lobed edges. Each puff is lit at the skin the eye sees, not at its chord's middle. One world
  noise with its analytic gradient scallops the outline, bends every lobe's normal, and thins the depth. Every knob is a
  named key in each `PuffCloud.KINDS` row (`crisp`, `bump`, `relief`, `body`, `shade_light`, `terminator`, `top`), plus
  `PuffSky.SHADE_COLOUR`. Close to (40 to 200 m) and inside, it all fades back to the soft clouds2 look, so a fly-through
  is unchanged. `tests/puff_shot.gd --only=look` fails a heap that is not lit from one side. `research/clouds_3.md` has
  the reasoning and the numbers.
- **TOWERS BILLOW AND STAND IN WALLS (clouds3, step 3).** A towering cumulus is 5 to 7 overlapping masses with bulging
  lobes and a cauliflower crown (`PuffCloud._tower`, `TOWER_FOOT`/`TOWER_NECK`/`TOWER_LOBES`). `PuffSky.plan` groups its
  towers into walls of about `WALL_TOWERS`, `WALL_STEP` of a width apart (`PuffSky.wall`), taking the same random draws
  so no other cloud moves. A cloud's self-shadow is capped at `SHADOW_MOST` (600 m) of its reach, because a tower's reach
  is its height. The user asked for "darker bluer" shade and soft, wispy edges; both are how it is now.
- **`MODEL_MATRIX` IN `fragment()` IS THE BATCH'S, NOT THE MULTIMESH INSTANCE'S.** The instance transform is applied in the
  vertex stage only. clouds2 turned each puff's modelling by `mat3(MODEL_MATRIX)` in the fragment shader, so every
  puff's lighting came out turned by its own random yaw. Pass what a fragment needs from the instance in flat varyings,
  as `puff_x`/`puff_y`/`puff_z` do.
- **WHAT IT COSTS**, under a measurement hold, at 1600x900 and 2880x1620. The 24 km probe sky is 0.161 and 0.321 ms,
  against 0.031 and 0.082 ms with no clouds, in 6 draws. Inside a cloud it is 0.429 and 1.333 ms before giving way. The
  depth copy it brings back to PLAIN is +0.022 to +0.075 ms.

### A cloud has one base, a shape of its own, and the sky's light

Asked for on 2026-09-13: "improvements on the mountains and clouds, i'd like them to be more realistic." Before it,
every cloud in the sky was the same nine lumps in the same ring (`l % 3`, `(l * 7) % 5`) scaled by its zone, so thirty-one
clouds read as one cloud stamped thirty-one times; each lump was cut flat at ITS OWN bottom, so a cloud had nine bases at
nine heights; and PLAIN's white lit spheres were barely greyer underneath than on top.

- **ONE FUNCTION LAYS A CLOUD OUT.** `LiftYard.cloud_lumps(zone, wind)` is static and pure, so the MultiMesh and the test
  are fed by it alike -- headless answers a default for every instance read back off a MultiMesh. It is seeded by where
  the zone is, through `Terrain.hash01`, with the SIGNED position (the absolute value made mirror-image zones one seed):
  a core on the base, up to `CloudTuning.MAX_TOWERS` towers stacked on it as the thermal strengthens, and a skirt whose
  sizes are drawn squared, so most lumps are small and a few are big. Every lump carries its cloud's base, thickness and
  seed in custom data. Every number is in `world/cloud_tuning.gd`.
- **LIT BY THE SHADER FROM THE TIME OF DAY, NOT BY THE ENGINE.** A custom `light()` does not run where vertex shading is
  forced, which is a standalone headset's default, so both cloud shaders are unshaded and call
  `world/shaders/cloud_light.gdshaderinc` -- PLAIN once a vertex, FINE once a pixel -- for a flat base darker the thicker
  the cloud, a sunlit crown, and a lining where a thin edge has the sun behind it. The sun, sky and shade colours are
  worked out from `DaylightTuning`'s own numbers by `LiftYard.cloud_light` and written onto both materials by
  `LiftYard.show_daylight`, once per change. `to_eye` is from `CAMERA_POSITION_WORLD`, the midpoint of the eyes, so a
  lining is the same in both.
- **FINE's rim frays in clumps, and nothing in its coverage reads TIME**, so a still frame does not blink: the threshold is
  mostly value noise a few cells across and 0.3 hash. The shape still boils, in the vertex.
- **Found by looking, not by any suite: the first numbers whited the clouds out.** With the whole sun (1.0) and the whole sky
  added on top, a day cloud summed past white nearly everywhere -- worked from DAY's numbers, a sunlit side about 1.5 to 1.8
  and even the base about 0.87 -- and the clouds view (2026-09-14) drew both finishes' day clouds as flat white shapes with
  less modelling than the engine-lit spheres they replaced, while evening looked right. The shares came down (0.75 sun, 0.25 turned away, 0.5 sky) and the modelling came back. The same look showed a strong thermal's towers as a column of beads, each a share of the cloud's reach; a tower is
  now a share of the lump it stands on (`TOWER_SIZE`, `TOWER_STEP`), so it tapers as it climbs.
- **And the base still read pale, so the sky gives way to the sun (2026-09-14).** Looking at the merged pictures, the lead
  found a day cloud's underside barely darker than its crown. Dimming the base alone (`BASE_BRIGHT` 0.95/0.55 to
  0.70/0.40) did not do it: measured over the cloud pixels of the clouds view, the darkest tenth against the brightest went
  only from 0.820 to 0.807, because it dimmed every low part together, crowns included. The sky's light was what filled
  the shade in, so `SUNLIT` is 0.9, `AWAY` 0.2 and `AMBIENT` 0.35 as well: the same measure reads 0.752 (PLAIN; FINE 0.746),
  the darkest tenth falls from 0.731 to 0.645 and the brightest stays at 0.858. A number, not a shader, so nothing else
  changed. FINE's base still shows a ragged fringe where the rim dither reaches a flat base seen nearly edge-on -- a shader
  matter, left for later. (The measure counts only the day sky: an evening sky is warm and passes its colour test.)
- **What holds it.** `tests/air.gd` holds every lump of every cloud to its ZONE's top, read off `Terrain.lift_zones()`,
  and no two clouds to one heap. RED, every cloud given one seed: 27 repeated layouts in 31 clouds. `tests/scenery.gd`
  holds both finishes' clouds to the level's real evening sun, read off the DirectionalLight3D, and to evening's colour
  as written, and holds the cloud writes still for sixty frames. RED, the clouds not relit on a change: both finishes
  still carried day's sun, (0.418, 0.571, 0.707) and white, against evening's (-0.933, 0.122, -0.339) and (0.95, 0.684,
  0.456).
- **What it costs:** less than it did. Stock 4.7.2, d3d12, 1600x900 at 3D scale 1.40, A (HEAD's cloud files) and B (these)
  interleaved A B A B, 240 frames a view, TAKEN WITH OTHER LANES' SUITES AND RENDERS RUNNING on the same machine, so only the
  B-minus-A difference is read. GPU timer medians: the clouds view -0.012 ms PLAIN by day, -0.011 at evening, -0.009 FINE by
  day, -0.007 at evening; the mountains view, which has clouds in it, -0.034 to -0.035 on both finishes -- against A's own
  spread of 0.000 to 0.003. Both cloud shaders are unshaded now, so the engine's per-pixel light and shadow lookups are gone.
  Draw calls are unchanged (641 PLAIN, 696 FINE on the clouds view); primitives rise 13,392 PLAIN and 44,640 FINE, eleven
  lumps a cloud for nine. The wall clock moved -0.24 to +0.62 ms against a spread of 0.49 to 1.30 under that load: nothing.
- **Rejected:** greying the low lumps by instance colour alone (cheaper still, and it gave a cloud no flat base, which is
  what makes a white heap read as a cumulus); a pure hash rim (speckle close under the deck, and with TIME in it single
  cells blink in a still frame).

### A cloud you can fly into: the mesh far, the fog near

Asked for on 2026-09-14: cumulus you can fly into and lose the outside view. A `LiftYard` cloud is spheres drawn with their
back faces culled, so from inside one the island is in plain view; froxel fog hides what is behind it, but from a few
kilometres it is a soft blob where the lumps are crisp (the first fog pictures, `godotgames-drafts/2026-09-14/cockpit-clouds`,
`r2-volumes` against `r1-lumps`). So each cloud is its mesh far off and FogVolume fog near the eye, crossfaded.
`world/cloud_bank.gd` (`CloudBank`) draws the fog, on FINE, on Forward+ (the Mobile and Compatibility renderers have no
volumetric fog, and the level builds no bank on them). `--clouds=lumps` after the bare `--` keeps the mesh clouds alone, to
time against; `--clouds=none` draws no cloud, for reference pictures. PLAIN is the mesh clouds alone with the environment's
volumetric fog off, and the whiteout below. ONE SWITCH: the finish.

- **ONE VOLUME A THERMAL, LAID OUT BY `LiftYard.cloud_lumps`.** A box round the cloud's lumps from the zone's top up
  (`LiftYard.cloud_bounds`) and a material carrying the same twenty-four lumps, each turned and stretched along the cloud's
  heading (`lump_radii`, `heading`), so the fog stands where the lumps stood; world
  noise (`world/shaders/cumulus_fog.gdshader`) only erodes inside that, and climbs at `FOG_CLIMB`. One material a cloud: a
  fog shader cannot tell which cloud it is in. `tests/air.gd` holds every box to its zone's top round its lumps and the
  envelope (`LiftYard.shape_at`, the shader's `cloud_shape` in GDScript) thick in the core and empty a metre under the base.
  RED, the base clamp removed: 20 of 20 boxes off the base (1398.4 against 1500.0) and fog under all 20.
- **THE MESH FAR, THE FOG NEAR, PER CLOUD, ANNOUNCED.** `CloudBank.fog_share` of the eye's distance to a cloud's box -- the
  camera the viewport draws with, the midpoint of the eyes in a headset -- is all fog inside `CloudTuning.FOG_FADE.x` (150 m)
  and all mesh past `.y` (500 m; fog at 700 m was already a blur). The bank emits `fog_share_changed(key, share)` and the
  level hands it to `LiftYard.show_fog_share`: the FINE lumps give way in blotches a sixth of a lump across
  (INSTANCE_CUSTOM.a, `world/shaders/cumulus.gdshader`), a cloud that is all fog has its lumps shrunk to a millimetre, and a
  cloud with no fog has its volume hidden so the froxels never run it. Shrunk rather than packed out of the batch because a
  lump's place in the batch is how its cloud's custom data is found. The first fade scaled the rim's alpha down as a whole
  and dissolved the lumps as salt and pepper (`cloud_at_350`). `tests/air.gd` holds the share the fog is drawn with and the
  share the lumps were told to `fog_share` far off, inside and in the fade, PLAIN to all mesh, and a zone that goes to taking
  its fog and leaving its lumps whole. RED, the announcement cut: lumps told 0.00 while the fog drew 1.00 inside and 0.50 in
  the fade.
- **CLOUDS COME AND GO BY ZONE**, keyed by `LiftYard.cloud_key` (the zone's ground position to the metre): `gather` adds the
  zones it has not seen and removes the ones that have gone, for a world that streams its thermals.
- **ONE COLOUR ACROSS THE FADE, measured.** Mean colour of the cloud's pixels against a `--clouds=none` picture of the same
  view (`tests/scenery_shot.gd`'s `cloud_at_<metres>` poses), FINE, the mesh at 550 m against the fog at 150 m:

  | | mesh at 550 m | fog lit by the engine (the first fog) | fog as `cloud_light` in EMISSION | fog as `cloud_light` in ALBEDO (now) |
  |---|---|---|---|---|
  | day | (195, 201, 212) | (175, 184, 202) | (190, 197, 202) | (199, 205, 214) |
  | evening | (216, 178, 147) | (137, 112, 116) | (208, 164, 106) | (214, 174, 140) |
  | night | (17, 21, 32) | (34, 42, 64) | (2, 2, 2) | (19, 24, 35) |

  Over the whole strip, 700 m out to inside, the cloud's mean luminance holds at 200 to 204 by day, 175 to 184 at evening and
  21 to 25 at night; inside, 226, 169 and 25. The fog's colour is the lumps' own `cloud_light`, from `LiftYard.cloud_light`
  and `LiftYard.cloud_light_shares` (one place for both), with the densest lump's normal at each froxel.
- **WHY ALBEDO, AND THE SUN IT IS DIVIDED BY.** Godot 4.7 packs a froxel's emission into one integer after weighting it by
  the density and truncates it -- `emission *= clamp(density, 0.0, 1.0)`, `uvec3(emission.r * 511.0, emission.g * 511.0,
  emission.b * 255.0)` (`volumetric_fog.glsl`) -- so at a cloud's density a night's light is under one step: black, and an
  evening loses its blue first. Rounding instead of truncating fixed evening and not night. Albedo is packed at 2047 steps
  before the light multiplies it, so the colour rides there divided by the light the engine will use: the sun's colour made
  linear times its energy (`CloudBank.engine_sun`), times PI (`light_data.energy *= Math::PI`, `light_storage.cpp`) times the
  phase at anisotropy 0, 1 / (4 PI) (`volumetric_fog_process.glsl`) -- 0.25, derived, not fitted, and it matched all three
  times at once. `sun_light` is the wrong divisor: it makes colour and energy linear together, a sixth of the moon at night.
  Hence `FOG_ANISOTROPY` 0, and no ambient inject.
- **THE PROTOTYPE'S NOTE ON EMISSION WAS WRONG, AND IS WITHDRAWN.** It said emission "adds up along the path". Measured with
  albedo black, deep in a cloud: emission 0.5 read 217 of 255 at the density and 216 at three times it, 0.25 read 172 -- a
  colour the engine weights by density itself. The environment's `volumetric_fog_emission` does nothing to the volumes (it
  lights the environment's own fog, whose density is 0): 183.4 against 183.2.
- **`volumetric_fog_sky_affect` 1, NOT THE BRIEF'S 0.35.** At 0 the part of a cloud in front of the sky was not drawn at all.
- **ONE FROXEL GRID FOR BOTH EYES, from the camera that encloses them.** Read from Godot's 4.7 source (2026-09-14), not seen
  in a headset. `RendererSceneRender::CameraData::set_multiview_camera` builds one main transform and one `main_projection`
  whose frustum encloses both eyes' (from `planes[0][PLANE_LEFT]` and `planes[1][PLANE_RIGHT]`, then
  `main_projection.set_frustum(local_min_vec.x, local_max_vec.x, ...)`). `render_forward_clustered.cpp` hands that one
  camera to `_update_volumetric_fog(rb, ..., scene_data->cam_projection, scene_data->cam_transform,
  scene_data->prev_cam_transform.affine_inverse(), ...)`, and `Fog::volumetric_fog_update` takes a single
  `const Projection &p_cam_projection, const Transform3D &p_cam_transform` -- no view count, no per-eye grid. Each eye's
  fragments read it through the same projection: `combined_projected = scene_data.projection_matrix * vec4(vertex_interp,
  1.0)` and `volumetric_fog_process(combined_uv, -vertex.z)` under `USE_MULTIVIEW`. WHAT THAT MEANS IN A HEADSET: the fog
  is one field in the world, read by both eyes at their own surface points, so there is no per-eye pattern and the house
  rule holds; the grid's 128 columns are spread over the wider combined frustum, so each eye gets a little coarser a fog
  than the desktop's; the sky and anything past `volumetric_fog_length` read the last slice at the combined uv, which is
  the same in both eyes; and temporal reprojection follows the combined camera, so it ghosts with head turns as it does
  with the mouse. Still to see in a headset.
- **INSIDE, THE WORLD IS GONE**, at `FOG_CORE_DENSITY` 0.04: with the ambient inject off the step across where the horizon
  would be was 3.6 of 255, the same as at 25 times the density. `LiftYard`'s additive rings and wisps still show through.
- **MOVING.** A pass flown into the cloud at 140 m/s (`cloud_fly`, `--strip=30`, day and evening) keeps one colour from 1.2 km
  to inside; in the fade the lumps' blotches are the most visible thing for about a second. A turn of 30 pixels a frame
  (`--drift=30 --strip=10`, about 150 degrees a second) near and inside the cloud drew no smear from temporal reprojection in
  the frames saved. Thirty seconds of TIME on `cloud_at_60` (`--frames=1800 --strip=300`) barely change: the texture climbs
  24 m against a 160 m noise, under 12-pixel froxels. It does not boil; it hardly evolves either.
- **IS THE EYE IN A CLOUD: ASKED ONCE A FRAME, ANNOUNCED, DECIDED BY THE LEVEL.** `LiftYard.eye_in_cloud(eye)` answers how
  dense the densest cloud holding the eye is there, 0 to 1, and which cloud (`LiftYard.cloud_key`), from
  `LiftYard.cloud_density_at` -- the fog shader's density of the same envelope with its noise at the mean, so a mesh cloud and
  a fog one begin in the same place -- and asks the lumps only of a cloud whose box holds the eye. `FlightLevel` asks it from
  the camera the viewport is drawn with (the midpoint of the eyes in a headset: the eye `CloudBank` fades by), emits
  `eye_in_cloud(depth, key)` when the depth moves by a hundredth or the eye leaves every cloud, and `_on_eye_in_cloud`
  decides, and decides again on every change of finish or time of day:
  - the rings and wisps fade out by the depth, on both finishes (`LiftYard.show_eye_in_cloud`): they are additive and
    unshaded, and from inside the fog the ring 1.5 km below still showed;
  - with no fog clouds worn -- PLAIN, or FINE with `--clouds=lumps` or on a renderer with no volumetric fog -- the depth fog
    whites the view out
    (`Daylight.show_in_cloud`): its density from the scene's 0.00016 to `CloudTuning.WHITEOUT_DENSITY` 0.06 (95 % of the view
    gone by 50 m), its light to the cloud's colour (`LiftYard.cloud_colour`, `cloud_light` worked in GDScript) and its aerial
    perspective to none, written only on a change. With fog clouds worn the fog does it, and the depth fog is left alone.

  The eye was the rig's head or the watch camera first, and the suite, which has neither camera, found no eye at all: the
  viewport's camera is the one every build has. `tests/air.gd` stands the level's viewport camera in the core of a cloud on
  PLAIN -- depth 1.00 in that cloud, markers 0.000, depth fog 0.0600 in the cloud's colour -- and two kilometres over it
  every one of those is back to the time of day's. RED, the level's connection cut: markers 1.000 inside and the depth fog
  at 0.00016.
  Pictures (godotgames-drafts/2026-09-14/cockpit-clouds/p2b-inside): from inside the clouds view's cloud on PLAIN the
  island that was in plain view is flat cloud colour -- grey-white by day, peach at evening, dark blue at night -- and no
  ring; from 60 m and at the edge, outside the dense envelope, the picture is unchanged; FINE with no fog clouds the same.
- **WHAT IT COSTS: NOTHING FAR FROM A CLOUD, ABOUT 0.14 MS NEAR ONE, ON FINE.** Stock 4.7.2 on Forward+, d3d12, 1600x900 at 3D
  scale 1.40, today's mesh clouds (A) and these (B) interleaved A B A B, 240 frames, `--hold-fires`, WITH OTHER LANES' SUITES
  AND RENDERS RUNNING, so only B minus A is read. GPU timer medians, both rounds agreeing to 0.008 ms: FINE, the clouds view
  (every cloud all mesh) 0.495 against 0.492, `cloud_at_250` (in the fade) 0.459 against 0.601, inside 0.449 against 0.582;
  PLAIN within 0.006 ms of A on all three. CPU medians moved inside their own spread. THE FROXELS ARE SWITCHED OFF FAR FROM
  EVERY CLOUD: with the environment's volumetric fog left on, the clouds view cost 0.609 ms against 0.489 with no volume in
  the grid at all, so `CloudBank._process` turns it on only while some cloud has fog in it; `tests/air.gd` holds it (RED, on
  whenever FINE: "far on").
- **THE CLOUDS ARE NOT ONE FAMILY, AND THEIR EDGES ARE SOFT AND TORN** (asked for on 2026-09-14: "more detail, spheres and
  dithering ... real clouds are more distorted and shredded and have softer edges", and "make the shapes different cloud to
  cloud"). A cloud is `CloudTuning.LUMPS` 24 lumps, not 11, and one of five kinds drawn by the zone's seed among the kinds whose
  strength range holds its thermal's, each by its weight (`CloudTuning.TYPES`: humilis, mediocris, congestus, fractus, spread).
  A kind names its lumps' flatness, its spread, how long it is along its own heading, its towers, their lean and the shear of
  its top, its crown bumps, the shreds torn from its rim and tower tops, and how ragged its skirt is (`LiftYard.cloud_lumps`).
  A lump takes the square root of its cloud's stretch; the whole of it made every lump of a long cloud a saucer from under it.
  Every lump the same count for every cloud, so the sky is still one MultiMesh. The pick is hashed twice: `Terrain.hash01` is
  one mixing round, and neighbouring zones' seeds drew the lightest kind for six clouds of eleven strong thermals and congestus
  for none.
  - `tests/air.gd` measures it on the laid-out lumps, never the seeds or the kinds: each cloud's height over its widest plan
    extent, its length over its width among eight headings, and its lumps broken away, into TALL, FLAT, LONG or HEAP; the island
    must spread its height-to-width by 0.15 and hold four classes. RED on the eleven-lump layout: spread 0.106, HEAP 17 and
    FLAT 3. Now 0.227 and HEAP 10, FLAT 6, TALL 3, LONG 1.
  - AND NO CLOUD SPREADS PAST ITS THERMAL: every cloud's fog box is at most `CloudTuning.PLAN_MOST` 4.5 of its zone's radius
    across, and a cloud past it is drawn in towards its middle in plan. The first kinds laid a flat cloud out 3.1 km long over a
    279 m thermal (11.19 radii): it came on as fog while nearly all of it was a kilometre off, a blurred streak, eleven pairs of
    boxes overlapped and the fly-in began inside a neighbour. RED at 11.19; eleven lumps reached 4.47 and overlapped six pairs,
    and six pairs overlap again now (printed, not held: the terrain puts the thermals).
  - SOFT EDGES, ONE PATTERN FOR BOTH EYES: FINE's rim fades over the outer 0.55 of the facing, not 0.30, in cells about a pixel
    across from the midpoint of the eyes, keyed to the lump; PLAIN gets a rim it did not have, the facing worked out once a
    vertex against a hash of the fragment's cell in the lump's own frame. FINE's displacement 0.24 with florets at half of it (at
    0.30 and 0.6 a kilometre-wide lump overhead showed its sphere's facets as shelves).
  - THE FOG, SHREDDED: its erosion is 0.45 billows (a cell-distance noise that bulges) against smooth noise, a finer octave
    within 80 to 320 m of the eye (`FOG_NEAR_DETAIL`, `FOG_NEAR_REACH`; `CloudBank` writes the eye only to a cloud with fog in
    it), and it climbs at 3 m/s, not 0.8. `FOG_LUMP_SOFT` 0.30: 0.15 was tried and merged a cloud's lumps into one smooth band.
  - THE FADE STILL MATCHES. Colour, mean of the cloud's pixels against `--clouds=none` (FINE, mesh at 550 m, fog at 150 m):
    luminance 198.5 against 198.6 by day, 181.9 against 181.6 at evening, 20.6 against 22.1 at night. Outline: `cloud_at_300`
    and `cloud_at_150` drawn as fog and with `--clouds=lumps` from the same pose stand the same footprint, heights and towers;
    the fog is softer and its top flatter, at froxel size. The dissolve in the fly-in (`cloud_fly --strip=30`, frames 330 and
    360) is fine speckle at the lumps' edges where it was holes a sixth of a lump across; it is still visible for about a
    second. Thirty seconds of TIME at 60 m (`--frames=1800 --strip=300`): a mesh tower's outline moves visibly in fifteen
    seconds, billowing rather than boiling; the fog, under 12-pixel froxels, still barely changes.
  - WHAT IT COSTS: +0.14 MS GPU ON FINE'S CLOUDS VIEW, +0.01 ON PLAIN'S. Stock 4.7.2, d3d12, 1600x900 at 3D scale 1.40, the
    eleven-lump clouds (A, the working changes stashed) and these (B) interleaved A B A B, 240 frames, `--hold-fires`, WITH
    OTHER LANES' WORK ON THE MACHINE, so only B minus A is read; GPU timer medians, both rounds agreeing to 0.009 ms. The
    clouds view (every cloud mesh): FINE 0.429 to 0.570 (+0.141), PLAIN 0.216 to 0.227 (+0.011); `cloud_at_250`, in the fade:
    FINE +0.029, PLAIN +0.030; inside: FINE +0.051, PLAIN +0.054. Draw calls the same on the clouds view (859 FINE, 793
    PLAIN); primitives +187,200 FINE and +56,160 PLAIN, thirteen more lumps on each of twenty clouds at 720 and 216 triangles.
    CPU medians rose 0.06 to 0.28 ms against A's own round-to-round spread of up to 0.09, a rise, not traced. REJECTED: FINE's lump on an 18 by 10
    sphere, not 24 by 14 -- 155,520 fewer primitives and only 0.021 ms off the clouds view (0.566 to 0.545) and 0.016 off
    `cloud_at_250`, a seventh of what the pass added, so the cost is the pixels (the wider rim, the grain, more lumps over each
    other), and it is the facets 24 by 14 was chosen against. WHERE TWENTY-FOUR COMES FROM: the most a kind stands off its
    core -- congestus's core, five towers, six crown bumps and three shreds, fifteen -- and a skirt of nine under it.
  - Pictures: `godotgames-drafts/2026-09-14/cockpit-clouds`, `d2-before*` and `d2-after*` (3 km, 700 m, 300 m, inside, day
    and evening, both finishes, and `d2-before-after-*.png` side by side), `d2-after-each/sheet-fine.png` and
    `sheet-plain.png` (every cloud from 1100 m), `d2-after-evolve`. The double editor draws the fog clouds as the stock
    one does (`rebased-double`).
- **LOW MIST AT EVERY TIME OF DAY, AS THE DEPTH FOG, LYING ON WHAT IS UNDER THE EYE, ON BOTH FINISHES** (asked for on
  2026-09-14: mist at all times of day, day included, following "ground and water height from a query"). Each time of day
  names three numbers in `DaylightTuning`: `mist_density` with the eye low over the surface, `mist_above` once it is
  `mist_top` over it, and the eye's height between eases from one to the other (`Daylight.mist_at`). Day 0.00045 / 0.00016
  / 800 m, evening 0.0005 / 0.0003 / 300 m, night 0.0005 / 0.00025 / 250 m; the scene's own 0.00016, at every height and
  time, is day's `mist_above`. `FlightLevel` hands `Daylight.show_eye_height` the viewport camera's height over
  `Terrain.surface_height` once a frame, and Daylight writes the fog only when the mist has moved by `MIST_STEP` 2 % of what
  it last wrote, so `tests/scenery.gd`'s sixty still frames still count 0 writes. `Terrain.surface_height` is the seam: the
  slab's top over the island and `SEA_LEVEL` off it today, and `GroundField`'s height and water once the game stands on it
  (nothing in the game asks it yet). Being the depth fog, it grows with distance: from a standing pilot's eye the grass is
  as it was and the far peaks and towers go soft (`godotgames-drafts/2026-09-14/cockpit-clouds/p2e2-mist`,
  `p2e2-mist-tuned`). `tests/air.gd` holds the depth fog, through the level's own `choose_time` and camera, to each time's
  `mist_density` two metres over the surface and its `mist_above` three `mist_top`s up, and day's mist to be thicker than
  its clear air. RED with Daylight writing the scene's number: evening low 0.00016 against 0.00060, day low 0.00016 against
  0.00045. The whiteout test now takes its clear fog two kilometres up, where it compares it.
  - Tuned by looking: day's `mist_top` 800 m, not 400, because at 400 the fields from `runway_base`, 300 m up, were nearly as
    clear as before (863,872 pixels moved between the two). The clouds view stands 1,080 m up, past it either way, and sees
    no day mist; the mountains view at evening stands 360 m up, past evening's 300 m, and draws its `mist_above`. Evening's
    0.0005 is the density chosen in the first evening trial (`p2e-haze-trial`: at 0.001 the island from 300 m up was mostly
    gone).
  - No new render work: the depth fog was already on, and only its density changes. On the CPU, one call and one
    `Terrain.surface_height` a frame, and a write only when the mist has moved by 2 %.
  - The night gates (`--parade`, both finishes) pass on `grass`, `runway_base` and `town_approach` with the mist: aircraft
    contrast 7.93 / 8.76, 3.17 / 3.75, 4.52 / 5.21 (PLAIN / FINE). `traffic` misses its 3.0 with or without it (2.42 /
    2.79 on this tree with no mist; 2.50 / 2.75 earlier with neither fog clouds nor cirrus), so that miss is not the clouds'
    and is not traced here.
  - REJECTED, BY LOOKING (`p2e-mist-trial`): Godot's height fog, whose amount is `1 - exp(min(0, (y - fog_height) *
    fog_height_density))` (`scene_forward_clustered.glsl`) with no distance in it, greyed the grass at the eye's feet at a
    top of 120 m and 0.0035; and FogMaterial boxes over the low ground on FINE, lit into a flat orange sheet with a hard top
    at every density from 0.002, one to three of the 1024 density steps the engine packs, and running the froxels whenever
    the eye is low.
- **CIRRUS, IN FINE'S SKY.** FINE wears `world/shaders/sky_fine.gdshader` in place of the ProceduralSkyMaterial PLAIN kept
  until the moon (PLAIN wears `world/shaders/sky_plain.gdshader` since 2026-09-15; see "The moon"):
  Godot's procedural sky copied line for line from `ProceduralSkyMaterial::_update_shader` (`sky_material.cpp`, 4.7), with the
  uniforms its setters write -- `inv_sky_curve` 0.6 / 0.15, `inv_ground_curve` 0.6 / 0.02, `sun_angle_max` cos 30 degrees,
  `inv_sun_curve` 1.6 / pow(0.15, 1.4) -- and a sheet of cirrus 9 km up in its half-resolution pass (`render_mode
  use_half_res_pass`): where the eye's ray meets the sheet, warped value noise drawn long along `CloudTuning.CIRRUS_HEADING`,
  each streak bent sideways and broken along its length, faded out along the ray by 60 km, lit by LIGHT0 (the sun, or the
  moon) and the horizon's colour. No TIME -- there is no wind, and TIME redraws the sky's cubemap every frame -- and none in
  the cubemap pass, so the light the sky throws is the sky's without it. `Daylight` makes the material
  (`Daylight.fine_sky_material`, `CloudTuning.CIRRUS_*`) and writes the same four colours to both skies on every change; the
  level puts one or the other on the environment in `_wear_the_finish`, and `finish_worn["sky"]` reads which is on.
  `--cirrus=off` keeps PLAIN's sky on FINE, to time against. `tests/scenery.gd`'s held-still snapshot of the sky reads the
  FINE sky's shader parameters now; it cast the sky to ProceduralSkyMaterial and would have held nulls still.
  `tests/scenery.gd`'s every-surface check holds the swap: RED, the level always putting PLAIN's sky on, `"sky": false`
  on FINE, before and after a second press of the key.
  - FOUND BY LOOKING: the first streaks, 8 km across at 0.00012 cycles a metre, were one soft smear in any frame, and every
    probe view looks near the horizon where the sheet fades -- the sky from the clouds, sea and mountains views was the same
    with it and without. `tests/scenery_shot.gd` gained `cirrus`, 300 m over the runway looking 50 degrees up; at 0.0006
    and eight times as long as wide the streaks were straight bands the length of the sky, like searchlights; bent and broken
    (`world/shaders/sky_fine.gdshader`) and five times as long, they read as wisps by day, faint and warm at evening, faint
    and moonlit at night (`godotgames-drafts/2026-09-14/cockpit-clouds/p2d-cirrus3`). Evening's is barely there.
  - THE DOUBLE EDITOR DRAWS IT AS STOCK DOES, NEAR THE ORIGIN. The sheet is placed from the sky shader's `POSITION`, the
    camera, and a scene's eye built-in is minus the camera on a double build (`working_with_godot.md`), so it was looked at:
    `cirrus`, FINE, stock against the double editor (`godotgames-drafts/2026-09-14/cockpit-clouds/p2d-reapplied`), 17 of
    1,440,000 pixels moved by more than 4 of 255 by day (at most 14), none at evening, 2 at night. That pose is 300 m over
    the runway; nothing has looked at the sheet from tens of kilometres out.
  - WHAT IT COSTS: Stock 4.7.2, Forward+, d3d12, 1600x900 at 3D scale 1.40, FINE with PLAIN's sky
    (`--cirrus=off`, A) and with the cirrus sky (B) interleaved A B A B, 240 frames, `--hold-fires`, with other lanes' work on
    the machine: GPU timer medians +0.022 ms on the clouds view (0.486 to 0.508), +0.024 on the sea view (0.402 to 0.426) and
    +0.030 looking up at it (`cirrus`, 0.261 to 0.291), both rounds agreeing to 0.003; CPU medians inside their own spread.
- **NOT BUILT:** mist as a layer with a top you can fly over, or pooled in valleys and over lakes (the
  depth fog has no place in it); cloud bases and thermal tops set from the mountains (terrain's recommendation, for after
  this); and any look in a headset.

### A cloud is lit as a volume: the sun through its own envelope

Asked for on 2026-09-15: "increase the volumetrics of the clouds". The survey before it (`godotgames-drafts/2026-09-15/cockpit-mist/survey`,
`cumulus_side` and `clouds`) drew a day cumulus as white spheres whose side turned from the sun was nearly as bright as the side
facing it: `cloud_light` knew a lump's facing and its height in the cloud, and nothing about how much cloud stood between it and
the sun.

- **EACH CLOUD HAS AN ENVELOPE**, `LiftYard.cloud_envelope(lumps)`: the axis-aligned ellipsoid of the same mass and spread as its
  lumps -- each lump weighed by its volume, with its centre and its own spread along each world axis; the radii come back from
  the spread (a solid ellipsoid's is a fifth of its half-width squared), at least `CloudTuning.ENVELOPE_LEAST`. Static and pure,
  like `cloud_lumps`.
- **ONE LIGHT, THREE CALLERS.** `world/shaders/cloud_light.gdshaderinc` takes `sun_depth`, the metres of envelope between a point
  and the sun (a ray against the ellipsoid, `envelope_sun_depth`), and `buried`, how deep inside it the point is:
  - the sun a point gets is Beer's law with a floor for light scattered many times, `max(exp(-d k), SCATTER_FLOOR exp(-d k
    SCATTER_REACH))` with `k` = `SUN_EXTINCTION` (1/300 m), so a far side and a core are dim and never black;
  - the sky's light falls to `CORE_SHADE` on a surface buried in the envelope: the crevices between towers;
  - a thin rim on the side turned from the sun passes `TRANSLUCENT` of the sun that reaches it, and the silver lining is kept to
    the outer lumps.

  PLAIN works it once a vertex, FINE once a pixel, the fog clouds once a froxel (`cumulus_fog.gdshaderinc`, the envelope as two
  uniforms from `CloudBank._paint`), so the mesh-to-fog fade is still one colour. `LiftYard.cloud_colour`, the whiteout's colour,
  mirrors it half-way into a middle cloud. Every share is `LiftYard.cloud_light_shares`, written onto all three materials.
- **A LUMP FINDS ITS CLOUD BY ITS PLACE IN THE BATCH.** `world/shaders/cloud_envelopes.gdshaderinc` is two `vec4[64]` arrays and
  `lumps_a_cloud`; a lump's cloud is `INSTANCE_ID / lumps_a_cloud`, looked up in the vertex stage (INSTANCE_ID is not a fragment
  built-in) and handed to the fragment flat. REJECTED: the instance colour, which arrives as COLOR, eight bits a channel clamped
  to 0..1 by the spatial shader reference, where a centre is kilometres. `CloudTuning.MOST_CLOUDS` is the arrays' length; a sky
  past it is warned of and its extra clouds are lit as shells. The arrays are written whole on every rebuild, padded, so a cloud
  past the list reads nothing rather than the last rebuild's envelope.
- **WHAT HOLDS IT** (`tests/air.gd`, `_every_cloud_is_lit_through_its_own_envelope`): every cloud's envelope holds its core lump
  and reaches no further than its box; the lumps' arrays at each cloud's place in the batch and each fog cloud's uniforms are
  `cloud_envelope` of that cloud's lumps; the shader's array is `MOST_CLOUDS` long and the island's 20 clouds fit; and at every
  time of day, for every cloud, a point on the sunward side of the envelope keeps more sun than its middle, and its middle more
  than the far side. RED, each restored by SHA-256: `envelope_sun_depth` returning 0, 60 of 60 wrong ("sunward 1.00, middle 1.00,
  far side 1.00"); the envelopes padded to nothing, "20 of 20 clouds' lumps with another envelope".
- **WHAT IT LOOKS LIKE, MEASURED.** `--still`, double editor, 1600x900 at 3D scale 1.40; the cloud's pixels against a
  `--clouds=none` picture of the same pose, and the darkest tenth of their luminance over the brightest (the modelling measure
  the clouds lane used):

  | view | before | after |
  |---|---|---|
  | clouds, PLAIN day / FINE day | 0.726 / 0.725 | 0.674 / 0.686 |
  | clouds, PLAIN evening | 0.785 | 0.712 |
  | cumulus_side, PLAIN day / FINE day | 0.682 / 0.683 | 0.629 / 0.622 |
  | cumulus_side, PLAIN evening / FINE evening | 0.742 / 0.649 | 0.609 / 0.440 |
  | cloud_at_150 (fog), FINE day | 0.693 | 0.561 |

  The brightest tenth moves by a few steps, so crowns keep their white; lee sides, bases and crevices darken, and a day cloud's
  mean luminance falls from about 194 to 171. THE FADE STILL MATCHES: mesh at 550 m against fog at 150 m, luminance 171.7 against
  168.6 by day (193.9 against 194.6 before), 172.2 against 167.2 at evening (183.5 / 182.2), 14.9 against 16.7 at night
  (17.6 / 19.3). Pictures: `godotgames-drafts/2026-09-15/cockpit-mist/step1-fade/after2` against `before`.
- **TUNED BY LOOKING, AND NOT ALL FIXED.** `SCATTER_FLOOR` 0.45, not 0.35: at 0.35 the lower lumps of the clouds view's cloud from
  150 m by day were slate blue beside a white fog flank (`step1-fade/after`, darkest tenth 123 of 255). At 0.45 it is 127, and
  those near mesh lumps still read harder and bluer than the soft fog next to them; the blue is the sky's light filling the shade.
  At dusk from 2 km (`cumulus_side`, FINE evening) most of a cloud is on its shaded side, which is what a 7-degree sun does.
- **WHAT IT COSTS: +0.02 MS GPU ON PLAIN, UNDER +0.01 ON FINE.** Double editor, d3d12, 1600x900 at 3D scale 1.40, main (A) and
  this (B) interleaved A B A B, 240 frames, `--hold-fires`, WITH cockpit-moon, cockpit-townlights and cockpit-terrain running
  Godot beside it, so only B minus A is read (means of the two rounds): PLAIN clouds +0.016 by day and at evening, cumulus_side
  +0.022 / +0.004, mist_city +0.023 / +0.027, cloud_at_250 +0.010 / -0.003, inside (`cloud_at_-40`) +0.001 / +0.010; FINE +0.000
  to +0.007 on every view. A's own two rounds differ by up to 0.014 on PLAIN, but PLAIN rises on every view: the vertex work of
  480 lumps is not it, and the likelier cost is the two 64-entry arrays in the material's uniform buffer; not traced. Draw calls
  and primitives identical. A headset draws both eyes through one multiview pass, so PLAIN's vertex cost is paid once a view,
  twice in all.
- **A CLOUD'S EDGE IS A BLENDED FALLOFF, NOT A STIPPLE** (team-lead, 2026-09-15, off the survey's `cumulus_side`: "coarse
  salt-and-pepper stipple several pixels deep. In VR that will crawl and differ between eyes"). Both finishes' rims were
  `ALPHA_SCISSOR_THRESHOLD` against a hash of the lump's cells, so every pixel of the outer band was drawn or not. Now each
  finish draws a lump in TWO PASSES from one include (`world/shaders/cumulus_lump.gdshaderinc`, `cumulus_plain_lump.gdshaderinc`):
  the CORE opaque, cut where a smooth coverage falls under `CORE_COVERAGE` (0.35, see below), and the RIM (`cumulus_rim.gdshader`,
  `cumulus_plain_rim.gdshader`, `#define RIM_PASS`) blended with no depth, from nothing at the silhouette to whole where the core
  begins, hung on the core's material as its `next_pass` by `LiftYard._cloud_paint` and lit with every number the core is
  (`LiftYard._paints`).
  - WHY A BATCH OF UNSORTED LUMPS CAN BLEND: a rim is low alpha over cores of nearly its own colour, so the order two rims blend
    in does not show, and every rim is depth-tested against the cores in front of it. Core and rim meet where the coverage is
    the core's cut and the rim's alpha is 1 there, so there is no seam.
  - THE COVERAGE IS SMOOTH AND IN THE WORLD. FINE's is the facing eaten by world-space value noise, given way to the fog in soft
    clumps at fixed frequencies in the lump's frame (the old clumps' frequency stepped by powers of two with range, which a
    stipple hid and a smooth edge would show as a pop). PLAIN's is the facing, WORKED OUT ONCE A PIXEL: once a vertex, the
    falloff ran straight across each triangle of the 12 by 8 sphere and a lump's outline read as its facets (`step1-rim/after`,
    `before-over-after-clouds-plain-day-crop.png`), which the stipple had hidden. PLAIN's light is still once a vertex.
  - REJECTED: alpha to coverage (FINE's two samples give three levels, a coarser stipple); FRAGCOORD dither and the engine's
    alpha hash (a pattern per pixel of each eye).
  - WHAT HOLDS IT (`tests/air.gd`, `_every_clouds_edge_is_a_falloff_and_not_a_stipple`): both finishes' materials have their rim
    pass, lit as their core (sun, sky, shade, envelopes, extinction), and no lump include cuts its coverage against a hash or
    FRAGCOORD -- read from the code, not its comments: the first run of the check read the include's own note about the stipple
    it replaced. RED, restored by SHA-256: the rim pass not hung on, "plain has no rim pass", "fine has no rim pass".
  - PLAIN'S LUMP IS A 24 BY 12 SPHERE, not 12 by 8. With the rim blended, the outline is the mesh's own polygon: along an edge
    between two silhouette vertices the interpolated normal never turns edge-on, so the rim's alpha never reaches nothing there,
    and working the facing out once a pixel did not change it -- a lump overhead read as a faceted ellipsoid, which the stipple
    had hidden (`godotgames-drafts/2026-09-15/cockpit-mist/step1-final/before-over-after-clouds-plain-day-crop.png`). At 24 by 12
    the outline is round (`before-over-after2-clouds-plain-day-crop.png`).
  - LOOKED AT, 1:1, on main's sky_plain and stars (`step1-final`): no stipple on either finish; FINE's edge soft and torn; at
    night no star shows through a cloud or its rim (`after/cumulus_side-plain-night.png`); a fly-in (`after-fly`) shows no speckle
    through the fade.
  - SEEN FROM ABOVE, A LUMP'S EDGE IS A DARKER BAND A FEW PIXELS WIDE WITH A THIN LIGHT LIP OUTSIDE IT
    (`step1-final/glassrim-zoom4-cumulus_side-plain-day.png`, four times). Team-lead read it as a bright glass rim, the kind of
    sub-pixel edge that aliases between the eyes. TRIED AND REVERTED: fading the lining and the thin edge's light by the rim's own
    alpha, so they fall to nothing where the rim does (FINE's thin factor times the rim's alpha; PLAIN's thin-edge light carried
    apart once a vertex and added back once a pixel). The before and after crops match
    (`glassrim-before-over-after-cumulus_side-*-day-crop.png`), so that light was never the line. The likelier cause is the split
    itself: the rim's colour blended over the darker ground behind it, inside the core's hard cut; see the next two bullets.
  - THE EDGE IS FILTERED OVER THE PIXEL, AND THE CORE CUT LOWER (team-lead off `glassrim-zoom4`, 2026-09-15: stair-steps on the
    core's hard cut along a lump's top edge, which would crawl in a headset; PLAIN, a headset's default, has no MSAA).
    `world/shaders/cloud_rim.gdshaderinc`, both finishes, both passes: the rim's alpha is its ramp clamp(coverage / `CORE_COVERAGE`)
    AVERAGED OVER THE PIXEL -- coverage plus and minus half its `fwidth`, exact for a linear ramp -- and the core is cut at
    `CORE_COVERAGE` plus half the `fwidth`, so it starts only where the whole pixel is past the cut and the rim under it is whole.
    Where the ramp is many pixels wide that is the ramp; where it is narrower than one, the pixel gets its share. `CORE_COVERAGE`
    0.35 and the coverage's ramp `RIM_RAMP` 0.8 (0.5 and 0.55 before), so the rim spreads over more pixels; the light keeps its
    own 0.55 lining. `tests/air.gd` fails unless both lump includes filter the edge (RED, restored by SHA-256: PLAIN's rim alpha as the bare ramp, "cumulus_plain_lump.gdshaderinc").
    - REJECTED: alpha to coverage on FINE's core (`alpha_to_coverage` with `ALPHA_ANTIALIASING_EDGE`). The engine still discards
      under the scissor and feathers at the scissor plus the edge (scene_forward_clustered.glsl), which works; but with the core
      cut where the rim is already whole there is no contrast left for it, and it would have kept FINE on another path than the
      headset's PLAIN, where it does nothing.
  - NOT FIXED BY THAT: THE STAIR-STEPS ARE THE MESH'S OWN SILHOUETTE. The before and after crops, placed where they differ most
    (`step1-rim3/rim3-plain-day-crops.png`, `rim3-fine-day-crops.png`, four times, main 7c28a961 against the lane), look nearly the
    same: along an edge between two silhouette vertices the interpolated normal never turns edge-on, so the rim's alpha is still
    0.1 to 0.3 where the triangle ends, and past the triangle there is no fragment to filter -- the same thing that showed the
    12 by 8 sphere's facets. Seen from above, the "darker band with a light lip" (`glassrim-zoom4`) is the same edge: the rim's
    colour over the darker ground, ending on a polygon. THE NEXT STEP, decided by team-lead after the mist: the rim pass drawn a
    few percent larger than the lump, its alpha from the eye ray's closest approach to the lump's true sphere worked out once a
    pixel, so it reaches nothing at the true silhouette, inside the drawn mesh; under the flat base the facing as now; the extra
    overdraw timed.
  - THE FADE STILL MATCHES: mesh at 550 m against fog at 150 m, luminance 173.6 against 170.0 by day, 172.4 against 167.6 at
    evening, 15.3 against 16.9 at night (`step1-final/after` against `after-none`).
  - WHAT IT COSTS, the rims and PLAIN's rounder sphere together, against the envelope lighting alone: double editor, 1600x900 at
    3D scale 1.40, the lane (B) against 83758d6a (A) interleaved A B A B, 240 frames, `--hold-fires`, no other lane's windowed
    Godot running (logged per launch); A's rounds agree to 0.009 ms, B's to 0.006; GPU timer medians, B minus A, day / evening:

    | view | PLAIN | FINE |
    |---|---|---|
    | clouds | +0.030 / +0.037 | +0.047 / +0.048 |
    | cumulus_side | +0.028 / +0.048 | +0.037 / +0.044 |
    | cloud_at_250 (in the fade) | +0.029 / +0.030 | +0.048 / +0.048 |
    | inside (`cloud_at_-40`) | +0.031 / +0.028 | +0.047 / +0.047 |
    | mist_city | +0.076 / +0.077 | +0.029 / +0.027 |

    One draw call more a finish. PLAIN's sphere is most of PLAIN's share: +495,360 primitives on the clouds view (563,125 to
    1,058,485), two passes of a sphere with four times the triangles, and mist_city, with many small far clouds in frame, pays most.
    NEXT, NOT DONE: a coarser PLAIN lump past a few kilometres (team-lead). Every cloud's lumps are one MultiMesh, and the
    envelopes (INSTANCE_ID over the lumps a cloud) and the fog dissolve (`show_fog_share`) find a cloud by its place in that batch,
    while a visibility range acts on the whole node; so it is per-cloud nodes or a re-sorted batch, each with its own A/B. A single
    18 by 10 sphere for every lump is the short alternative, with crops to see whether the near facets come back.
- **NOT DONE:** a powder term in the Horizon sense (it darkens the near surface of a sample INSIDE a volume, which a lit surface is
  not); an envelope turned along the cloud's heading (a long cloud at 45 degrees gets a fatter envelope than its shape); shade from
  one lump onto the next.

### Low mist lies in the world: ground haze and low stratus over the ground under them

Asked for on 2026-09-15: "make sure that we have near-ground mist or low clouds that is thinner and creates more atmosphere", and
mid-way, "some volume to the mist would be nice, but nothing compared to the clouds". The survey before it
(`godotgames-drafts/2026-09-15/cockpit-mist/survey`) found the mist was the environment's depth fog with its density eased by the
EYE's height: one wall -- the same over a city, a valley and open ground, with no top to see from above, and at night fog so dark
there was no mist at all.

- **THE DEPTH FOG IS CLEAR AIR NOW.** `DaylightTuning`'s `mist_density`, `mist_above` and `mist_top` became one `clear_air` a time
  of day (0.00016 day, 0.00018 evening, 0.00015 night), written at every height; `Daylight.mist_at` and `show_eye_height` are gone,
  and so is the level's call. The whiteout still lerps it to `CloudTuning.WHITEOUT_DENSITY`. `tests/air.gd` holds the depth fog to
  `clear_air` two metres and 900 m over the ground at every time. `tests/town_lights_shot.gd --fog-check` takes night's clear air
  and the fog a hundredth into a whiteout as its two densities (it took the eye-height pair).
- **THE MIST IS A PASS** (`world/shaders/mist.gdshader`, `MistLayer`): one quad in clip space over the whole view, drawn after
  everything opaque and FIRST among the see-through things (`Material.RENDER_PRIORITY_MIN`), which rebuilds each pixel's surface
  from the depth buffer through the view's own inverse projection and VIEW_MATRIX (never INV_VIEW_MATRIX, which the double build
  overwrites) and takes away and puts back what `mist_along` says lies between the eye and it. Both finishes: a headset starts PLAIN.
  `--mist=off` builds none; `--mist-steps=N` holds both finishes to N steps, for the probe.
- **WHAT THE MIST IS** (`world/shaders/mist.gdshaderinc`, every number in `world/mist_tuning.gd`): extinction per metre as bands over
  the ground under each point -- GROUND HAZE, densest at the ground and falling by e every `haze_height`, broken up by world noise;
  LOW STRATUS, a Gaussian band over the ground in noise patches, its top lit `STRATUS_MODELLING` brighter than its underside (the
  little volume), faded out past `STRATUS_REACH` along the ray. TWO CAPS: a ray takes mist no further than `REACH` (14 km; the sky is a ray
  that long, not 40 km), and no more than `STRATUS_MOST_TAU` optical depth from the stratus -- the band seen edge-on from near its
  own height runs kilometres inside it and was an opaque line along the horizon whatever its density; capping what one ray may
  take kept the patches seen from above and below as they were. Coloured by the time of day's mist colour and a glow toward the sun.
  ANALYTIC IN HEIGHT: along a straight ray height is linear, so the exponential's integral is exact and the band's is an erf; only
  the ground and the noise are taken once a step, where their band matters on it (the haze at the step's lowest point, the stratus
  where the ray is nearest the band's middle), so a patch crossed from above stands still in the world as the eye moves. Nothing
  is dithered or jittered.
- **THE GROUND UNDER IT IS ASKED, NEVER TYPED** (`MistChart`): a 128-texel float chart of the ground over 16,384 m round the eye,
  snapped to 4,096 m, baked through `Terrain.surface_heights` (cockpit-terrain's bulk form of `surface_height`: texel centres,
  rows along z, one call to the generated ground rather than one a texel) on a `WorkerThreadPool` task that writes only into a Dictionary made for it, and
  uploaded when finished; `MistLayer.bake_now` waits for one as the level loads. The island is the slab today, so the chart is
  flat; `GroundField` answers through the same seam when the level stands on it.
- **ITS NUMBERS ARE GLOBAL SHADER UNIFORMS** (`project.godot` `[shader_globals]`, `mist_*`), written by `MistLayer` through
  RenderingServer once per change and recorded for the tests (`writes`, `mist_written`); a sampler global takes the texture's RID.
  When the layer leaves the tree its densities go to 0, so a level with no mist never wears the last one's.
  THE MIST'S TIME IS ITS OWN CLOCK, `mist_clock`, written once a frame by `MistLayer` and not counted in its writes; every call
  hands it, never TIME. Handing the lamps' mist TIME turned `tests/night_lights.gd` red on main (the lamps flash from the tick
  alone, and TIME is each machine's own time since start), which a targeted gate without night_lights did not run;
  `tests/lint.gd` fails on any mist call that reads TIME.
- **EVERY SEE-THROUGH THING MISTS ITSELF THE SAME WAY** (team-lead: "the shared include is a contract for every transparent
  shader"). Drawn after the pass, a blended thing would otherwise be laid over the mist unmisted. Each takes `mist_along` once a
  vertex at its own place in the world: a blended one mixes toward the mist's colour, an additive one is dimmed by what the mist
  takes, and a lit blended one (the smoke) darkens its albedo and carries the mist in EMISSION so the sun does not light the mist
  twice. Contrails (both), wisps, FINE fire (flame, ember, smoke), the heavy bursts' fire and smoke (four), missile motors (two),
  the FINE lights' halo (its core is opaque, and misted by the pass), the clouds' rims, the town's far lights (one line after
  `scene_fog_transmission`, as agreed with cockpit-townlights) and cockpit-streetlights' lamps (`lamp.gdshaderinc`, the same
  line, the lamp's place from the eye and the view's rotation). PLAIN FIRE was a StandardMaterial3D, which cannot include a shader;
  it is `world/shaders/fire_plain.gdshaderinc` now, tinted by `FireYard._tint` only on a change as before.
  - `tests/lint.gd` holds it: every spatial shader with a blend mode or `depth_draw_never`, or ALPHA with no scissor, includes
    `mist.gdshaderinc` (itself or through an include) or is in `MIST_EXEMPT` with a reason; every script or scene that makes a
    see-through StandardMaterial3D is in `MIST_EXEMPT_MATERIALS` with a reason (markers meant to be found through haze, lights,
    things at arm's length). RED, each restored by SHA-256: contrail.gdshader without its mist sample, and a stray see-through
    StandardMaterial3D in a script not on the list.
  - THE INCLUDE'S LOCALS ARE ALL `m_`-PREFIXED: a host shader's varyings and uniforms share its scope, and the first version
    redefined beacon.gdshaderinc's `lit` -- SHADER ERROR, the runway lights not drawn, and every suite still RESULT=PASS. The
    headless suites that build the level compile nearly every shader; a SHADER ERROR on their stderr is a failure now.
  - The include has its own noise (`mist_noise`, wrapped every 128 cells by the terrain's rule) because terrain_noise.gdshaderinc
    has no include guard and half the shaders that must include this include that already.
- **ITS COLOUR IS THE HORIZON SKY'S, AND THE STRATUS IS LIT FROM THE SIDE THE EYE IS ON.** `mist_colour` is `DaylightTuning`'s
  `sky_horizon`, never typed: night's own (0.10, 0.12, 0.17) was forty times the night sky, and a patch overhead taking a tenth
  of the light lifted the whole sky from 0.03 to 0.15 (step2-try5, mist_under-plain-night). A layer seen from above shows its
  sunlit top, `STRATUS_MODELLING` brighter, with the glow toward the sun; from below its underside, as much darker, with no
  glow. NOT BY THE RAY'S MIDDLE: with one step that is kilometres above the band on a ray from the grass into the sky, and every
  patch overhead lit as its top drew bright arcs across the evening sky (step2-try6-stratus, grass-fine-evening).
  - AT NIGHT UNDER A PATCH the sky is still brighter than with no mist: 1.9 to 2.5 times on FINE and 2.3 to 2.7 on PLAIN in linear light, about
    twice in sRGB (step2-try7 against step2-try5-nomist, mist_under; 3 to 4 times in try 6, when the underside was lit as the top).
    KEPT, by team-lead's decision. Moonlit thin cloud reads lighter than the stars behind it. Capping the light the mist puts
    back at the horizon's colour plus the moon's own term changes nothing, because the underside is already under it; the
    lift is a tenth of the horizon's colour over a zenith six times darker.
- **NO SUN GLOW ON THE STRATUS**, only its modelling: a patch near level is a sliver, and lit by the glow toward the low sun
  every sliver was a white line, which the near patches kept for `mist_low` brought back (step2-try9-stratus, fields and
  mist_low at evening). The haze keeps the glow, 0.35 at evening as by day. AND NEVER BRIGHTER THAN THE HORIZON SKY: the top
  is the mist's own colour and the underside darker by `STRATUS_MODELLING`; lit a quarter brighter, a patch near level from
  40 m over its band was still a white sliver brighter than the sky behind it (step2-try10-stratus, fields-fine-evening).
- **NOT KEPT WHOLE FROM JUST BENEATH THE BAND** (step 2b): the near-patch exemption is dropped when the eye is under the band's
  middle, ramped over one band width. Seen from 40 m under the band a patch over a town at night was a pale lens, lighter than
  the sky (cockpit-streetlights' step2c above/town-plain-night-clear-01km; `mist_lens` in tests/scenery_shot.gd, the same pose,
  shows none now, whole and stratus alone). By side, not by distance: `mist_low`, 30 m OVER the band, is nearer its middle than
  the lens pose and keeps its patch; a deck overhead seen at 20 degrees keeps its ceiling through the angle fade (`mist_deck`).
- **NOTHING READ THAT THE FADES OR THE GROUND DO NOT NEED** (step 2b): no chart fetch on flat ground, and no stratus noise or erf
  on a ray both stratus fades leave under a thousandth. The look is the same. NOT PRICED: the quiet-slot run was void (a game on
  the GPU); they are to be timed with step 2c. Two pricing probes stay, never a level's: `--mist-part=none` (the pass drawing
  nothing) and `--mist-pass=fill` (tests/mist_fill_probe.gdshader, the quad with no depth read).
- **NO WHITE LINE ALONG THE HORIZON: THREE CAUSES, SEPARATED BY PICTURES** of mist_city and fields at evening with
  `--mist-part=haze`, `--mist-part=stratus` and `--mist=off`, and on main (step2-try6-look, step2-try7-look). None was the island's
  sea edge (no mist and main show no line). THE STRATUS SEEN EDGE-ON drew sharp lines a pixel or two tall through every peak's
  foot. It now fades along a ray from whole at 1.6 km to gone at 8 km (`STRATUS_REACH`, `M_STRATUS_NEAR`), and by the ray's angle
  from gone within 1.1 degrees of level to whole past 9.8 (`M_STRATUS_LEVEL`), where a band is squashed into slivers wherever
  it lies -- WEIGHED IN ONLY PAST 1.5 KM along the ray and whole past 3 (`M_STRATUS_LEVEL_FROM`; team-lead: flying low beside
  the band, a patch a kilometre off sits within a few degrees of level, and that low cloud round the eye is the atmosphere
  asked for; `mist_low`, the eye 30 m over the band a kilometre from a patch, holds it: the patch is there in step2-try9 and step2-try10). A NARROW FADE IS AN EDGE: at 0.6 to 3.4 degrees the slivers stayed (step2-try8-stratus), and a distance fade ending
  at 6.4 km drew an arc across the night sky under a patch (step2-try8, grass-plain-night), so both are long ramps.
  - NOT A THING THAT COMES AND GOES WITH A NOD (team-lead: "a patch that appears and disappears as you nod would be worse than
    a thin line"): both fades are in the world's directions, so only the eye's height and distance move them.
    HELD BY TWO SWEEPS in `tests/scenery_shot.gd`, each step's 5 by 5 pixels round one point in a patch printed as `[mist-sweep]`, against the same step with `--mist=off`
    (step2-sweep, evening and night, both finishes): `mist_nod`, the eye still and the head pitched from level to 5 degrees
    down with the patch 2.3 degrees under level, moves the mist's share by at most 0.004 to 0.010 a step over 10 steps
    (0.18 of it); `mist_climb`, the eye climbing from 10 to 160 m over the band 2 km off, brings the patch in from 0.05 to 0.23
    by evening and 0.07 to 0.18 at night, the most in one step 0.05 to 0.08, at the grazing end, with no pop. THE HAZE'S GLOW toward the low sun was
  brighter than the sky along the ground line: evening's `sun_glow` came down from 0.9.
- **HOW FAR YOU SEE** (to 5% transmission, a level ray over open ground at the noise's mean; the eye-height depth fog on main
  against clear air plus the mist, from the statics headless, 2026-09-15), because the user asked for "lighter, not too thick":

  | time | 2 m up | 60 m | 300 m |
  |---|---|---|---|
  | day | 6.7 km -> 10.7 -> 12.5 | 6.7 -> 15.8 -> 16.8 | 8.4 -> 18.7 -> 18.7 |
  | evening | 6.0 -> 9.3 -> 12.5 | 6.3 -> 12.8 -> 16.8 | 10.0 -> 16.6 -> 19.9 |
  | night | 6.0 -> 10.3 -> 12.5 | 6.5 -> 15.4 -> 17.0 | 12.0 -> 19.9 -> 19.9 |

  The middle column is step 2 as merged (d414da58), the last after team-lead's "at least 12 km at 2 m at evening, with
  thinner and thicker places": every haze density down, evening's clear air night's 0.00015, and the haze's breakup 0.9 over
  1,500 m rather than 0.6 over 600, so it lies in banks and gaps kilometres across rather than a fine mottle that averages to
  a film (step2b-try12-look: the evening fields and mist_city lighter, the towns' street lights showing through at
  3 km, the ground under the haze in slow banks rather than a flat grey-brown). Stratus patches take it down where they lie, which is the "not uniform".
- **WHAT A STEP COSTS, AND SO ONE AND FOUR** (double editor, 1600x900 at 3D scale 1.40, `--mist-steps=0..8`, two rounds agreeing to
  0.014 ms): the pass with no steps +0.06 ms GPU PLAIN and +0.10 to +0.13 FINE (the depth read and the blend, FINE's with its
  multisample resolve); every step about +0.045 more. At four and eight the first try cost +0.24 and +0.45 to +0.55. Both finishes
  take one step (the closed form over the whole ray: exact in height over flat ground, two noise taps); FINE also reads the
  stratus's second octave.
  - WHAT IT ALL COSTS -- the pass AND every see-through shader's own sample -- double editor, d3d12, 1600x900 at 3D scale 1.40
    (2240 by 1260, 2.82 M pixels, ONE view), `--mist=off` (A) against the mist (B) interleaved A B A B, 240 frames,
    `--hold-fires`, no other lane's windowed Godot running (logged per launch); A's rounds agree to 0.012 ms, B's to 0.011; GPU
    timer medians, B minus A, day / evening:

    | view | PLAIN, one step | FINE, four steps |
    |---|---|---|
    | mist_city (3 km from a city, 300 m up) | +0.092 / +0.105 | +0.196 / +0.224 |
    | mist_valley (600 m over a range) | +0.093 / +0.098 | +0.185 / +0.199 |
    | fields (260 m over the fields) | +0.126 / +0.136 | +0.221 / +0.242 |
    | grass (a pilot's eye on the grass) | +0.108 / +0.113 | +0.254 / +0.225 |
    | cumulus_side (2 km up) | +0.088 / +0.071 | +0.155 / +0.147 |

    FINE at one step (option 0: the closed form over the whole ray, two noise taps, no march -- team-lead's ask) and at two, one
    round each against the same A, by day: mist_city +0.108 and +0.141, mist_valley +0.117 and +0.142, fields +0.133 and +0.153
    -- against four steps' +0.196, +0.185 and +0.221. So a step past the first costs FINE about +0.03 each, and FINE at one step
    is about half its four. FINE SHIPS AT ONE STEP (`MistTuning.STEPS_FINE`), because one step looked the same as four in the evening valley, bar a little less
    breakup at the far edge (step2-try4-fine-one-step against step2-try4).
    These prices were taken before the stratus cap (one `min` a step) and the lighter presets, neither of which adds work.
  - PER EYE, ESTIMATED AND NOT MEASURED. The march is per pixel, so its cost scales with the pixels drawn. A headset draws each eye
    at `PilotRig.RENDER_SCALE` 1.4 times the runtime's suggested size on each axis; nothing in the repository records the
    suggestion for the user's headset. On an ASSUMED 2064 by 2208 (not read from the headset), an eye is 2890 by 3091, 8.9 M
    pixels, 3.2 times the view above: PLAIN about +0.3 ms an eye, +0.6 for both, against PLAIN's +0.5 for both; FINE about +0.7
    an eye. VRS_XR foveation (on for Forward+, `PilotRig`) shades the outer field coarsely and is not in that figure. If the
    headset confirms it, the next saving is the pass at half resolution with a depth-aware upsample.
- **IN A HEADSET, REASONED AND NOT YET SEEN.** Each eye's ray is rebuilt from that view's own projection and VIEW_MATRIX; the quad is
  placed in each view's clip space, so no near plane clips it; `hint_depth_texture` is the resolved depth, one sample a pixel; every
  noise is in the world, the ray starts at the midpoint of the eyes, and nothing reads the screen. A headset draws both eyes through
  one multiview pass, so the per-pixel march is paid for every pixel of both eyes at the headset's render target:
  `PilotRig.RENDER_SCALE` 1.4 on each axis of the runtime's suggested size.
  - **THE USER'S CHECK IN THE HEADSET** (V in the window, PLAIN): 300 m over the fields at evening, turn the head slowly left and
    right, then lean: the haze and any stratus patch must stay put in the world, the same in both eyes, with no crawling grain, no
    band that follows the head and no line where a plane cuts through. Then fly down into a patch and out: no pop.
- **WHAT HOLDS IT** (`tests/mist.gd`): the mist falls with height at every time (2 m over 60 m over three band-widths over the band,
  and next to nothing at the ceiling), there is mist at every time, day is thinner than the low sun; the chart is the ground it
  was handed (a slope, texel for texel); a new chart arrives when the eye flies off the old one, no frame of the layer waits for a
  300 ms bake, and it was baked off the main thread; the level's own `choose_time` puts each time's numbers in the globals and a
  still level writes none. RED, each restored by SHA-256: the haze not falling with height, and the ground chart typed as 0.
- **LOOKED AT** at 1600x900 on the double editor, both finishes, day, evening and night (godotgames-drafts/2026-09-15/cockpit-mist,
  `step2-try10` and `step2-try11`, with `-look` sheets beside each): by day soft patches lying over the island seen from 2 km up
  (`cumulus_side`) and a thin haze over the fields; at evening the valley's low ground under pale patches, the grass under a
  clean sky with a soft glow along the ground line, and a patch a kilometre off still there from 30 m over its band
  (`mist_low`); at night the towns' windows and red lamps through a thin blue haze, and stars dimmed, not cut, under a patch.
  NOT FIXED: from 40 m over the band (`fields`) patches between 1.5 and 3 km still read as faint light slivers along the
  horizon -- the near patches kept whole on purpose; and under a patch at night its edge is a lighter arc across the sky.
- **THE HALF-RESOLUTION COMPUTE MIST, LAID ON BY BLENDING, IS WHAT PLAIN DRAWS** (step 2c, team-lead's DECISIONS 2026-09-15:
  build it off the GPU-bound table; lay it on by blending after prototype (a); ON after one bracketed slot against the spatial
  pass; `MistTuning.COMPUTE_ON_PLAIN`). `world/mist_effect.gd`; `world/shaders/mist_half.glsl` works the mist out per texel of a
  half-sized image from mist_core; `world/shaders/mist_lay.glsl` lays it on with one procedural triangle a view, blended. FINE
  keeps the spatial pass. Built because at 3840x2141 x2.00 the spatial pass with nothing in it cost +0.61 to +0.83 ms -- the
  full-screen fill, the blend and the depth copy the engine makes for any transparent shader that reads `hint_depth_texture`.
  - WHEN IN THE FRAME: PRE_TRANSPARENT. servers/rendering/renderer_rd/forward_clustered/render_forward_clustered.cpp, _render_scene:
    opaque, POST_OPAQUE, the sky, the MSAA resolves, POST_SKY, the separate-specular merge, the screen-texture and depth-texture copies
    (each only if something needs it), PRE_TRANSPARENT, the transparent pass. At POST_OPAQUE the sky draws over the mist; at
    POST_SKY the specular merge lands on it.
  - NOT ON FINE: with MSAA the transparent pass draws into the multisample colour buffer and resolves it over the internal texture
    afterwards, over anything laid on the resolved one. PLAIN has no MSAA and a headset starts PLAIN (`Finish.HEADSET_DEFAULT`,
    `suit_the_display`); a player who chooses FINE gets the spatial pass. `MistLayer.computes` decides, by finish;
    `--mist-pass=spatial|compute|compute-half|compute-mask` holds it for the probes.
  - ONE COPY OF THE MATHS: `world/shaders/mist_core.gdshaderinc` holds every constant and function of `mist_along` and nothing else
    (no uniform, no include, no built-in), in the GLSL both languages accept; mist.gdshaderinc includes it after declaring the
    `mist_*` globals, and mist_half.glsl #defines the same names onto a uniform buffer `MistEffect.pack` fills. A compute file's
    #include is not followed inside an included file (rendering_device_binds.cpp), which is why the core includes nothing.
  - THE HALF PASS: per texel the nearest and farthest depth of its 2 by 2, each rebuilt at its own pixel, the mist worked out for
    each (the far one only where they differ by `COMPUTE_EDGE`), and an EDGE MASK -- two surfaces in the texel, or a neighbouring
    texel's 2 by 2 sky against surface or another surface by the edge share.
  - THE LAY-ON: blended src ONE, dst SRC_ALPHA, alpha untouched (colour * T + mist * a), one linear tap of the half mist a pixel,
    and the depth-weighted 2 by 2 (each tap's nearer or farther surface by depth likeness, bilinear, nearest in depth as the
    fallback) only where the mask is set. `draw_list_begin(framebuffer, DRAW_DEFAULT_ALL)`, which in 4.7.2 LOADS and STORES the
    colour; the triangle is procedural (`draw_list_draw(list, false, 1, 3)`, no vertex buffer). The enum names came from
    `_tools/godot-4.7.2-double/extension_api.json` when the web class page truncated them.
  - REJECTED, A COMPUTE STORE: the first lay-on, a full-resolution compute upsample (mist_up.glsl, removed), cost +1.03 to +1.07 ms
    at 4K whatever the mist held -- about thirteen texel fetches and an imageLoad/imageStore of RGBA16F on every pixel -- which
    left the whole compute mist at +1.21 to +1.36 against the spatial pass's +0.93 to +1.50, cheaper on two views of seven. Proved
    by a probe that ran the half pass and laid nothing on (`--mist-pass=compute-half`): its frames matched mist off but for
    see-through things' own per-vertex mist, where full compute differed on 39-99 % of pixels, and two mist-off launches were
    pixel-identical. The blended composite, priced the same way, is +0.23 to +0.32. A compute pass cannot blend.
  - THE EDGE MASK'S SHARE (`--mist-pass=compute-mask`, share of output pixels): town_street 9.1-9.2 %, mist_lens 10.1-10.3,
    mist_valley 11.1-12.0, mist_city 11.6-12.0, forest_low 12.7-13.1, grass 13.8-14.0.
  - FRAMEBUFFERS: one a colour texture, kept by the texture's RID; `MistEffect.framebuffers_to_let_go` names those no view drew into
    this frame and the callback frees them, because a resize, a finish change or a headset hands the views new textures
    (tests/mist.gd `and_a_resized_views_framebuffers_are_let_go`).
  - PER VIEW: each view's own inverse projection (`RenderSceneData.get_view_projection`, eye offset in, depth-corrected as the
    engine's own: render_scene_data_rd.cpp) and the centred camera, and its own framebuffer on that view's slice of the colour
    texture. `tests/mist.gd` holds the projections with two eyes (`and_each_eye_gets_its_own_projection`) and the packing against
    the shader's own Params order. BOTH VIEWS, DRAWN (tests/mist_multiview.gd, a probe): the watch level through a SubViewport
    with `use_xr`, fed by a scripted two-view XRInterfaceExtension with its eyes 40 m apart, converging at 3 km, normal and
    swapped. Compute against spatial, `mist_city`: normal eyes mean 0.03/255, p99 1, 12 pixels over 16/255 (0.002 %); swapped
    mean 0.01, p99 1, none over 16 -- while spatial with normal eyes against spatial with swapped differs on 97 % of pixels, mean
    7.44 -- so whichever eye the picture holds, the compute mist draws it as the spatial pass does. Run with OpenXR off by
    setting, not by flag: see the trap below.
  - THE DEPTH COPY STAYS GONE ON PLAIN: `tests/lint.gd` fails if any shader but `world/shaders/mist.gdshader` reads
    `hint_depth_texture` (`and_only_the_spatial_mist_reads_the_depth_texture`), because one that did would bring the copy back to
    every PLAIN frame.
  - EQUAL TO THE SPATIAL PASS, and the tolerance written before looking: on PLAIN at day, evening and night, compute against
    `--mist-pass=spatial` on mist_city, mist_valley, grass and mist_lens, away from edges (over 4 px from any edge of the no-mist
    picture) mean |difference| at most 1.0/255 and 99th percentile at most 3/255, a sky patch mean at most 2/255: 12 of 12 within,
    mean 0.02 to 0.04, p99 1, with the blend (godotgames-drafts/2026-09-15/cockpit-mist/build-look; equality_2c.py).
  - A LINE ALONG EVERY EDGE, AND ITS FIX: first try, a half texel kept only its nearest depth and was rebuilt at its 2 by 2's middle,
    so the far side of an edge took the near side's mist and a grazing horizon slid kilometres: a line a pixel or two tall along
    the grass's horizon, 824 to 1,372 pixels over 16/255 (step2c-look2 grass-maxima.png). Keeping the sky's own mist changed
    nothing (look3): the line was the near grass against the far sea, not the sky -- found by counting along an exact sky mask.
    Now each texel keeps its nearest and farthest depth, each rebuilt at its own pixel, and the upsample takes whichever matches:
    0, 54 (one row, at most 19) and 0 pixels over 16/255 on grass by day, evening and night.
  - ALONG EVERY DEPTH EDGE (`--mist-pass=edges`, tests/mist_edges_probe.gdshader), pixels over 16/255 within 2 px of one,
    day/evening/night: mist_city 14/0/0; mist_valley 0; grass 0/0/0; mist_lens 0; forest_low 0/0/0; town_street 1/0/0 -- the same
    with the blend as with the compute store. Texels holding two surfaces: 1.9 to 4.9 % of the picture on every view.
  - LOOKED AT, spatial beside compute: a tower's top, a peak and the runway gate's frame close in `mist_lens` show no halo
    (step2c-look2/edge-crops.png); the grass's horizon before and after (grass-maxima.png); the alpine over_town pose with the blend
    on PLAIN, band 1.08/255 as with the mist off (horizon-main048/alpine-build).
  - WHAT IT COSTS, BRACKETED AGAINST THE SPATIAL PASS IN ONE SLOT (t2c5, 2026-09-15 01:23-01:27): 7680x4282 (32.9 M px), PLAIN,
    day, 180 frames, seven views, off, spatial, off, compute, twice, every launch between mist-off launches that agreed within
    0.01-0.03 ms, the user's own apps a steady background, 9 of 9 launches kept (godotgames-drafts/2026-09-15/cockpit-mist/
    step2c-time5; time_2c2.py). GPU median ms over mist off, round 1 / round 2:

    | view | spatial | compute | saving |
    |---|---|---|---|
    | mist_city | +1.390 / +1.398 | +0.548 / +0.560 | -0.840 |
    | fields | +1.501 / +1.485 | +0.627 / +0.624 | -0.867 |
    | grass | +1.252 / +1.259 | +0.618 / +0.617 | -0.638 |
    | mist_valley | +1.152 / +1.160 | +0.531 / +0.538 | -0.621 |
    | cumulus_side | +0.922 / +0.927 | +0.460 / +0.458 | -0.465 |
    | forest_low | +1.231 / +1.235 | +0.614 / +0.612 | -0.620 |
    | town_street | +1.261 / +1.265 | +0.611 / +0.623 | -0.646 |

    Half the spatial pass's cost or less on every view. For a headset's two eyes at 17.8 M px, estimated by pixels: compute +0.34 ms
    against spatial +0.81, a saving of 0.25 to 0.47, under the +0.5 asked.
- **THE HAZE READS THE GROUND AT THREE PLACES A STEP, NOT ONE** (2026-09-15, off cockpit-terrain's B1 pictures;
  `world/shaders/mist_core.gdshaderinc`, `mist_along`). Each half of a step is integrated over the lower ground of its own two
  ends (the step's start, middle and end). Before, one ground a step was read where the step is lowest, and both finishes take
  ONE step: on a ray rising a hair to a peak that end is the eye (the valley's ground, little haze), on a ray falling a hair to
  it the peak (its own surface, thick haze). A hard line across every mountain at the eye's height: on the alpine world's
  over_town pose (eye (-13947, 935, 12220) looking north, tests/town_lights_shot.gd --world=alpine) the left mountain's rows
  stepped +41.8/255 at the horizon, BAND 37/255 off a straight line (horizon_jump.py; mist off 1.1). TRIED AND DROPPED: the end
  nearest its own ground (BAND 27) and each half over its own end's ground (BAND 13) -- a rising ray's start or middle then lies
  under the ground it was handed, `mist_exp_integral` takes it as full density there, and near level that is a soft band at the
  same height. Now BAND 1.1, the mist-off picture's own, on PLAIN and FINE; over flat ground the halves sum to the old integral
  exactly, and main's six mist views moved mean <= 0.30/255, p99 <= 5. COST: two more chart fetches, one more noise and one more
  exp integral a pixel. Not priced alone: the spatial pass with it cost +0.93 to +1.50 ms at 4K in the timing above, the whole mist
  without it +0.98 to +1.40 in a quiet slot of its own (45627150), and the compute mist's half pass, which holds every term of the
  maths, +0.17 to +0.28 -- the maths is not where the mist's cost is.
- **`--xr-mode off` ALSO TURNS OFF THE RENDERER'S MULTIVIEW SHADER VARIANTS, so no two-view render can be tested under it**
  (2026-09-15, step 2c's multiview check). tests/mist_multiview.gd, launched with `--xr-mode off` as every launch here is, drew
  nothing on the spatial pass or the compute mist: the SubViewport's picture pure black, and 92 each a run of "Attempted to use
  an unused shader variant (shader is null)" (pipeline_cache_rd.h:73), `!variants_enabled[p_variant]`, "This render pipeline
  requires (0) bytes of push constant data, supplied: (96)" and "No render pipeline was set before attempting to draw" -- with
  `xr/shaders/enabled=true` in project.godot. The same probe with OpenXR off BY SETTING instead drew both views: 0 of those
  errors, real pictures, and the eyes' pictures different.
  - SO A MULTIVIEW CHECK TURNS OPENXR OFF BY SETTING (team-lead, with guards): only in a scratch worktree; an `override.cfg`
    beside project.godot, git-ignored through .git/info/exclude, with `[xr] openxr/enabled=false` and `shaders/enabled=true`; the
    launch WITHOUT `--xr-mode off`; the first launch alone and stopped on any OpenXR instance or runtime line in its log (there
    were none in four); the process list logged before and after; no launch while the user's own Godot runs; the override
    deleted afterwards. Every other launch keeps `--xr-mode off`, headless included.
  - WHAT THE PROBE STILL GETS WRONG: with the eyes swapped, both passes print "Condition p_top <= p_bottom is true" 92 times --
    a frustum from the scripted interface, not the mist -- and its view count read 1 until MistEffect.views_drawn kept the most
    views of any frame rather than the last (the window draws after the headset's viewport). Rerun on that fix, one more guarded
    launch: views drawn 2, RESULT=PASS, 0 engine errors, 0 OpenXR lines.
- **A CHANGE TO mist_core.gdshaderinc IS NOT SEEN BY THE COMPUTE MIST UNTIL ITS SHADER IS REIMPORTED.** mist_half.glsl (like
  mist_lay.glsl) is an RDShaderFile, compiled on import; editing a file one #includes changes neither, so nothing reimports it and
  PLAIN keeps the old maths while FINE takes the new. Found folding the fix above into 2c: equality 11 of 12 and the alpine line
  still on PLAIN (step +23.9) but gone on FINE. `--import` after deleting only the .md5 stamps did not rebuild; deleting the
  compiled `.res` did. Folded in with the imports rebuilt, equality went back to 12 of 12 and the depth-edge counts fell (grass
  evening 54 to 0, forest_low evening 13 to 0).
  - SO THE COMPUTE SHADER CARRIES A STAMP (team-lead): `mist_half.glsl` says `// mist_core sha256: <hash>` just after
    `#version`, and `tests/lint.gd` `and_every_compute_shader_carries_the_hash_of_the_maths_it_includes` fails when any .glsl
    including mist_core says anything but the include's SHA-256 WITH CARRIAGE RETURNS STRIPPED (git checks it out CRLF here and
    LF on Linux, so a raw hash would match one kind of checkout). An edit to the maths is then an edit to the .glsl, which git
    carries, and every checkout's plain `--import` recompiles it. REJECTED: a test failing when mist_core is newer than the
    compiled shader -- a rebase over a mist_core change updates the include's time and never reimports the .glsl, so every
    other lane would go red until someone deleted .res files by hand. MUTANT: a comment appended to mist_core without bumping the
    stamp turns lint RESULT=FAIL on that check alone; put back byte for byte (SHA-256) it passes. A plain `--import`, nothing
    deleted, rebuilt mist_half.glsl's compiled shader after the stamp changed (00:05:08 to 00:15:49).
- **A TOWN WEARS A HAZE DOME, AND AT NIGHT IT GLOWS WITH ITS WINDOWS** (step 3, asked for on 2026-09-15: "especially around
  cities"; `world/shaders/mist_core.gdshaderinc` `mist_dome_tau`, `MistLayer.show_towns`, `MistTuning` DOME_* and TOWN_GLOW).
  Over each town `TownCatalogue.towns()` names -- never TOWNS: on the generated ground a town is seated where its site is -- extra
  haze, `dome_density` per metre at the town's ground (0.00020 by day, 0.00035 at evening, 0.00040 at night), falling by e every
  `DOME_HEIGHT` (80 m) and across `DOME_SPREAD` (1.4) radii as a Gaussian. At most `MOST_TOWNS` (8), the shader's `M_MOST_TOWNS`,
  held equal by tests/mist.gd.
  - HOW A RAY TAKES IT: for each town, the ray where it comes nearest the town's axis in plan, the Gaussian across it read there,
    and the height's fall integrated exactly along the stretch of the step that crosses the dome -- sqrt(pi) spreads over how
    level the ray is. A town more than three spreads from the ray is skipped.
  - THE GLOW IS THE WINDOWS' LIGHT: `MistLayer.town_glow` = TownTuning.PLAIN_WINDOW_LIGHT x DaylightTuning's windows_lit x
    window_glow (what TownView lights the windows by) x TOWN_GLOW (0.20), added in proportion to the dome's share of each step's
    haze. None by day (windows_lit 0). WINDOWS ONLY while TownTuning.STREET_LIGHTS_ON is false: a glow over dark streets would light
    a town the player sees unlit; the lamps' LIGHT_PER_CANDELA share joins when street lights are turned on (NOT HERE YET).
  - BOTH PASSES, ONE COPY: the spatial pass reads globals `mist_towns` (a texel a town: centre x, ground y, z, radius),
    `mist_town` (count, density, height, spread) and `mist_town_glow`; the compute half pass the same texture on binding 7 and
    `town`, `town_glow` in its Params (MistEffect packs 48 numbers now). The stamp in mist_half.glsl moved with mist_core
    (722e2d62...).
  - HELD (tests/mist.gd): the dome denser over a town than 5 km out and than 400 m up, at every time, AND mist_core's
    STRUCTURE: mist_dome_tau sums that term, assigns its sum nowhere else and returns it, and mist_along takes m_dome_tau from
    it alone and adds it to the extinction once (headless draws nothing, so the shader's side is held by its text); the
    glow the windows' colour, none by day, street lights off; the shader's M_MOST_TOWNS the layer's width; the packing in the
    shader's own field order; and through the level's `choose_time`, the glow written equal to what the TOWN'S OWN MATERIAL is
    lighting (TownView.windows_lit), never to `MistLayer.town_glow`, the function the level writes it with.
  - MUTANTS (team-lead, 2026-09-15; one headless mist suite each, bytes put back and matched by SHA-256, green after):
    - the dome zeroed where mist_along adds it; the add removed; `m_dome_tau` zeroed before an untouched add; the term zeroed
      inside `mist_dome_tau`'s sum; `mist_dome_tau` returning 0 -- each red on
      `and_the_domes_lie_over_the_towns_and_thin_with_height`.
      The first stayed GREEN while the check read only `dome_density_at`, the GDScript mirror; the zero-before-the-add and the
      zero-returned stayed GREEN against a bare substring of the shader, which is why the check holds its structure;
    - `windows_lit` taken out of `town_glow`, and the glow scaled by a constant 1.5 at night: each red on
      `and_the_level_puts_each_times_mist_on_the_material`. The first stayed GREEN while that check compared with `town_glow`
      itself. Day stays 0 through window_glow, so only the night's size shows it;
    - the glow a constant: red on `and_the_glow_is_the_windows_light_and_none_by_day`;
    - the layer writing 9 towns, and the shader's M_MOST_TOWNS at 7: each red on
      `and_the_shader_reads_as_many_towns_as_the_layer_writes`.
  - PROBE: `--mist-towns=off` hands no towns, for pictures and timing of what the domes add. Never a level's.
  - LOOKED AT (step3-look at TOWN_GLOW 0.06, 1600x900, day/evening/night over mist_city, town_street, grass and mist_valley,
    PLAIN and FINE; the glow moves only the night). From outside, the domes add a mean of 0.09-0.77/255 (p99 at most 18) to a
    view against `--mist-towns=off`. Standing in a street they add a light veil, mean 5-12 (p99 42 at evening). At night on FINE
    each town wears its own pale haze pooled round its lights, with open ground between -- not a sheet. The dark arc over the
    night grass is the deck's edge and predates this step.
  - THE GLOW'S STRENGTH, CHOSEN BY PICTURES (team-lead's bar: a soft warm glow from 5-10 km, windows not washed out). Six
    values, mist_city and town_street at night on PLAIN (step3-glow/compare-*.png). Mean R-B over the towns' band on mist_city,
    no towns -9.9: 0.02 -10.3, 0.06 -9.3, 0.15 -7.5, 0.20 -6.7, 0.30 -5.3, 0.50 -3.1. The same standing in town_street, no towns
    -14.4: 0.06 -11.7, 0.20 -3.9, 0.30 +0.2, 0.50 +6.6. The lit windows' p99.5 luma held at 242-244 at every value.
    - 0.02 and 0.06 read pale grey-blue: a glow that is barely there.
    - 0.30 and 0.50 are warm from afar, but inside the town they turn the sky a brown sodium haze over streets that are dark,
      which is what WINDOWS ONLY above is for.
    - 0.20 is the warm pool round each town from afar, and a warm grey overhead in the street. At evening (windows_lit 0.22)
      every value reads the same.
  - EQUAL ON BOTH PASSES: the compute mist against `--mist-pass=spatial`, all twelve views with the domes and the 0.06 glow:
    mean 0.02-0.05/255, p99 1, no pixel over 16 but 29 on mist_city by day -- what the compute path differed by before domes.
  - WHAT IT COSTS (bracketed slot t3, 2026-09-15 02:10; 9 launches, none void, the off launches either side of each within
    0.04 ms; 7680x4282 PLAIN by day, GPU median). The compute mist with the domes against the same with `--mist-towns=off`,
    seven views, twice each, domes minus no towns:

    | view | domes |
    |---|---|
    | cumulus_side | +0.04 ms |
    | fields | +0.07 ms |
    | grass | +0.08 ms |
    | mist_valley | +0.08 ms |
    | town_street | +0.09 ms |
    | forest_low | +0.09 ms |
    | mist_city | +0.11 ms |

    On two eyes' 17.8 M px that is about +0.02 to +0.06 ms. The whole compute mist is now +0.48 to +0.71 ms at 7680x4282
    against the mist off, and +0.44 to +0.65 with no towns.
- **THE HAZE POOLS IN THE VALLEYS** (step 4, asked for on 2026-09-15: "especially around cities or around low mountains";
  `MistChart.relief_of`, `mist_core.gdshaderinc` `mist_chart_at` and `mist_pool_at`, `MistTuning` RELIEF_TEXELS, POOL_DEPTH and
  `pool_gain`). Where the ground lies below the ground round it, the haze is thicker: by up to `pool_gain` more (1.0 by day, 2.4 at
  evening, 3.2 at night -- cold air drains downhill after dark), reached `POOL_DEPTH` (60 m) below the surroundings. Only the
  haze pools; the stratus deck stays where it lies.
  - THE RELIEF IS THE CHART'S GREEN. `MistChart.bake` writes RGF now, red the height and green the relief: each texel's height less
    a box blur of the heights `RELIEF_TEXELS` (12) texels each way, along rows then columns, twice (about a 1.3 km Gaussian at 128 m
    a texel), edges clamped. Running sums on the worker. Below zero on a valley floor or in a bowl, above on a ridge, zero on any flat
    or steady slope -- so the island, one flat slab, is unchanged.
  - EVERY CHART IS RGF, THE FIRST INCLUDED: MistLayer creates the texture from the first chart and `update`s it with every later one,
    an update refuses a change of format, and the compute mist keeps sampling the RD texture handed at the first bake.
  - NO FETCH MORE: `mist_chart_at` reads height and relief together (`.rg`) at the three points the haze already read the ground at,
    and each haze half multiplies its density by `mist_pool_at` of the relief at the same lower end its ground came from.
  - BOTH PASSES, ONE COPY: FINE reads global `mist_pool` (gain, depth, 0, 0); the compute half pass `pool` in its Params
    (MistEffect packs 52 numbers). The stamp in mist_half.glsl moved with mist_core.
  - TUNED BY ONE TRIAL OF THREE, on alpine (step4-trial): at a 470 m blur and half these gains the evening valley moved by 1.5/255,
    because only narrow floors read as low (7-16 % of a chart 60 m under its surroundings, off the generated ground by a probe
    that stands on it as the level does); at 1.3 km the broad low ground between the ranges does (21-40 %), and with the gains
    doubled the evening lowland fills with lighter broken haze along the valleys while the first city moves by 1.6.
  - HELD (tests/mist.gd): a chart handed a pit 150 m deep and a ridge 150 m high, 9 km either side of a flat at 128 m a texel,
    has its relief well below zero on the pit's floor, well above on the ridge's crest, zero between and in a corner, none anywhere
    on a flat, and is RGF; the pool thicker over a valley than a flat and a ridge's a flat's at every time, night's deepest and day's
    shallowest, AND mist_core's STRUCTURE (the relief read with the height, the pool one plus the gain over the relief below zero,
    each haze half multiplied by the pool at its ground's end); the level writing each time's gain; the packing.
  - PROBE: `--mist-relief=off` writes no pool gain, for pictures and timing of what the pools add. Never a level's.
  - LOOKED AT (step4-look, 1600x900, day/evening/night, mist_valley, mist_climb, mist_low, mist_city and town_street, alpine and
    island, PLAIN, PLAIN with `--mist-relief=off`, the spatial pass and FINE): on alpine the pools add most at evening, where the
    valleys are -- mist_valley mean 4.5/255 (p99 15), mist_climb 3.3 (p99 23), mist_low 3.7 (p99 26) -- about half that at night
    and a fifth by day, and least over the towns (mist_city 1.6, town_street 2.0 at evening). On the island every view is
    unchanged to the last level: its chart is one flat slab. The views were chosen on alpine first: `grass`, `fields` and
    `forest_low` pose off island coordinates there (WHAT IS NOT HERE YET).
  - EQUAL ON BOTH PASSES: the compute mist against `--mist-pass=spatial`, the same five views at three times with the pools, on
    both worlds: mean 0.02-0.05/255, p99 1, and at most 112 pixels over 16 in a picture (mist_city at night on alpine).
  - MUTANTS (phase D, 2026-09-15 08:05; one headless mist suite each, bytes put back and matched by SHA-256, green after):
    - the relief's sign flipped, and no blur (each texel its own relief): each red on
      `and_the_chart_holds_the_valleys_below_their_surroundings`;
    - the shader reading the height as the relief (`.rr`), pooling on ridges (`m_relief` for `-m_relief`), the near half's haze
      not pooled, night's gain under evening's, and the tests' mirror pooling on ridges: each red on
      `and_the_haze_pools_in_the_valleys_and_nowhere_else`;
    - the level writing no pool: red on `and_the_level_puts_each_times_mist_on_the_material`;
    - `MistEffect.pack` dropping the pool: red on `and_the_compute_mist_packs_every_number_where_its_shader_reads_it`.
  - WHAT IT COSTS: NOTHING MEASURABLE (bracketed slot t4, 2026-09-15 07:56-08:01, alpine world; 9 launches, none void, the off
    launches either side of each within 0.03 ms; 7680x4282 PLAIN by day, GPU median). The compute mist against the same with
    `--mist-relief=off`, six views, twice each: -0.015 ms (mist_valley), -0.001 (mist_climb), +0.002 (cumulus_side), +0.009
    (mist_city), +0.004 (town_street), +0.005 (mist_low) -- inside the rounds' own spread. The relief rides the ground fetch the
    haze already made, and a pool is one smoothstep a half. THE VIEWS WERE PROVEN ON ALPINE FIRST: `grass`, `fields` and
    `forest_low` pose off island coordinates there and would have timed the sea; mist_valley and mist_climb look over its valleys,
    cumulus_side from 2 km. The whole compute mist is +0.58 to +0.73 ms at that size on alpine (two eyes about +0.40).
- **NOT DONE:** summit caps (see WHAT IS NOT HERE YET). PLAIN draws the compute mist above, FINE the spatial pass (MSAA).

### A mountain is a range of triangles, and the triangles are both the picture and the rock you hit

Asked for on 2026-09-18: "redesign the blocky mountains ... a low poly mountain, and mountain range would be nice ... a
shader can add more detail and grittyness (like valley edges and creek grooves). Ranges is important, on a spline seems
like a good idea, but you need to control for height as well. Design something that is VERY performant ... The 'stepped
pyramid' look of the current mountains isn't good."

WHAT CAME BEFORE, AND WHY IT HAD TO GO. The island's mountains were 583 stacked boxes, because every box was also its
collision: shading them as a slope (2026-09-13, `RockTuning`'s "SHADING, NOT GEOMETRY") and breaking each peak into a
massif of offset stacks (2026-09-14) both left the outline a ziggurat, and a smooth skin over the boxes would have stood 18
to 38 m clear of the rock a shell burst on. From 20 km out the island had no mountains at all: the rock layer streamed out
at about 10 km (`mtn_far`, the 2026-09-18 before picture). Both old sections and their generator are gone; their
measurements are in git history (`git log -S"A mountain is a massif" -- cockpit/agents.md`).

- **ONE SET OF TRIANGLES, TWO CUSTOMERS.** `ashiato-gd/src/cockpit/range_core.hpp` is the mountains as a function of
  integers -- Catmull-Rom ridge lines through control points, whole metres, ticks of 1/32 m, Q16, an integer square root, a
  cosine and a bearing with no libm -- sampled on a 48 m grid jittered by a hash up to a quarter of the spacing and cut into
  1,920 m tiles. `massif.hpp` hands each tile to Box3D as a static triangle mesh; `MountainRange.tile(i)` hands the SAME
  arrays to `world/mountain_view.gd`. Every vertex is exact in a float32, so what is drawn is what is hit, to the bit.
  REJECTED: height fields (a regular grid and a fixed diagonal read as a grid, and cannot move a vertex sideways), a skin
  over boxes, a GDScript generator (floats and a libm on every peer), and levels of detail (a coarser far picture is a
  hillside the simulation does not have, and the whole island is 39,582 triangles).
- **THE DATA IS `world/mountain_ranges.gd`.** A range is `{salt, peak, saddle, points}`, each point `(x, z, crest, foot)`:
  the ridge passes through it, the crest there before the noise, and how far out the foot reaches. The ENVELOPE -- no crest
  above `peak`, none below `saddle` -- holds on the ridge line exactly, and no vertex rises above its range's peak. The ring
  is six arcs worked out from a radius, a wander and six PASS bearings (three carry the island's fires); three inland ranges
  run along the ring at chosen bearings, leaving a valley each; two lone mountains have radiating spurs.
- **THE SHAPE, AND WHAT EACH PART FIXED.** Across a ridge `(1 - u)^1.5 (1 + 0.6 u)`: a sharp crest, concave at the valley
  (the first `(1 - u)^2 (1 + 1.4 u)` read as rounded hills). Spurs and gullies are a wave along the ridge, leaning and curving
  downhill, staggered side to side, each gully its own depth from a hash, heading below the crest (the first build read as
  a fishbone in a hillshade). The tallest quarter of each envelope is cragged by up to a sixth of its height. A third, 150 m
  crest noise makes a skyline of summits and notches.
- **KEEP-OUTS, NOT REJECTION.** `Terrain.mountain_keepouts` hands the function every clearance (spawns, fires, runway
  approaches, air bases, the railway, the gates, the hand-built places), every town to 120 m past its radius, and every
  wood, each with a floor. The rock stands under the floor and rises from it at fifty degrees. The keep-outs are grown by
  2.25 spacings before use, because the first build held only the vertices inside and DREW rock 1.8 m into a keep-out whose
  floor was 0: a triangle over an edge interpolates from corners outside it.
  **THE RAILWAY'S IS ITS OWN, ON THREE COUNTS, each a per-keep-out list beside the five ints** (`mountain_keepout_lists`: `margins`,
  `rises`; `configure` refuses a list of the wrong length): a box surveyed every `RAIL_KEEP_STEP` = 20 m (not `RAIL_STEP`, which the
  train, the lamps and ten tests read) and 0.6 of it wide, so neighbours overlap on a bend by construction; grown by `RAIL_MARGIN`
  = 54 m, not 108; and climbing out at `RAIL_RISE_FIFTHS` = 15, three to one, not 6/5. Swept 2026-09-20 against the DRAWN triangles
  (`tests/mountains.gd`): a finer step goes no further at a safe margin (step 10 at 48 leaves 1.01 m of rock on the way; the way
  wants box plus margin near 66 m), so the step bought only 52 -> 44 m; the rise moved the ground 100 m over the track from 164 m
  out to 116 m. Nothing else's clearance moved: a rise of 6 reproduces the previous recorded hashes to the digit. A bucket is filed
  by the SHALLOWER of the default and the box's rise, or steep rock is missed as holes. 4:1 reads as a blunt mesa, 3:1 as a
  mountain foot. A new `keepout_rises` entry lands in the DLL: the Linux `.so` needs `tools/bootstrap.sh --double`.
- **EVERYTHING PLACED ASKS THE ROCK THROUGH ONE QUERY.** `Terrain.rock_clears(at, half)`: the highest rock over a box's
  footprint, from `HeightPyramid.highest_within` -- square by square at 32 m, NOT the autopilots' four-lookup
  `highest_over`, which refused a fire in a pass for rock 330 m away. Fires, the aircraft, helicopter and car pools, roads
  and trees ask it. `Terrain.ground_height` and `surface_height` on the island include the rock, so the mist, the lift
  markers and the clouds follow it.
- **`Terrain.land_height` IS THE GROUND BEFORE ANY MOUNTAIN.** An air base checking that its ground is level asked
  `ground_height`, which asked the mountains, whose keep-outs ask the spawns, which ask the air bases: round in a circle
  until the stack overflowed. Anything the mountains are cut back FROM asks `land_height`.
- **ISLAND CARS DRIVE INSIDE THE RING.** A convoy sent through a sixteen-degree pass abreast drove its followers 44 m up
  the talus either side and 1.5 km apart; with the car pool inside `MountainRanges.ring_inside()` the convoys hold at 7 m.
  smoke's "cars down" is now height over the ground under the car: one AI car in a long smoke run still ends parked 57 m up
  the NE range's foot, on the ground, and is recorded under What's next rather than hidden.
- **THE SIMULATION.** `CockpitWorld.set_mountains` builds the meshes (6 ms, 1.66 MB) and folds the rock into
  `clear_between`, `ground_height_at`, `surface_under`, `highest_ground_near` and the nearest-blocker search; the leg tests
  ask the same max pyramid the generated ground's do (`height_pyramid.hpp`, lifted out of `Bedrock` line for line). A
  static mesh costs a rollback nothing. The island's "loaded" hello carries the meshes' hash where it carried "" (digits only, as the hello reader requires: an
  "m" in front of it made every host drop every joiner's hello), and PROTOCOL is 27.
- **THE PICTURE.** `shaders/mountain.gdshaderinc`, both finishes: flat facets from screen-space derivatives near, blending
  to smooth vertex normals past 2.5 to 7 km so a sub-pixel facet does not flicker; one tone a facet (7%); strata; scrub;
  scree at the foot; gully shade (28%), gully rims (the "valley edges") and creeks from two grit channels the function bakes
  into each vertex's colour; snow by height and slope, lower in a gully; the foot in the island grass's own field colour,
  copied off the ground's material. FINE adds grain and meandering creeks. Every number is in `RockTuning`.
- **ITS OWN HAZE, THINNER WITH HEIGHT, AND A FAR BLUE.** The world's fog is one density at every height (`clear_air`,
  0.00016 a metre), which leaves 5.6% of anything 18 km off: from out at sea the island had no skyline. The shader writes
  FOG itself: the Environment's density and colour, read every frame by MountainView (so a cloud's whiteout still whites
  the mountains out), with the DENSITY thinned by the facet's height to 0.12 of itself by 300 m -- from 18 km most of the
  rock seen is lower flank, and thinning to 0.3 by 700 m showed the crests alone ("barely there"; a test paint of pure red
  showed through at about a tenth). At the foot it is exactly the grass's fog, so there is no seam. Past 6 km the rock
  turns toward a haze blue-grey (70% by 16 km), so a distant range is a silhouette darker than the sky, not pale snow.
- **LIFT OFF THE ROCK.** Every island thermal whose ring would touch rock moves to the nearest place its whole ring is
  clear (`Terrain._lift_off_the_rock`, 90 m rings): LiftYard lays the ring on the ground, and twelve rings draped up flanks
  read as roads climbing them (team-lead took one for a road, twice). A moved zone carries `cloud_seed_at`, its first place,
  from which LiftYard hashes its cloud's kind and shape; without it the island's clouds re-rolled into three kinds of four.
- **WHAT IT COSTS, measured (2026-09-18, a MEASUREMENT slot, double editor, d3d12, RTX 5080, 1600x900, 240 frames, two
  rounds interleaved A B A B, every round clean).** A is main at fa83bc8c drawing the boxes, B this lane. GPU medians, B
  minus A, PLAIN / FINE: `mtn_ring` +0.011 / +0.010 ms, `mtn_far` -0.005 / -0.003, `mtn_valley` +0.032 / +0.051,
  `mtn_close` -0.025 / -0.028. At 3D scale 1.41 -- twice the pixels, the stereo proxy, fair because the extra cost is the
  per-pixel grit and 39,582 resident triangles are nothing to a second eye's vertex stage -- +0.016 / +0.022, -0.003 /
  +0.005, +0.047 / +0.078, -0.048 / -0.059. Draw calls FALL on every view, 252 from the runway, since the rock's per-cell
  MultiMesh batches are gone. The two rounds of each side agree to 0.002 ms.
- **NO SHIMMER.** `scenery_shot`'s `mtn_fly` flies 1.5 km up at 120 m/s towards ranges 5 to 15 km off, where a facet is
  about a pixel, and saves every frame (`--strip=1`). Counting pixels below the horizon whose luminance steps up then down
  by more than 0.06 over three frames: 0.001% of the land a frame, the same with every facet lit flat
  (`--mountain-smooth=off`) as with the far blend -- and a checkerboard flicker painted into alternate frames reads 22.7%,
  so the count can see shimmer. The blend is kept as insurance for a sharper screen than 1600x900.
- **WHAT HOLDS IT.** `tests/mountains.gd`: both hashes recorded on both editors; 2,000 rays through a CockpitWorld land at
  worst 0.8 mm from the drawn triangle; the island level itself stood up and 500 rays through its own simulation at the
  meshes MountainView drew land within 0.5 mm; the envelope; no rock in 840 keep-outs; the pyramid never under the rock.
  RED, each on its own check: the collision a tick above the picture (3.19 cm), the picture half a metre above the
  collision (0.5004 m), the ring wandering a metre further (both hashes), keep-outs not grown (265.8 m over a 250 m floor),
  the crest clamp removed (a 66.9 m saddle). smoke measures the ring's tightest pass under 60 m on the rock itself
  (`Terrain.ring_gaps`). The scenery yard's streaming suites lay their own rock (`tests/rock_lattice.gd`).

## THE WOODS ARE A PICTURE, AND COST ALMOST NOTHING TO DRAW

**A tree is never solid.** The user asked for "a shader that defines a forest of trees ... very cheap;
they need no collision, just visible (like grass but a forest)", with detail controls to make the FINE
version convincing. So a wood is a rectangle in `world/forests.gd`, grown by `world/woodland.gd` from
the same boxes the simulation is given and never handed to it: an aeroplane flown into a wood flies
through it, and `tests/forest.gd` asks the simulation so -- a leg end to end through each wood at 8 m is
clear, and the same leg through a tower is not.

### Where a wood is, and what it may not stand on

- **A stand is a catalogue entry**: centre, size (across, along), heading (a vehicle's yaw, in degrees),
  density (on the tuning's trees per hectare), mix (share of conifers). Defaults at the call site:
  density 1.0, mix 0.5, heading 0. No size is no forest, with a warning; density past 4 is held there.
- **The ground says where nothing may stand, once**: `Terrain.ground_keepouts(solid)` is the runway's
  approaches, the railway, the fires, the spawns, the gates (each tagged with its `why`) and every solid
  box, and a tree whose box touches any of it is not grown. A stand may overlap anything; it is carved
  round it tree by tree. The towns' roads join the same list.
- **Planted by hash, not stored.** A lattice in the stand's own frame at FINE's spacing; each point's
  rank, wander, height, kind, tint, lean and wind phase are `Terrain.hash01` of the stand and the point.
  PLAIN keeps the points whose rank is under its share of FINE's trees, so PLAIN's wood is FINE's with
  trees taken out and the finish key never reshuffles it -- and the suite checks it tree by tree.
- **Grown once, on the main thread**, in `FlightLevel._build` as the level loads, with no loading screen:
  5,193 PLAIN and 11,393 FINE trees in 125 to 509 ms on the desktop, before the first frame of the world --
  1,892 and 3,768 since they were thinned (2026-09-13), 900 ms headless in the forest suite against 903 before.

### What each finish draws

| | PLAIN | FINE |
|---|---|---|
| trees a hectare | 45 (70 before 2026-09-13) | 100, half of them past 1 km (160 before) |
| middle | patchy: a 110 m noise keeps 0.6 to all of the trees, never none | the same trees' share |
| tree | trunk of 3 sides, one crown of 6 sides and two rings: 30 triangles | trunk of 4, three crown tiers of 8 sides: 104 |
| lean, wind | none | up to 0.07 rad; whole-tree bend, height squared, its own phase |
| far fade | trees shrink out in rank order between 1.8 and 2.6 km | 2.4 to 3.6 km |
| edge | thins over the outer 120 m (60 before), kept with a chance of (distance in / band)^2, the band's width wandering by half along each side, the last trees in 35 m clumps, trees up to a quarter shorter | the same over 140 m (70 before), up to 30 per cent shorter |
| floor | the grass darkens and greens inside a stand, fading over the same band by the same curve | and a ragged edge up to 40 m out (22 before) |
| chunks | 128 m squares in the stand's frame, one draw each: 60 (67 before) | 63 (67) |

Every number is in `world/forest_tuning.gd`, and nowhere else: the shader uniforms have no
initialisers, and `tests/forest.gd` changes every tuning number in turn and fails if the wood does not
change with it. `--forest=key=value,...` on `tests/scenery_shot.gd` tries a value without editing the
file; `--forest=off` grows nothing.

### Rules it follows, each for a reason

- **Opaque, and no textures**: no alpha leaf cards (a cut-out loses early depth on a tiled GPU, and a
  wood of them is overdraw in both eyes), no camera-facing billboards (a card turned to the head is a
  different card in each eye), no octahedral impostors (they are baked texture atlases).
- **The wood thins and fades in the vertex shader**, keyed to the tree's own rank and its distance from
  `CAMERA_POSITION_WORLD`: the same trees in both eyes, nothing discarded, no per-frame writes. Chunks
  are culled past the fade by `visibility_range_end` (culling is honoured on every renderer). The engine's
  own fade modes, SELF and DEPENDENCIES, work only on Forward+ by the `GeometryInstance3D` class reference,
  and the game is Forward+ since 2026-09-14 -- but they are alpha blending, which the same reference says
  forces transparent rendering through the fade. The shader's thinning is opaque; nobody has timed the other.
- **No shadows.** Instanced shadows redraw every tree; the floor stands in for the shade.
- **Lit by the scene, not by a baked sun.** The tree and floor shaders write albedo and let the scene's
  light and ambient do the rest; the one thing baked into a tree is how much its own crown shades it.
  So the woods darken with an evening or a night.
- **The edge thins by the same rank that decides everything else**, which is what the user asked for
  ("dither the amount of trees near the edge so that the falloff makes it a bit smoother"): a tree is
  kept if its rank is under the finish's share times the edge's chance. The suite counts six rings of
  the band on a bare stand -- 0.01, 0.07, 0.17, 0.37, 0.59 and 0.90 of the middle's trees a hectare,
  outermost first (four slices of the 70 m band read 0.05, 0.23, 0.49 and 0.84 before 2026-09-13).
- **Thinner, patchier and softer at the edge, on request (2026-09-13):** "The forrest is too dense, and
  should have more dithering near the edges (less trees so it blends into the 'non forrest')."
  - Trees a hectare PLAIN 70 -> 45, FINE 160 -> 100. On the catalogue's stands PLAIN 5,193 -> 1,892 and
    FINE 11,393 -> 3,768 (east_wood 7,535 -> 2,614 and west_wood 3,858 -> 1,154 on FINE): 64 and 67 per
    cent fewer, more than the density's 36 and 38, because the patches keep 0.8 of a place's trees on
    average and the wider band takes more of each stand. The suite holds both under the before counts
    and under the after counts and five per cent.
  - The middle is PATCHY, NOT HOLED: `Woodland.thinning` keeps `patch_least` (0.6) to all of a place's
    trees on a 110 m noise, so from the air a wood is thicker and thinner and never a bare glade --
    team-lead's call. The suite holds that the noise moves by a quarter (0.61 to 0.98 over 900 places),
    never keeps under half, and that no 50 m square of a bare 1000 m stand's middle is empty (121
    squares, fewest 14 trees).
  - The band is twice as wide and falls as the square, and inside it a 35 m clump noise decides which
    trees survive (`edge_clumps` 0.6 at the outer side, fading to none at the inner edge), so the last
    trees stand as singles and small clumps.
  - **The same trees on both finishes.** Both noises and the clump weight are read on the lattice's
    (FINE's) numbers, and the weight fades with FINE's edge chance, not each finish's -- PLAIN's narrower
    band would otherwise weigh its clumps differently, the 10-tree subset bug the wander was. PLAIN's
    chance is at most 0.45 x (140/120)^2 = 0.61 of FINE's anywhere FINE is under the clamp; the suite's
    position check finds 0 of 1,892 PLAIN trees outside FINE's wood.
  - RED, each new check first, the forest suite alone with one tuning number broken: the old density
    (70 and 160) fails the ceilings on both finishes, 2,873 and 6,014 trees -- still under the before
    counts, since the patches and the wider band thin it too; `edge_curve` 0.2 fails the rings (the
    outermost 0.68 of the middle) and the shorter-at-the-edge check; `patch_least` 1.0 fails "thicker in
    some places" (1.00..1.00) and leaves `patch_scale` idle; `patch_least` 0 fails "never under half"
    (least 0.02) but not the bare squares, which each still held a tree or two -- so the bare squares
    were driven RED on their own with `patch_least` -1, which the planter's clamp turns into open ground
    wherever the noise is low: 121 squares, the fewest holding 0 trees.
- **Eight stands have a floor**, because a shader's array length is a constant: `most_stands` in the
  tuning says so, a test holds it to the shader, and a catalogue past it is counted and warned.
- **64 m chunks on FINE were rejected on arithmetic**: 272 draws for the two starting stands, over the
  250 the woods, towns and lights share. FINE's denser near ring is the shader's instead. Placing trees
  in a particle shader was not needed at these counts.

### What it costs

**MEASURED ON A DESKTOP, NOT IN A HEADSET**, 2026-09-13: stock 4.7.2, d3d12, RTX 5080, 1600x900 at 3D
scale 1.40, `--fixed-fps 60`, `--hold-fires`, 240 frames. A was cockpit at f3b0003 (the catalogue and
the views, nothing drawn); B the same with the woods; eight launches alternated A B A B A B A B, each copy
under its own `config/name` so neither read the other's user://. Judged by the rule of Stage 2c, written
before the runs. GPU timer medians, ms:

| view | PLAIN A → B | FINE A → B | draws A → B, PLAIN / FINE |
|---|---|---|---|
| forest_low | 0.229 → 0.283 (+0.054) | 0.514 → 0.815 (+0.300) | 888 → 926 / 956 → 994 |
| forest_high | 0.240 → 0.290 (+0.050) | 0.508 → 0.790 (+0.282) | 1030 → 1070 / 1109 → 1149 |
| town_approach | 0.228 → 0.277 (+0.049) | 0.447 → 0.688 (+0.241) | 916 → 950 / 996 → 1030 |
| town_night_lights | 0.220 → 0.228 (+0.008) | 0.421 → 0.673 (+0.252) | 695 → 695 / 744 → 784 |
| fields | 0.248 → 0.277 (+0.029) | 0.506 → 0.653 (+0.147) | 951 → 978 / 988 → 1015 |
| runway | 0.232 → 0.242 (+0.010) | 0.502 → 0.524 (+0.022) | 931 → 936 / 978 → 983 |
| town_street | 0.258 → 0.264 (+0.006) | 0.485 → 0.497 (+0.012) | 357 → 357 / 429 → 429 |
| mountains | 0.256 → 0.262 (+0.006) | 0.477 → 0.490 (+0.013) | 295 → 295 / 328 → 328 |

- **PLAIN**: no view past its 0.10 ms threshold; the finish counts as changed, a mean of +0.027 ms over
  the views against A launches whose all-view means agreed to 0.001. The worst view, +0.054, is under
  the forest's share of the scenery limit (+0.12 of +0.25).
- **FINE**: changed on the five views with a wood in them, +0.15 to +0.30 ms, a mean of +0.159. The worst,
  +0.300, is under the forest's share of +0.40, which leaves +0.50 of FINE's +0.80 for towns and lights.
  town_night_lights shows why FINE costs where PLAIN does not: from 1.8 km out FINE still draws east_wood
  3.2 km away, which PLAIN has faded out by 2.6.
- **The wall clock is noise** on every view and both finishes (FINE +0.003, PLAIN -0.017, against A
  spreads of 0.094 and 0.071): at this scene weight this desktop's frame is not waiting on the GPU.
- **THE COST IS VERTICES, paid for every tree in range whether it shows or not.** A tree past its fade is
  shrunk to its foot in the vertex shader, not culled, so every chunk in range runs every tree's vertices:
  FINE adds 783,640 primitives on forest_high and on town_night_lights alike, PLAIN about 100,000. If the
  share is ever short, the tuning comes down first -- FINE's `crown_sides`, `trees_per_hectare`, `fade_to`.

**THINNED, 2026-09-14**: the same probe and settings in the scenery lane, taken under load from the other lanes, A
being the woods as they were (`forest_tuning.gd` and `woodland.gd` from main) and B the thinner ones, four launches
alternated A B A B, 240 frames each. GPU timer medians, ms, the mean of each build's two launches (A's two agreed to
0.002 and B's to 0.011 on every view):

| view | PLAIN A → B | FINE A → B | primitives A → B, PLAIN / FINE |
|---|---|---|---|
| forest_low | 0.280 → 0.247 (-0.033) | 0.803 → 0.593 (-0.211) | 826,531 → 766,651 / 1,803,304 → 1,316,688 |
| forest_high | 0.289 → 0.266 (-0.023) | 0.790 → 0.599 (-0.191) | 1,005,587 → 942,617 / 1,947,964 → 1,436,180 |
| town_approach | 0.273 → 0.245 (-0.028) | 0.685 → 0.524 (-0.161) | 837,623 → 782,273 / 1,694,296 → 1,254,064 |
| fields | 0.271 → 0.256 (-0.015) | 0.651 → 0.545 (-0.106) | 794,829 → 758,769 / 1,450,020 → 1,168,804 |

Draws moved by at most seven. The cost is still vertices: FINE's forest_high loses 511,784 primitives with 7,625 fewer
trees, and its worst share of the scenery limit falls from +0.300 ms to about +0.09.

### Found while building it

- **A PackedArray taken out of a Dictionary and appended to is a copy.** The first tree mesh had no
  vertices, and the only sign was `ERROR: array_len == 0` under a scenery suite that printed PASS.
- **`[] if off else stands()` is a plain Array**, and assigning it to an `Array[Dictionary]` is a script
  error that aborted `grow` -- which is what `--forest=off` looked like it was doing on purpose.
- **A one-ring broadleaf is a diamond on a stick** from a low pass; two rings a tier make it a tree.
- **The clearance check passed with the planter ignoring keep-outs**, because both starting stands are
  on open ground. A stand laid across the inner south gate and the runway's approach now has to be
  carved (89 trees of 664), and planting it with the keep-outs ignored fails.
- **PLAIN stopped being a subset of FINE when the edge thinned**: 10 of 5,209 PLAIN trees stood where
  FINE had none. The first guess was the carving round keep-outs, since the finishes' trees differ in
  size; carving both with one box changed nothing (still 10), so that guess was wrong -- the one box is
  kept, as a guarantee. The cause was the band's wander, read along each side at `along / band`, and
  PLAIN's band is 60 m to FINE's 70, so the same place read different noise. Read on FINE's band on both,
  0 of 5,193; on each finish's own again, the same 10.

### NOT here

- A forest placed in the editor or drawn in the headset (the catalogue is ready for one).
- A PLAIN picture gate on views with a wood in frame: the forest changes them, as it must, so "PLAIN
  identical to the build before" applies only to views with no wood in them.
- A headset measurement: every number above is a desktop's.

## THE WORLD

A 14.4 km island: a ring of thirty mountains around the edge, three inland ranges, three
cities and three towns with roads between them, eight arches to fly through, and sea beyond. It is **generated**, in
`world/terrain.gd`, and every solid thing in it -- plus every spawn point -- comes out of
that one file.

The wire can describe **±32,768 m on either horizontal axis and −200 to 41,700 m up, every
position to 0.01 m** (the `ground` and `height` quantisers in `cockpit_components.hpp`, 23 and
22 bits). Both are read from the ground's own bounds in `ground_core.hpp`: the world's edge
(`kWorldEdgeMetres`, also the most `GroundField`'s `world_half` may be), and the open sea's
floor at −150 m (`kSeabedMetres`) less 50 m for a hull resting on it. GDScript asks
`CockpitWorld.wire_range()`. That is a hard edge, not a soft one: a vehicle outside it is
clamped on the wire, so everyone else watches it stop at the boundary while its own pilot flies
on. It has been widened three times, 2 km to 8, 8 to 32, and 32 to 65.5 km with 41,900 m of
height for the terrain world, at six bits a position. A clamp is no longer silent:
`put_position` counts every clamped coordinate, and `CockpitWorld` reports them as an error
that names the first position outside the range, by component, field, entity and value.
Rounds and missiles are spent where they cross the same range (`leaves_the_wire`).

**THE SEABED IS A FLOOR (2026-09-16, lane/sinking).** Until then neither world's open sea had one the physics could touch:
the island's sea is not solid by design (a water bomber skims it), and the generated ground builds no height field under
-40 m, so its -150 m seabed was a number `ground_height_at` answered and the collision did not have. Anything that went in
fell for ever and was clamped at -200 m on every other machine, with "the wire clamped" once a second.
- **Measured before:** eight kinds dropped unflown from 40 m over open sea reached -824 m (heli) to -3,821 m (tank) in 40 s,
  25,545 clamps, identically on both worlds; `tests/seabed.gd`, one of every kind for 30 s, a train at -4,005 m and 34,363
  clamps. Found only by `chatter` with the voice model, whose two unflown aeroplanes stalled into the island's sea fifty
  seconds after their spawn (31 to 63 clamp errors); without the model that suite ends in 3.5 s.
- **The fix:** `world/seabed.gd` (`Seabed.lay`), one static box under the whole wire from the seabed down to the wire's
  floor, laid by the level with the rest of the country on both worlds. Its top is the generated ground's own seabed, read at
  its corner as `far_out` reads it; `kSeabedMetres` is not bound to GDScript, so `tests/seabed.gd` holds the two together by
  sounding the open sea on both worlds within a metre.
- **After:** the fourteen of twenty-two kinds that sink come to rest at -147.4 m (airliner) to -149.7 m (segway), 0 clamps.
- **OPEN (2026-09-18, the F-16's lane): the seabed suite's drops pile up on alpine.** `tests/seabed.gd` asks for drops
  `SPACING` (600 m) apart, but `Terrain.open_sea_near` snaps each one to the nearest open sea, and alpine has little of it.
  Craft came down on each other:
  - the light helicopter 3 m from the train, where it slid at 0.08 m/s, over `AT_REST`. It read as the helicopter failing
    to come to rest; it was the helicopter on the train;
  - the F-16 6 m from the submarine, where it sat afloat at +2.3 m and was never counted as sunk, so never measured.
  - **Why it showed then:** the row was centred on the number of kinds, so adding kind 27 moved every drop 300 m.
  - **What changed:** the row is now FROZEN at the 27-kind layout, so kinds 0-26 are asked for where they passed on main
    and a new kind appends eastward. A drop within `CLEAR_OF` (300 m) of an earlier one is asked for again on a spiral.
    Both suites are green: the helicopter rests at -148.95 m where it always did, and the F-16 sinks and rests at -148.40 m.
  - **Not solved:** 48 spiral steps still find no clear sea for every kind on alpine. The run prints
    `[seabed] NOTE alpine closest drops`, and on this build the Osprey comes down on the battleship, afloat and unmeasured.
    A pair check would be red on main too, so it is printed, not asserted. The fix wants drops that know alpine's sea: a
    list of open-sea points from the ground, not a row snapped to it.
- **What it changed:** the island's open-sea `water_depth_at`, inf to 150.0 m (see `water_depth_at` below, with the diff).
- **Rejected:** a floor below the sounding's reach, top at -201 m. Every answer stayed byte-identical, and five of eight kinds
  rested with their origins at -200.15 to -200.40 m, past the wire's floor: 24,180 clamps in 60 s. A craft rests 0.6 to
  2.6 m above what it lies on, so no height keeps both.
- **A catch, not the design of a wreck.** A craft on the floor with a player in it is a player at -150 m, and aircraft feel no
  water at all (the airliner went through the surface without slowing). What ditching is, and what becomes of a crew, is
  the user's to decide; both are on the plan.

Three rules hold that file together, and each of them is there because breaking it produced
a bug that no screenshot would show:

1. **One list feeds the physics and the picture.** `FlightLevel` walks `Terrain.boxes()`
   once for `Sim.add_static_box` and once for the rock and concrete `MultiMeshInstance3D`s and the
   towns' `TownView`. Scenery drawn
   where the simulation has none looks exactly like a networking fault.
2. **The randomness is not the engine's.** Static collision is not replicated; every peer
   generates it. `RandomNumberGenerator` is deterministic for a seed *today*, but it is not
   a documented wire format, and a Godot upgrade that changed it would desync every client
   that had not upgraded. The nine-line integer hash in that file cannot change under us.
   A peer whose mountain is elsewhere does not get a visual glitch -- it predicts its own
   aeroplane through a hillside the server says is solid, and rolls back into it for ever.
3. **The generator keeps its own clearances.** Spawn points and gate corridors live in the
   same file, and nothing is generated into them. Hand-placing scenery around hand-placed
   spawns works exactly until either moves: the first version put a pod inside a mountain
   and walled up one of its own gates, and the smoke test found both.

Two bugs worth keeping written down, because both were silent:

- A gate's "along the corridor" vector was `Vector3.ONE - across.abs()`, which keeps the
  **Y**. Every corridor was as tall as it was long, a 220 m column of protected air that
  quietly deleted six mountains off the ring.
- Fourteen peaks at that width closed the ring into a **fence**. Eleven leaves gaps of
  234 to 465 m. The smoke test measures the tightest one, because "is there a way out of
  this island" is not something you can see in a screenshot from inside it.

**What is in it is printed, not typed here**, because this line went stale three times over (463, then 650, and 984 by
the time anybody counted again). `tests/streaming_probe.gd` with `--parts=boot` prints the solid boxes by group, and
smoke prints how far out and how high everything stands (`it_all_stands_on_the_island`) and the tightest and widest
gap between peaks (`there_are_gaps_in_the_mountains_to_fly_through`). Read on 2026-09-14, after the massif: 984 solid
boxes (583 rock, 377 buildings, 24 concrete) and the ground slab.

The `Ground` mesh in `sky.tscn` is sized to match `GROUND_HALF` and has to be. Beyond the
coast is water at `SEA_LEVEL`, told to the simulation through
`Sim.set_handling(Kind.BOAT, ...)` rather than left on a default that happens to agree with
the mesh. Boats spawn off it.

An aeroplane handed over by the take-the-next-craft button is launched at 800 m, which is
above the mountains rather than merely above the towers.

### The world is filed by the kilometre, for a picture drawn round the aircraft

The user wants a world of 30 to 70 km, drawn round the aircraft and not all at once, with the headset on the double
build (so no floating origin) and some authored airfields and models to come. The plan is the cockpit-streaming
design in the drafts folder beside the repository (godotgames-drafts, 2026-09-14), and its first rule is this
section's: **THE PICTURE
STREAMS, THE COLLISION DOES NOT.** Every world keeps every static box (rule 8) because a box is about 930 bytes and
costs a tick nothing -- 24,625 of them, the island tiled five by five, add in 33 to 41 ms and 21.8 MB and leave a
24-aircraft tick at 0.028 ms against 0.028 (`tests/streaming_probe.gd --parts=scale`, 2026-09-14).

### The level map is one dead world picture plus live markers (2026-09-16)

`LevelMap` shares the level's `World3D` with a 1024 px orthographic `SubViewport`, gives its camera a fog-free
environment, asks for `UPDATE_ONCE`, and then leaves it disabled. Level, daylight and finish changes each request one
new picture; an ordinary frame never does. The clipboard MAP tab and the dedicated `MapScreen` both use `MapCanvas`
for moving crew arrows, so the 5 Hz overlay does not render the country again. Positions and headings come from
`Sim.current` through `CrewManifest`; `LevelMap.marker_style` reads names and colours from item 15's authoritative
`Net.name_of` and `Net.colour_of` APIs, and the map keeps no second roster.
The screen is `Bind.Take.NONE`: BUILD may move it, but no flight hand grabs a read-only pane.

Measured windowed with `tests/map_shot.tscn --xr-mode off`: the one 1024 px island render plus its portable texture snapshot took 35.21 ms on the RTX
5080 used for the probe. Headless `tests/level_map.gd` measured 0.000 px projection error at all four island corners
and no rebuild over five ordinary frames. Pictures are `screenshots/2026-09-16/map-item19-island.png`,
`cockpit-device-map-screen.png`, and `map-item19-pilot-seat.png` (pilot eye point).
Gates: `level_map`, `map_page`, `map_screen`, `builder`, `pinch`, `fit`, `clipboard`.

### And the map now draws the traffic too, and says which of it is a person (2026-09-17)

**AN OPERATOR WATCHING A MAP IS BEING TOLD ONE THING: which machines in the air have a human in them.** Everything
they say on the radio afterwards rests on it, so a map that colours one aeroplane wrong is worse than a blank map --
it is confidently wrong and nothing on the screen says so.

`LevelMap.markers` lists CREWED craft only, because the CREW page answers "where can I sit with somebody" and the
hundred and forty machines flying themselves are not an answer to that. `world/air_picture.gd` is the other question:
`AirPicture.contacts(manifest, states)` is that list plus **every other craft in `Sim.current`**, each row carrying
`manned`. `world/sky.gd` hands it to every map surface, so the clipboard MAP tab and every `MapScreen` in the game
now show the traffic as well as the crew.

**THERE IS NO "THIS ONE IS AI" BIT ANYWHERE IN THE GAME, and this file does not invent one.** A craft is manned when
its own replicated `Seats` holds a client id -- what the server alone writes and what `CrewManifest.read` derives the
manifest from -- so an AI contact is simply a craft the manifest did not name. A player who steps out of an aeroplane
is a grey contact on the next tick and one who boards it is a coloured one, with nothing stored and nothing to keep
in step (rule 10).

**FOUR CHANNELS AT ONCE, because one is not enough to read in a second**: a crewed craft is a SOLID arrow, half again
as big, in its player's own roster colour, carrying their name always; anything else is an OPEN grey outline, smaller,
with no name on it until it is picked. Plus a tally in the corner -- "3 PLAYERS / 32 AI" -- because a number is the
fastest read on a board. The traffic is drawn first and the people over it, or the one marker an operator is looking
for disappears under the next contact to cross it.

**A MACHINE IS CALLED WHAT IT ALREADY ANSWERS TO ON THE RADIO.** `RadioPhrases.callsign(kind, entity)` is the
authority -- "Airliner 27", spoken as "airliner two seven" by the aircraft itself -- so the words on the plot and the
words in the headset are one function and not two, and an operator has something to say. **Never `Net.name_of`**: it
answers "PLAYER 7" for a stranger, so a contact handed its client id of -1 comes back labelled "PLAYER -1" in a
player's fallback colour, which is a machine wearing a person's name. A contact's KEY is `-entity`, local to that one
piece of glass and travelling nowhere. The call sign is NOT replicated -- it comes off a hash of the entity id and
entity ids are per-world -- which is already true of the radio and costs nothing with one operator's plot, because the
pilot being turned cannot see the label and is being turned by voice. A replicated call sign is the feature to build
before a second operator seat exists.

**COLOUR IS THE WEAKEST OF THE FOUR, AND LOOKING AT THE PICTURE IS WHAT PROVED IT.** `PlayerColours.PALETTE`'s eighth
colour is `b0bec5`, a pale blue-grey; the AI grey `8a949c` sat close enough to it that "the AI colour is not IN the
palette" -- which is what the check said first, and which passed -- would have allowed a machine drawn indistinguishably
from a player wearing it. `AirPicture.AI_APART` is now a floor of 0.25 in RGB and `AirPicture.nearest_player_colour()`
measures 0.274 against the real palette. Even at the floor, a grey player is still solid, bigger and named.

`tests/air_picture.gd` is **anchored outside the map**: the truth is `CockpitWorld.vehicle_seats`, not the manifest the
picture was handed, and the two partitions must be the same set both ways with nothing left over. Section 3 boards and
leaves an autopilot aeroplane through a real client input frame (`set_pilot_input`), the way `tests/nobody_aboard.gd`
does. Section 5 holds that the plot is a DISPLAY: pressing a contact picks it out and moves nothing and seats nobody.
Eight mutants, each red on the check that names it: the map as it was (crewed craft only, which is how the claim that
autopilot aircraft were invisible was proved rather than asserted), every machine called a person, a machine in a
palette colour, a machine named by `Net.name_of`, a tag typed in `AirPicture` instead of the radio's, every machine
sharing one key, a tower counted as traffic, and the grey crept next to `b0bec5`.
What it CANNOT see is whether a person can tell them apart, because headless has no rendering device. `map_shot` saves
the picture twice, the second time with the saturation taken out: if the players cannot be found in the greyscale one
in a second, the other three channels are not doing their share. `screenshots/2026-09-17/cockpit-awacs-01-air-picture.png`
and its `-greyscale` twin, three players among thirty-two machines.
Gates: `air_picture`, `level_map`, `map_page`, `map_screen`, `clipboard`.

`world/world_map.gd` is the first piece: `Terrain.boxes()` filed into cells of `WorldMap.CELL`, 1,024 m, **each box
in the one cell its centre stands in**, and each cell's bounds the hull of what is filed there. By the centre and not
the footprint, because a picture drawn from a footprint filing draws a border box once for every cell it touches;
`BoxGrid` files by footprint, which is right for "is this point clear" and is the other question. It draws nothing
yet.

Measured 2026-09-14: 984 boxes into 61 cells in 1.45 ms; 275 boxes reach past their own cell's square, the furthest
by 326 m, which is why a cell's cull box is its bounds and never its square. `tests/world_map.gd` holds it to the
list, and each check was driven RED first:

| broken on purpose | what failed |
|---|---|
| filed in every cell the footprint touches | `every_box_of_the_island_is_filed_exactly_once` (1,329 filed of 984) and `every_box_centre_stands_inside_its_cells_square` (345 astray) |
| `int()` instead of `floori` in `cell_of` | the centre check (831 astray) and `just_below_zero_is_the_cell_below_zero_on_both_axes` |
| bounds from the centres alone | `every_cells_bounds_are_exactly_the_hull_of_its_boxes` (61 of 61 loose) |
| a refusal not counted | `a_box_with_no_place_is_not_filed_and_is_counted` |

The centre check asks the cell's own rectangle (`WorldMap.square_of`), not `cell_of`: a check that asked `cell_of`
would agree with any mistake `cell_of` made, which is exactly what the `int()` run shows it catching.

### The picture is drawn a kilometre at a time

The rock was ONE MultiMesh of 583 boxes, the concrete one of 24, the railway one of 5,712 pieces and each town one,
and a MultiMesh is culled as one box: a single step of a single peak in frame drew every mountain on the island.
Since 2026-09-14 the picture is drawn from the `WorldMap` filing -- **one MultiMesh per cell per material** --
`world/scenery_yard.gd` (`SceneryYard`) for the rock, the concrete and the railway, and `TownView` for the buildings
and the paint. On the island that is 55 rock and concrete batches, 11 of buildings, 15 of paint and the railway's.
`FlightLevel` hands the yard the boxes, and the railway as pieces sampled off `rail_pose` exactly as before; it no
longer builds a MultiMesh of scenery itself.

- **Each batch stands at the middle of what it draws**, its instances offsets from there. A MultiMesh's transforms are
  float32 whatever the engine's precision, and a box 35 km out written as a world position is on a 4 mm grid. The
  furthest corner of any instance on the island is 1,794 m from its batch's middle.
- **Drawn to the camera's far plane, asked of the camera** (`FlightLevel._far`): `visibility_range_end` is measured to
  the middle of a batch's box, so a batch ends at far plus half its box's diagonal and nothing the camera could see is
  dropped. Nearer than that is the rings' business, next.
- **The value handed over is the value kept.** Each batch keeps the transforms and custom data it was handed, for the
  tests, from the same line that handed them over -- see the RED below for the version that did not.

`tests/scenery_yard.gd` holds the batches to the list: every rock, concrete and building box drawn once, the size and
in the place `Terrain.boxes()` says, in its own cell's batch as a small offset; every rock step carrying its box's
peak; every batch drawn out to its furthest corner, measured from the instances; every street, road and railway
piece drawn once in its own cell; the finish reaching every batch. smoke's `the_picture_is_the_same_list_as_the_physics`
counts the yard's batches (984 drawn, 984 solid). Each check was driven RED first:

| broken on purpose | what failed |
|---|---|
| a border box drawn by the cell beside it as well | drawn-once (605 of 583), own-cell (22 astray), the peak count |
| instances as world positions, batch at the origin | the small-offset checks (583 rock) and the range (furthest corner 5,860 m) |
| a batch drawn out to far from its middle | the range: `Rock_-6_-1 ends at 24000, wants 24356` |
| no peak handed to the rock | the peak check, 583 wrong -- **but only once the kept value was the handed value**: the first version kept a second `rock_custom` call beside the one it handed over, and this mutant PASSED |
| the finish missing the last batch | the finish check |
| paint filed 600 m east | 74 of 115 astray |
| railway pieces not taken back to their batch's middle | 565 of 565 astray |

**The pictures moved by pixels, and here is where.** `tests/scenery_shot.gd --still`, all sixteen views on both
finishes, two launches before and two after, alternated: 16 of 32 pictures identical to the pixel; the rest differ by
at most 4 of 255 in a channel, the most being `fields` FINE at 256 pixels of 3. The differences are the same in both
pairs, so they are the change and not the launch. Looked at (`godotgames-drafts/.../cockpit-streaming/inc2/diff-*`):
every cluster sits where a distant mountain's bottom step meets the grass, which is a depth tie between two surfaces in
one plane -- and a vertex moved by a float step, which is what writing it as an offset does, decides a tie the other way.

**What it costs.** Measured 2026-09-14 on the stock editor, d3d12, RTX 5080, 1600x900 at 3D scale 1.40, with other lanes running Godot
throughout, so only the difference is read.
- GPU time: launches alternated A B A B over all sixteen views and both finishes, `--hold-fires`, 240 frames. The GPU
  timer median fell by 0.014 to 0.098 ms on every view with scenery in it (A's own spread at most 0.015), and did not
  move on `sea` and `coast` (+0.000 to +0.006).
- Primitives fell by 9,444 to 72,732, because a cell out of frame is now culled on its own.
- Draw calls rose by 6 to 73. Of the 250 draws the woods, towns and lights share, the towns go from at most 8 (six
  towns and the paint) to at most 26 (11 building cells and 15 paint cells) with the whole island in view. The rock,
  concrete and railway batches were never in that share.
- **The render CPU did not move, and the first A/B said it had.** The first run read the viewport CPU timer 0.5 ms
  higher on `sea` and `coast`, where nothing drawn changed. A run with every visibility range switched off moved it by
  -0.14 to +0.09 ms, so it was not the ranges. Three launches of each build, alternated, then read after minus before at
  -0.031 to +0.049 ms on all ten view-finishes checked (sea, coast, fields, clouds, mountains), inside each one's own
  launch spread of 0.058 to 0.244 ms. A load log over the same minutes shows the main checkout's editor and the steam,
  double and terrain lanes starting and stopping Godot. The CPU timer moves with whatever else the machine is doing;
  read it only off alternated launches, several of each.

| view (FINE) | GPU median before, ms | GPU after - before | draws before -> after | primitives before -> after |
|---|---|---|---|---|
| fields | 0.702 | -0.072 | 951 -> 1,010 | 1,045,660 -> 1,007,728 |
| forest_high | 0.805 | -0.014 | 1,170 -> 1,243 | 1,376,164 -> 1,366,720 |
| town_approach | 0.708 | -0.053 | 918 -> 975 | 1,124,024 -> 1,086,008 |
| mountains | 0.458 | -0.062 | 269 -> 275 | 431,704 -> 358,972 |
| runway | 0.619 | -0.082 | 1,013 -> 1,066 | 1,008,264 -> 965,352 |
| sea | 0.404 | +0.001 | 250 -> 250 | 329,076 -> 329,076 |
### The ground is a function of integers, in C++

The world is to become terrain rather than a slab ringed with box mountains: the design is in the drafts folder beside
the repository (godotgames-drafts, 2026-09-14, cockpit-terrain/report.md). Its first piece is `GroundField`
(`../../ashiato-gd/src/cockpit/ground_field.hpp`). It turns integer metres into heights in ticks of 1/32 m, gives the water
standing at a place, and holds the catalogue of lakes, town sites and airfield strips the function found. No level asks
it yet; `CockpitWorld.set_ground` stands a simulation on it (AND THE SIMULATION STANDS ON IT, below).

- **INTEGERS ONLY, because the ground is not replicated** (rule 8).
  - The noise is gradient noise on lattices of 2^k metres, in Q16 fixed point on int64.
  - Distances are compared as squares, so no root is taken.
  - Phase 1 built the same function in stock GDScript, double GDScript and C++ and got one SHA-256 from all three for
    9,584 heights, their water and the catalogue. `tests/ground_field.gd` holds this copy to those hashes on whichever
    editor runs it: PASS on both, 2026-09-14.
- **IN C++, because GDScript is 400 times slower** at this: 39 to 174 µs a sample against about 150 ns. A 64 km square
  at 16 m is 16 M samples: a quarter of a second, against ten to seventeen minutes.
- **GDScript will not shift a negative int at all.** `-5 >> 1` is "Invalid operands for bit shifting. Only positive
  operands are supported" -- a PARSE error on constants, which hung both editors until the deadline. The phase-1 sketch
  floored through a helper; the C++ uses C++20's arithmetic `>>`.
- **Three tuned numbers, required and defaulted nowhere in C++:**
  - `world_half`, 8,192 to 40,000 m;
  - `peak_height`, 0 to 3,000 m;
  - `seed`, 0 to 65,535.
  - The game's values are `world/ground_tuning.gd` and nowhere else.
  - `configure` reports an unknown key, a missing one, a clamp and a wrong type, and warns each. A missing or mistyped
    key leaves no ground at all.
- **What the suite found RED.** One salt of the 256 m detail octave changed (71 to 70) in a rebuilt library failed five
  checks: the points, the heights, the water, the catalogue (145 ints against 143), and the worker thread's heights.
  Every tuned number moves the world:
  - seed 1 is another world (1,516 km² of land against 1,330);
  - `peak_height` 700 lowers the highest ground from 1,237 to 699 m on a 512 m lattice;
  - `world_half` 20,000 holds 580 km² of land against 1,330.
- **EVERY NOISE OCTAVE HAS ITS OWN LATTICE, and the recorded hashes are this library's, not phase 1's.** Gradient noise
  is exactly zero at its lattice corners, and every power-of-two lattice has a corner at the origin. So at (0, 0) every
  ridged octave stood at its crest at once and the warp was zero.
  - The user's alpine world (64 km, 3,000 m) put its highest ground there: a 3,110 m needle rising 8 to 12 m a metre on
    every side, which `tests/alpine_probe.gd` reported as the steepest step twice before a line of samples across both
    axes showed what it was.
  - Each salt now moves its octave's lattice by an odd number of metres.
  - Measured on the alpine world, before → after:
    - highest ground 3,110 → 2,973 m;
    - land steeper than 60 degrees 8.0 → 6.85 %;
    - cells whose relief reaches 2,048 m 40 → 15.
  - It changed the phase-1 world as well, so the suite's hashes were recorded again from the stock editor's build and
    matched by the double editor's.
- **ALPINE RANGES KEEP THEIR SMALL RIDGES THE SIZE THEY WERE.** Above 1,350 m the 1,024 m and 512 m ridges stop growing
  with `peak_height` and the broad ridges carry the rest, renormalised to reach it. Worlds at or under 1,350 m are
  unchanged by it, bit for bit. At 3,000 m it took the land steeper than 60 degrees from 10.4 to 8.0 % (before the
  lattices above).
- **THE SUMMITS ARE ROUNDED** (the user's ask, 2026-09-14). Above 1,350 m each ridged octave takes a soft absolute value,
  rescaled so a crest keeps its height; at or under 1,350 m the softness is zero and the arithmetic is unchanged, bit for
  bit (0 of 16,008,001 samples moved). On the alpine world:
  - needles, a fall of 180 m or more within 90 m of a summit: 83 → 1;
  - the median fall in those 90 m: 128 → 58 m;
  - the highest ground: 2,973 → 3,093 m. Unrescaled, the same rounding took the ranges down to 2,360 m.
- **AND THE VALLEY FLOORS.** The carve was 75 m × (1 − |n|/w)², and |n| has a corner at zero, so every valley floor was a
  crease with walls to about 73 degrees. Within a quarter of the width of the centre line |n| is now a parabola meeting
  it with the same slope, and beyond that nothing moved. Lowland under 500 m steeper than 30 degrees: 10.81 → 10.00 % on
  the alpine world, which kept its 7 towns and 13 lakes. **Rejected:** a smoothstep of the whole profile, which reshaped
  every valley's sides for no measurable softening (10.81 → 10.85 %) and took 4 of the 1,350 m world's 12 towns.
- **FOUR TO SIX AIRFIELDS, NOT ONE** (the user's ask). A strip is tried in every 2,048 m cell along both axes, dropped if
  any of its 33 samples is under 6 m or over 450 m or it is near a lake or a town, and the rest sorted flattest and
  lowest first. They are taken in rounds that loosen only while fewer than four are taken: relief 50, 85, 120 m; spacing
  12, 10, 8 km; one, one, two strips a region of the square's nine. The first rule, one candidate an 8 km cell, found one
  airfield on the alpine world. Now it has 4 and the 1,350 m world 5, every one taken in the first round, with at most
  45 m of relief before flattening.

### And the simulation stands on it

`CockpitWorld.set_ground(GroundField)` lays the ground into a started world (`../../ashiato-gd/src/cockpit/bedrock.hpp`).
**Off by default**: a world with no ground answers every question exactly as the island's did, and no level sets one yet.

- **A Box3D height field a land cell**, 65 × 65 samples at 16 m, every peer laying them from integers in the same order.
  - **Exact to the tick.** Box3D quantises a field's heights over its range in 65,535 steps. A range of exactly 65,535
    ticks from a lowest sample on the grid makes each step 1/32 m and the quantiser's arithmetic exact in float32.
  - **A cell that spans more is four fields, and a quarter that still does is four again.** The first version split
    once; the suite found 3 of the alpine world's quarters still rounding a height, because the rounded summits keep
    their height on fuller shoulders (24 cells split, where 15 did before).
  - A cell whose every sample is under −40 m is open sea and has no field.
  - The alpine world: 1,799 land cells, 1,880 fields, 35.8 MB, laid in 1.75 s on each peer.
- **A max pyramid for the autopilots**, 10.7 MB: the highest of each 32 m square's nine samples, rounded up to a metre,
  then the highest of four, level by level. `clear_between` asks it beside the boxes, halving a leg down to 32 m. It may
  call a clear leg blocked and never a blocked one clear: 0.70 µs a leg on the stock editor, 1.10 on the double.
  **A car's or a boat's leg does not ask it**: the ground under a surface leg is the road, and what a car may not cross
  is the terrain's content to say.
- **What else a ground changes:**
  - `what_blocks` reports the square of ground a dropped leg came nearest to;
  - `Underneath` is the ground or the water under a wheel, or a deck, and says which;
  - `recovery_height` and the launch height are over the highest ground within 1.5 km;
  - a scoop is measured over the water that is there, a lake's own level, and not over a shore under 3 m deep.
- **Box3D is single precision in both libraries.** `b3_pos` narrows every position to a float32, so 32 km out the
  physics holds a position on a 3.9 mm grid on the double build as well. The suite first asked its rays at exact doubles
  on the double editor and missed the ground by 2.7 mm on steep faces; it now asks where the physics can stand.

`tests/ground_collision.gd`, against the game's world (64 km, 3,000 m, seed 0), on both editors:
- a Box3D ray down lands on the drawn triangle, worked out in the suite from four samples on Box3D's diagonal, within
  0.244 mm at 10,000 land points;
- the simulation's `ground_height_at` is that triangle within 0.122 mm;
- no leg called clear is blocked by the drawn ground sampled every 2 m (1,386 clear, 414 blocked), and a level leg a
  quarter of a metre under each of the 22 summits standing 1.5 m proud between a pyramid square's corners is called
  blocked;
- a client lays the server's hash, and seed 1 does not;
- with no ground a leg through the 3,083 m summit is clear, and with it blocked;
- a tanker fills 10 m over a lake at 76 m and over the sea, and not over the lake's shallow shore or its rim;
- a light aeroplane braked on 3, 8 and 12 degrees moves 0.00 m in 30 s, and unbraked on 8 degrees rolls 245 m.

Each was driven RED by a mutant library, one at a time, the source restored byte for byte before the next:

| broken on purpose | what failed |
|---|---|
| a field laid 16 m east of its samples | the ray: 55 of 10,000 missed, the worst 49.8 m out; 526 and 928 of 1,000 at half a metre and a metre and a half |
| the pyramid's finest level from a square's four corners, not its nine samples | 22 of 22 summit legs called clear. **Random legs and legs grazing random lines passed it**, so the summit legs were added |
| the scoop measured from sea level | the tanker over the 76 m lake did not fill |
| the wheel brakes left off | braked on 3, 8 and 12 degrees: 108, 244 and 279 m in 30 s |

### And kept round the eye

Since 2026-09-14 the yard builds a kilometre of the picture when it comes within reach of the eye and lets it go
when it is well out of it (`world/scenery_yard.gd`). **The collision does not stream**: every world still holds every
static box. What streams is nodes, buffers and draws.

**A yard is layers, and a layer knows nothing of rock or rails.** A layer is a set of `WorldMap` cells with the
bounds of what each will draw, a reach in metres, a parent node and a function that builds a cell's nodes. Rock,
concrete and the railway are the yard's own layers; the buildings and the paint are `TownView`'s, handed in. Terrain
chunks, lakes and authored places are to be more layers. The yard decides only when a cell is built and let go.

The rules, each for a reason:

- **Distance is from the eye to the nearest point of a cell's bounds, on the ground.** Not to its square, because a
  mountain leans 326 m into the next cell (THE WORLD, above). Not in 3D, because climbing does not stop you being over
  the ground.
- **Built within reach, let go only beyond reach + half a cell + the distance the eye covers in `LOOK_AHEAD` at its own
  speed, measured from the eye.** The first version measured let-go from both the eye and the point ten seconds
  ahead, with half a cell of margin. A 300 m helicopter orbit swings the ahead point round a circle wider than that
  margin, and it built 25 cells and let 18 go in five laps. Measured from the eye with the swing in the margin, it
  builds 9 and lets none go.
- **Where the eye will be counts for building:** `LOOK_AHEAD`, 10 s along the velocity taken between two frames. At the
  plane's 166 m/s that is 1.66 km.
- **A few a frame:** `watch` stops once `ATTACH_BUDGET_USEC`, 2 ms, has been spent in a frame, and always takes at least
  one cell. Since increment 4 that counts everything it does; see "And the work is done on worker threads", below.
- **The plan is redrawn every `REPLAN_EVERY`, 128 m of travel**, not every frame, and since increment 4 on a worker.
- **At boot it is all built at once:** `FlightLevel._build` calls `fill_around(eye)`, because a level loading is a load.
- **Reach is still the camera's far plane.** On the island every cell is within it of every other, so nothing is ever let
  go here; the rings do their work past about 40 km across.

`tests/scenery_rings.gd` drives the rings over the island tiled five by five (72 km, 1,484 cells), a picture only, moved
through `watch(eye, delta)`. Every distance is measured from the cells' own bounds, not asked of the yard.
- At rest: exactly the cells within reach are built, 389 of 1,053 rock cells.
- Across 40 km at 166 m/s: no cell comes within reach unbuilt (241 looks). A cell a kilometre inside reach of where the
  eye will be in 10 s is already built.
- Five laps of the orbit: 9 built, 0 let go.
- A 60 km jump: filled in over 11 frames, the worst 2,128 us against 2,000 plus a largest cell of 674.
- Let go: 0 of 296 batches still alive two frames later.
- On the island: every cell is built from each corner, the middle and the carrier.

Each check was driven RED first, one mutant of `world/scenery_yard.gd` at a time, restored byte for byte:

| broken on purpose | what failed |
|---|---|
| no hysteresis: let go the moment it is out of reach | circling: 65 built, 60 let go in five laps |
| no looking ahead | flown across: 136 cells within reach unbuilt; and circling, 12 built and 6 let go |
| no budget: every wanted cell in one frame | the 60 km jump filled in 2 frames, the worst 10,591 us against 2,000 |
| distance to the cell's square, not its bounds | at rest (1 missing within reach, 17 built beyond it); circling (147 built, 143 let go); let go (2 beyond the margin still counted) |
| let go without freeing | 296 of 296 batches still alive after moving 60 km |
| **the first version's let-go**, from the eye and the point ahead with half a cell of margin | circling: 25 built, 18 let go -- the bug exactly as it was found |

**The pictures did not move, but for one depth tie.** `tests/scenery_shot.gd --still`, all sixteen views on both finishes, two
launches of increment 2 and two of increment 3, alternated, on the stock editor:

- **18 of 32 pictures are identical before and after in both pairs.**
- The FINE views that differ do so by 1 to 21 pixels of step 1. Two launches of the same build differ by as much on those
  views (A against A up to 17 pixels, B against B up to 21), so that is launch noise.
- **`fields` PLAIN is the one real change: 210 pixels of step 2, the same in both pairs, where either build against itself
  differs by 0.**

Looked at (`godotgames-drafts/.../cockpit-streaming/inc3/diff-fields-plain.png` and `fields-plain-after-marked.png`): every
changed pixel is in the strip where the distant mountain on the left meets the grass (x 93 to 154, y 413 to 424). That
is the same strip increment 2's `fields` FINE change sat in. Rock and ground meet in one plane there, so which wins a
pixel is decided by draw order. Increment 3 builds and adds batches nearest the eye first, where increment 2 added them
in cell order, and that decides the tie the other way. By eye the before and after are the same picture.

**What the rings cost a frame, headless** (`tests/streaming_probe.gd --parts=rings --seconds=60 --speed=166`, double
editor, 2026-09-14, machine at 2% load at the end). The level's own yard and town layers, the eye flown round the
island's diagonals and edges at the plane's top speed, 7,200 frames at 120 Hz through `SceneryYard.watch`, each call
timed:

| world | cells over four layers | `fill_around` | `watch` mean | p50 | p99 | worst | frames re-planned | built / let go in flight |
|---|---|---|---|---|---|---|---|---|
| the island | 81 | 4.5 ms, 81 built | 3 us | 1 us | 112 us | 138 us | 78 | 0 / 0 |
| the island tiled 5 by 5, 72 km | 1,611 | 34.3 ms, 621 built | 31 us | 2 us | 2,470 us | 4,187 us | 78 | 148 / 136 |

- **On the island the rings cost nothing a frame can show.** 3 µs mean, and the worst frame is a re-plan at 138 µs.
- **On a 72 km world a re-plan is a 2.5 ms frame.** A re-plan walks every cell of every layer and sorts what it wants, in
  GDScript, every 128 m of travel. At 166 m/s that is about every 0.8 s. Increment 4 took it off the frame: see "And the
  work is done on worker threads", below.

**smoke's wall time, and why one run went past its 180 s deadline.**

The run that timed out, 2026-09-14 14:30, stopped 189 checks in, after `a_car_may_drive_across_the_ground`: the next
thing smoke does is settle the whole level with its traffic for 3,600 physics frames. It printed no error. The machine
was at 100 % CPU, with the clouds lane running six Godot processes and the voice, rota and steam lanes one or two each.
A rerun alone with a 480 s deadline passed in 231 s.

Back to back, smoke alone, only the three world files it loads swapped. A is increment 2, which is main b29f5f2 for
everything smoke loads; B is increment 3. Machine CPU and the other lanes' Godot processes were read at each launch's
start and end:

| launch | wall time | CPU % start/end | other Godot processes start/end |
|---|---|---|---|
| A1 | 143.9 s | 6 / 0 | 6 / 6 |
| B1 | 162.6 s | 6 / 3 | 6 / 10 |
| A2 | 163.8 s | 0 / 7 | 10 / 8 |
| B2 | 170.0 s | 2 / 5 | 8 / 4 |

- **B averaged 12.4 s longer, and was longer within both pairs**, by 18.7 s and then by 6.2 s.
- **But A's own two launches differ by 19.9 s**, and A2 — with no increment 3 in it — took longer than B1. Four launches
  cannot separate the two builds from the load.
- **What increment 3 does per frame in smoke, measured and read:**
  - the yard's `_process`, a camera lookup and a `watch()`: 3 µs mean, 138 µs at the worst re-plan, on the island
    (`--parts=rings`). Over the 3,600-frame settle that is about 0.01 s;
  - `fill_around` once per session build: 4.5 ms;
  - nothing else. Neither smoke's frame loops nor the level's per-frame functions call the yard or the towns; smoke asks
    `drawn_boxes` and `drawn_buildings` once each.

So the one per-frame change was switched off and timed against itself. B is increment 3; C is increment 3 with
`SceneryYard._process` returning at once, so everything is built at boot by `fill_around` and nothing is kept round the
eye after:

| launch | wall time | CPU % start/end | other Godot processes start/end |
|---|---|---|---|
| B1 | 141.9 s | 6 / 100 | 4 / 5 |
| C1 | 209.9 s | 100 / 85 | 6 / 10 |
| B2 | 166.0 s | 57 / 4 | 8 / 4 |
| C2 | 154.4 s | 1 / 2 | 4 / 6 |

- **The yard not watching was not faster**: C averaged 182.2 s against B's 154.0 s. C1 ran with the machine at 100 %.
- **Increment 3's fastest launch, 141.9 s, is the fastest of all eight**, faster than either of increment 2's (143.9 and
  163.8 s).
- **Verdict: the time is the machine's, not the rings'.** Across eight launches of three builds, smoke took 141.9 to
  209.9 s alone, tracking the load the other lanes put on the machine. The 180 s timeout was a run at 100 % CPU.
  Nothing measured puts a cost on increment 3 larger than launch-to-launch drift, and the rings' own per-frame work is
  3 µs.
- **The deadline is tight for everybody**: the steam lane measured 149.6 then 153.7 s alone on main with GodotSteam in.
  A deadline of 180 s against a suite whose quiet time is 142 to 154 s leaves about 15 % for whatever else is running.

**What the frame pays, windowed** (stock editor, d3d12, RTX 5080, `scenery_shot --hold-fires`, 240 frames, launches of
increment 2 and increment 3 alternated, 2026-09-14):

- **The GPU and the draws did not move.** Sixteen views on both finishes, A B A B. The GPU timer median after minus
  before is -0.037 to +0.004 ms on every view-finish, and draw calls are identical on all 32. On the island increment 3
  draws exactly what increment 2 drew; it only decides it round the eye.
- **That run's render CPU and script times were void, and are not quoted.** It straddled another lane's C++ build:
  compiler processes in 28 of 48 load samples, CPU at 48 % mean and 96 % at worst. After minus before ranged -2.7 to
  +1.5 ms against launch spreads of up to 4.6 ms.

- **Render CPU, rerun quiet: unchanged.** Five views on both finishes, three launches of each build alternated, every
  launch started with no compiler processes, and the machine at 4 to 14 % CPU from the second launch on. After minus
  before is 0.000 to +0.190 ms on all ten view-finishes, inside each one's own launch spread of 0.038 to 0.426 ms.
- **Main-thread script time cannot see the rings, and says so.** The frames' `process_scripts` median climbs with launch
  order, for both builds alike, by about 1.5 ms from the first launch to the sixth (`fields` FINE: 1.45, 1.80, 2.38,
  2.91, 2.62, 2.80 ms). Every after launch runs just after a before launch, so it rides the climb: after reads 0.2 to 0.4 ms
  higher within each pair, on `sea` (where nothing is built) as much as on `fields`. The rings' own work, timed directly
  (`--parts=rings`), is 3 us a frame, a hundredth of that drift. A script-time difference between builds needs launches in
  a balanced order (A B B A), not alternated pairs; nothing here is quoted as a cost.

### And a hand-built place loads on a thread

The user plans some hand-built airfields, imported models and textures beside the generated island. Since 2026-09-14
a place is a folder under `world/chunks/`, read at boot by `world/authored_chunks.gd` (`AuthoredChunks`), and drawn by
the yard as a **prepared layer**. The game has no place yet. `_template` is a working one the tests load by name, and
the `_test_*` folders beside it are broken on purpose.

**A place is `chunk.json`, `near.tscn` and optionally `far.tscn`:**
- `at`: metres, in the world;
- `yaw`: degrees, a vehicle's yaw;
- `reach`: metres; absent means the level's far distance;
- `boxes`: metres, in the place's own frame.

The folder name is the id, a folder starting with `_` is skipped, and a place that cannot be read is left out with a
warning.

**The rules, each for a reason:**
- **Collision is the manifest's boxes, never the scene's.** The boxes join `Terrain.boxes()`'s list in
  `FlightLevel._build`, as group `AUTHORED`, so they reach the simulation, the grid and the fire front on every peer at
  load (rule 8). A scene is loaded when one machine's eye comes near it. A shape inside it would be solid on that machine
  and air on the others, so a scene holding any collision object is refused where it is built (`refusal_in`).
- **A yaw is a quarter turn or nothing**, because `Sim.add_static_box` has no rotation. A quarter turn swaps a box's
  sides exactly; 45 degrees would collide somewhere other than where it is drawn.
- **The generator keeps off a place.** `Terrain.clearances()` includes each place's hull plus `AUTHORED_ROOM`, 150 m,
  as `why: &"authored"`.
- **Loaded on a thread, built only once loaded.** The yard's prepared layer calls `prepare` once when a cell is first
  wanted (`ResourceLoader.load_threaded_request`, `CACHE_MODE_REUSE`). It calls `readiness` each frame the cell is next
  in line (`load_threaded_get_status`). `build` runs only after readiness has said READY, because
  `load_threaded_get` on an unfinished load blocks like `load()` (Godot's background loading page, checked against
  4.7.2's API). A cell still loading goes to the back of the queue without holding up the rest. A cell whose load
  FAILED is warned about once and never built. `fill_around` does not wait for prepared layers.
- **A texture under `world/chunks/` imports VRAM compressed with mipmaps.** Headless import does not do the editor's
  detect-3D re-import, so the settings are written into the committed `.import`, and the suite reads them back.

`tests/authored_chunks.gd` checks each rule against something the reader did not compute (2026-09-14):

- **The scan** skips all five `_` folders, measured against the folder listing. The game has no place yet, so 0 places
  are read.
- **The template's box** stands at (12020, 1, 12000) with half-extents (10, 1, 40). That is where
  `Terrain.nose_from_yaw` puts a box 20 m behind a place turned a quarter, with its sides swapped. Its group is
  `AUTHORED`, and its near scene holds nothing that collides.
- **The broken places:**
  - bad JSON, no scene and a 45-degree yaw are each not placed;
  - the collision fixture's scene is refused by name: "Wall is a StaticBody3D, and collision is the manifest's boxes".
- **The contract, by spy:** a prepared layer answered WAITING three times and then READY. The yard asked 4 times,
  built once, never before READY, and not at all in `fill_around`. A spy that records the answers holds however fast a
  load finishes, which a timing check could not.
- **The real path:**
  - `add_to_yard` with the template requested its scene on a thread by `fill_around`;
  - the scene was built 142 frames later, headless, at the place's own transform, with nothing in it that collides;
  - it was let go and freed once the eye was 60 km away.
- **A failed load** is never built.
- **The import rule:** the one texture under `world/chunks/` imports with `compress/mode=2`, `mipmaps/generate=true` and
  `detect_3d/compress_to=0`, read back out of its `.import`.

Each check was driven RED first, one mutant at a time, every file restored byte for byte:

| broken on purpose | what failed |
|---|---|
| the yard builds a prepared cell without asking whether it is ready | the spy: asked 0 times, 1 build before READY; and a FAILED cell built |
| the yard builds a cell whose load FAILED | the failed cell built |
| a scene's collision is not refused | the collision fixture's refusal read '' |
| a yaw off a quarter turn is let through | `_test_yaw_45` accepted |
| a box placed without its place's turn | the box at (12000, 1, 12020), wanted (12020, 1, 12000) |
| the scan reads the `_` folders | `_template` and `_test_collision` read as places |
| the template's texture imports lossless with no mipmaps | read back as `compress/mode 0, mipmaps false` |

**The island did not change.** `tests/streaming_probe.gd --parts=dump` with 3b in writes the generated world out whole:
- `boxes()`: 984;
- the roads: 7;
- the keep-outs: 1,612;
- both finishes' trees: 1,892 PLAIN and 3,768 FINE.

`Terrain.clearances()` now asks the place catalogue, and the file hashes to `9D0C4D1F…`, the same as at increment 0.
With no place in the game, the catalogue adds nothing, and the island is the same record for record.

With 3b in:
- `lint`, `docs`, `world_map`, `scenery_yard`, `scenery_rings`, `scenery`, `towns` and `forest` pass;
- `smoke` alone passes in 119.7 s at 5 % CPU, `the_picture_is_the_same_list_as_the_physics` still 984 drawn against
  984 solid.

### And the work is done on worker threads

Since 2026-09-14 the yard's two main-thread costs run on `WorkerThreadPool` (`world/scenery_yard.gd`): the plan, and each
cell's MultiMesh buffer. What a frame still pays for is copying what a plan reads, putting finished buffers on nodes, and
letting cells go. Before, on the island tiled to 72 km, a re-plan was a 2,470 µs frame at p99, and one cell's batch took up
to 674 µs.

**A layer is one of three kinds, by what a cell needs before it can be built:**
- `add_layer(name, bounds, reach, parent, build)`: nothing. `build(cell)` makes the nodes on the main thread.
- `add_worked_layer(name, bounds, reach, parent, work, build)`: numbers. `work(cell) -> Dictionary` runs on a worker, and
  `build(cell, done)` puts what it returned on nodes. Rock, concrete, the railway, the buildings and the paint are worked
  layers. This is the kind for anything generated, such as a terrain chunk's mesh.
- `add_prepared_layer(...)`: something the layer starts and owns, such as 3b's threaded `ResourceLoader` load.

The design had `add_prepared_layer` gain a `loads_at_fill` flag instead. A third kind of layer changed no caller.

The rules, each for a reason:

- **A worker reads, never writes, what the main thread owns.**
  - A layer's lists and bounds are complete when it is added and never change size afterwards. Godot's thread-safety
    page allows reading a container from several threads, but not resizing it.
  - A task writes only into a Dictionary made for it, which the main thread reads once
    `WorkerThreadPool.is_task_completed` says so.
  - `work` touches no node, no `Sim` and nothing of the yard's. It names its class for the static it calls
    (`SceneryYard.box_buffer`, `TownView.building_buffer`), so the lambda reaches for nothing of the node it was made in.
- **`MultiMesh.buffer` is 12 floats of transform an instance, then 4 of colour if the MultiMesh carries colour, then 4
  of custom data if it carries that.** The transform is the basis's three rows, each followed by that row's origin
  component. The class reference does not say so. The layout was read from Godot 4.7's
  `MeshStorage::_multimesh_instance_set_transform` and is held to the engine by
  `tests/streaming_probe.gd --parts=buffers`, windowed. That part fills MultiMeshes a call an instance, reads the real
  renderer's buffer back and compares it float for float: 58 batches and 11,760 floats, every one identical, the worst
  difference 0. The batches are every rock and concrete cell on the island, 64 banked pieces of railway (so no basis is its own transpose), 40 made-up buildings with custom data and 40
  yawed slabs with colour. RED, windowed, the yard restored byte for byte after each: with the transform written column
  for row, the railway's third float read 8.417 where the engine had -0.286; with the first float of colour and custom
  data left unwritten, a rock cell's thirteenth read 0 where the engine had -5,336.8. Headless has no buffer to read
  back, which is why this is a probe part and not a suite.
- **A finished plan is used unless the eye has jumped** more than `LET_GO_BEYOND` from where the plan was made, or
  `fill_around` has run since. Within that distance every cell it lets go is still out of the eye's reach, and every cell
  it wants is still inside the margin. The first version dropped any plan a newer one had been asked for while it ran,
  and an eye moving faster than a plan could be worked out never had one used: 28 dropped and 0 used across 40 km.
- **The plan's task is high priority and the cells' work low**, because `add_task` runs high-priority tasks first. A
  plan never queues behind a thousand cells.
- **Finished cells are built first, in the order their work started (nearest first), and only then is new work
  started.** Queued behind the not-yet-started cells, a near cell's finished buffer waited for every far cell to be
  started.
- **`watch`'s 2 ms budget counts everything it does from its first line**: taking and asking for a plan, letting go
  (first, with a quarter of the budget, since it bounds memory), building and starting. It always asks about at least
  one cell.
- **The queues are read by an index, not `pop_front`**, which moves every key behind the one it takes. A plan on a
  72 km world wants a thousand cells.
- **Every task is waited for, taken or dropped**, because `add_task`'s page says what a task allocated is freed only
  then. A task still running when the yard is freed is waited for in `NOTIFICATION_PREDELETE`.
- **At boot, `fill_around` plans on the main thread, starts every cell's work at high priority and waits for it.** A
  level loading is a load.

**A suite's frames are not a flight's.** A headless suite drives thousands of frames in the time a worker takes to plan
once. Unpaced, `scenery_workers` flew 21,686 frames in about a second, and the eye crossed 40 km in it. So:
- `tests/scenery_rings.gd` calls the yard's `catch_up()` seam after every `watch`. It waits for the workers and takes
  their plan, as a flight's frames would.
- `tests/scenery_workers.gd` paces its flight at four times real time.
- One rings check moved: its first look is now a second into the flight, not on frame 0. On frame 0 the plan that frame
  asked for is still on its worker, and 3 cells counted as late. Every later look found none.

`tests/scenery_workers.gd` (2026-09-14):
- **Off the frame.** With every cell's work slowed to 50 ms by the shipped `work_delay_msec` seam (read inside the
  work, so work done on the main thread sleeps too), 27 cells arrived over 817 frames. The worst `watch` took 883 µs,
  against 50,000 µs for one cell's work. Once the eye went 200 km off the map, the 150 cells being worked on dropped
  to 0, and none of them was built.
- **Streamed in, the list.** Nothing filled: 55 of 55 rock and concrete cells arrived through `watch` in 4 frames, and
  drew the 607 boxes the list has, each once, with the size, place and peak read from the boxes themselves.
- **The plan off the frame.** Across 10 km of the 72 km world at 166 m/s, paced at four times real time, 78 plans came
  from workers, 0 were dropped and 0 were worked out inside `watch`. The longest plan took 3,874 µs on its worker.
  `watch` was 12 µs at p50, 210 µs at p99 and 602 µs at worst over 5,421 frames.
- **A stale plan.** With the plan slowed to 200 ms, the eye jumped 60 km and back inside one plan's run: 1 plan was
  dropped, 1 used, and nothing was built or let go for it.

Each check was driven RED first, one mutant of `world/scenery_yard.gd` at a time, restored byte for byte:

| broken on purpose | what failed |
|---|---|
| a worked cell's work done on the main thread, inside `watch` | the slow-work check: the worst `watch` 52,521 us against one cell's 50,000 |
| the plan worked out inside `watch` | the flight: 78 plans inside `watch`, `watch` at p99 2,656 us and worst 3,957 us; streamed in, 1 plan inside `watch` |
| a plan the eye has jumped away from is used | the stale plan: 303 cells built for where the eye had jumped to |
| the work makes the buffer about a different middle from the one the batch stands at | streamed in: boxes drawn where the list has none; and `scenery_yard`, every rock and concrete box and every peak |
| a cell no longer wanted keeps its work | off the map: 147 cells built after the plan that no longer wanted them. The check's first version, which counted only the cells left being worked on, passed this mutant |

**The pictures did not move.** `tests/scenery_shot.gd --still`, all sixteen views on both finishes, two launches of
increment 3b and two of increment 4, alternated, on the stock editor (2026-09-14, no compiler processes, 1 to 9 % CPU):

- **23 of 32 pictures are identical before and after in both pairs, and all sixteen PLAIN views are identical in every
  pair.**
- The nine FINE views that differ do so by 1 to 50 pixels, every one of them by a single step of one channel. Two
  launches of the same build differ by as much on those views: 3b against itself by up to 18 pixels, increment 4
  against itself by up to 32. That is launch noise.
- Looked at (`godotgames-drafts/.../cockpit-streaming/inc4/`): the mountains' shaded steps, the town's painted grid and
  buildings, and the runway with its paint and the towns beyond it are as they were. Every one of them is now drawn from a
  buffer a worker wrote, so the identical PLAIN pictures are that buffer checked pixel for pixel on a real renderer.

**What the frame pays, windowed** (stock editor, d3d12, RTX 5080, `scenery_shot --hold-fires`, 240 frames, 3b and
increment 4 launched A B A B, 2026-09-14; every launch started with no compiler processes and the machine at 0 to 12 %
CPU). Sixteen views on both finishes:

- **The GPU and the draws did not move.** GPU timer median, after minus before: -0.001 to +0.009 ms on every
  view-finish. Draw calls are identical on all 32.
- **Render CPU did not move:** -0.173 to +0.058 ms, inside each view-finish's own launch spread (up to 0.418 ms).
- **Main-thread script time went down where it moved at all:** the frames' `process_scripts` median, after minus before,
  is -0.855 to +0.203 ms, negative on 27 of 32. The spreads are wide (up to 1.79 ms on `clouds`), and two launches each
  are not enough to quote a saving. On the island there is nothing to re-plan, so none was expected.

**What `watch` costs a frame now, headless** (`tests/streaming_probe.gd --parts=rings --seconds=60 --speed=166`, double
editor, 2026-09-14). Increment 3b (A) against increment 4 (B), launched A B A B, 7,200 frames at 120 Hz each, round the
island's diagonals and edges and then the island tiled to 72 km. Every launch started with no compiler processes and 6
to 8 other lanes' Godot processes, and the machine was at 1 to 25 % CPU. B's probe calls `catch_up`, untimed, after each
timed `watch`, as a flight's frames would give the workers time:

| world | build | `fill_around` | `watch` mean | p50 | p99 | worst |
|---|---|---|---|---|---|---|
| the island | A | 3.7, 3.5 ms | 3, 3 us | 2, 2 us | 113, 115 us | 154, 220 us |
| the island | B | 4.8, 5.8 ms | 3, 3 us | 3, 3 us | 14, 13 us | 41, 64 us |
| tiled to 72 km | A | 34.1, 33.9 ms | 31, 31 us | 2, 2 us | 2,507, 2,529 us | 4,090, 3,812 us |
| tiled to 72 km | B | 41.2, 39.6 ms | 5, 5 us | 3, 3 us | 64, 61 us | 294, 293 us |

- **On the 72 km world, `watch` fell from 2.5 ms at p99 to 62 us, and from about 4 ms at worst to 294 us.** All 78
  plans came from workers, none were dropped and none were worked out inside `watch`. The most one cell took to build on
  the frame was 150 us, against 674 us before.
- **Both builds kept the same cells:** 78 re-plans, and 148 built and 136 let go in flight.
- **`fill_around` got slower, though it now runs every cell's work on every thread:** 1.2 to 1.6 times what it was, 40 ms
  at load on the 72 km world. Not taken apart. The work writes each instance's floats one at a time in GDScript, where
  the old batch made engine calls. It is paid once, at load.

### And what is let go is kept, a bounded number of cells

Since 2026-09-14 (increment 5a) a worked cell's finished numbers outlive its nodes. `SceneryYard` holds the Dictionary
each built cell was made from. When the cell is let go, or a plan drops finished work for a cell it no longer wants, the
yard keeps that Dictionary: the last `KEEP_CELLS`, 512, over every worked layer. A cell wanted again is ready at once and
built from what was kept, with no work started.

The rules, each for a reason:
- **A bounded number of cells, not of bytes.** A layer's numbers are whatever its `work` returns: a MultiMesh buffer and
  its records here, a terrain chunk's arrays later. Counting cells needs no guess at what a Dictionary costs, and the
  suite measures what they cost here.
- **The oldest let go is the first dropped.** A Godot Dictionary keeps the order its keys went in, so the first key is
  the one to drop. A cell built again leaves the list.
- **Finished work a plan drops is kept too.** Work still running is left to finish and be reaped, not waited for.
- **What is held for a live cell costs its buffer and no more:** `placed` and the rest are the same Arrays the batch's
  metas hold.
- **`keep_cells` is a shipped seam**, `KEEP_CELLS` in the game, so a suite can keep nothing.

`tests/scenery_memory.gd` (2026-09-14) flies the island tiled to 72 km, a picture only, with the workers caught up after
every `watch`:
- **Turning back.** Filled at home, the eye was moved 6 km away until nothing changed for 30 frames, then home again
  with no velocity. 65 cells were let go on the way out and 65 built on the way back, all 65 from what was kept, with 0
  works started. Every rock cell within reach of home was built.
- **Memory.** A lawnmower of three 60 km rows: 220 km at 166 m/s, 39,759 frames at 30 Hz, with a real frame after each so
  freed nodes are gone before they are counted. In all, 2,493 cells were built and 2,141 let go. The last third may not
  pass the first third's peak by more than 5 %, and the cells kept may never pass the bound. Peaks, by third of the
  flight:

| | first | middle | last |
|---|---|---|---|
| live cells | 635 | 680 | 590 |
| nodes in the tree | 643 | 688 | 598 |
| static memory | 66.5 MB | 67.9 MB | 67.4 MB |
| cells kept | 512 | 512 | 512 |

- **What keeping costs:** the same flight keeping nothing peaked at 65.2, 65.6 and 65.0 MB. So 512 cells kept here cost
  about 1.3 to 2.4 MB, some 3 to 5 KB a cell. A terrain chunk's arrays will be bigger; measure them before trusting 512.

Each check was driven RED first, one mutant of `world/scenery_yard.gd` at a time, restored byte for byte:

| broken on purpose | what failed |
|---|---|
| nothing kept: an LRU of 0 cells | turning back: 65 works started, 0 cells built from what was kept |
| nothing let go | memory: live cells 1,068 / 1,405 / 1,611, nodes 1,076 to 1,619, static 69.3 to 75.3 MB |
| no bound on what is kept | the bound: 626 / 976 / 1,259 kept against 512. Static rose from 66.5 to 69.7 MB, 4.8 %, inside the 5 % slack, so the count is what catches it |
| a kept cell's work started anyway | turning back: 65 works started |
| a let-go cell's numbers not kept | turning back: 65 works started, 0 from what was kept |

**The island does not change.** Every cell on it is within reach of every other, so nothing is let go and nothing is
kept. The functions that build a batch are the ones increment 4's pictures and cost A/B measured.

## WATER THAT IS NOT THE SEA: SHORES, RIVERS AND CANYONS (lane/rivers, 2026-09-20)

The user: *"On some levels we have gaps for rivers and lakes but i'm not sure if we have taken the time to make sure
they work. near these the ground and water should look different on the shore... let's make sure we have some deep
200-300meters that have a river in them (50m wide) and a high mountain on both sides so we can fly through them...
being able to place rivers through a mountain pass might make building maps much easier."*

The survey came first, and it answered a question nobody had asked out loud: **there were no rivers in the game at
all.** The ground function made a coast, ranges, valleys, lakes, towns and pads, and no watercourse of any kind; the
only thing named "River" in the repository was a prop in the combat reel's scene. The lakes were real, correct and
drawn -- and carried a bug that had shipped for three days.

### Thirty of the fifty-four lakes were given the open sea's swell

`WaterSurface.dressed` handed every water surface `land_half = Terrain.WORLD_HALF`, **7,200 m -- the ISLAND level's
half-width -- on every level.** Both ocean shaders fade their vertex displacement in over `max(|x|,|z|) - land_half`
from 40 m to 260 m. The lakes exist only on the generated levels, which put them wherever the hash puts them: out to
19 km.

`tests/rivers_survey.gd`, 2026-09-20: **30 of 54 lakes on the five generated levels stood outside that band at a
motion factor of 1.00 of full.** Alpine's westernmost is 27 m above the sea and 15.3 km out, and it heaved with the
open swell while `Terrain.water_height` -- what a hull floats on, and where `LakeSheets` lays its vertices -- stayed
flat.

**Both `lake_sheets.gd` and `sea_surface.gdshaderinc` carried a doc block saying a lake is inside the coast band and
so still.** True on the island; false everywhere a lake actually is. A doc block is not a check.

- **The fix:** inland water SAYS it is inland (`WaterSurface`'s `inland`), instead of being inferred from a radius.
- **Withholding the swell was not enough:** `ocean_fine.gdshader`'s `swell_steepness` defaults to 0.15 *in the shader
  file*, so a lake on FINE chopped with nothing handed to it.
- The motion gate moved into one place, `shaders/still_water.gdshaderinc`: `ocean.gdshader`, `ocean_fine.gdshader` and
  `sea_surface.gdshaderinc` each typed the same two lines, on a number a wake must agree with to the centimetre.
- **The probe first passed having measured nothing.** `JSON.parse_string` gives floats, `configure` refuses
  "world_half is not an int", every catalogue came back empty, and the loop reported zero lakes outside the band:
  RESULT=PASS, 0 lakes. The tautology trap's other face -- not a check that cannot fail, but one that passed because it
  measured nothing.

### A lake has a shore now, and a photograph moved the plan

The `land_half` fix was green and the sea was unchanged, so the work looked done. A picture of a lake from the air said
otherwise: the water was the ocean's near-black `deep_colour` in green grass, **the sheet's outline was a visible
staircase of 16 m squares**, and the rim read as a grey kerb. All three green in every suite, because an outline is
what a headless suite cannot see.

- **The waterline is solved, not snapped.** A cell was drawn whole if any one corner was wet. Each cell is now clipped
  to where the ground function's depth crosses zero, with the crossings SHARED between the two cells either side of an
  edge -- worked out per cell they differ in the last bit and leave a crack of daylight along every boundary.
  Vertices standing over ground higher than their own lake's level by more than 0.35 m, grid against solved edge:
  6.88 to 0.26 %, 7.78 to 0.19 %, 11.02 to 0.00 %, 7.70 to 0.11 %, 7.54 to 0.17 % on adriatic, alpine, gliders,
  testfield and trace. Worst single overshoot 96 m, then 36 m.
- **The depth rides in `ARRAY_CUSTOM0` as one float32, not in the vertex colour.** `ARRAY_COLOR` is eight bits a
  channel: every depth over 1 m clamped and the whole grading collapsed into the first metre. Normalising would have
  fitted it at about ten quantisation steps across a 0.45 m shore band, which is how a smooth shallow reads as contour
  rings.
- **The sand band was keyed to sea level written as a number.** `smoothstep(1.5, 5.0, height)` against ABSOLUTE
  height, and every lake stands between 13 and 126 m, so **not one of them had a beach**. Against `height - water` the
  sea keeps exactly the beach it had, because its level is 0 out there.
- **STILL WRONG, and asked about rather than done:** the ground function raises a rim round every lake, holding the
  land 2 m up for about 90 m out, to hide the drawn water's outer edge. The edge is now cut at the waterline, so the
  rim may have no job left -- but removing it moves every recorded world hash.

### A river is a line the level draws, and the canyon is built round it

A level's `rivers` block gives a centre line, the water's width and the canyon's depth. `GroundField` cuts the bed and
stands the water in it; `Watercourse` turns the same declaration into two `MountainRange` walls either side and a chain
of keep-outs down the corridor. The corridor comes from the width, the wall's offset and foot from the depth, the
keep-out's floor from the water. **A world that names no river is bit for bit the world it was** -- the bargain `coast`,
`sites_within` and `pads` were added on.

**The depth is the walls' number, not the cut's.** A 250 m slot cut into ground standing 100 m above the sea has its
floor under the sea, and most of the generated lowland is under 130 m. So the canyon's depth is the height of its rim
over its water, which is what a pilot in it experiences.

`cockpit/levels/canyon/`, "The gorge", measured by `tests/canyon.gd`: the river is the 50 m asked for, the water falls
72 m head to mouth and climbs at 0 of 75 stations, **the canyon is 305 m deep on the mean against a 260 m ask with 0 of
76 stations short and the shallowest 214 m**, and the floor is clear to 5.5 m over the water across a 220 m corridor.

#### Two hours were spent tuning the wrong number

The first gorge measured **191 m against a 260 m ask**. Raising the wall's crest from 1.3 times the depth to 1.6 moved
it to 200 m, and that 9 m was the clue: the crest was never the binding constraint. **Rock may climb out of a keep-out
at `kClearRise`, six fifths of a metre a metre, and no steeper**, so a ridge one depth outside the corridor cannot
stand more than 1.2 x that run above the keep-out's edge whatever crest it is given. Moving the ridge to 1.35 depths
out gave 241 m; 1.6 gave 305 m. *When a change to the obvious knob moves the number by five per cent, the knob is not
the constraint.*

**Rejected, each with its number:**
- *A keep-out margin to clear the floor.* What stood at the corridor's edge was the UNCUT hillside, not rock. Widening
  the keep-outs by one mountain spacing moved none of it -- **the failing values came back identical to the metre** --
  and cost 16 m of mean depth, because pushing the talus out lowers the rock everywhere the rim is measured.
- *Levelling the water at the control points.* A level author puts them kilometres apart, and where the ground dipped
  between two the surface stayed on the straight line and stood **46 m over the valley floor: a wall of water 50 m
  wide**. The level is worked out every 32 m along each leg now.
- *Walls that stop where the river's line stops.* A ridge tapers to nothing at its last control point, so the rim at
  the head measured **9 m BELOW the water**. Two depths of overrun puts the taper outside the river.

#### And the concealment is measured, against the game's own sight

**This check first marched its own ray**, because a survey for `line_of_sight`, `can_see` and `occlu` found nothing in
the project. Two lanes made that survey the same night and both were wrong the same way:
`CockpitWorld.ground_leg_is_clear` has answered exactly this since the generated ground landed, over both the height
fields and the mountain triangles through one shared max-pyramid, and it is **named for a flight leg** because the
autopilots needed it first. `SightLine` (lane/flatcrew) is the name for it, and it is the only answer -- a hand-rolled
sampler would have been a second opinion about where the ground is, so a canyon could have hidden a fighter from the
test and not from radar.

**The bias is one-directional and stated:** the pyramid may call a CLEAR line blocked and never a blocked one clear, at
the grain of a 32 m square. Read as concealment, terrain hides slightly MORE than geometry alone, so a canyon designed
at its nominal depth cannot be exposed in the game by a rounding.

Measured over the whole run -- every station of the river, at 60 m over the water:

- **100 % of the run is concealed** from the abeam observers 6 km out and 800 m over the rim, 7.6 degrees of
  look-down: **0 of 456 sight lines clear.**
- Down the canyon's axis 114 of 456 are clear, which is what a canyon cannot help and never has.
- Swept upward: 0 % seen at 1.9, 3.8 and 7.6 degrees, 3 % at 14.9, **43 % at 28.1 degrees** -- where cover goes.
  Reported rather than required, so the angle is a number in the log instead of an assumption in a head.
- **The control:** the same craft on open ground is seen from 67 % of the same observers.

**AND THE CONTROL EARNED ITS PLACE ON THE FIRST RUN.** With `SightLine` wired in, the check reported 456 of 456 abeam
lines CLEAR -- including lines straight through 300 m of rock. The world had not been `start()`ed before `set_ground`,
so it held no ground, and `SightLine` answered its safe default (true, nothing in the way) for every line. What gave it
away was **the control scoring 100 % as well**: a concealment check on its own would have read "0 % concealed" as a
finding about the canyon rather than about the instrument.

**NOT fixed here:** a regular crenellation along the canyon floor's edge, visible from the air. The evidence says it is
in the ground and not the rock, and todo/rivers--canyon-floor-crenellation.md has three places to look, with
the cheapest first.

### A level says how fine its rock is cut, because a machine cannot

The user: *"we should be able to tweak the quality there so we can up or downgrade the poly count based on our
needs."* A level names `rock_spacing`, the metres between the mountain grid's vertices. The quads a side of a tile move
with it so **a tile keeps its 1,920 m** -- a tile is a draw call and a culling unit, and how much world it holds should
not change because somebody asked for finer rock. A level that names nothing gets the rock it always had.

Measured on the island's ranges (`tests/rock_quality.gd`):

| spacing | triangles | tiles | build |
|---|---|---|---|
| 96 m | 11,278 | 37 of 20 quads | 7.5 ms |
| 48 m | 41,762 | 37 of 40 quads | 25.6 ms |
| 24 m | 157,398 | 37 of 80 quads | 95.1 ms |

The triangles follow the inverse square (3.70x and 3.77x against the law's 4.00x; the rest is edge tiles being partly
empty). **And it is the same mountain**, which a triangle count cannot check: across the whole sixteen-fold range the
summit moves 17.2 m, and of 400 points spread over the ranges 3 move more than 60 m, the worst by 69.9 m, all on steep
faces where a coarser grid cuts the corner off a cliff.

**IT CANNOT BE A PER-MACHINE SETTING, and that 69.9 m is the proof.** The lane's brief asked for the dial to go on
`DetailReach` (distance) or `Finish` (the PLAIN/FINE tier a player flips with a thumb). Both are per-machine by design;
the mountains' triangles ARE their collision, static collision is not replicated (RULES 8), and every peer builds its
own rock from this number. Two peers at different qualities would stand rock 70 m apart on exactly those faces, and a
peer whose hillside is elsewhere predicts itself into the server's. So it is a level's number, agreed by everyone on
the map -- which is also what "based on our needs" means when the need is building a map.

### Three optional ground keys: no sea, sites inside a reach, and airports the level lays (lane/testfield, 2026-09-19)

For the test field (the user, 2026-09-19: "a larger map (with no ocean) that has runways on either side"), `GroundField.
configure` takes three optional keys beside the required three. Absent, each has the value every recorded world was
built with, so `tests/ground_field.gd`'s recorded hashes are unchanged, and a section of that suite names all three at
their defaults and gets the same hashes.
- **`coast`**, in 32nds of `world_half` (16 to 128, default 21). The land fraction is 1 - r^2/coast^2, plus noise of
  at most +-0.54, so at 96 it stays above 0.24 even in the corner and there is no sea. Measured on a 512 m lattice of
  the 65 km square at peak 300: 11,343 sea samples at 21, 0 at 96, the lowest ground 1.5 m. Lakes stay.
- **`sites_within`**, in metres (0 means anywhere). Towns, lakes and the ground's own strips are catalogued only with
  their centres inside it. All-land otherwise catalogues sites out to the corners, and `Terrain.placed_reach` pushes
  the edge band past the wire. At 20,500: 43 sites, the farthest 20,195 m out.
- **`pads`**: the airports a level lays. Each is a rectangle flattened at the mean of the ground over it (9 by 9
  samples, before lakes) and blended back over `margin`. Each has up to 8 FUNNELS, one per runway end,
  `[x, z, dir, length, half_width]`, and inside a funnel no ground stands above the pad's level plus one metre in 34
  out (TERPS's precision obstacle clearance surface). OUTSIDE a pad the ground is held within 1 in 8 of its level (a
  cutting or an embankment), and outside a funnel's strip its cap rises 1 in 8 with the distance from it, behind the
  end and past the far end too, so a ridge across a final is cut as a valley no steeper than 7.1 degrees. See "The cuts"
  under THE TEST FIELD for the first version, fixed-width smoothsteps, which stood at up to 49.9 degrees. Lakes and towns keep clear of every pad and funnel,
  and a world with any pad finds no strips of its own. A malformed pad leaves no ground, since a half-read pad is an
  airport on a hillside. Measured: a 800 m by 4 km pad with two 10 NM funnels at peak 300 flattens every sample of its
  rectangle to 102.62 m. Along both finals, 0 samples stand above 34:1 with it and 2,531 without it.
- `catalogue()` gains `pads` (each with the level found) and `catalogue_ints` appends them after the strips, so the
  ground's own hash covers them.

Rejected: a wider island slab with MountainRange ridges. It is flat with no rolling land, and every island function
(spawns, fires, lift, waypoints, fleet, gates, city) would have needed a third case. Also rejected: letting the test
field's airports go where the ground's own strips fell, because those are 1.8 km strips, and a 747 airport laid where
its file says needs the ground to make room.

### And a cell is drawn at a level

`SceneryYard.add_level_layer(name, bounds, reaches, parent, work, build)` is a worked layer drawn at a LEVEL by distance,
for the terrain: level 0, the finest, within `reaches[0]` of the eye, level k within `reaches[k]`, and nothing past the
last. `work(cell, level) -> Dictionary` runs on a worker and `build(cell, level, done)` puts it on nodes. The shape was
agreed with cockpit-streaming before the file was touched.

- **Finer at once, coarser late.** A cell goes finer as soon as the nearer of the eye and the point ahead is within a
  finer reach. It goes coarser only once the eye itself is past the drawn level's reach plus `LET_GO_BEYOND` and the
  swing: the let-go rule, applied between levels.
- **A swap is a build.** It is queued, budgeted and built after its work like any cell. In `_attach` the new level's
  nodes go into the tree before the old level's are freed.
- **Every key of work in flight carries its level**: the queue, the working list, `_started`, `_slots`, `_failed` and
  `_kept` are keyed by Vector4i. The built cells (`_live`, `_held`, the let-go list) stay Vector3i, and `_level_of` says
  which level each is drawn at. A layer with no levels is level 0 throughout, so the rock, the towns and the authored
  places passed their suites unchanged.
- **The old level's numbers are kept under their own level**, so swapping back starts no work.

Held by spy layers over the tiled island's rock cells, at reaches of 4 and 12 km, with what is drawn read off the spy's
nodes and never asked of the yard:
- at rest, every cell is drawn once at the finest level its distance allows (14 at level 0, 79 at level 1);
- flown 40 km at 166 m/s: 175 swaps, 0 frames where a cell within reach had nothing drawn, 0 where one had two;
- circling 300 m round a cell 120 m off level 0's edge: 0 swaps after the first lap;
- 6 km out (18 swaps to the coarser level), 22 km out (74 let go), and home: 98 builds, all from what was kept, 0 works
  started, every one handed its own cell's and level's numbers (`tests/scenery_rings.gd`, `tests/scenery_memory.gd`).

Each rule was driven RED by a mutant of `world/scenery_yard.gd`, restored byte for byte:

| broken on purpose | what failed |
|---|---|
| a level change as a let-go and a build: the plan frees the old level, and the new one arrives when its work does | the flight: 108 cells within reach left with nothing drawn; and going out, 0 swaps |
| coarser as soon as the eye is past the reach, with no margin | circling: 110 swaps in five laps |
| numbers kept under the other level | turning back: 65 works started; coming home, 80 works started and 18 builds handed the other level's numbers |
| a swap that throws the old level's numbers away | coming home: 18 works started |
| a build that takes whichever level was kept for its cell | coming home: 18 builds handed the other level's numbers |

**A count of builds handed the wrong numbers needs a cell with both levels kept.** The flight never swaps back, and a trip
6 km out and home keeps only one level for any cell, so the last mutant passed both. The trip home goes by way of 22 km,
where the cells swapped coarse at 6 km are let go with their coarse numbers kept beside their fine ones.

### And the ground is drawn, a level at a time

`GroundView.show_ground(field, yard, far)` (`world/ground_view.gd`) lays the C++ ground into a yard as one levelled layer,
"Ground". No level calls it yet; the level switch that stands a world on the ground is the next step.

- **Every cell with a 64 m sample above −60 m is drawn**: 2,015 on the alpine world, found in 125 ms. That is 20 m below
  the collision's −40 m, because 64 m samples can miss a 16 m one the collision counts. The suite finds all 1,799
  collision cells among them.
- **Levels by distance to a cell:** 16 m within one cell, 32 m within three, 64 m within six, 128 m out to `far`. No 256 m
  level, which would move a 60-degree ridge 900 m.
- **The picture is the collision.** A cell's vertices are the function's samples, and at level 0 each square is split on
  Box3D's diagonal. At level 0, 50,700 vertices of the 12 highest cells are the function's heights to the tick, and Box3D
  rays at random triangles' middles land within 0.122 mm.
- **A coarser square is split on the diagonal that follows the crest**: the one whose middle is nearer the function's
  height at the square's middle, a tie on Box3D's. On one fixed diagonal a crest lying across the squares was drawn as a
  sawtooth. In the 12 highest cells 6,709 of 12,288 squares turn at 32 m, 1,716 of 3,072 at 64 m and 436 of 768 at
  128 m, and the drawn middles stand 2.62 m off the function on average against 4.97 m. The crest crop's turns of light
  and shade fell from 223 to 133 on the snow crest and 149 to 97 on the dark face (report 8k).
- **A skirt down every edge, sized against every other level**, not only the next. The yard coarsens late at speed, so a
  16 m cell can stand beside a 64 m one. Along the 24 neighbour edges of the highest cells, at every pair of different
  levels, all 18,720 gaps are spanned; the widest is 100.5 m, 16 m against 128 m.
- **Lit a pixel at a time from a normal map baked for each cell** (`world/shaders/ground_view.gdshader`). Normals worked
  out at the vertices and interpolated across 32 m and 64 m quads drew pale vertical streaks down every steep face. On
  far.png's steep 32 m face the turns of light and shade summed over rows fell from 1,147 to 397 (8 levels). The map has
  a texel every 16 m at the 16 m and 32 m levels (65 a side), 32 m at 64 m (33) and 64 m at 128 m (17). Each texel is the
  function's normal a texel either side, to a byte. One heights call a cell on a grid at that texel gives the map, the
  vertex normals, the mesh and the crest middles. The map was chosen over the function in the fragment shader by measured
  cost: GPU-bound at 3840x2141 and scale 2.0 on the double editor, PLAIN, the map cost what vertex normals cost (2.76 to
  2.87 ms against 2.77 to 2.87) and a 19-lookup stand-in for the function 5.73 to 6.04 ms (report 8l).
- **A STATED LIMIT: a coarser map's light is not the finest map's.** At the texels they share it stands 0.0 degrees off at
  32 m, 0.9 on average and 7.7 at worst at 64 m, and 2.8 on average and **21.8 at worst at 128 m**. A 128 m cell is drawn
  past 6 km, where that 64 m texel is the ground's light filtered to its distance. Accepted by team-lead (2026-09-15).
  Where a pilot sees a 128 m cell's light jump as it becomes a 64 m one, this is why.
- **The colour from the slope the drawn triangles have**, in the vertex colours. That is the rock rule that removed the
  probe's beaded valley lines. It is chosen per vertex, so the snow and rock edge is still feathered along the 16 m
  triangles near the eye; colour by slope per pixel belongs to the surface shaders' step.
- **The work is on a worker**, and a cell worked on a thread is the cell worked on the main thread, array for array
  (2026-09-15, with the crest middles and the normal map):

  | spacing | triangles | double editor | stock editor |
  |---|---|---|---|
  | 16 m | 9,216 | 15.7 ms | 4.8 ms |
  | 32 m | 2,560 | 8.9 ms | 2.7 ms |
  | 64 m | 768 | 2.6 ms | 0.9 ms |
  | 128 m | 256 | 0.95 ms | 0.31 ms |

  One 65 by 65 map at every level cost a 128 m cell 5.94 ms on the double editor. Matched to the level it is 0.95 ms,
  under the 2 ms team-lead set before a C++ bake. A C++ `GroundField.cell_arrays` stays the answer if that work shows in
  a frame; it is not the frame's today.
- **In a yard**, filled over the highest cell at 3,500 m, every cell within reach is drawn once at the finest level its
  distance allows (9, 36, 92 and 342 cells at 16, 32, 64 and 128 m), with that level's vertex count.

`tests/ground_view.gd` was driven RED by four mutants of `world/ground_view.gd`, each restored byte for byte:

| broken on purpose | what failed |
|---|---|
| a skirt only its 0.5 m margin deep | 13,128 of 18,720 gaps not spanned |
| a skirt sized against the next level only | 1,932 gaps not spanned: a 16 m cell beside a 64 m or 128 m one cracks |
| every square on the other diagonal | 49,152 squares wrong; rays up to 2.4 m off the drawn triangle |
| the grid read one sample off | 50,679 vertices off the function; 94 rays missed; 10,837 gaps not spanned |
| every level held on Box3D's diagonal | 0 squares turned, 8,861 on the wrong diagonal, the middles 4.97 m off |
| every normal baked at twice its texel scale | the worst texel 0.264 off the function, against a byte's rounding of 0.0039 |

### And the level can stand on it

`FlightLevel` (`world/sky.gd`) stands on the island's flat slab or on the generated ground, one world a session.
- **Which world:** the session's level's (`LevelChart.world`), chosen on the desk or with `--world=` and told to every
  joiner before it builds anything; see "LEVELS: A FOLDER EACH, CHOSEN ON THE DESK". A level on the generated ground
  names its three numbers, or takes `GroundTuning.values()`, and `GroundField.configure` checks them when the level is
  read. The build constant, the flag's refusal and the question in `_build` that stood here were the interim.
- **On the alpine world:** the level makes one `GroundField` for its life and hands it to `Terrain`. `Sim.set_ground`
  gives it to every world, one a frame, behind "Loading the ground". `GroundView` is a levelled layer of the level's yard.
  There is no slab and no flat Ground plane. The island's boxes, hand-built places, roads, woods, railway, runway, rising
  air, grass blades, spawns, fires, trains and fleet stand on the slab, and the level builds and seeds them on the island
  only -- except the towns, which are seated on the generated ground (below). The level seeds nothing until its build has
  finished: waiting for the ground lets the session come up mid-build.
- **Terrain answers from the ground it stands on**, statically and from any thread: `surface_height` (the higher of the
  ground and its water, which cockpit-mist's chart bakes on a worker), `surface_heights` (the same over a grid, texel
  centres on it), `ground_height`, `water_height` (a lake's level, the sea's, or -INF) and `open_sea_near(at, depth)`
  (cockpit-carrier's ships). On the island every answer is the slab's and the sea's, as before.
- **Depth under a hull is `CockpitWorld.ground_height_at`**, the function on Box3D's triangles, which answers everywhere.
  Bedrock builds no height field for a cell whose every sample is at or below -40 m, so over open sea a ray down finds no
  seabed OF THE GROUND'S: at the world's corner `first_solid_below` returned -1 against -150 m (2026-09-15). cockpit-pirate
  reads it so. Since 2026-09-16 the ray does meet `Seabed`'s static floor at -150 m, on both worlds; see THE SEABED IS A
  FLOOR under THE WORLD.
- **The island's places on the alpine world** (team-lead, 2026-09-15): the six island towns go by name, each with its own
  plan, seed and lights, onto generated town sites through one ordered table; the island's runway goes onto the flattest
  generated airfield, and the other airfields get runways of the same kind; the box peaks, gates and railway stay the
  island's. Hand-placed sites in `GroundField`'s catalogue, so the island's places flattened exactly where they stand in
  island coordinates, were REJECTED: it changes `ground_core` and every recorded hash, needs a library build, and the
  island's flat plan at those coordinates lands on generated ridges.
- **The towns, seated** (the terrain level's increment B1, 2026-09-15). `TownCatalogue.towns()` is the ONE place a town is
  read from: `TOWNS` on the island, and on the generated ground each line with its "centre" moved to a town site's middle
  at the site's level and a "site" `{index, r, margin}` beside it. `TownPlan`, `Terrain.lift_zones`, the probes' poses and
  cockpit-mist's domes and valley pools read it, never `TOWNS`. THE ORDERED TABLE IS A RULE (team-lead): the biggest plan on
  the biggest flat -- sites by radius, towns by radius, ties in catalogue order, paired. A site is flat at its level out to
  r (380-539 m) and blends back over 420 m (`ground_core.cpp`, `apply_sites`), so a town must fit in r: on today's ground
  inner (470 m, 540.5 m to its ragged edge) stands on r 537, eastern and western on 524 and 522, ford, hollow and brook on
  518, 492 and 422, and the r 390 site 5.7 km from the spawn is empty. Rejected: the towns on the sites nearest the spawn
  (the 518 m site left empty for no reason a pilot could see), and a typed table of names and coordinates (a changed seed
  leaves it on a hillside).
  - A building stands on its town's ground (`TownPlan._put`, `at.y`); the island's are the boxes they were. 444 buildings
    on the alpine world, every floor on the ground under it within a tick, every roof in both worlds' collision -- 410 since
    increment B2 puts the island's town spawns and two road machines' pairs in the seated towns (below).
  - A SEATED TOWN'S STREETS END AT ITS FLAT. A street is one level mark -- streetlights' lamps stand on its top and their
    pools lie flat on it -- and rounded up to the block, eastern's reached 576 m on a 524 m flat, 50 m into the blend. On a
    seated town a street ends at the last crossing inside r; 108 streets, both ends of each on the ground.
  - `Terrain.boxes()` on the generated ground is the seated towns' buildings and nothing else; its clearances are the
    spawns, the fires and, since increment B2, every runway's two approaches. `Terrain.rail_points()` is empty there (a lamp skips any pole within 8 m of the rail), and
    `Terrain.roads()` is empty with no warning (WHAT IS NOT HERE YET). A starting fire is kept off every town site, read
    from `towns()` rather than `boxes()`, whose clearances are built from the fires.
- **The runways and what stands on them** (the terrain level's increment B2, 2026-09-15). A runway is a FRAME
  (`Terrain.runway_frame(centre, bearing, length, width)`: centre, along, across, threshold, far end, and the three numbers),
  and its paint and lights are worked out from the frame alone (`runway_marks_for`, `runway_lights_for`).
  `Terrain.runways()` is every runway a world has: the island's one, or one on each airfield strip `GroundField` flattened,
  at the strip's level, lying along it -- a strip whose x half-extent is the longer points at bearing 90, one along z at 0
  -- the first being the flattest. On today's ground: (-1370, -17258) at 18.75 m and (5363, 600) at 92.66 m at bearing
  90, (1384, 13166) at 85.84 m and (-17495, 1422) at 65.06 m at 0. `runway_axis()`, `runway_marks()` and `runway_lights()`
  stay the ISLAND runway's, so their 82 readers -- the grass, the radio's runway number, smoke, scenery and every picture
  pose -- are unchanged; the level draws and lights every frame of `runways()`, and `_clearances` keeps both approaches
  of each.
  - A PARKED SPAWN WITH A PLACE is placed off it: the runway's Cessnas, tower and gliders off `runways()[0]`'s frame (the
    island's integer offsets on its bearing-0 frame, so its places are the ones they were), inner's and western's cars and
    eastern's helicopter off `towns()` by name (`Terrain._in_town`), each tagged with its place, and the generated ground's
    arm keeps them where the table put them. Proven byte for byte on the island: boxes, streets, rail, the runway's 42
    marks and 112 lights, its frame, 621 clearances and 37 spawns hash the same before and after.
  - A PARKED SPAWN WITH NO PLACE, on the generated ground only (team-lead, 2026-09-15): the helicopters, Chinooks and the
    low pod the island keeps by its spawn go on the first runway's apron (`Terrain.APRON_SPOTS`, across the strip from the
    gliders), resting at their own half-height on the strip's level -- the ground by the level's spawn is a ~41 degree
    mountainside, and a first rule that stood them their island height over the highest ground within a kilometre put
    them 904-1,258 m over their own ground, caught by terrain_level; the pod over an inland range stands its 700 m over
    the highest ground by its own x and z; the cars and tanks, road machines, go on inner's central avenue
    (`Terrain.ROAD_MACHINE_SPOTS`) or are not placed. terrain_level holds every parked machine on its place and at rest
    after the settle: where it was put, upright and still.
  - THE RADIO NAMES THE WORLD'S FIRST RUNWAY, `Terrain.runways()[0]`'s own number: "36" on the island (tests/chatter.gd),
    and on today's alpine world strip 0's -- its frame points west, so "27", the strip's other end being 09.
  - THE SPAWNS IN THE TOWNS COST THEM 34 BUILDINGS, and that is kept (team-lead): every spawn keeps `SPAWN_CLEAR`
    (90 x 70 x 90 m half-extents) clear, so with inner's two cars, western's car and eastern's helicopter in their seated
    towns TownPlan leaves 444 buildings at 414 -- the room the same spawns already keep in the island's towns -- and the
    two road machines' pairs on inner's avenue take 4 more, 410; drawn round inner, 118 becomes 101. Measured both ways:
    444 and 118 with the town spawns kept out of the towns, 414 and 105 with them in, 410 and 101 with the road machines.
- **Load**, measured headless on both editors before it was built: `set_ground` 2,052 and 2,243 ms (double), 2,012 and
  2,223 ms (stock); `GroundField.configure` 5 ms; `GroundView` laid in 152 ms; the first fill round an eye 322 ms at 3,000 m
  over the peaks, 123 ms in a valley. What a headset's compositor and tracking do across a ~2 s frame was NOT measured:
  no headset is attached to the workstation these were taken on (every windowed run reports "OpenXR: Failed to get system
  for our form factor"). See WHAT IS NOT HERE YET for the C++ follow-up.
- `tests/terrain_level.gd` stands the level on the alpine world through `Net.choose_level("alpine")` and holds both
  worlds' ground, the seabed under the sea, the collision against the ground, the drawing, Terrain's answers against
  `GroundField` asked directly, the seated towns (every town on a site of its own, floors on the ground, roofs in the
  collision, streets on the flat, no rail or road, no starting fire on a site, a town drawn with its lamps, the street lights turned on for the suite), the runways (one on each strip, on its middle and ground and along it, its paint and lights on the ground and drawn, its approaches clear of every building), and the traffic: launched aeroplanes clear of the ground, ships on deep open sea, every
  pool's points with a leg the simulation would take, fires on the ground, and every lone machine with somewhere to be.
  It counts its sections from its own `_sections += 1` lines, so a section added needs no count typed beside it.
- **The pools meet the simulation's own leg rules, asked of it.** `Terrain._with_a_clear_leg(points, kind)` keeps a point
  only if a leg to another clears the ground at `CockpitWorld.ai_leg_rules(kind)`'s clearance and overhead and is no
  shorter than its shortest (cockpit-levels' binding). Asked kind by kind (team-lead, 2026-09-15): every wing but the
  tiltrotor is an aeroplane, 90 m and 3,000 m; a helicopter 40 m and 1,500 m; the tiltrotor keeps 90 m and its own 400 m
  shortest leg, so OSPREY's pool is the aeroplanes' or more -- on today's alpine world 57 points against their 55, every one of theirs kept
  and two more, (5476, 2885, -9687) and (5690, 2866, -8352), whose only legs are under 3,000 m. Every other kind's pool hashed
  identical before and after on both worlds. With no simulation every point is kept. Before, `Terrain` MIRRORED the
  numbers (`SIM_WING_*`, `SIM_HELI_*`); a helicopter pool kept to Terrain's own 30 m room and no shortest leg had left one
  hovering 137.6 m over a valley with no leg. terrain_level holds the PLANE, OSPREY and HELI pools to the rules it asks
  the SERVER for itself, which is what catches Terrain asking the wrong thing.
- **The rising air stands on the ground** (increment B3, agreed with cockpit-mist, 2026-09-15). `Terrain.lift_zones()` on
  the generated ground: one thermal over each seated town that has one (inner, eastern, western), and a scatter over the
  land's valley floors and slopes -- dry land, outside every seated town's site, at least 150 m under the highest ground
  within 1.5 km. Every zone is BASED ON THE GROUND UNDER IT (`position.y` = `ground_height`) and its `top` is a world y,
  because the simulation keeps a column's top and never its base and `LiftYard` puts the cloud's base at `top`. THE
  CLOUD CLEARS THE ROCK, AND THAT WINS (mist): a top is lifted until the cloud's base clears the highest surface within
  the widest cloud's reach (radius x `LiftYard.CLOUD_SPREAD` x the widest `CloudTuning.TYPES` spread, 2.52 radii) by
  30 m; a top over a nearby summit is natural, a base in a mountainside is a clipping bug; nothing of a cloud is drawn
  under its base, so there is no skirt to clear. A zone no column up to 3,000 m clears is dropped, a town's by name.
  On today's alpine world, 20 zones: the 3 towns' thermals and 17 of 40 scattered tries; a fresh answer 99.6 ms (587 ms
  while the summit test sampled its 1.5 km at 16 m, now 64 m); one column lifted to 1,618 m to clear the rock; every
  cloud's base clears the ground within its own kind's reach by 484.2 m at the least. REJECTED: a "sunny slope" filter (the daylight presets put the sun anywhere from 30.6 to 285 degrees round)
  and ridge lift (no wind). terrain_level holds a thermal over every thermal town, every zone on the ground and off the
  water, every cloud's base clear of the ground within its OWN kind's reach on an 8 m grid, and every zone felt by the
  simulation halfway up its column. THE RING AND WISPS STAND ON THE GROUND UNDER THEMSELVES (team-lead's ruling, in
  cockpit-mist's `lift_yard.gd`, reviewed by mist): they were put off the ground under the zone's centre, which buried the
  uphill side and floated the downhill on a slope (found by mist). `LiftYard.ring_placement` keeps today's hoop over level
  ground -- every island ring, byte for byte -- and drapes 48 straight pieces over uneven ground, both ends 2 m over the
  surface; `LiftYard.wisp_ends` starts every wisp 6 m over the ground under its own start. On alpine 3 hoops and 816
  pieces, the worst piece middle 5.33 m off. THE 30 m MARGIN IS MEASURED: a 16 m sample missed at most 11.8 m of the
  highest ground under today's zones' reach. THE RAISE IS PROVEN BY A HAND-BUILT CASE: no zone today needs it, so
  terrain_level sweeps the land for where the ground rises most within the widest cloud's reach and holds a zone placed
  there by `Terrain.grounded_zone` to stand taller than 1,500 m and clear it.
- **The woods stand on the ground** (increment B4, team-lead's rulings, 2026-09-15). On the generated ground `Forests.stands()`
  is a rule, not typed rectangles: 60 rectangles tried by `Terrain`'s hash, each kept when every 64 m sample is dry, off every
  seated town's site and margin, every airfield strip and margin and every runway approach (each asked of its owner), when 70%
  of its ground is no steeper than 35 degrees, and when it touches no wood kept before it; the first eight, the floor's limit.
  The conifer share follows the wood's median height: 0.3 at the sea to 0.9 at 600 m. Every tree (`Woodland.plant`) is
  skipped on water or past 35 degrees, and its foot is sunk to the lowest ground under its trunk, so a trunk on a slope stands
  on its downhill edge; on the island's slab none of it moves a tree. The floor under the woods is painted on the generated
  ground's cells: `ground_view.gdshader` includes `forest_floor.gdshaderinc`, and `GroundView.lay_the_floor` sets it on every
  cell built and every cell built after, EACH CELL CARRYING ONLY THE WOODS THAT TOUCH IT, because the floor's
  per-pixel loop over every rectangle was the woods' cost (below). MEASURED FIRST, and why 35 degrees and no treeline: a probe of 60 such rectangles on today's alpine world found valley
  floors and coasts at 0-150 m with median slopes of 2-8 degrees and mountains past about 800 m at medians of 36-63; slope
  limits of 25 / 30 / 35 / 40 degrees kept 31 / 33 / 34 / 36 rectangles, and a treeline at 1,200 to 2,100 m changed
  nothing. With the strip and approach keep-outs as well, the rule's 60 tries end 2 wet, 5 on a site, strip or approach, 20
  too steep, none touching, 8 kept and 25 more past the floor's eight. THE COST, 4K 3840x2160 on the double
  editor, the forest's GPU median less the mean of a `--forest=off` launch either side (two rounds each, forest_low then
  forest_high). The island's woods: PLAIN +0.021 +0.021 / +0.037 +0.040, FINE +0.120 +0.121 / +0.185 +0.183. The eight
  alpine woods as first built (7,203 PLAIN trees, 236 chunks, every cell looping over all eight rectangles): PLAIN +0.107
  +0.104 / +0.122 +0.129, FINE +0.233 +0.247 / +0.267 +0.264. Neither trees nor draws: thinned to the island's trees +0.08 /
  +0.11, and on 256 m chunks as well (69 draws) +0.09 / +0.115. The floor: the eight with the floor left off the ground view
  +0.032 +0.036 / +0.022 +0.021. WITH EACH CELL'S OWN LIST, as shipped: PLAIN +0.048 +0.042 / +0.028 +0.026, FINE +0.147 +0.154
  / +0.163 +0.159. team-lead's bar was the island's plus 0.02 ms; forest_low is over it by 0.002 to 0.007 ms, which he ruled
  noise against a round number, and eight woods ship (two, +0.032 +0.040 / +0.048 +0.047, were the fallback). The per-cell
  list paints what the whole list did: at a seam where a wood crosses a cell the two pictures differ by at most 3 on PLAIN and
  28 on FINE (0-255, p99 0 and 1), and two launches of one unchanged build differ by 4 and 29. Grown in 0.8-1.2 s on alpine
  against the island's 0.1 s.
  terrain_level holds every wood off its keep-outs and apart, every tree's foot on the lowest ground under its trunk with no
  ground round its edge below it, no slope past 35 degrees, none on water, and the floor on the cells that existed and on
  cells built after the eye moved.
- **The roads lie on the ground** (increment B5, team-lead, 2026-09-15). On the generated ground `Terrain.roads()` is
  `TownPlan.roads_on_the_ground()`, worked out once per ground: the seated towns and then the airfield strips, joined
  shortest pair first by straight distance (Kruskal's), a pair no road reaches giving way to the next shortest -- Prim's
  tree left a town and a strip apart when its one link found only a 56 km way round. Each link is routed by A* on a 256 m
  grid (`TownTuning.ROAD_GRID`), never onto
  a cell with water anywhere on it, into another town's site or strip, or up a step rising more than 12 % of its level run
  (`ROAD_GRADE`; the 8 % this entry set out left the strip at (5363, 600) with no road), costing up to twice its run the
  steeper it climbs, and giving up past
  three times the straight distance (`ROAD_DETOUR`); then pulled straight
  wherever a straight line keeps those rules, and cut into 16 m pieces (`ROAD_PIECE`, GroundView's sample spacing) whose
  ends stand on the ground. No piece may rise more than 30 % of its run (`ROAD_CLIFF`), which the grid cannot see: its
  points straddle banks and gullies, and the first alpine routes left 6 of 9 links out, each with 11 to 36 pieces rising 59
  to 97 % on valley floors. So every step of a found route, and every straight, is walked at the pieces' own points, and a
  steep step is forbidden, for every later route too, and the route found again (at most 24 times). A link with a piece on water, a steep piece left,
  or no route is not laid, and a place no road reaches is named in a warning. A road leaves a town down its central avenue and meets a strip 60 m off
  whichever long side faces the other place. `road_marks` pitches a piece on a slope about its own across axis; a level piece, every island road, has
  no pitch. TownView draws a mark turned, pitched and then scaled IN ITS OWN AXES (`Basis.scaled_local`): `Basis.scaled`
  scales in the world's, so until B5 a yawed road drew skewed -- at 0.7 rad 64.7 m across instead of 9 -- and the island's
  roads' paint changes with it, though their numbers hash the same. On today's ground:
  10 places, 9 roads, 122.5 km in 7,677 pieces, the steepest 29.6 %, 1,328 grid steps walked and 185 found steep, 4 pairs
  refused on the way, worked out in 1,516 ms of the alpine boot.
  terrain_level holds every piece's ends on the ground and its middle off the water, no piece steeper than 30 %, and every
  town and strip joined. scenery_shot's `road_close` (the steepest piece, from 120 m) and `road_far` (the longest straight
  run, from 1.5 km) are the pictures.

### And nothing is built to draw the far band, because it costs next to nothing

The design's increment 5 had a far impostor: past a mid ring of about 8 km, rock and buildings merged into a few boxes a
cell. Measured before it was built, it did not earn building, and was not (2026-09-14).

`tests/streaming_probe.gd --parts=far`, windowed (stock editor, d3d12, RTX 5080), draws the island tiled to 72 km:
- rock, concrete, buildings and paint, in a yard of their own under a bare camera and a sun, with no environment, fog or
  shadows;
- once out to the level's 24 km and once cut at 8 km, A B A B in one launch;
- from a low pose (600 m, looking along the ground across tiles) and a high one (3,000 m, looking down across the map's
  middle).

The machine was at 1 to 4 % CPU with no compiler processes. Medians over 60 frames; both laps read the same to the
hundredth of a millisecond:

| pose | reach | cells built | draws | primitives | GPU | render CPU |
|---|---|---|---|---|---|---|
| low | 24 km | 590 | 176 | 31,500 | 0.080 ms | 0.087 to 0.090 ms |
| low | 8 km | 86 | 17 | 3,300 | 0.062 ms | 0.038 ms |
| high | 24 km | 607 | 212 | 38,616 | 0.080 to 0.081 ms | 0.099 to 0.100 ms |
| high | 8 km | 87 | 44 | 8,220 | 0.056 to 0.057 ms | 0.047 ms |

- **Everything from 8 to 24 km is 159 to 168 draw calls, about 0.02 ms of GPU and 0.05 ms of render CPU.** A headset
  pays render CPU twice: 0.1 ms, against an 11.1 ms frame. An impostor could win back only part of that. It would add a
  second picture of every mountain to keep in step with the first, and a swap to hide.
- **Looked at** (`godotgames-drafts/.../cockpit-streaming/inc5b/`): at 24 km the ranges stand to the horizon; at 8 km
  they stop a few tiles out. The level's fog leaves 28 % of that band at 8 km and 5 % by 18.7 km.
- **What this does not measure:** the level's environment, fog and whatever shadows its sun casts. The level pays more
  for the band than this; this is the scenery's own share.
- **Where far cost will live instead: the terrain.** A heightfield drawn to 24 km is triangles in every cell, which is
  what cockpit-terrain's levels are for: a `SceneryYard` layer drawn at coarser spacings further out. Revisit an impostor
  for the generated boxes only if a measurement with the level's own sun, shadows and fog says the band matters, or if
  terrain's far rings leave the band's rock and buildings drawn at full detail where they cost something. See WHAT IS
  NOT HERE YET.

## TOWNS, AND THE ROADS BETWEEN THEM

**A town is a line in `world/town_catalogue.gd`**: a centre, a radius, a block and street width, how tall its middle
and its edge are, how many towers and how far out they may stand. `world/town_plan.gd` grows it with `Terrain.hash01`
-- never the engine's RNG, for the reason THE WORLD gives -- into a straight street grid (streets on every multiple of
`block` from the centre, both ways), blocks between the streets, one or four lots to a block, and a building on a lot
unless the hash leaves it empty. How likely a lot is to be empty, how tall its building is and how likely a block is to
be split all move from the centre's number to the edge's along a smoothstep of distance over radius; a tower takes a
whole block and stands only inside `tower_radius`. Every building is a whole number of `TownTuning.STOREY`s, which is
what lets the shader's window rows end at the roof.

The three grey grids that were `Terrain.CITIES` are the first three entries, at the same centres (inner, eastern,
western); three small towns with no towers (ford, hollow, brook) are the next three. `Terrain.lift_zones` reads its
thermals off the catalogue now, so a city moved takes its cumulus with it.

**STRAIGHT STREETS, BECAUSE A STATIC BOX HAS NO ROTATION.** `add_static_box` takes a position and half-extents and
nothing else; a town on a slant is a wire-and-simulation change (a rotation argument), and was decided against for v1
on 2026-09-13. Roads BETWEEN towns are paint and run at any angle.

### One building is one record is one box

A building is the dictionary `Terrain.boxes()` hands out -- `{position, half_extents, group: BUILDING, roof, seed,
town}` -- so it reaches the simulation once (`FlightLevel._build`, unchanged) and is drawn from the same entry
(`TownView`, one MultiMesh a kilometre since 2026-09-14, size in the basis, roof, seed and storeys in `INSTANCE_CUSTOM`), and its red lights
are computed from it (WP5). `TownView.drawn_buildings()` reports what it handed the MultiMeshes, and smoke holds it to
the list and to the simulation:

- `every_building_drawn_is_exactly_one_box_of_the_same_size` -- a multiset match to the centimetre: 377 drawn, 0 with
  no box, 0 boxes not drawn.
- `and_the_simulation_holds_each_one_wall_for_wall` -- `leg_is_clear` on the SERVER's solid list, which never sees the
  GDScript dictionaries: a leg across each wall from 0.3 m outside to 0.3 m inside is blocked, one from 0.3 m to 1.3 m
  outside is not. 1508 walls of 377 buildings.
- RED: the drawn size made 1 % larger (`half * 2.02`) failed both, 377 of 377.

**THE READ-BACK THAT READS NOTHING.** The first version of the check read the instances back with
`MultiMesh.get_instance_transform`, and every one of 377 buildings (the first placement) came back at the origin with no size. Headless, that
call answers from the dummy rendering server, which keeps no buffer. So `TownView` keeps the transforms as it sets
them; the test reads the part that can go wrong in this file (which town, the doubling of half-extents) and asks the
simulation separately about the rest.

### What the island has now

Measured 2026-09-13, everything else unchanged: **650 solid boxes** (383 at HEAD, read by the same probe on the same day
-- THE WORLD's "463" is from an older island; the three grids were 110 of the 383), of which **377 are buildings** -- inner 93, eastern 83, western 69, ford 37, hollow 57, brook 38 -- under `MOST_BUILDINGS` 1600. Mean height
inner third / outer third: inner 66 / 17 m, eastern 35 / 15, western 46 / 15, ford 15 / 9, hollow 16 / 10, brook 12 / 9.
With the clearance filter switched off the same generator builds 444; the ones it leaves out stood in spawn, rail,
runway and fire clearances. The railway runs north-south through the western city and its corridor empties the row of
blocks at x = -3552 from end to end -- that is the clearance working, and it is why the avenue test's twin accepts a
blocked row on EITHER side.

### Roads

`TownPlan.roads(solid, clearances)`: Prim's spanning tree over the town centres (catalogue order on ties, so every peer
lays the same tree), then the `EXTRA_LINKS` shortest links left over under `EXTRA_LINK_LONGEST`, for a loop. A road
leaves a town down its central avenue on the side facing the other town. A straight link that meets a clearance, a
mountain, a building or a third town is tried through a dogleg at one, two and three `DOGLEG_STEP`s either side of its
middle; a link that finds no way is dropped with a warning, and `towns` fails if that cuts a town off. Clearances tagged
`rail` do not stop a road: two cities sit on the rail loop, so it crosses at a level crossing. 7 lengths today, 1
crossing the railway, every town reachable. RED, with brook moved for the run to (-1500, 1800), beyond the runway: with the keep-outs off its roads
ran through the tanks' spawn clearance and `no_road_crosses_a_clearance_but_the_railway` failed; with them on, no road
crossed one but two links found no way round, and `every_town_can_be_driven_to` failed at 4 of 6. No road crosses
either wood today: both keep 1.00 of their ground free (`tests/forest.gd`), so the roads remove no trees. Drawn as yawed paint slabs with the streets, one MultiMesh,
no collision.

### A building stops what it should, with no simulation change

`tests/towns.gd` builds a server world with the whole island the way the level does and finds, rather than assumes, a
tower with open ground in front and behind: 166 m tall at (376, 83, -416), shot from the west.

- A tank's round stops at its wall: surface GROUND, 0.000 m past the face. With that one box left out of
  the world, the same round lands 478 m further on.
- A radar missile launched at a target parked behind it is not guiding a third of a second off the rail; with the box
  left out, it is. `seen_from` is the one function a seat's lock and a missile's seeker both ask.
- A hit on a building still reports `ground`: there is no building surface. That is WP6's, if it is wanted.

The first version of the finder looked only from the west, wanted 120 m of open ground, and ended every approach leg
one metre short of the wall with three metres of clearance -- so all 172 faces were "blocked" by the building being
looked at. A leg is fattened by its clearance; stop it that far short.

### The fire suite had been fighting its fires on the whole island

The towns found it, and it landed on its own first (f3b0003): `FireFront` read an empty solid list as the whole island,
so every rate check in `tests/fires.gd` -- built on `_open_ground()`, NOTHING SOLID ANYWHERE -- had run among every
mountain. The inner city standing within 500 m downwind of the test fire made the third fire 38 s late instead of 23.
See the note on `FireFront._init`.

### What it costs the simulation

Eight launches, HEAD and towns alternated (A B A B A B A B), two whole trees, double-precision editor headless, the
rule sent to the lead before any run: the tick change counts only past T = max(0.02 ms, the range of the four A
medians), and a change past +0.10 ms stops for simulation work (WP6). Every fires and smoke run passed.

| | HEAD, four launches | towns, four launches | medians |
|---|---|---|---|
| server + client per tick | 0.265 0.320 0.333 0.323 ms | 0.284 0.323 0.320 0.317 ms | 0.322 -> 0.319, T 0.068 |
| `Terrain.boxes()` | 42.5 43.7 43.1 42.5 ms | 163.7 161.3 158.2 159.4 ms | 42.8 -> 160.4 |
| `waypoints()`, six kinds | 300.7 306.7 308.0 304.5 ms | 1154.1 1200.6 1162.5 1140.4 ms | 305.6 -> 1158.3 |
| 10,000 `leg_is_clear` | 46.5 47.1 47.4 46.8 ms | 46.1 47.6 49.5 49.2 ms | 46.95 -> 48.40 |
| fires suite | 15.46 15.83 15.93 15.36 s | 15.17 15.57 15.38 15.36 s | 15.6 -> 15.4 |
| smoke suite | 57.55 84.16 70.05 67.20 s | 67.83 79.15 71.94 71.74 s | 68.6 -> 71.8 |

- **THE TICK DID NOT MOVE: -0.003 ms against a noise of 0.068.** 650 static boxes in Box3D cost a tick nothing this
  instrument can see, so none of WP6 (compound bodies per town, a grid in `clear_between`) was started.
- **THE BOOT DID: +970 ms**, all of it GDScript. `waypoints()` rebuilt `boxes()` once per kind and walked every box for
  every candidate point, so it grew with buildings times points. The C++ leg test grew 1.45 ms in 10,000 calls.
- **smoke's wall clock cannot see a second at boot:** HEAD alone ran it in 57.6 to 84.2 s. The probe is the instrument.

**AND THEN THE BOOT WAS FIXED, and came out faster than the island without towns.** Three changes: `boxes()` is
built once per level and handed round (`FlightLevel._solid`), filed by place in a `BoxGrid` of 256 m cells that asks a
point about the boxes near it with `_clear_of`'s own arithmetic, and each town asks only about the clearances and
mountains that touch its own square. `waypoints(kind, grid)`, `ai_fleet(grid)` and `one_more(kind, which, grid)` take
the grid as a required argument. The same eight-launch rule, against HEAD at 89cfc96 (the woods in both):

| | HEAD, four launches | towns, four launches | medians |
|---|---|---|---|
| server + client per tick | 0.289 0.260 0.259 0.260 ms | 0.292 0.260 0.259 0.259 ms | 0.260 -> 0.260, T 0.030 |
| `Terrain.boxes()` | 57.9 58.3 57.9 58.0 ms | 29.6 29.3 29.1 29.4 ms | 57.95 -> 29.35 |
| `waypoints()`, six kinds, grid built included | 393.6 393.0 392.1 392.6 ms | 3.3 3.1 2.9 3.0 ms | 392.8 -> 3.05 |
| 10,000 `leg_is_clear` | 45.5 45.7 45.7 45.5 ms | 50.3 49.4 48.8 49.4 ms | 45.6 -> 49.4 |
| fires suite | 14.02 13.25 13.15 13.18 s | 13.26 13.15 13.25 13.05 s | 13.2 -> 13.2 |
| smoke suite | 53.11 46.49 47.60 47.37 s | 47.53 46.55 46.83 46.47 s | 47.5 -> 46.7 |

- **Boot: 451 ms at HEAD, 32 ms with 650 boxes** -- 418 ms faster than the island had before any town. Most of HEAD's
  cost was `waypoints()` rebuilding the island six times, which no change here needed to keep.
- **The tick still does not move** (-0.001 ms, T 0.030). The one number that grew is the C++ `leg_is_clear`, linear in
  boxes: +3.8 ms in 10,000 legs, 0.4 microseconds a leg. An autopilot asks a few a second; that is not WP6.
- **The grid gives the walk's answers**, held by `tests/towns.gd`: the six pools identical filed as walked, and 0 of 4000
  random points near boxes disagreeing. RED: a grid filing each box by its centre alone changed the heli and car pools
  (55 against 50) and disagreed on 224 points.

### FINE draws inside the box, and what that trades

FINE's setbacks, plant rooms and pitched roofs are drawn INSIDE the building's collision box, never outside it: inset at
most `TownTuning.FINE_SETBACK_MOST` (4 m), and only in the top 30 % of the height. Decided by the lead, 2026-09-13. The
trade, stated so nobody rediscovers it as a bug: a round or an aeroplane can stop against up to four metres of
invisible ledge high on a tower. The alternative -- a box per setback -- breaks one building, one box, and adds to the
tick and to every linear walk of the solid list.

## ROAD VEHICLES: DRAWN MESHES, AND NOTHING THE SIMULATION HAS (lane/roadfleet, 2026-09-19)

Asked for by the user: *"We need a selection of cars, trucks and busses, something we can simulate cars and traffic
with. Make sure they don't think about physics, they are not craft so don't build KIND or make them part of the physics
simulation, but let's just create models for them, we can place them as meshes in the levels."*

**A road vehicle is a picture and never a thing.** No kind, no entry in the C++ kind table, no collision box, no wire,
no seat, nothing the tick touches. They are in `Forests`' family, not `PowerStation`'s: that file gets to say "a forest
is a picture and never a thing" because an aeroplane flying through a wood is a choice somebody can defend, and an
aeroplane flying through a parked hatchback is the same choice and an easier one. `tests/road_vehicles.gd` ASSERTS the
absence rather than assuming it -- no road-vehicle file may declare any method `world/power_station.gd` declares for its
own solid, and none may so much as name `add_static_box` -- because copying the nearest template is exactly how one of
these would quietly become solid.

There is already a drivable `car` KIND in this game (`craft/car`, kind 3, with a wheel and a seat). Nothing here touches
it, extends it or is modelled against it.

**Where everything lives.** `objects/vehicles/road/road_fleet.gd` is the catalogue -- one line a type, and the one place
anything may know how big a vehicle is. `objects/vehicles/road/road_car.gd` draws the four car bodies from a line.
`objects/vehicles/road/pressing.gd` is the shared faceted geometry, `Plating` for road vehicles: `loft`, which is a box
whose width and whose top and bottom vary along its length, and `wheel`, which is the boxcar's eight-sided prism.
`craft/road/sources.md` is the fact table, with a URL, a datum and a PUBLISHED/MEASURED/ESTIMATE tag on every figure.

### Four numbers derived, never typed

`rear_overhang` is `length - wheelbase - front_overhang`; the track is one share of the overall width; the wheel
diameter comes out of the tyre size by the published ISO formula; the axle positions come out of the overhangs. A
vehicle whose overhangs and wheelbase do not add up to its length is **the right size with the wrong stance, and every
dimension check passes**. The method is the Atego's: Mercedes-Benz's own specification sheet gives four wheelbases, four
rear overhangs and four overall lengths and never prints a front overhang -- subtracting gives 1,620 mm on all four
identically, and four arithmetic routes to one figure beats one printed number.

### The two faults a picture found and a green suite did not

1. **THE UNDERSIDE WAS FLAT AT THE GROUND CLEARANCE**, which is a real published number and the wrong one: it is the
   lowest point of the FLOOR PAN, not of the bodywork. At 145 mm on a hatchback only 145 mm of a 632 mm tyre was outside
   the body and the cars read as bricks on white stubs -- with the right length, width, height and wheelbase, four
   contact patches on the road and eight facets a wheel. The body now sweeps up to a SILL at two thirds of a wheel
   diameter between the arches, so the arch is an opening rather than a painted rectangle. CLAUDE.md rule 2.
2. **A COLOUR DERIVED FROM THE PAINT LANDED ON A FIXED ONE.** The underside was `paint * 0.35` and the rocker's floor
   `paint * 0.30`; the crossover's blue-grey times 0.30 is inside two hundredths of the glass colour on all three
   channels, and the suite reported that its windows began at its floor pan, 195 mm over the road. **Keeping the fixed
   palette well separated proves nothing about colours computed from a colour somebody else picks** -- a paint is chosen
   per instance and can be anything, so any shade of it can be anything. Nothing darkens a paint any more: the underside
   is a constant and the rocker is the paint itself, which is what a real rocker is painted. What is left is one
   comparison, and the suite makes it.

### The check anchored outside the model

`tests/road_vehicles.gd` reads the pickup's BED FLOOR off the drawn vertices and holds it to **5 ft 6 in**, a published
bed length that no part of the model was built from and that nothing in `RoadFleet` knows exists -- `Boxcar`'s AAR
clearance plate from the same place. It caught its own datum error first: `backlight` was set so that `tail - backlight`
came to 1.6613 m, within one per cent of 5 ft 6 in and apparently settled, but that span is the bed OPENING plus the
tailgate and the rear bumper. The drawn floor at that setting was 1.366 m, **18 per cent short**. A published dimension
has a datum, and 5 ft 6 in is the floor you can put a pallet on.

### What is checked, and what it costs

Each type's envelope, wheelbase and stance off its own vertices (never `transform * get_aabb()`); the lowest drawn point
at y = 0, which is the tyres' contact flat and is exact because `Pressing.wheel` CIRCUMSCRIBES the tyre rather than
fitting inside it; tyres inboard of the flanks, which stands in for a track figure nothing published supports; eight
facets a wheel from the drawn normals; the greenhouse narrower than the body, which is the one cue separating a car from
a van; and the deck behind the rear glass per body style -- 0.14 m on the hatchback, 0.70 on the saloon, 0.18 on the
crossover, 1.96 on the pickup -- because four styles drawn from one shape table is exactly the arrangement in which they
all quietly become one car. **Ten of ten mutants caught.** A car is ONE surface and about 250 triangles, against the
boxcar's 900 and the Hawkeye's 2,700.

### The trucks, and the reading that had to be corrected

A panel van, a rigid box lorry and an articulated tractor with its semi-trailer
(`objects/vehicles/road/road_lorry.gd`). **A truck is TWO VOLUMES OF DIFFERENT HEIGHTS and the joint
between them is the whole silhouette** -- a lorry drawn as one box is a shipping container on wheels.
The van is the exception that proves it: its cab and its load space ARE one volume, which is exactly
why a van reads as a van. A cabover's windscreen is nearly upright (8 degrees off vertical against a
car's 61), the body stands on a frame a PUBLISHED 955 mm over the road, and the drive axle is twinned.

**THE ATEGO'S 180 mm IS AT THE FRONT, AND THIS LANE FIRST PUT IT AT THE REAR.** Mercedes-Benz's sheet
gives `H` (bumper to back of cab) plus `G` (back of cab to end of frame) as 180 mm short of the
overall length, on all four wheelbases. That consistency is real and it was written up as a rear
underrun bar, concluding that the body must not be drawn to the overall length. It is wrong. The
sheet's sixth figure settles it: `I`, cab rear to front axle, 210 mm. At the rear the cab rear
computes to 30 mm from the front axle and contradicts `I`; at the front it computes to exactly 210
and the frame's end lands on the overall length to the millimetre. Six printed figures, one reading
satisfies all six.

**A residual that appears consistently tells you something is MISSING; it does not tell you WHERE.**
Four confirmations of a magnitude say nothing about its position, and the figure that disambiguated
it was on the same sheet, unused, because the first reading closed plausibly enough to stop the
search. `craft/road/sources.md` carries the table. Do not "restore" the other reading.

### Which bounds anything was fitted to, and which it was not

The suite holds every truck to 96/53/EC -- 2.55 m wide, 4.00 m high, 12 m for a rigid, 18.75 m for a
road train -- and holds the box body to the Atego's PRINTED `G` of 7,235 mm, which it hits to the
millimetre. **One bound is excluded on purpose and says so:** the artic's 16.5 m articulated maximum,
because its kingpin set-back was CHOSEN to satisfy it, which is how a haulier specs a tractor and
which makes it a figure the model was fitted to. Checking against a bound you fitted to is the model
asking itself. What survives is kingpin-to-rear: a published 13.600 m trailer less a published
1.700 m kingpin setting is 11.900 m against a published 12.500 m maximum, with nothing of ours in it.

**No container is drawn here.** The seaport lane owns the ISO box; a skeletal publishes its deck
instead of carrying a copy. The free cross-check: a 9 ft 6 in high-cube on a 1.100 m deck stands
3.996 m, four millimetres under the legal 4.00 m, which is why low-deck skeletals exist at all.

### The buses, and the constraint a legal maximum puts on a model

A 12 m low-floor city bus and a touring coach (`objects/vehicles/road/road_bus.gd`). They are within
265 mm of each other in length and identical in width, so **size is not what separates them: the
height of the floor is.** A coach's is raised over a luggage hold, so its glass starts high with a
deep blank band beneath it; a low-floor city bus's deck is 400 mm over the road, so its glass comes
down nearly to its skirt and there is no band at all. Drawn without that band a coach IS a city bus,
and every envelope check would still pass. The suite measures each one's window sill as a share of
its own height and requires the coach's to be a tenth higher: 0.39 against 0.23.

**A VEHICLE BUILT TO THE LEGAL MAXIMUM HAS NO ROOM FOR PROUD DETAIL.** The glazing and skirt were
drawn 4 mm and 3 mm outside the flank, as they are on a car where nobody notices. A bus is 2,550 mm
wide because that is all it may be, so the drawn vehicle came out 2,558 and illegal. The body is
drawn narrower and **the glass sits on the published width**, which is what flush bonded glazing
actually is. Every other vehicle here had room to be careless.

**AND TWO CHECKS WRITTEN AS PROPORTIONS HAD TO BECOME ABSOLUTE HEIGHTS.** "Glass above its own
waist" and "nothing glazed in its bottom quarter" both failed the low-floor bus honestly -- its sill
is 0.72 m on a 3.12 m body, and coming down that far is what low-floor MEANS. A proportion demanded
the most clearance from the tallest vehicles, which is backwards. Both now use `GLASS_CLEARS_ROAD`,
half a metre, which is knee height: the crossover's underbody that these checks exist to catch sat
at 0.195 m, and a bus's lowest legitimate window at 0.72, so the bound means something on its own.

The suite also holds a bus to the **13.5 m two-axle bus maximum** rather than the 12 m for a rigid
goods vehicle. Using the goods limit would be the right vehicle against the wrong law -- and it
would PASS, which is worse, because both buses are under 12.5 m anyway.

`tests/road_vehicles_shot.gd` renders the line-up with a 1.80 m figure for scale, the row from above (which is how
nearly all of them will be seen), an eye-height pass, and every silhouette orthographic on one page. **The row is laid
END TO END, each vehicle taking its own length plus a gap, and the cameras stand back by a distance worked out from the
row and the field of view.** Spacing everything by the longest -- the 16.48 m artic -- made the row 114 m long and left
the cars as specks; a fixed 7.4 m before that drew the artic through the van. The silhouette page is a fixed width and
the SCALE follows, so it is named in the file rather than assumed.

## THE TIME OF DAY

    the TIME tab on the clipboard, or --time=day|evening|night|dawn|dusk|HH:MM and --clock-rate=N after the bare --

### A clock, and the three presets are points on it (2026-09-18, lane/daytime)

"Allow for time of day changes, so we can cleanly have the sun and moon move over time and handle special cases like
twilight ... change the time to arbitrary times of day from the ipad (not just the three we have now)." The time of day is
a CLOCK now: minutes since midnight, the session's (`Net.clock_now`), running at a rate the host sets (0 frozen, 1 real
time, up to `Net.CLOCK_RATE_MOST` = 3,600). Three pieces:

- **`Orrery` (`world/orrery.gd`) puts the sun and the moon in the sky from the clock** with the textbook sums: latitude
  53 N, the sun's declination +7.1725 (a fixed date), the clock an hour ahead of the sun. Nothing is typed per time of day.
- **`DaylightTuning.look_at(minutes)` is what the world looks like**: the three presets blended by the TRUE SUN'S ELEVATION
  -- DAY from 20 degrees up, EVENING at its own 7, NIGHT from 12 down -- plus where the sun and moon are, which of them is
  the light, the moon's light and the stars. A table keyed by the three (`MistTuning`, `OilField`'s flare) is blended by
  the look's `like` weights with `DaylightTuning.blend`, never by a curve of its own. Every consumer is handed the look.
- **`Daylight` tells the renderer in STEPS**: the clock is read every frame (sums only) and the world is told when the sun or
  the moon has moved `STEP_DEGREES` (0.25) and not inside `STEP_GAP` (0.5 s) of the last telling; a frozen clock writes
  nothing. One step is `Daylight.writes_per_step()` = 31 properties. tests/scenery.gd holds a clock at 3,600 times to at
  most one step per gap (2 steps, 62 writes in a second); a mutant that stepped every frame wrote 3,751.

**The presets are where they were.** The clock's DAY (10:28) and EVENING (18:51) are the times the sun stands at those
presets' elevations, and the sky was solved so it stands at their azimuths too (0.0001 degrees off, tests/daytime.gd).
**That needed the sky turned 17.36 degrees against the island's grid** (`Orrery.SKY_TURN`): with north held at -Z no real
path goes through both suns and still has a dark night -- the best miss is 5.2 degrees, and the exact one is a white night at
66.5 N. The look at each preset's point is the preset key for key (tests/daytime.gd), and before and after pictures of five
views on both finishes differ at DAY and EVENING by no more than two runs of the same build do (the sea's waves).
**NIGHT's moon moved**: typed at compass 40 (north-east), which no moon reaches from any temperate latitude, while its note
said south-east; it now stands where `Orrery` puts it at 23:30, 40 degrees up at compass 139.5, a waning gibbous 93 per cent
lit, with the true sun 26.9 degrees down. The moonlit sides of things turn about 100 degrees round.

**The light is the sun while the sun is above -1 degree and the moon below it**, one DirectionalLight3D either way: the sun
fades to nothing between 6 and -1 degrees and the moon's light comes up between -4 and -12, so the hand-over happens in the
dark. With the moon down the light is hidden (no shadow map) and NIGHT's ambient keeps `MOONLESS_AMBIENT`. The skies draw
the moon along its own `moon_direction`, so a moon over the dusk stands in the sky while the sun is still the light.
**The ambient is always the sky's**, mixed toward `ambient_colour` by `ambient_sky` (Godot's `ambient_light_sky_contribution`,
which at 0 is exactly the COLOR source NIGHT had), so dusk can pass from one to the other.

**Twilight by the sun's height, not by name.** Between EVENING (7 up) and NIGHT (12 down) stand two looks with no button:
SUNSET at 0 and the BLUE HOUR at 6 down, each with its own `like` weights over the three presets. A straight blend from
EVENING to NIGHT passed through a grey middle. And a DUSK GLOW (`DaylightTuning.DUSK_GLOW`, `sky_night.gdshaderinc`'s
`dusk_glow_seen`) is added to the sky low down in the sun's direction, from 6 degrees up to 12 down, strongest between 0 and
-4. **It needed the depth fog taken off the sky at dusk**: at Godot's `fog_sky_affect` of 1 the fog replaces the sky at the
horizon, and the first sunset sequence was a flat grey-pink all round at 19:45. `fog_sky_affect` is a look key now, 1 at
every preset (the scene never set it, so that is what they always had), 0.4 at SUNSET and 0.5 at the BLUE HOUR, and back to
1 inside a cloud. The lamps that are simply on or off (the platforms' floods) come on under 10 degrees and go off over 12
(`Daylight.LAMPS_*`); walked a minute either side of the threshold they change once, and with no gap they changed 20 times.
The board's readout names the sky by an almanac's words (`DaylightTuning.sky_words`). Pictures: tests/daytime_shot.gd.

**A day in ten seconds** (the user, 2026-09-18: "a sunrise/sunset/moonrise (at very fast speed, shorter than 10 seconds), so
we can see the full time of day cycle"). `Net.CLOCK_RATE_LAPSE` = 8,640 is the TIME tab's TIMELAPSE and the fastest a clock
may run. At the step rule's half-second gap that is 20 steps a day, 18 degrees of sun each -- a slideshow -- so at
`Daylight.LAPSE_FROM` (4,320, a day in 20 s) or faster the daylight steps EVERY FRAME, and below it the rule stands (3,600
times is still 2 steps a second). tests/scenery.gd holds 120 frames at 8,640 to 119 to 121 steps of at most 36 writes; the
mutant with no lapse stepped twice.

**What a step costs, and the spike that was a log line.** `tests/daytime_shot.gd --measure=N` times, windowed and from
one place, the renderer's GPU and CPU frame over four rounds -- frozen, the same sky told again every frame, frozen again,
and the real time-lapse -- with `Daylight.costs`, each part of a step by name (the look, the writes, and every consumer
`FlightLevel._on_the_time_changed` calls, `_counted`). In team-lead's GPU slot (2026-09-18, 1600x900, PLAIN, 480 frames a
round): GPU median 0.662 ms frozen, 0.746 with a step every frame, 0.754 at the time-lapse -- **the sky's radiance and the
writes cost the GPU about 0.08 ms**. The CPU was the problem: a forced step every frame was 3,367 us on the mean and 7,978
at worst (71 ms once), while its parts added up to about 800. The rest was the `[daylight]` line printed to the log on
every step. A step of a running clock prints nothing now (`show_clock(minutes, said)`); DAY's light for the trails'
shares and NIGHT's moonlight are worked out once, not per step (a whole look each, three times a step); and in a
time-lapse the board and the dials are told the time four times a second (`RIG_TOLD_EVERY_MSEC`), since the readout
redraws the board. After, under other lanes' load: a forced step 938 us on the mean, 2,581 at worst; the time-lapse 797
and 1,883. **The moon's face is drawn
whenever the moon is up**, pale by day (`MOON_BY_DAY`), so it is seen to rise: at 18:52 in the east-north-east, 52 minutes
before the sun sets in the west-north-west. DAY and EVENING keep no moon because it is down at both (5.5 and 0.15 degrees
under). The reel (`tests/daytime_shot.gd --reel=17:00` under `--write-movie`) is split east and west for that reason: an
hour is 0.4 s of it, and no one camera holds both.

**Presets, before the clock** (the rest of this section, kept as it was written):

**Three presets, not a clock.** Asked for on 2026-09-13 "so we can test day, evening and night". A clock turning
through a day is a sky that is never the same twice, which no probe can compare, and a light re-told to the renderer
every frame. `world/daylight_tuning.gd` holds DAY, EVENING and NIGHT, every number in them, and why; `world/daylight.gd`
(`Daylight`, a node the level owns as `FlightLevel.daylight`) puts one on the world.

| | DAY | EVENING | NIGHT |
|---|---|---|---|
| sun | 34.8 deg up, white, energy 1 | 7 deg up from the west, warm, 0.9 | a moon 40 deg up, cool, 0.14, drawn with its face |
| ambient | the sky | the sky, 0.8 | a blue-grey colour, 0.55 |
| sky and fog | the scene's colours, Godot's fog light | a warm horizon and warm fog | near black, dark blue fog |
| windows lit | none | 22 % | 55 % |

**DAY is the sky as it was.** The colours `world/sky.tscn` wrote, the fog light colour Godot defaults to (the scene never
set one), and the sun where its DirectionalLight3D stood: (0.42, 0.57, 0.71) towards the sun, read off the scene's
basis and checked against `DaylightTuning.towards_the_sun(DAY)` = (0.418, 0.571, 0.707) before anything was built on
it. **NIGHT's ambient is a COLOUR, not the sky**: a near-black sky as the ambient is a near-black world, and the moon
alone leaves every face turned from it black.

**Written once per change, never per frame.** A light, an environment or a sky material set from script is a call into
the RenderingServer, about half a millisecond a frame when it was done per frame here. `Daylight` has no `_process`;
`show_time` writes only on a change, and every write goes through `_write`, which counts.

**The session owns it, the level draws it, and the board announces.** `FlightLevel.choose_time` is what the TIME tab's
`chose_time` is connected to, and it asks `Net` (see "The host's sky" below); on a change the level tells the towns how
many windows to light and the board which button to press, once each.
`--time=` is read the way `--finish=` is, so `--level=world -- --time=night` starts at night.

### The host's sky, and every machine's own finish (2026-09-16, plan item 17)

    the TIME tab's three times and its CLOUDS switch; tests/sky_peers.gd

**What the world IS agrees across a session; what a machine can AFFORD to draw does not.** The user, 2026-09-15: "time
of day and other level options are not synced, graphics detail shouldn't be synced, but time of day should. Toggle
clouds could also be a networked choice." So the time of day and whether there are clouds are `Net.time_of_day` and
`Net.clouds_on`, decided by the host, and the finish (`Finish`), the fog clouds (`CloudBank.asked_for`) and `--clouds=none`
stay on the machine that asked for them. A client turning its own detail down is correct; a client under a different sky
from its host was the bug, and this section's entry in WHAT IS NOT HERE YET said so from 2026-09-13.

**One authority question, named: `Net.decides_the_sky()`** -- a host, or a machine in no networked session. The TIME
tab, the time-of-day dial and CLOUDS all announce to `FlightLevel.choose_time` / `choose_clouds`, which ask `Net` and
draw what `Net.sky_changed` says. A joiner's press is refused in words on its own board ("The host sets the time of
day."), and the buttons and dials go back to what the level draws because they are shown it. The line under the TIME tab
is `ClipboardPage.time_words()`, off the same predicate, so it cannot tell a joiner it may set what will be refused.

**It rides the hello, and there is no second path** (`Net`, "THE SKY"; PROTOCOL 2):

| Message | From | Said | Why |
|---|---|---|---|
| `level` + `time`, `clouds`, `n` | host | until `loaded` | a joiner BUILDS under the host's sky rather than flipping to it once admitted |
| `sky` {`time`, `clouds`, `n`} | host | every 200 ms until heard with this `n` | a change, to every admitted peer; and once on admission, which closes the gap between a peer's `loaded` and a change made meanwhile |
| `sky_heard` {`n`} | peer | to every `sky` | an answer lost is what makes the host say it again |

**`n` counts the host's changes, and a peer takes only a higher one.** Over Steam the carrier is unreliable, so a level
hello said before a change can arrive after the `sky` that announced it and would put the old time back. `read_hello`
drops a time that is not a `DaylightTuning.When` (an enum is not clamped: NIGHT is not a nearer answer to 7 than DAY),
clouds that are not a bool, a sky with no count, and a level hello carrying half a sky; a level hello with NO sky is read,
so a host a protocol behind is refused as "a different version" rather than timing out.

**Per session, not kept, which is the opposite of `Net.level`.** `play_solo`, `host` and `host_steam` start the sky at
`--time=` or the start, with clouds. The desk has nowhere to choose a time, so a sky kept between sessions would be one
nobody on this screen chose -- a joiner back from a friend's night flight flying alone in the dark with no idea why.

**CLOUDS hides the cumulus batch, it does not rebuild it** (`LiftYard.show_clouds`), so turning them back on costs
nothing and every lump keeps its fog share and light. The thermal wisps and rings stay: they mark rising air, which the
simulation has either way. Nobody is whited out inside a cloud that is not drawn -- `_look_for_the_clouds` answers depth 0
while the batch is hidden.

**The gate, and the red that proved it.** `tests/sky_peers.gd` hosts the island in its own process, presses NIGHT, CLOUDS
off and FINE SCENERY the other way from its joiner's on its own board, and reads the other machines' `SESSION_REPORT`,
whose `sky=`, `clouds=` and `finish=` are what that machine DRAWS. It passed first time, so by mutation:

| Mutant | Red on |
|---|---|
| the level hello carries no sky | `a_joiner_after_the_change_arrives_under_the_hosts_night_with_no_clouds` -- its first report said day |
| `_changed_the_sky` owes no peer | `the_joiner_follows_the_hosts_night_and_its_clouds`, after 60 s |
| `decides_the_sky` answers yes on a joiner | `and_pressing_day_on_its_own_board_is_refused_in_words` -- it drew day, and its board said "Sets the time of day and the clouds for everybody in this game." |
| `_start_afresh` keeps the count (`_sky_heard`) | `and_follows_a_fresh_hosts_evening_at_count_1_again` -- a joiner that heard count 1 from one host stayed on its night under a fresh host's EVENING at count 1 |

**The second mutant was GREEN at first, and that was the suite's race, not the code's luck.** The host pressed within a
few frames of its joiner being admitted, while the admission's own `sky` was still unanswered, and that resend carried the
change. The suite now waits for the host to owe its joiner nothing before it presses. A change that is only ever seen
riding somebody else's resend is a change nobody has shown is told.

### Lit windows

In both building shaders, from the same record as the box: a window is lit when a hash of its bay, its storey, its wall
and the building's seed is under the time's share, on walls and never roofs, as EMISSION on the glass. PLAIN lights it
one flat warm colour; FINE picks a warm lamp or a cool screen and a brightness by a second hash (`TownTuning`). Where the
window grid fades to its average with range, the glow fades to ITS average, so a far town is a glow rather than a
shimmer. `TownView.light_windows` sets two uniforms on the two materials, once per change.

### A dial on the panel

Asked for on 2026-09-13: "make me a detent knob switch to move between day, evening, night so i can add it to the
plane". `TimeOfDayDial` (`objects/controls/time_of_day_dial.gd`) is a `DetentDial` whose stops are `DaylightTuning.When`'s
words: in the builder's parts bin, and in no cockpit anybody is given.

**A class, not a DetentDial with other words on it.** A saved layout keeps a part's name, channel, range and scope, and not
its stops, so a relabelled `DetentDial` would come back from SAVE as LOW, MED, HIGH on MODE. A second table of configured
parts beside the class names was the other way. **The pilot's, on no channel** (`Scope.PILOT`, channel -1): nothing sends
it -- `_send_what_moved` and `FlightLevel._draw_cockpit` only touch a CRAFT control on a channel -- and its time is still
the session's -- `FlightLevel.choose_time` asks `Net`, so a joiner's dial springs back to its host's time.

**It asks, and is told.** Turning it past a detent emits `chose_time`; `PilotRig` passes that on as its own `chose_time`,
which `FlightLevel` connects to the same `choose_time` the TIME tab lands on. `_on_the_time_changed` calls
`PilotRig.show_time`, which tells the board and every `TimeOfDayDial` on the station, in reach of a hand or not, and a dial
put in later is shown the time when the rig takes the station again. The dial draws what it is told through `apply`,
which a hand holding it refuses, and when let go goes to what it was last told: it keeps no time of its own. In the hall
there is no sky, so nothing answers, and it stays where it is left.

**`DetentDial.DETENT_HOLD` changes every dial.** A stop is left only a tenth of a stop's throw past halfway, 4.5 degrees on
a three-stop dial. Settling on the nearest stop alone put the boundary at exactly halfway, and a wrist resting there
flipped between two stops at the display rate: with the hold at 0, ten wobbles of 2 degrees either side of the edge wrote
the sky 228 times and clicked 19 times. `tests/feel.gd`'s detent checks turn a whole stop at a time and pass unchanged,
and so does `tests/builder.gd`'s walk of every tenth of the sweep.

`tests/station_shot.gd -- --kind=plane --seat=0 --add=TimeOfDayDial --time=evening --labels` puts one where the builder
lands a part (0.00, 1.06, -0.34 on the plane's pilot station) and shows it a time; `PilotRig.where_a_new_control_lands` is
static for it.

**Its names are read from the seat (2026-09-14)**, and so are every DetentDial's. Photographed from the seat, the time dial
showed no DAY, EVENING or NIGHT, and a plain dial no LOW, MED or HIGH; from straight above both read cleanly, so they were
drawn. Two things hid them. **The names lay flat**, facing up, 6.2 mm a line, 2 mm off the dial's base and 4 mm under the
top of its plate: from the seated eye they were 53 degrees off its line and about 9 px tall, with the middle one behind
the pointer bar. **And the builder landed parts behind the flight display.** `PilotRig.where_a_new_control_lands` stepped
clear of controls only, and put a part at (0, 1.06, -0.34), where every station's `Display` stands with its glass at
z -0.354: the dial's far half and all three names were behind the screen.

Every DetentDial now writes its names on a small dark placard behind the knob, leaning back by
`DetentDial.legend_tilt()` -- the angle a seated pilot looks down at their hands, `atan2(HANDS_BELOW_EYES,
HANDS_FORWARD)` off `CockpitStation`, about 50 degrees, not a typed angle -- each name level and standing where the
pointer's line at that stop meets the row, so the pointer still points at the name it is on. A line is 10 mm (64 x
0.00016); the row stands 40 mm up (20 mm was clear of the pointer in space and not from the seat: see below), and 5 cm behind the middle, because at 4 cm
EVENING (4.3 cm wide) ran into NIGHT. The stop it is on stays amber. Billboarded names were the other way and were not
taken: they turn with the head and stop lining up with their stops. **A dial's own label hangs over the placard**
(`VehicleControl._label_point`, which every control's label is placed by and a DetentDial overrides): over the grip, with
LABELS on, "TIME OF DAY" was seen written through EVENING. **A new part steps towards the seat** while it is inside a
screen's frame or less than `DetentDial.LEGEND_REACH` in front of it, before it steps sideways: on the plane it lands at
z -0.25, which puts it above the stick, so the stick's own label, with LABELS on, crosses the knob until it is moved.

`tests/builder.gd` looks rather than counts. For a plain dial and a time-of-day dial at the builder's landing spot on a
real station, from the eye the seat puts a pilot's head at: every name within 30 degrees of the line to the eye, at least
20 px tall at `HEADSET_PIXELS_PER_DEGREE` (20, a Quest 2), above the plate (read off the plate's own mesh); no screen's
frame on the line to the eye; and, with LABELS on, the dial's own label seen wholly above every name. RED on the code
before: all six names "53 deg off, 9.2 px, -4.0 mm over the plate" (8.8 px for the middle ones) and "behind Display";
and, with the placard in but the label over the grip, "EVENING under DIAL TIME OF DAY (-42.7 deg against -42.2)". GREEN:
8 to 11 degrees off, 28.3 to 28.8 px, 14 mm over the plate, nothing between, the label clear above. Looked at from the
seat, on the stock editor: `tests/station_shot.gd` on the plane's pilot station with LABELS on, and the world from the
pilot's seat at evening, both showing DAY, EVENING in amber and NIGHT; and close, LOW in amber, MED and HIGH.

**And a part the builder adds keeps its grip out of every other control's grab, in nobody's line of sight
(2026-09-14).** Moved clear of the display, a new part landed at (0, 1.06, -0.25), where a dial's knob sat on the stick's
head: its grip was inside the stick's grab, by 15.9 cm and by 16.7 cm with the stick fully back. `PilotRig.place_a_new_control`
now places every new part -- the rig's `add_control`, `tests/station_shot.gd` and the builder suite call it and nothing
else -- by a search that ends: up to 5 steps (9 cm) to either side, 4 rises (4 cm) up and 3 half-steps towards the seat,
nearest first with a side step counted twice. A spot is taken when the new part's grip, turned as it will stand, is at
least `VehicleControl.REACH` from every other control's grip and from a stick's grip at each of the nine places full
deflection puts it; within `CockpitStation.EASY_REACH` of a shoulder and out of `CockpitStation.KNEES`; clear of every
screen and crew board by `DetentDial.LEGEND_REACH`; and off every line from the seated eye to a screen's or the crew
board's face. The shoulder, the arms and the knees are `CockpitStation`'s now; `tests/fit.gd` measured the arms first and
reads them there.

- **One reach from the grips, not two reaches round each origin.** Two reaches between grabs, with a ball round each
  control's origin, was built first and was rejected the same day: the plane was crowded from its second part, and a
  builder that says crowded at once is no builder. The fault had been a grip inside another control's grab, and the hand
  already takes the nearest grip. With one reach, seven time dials fit clear on the plane, the helicopter and the boat
  alike. The first lands at (-0.27, 1.06, -0.34), beside the throttle, 0.35 m from a shoulder: 7.7 cm outside the stick's
  grab at its nearest (7.9 cm outside the boat's throttle's), and 16.3 cm at the stick's full forward and full back.
- **When nothing fits** -- a console already full -- the reachable spot, out of the knees, whose grip is furthest outside
  every other grab, and the board says "TIME OF DAY DIAL is in, but crowded: no clear place was left. Move it." in one
  line, with nothing warned. Through the rig on the plane that was the eighth part.
- **Only a part that is read turns to face the seat**, about the vertical: `VehicleControl.faces_the_eye()`, true for
  `DetentDial`, `RotaryKnob`, `ToggleSwitch`, `CrewButton` and `MfdPanel`. A lever, a throttle, a wheel, a stick and the
  pedals keep the seat's forward, because they are worked along their own axes: turned like everything else, a new throttle
  stood 47.2 degrees off the seat's forward and new pedals 23.7.
- **Off the pilot's sight lines.** Kept two reaches from the stick, a dial at (0.27, 1.18, -0.25) stood 11 cm in front of
  the crew board and hid two of its rows from the seat. The search puts a ball of `DetentDial.LEGEND_REACH` at name height
  against the lines from the eye to 5 x 5 points across every screen's and the crew board's face.
- **Seen from the seat, not reckoned in space.** A DetentDial on a station leans its names up the line to the seated eye
  from wherever it stands, on every move (`NOTIFICATION_LOCAL_TRANSFORM_CHANGED`), so the row is level in the eye's view and
  faces it; and the row stands 40 mm up, not 20, because at 20 the pointer's bar lay across EVENING from the seat -- by 20
  to 28 percent of its height -- though the placard cleared the pointer in space.
- **The reach buzz asks nothing of a part the bin has taken.** `PilotRig._notice_reach` read the grip of a trim wheel
  binned where a test's hand was: out of the tree for a frame and still an object, it printed "!is_inside_tree()". A
  control out of the tree is now nothing in reach.
- **A saved cockpit is not moved by any of it**: the search runs only for a part being added, and a layout file with a
  dial at the old spot loads every control to within a millimetre.

`tests/builder.gd`, measured off the controls and never off the rig's rule. On the plane's, the helicopter's and the
boat's stations a placed dial's grip is at least a reach from every other grip and the stick's nine full-deflection grips,
within an easy reach, out of the knees, its names behind no screen, none of its meshes on a line from the eye to 7 x 7
points across any screen or the crew board, and at least four dials fit clear. A throttle and rudder pedals keep the
seat's forward within 3 degrees. From the seated eye looking at a dial's row, the row leans under 3 degrees, and at each
stop no name's projected rectangle meets the pointer's. RED on the commit before: "plane: it hides Crew from the seat;
plane: only 1 clear before crowded; heli: only 2 clear before crowded; boat: it hides Crew from the seat; boat: only 1
clear before crowded", "ThrottleLever ... turned 47.2 deg; RudderPedals ... turned 23.7 deg", "EVENING under the pointer at
EVENING (28% of its height)"; the row's roll with new parts not turned, "the row leans 17.4 deg across the view"; and the
reach buzz, "1 engine error(s), first: ERROR: Condition "!is_inside_tree()" is true". GREEN: seven clear on each station,
0.0 degrees for the throttle and pedals, the row level at 0.0, the pointer clear at DAY, EVENING and NIGHT, the names 0
to 5 degrees off the eye at 21.4 px and 34 mm over the plate, crowded through the rig on the eighth part, and no engine
error. Looked at from the seat on the stock editor, aimed at the dial where it lands on the plane: DAY, EVENING and NIGHT
each in amber in turn, the row level and the pointer under it, the label above; the stick, the display and the crew board
clear of it; and a plain dial close up, LOW in amber, MED and HIGH.

### How it was proved

- `tests/scenery.gd`, on the level it already boots: the right hand's beam (`force_hand`, re-posed every frame of the
  pull, and `force_input` on the trigger) presses TIME, then EVENING. The level reads EVENING; the board shows only
  EVENING; the light reads energy 0.900, elevation 7.00 and azimuth 250.00 off its own basis; the fog is EVENING's colour;
  both town materials light 0.22; and over sixty frames 0 writes and no value changed. RED, three mutations at once: the
  level not connected to `chose_time` failed the time, the board, the sun, the fog and the windows; a write of the sun's
  energy in `_process` failed the sixty frames with "60 writes in 60 frames".
- `tests/scenery.gd`, on the same level, after the TIME tab's check: two dials put in with `PilotRig.add_control`, the
  second carried 1.5 m along the station, both show the level's EVENING; the beam presses NIGHT and both turn to NIGHT;
  the right hand takes hold of the near one and rolls it one stop, and the level is EVENING, the board shows EVENING and
  not NIGHT, with one detent; ten wobbles of 2 degrees either side of the EVENING/DAY edge write the sky 0 times and click
  0 times; let go, it stays on EVENING. RED, one mutation at a time: the level not connected to `rig.chose_time` left
  "level NIGHT, board NIGHT" under the hand; `show_time` not telling the dials left "near dial EVENING, far dial EVENING"
  at NIGHT; `DETENT_HOLD` at 0 gave "228 sky writes and 19 clicks"; `_take` not showing a new dial the time left "the
  dials on DAY and DAY" at EVENING.
- `tests/builder.gd`: a dial saved and applied to a fresh station comes back with DAY, EVENING, NIGHT, the pilot's, on
  channel -1 and range 2, where it was. RED with `channel = -1` taken out of `TimeOfDayDial._build`: "channel 11".
- `tests/clipboard.gd`'s fit check hands the board a time (a rig with no level has no sky, and the TIME tab then shows a
  line, not buttons) and passes on seven tabs. RED: three 400 px TIME buttons ran the row to 1234 px.
- `tests/scenery_shot.gd --time=day,evening,night` (windowed) holds night to day and to stated floors, off its own
  pictures -- see `_hold_the_night`. On 2026-09-13 (stock 4.7.2, d3d12, RTX 5080, 1600x900 at 3D scale 1.40), on six views
  and both finishes: the red lights at night read 6.6 to 12.8 times brighter than a ring round them (1.2 to 2.0 by day,
  where they are found by colour), and their red pixels a light held or rose against day's on every view. The subjects'
  mean luminance at night against day: ground 0.054 PLAIN / 0.052 FINE on the `grass` view (0.32), mountains 0.062 /
  0.060 (0.45), forest 0.028 / 0.028 (0.38), towns 0.219 / 0.185 on `town_approach` with `FAR_GLOW` (0.397 / 0.345
  before it)
  (0.55, windows and walls together). The floors are about half the darker finish -- mountains 0.03, forest 0.014, ground
  0.03 -- except the towns', 0.035, which sits between their walls alone (HEAD's shader at night, 0.044 to 0.076) and no
  light at all (0.025), so lit windows cannot carry a black town over it.
- RED, windowed: NIGHT with no moon, no ambient and no lit window, and every red light drawn at a tenth. Mountains 0.000,
  forest 0.002 and towns 0.025 failed their floors. Two gates did NOT fail, and both were wrong: the ground was measured
  on the `fields` view, where a fire's smoke column stands in front of the grass and PLAIN smoke stays pale in any light
  (0.131 with no light at all), so the ground is measured on `grass` now; and the dim lights read 0 red pixels a light by
  day AND by night, so night held level with day and passed. `LIGHT_PIXELS_LEAST` (0.25 a light; the fewest a real
  night gave was 0.50) is the absolute floor that now fails it. Run again with both corrected, the same mutation failed
  every gate on seven views -- the red lights on all eleven view-and-source readings, the ground at 0.000, the mountains
  0.000, the forest 0.002, the towns 0.025 and 0.000 -- and the tuning as written passed every one.

### What it costs

**The time change: nothing a frame.** No `_process`; 0 writes in 60 frames after a change (above).

**The lit windows: nothing this instrument can see.** `tests/scenery_shot.gd --hold-fires --time=night`, 240 frames a
view, the three town views on both finishes, four launches alternated A B A B: A with HEAD's `building.gdshaderinc`
swapped in (no window lights), B with this one. GPU median, ms:

| view | finish | HEAD, two launches | lit windows, two launches |
|---|---|---|---|
| town_approach | PLAIN | 0.264, 0.264 | 0.264, 0.265 |
| town_approach | FINE | 0.668, 0.668 | 0.669, 0.669 |
| town_street | PLAIN | 0.257, 0.256 | 0.257, 0.257 |
| town_street | FINE | 0.466, 0.467 | 0.468, 0.468 |
| town_night_lights | PLAIN | 0.217, 0.217 | 0.217, 0.218 |
| town_night_lights | FINE | 0.658, 0.662 | 0.659, 0.662 |

+0.0005 to +0.0015 ms, inside HEAD's own spread between its two launches (up to 0.004 ms). Against what the scenery
plan has left for towns and lights -- about +0.50 ms on FINE and +0.20 ms on PLAIN -- it spends none of it. Two hashes
and an emission term on pixels already drawn, with no branch and no texture.

### Found while looking, and fixed before it landed

The first windowed pass (2026-09-13) showed three things wrong that no gate had asked about:

- **The air's markers glared at night.** The yellow rings on the ground round every thermal and the pale wisps climbing
  under every cloud (`LiftYard`) are unshaded -- light rather than substance -- so the sun going down did nothing to
  them, and at night they were the brightest things on the island. Each preset now has a `markers` brightness (DAY 1,
  EVENING 0.6, NIGHT 0.12) that the level hands `LiftYard.show_daylight` once per change: one alpha on each of two
  materials, kept through every rebuild of the yard.
- **A far town at night was a block of orange.** Past the window fade a facade's glow is what its windows average to,
  and at 2.5 km that drew as flat glowing boxes. `TownTuning.FAR_GLOW` (0.3) scales the averaged glow only; near windows
  are untouched. Points out there needed something other than the facade drawing them, which was priced and built on
  2026-09-15: see "A town's lights from far off".
- **Evening was a heavy orange haze** that washed out the far mountains: the scene's aerial perspective of 0.3 took a
  warm fog colour. Evening's aerial perspective is 0.1 now (a preset number, like the fog colour), and its horizon and
  fog are paler and less orange.

### Why the windows flickered

Reported 2026-09-13: "at evening and night, the windows on the buildings flicker a ton ... it's probably because they are
clipping into the wall of the building ... perhaps move them just a slight amount away from the building." Then: it may
shimmer by day too, less noticeably.

**THE WINDOW DID NOT KNOW WHETHER IT WAS LIT, AND THE FIX IS TWO WORDS: `varying flat`.** Which window is lit is
`window_hash`, a sine hash -- `fract(sin(dot(...)) * 43758.5453)` -- of the window's bay and storey, the face it is on
and the building's seed. The face and the seed reached the fragment shader as ordinary varyings. They are constant
across a face, but perspective-correct interpolation hands a constant back only to about one part in ten million,
differing pixel to pixel and moving as the view does, and a hash that multiplies a sine by 43758 turns that into a
different answer. So the pixels of one near, plainly resolved window disagreed about whether it was lit and changed
their minds as the head moved: bright against dark at any range at night, and invisible by day because no window is lit
then. With `flat`, every pixel of a face has the vertex's value exactly -- down the street at night, turning a quarter
of a pixel a frame, that alone took 1,217 toggles a frame to 153.

**Rejected, and why:**
- *Offsetting the windows off the wall*, which is what the report asked for. A window is not geometry: the whole grid is
  drawn inside the wall's own fragment shader on one box a building, so there is no second surface at any depth to fight
  and nothing to move. The report was right in one way -- the window itself was unstable, pixel by pixel, and not only
  far off.
- *Two buildings sharing a wall plane.* None do: every lot stands back `LOT_MARGIN_MIN` (1 m) from its edge, with a 6 m
  alley between lots and a street between blocks. `tests/towns.gd`'s `and_none_comes_within_a_wall_of_another` holds a
  0.5 m gap (0 pairs); RED with `LOT_MARGIN_MIN` and `ALLEY` at 0, one pair in the eastern town.
- *A second drawer of the same boxes.* Only ROCK and CONCRETE are drawn by group besides the towns, and smoke holds the
  drawn count to the solid list.
- *Post-processing.* No FXAA, TAA, FSR, auto exposure or glow, and scaling is bilinear: a steady edge crosses a pixel
  once through all of that.
- *Pulling the range fade nearer.* It could not have touched a near window, and a pixel is a size on the screen, not a
  distance.
- *Multisampling.* FINE already has 4x, and it smooths geometry edges, never a step inside a fragment shader.

**And the small windows aliased as well**, which is the smaller part and all of the day part. Each window was a hard
`step()`, and a window a pixel or two across turns on and off as the head moves. Each edge is now ramped over one pixel
(`fwidth` of the facade coordinate, never of its `fract`, whose wrap reads as a whole cell). Then panes and lights part:
- PANES fade to the tone they average to once a window's smaller side is under `TownTuning.WINDOW_PIXELS_LEAST` (2).
- **LIGHTS DO NOT AVERAGE.** Averaged, a field of lit windows is a glowing slab: the version that faded lights with the
  panes drew the town from 900 m at night as amber slabs -- the far town's orange blocks again -- though its mean colour
  was HEAD's to within a few levels ((82, 75, 50) against (109, 79, 39) on the left tower). So under
  `TownTuning.LIGHT_PIXELS_LEAST` (3) the lit pattern moves to a COARSER GRID, two windows by two and then four by four,
  with the same share of cells lit and each light the same share of its cell: the light a facade gives is kept, and it
  arrives as fewer points each big enough to draw. The two grids either side of the pixel size are cross-faded, so no
  light pops; the grid at level 0 is the windows with the hash they always had.
- A lit window is filtered in what is seen, not in light: at a glow of 2.2 a pixel a fifth covered still showed nearly
  white, so it is given the light a tonemapper (taken as x / (1 + x)) shows at that share of a whole window, and a whole
  window keeps exactly its glow.

Past `windows_to` both still fade to the average, the glow at FAR_GLOW's share. No TIME, no FRAGCOORD: the same in both
eyes.

**The window numbers reach the materials now.** `bay`, `window_wide`, `window_tall` and `windows_to` had never been
handed over, so both finishes drew the shader's defaults and FINE's numbers in TownTuning did nothing.
`tests/scenery.gd` reads all ten back (RED on HEAD: all ten null). FINE's 2200 m fade is kept: at 1400 m every shimmer
reading matched 2200 m's to within 0.3 %, because the pixel fade takes those windows first.

**The instrument: `tests/scenery_shot.gd --drift=P`.** The camera turns P pixels a frame for 60 frames after each view is
timed, and a pixel that crosses `LIT_LUMINANCE` and crosses back the next frame is a TOGGLE, which an edge moving
steadily never makes. `<view>-<finish>-<time>-shimmer.png` paints where the toggles were. It holds itself to account:
the camera's yaw is read back against the turn asked for (worst 0.000 px) and each picture is held to the one two frames
back. On the parade views (`LIGHT_SHIMMER_VIEWS`) it counts the red aircraft lights instead -- see "An aircraft's lights
by distance". Three things it had to be taught, each a wrong turn first: a sideways STEP counts near edges honestly
moving (0.15 m moves a wall 30 m off seven pixels), so a turn is used instead; **crossings count motion, toggles count
shimmer**; and filtering alone could not move the street at night (1,217 toggles at HEAD, 1,142 filtered at 3 px), while
the heat picture showed streaks across NEAR, large lit windows, which is no aliasing pattern at all -- that picture
found the hash.

TOGGLES A FRAME, stock 4.7.2, d3d12, RTX 5080, 1600x900 at 3D scale 1.40, `--still --drift=0.25`, the camera still 0 on
every one. **The flat varyings alone take out most of the night, and the pixel filter the rest:**

| view | finish, time | HEAD | flat only |
|---|---|---|---|
| town_windows (900 m) | PLAIN night | 605.9 | 248.6 |
| town_windows | FINE night | 621.3 | 261.8 |
| town_windows | PLAIN day | 5.4 | 5.4 |
| town_windows | FINE day | 5.5 | 5.5 |
| town_street (520 m) | PLAIN night | 1216.7 | 153.1 |
| town_street | FINE night | 1224.2 | 157.3 |
| town_street | PLAIN day | 41.2 | 41.2 |
| town_street | FINE day | 37.7 | 37.7 |

Filtering at 3 pixels beat 2 on every reading and went no further, because that version faded the lights with the panes
and drew the amber slabs. What landed trades a little of that count for points of light -- four launches alternated
HEAD, fix, HEAD, fix (a drifting pair and a still pair), toggles a frame:

| view | finish | day | evening | night |
|---|---|---|---|---|
| town_windows (900 m) | PLAIN | 5.4 -> 1.4 | 25.1 -> 3.2 | 605.9 -> 21.5 |
| town_windows | FINE | 5.5 -> 1.3 | 24.8 -> 3.5 | 621.3 -> 26.4 |
| town_street (520 m) | PLAIN | 41.2 -> 15.9 | 654.8 -> 15.9 | 1216.7 -> 43.0 |
| town_street | FINE | 37.7 -> 13.2 | 659.1 -> 21.0 | 1224.2 -> 39.0 |
| town_approach (2.5 km) | PLAIN | 0 -> 0 | 0 -> 0 | 1.2 -> 1.2 |
| town_approach | FINE | 0 -> 0 | 0 -> 0 | 0.3 -> 1.7 |

Night is 3.2 to 4.2 per cent of what it was, evening 2.4 to 14, day 24 to 39. The still camera read 0 on all 36. The
probe's turn read back to 0.000 px everywhere; on `town_street` 4 of 59 frames sat nearer the picture two back than the
last, in every launch of both builds alike.

**By day the picture is the same, less the finest grid.** Still frames, HEAD against the fix, pixels moved by more than 8
of 255: `town_approach` 0 per cent on both finishes; `town_windows` 0.75 PLAIN and 0.93 FINE; `town_street` 1.8 and 2.3 --
the one-pixel ramp round each pane, FINE's now-wired larger windows, and panes under 2 pixels faded to their tone. A
tower's face 900 m off by day reads (117, 101, 105) before and (118, 101, 105) after. At night the far towers are dark
walls with lights on them, as they were, with fewer and larger lights where the windows are smallest.

**What it costs.** GPU median over 120 frames, the two launches of each build: PLAIN +0.000 to +0.0025 ms, FINE -0.004 to
+0.0075 ms, across the three views and three times. Two lit grids a pixel instead of one, and against the +0.50 ms FINE
had left for towns and lights it spends a hundredth of it.

### How far a town's lights are seen, measured before anything was changed (2026-09-15)

Asked for on 2026-09-15: "make sure the building shaders and lights have a higher draw distance, currently they are too
short. I should be able to see the lights on a building from farther away". `tests/town_lights_shot.gd` photographs the
first city from 2, 5, 10 and 15 km south, at night, with the eye 900 m up (over every preset's mist, fog 0.00025) and 40 m
up (in it, fog 0.000483), on both finishes, and prints what decides the reach beside each picture. Double editor, d3d12,
RTX 5080, 1600x900 at 3D scale 1.40, no other lane running Godot.

- **THE MESH WAS NEVER THE LIMIT.** All 11 building batches end at 24,107 to 24,658 m: `FlightLevel._far()`, the camera's
  24 km far plane, which the rock, the paint and the railway are drawn to as well. One number, asked of the camera.
- **THE WINDOW FADE WAS.** A window light fades from 0.55 to 1.0 of `windows_to` -- 770 to 1,400 m on PLAIN, 1,210 to
  2,200 m on FINE -- and past it a facade is `FAR_GLOW` of its average: dim orange blocks, no points.
- **AND THE FOG.** The engine's exponential fog, transmission `exp(-density * d)`: 0.61, 0.29, 0.082, 0.023 at the four
  distances over the mist, 0.38, 0.089, 0.008, 0.0007 in it. The facade's glow is fogged with everything else.
- Brightest pixel in the town's box against its background, PLAIN over the mist: 0.327/0.066, 0.255/0.059, 0.145/0.047,
  0.070/0.047; in it 0.248/0.061, 0.115/0.059, 0.064/0.046, 0.069/0.047. FINE over the mist 0.777, 0.186, 0.134, 0.063.
  So points to 1.4 km (PLAIN) or 2.2 km (FINE), a warm smudge to about 10 km over the mist and 5 km in it, and nothing at
  15 km in either.
- No building carries a street or obstruction light yet; the windows are the town's only light.

### A town's lights from far off: points that carry their windows' light (2026-09-15)

Built on the survey above. **Past `windows_to` a lit town is drawn by POINTS standing off its walls**, one for every
`TownTuning.FAR_LIGHT_WINDOWS` windows a side (`world/shaders/town_lights.gdshaderinc`), and the wall hands its lights to
them across the band before `windows_to`, from one function both shaders include (`town_handover.gdshaderinc`). The wall
gives no light past `windows_to` now: FAR_GLOW's averaged glow survives only inside it, for lights too small to draw at
a grazing angle.

- **ONE LAYER, NOT TWO.** A kilometre's far lights are made by the same worker task and put on nodes by the same build as
  its buildings (`TownView.draw_towns`), so the two arrive, are kept and are let go on the same frame. Two layers on the
  same bounds are two queue entries, split by the 2 ms budget and by work that finishes at different times.
- **THE LIGHT IS KEPT, NOT THE SIZE.** A point carries its cell's lit window area at `window_glow`, turned by its wall's
  facing and through the fog, spread over a separable tent at least `FAR_LIGHT_PIXELS` (1.5) half-wide: a tent sums to
  the same light wherever pixel centres fall, so a point does not flicker crossing pixels or differ between two eyes.
- **CROWDED POINTS ARE GATHERED, faint ones THINNED.** Where points would stand closer than `FAR_LIGHT_SPACING` (3 px) only
  that share is drawn, each carrying the light of those it stands for; where even that is under `FAR_LIGHT_LEAST`, a point
  is drawn at that floor by a stable hash. So a town going away is fewer, brighter points with dark between, and the
  light it gives stays what its windows give. Every 2x2 cluster drawn ran together into a lit maze at 2 km.
- **THE SCENE'S OWN FOG, TAKEN, NOT SKIPPED.** The engine's fog on an additive quad adds the fog colour over the whole quad,
  so the points are `fog_disabled` and take `exp(-fog_density * d)` themselves, with the environment's own density, which
  the level hands to `TownView.show_fog` each frame and which writes only on a change. That is the engine's exponential
  fog exactly; the extinction chosen is the scene's.
- **Placed through `billboard.gdshaderinc`**, no `skip_vertex_transform`: steady on the double build. No TIME, no FRAGCOORD.
- **1.5 px IS PER EYE.** A point's pixel size is worked out from the projection and the viewport of the eye drawing it, so in
  a headset it is 1.5 px of that eye's own render target: at the project's assumed 20 px a degree a headset shows
  (`tests/builder.gd`, a Quest 2) and `PilotRig.RENDER_SCALE` 1.4, about 28 px a degree. The desktop pictures here are
  1,260 rows over 75 degrees, 16.8 px a degree, so a point is a larger share of a degree on the desk than in the headset.
- **The fog is one include, `world/shaders/scene_fog.gdshaderinc`,** so cockpit-mist can add a height-banded density in
  one place for every shader that takes the fog itself.
- **AND IT MATCHES THE ENGINE'S, MEASURED** (`tests/town_lights_shot.gd --fog-check`): at each finish's handover distance,
  900 m up, the walls' lights alone and the far lights alone, each lit against unlit so walls, roads, sky and the fog's
  colour cancel, with the fog at night's two densities and at none, in linear light under the linear tonemapper. What
  each lets through, walls against far lights: PLAIN at 1,400 m 0.6705 / 0.6676 over the mist (0.00025) and 0.4489 /
  0.4459 in it (0.0005); FINE at 2,200 m 0.5617 / 0.5594 and 0.3177 / 0.3139. At most 0.4 % of the light apart, under one
  8-bit step of a lamp at full brightness in linear light. The check fails if the environment gains height fog,
  volumetric fog or another fog mode. With no fog at all the two carried the same light to within 6 % on PLAIN (183.9 /
  194.4) and 1 % on FINE (80.4 / 81.0): the handover keeps the light, not only the fog.

**Two traps, each a picture that looked like a tuning problem:**

- **A POINT IN FRONT OF ITS WALL LOST THE DEPTH TEST TO IT.** Pulled towards the eye by its own radius (0.5 m off the wall
  plus 3.6 m at 2 km), every point in front of a face was hidden, and the only ones drawn were those whose quads reached
  past a building's edge: the town drew as outlines of light. Painted by wall it was the same; pulled 30 m, or with no
  depth test, every face filled. It was never depth precision: a quad faces the eye, and on a wall seen at an angle its
  corners lean into the wall by up to its radius times the root of two, which a pull along the ray does not undo. A pull
  of 1 % of the range along the ray filled the faces and was built first, but let a nearer block within that 1 % fail to
  hide a point. **Each point now stands off its own wall along the wall's normal by half again its radius** -- 3.6 m at
  2 km, 27 m at 15 km -- which clears the wall at any angle and cannot reach past a neighbour an alley's 6 m away. At 2 km
  that drew 382 points against the pull's 365. Looked at from 40 m up at 1.6 and 2.5 km, where towers stand in front of
  lower blocks (`godotgames-drafts/2026-09-15/cockpit-townlights/occlusion`): every tower face carries its own grid of
  points, and nothing shows through a tower from the blocks behind it.
- **`PROJECTION_MATRIX[1][1]` IS NEGATIVE** on Godot's RenderingDevice renderers, which flip Y inside the projection.
  Metres a pixel taken from it came out negative, gathering clamped every point to nothing, and no far light drew at all
  -- while the brightness, which squares it, looked right. Split by a variant with gathering off (drew), one keeping every
  point (drew, white) and one painting gathered, share and kept as colours (black: all three near zero). Take `abs()`.

**MEASURED**, double editor, d3d12, RTX 5080, 1600x900 at 3D scale 1.40, `tests/town_lights_shot.gd`, the same poses as the
survey. Brightest pixel in the city's box against its background; "hidden" is how many pixels of the box change with the
far lights hidden, against 0 between two frames of the same picture:

| night | 2 km | 5 km | 10 km | 15 km |
|---|---|---|---|---|
| PLAIN over the mist, before | 0.327 / 0.066 | 0.255 / 0.059 | 0.145 / 0.047 | 0.070 / 0.047 |
| PLAIN over the mist, after | 0.987, 365 points, 2,842 hidden | 0.691, 88, 696 | 0.447, 20, 148 | 0.185, 6, 22 |
| FINE over the mist, before | 0.777 | 0.186 | 0.134 | 0.063 |
| FINE over the mist, after | 1.000, 426, 2,753 | 0.753, 89, 684 | 0.442, 20, 142 | 0.153, 6, 24 |
| PLAIN in the mist, before | 0.248 / 0.061 | 0.115 / 0.059 | 0.064 / 0.046 | 0.069 / 0.047 |
| PLAIN in the mist, after | 0.984, 232, 1,797 | 0.463, 57, 426 | 0.064, 0, 0 | 0.069, 0, 0 |
| FINE in the mist, after | 0.993, 296, 1,787 | 0.501, 57, 417 | 0.064, 0, 0 | 0.069, 0, 0 |

Backgrounds are as before (0.047 to 0.066). At dusk, over the mist, hiding the far lights changes 78 pixels at 5 km on
PLAIN and 82 on FINE, and 0 at 10 km, where evening's fog (0.0003) leaves 0.050 of the light. The table is the shipped
tuning, four windows a side; at two a side the same views read 0.890, 0.819, 0.467 and 0.255 over the mist, with 569, 90,
18 and 4 points -- brighter near and far, fewer points far, and three times the memory (below).

- **By day the far lights draw nothing**: 0 pixels change with them hidden on both finishes at 5 and 10 km, on the
  finished tuning and on every tuning tried before it.
- **Across the handover, no dip and no bump**: 21 readings from 600 to 2,600 m on each finish, none under three quarters
  of the lower neighbour or over a third above the higher. **That check cannot see an early handover**: with the wall's
  share taken at 0.6 of `windows_to` it still passed, because the town's light falls steeply with distance anyway. What
  holds the handover to one band is headless -- both shaders take `town_far_share` once and work nothing out beside it.
- **By day nothing lights a far point twice over**: day's `windows_lit` and its `window_glow` are both 0, and either alone
  keeps the far lights dark. A mutant that only forced every point lit drew nothing by day, so the red is one that ignores
  the time of day altogether.
- **In the default low mist a town's lights reach about 5 km, not 10.** Transmission at 10 km is 0.008 (fog 0.000483, a
  meteorological visibility of 3.912 / 0.000483 = 8.1 km), and no floor or spacing tried drew a point there. Lights are
  seen somewhat past the visibility in life; 0.8 % of a window's light is past what a pixel can show over this sky. Over
  the mist, at 900 m, the city is points to 15 km.
- **Building masses** by night are the lights; the walls under the moon are within a few levels of the fog by 5 km.

**AND WHAT IT KEEPS: THE FIRST GATE FOUND THE MEMORY.** `tests/scenery_memory.gd` flies 220 km over the island tiled to
72 km and holds the last third's static memory within five per cent of the first's. With far lights at two windows a side
it read 186.5, 214.2 and 206.8 MB by third, where the section above records 66.5, 67.9 and 67.4 before any far light:
red, and a cost the timing budget below never looked at. The yard keeps a let-go cell's finished numbers, and each
kilometre of far lights carried an Array of Transform3D and one of Color beside its buffer, for the tests alone -- on the
double build every transform in an Array is a heap Variant. **A kilometre of far lights keeps only the buffer it was
handed** now, and `tests/town_lights.gd` decodes that: 118.4, 127.5 and 123.7 MB, green by 0.6 MB, the rest being the
buffers themselves (1.7 MB an island, tiled 25 times). **At four windows a side, 8,288 points against 26,772: 83.4, 87.0
and 85.4 MB**, green by 2.2 MB and 18 MB over the island with no far lights; the towers at 1 km still read as lit window
grids and the city at 2 km as points (`godotgames-drafts/2026-09-15/cockpit-townlights/win4`).

**AND WHAT ONE KILOMETRE COSTS TO BUILD** (asked for at under 20 MB of instance data held and under 10 ms a kilometre on a
worker; `tests/town_lights.gd`, on the double editor's GDScript): 8,288 points in 11 kilometres, the densest the inner city's
(0, -1) with 93 buildings and 2,816 points, 176 KB, worked out in 3.79 ms; 0.51 MB for the island, 12.6 MB tiled to the
72 km world. The suite holds both.

**WHAT IT COSTS.** Over the inner city at night, over the mist, launches alternated far lights hidden (the probe's
`--far-lights=off`) and shown, two of each, one at a time, with no other Godot process running on the machine. GPU median
over 240 frames, ms:

| view | hidden | shown | added |
|---|---|---|---|
| PLAIN, 5 km | 0.239, 0.239 | 0.242, 0.241 | +0.003 |
| PLAIN, 15 km | 0.182, 0.180 | 0.187, 0.185 | +0.005 |
| FINE, 5 km | 0.468, 0.469 | 0.488, 0.487 | +0.019 |
| FINE, 15 km | 0.340, 0.339 | 0.358, 0.357 | +0.018 |

- **Draw calls: +11 in every view**, one batch a built kilometre of buildings. FINE pays more GPU than PLAIN for the same
  quads, which is its 4x multisampling of every covered pixel.
- **Render CPU did not move beyond its own spread.** Medians shown against hidden read +0.011 to +0.051 ms in one pair and
  -0.022 to +0.005 in the other, where the two hidden launches alone differ by up to 0.044. Against 0.2 ms allowed, the worst
  reading is a quarter of it.
- **A headset roughly doubles all of it**: two views, so about +0.04 ms GPU on FINE, +22 draws, and at worst +0.1 ms render
  CPU -- inside the 0.3 ms GPU and 0.2 ms CPU asked for with room.
- **That table is two windows a side, 26,772 points, timed with nothing else running, and it bounds the shipped four a
  side from above**: the same draws with a third of the instances. Timed again at four a side, the same alternated pairs
  read +0.000 to +0.009 ms GPU on both finishes, +11 draws and render CPU flat at 0.100 to 0.108 ms -- but with the mist
  and moon lanes' Godot running beside it, one windowed, where two hidden launches of one view differed by 0.012 ms. So
  those are read as no worse than the quiet table, not as a finer number.

**REJECTED**
- *Raising the buildings' `visibility_range_end` to 15 km*: they already reach the camera's 24 km (the survey), and
  cockpit-streaming priced 8 to 24 km of scenery at about 0.02 ms GPU. Reach was never the fault.
- *The engine's fog on the points*: adds the fog colour over each quad, a square round every point at dusk.
- *A far-lights layer of its own*: see ONE LAYER.
- *A lower floor*: 0.015 and 0.01 drew 10 and 15 km over the mist to the hundredth of 0.03's picture.
- *Spacing 2 px*: dimmer far points (0.166 at 15 km) and a 5 km town running together.
- *Two windows a side*: brighter far points, but 26,772 of them, and a memory flight green by 0.6 MB.

`tests/town_lights.gd` holds, headless: every point off a wall of a building in the list and facing out (8,288 points);
the wall area they carry (0.997 of 1,055,348 m2, less only part cells); each kilometre's lights drawn at least as far as its
buildings; flown 14 km out and back with 11 kilometres let go and built again, 0 holes, 0 doubles, 0 lights without
buildings; with each cell's work slowed to 50 ms every kilometre lit and no watch over 661 us; and the handover taken from
one function in both shaders. RED, one mutant at a time, each file restored and its SHA-256 checked:

| broken on purpose | what failed |
|---|---|
| the lights' reach typed as 15,000 m | the reach: "(-4, -1) ends at 15560, its buildings at 24559.6", at both two and four windows a side |
| each kilometre's lights worked out in the build, on the main thread | off the frame: the worst watch 94,955 us at two windows a side and 54,489 us at four, against one cell's work of 50,000 |
| the wall's share taken at 0.6 of `windows_to` | one function: "the wall does not take 1 - town_far_share(far, windows_to) once"; the windowed sweep passed (above) |
| the far lights lit whatever the share, at night's glow whatever the time | the probe, by day: 743 pixels at 5 km and 162 at 10 km at two windows a side, 839 and 163 at four, changed with them hidden, 0 between two frames |

### Obstruction lights on tall buildings (2026-09-15)

Asked for on 2026-09-15: "street lights and obstruction lights on buildings, absolutely, yes". Until then a town's windows
were its only light (the survey above), and the red lights THE TOWNS once promised (WP5) were never built.

**THE RULE IS ICAO'S, a faithful subset** (Annex 14 Vol I, chapter 6, read in the 2004 text; FAA AC 70/7460-1M agrees where
it speaks). `TownView.obstruction_lights_on` puts them on, from the building's own box:

- **Which buildings: taller than 45 m** (`TownTuning.OBSTRUCTION_HIGH`). 6.3.7: an object "greater than 45 m" takes
  medium-intensity lights; the FAA lights a structure over 150 ft (46 m) with L-864. The island has 13: ten towers of
  118.8 to 212.4 m and three blocks of 46.8 to 50.4 m.
- **Where: the four vertical corners, at the top and at levels down to the ground.** 6.3.11 and 6.3.14 put the top lights on
  the highest points and edges; 6.3.17, for medium-intensity Type B over 45 m, adds levels "spaced as equally as practicable"
  no more than 52 m apart (`OBSTRUCTION_LEVELS_APART`), alternately low-intensity Type B and medium-intensity Type B. Measured
  from the building's ground, not from the tops of nearby buildings, which 6.3.17 also allows. 160 lights on the island.
- **What: medium-intensity Type B, 2,000 cd flashing red, on top; low-intensity Type B, 32 cd steady red, between** (Table 6-3).
- **Flashing together, 30 a minute.** 6.3.32: medium-intensity lights on an object "shall flash simultaneously"; Table 6-3
  allows 20 to 60 a minute and the FAA's L-864s flash together at 30. Half a flash a second is a quarter of the 2 Hz under
  which a flash is a strobe. On for 0.5 s of the 2 s, eased over 0.1 s -- chosen by looking; neither document read gives an
  on-time.
- **At night.** Medium-intensity Type B is the night half of a dual system. The lamps show `TownView.lamps_for(windows_lit)`
  of their light: that share over night's, so 0 by day, 0.4 at evening and 1 at night, worked out from the windows' own number.
- **NOT DRAWN: the vertical beam.** Table 6-3 has a medium light at 3 % of its intensity 10 degrees below the horizontal,
  which is where a roof is seen from 900 m up and 5 km off.

**ONE INSTANCE, NEAR AND FAR** (`world/shaders/lamp.gdshaderinc`). A lamp is not handed from a near drawing to a far one:
the same quad is a lantern-sized spot close to and a point at the far lights' 1.5 px floor far off, so no distance draws it
twice or not at all. Its candela is turned into the light the far lights carry by one scale taken from the windows
(`TownTuning.LIGHT_PER_CANDELA`: a lit window, 2.85 m2 at about 200 cd/m2, is 570 cd and draws 6.3), so a red light and a
window keep the proportion they have in life. Close to, a lamp grows to at most 3 px before it is simply as bright as it is.
Stood off its corner along the diagonal, and up off the roof, by two of its radii.

**FLASHING FROM THE TICK.** `TownView.show_flash(ticks, tick_dt)` hands the materials ONE phase, from
`Engine.get_physics_frames()` and `Sim.tick_dt()`, which the level passes every frame; it writes once a tick. No light carries
a phase of its own and the shader never reads TIME. So every light on the island flashes together, and two views of the same
tick draw the same flash whenever they are drawn. **Two peers are in phase only by chance**: `CockpitWorld` binds no tick
number, so the tick counted is this machine's; a peer-exact flash is a C++ getter for the server's tick, not built.

**BUILT WITH THE BUILDINGS**: the work that makes a kilometre's buildings and far lights makes its obstruction lights, and
the same build puts all three on nodes -- a third node, only on the 3 kilometres that have any. Drawn as far as the far lights.

**SEEN, AND THEN THE FOG.** A red at 10 km over the mist was 7 red points in the city's box and nearly nothing to look at:
2,000 cd spread over a 1.5 px tent, then fogged to 0.082, drew at 0.005 of linear light. A point of light is seen by the
illuminance it puts on the eye (Allard's law), and ICAO Doc 9328 works out a light's visual range at night against 1e-6 lux;
a screen cannot show that. So `lamp.gdshaderinc` takes each lamp's light in CLEAR AIR, spreads it over its tent, floors the
tent's peak at `TownTuning.LAMP_SEEN_PEAK` (1.0) where the clear-air illuminance, candela over distance squared, is over
`LAMP_SEEN_LUX` (eased in over four times it), and only then multiplies by the fog's transmission -- floor and all. **The
first floor sat after the fog, gated on the fogged illuminance: a lamp over the threshold drew at the floor however thick the
mist, a light through fog that stops it.** Team-lead caught it from the description before any picture of it was looked at.

**AND IT TAKES THE FOG EXACTLY** (`tests/town_lights_shot.gd --fog-check`, which now holds the lamps as well as the far
lights): at 5 km, 900 m up, at night, no window lit, the linear tonemapper, the lamps' light -- the city with them shown
against it with them hidden -- with night's mist density (0.0005) against none: 0.884 against 10.911, 0.0810 through where
exp(-density * distance) is 0.0821. Every red there is on its floor, so a floor after the fog would have let through 1.

**MEASURED**, double editor, d3d12, RTX 5080, 1600x900 at 3D scale 1.40, `tests/town_lights_shot.gd --compare`, the first city
from the south with the flash held on (`godotgames-drafts/2026-09-15/cockpit-streetlights/step1`, `step1d`, `step1e`). How many
pixels of the city's box change with the lamps hidden, against 0 between two frames of the same picture:

| night, PLAIN / FINE | 1 km (160 m up) | 2 km | 5 km | 10 km | 15 km |
|---|---|---|---|---|---|
| over the mist (0.00025), before the floor | -- | 303 / 294 | 148 / 144 | 47 / 45 | -- |
| over the mist, with it | 565 / -- | 399 / 394 | 183 / 175 | 123 / 120 | 30 / 29 |
| in the mist (0.000483, 40 m up), with it | -- | 278 / 267 | 128 / 120 | -- | -- |
| evening, over the mist | -- | 247 / 245 | 84 / 82 | -- | -- |
| day | -- | 0 / 0 | 0 / 0 | -- | -- |

**A COUNT OF RED POINTS IS NOT IN THAT TABLE ON PURPOSE.** The probe's first test for a red pixel compared it with one corner
of the box, and the low mist's tint passed it: 680 "reds" at 2 km in the mist. Compared with the median of the 5x5 ring round
each pixel, over the mist it finds 41 at 2 km and 14 at 10 km with the lamps shown and 0 with them hidden; but from a low eye
the lit brick walls pass too, 203 at 1 km and 216 at 2 km in the mist WITH NO LAMP DRAWN. So the probe prints the red count
only beside the same count with the lamps hidden, and the changed pixels are the reading. Looked at: the reds on every tower
corner at 1 km from 160 m up; at 2 km the corners and their levels, over the mist and in it; at 5 km a tower's levels merge
into short red bars, front corner over back, as a lit mast does; at 10 km a red point at each corner of the two towers in
view; at dusk faint pink points in a pale haze.

**WHAT IT COSTS.** Over the city at 5 km at night, alternated launches with the lamps hidden (`--lamps=off`) and shown, two of
each, no other Godot drawing (`godots` logged at the start and end), GPU median over 240 frames: PLAIN 0.246 / 0.247 hidden,
0.246 / 0.246 shown; FINE 0.480 / 0.480 and 0.480 / 0.480. **+0.000 ms on both finishes**, render CPU 0.098 to 0.108 either way,
**+3 draws** (one a kilometre with a tower). Timed before the floor, which adds a smoothstep a vertex. In a headset, twice the
draws and the vertex work, and still nothing this instrument sees.

**NOT HERE YET: peer-exact flashing.** `CockpitWorld` binds `tick` and `tick_rate` but no tick number, so the phase is this
machine's physics frames. A getter for the server's tick, handed to `show_flash` instead of `Engine.get_physics_frames()`, is
a small C++ follow-up team-lead is to sequence with the other C++.

`tests/night_lights.gd` holds, headless, against the boxes and never against `obstruction_lights_on`:

- every light on a vertical corner of a building over 45 m, facing out along its diagonal; four flashing at every such
  building's top; levels no more than 52 m apart down to its ground, flashing and steady by turns; none on a lower building
  (160 lights on 13 of 377);
- the same with every building lifted 37 to 437 m off y = 0;
- one batch a kilometre, drawn at least as far as its buildings (3 batches);
- dark by day, 0.400 at evening, 1 at night, through `light_windows`, and the shader multiplying its light by it;
- no light with a flash of its own, the shader flashing on `flash_phase` alone with no TIME, the same tick handed 370 ms
  apart by the wall giving the same phase, and half a cycle's ticks later half a cycle on;
- with every cell's work slowed to 50 ms, the lights arriving with no watch over 181 us.

`tests/scenery.gd` holds the level's wiring: at evening the lamps read evening's share, and the phase on the material is the
tick's within two ticks.

RED, one mutant at a time, each file restored and its SHA-256 checked:

| broken on purpose | what failed |
|---|---|
| the lamps lit at night's share whatever the time | "day 1.000, evening 1.000 (wants 0.400)" |
| obstruction lights on every building | both placement checks: "1616 lights ... 18.0 m building 0 has 4" |
| the top taken as twice the half-height, as if every building stood on y = 0 | only the lifted check: "140 on no corner ... 165.6 m building 30 has no lights at its top (598.6)" |
| the phase from the wall clock, not the tick | the flash check: "half a cycle's 60 ticks later hands 0.1760 after 0.1760" |

The wall-clock mutant first passed the same-tick half of that check: the suite waited on a timer, which under `--fixed-fps 120`
runs on the game's clock -- 0.37 s took 1 ms of the wall's. It waits with `OS.delay_msec` now.

**THE REDS HAVE A REACH OF THEIR OWN (step 3).** Built at first by the buildings' own work, a tower's reds went with its walls
-- and the buildings' reach is what a player's view distance is to shorten, where an obstruction light should reach the
camera's far. They are a layer of their own (`TownView.OBSTRUCTION`) over the kilometres with a building over the height,
drawn to `draw_towns`'s `lamp_reach`, which defaults to the buildings' reach: the level's call is unchanged today. The far
lights stay one layer with their walls because a wall hands its light to them; a red has no wall-side twin. `tests/night_lights.gd`
flies it with the buildings at 4 km and the reds at 24 km, 14 km out and back: reds on let-go walls on 3,095 steps, 0 holes,
0 doubles, every tall kilometre built again at home; and each batch's range reaches `FAR` beyond its own furthest light --
"as far as its buildings" had read 24,122 m against 24,559 m once the reds' box held only the tall buildings.

The 220 km memory flight with the reds on their own layer: 86.2, 89.4 and 88.0 MB by third, against 85.8, 89.5 and 87.9
before. RED, each file restored and its SHA-256 checked: the reds' layer handed the buildings' reach -- "0 steps with reds
on let-go walls; 3253 holes"; the street lights built without their pools -- the arrival check "13 poles' and 0 pools'
batches" and the flight "11041 holes". Looked at (`godotgames-drafts/2026-09-15/cockpit-streetlights/step3`), the city at night from 2 and 10 km on
both finishes: with the level's one reach nothing moved -- the lights hidden change 6,289 / 6,227 pixels at 2 km and 502 /
505 at 10 km, PLAIN / FINE, as in step 2's pictures to the pixel, with 22 / 24 and 7 / 7 red points shown and 0 hidden.

### Street lights (2026-09-15)

**SWITCHED OFF THE SAME DAY, AND KEPT.** The user, flying PC VR on PLAIN: "The streetlights take up too many resources, let's
remove them from the cities (but keep them around we will use them at some point)" (2026-09-15). **`TownTuning.STREET_LIGHTS_ON`
is false.** `TownView.draw_towns` reads it once, and off it makes nothing of theirs: no street is filed as lit, so no kilometre's
work makes a lamp buffer and no build puts lamps, poles or pools on nodes; no pool or pole material, no pole or pool mesh, and
no railway asked of `Terrain`. Hiding the nodes would have kept every cost but the draw. The windows' far lights and the red
obstruction lights stay on, and the lamps' material stays with the reds. Everything after this paragraph describes the lights as
they are when switched on. It covers both worlds: the seated towns on the generated ground file their streets through the same
`draw_towns`, and `tests/terrain_level.gd` turns the lights on for its seated town's lamps.

- **Kept alive.** `TownView.street_lights_in_tests` builds them whatever the switch says, and `tests/night_lights.gd` runs every
  street-light check below with it on (3,635 lamps, as before). Its first check holds the switch as shipped: 0, 0 and 0 lamps',
  poles' and pools' batches of 13 lit kilometres and no pool or pole material, with 15 paint, 11 far lights' and 3 obstruction
  batches built, so the zero is not an empty town. RED, the switch ignored (`street_lights_on()` returning true): "[13, 13, 13]
  lamps', poles' and pools' batches against 0 each ... pool or pole material made true"; restored by bytes, SHA-256 checked.
  `tests/town_lights_shot.gd --street-lights=on` builds them to look at or to time.
- **What switching them off saves in the view**, double editor, d3d12, RTX 5080, 1600x900 at 3D scale 1.40, the first city at
  night from 2 km and 900 m up in clear air (`tests/town_lights_shot.gd`, which prints each view's cost beside its picture;
  `godotgames-drafts/2026-09-15/cockpit-lampsoff`), on against off: PLAIN 122 / 107 draws (**-15**), 223,544 / 213,298
  primitives in view (**-10,246**), the shadow pass unchanged (9 draws, 536,120 primitives: nothing of theirs casts), video
  memory 256.31 / 254.89 MB (**-1.4 MB**, 0.67 of it buffers); FINE 125 / 110 draws, 390,882 / 380,696 primitives, the same video
  memory. A headset draws each view twice. **Not the probe's static memory**: one launch with the lights off read 176.97 MB and
  another of the same build 158.18 MB, so a difference between two launches says nothing about the lights. The headless figure
  below is measured inside one process.
- **What building them cost**, headless, the island's towns drawn to 24 km and built from the origin by `watch` alone, three
  launches each way, alternated, beside other lanes' suites (drafts `cockpit-lampsoff/scratch`): `draw_towns` 11.5-12.4 ms on
  against 8.8-9.9 off; **the main thread's `watch` time for the whole build 9.4-10.7 ms against 5.7-6.5, about +4 ms**; **static
  memory +1.04 MB** (the towns' build read 3.35 MB on and 2.31 MB off in every launch); 39 nodes and 10,905 instances. On the workers, 8.1 ms for the 13 lit kilometres; on nodes, 0.52-0.62 ms cold
  and 0.22-0.35 ms warm.
- **Looked at**, the same pictures' 4x crops: on, a lamp every 32 m down every street; off, the streets dark between lit
  windows, warm on PLAIN and warm and cool on FINE, the towers' reds on, and no lamp or pool.
- **The red obstruction lights are still on, and cost next to nothing**, measured the same ways (2026-09-15). From 2 km at
  night, shown against hidden (`--lamps=off`): 107 / 105 draws on PLAIN and 110 / 108 on FINE, and 264 primitives fewer on
  both, which is two of the three tower kilometres in frame at a batch each. On the island, 160 lights in 3 batches, worked
  out in 0.13-0.14 ms on the workers, put on nodes in 0.035-0.128 ms cold and 0.013-0.018 ms warm, 20.9 KB of static memory
  of which 10 KB is instance data. Three launches, all the same (drafts `cockpit-lampsoff/scratch/reds_cost_*.log`). Their
  GPU time over the city at 5 km was +0.000 ms ("Obstruction lights on tall buildings").

Asked for with the obstruction lights: "street lights and obstruction lights on buildings, absolutely, yes". **Every town's
grid streets are lit, and the roads between towns are not**, as a rural road is not: `TownPlan.streets()` tags each street
mark with its town's `block`, and `TownView.street_lights_along` stands lamps along every mark that carries one.

**THE LAYOUT, by the rules road lighting is laid out by**, every number in `TownTuning`:

- **Height by width.** A street at least 20 m wide is a main road with 10 m lamps; a narrower one has 8 m. The catalogue's
  streets are 32 m in a city and 14 m in a town.
- **Spacing by height**, about 3.6 mounting heights (the usual 3.5 to 4 for uniformity), laid at an EVEN PITCH OF WHOLE LAMPS A
  BLOCK, half a pitch in from each junction: three in a city's 96 m block and two in a town's 64 m, 32 m either way -- 3.2 and 4
  heights. **Two layouts were built first and rejected:** evenly between junctions over the span alone (a town street one lamp a
  block a side, 64 m apart; a city street 68 m across each junction), then as many a block as kept the average nearest but
  still between junctions (18.7 m apart within a city block and 58 m across a junction, 4,862 lamps against today's 3,635).
- **A corner is lit once.** Half a pitch in from a city junction is its corner, on the crossing street's edge: the street
  along x keeps that lamp, and a street along z keeps `STREET_LIGHT_JUNCTION_CLEAR` (4 m) clear of the crossing, so no corner
  has two poles a metre apart and the corner pole serves both streets' kerbs.
- **Sides by width over height** (CIE 115's arrangements): one side up to 1, staggered to 1.5, opposite beyond. Both kinds of
  street here are opposite.
- **Where**: 0.8 m in from the kerb, the arm reaching 1.8 m over the street, and none within 8 m of the railway where a street
  crosses it (`Terrain.rail_points`).
- **Light**: 6,000 cd straight down (a 100 W LED lantern of about 12,000 lumens), high-pressure sodium orange, showing 15 %
  of it off its beam and from above.
- **No collision.** About 3,600 static boxes against the island's 650 is boot time and every linear walk of the solid list;
  a pole is a picture, as FINE's roof dressing is.

**ONE BUFFER, THREE BATCHES, WITH THE PAINT.** The work that makes a kilometre's paint makes its lamps (16 floats a lamp), and
one build puts the paint and three batches over that one buffer on nodes: the LAMPS (`lamp.gdshaderinc`, kind 0, drawn as far
as the paint -- a lamp is its own far light), the POLES (a pole, arm and head in the lamp's own space, to `POLES_TO`, 1 km)
and the POOLS (`lamp_pool.gdshader`, to `POOL_TO`, 1.5 km). A lamp's basis is along the street, UP SCALED TO ITS HEIGHT and
out towards the middle, so local y = -1 is the street's top where the pole stands and the pool lies. The street's own height,
from its mark: a street on ground that is not at y = 0 carries its lamps on its own top.

**THE POOL.** Under a lamp of I candela at height h, the street r metres from its foot has I h / (h^2 + r^2)^1.5 lux, and a
matt street of reflectance 0.08 shows 0.08 / pi of that as luminance: about 1.5 cd/m2 under a lamp, what a lit street is. No
OmniLight3D: thousands of dynamic lights is no headset's frame. It takes the fog and the low mist it lies under, sampled once
a vertex. Integrated, a pool sends the eye 2 x 0.08 x I candela times the sine of its elevation, and across 825 m to 1.5 km
the pool gives up exactly the share the lamp's point takes, from `lamp_pool_far_share` in `world/shaders/lamp_pool.gdshaderinc`.

**DRAWN FOR AN EYE ADAPTED TO THE NIGHT** (`TownTuning.night_adaptation()`, about 13). At the windows' scale -- a lit window's
200 cd/m2 at their glow of 2.2, `LIGHT_PER_CANDELA` -- a lit street's 1.5 cd/m2 drew at 0.017 of linear light, and from 300 m
down the inner city's avenue no pool could be seen (`godotgames-drafts/2026-09-15/cockpit-streetlights/step2`). The night
here is not drawn to a photometer. So the gain is worked out, never typed: the NIGHT preset's moonlit street as it is drawn
(the asphalt's albedo under its ambient colour and the moon on the flat, about 0.028) is taken as a real moonlit street
(0.12 lux of a gibbous moon 40 degrees up on asphalt of 0.08, 0.003 cd/m2), and a street under a lamp is drawn as much
brighter than that as it LOOKS -- its luminance over the moonlit street's, to the third power (Stevens' brightness law) -- then
divided by what the one scale would draw it at. A darker or brighter NIGHT moves it. **Rejected: an eye-chosen gain of 8**
(team-lead: a free number); 16 and 32 had washed the avenue out to haze. **The windows, by the same law**, would be drawn at
about 1.1 for their 200 cd/m2 against their tuned glow of 2.2: about twice as bright as this eye sees them. Their glow is the
town's own tuning, looked at and measured before this lane, and is left as it is.

**MEASURED, headless** (`tests/night_lights.gd`): 3,635 lamps on 108 of 108 streets in 13 kilometres; 0 on no street, 0 within
a metre of a building, 0 within 8 m of the railway, 0 in another street's carriageway, 0 poles within 3 m of another; the
gaps along every kerb, whoever's pole it is, 30.4 to 32.8 m; the same with every street lifted 250 m. The densest kilometre,
the inner city's (0, -1), 828 lamps worked out in 2.16 ms; 0.22 MB for the island, 5.5 MB tiled to the 72 km world.

**WHAT THE MAIN THREAD PAYS.** The densest kilometre's three batches made and added to the tree: 626 us the first time, 15 to
34 us after (held under 500 us). The worst watch while every lit kilometre arrived with its work slowed to 50 ms read 1,109
to 1,523 us -- and that is the yard's own budget (`ATTACH_BUDGET_USEC`, 2,000 us a watch), not the lamps: flown in from 60 km
with the streets lit and unlit alternately, three launches each, the worst watch read 1,882 to 2,032 us lit and 1,133 to 1,953
unlit. **Rejected: spreading the poles, the points and the pools over three yard ticks** -- a tenth of a millisecond warm, and
the cold build once a session.

**THE MEMORY FLIGHT** (`tests/scenery_memory.gd`, 220 km over the island tiled to 72 km): 85.8, 89.5 and 87.9 MB by third with
the street lights, against 84.3, 88.0 and 86.4 with the obstruction lights alone -- +1.5 MB, green by 2.1 MB. **HITCH**
(`tests/hitch_probe.gd`): a tick's median 0.087 to 0.088 ms, 0 of 1,800 over budget at 60 and at 120 Hz.

**LOOKED AT**, double editor, d3d12, RTX 5080, 1600x900 at 3D scale 1.40, `tests/town_lights_shot.gd --compare`
(`godotgames-drafts/2026-09-15/cockpit-streetlights/step2c`): down the inner city's avenue from 300 m at 12 m up, the street
and its pavements lit warm under a pole every 32 m, the poles dark against it; from 160 m up at 900 m, every street a row of
round orange pools with a lamp in each and the towers' reds above; from 2 km a lit grid; by day nothing. Pixels of the city's
box that change with the lights hidden (obstruction lights, lamps and pools; a pole is there by day, so it is not hidden),
against 0 between two frames, PLAIN / FINE: night over the mist 156,255 / 157,275 down the avenue at 300 m, 62,360 / 62,907
from 160 m up, 6,289 / 6,227 at 2 km, 1,868 / 1,857 at 5 km, 502 / 505 at 10 km; from 40 m up 1,378 / 1,381 at 2 km and 427 /
413 at 5 km; evening 65,903 / 66,732 at 700 m and 4,485 / 4,323 at 2 km; **day 0 / 0 at 700 m and 2 km.** The probe first hid the
poles with the lights, and by day the poles changed 740 pixels at 700 m.

**WHAT IT COSTS.** Over the inner city from 160 m up at night -- the most street lighting in one view -- alternated launches with
the lights hidden and shown, two of each, 240 frames, no other windowed Godot (other lanes' headless gates ran beside, so GPU
only): PLAIN 0.344 / 0.344 ms hidden and 0.353 / 0.352 shown, **+0.009 ms**; FINE 0.605 / 0.605 and 0.615 / 0.616, **+0.011 ms**;
**+14 draws** (poles, lamps and pools, a batch each a lit kilometre in view). In a headset, twice the draws and the vertex work.

RED, one mutant at a time, each file restored and its SHA-256 checked:

| broken on purpose | what failed |
|---|---|
| the lamp's foot at y = 0, not the street's top | both placement checks: "3635 lamps on 0 of 108 streets; 3635 on no street" |
| the pools lit at night's share whatever the time | the pools' check: "the pools read [1.0, 1.0] by day and at night" |
| no clearance for the railway | both placement checks: "13 by the rail" |
| the pool's handover worked out beside the one function (from 0.3 of `pool_to`) | "the pool does not take 1 - lamp_pool_far_share(away, pool_to) once; a shader works the band out beside the function" |

**NOT HERE YET:** a per-town total of the town's light for cockpit-mist's night glow (`TownView.town_light(town)`, windows and
lamps in `LIGHT_PER_CANDELA` units, the photometric total, never the adapted or floored drawing); agreed with cockpit-mist,
to be built when its step 3 asks.


### The moon

Asked for on 2026-09-15: "can you make sure the moon at night has a moon decal, that way it looks like the real moon".
At night the DirectionalLight is the moon, and both skies drew it the way they draw the sun: Godot's procedural light disc
and a glow reaching 30 degrees, which at night's energy of 0.14 was a faint blue smudge with no face and no phase.

**Where: along the light, and nowhere else.** `world/shaders/sky_night.gdshaderinc` draws the disc along
LIGHT0_DIRECTION, so there is no second copy of the moon's direction to disagree with the light `Daylight` aims from the
preset. It is at infinity, a direction with no position: both eyes see it in the same place, and neither the double
build's eye nor CAMERA_POSITION_WORLD is anything to it.

**The face** is NASA's, public domain: the Scientific Visualization Studio's CGI Moon Kit (https://svs.gsfc.nasa.gov/4720),
`lroc_color_2k.jpg`, credited "NASA's Scientific Visualization Studio"; the SVS help page says all its content is public
domain unless noted, and the kit notes nothing. `tools/bake_moon_face.py` baked it once into
`world/textures/moon_near_side.png`: an orthographic view of the near side, lunar north up and east to the right (Crisium
on the right limb, Tycho low in the middle), 512 px, 3 x 3 samples a pixel, and past the limb the limb's own colour so a
mip never averages in black. Imported lossless with mipmaps (`detect_3d/compress_to=0`, so the editor never turns it into
VRAM compression on first use). The script regenerates the committed PNG byte for byte. A DISC, NOT THE MAP: a
latitude-longitude map sampled on the sky pinches at the poles, seams at the limb and jumps mip level where the longitude
wraps. The shader picks the mip level from how many texels fall in a pixel, with textureLod, because a sample's implicit
derivatives are undefined inside the branch it is called in.

**Its size: 1.56 degrees, 3 times the real 0.52** (`NightSkyTuning.MOON_ENLARGED`, the one number the disc's size comes
from). It was 0.78 degrees, 1.5 times, the most the first brief allowed, until 2026-09-17, when the user asked "make the
moon twice as large at night". At `tests/builder.gd`'s HEADSET_PIXELS_PER_DEGREE (20) it is 29.6 px across, where it was
14.8 and the real size would be 10.4; in moon_shot's close view it measures 312 px, where it measured 157.

- **One number.** The sky's `moon_radius` is `NightSkyTuning.moon_radius()`, handed to both materials by
  `Daylight.sky_material`; the disc's cover, which is what hides a star behind it, and the reach of the halo's drawing
  (`moon_radius + 12` halo widths) are worked out from it in `sky_night.gdshaderinc`. Nothing else in the world has the
  moon's size: the sea reflects the cubemap, where the moon is never drawn, and its glitter is the light's specular, which
  has no size (no `light_angular_distance` is set anywhere).
- **Only at night, so one size.** `moon_bright` is 0 in DAY and EVENING, so there is no dusk moon to be a different size.
- **Its brightness is the same a pixel, so four times the light in all.** The face is drawn at the same `moon_bright`, as a
  nearer moon would be: the lit disc's mean luminance in the cloud look read 0.689 against 0.696 at the old size.
- **The halo stays 2 degrees wide.** It stands for the air's glow round the moon, not for the moon, and scaling it with the
  disc would have quadrupled the blue round it as well; at 1.56 degrees the moon still reads as a disc with a glow round
  it in the 30-degree cloud look (`cockpit-moon2-04`).
- **Held against the old size, never against the constant.** `tests/scenery.gd`
  (`the_moon_is_twice_the_size_it_was_on_both_skies`) reads `moon_radius` back off both materials at night and holds it
  to twice 0.78 degrees, written in the test; `tests/moon_shot.gd` (`<finish>_the_moon_is_twice_the_size_it_was`) holds
  the lit disc's width in pixels, over the pixels a degree spans where it stands on the camera's own projection, to the
  same: 312.0 px at 199.9 px a degree, 1.561 degrees, on both finishes. RED with `MOON_ENLARGED` put back to 1.5: "157.0
  lit px across at 199.9 px a degree: 0.785 degrees, wanted 1.56" on both finishes, and scenery's check failed; restored.
- **A puff cloud in front still hides it** (`<finish>_a_cloud_in_front_hides_the_moon`): the eye 1,500 m back along the
  moonlight from whichever puff of the level's biggest cloud (191 puffs) puts the most cloud in the way by
  `PuffSky.optical_depth_between` (6.7), and the disc keeps 26 per cent of its clear luminance on PLAIN and 19 on FINE
  (wanted at most 50). The first version aimed at the cloud's MIDDLE and looked straight through a gap between puffs, 65
  per cent: a cloud's middle is not where it is thickest. Behind 6.7 of optical depth a faint ghost of the disc and a few
  stars still show through the night puffs; that is the puffs' own translucency, the same at the old size (26 and 19 per
  cent with `MOON_ENLARGED` at 1.5), and is for the puffs' owner to judge.

**The phase is the true sun's.** NIGHT names where the sun is under the horizon, `true_sun_elevation` -30 and
`true_sun_azimuth` 285: 150 degrees from the moon, a waxing gibbous 93 per cent lit, so the terminator is on show (a full
moon has none; a crescent hides the face). `DaylightTuning.towards_the_true_sun` is the light's direction for a preset
that names no true sun, which is DAY and EVENING. Each point of the disc is a point on a sphere turned to the eye, lit
2 cos(i) / (cos(i) + cos(e)) -- Lommel-Seeliger, the moon's own law, which draws a full moon flat to its limb rather than
as a shaded ball -- with the terminator softened over 0.05 of cos(i), and earthshine on the dark side of 0.02 of the lit
face's brightness under a full Earth, less as the moon waxes. `moon_bright` is 0 in DAY and EVENING: a moon is drawn only
where the light is the moon, because the sky draws it along the light.

- **Added to the sky, never laid over it.** The first pictures (`probe/moon-plain-close-gibbous`, 2026-09-15) laid the
  face over the sky, and a gibbous moon's dark limb and all of a crescent's drew black, darker than the sky round them.
  The air's glow lies between the eye and the moon, so the moon's light is added and its cover only hides what is behind.
- **A small halo in place of the light's glow.** The procedural glow filled a close view of the moon with blue. At
  night, outside the cubemap, `moon_light_seen` draws `NightSkyTuning.MOON_HALO` (0.5) of the light's colour and energy,
  falling by e every 2 degrees outside the disc, as bright as the moon is lit. By day the sun's disc and glow are
  untouched.
- **Never in the cubemap pass.** There the old glow is kept exactly, so what the sky throws on the world and what the sea
  reflects is the old sky's. The ambient at night is a colour, not the sky, anyway.
- **Under the clouds.** On FINE the moon is added before the half-resolution cirrus is laid over it, so a streak crosses
  it; the sun is still drawn over the cirrus, as it always was. The mesh clouds, the cloud fog, the mist and the whiteout
  cover it the way they cover the whole sky background: the depth fog reaches the sky at the Environment's default
  `fog_sky_affect` of 1, which nothing here sets (agreed with the mist lane, 2026-09-15). From inside a cloud on PLAIN at
  night (`look2/cloud_inside-plain-night`) the view is the whiteout's flat colour with no moon in it.
- **In a headset, per eye, reasoned and not yet seen.** The disc's edge is antialiased over one pixel from
  `pixel_angle(dFdx(EYEDIR), dFdy(EYEDIR))`, taken at the top of sky() before any branch. Each eye's view is drawn on its
  own, so those derivatives are that eye's neighbouring pixels. Every run here is one view. **For the user, in the
  headset:** the moon's edge should be steady and the same size in both eyes, with no shimmer as the head turns.

**PLAIN wears a shader sky now.** A headset starts on PLAIN (`Finish.HEADSET_DEFAULT`), and a ProceduralSkyMaterial has no
moon to wear, so a moon on FINE alone would never have reached the headset it was asked for. The procedural code both
skies share -- uniforms, gradient, ground, light disc, copied from `ProceduralSkyMaterial::_update_shader` in 4.7.2's
`sky_material.cpp`, which differs only in a `sky_cover` texture PLAIN never set -- is
`world/shaders/sky_procedural.gdshaderinc`; `world/shaders/sky_plain.gdshader` is that and the moon. `Daylight.sky_material`
builds both materials with the moon's fixed numbers, and `show_time` writes the colours, `moon_bright` and `true_sun` to
both. Held by pictures, stock ProceduralSkyMaterial (ad8933c) against this, `tests/scenery_shot.gd --still
--finishes=plain` on the double editor, 1600x900, max and mean channel difference of 255:

| view | day | evening | night |
|---|---|---|---|
| cirrus | 1, 0.0004 | 1, 0.0000 | 41, 0.52 (the halo in place of the glow) |
| clouds | 1, 0.0011 | 1, 0.0001 | 184, 0.41 (the moon is in frame) |
| runway_base | 1, 0.0000 | 1, 0.0001 | 1, 0.0001 |
| sea | 5, 0.43 | 4, 0.27 | 237, 0.56 |

**The sea is noise, not the sky.** Two launches of the SAME stock build differ on `sea` by 8 by day (mean 0.67) and 245
at night (0.58), where the glint on the water moves between launches; `clouds` held to 1 in the same pair.

**What it costs: nothing this instrument can see, on either finish.** `tests/scenery_shot.gd --time=night --hold-fires
--frames=240` on the double editor, 1600x900 at 3D scale 1.40, the skies of ad8933c (stock ProceduralSkyMaterial on PLAIN,
the cirrus sky on FINE) against these, three rounds interleaved before, after, with nothing windowed beside them (headless
suites of two other lanes were running). GPU medians, ms, the mean of three launches each:

| view | PLAIN before | PLAIN after | FINE before | FINE after |
|---|---|---|---|---|
| moon (looking at it) | 0.108 | 0.109 | 0.282 | 0.280 |
| zenith | 0.091 | 0.092 | 0.220 | 0.220 |
| sea | 0.185 | 0.184 | 0.439 | 0.432 |
| clouds (the moon in frame) | 0.218 | 0.223 | 0.600 | 0.606 |

+0.005 ms at the most on PLAIN, where the budget was 0.1, and the three launches of one build spread by up to 0.010 on their own. A
first run beside another lane's windowed probe read the same to within 0.01 and was not counted.

**How it was proved.**
- `tests/scenery.gd`, after the level's own `choose_time` (which the beam has been seen to reach), off BOTH materials:
  moon 3.0 and NIGHT's true sun, turned back into -30.00 degrees up at 285.00, at night; moon 0 and the light node's
  own direction by day; a 512 px face on each. RED, one mutation at a time: `Daylight` writing the light's direction as
  the true sun, "PLAIN true sun at night 40.00 up at 140.00, NIGHT says -30.00 at 285.00"; `Daylight` writing FINE's sky
  alone, "PLAIN moon at night <null>".
- `tests/moon_shot.gd` (windowed, a probe named in `tests/docs.gd`), on both finishes, double editor: at night, zoomed to
  4.5 degrees and looking 0.9 right and 0.5 up of the light, with the true sun behind the eye, the lit disc's centroid is
  0.03 px from where the light projects and 157 px wide against 155.9 drawn (312 against 311.9 since 2026-09-17); with the light itself turned 3 degrees,
  0.02 px. The true sun a quarter turn right, then left, then 40 degrees off for a crescent, then the preset's: the lit
  centroid stands 34.6, 34.6, 58.3 and 5.2 px towards where the sun projects (wanted 3.1). By day the luminance across
  night's disc spreads 0.005. RED, one mutation at a time: the shaders drawing the moon along night's direction typed in,
  `normalize(vec3(0.49240, 0.64279, -0.58682))`, passed the first look and failed the turned light on both finishes with
  "0 lit px"; the face lit from `-moon` whatever the sun, "the lit centroid stands 0.0 px towards the sun" on all four
  phases on both. Each mutant was restored and checked by SHA-256.
- `tests/moon_shot.gd` on FINE, under the cirrus: the sheet painted to full cover, the eye carried 1,500 m at a time across
  the streaks, and the disc's mean luminance with the sheet against with none. It keeps 60 per cent of it 4,500 m across
  (100, 100, 99, 60, 60, 79, 100, 100 at the eight places; wanted at most 85). RED, the moon added after the
  half-resolution cirrus instead of before: 100 per cent at all eight. FOUND WHILE WRITING IT: from one pose the painted
  sheet read 100 per cent with the moon correctly under it, because the streaks still break along their length over
  cells kilometres across, and night's own cirrus is too faint to find over the moon from any of eight poses 1 km apart
  (`scenery_shot.gd`'s `moon_at_<metres>`, `cirrus-search`).
- Looked at on the double editor, in `godotgames-drafts/2026-09-15/cockpit-moon/`: `probe2` (close: full, gibbous, both
  quarters, crescent, by day; at the headset's scale, 1:1 and eight times), `probe4` (behind a sheet of cirrus), `look2` (`moon`, `zenith`, `cirrus` and
  `cloud_inside` at day, evening and night on both finishes) and `cirrus-search` (`moon_at_<metres>`, the moon view
  carried across the streaks, for the moon behind cirrus).

**Not built:** a moon at evening or by day (no preset has one, and a moon in the sky while the light is the sun would need
its own direction); libration, and the moon's tilt with latitude -- its north is the sky's up; the moon drawn on the sea
beyond the cubemap's old glow.

### The stars

Asked for with the moon on 2026-09-15: "have a shader that allows their to be stars". `world/shaders/sky_stars.gdshaderinc`,
in both skies, every number in `NightSkyTuning`.

**A function of the view direction alone.** One candidate star in every cell of a cube wrapped round the sky, 96 cells
along a face's edge, each face's coordinates bent by atan so a cell spans nearly the same angle at a corner as at the
middle: no pole to pinch, as a latitude-longitude grid would, and no position, so the stars are at infinity, the same in
both eyes and nothing to either editor's eye. A cell holds a star when its hash is under 0.14 -- about 3,900 above the
horizon, the naked eye's count on a dark night -- and three more hashes place it, size its brightness as pow(hash, 6) so
most are faint and few bright, and colour it from blue-white to orange, most near white.

**Never under a pixel, and no brighter for being drawn small.** A star is a gaussian 0.9 of this eye's pixels in sigma, from
the same `pixel_angle` the moon's edge uses, with its peak scaled by (a twentieth of a degree / pixel)^2 so the light it
gives is the same at every resolution. A star's centre is kept a quarter of a cell from the cell's edges, and one too wide
for its cell fades rather than being cut. No TIME: no twinkle, and no cubemap redrawn every frame.

**Out when the sun is down.** `NightSkyTuning.stars_seen` of the true sun's elevation: none above -4 degrees, all by -18,
astronomical twilight's end. `Daylight` writes it to both skies once per change; with three presets and no clock only NIGHT
shows them (EVENING's sun is 7 degrees up). NOT BUILT: a sky that turns with the hour -- there is no clock to turn it by.

**Dimmed** by the haze low down (up over the lowest 0.3 of the view's height), by the moon near it (falling by e every 8
degrees) and across the sky (the faintest quarter washed out under a full moon), all by how much of the moon is lit, and
hidden behind its disc. Drawn outside the cubemap pass, under FINE's cirrus, and covered by the clouds, fog, mist and whiteout
as the sky is.



**How it was proved.**
- `tests/scenery.gd`, after the level's own `choose_time`, off both materials: stars 0 by day and at evening, 1 at night.
  RED with `stars_seen` returning 1: "PLAIN DAY 1.0; PLAIN EVENING 1.0; FINE DAY 1.0; FINE EVENING 1.0".
- `tests/star_shot.gd` (windowed, a probe named in `tests/docs.gd`), double editor, 1600x900 at scale 1.40, a 60-degree
  view 60 degrees up and away from the moon, both finishes: 172 stars on PLAIN and 170 on FINE at night -- a star is a
  pixel brighter than its neighbours and 0.04 over the ring three pixels round it -- and none by day or at evening; the
  20 brightest 0.88 to 1.08 px in sigma; turned about its own up a quarter of a pixel a frame for 60 frames (the brightest
  star moved 19.7 px), each of 30 stars followed by its own direction, the light in its 7 x 7 box varied by 0.043 at the
  median and 0.067 at the worst. RED with a star's sigma a quarter of a pixel: 0.244 at the median and 0.313 at the worst,
  and 141 and 139 stars. THAT MUTANT PASSED THE WIDTH CHECK (0.76 to 1.12 px): the 1.40 render scale's downsampling and the
  tonemapper blur a quarter-pixel star to about a pixel in the saved picture, so what the width check can see is the
  shimmer's to catch. The moon-under-cirrus mutant was run again on the shaders with the stars in: 100 per cent at all
  eight places, RED.
- FOUND BY THE PROBE BEFORE IT PASSED, three times over: at 256 cells no star was drawn at all (above); the observer's
  board is a CanvasLayer of the observer's own, and its letters were counted as 93 steady "stars" until it was hidden;
  against the frame's median the sun's glow and the cirrus made 217 and 527 "stars" by day, so a star is held to its own
  ring; and each frame's light was appended to a copy of a PackedFloat32Array taken out of an untyped Array, so every series
  stayed empty and read a variation of exactly 0.000. The check now says how far the stars moved and how many frames each
  series holds.
- Looked at, `godotgames-drafts/2026-09-15/cockpit-moon/`: `stars4` (the high sky at day, evening and night on both
  finishes, and a 200 x 120 crop at 1:1 and four times) and `look3` (`moon`, `zenith`, `cirrus` and `cloud_inside` at
  day, evening and night on both finishes, with the stars in).
- **In a headset, per eye, reasoned and not yet seen**, as for the moon: each star's width is that eye's pixel. For the
  user: the stars should be points in both eyes that do not flicker or swim as the head turns.

**What they cost.** `tests/scenery_shot.gd --time=night --hold-fires --frames=240`, double editor, 1600x900 at scale 1.40,
ad8933c's skies against the moon and the stars, three rounds interleaved, every windowed Godot beside each launch recorded
at its start and end -- only the user's own editor, no lane's -- GPU medians, ms, the mean of three launches:

| view | PLAIN before | PLAIN after | FINE before | FINE after |
|---|---|---|---|---|
| moon | 0.104 | 0.122 | 0.281 | 0.292 |
| zenith | 0.090 | 0.106 | 0.220 | 0.231 |
| sea | 0.182 | 0.188 | 0.439 | 0.438 |
| clouds | 0.213 | 0.228 | 0.599 | 0.612 |

+0.016 to +0.018 ms on PLAIN wherever the sky fills the view, the moon's share of that about +0.001 ("The moon"), and
+0.006 looking at the sea, where most of the view is under the horizon and the stars return at once; +0.011 to +0.013 on
FINE. The three launches of each build agreed to 0.002. Under the 0.1 ms budget on both finishes. NOT TRIED: the optional
Milky Way band, a value-noise lookup on every sky pixel; with the field at 0.018 ms it would be affordable, and it is left
until somebody has looked at the stars in a headset.

## WHY THE WORLD HITCHED AT 300 KPH

It was never the simulation, and it took the tracer to say so rather than guess. The
numbers, headless, over thirty seconds of straight and level at 300 kph across the full
world with 463 solid boxes in it:

| | |
|---|---|
| tick cost, median | 0.063 ms |
| tick cost, p99 | 0.143 ms |
| ticks over the 16.67 ms budget | **0 of 1800** |
| rollbacks | 0.6 per second, 170 ticks replayed, worst span 10 |

The scenery costs nothing measurable: bare ground gives the same numbers. So the hitch was
in the frame, and three things were wrong with it.

**1. `physics_jitter_fix`, and this is the one.** Godot's default is 0.5, and it nudges how
many physics steps a frame gets to hide jitter for games that draw straight from physics
state. This one does not -- it interpolates between the last two simulated states with
`Engine.get_physics_interpolation_fraction()` -- so the nudge is not a fix, it is the
physics timeline sliding against real time underneath an interpolation that assumes it does
not. What it leaves is a fraction of a tick, so what you SEE from it is proportional to
speed: invisible in a hover, 1.4 m of travel per tick at 300 kph. It is `0.0` in
`project.godot` now, with the reasoning next to it.

**2. The renderer rebuilt the world to find out what to draw.** `_process` called
`vehicle_states()` and `pilot_states()` on every drawn frame, and each one builds a fresh
Dictionary per entity with eight or ten keys in it. At display rate, for a list that only
changes at tick rate. It reads `Sim.current` and `Sim.pilots` now, captured once per tick:
**25.5 us per frame down to 2.5**.

**3. The status line was formatted ninety times a second.** Four more calls into the
simulation and nine values into a string, for a label nobody can read that fast. Five times
a second now.

**4. AND THE ONE THAT WAS ACTUALLY DOING IT: the correction offset was a tick of travel.**

When a rollback lands, the picture is held still and eased onto the corrected truth instead
of snapping. The offset it holds was computed as *last tick's drawn pose* minus *this
tick's truth* -- which looks right and is not. Those two are **one tick of ordinary travel
apart even when the correction is exactly zero**.

So every rollback yanked the world back by a tick's worth of motion and then slid it
forward again. At a hover that is millimetres. At 300 kph it is 1.4 m, at the rollback
rate, and it reads as *the world stepping while the cockpit stays perfectly steady* --
which is exactly what it was, because the pilot is seat-parented and the whole world jerks
together while nothing inside the aircraft moves at all.

The offset is measured against where the picture WOULD have been this tick -- last tick's
drawn pose carried forward one tick by the velocity and spin it was drawn with -- so only
the genuine disagreement is left.

| worst drawn step error, 30 s at 300 kph | |
|---|---|
| on a corrected tick, before | ~100% of a tick (the picture stalls completely) |
| on a corrected tick, after | **0.3%** |
| worst anywhere, at 60 Hz | 60% of a tick, once in 1800 |
| worst anywhere, at 120 Hz | 32% of a tick, once in 1800 |

### And then the attitude, which nothing had ever measured

The position was smooth long before the world stopped hitching, because both smoothness
tests only ever checked POSITION. A rotation drawn in steps is far more obvious than a
position drawn in steps -- the whole world pivots around the pilot's head -- and it was the
half nothing was looking at. Both checks now walk the attitude as well.

Writing them turned up three separate things:

**`Quaternion.angle_to` cannot measure this.** It is `acos` of a dot product that is almost
exactly 1, and acos near 1 loses half its significant figures: its noise floor is around
0.0006 rad, which is LARGER than a whole tick of an aeroplane's pitch change. Measured with
it, a perfectly smooth rotation reads as seven slices of nothing and one of everything --
which looks exactly like snapping and is not. Everything here measures the chord a wingtip
sweeps instead: a subtraction, proportional to the angle, and two perpendicular vectors
catch a rotation about either.

**The attitude quantiser was a floor under the rollback threshold.** `quat_part` was
0.0014, about a twelfth of a degree, so `rollback_angle` could not usefully be tighter than
`0.05` -- three degrees of drift allowed before anything corrected it, and then three
degrees of world rotation blended out over 0.18 s, at the rollback rate. Nine more bits per
vehicle per update buys 0.0002, and the threshold is `0.004` rad: a fifth of a degree.
Corrections now move the world by **0.0003 degrees** instead of up to three.

**The rate controller was closing its loop in exactly one tick.** `control_authority` is a
raw torque per rad/s of error, so what it means depends on the inertia it is pushing:
16000 N*m per rad/s against an aeroplane's 274 kg*m^2 in roll is a time constant of
0.017 s, which at 60 Hz is one timestep. A first-order loop closed in one step of its own
timestep is on the edge of stability, and with four physics substeps and aerodynamic
torques arriving alongside it, it rings. `command_rate` now caps the torque at what would
take the rate most of the way in one step, from the body's own inertia about that axis --
the same clamp every force in this file already goes through.

### The instrument found a bug in the world, too

The probe reported 200 deg/s of "unexplained" rotation on an aeroplane flying hands-off,
which turned out to be an aeroplane on the GROUND, scraping along it at 82 m/s.

`Terrain._air` aimed a spawn's velocity with `Vector3(sin(yaw), 0, -cos(yaw))`. The nose is
the body's -Z turned by the yaw, which is `(-sin, 0, -cos)`. The sign is invisible for
anything facing along an axis, because the X term is zero there -- so five of the six
aeroplanes were fine and the one on a diagonal was launched flying ninety degrees sideways,
made no lift, and mushed into the sea while every test passed. `Terrain.nose_from_yaw` is
now the single answer to "which way is it pointing", and the smoke test checks every spawn
against it.

### Where it ended up

Thirty seconds of hands-off flight at cruise, across the full world:

| | 60 Hz | 120 Hz |
|---|---|---|
| worst drawn step error | 0.1% of a tick | 0.1% |
| worst unexplained world rotation in one tick | 0.0016 deg | **0.0004 deg** |
| ticks rotating more than 0.1 deg beyond their spin | 0 of 1800 | 0 of 1800 |
| rollbacks | 0.3/s | 0.2/s |
| attitude moved by a correction | 0.0002 deg | 0.0003 deg |

### The last one: a teleport guard measured in metres

A correction bigger than `kMaxBlendedCorrection` SNAPS instead of blending, on the grounds
that it is a respawn rather than a disagreement. Four metres was chosen when the fastest
thing here did 80 m/s, where it is half a second of flight and nothing routine comes near
it. Give the aeroplane four times the thrust and four metres is 26 ms at 152 m/s -- an
entirely ordinary disagreement -- so every few ticks a routine correction took the teleport
path and snapped the world by metres. Measured: one drawn tick in three, at 60 Hz.

It is in SECONDS OF TRAVEL now, with a floor in metres for things that are barely moving. A
real teleport is a respawn or a launch and moves hundreds of metres, which half a second of
travel still catches at any speed.

### THE AEROPLANE HAS 44000 N OF THRUST, AND 120 Hz IS NOT OPTIONAL WITH IT

Five and a half times its own weight. Top speed is set by drag rather than by thrust --
1.6 v^2 against 44000 N is about 165 m/s, very nearly 600 kph -- and hands-off at full
power it climbs at 30 m/s, which is what that much thrust means and not a fault.

Two things had to move with it. The `speed` quantiser went from 200 to 400 m/s, because a
velocity that does not fit is not an error anybody sees: it is silently clamped, and every
other machine watches the aircraft fly slower than its own pilot does. And
`kMaxBlendedSeconds` replaced a constant in metres -- see below.

At 60 Hz this aeroplane produces **34 rollbacks a second** and one drawn tick in fifteen
steps visibly. At 120 Hz it is 1.7 a second and **none of 1800 ticks** steps more than 15%
off. Run it at 120.

### THE SIMULATION RUNS AT 120 Hz

Because the tick is the length of the interval the renderer has to guess across: at 60 Hz
and 300 kph that is 1.4 m of aeroplane, at 120 Hz it is 0.7, and every timing error left in
the frame is halved with it. Affordable because it was measured rather than assumed -- a
tick costs 0.06 ms with the whole world loaded, so 120 of them is well under one per cent
of a core. It is NOT free in bandwidth, which is very nearly linear in the rate, so `[` and
`]` step it live for a session over a real network.

### THE FLASH

The HUD flashes across both eyes when the world moves for a reason the picture did not
choose, and the colour is the diagnosis:

- **YELLOW** -- this machine's prediction was wrong and the vehicle you are in was rewound
  and replayed. If the world lurches and the screen goes yellow at the same moment, the
  lurch is a rollback.
- **RED** -- the drawn position jumped more than twice as far in one frame as the
  vehicle's own speed can account for. That is not the network; that is the frame missing
  its timing, and it wants a completely different fix.

The panel also reads the **throttle as a percentage** -- a trigger has no detent and no
travel you can feel, so without a number on it there is no holding a cruise setting -- the
brake when it is on, the simulation rate, and rollbacks per second. Being able to tell those
two causes apart from inside a headset is the entire point: guessing between them from a
description cost a day.

`tests/hitch_probe.gd` is the measurement -- tick cost as a distribution, rollbacks and
what they cost in replayed ticks, the drawn step against what the vehicle's speed says it
should be, and what the tracer saw. It runs at 60 and 120 Hz. Re-run it rather than
reasoning about it. `CockpitWorld.set_tracing(true)` must be called BEFORE `start()`: the tracer is
attached as the client or server is built and there is nowhere to hang it afterwards.

### AND IT IS A SUITE NOW, WITH THRESHOLDS

It was a probe for too long. It measures the three numbers that would catch the most
expensive bug this project has had -- the correction offset that was a tick of travel, which
read as the world stepping while the cockpit stayed steady and took a day of guessing -- and
those numbers were recorded here as pass conditions in all but name. A change that doubled
tick cost or reintroduced that offset was caught only if somebody remembered to run it.

Measured 2026-09-11 on the double-precision engine, and these are what the thresholds are
set against:

| | 60 Hz | 120 Hz |
|---|---|---|
| tick cost, median | 0.171-0.178 ms | 0.063-0.065 ms |
| ticks over budget | 0 of 1800 | 0 of 1800 |
| worst drawn step, corrected tick | 2897% | **0.0%** |
| ticks stepped more than 15% off | 29 | **0** |
| worst unexplained rotation | 0.0300 deg | **0.0007 deg** |
| rollbacks | 31.5/s | **0.5/s** |

and the whole game at 71 vehicles: server and client together 0.259-0.273 ms median, the
client alone 0.079-0.080.

**The smoothness thresholds are held at 120 Hz only**, and that is not a dodge -- the 60 Hz
column above is a documented property of 44 kN of thrust and the reason this file says "run
it at 120" in capitals. Holding a 60 Hz run to a 120 Hz number would be a suite that fails
for a reason this file already explains.

**Twice the measurement, except where the measurement is zero.** Twice nothing is nothing,
so the four that read zero get a floor chosen from what the FAILURE looks like: the
correction-offset bug stalled the picture for a whole tick, so 30% is a third of the bug;
and a whole-world rotation becomes visible at about a tenth of a degree, which is where
`_turn_spikes` already counts.

**THE VERDICT IS TAKEN OFF THE MEDIAN AND NOT THE p99**, which is the opposite of what this
file says everywhere else and is right here for a measured reason. A hitch IS a p99 and an
average hides it perfectly -- so the probe prints the whole distribution and always will.
But a p99 THRESHOLD is a threshold on the MACHINE as much as on the code: six runs of this
identical, deterministic simulation on a workstation with two other agents running Godot
suites read p99 0.188, 0.192, 0.194, 0.202, 0.209 and **0.454** ms at 60 Hz, and a worst of
1.065 against a usual 0.27. The median over the same six read 0.171 to 0.178 -- a four per
cent spread against a hundred and forty. So the tail stays in the output where a person
reads it, and the tail's own invariant is held exactly and separately: `over budget`, which
has a hundredfold margin and cannot be moved by scheduling noise.

`crowd`, `jitter` and `station_shot` stay probes. The first two report numbers with no right
answer and the third renders a PNG a human has to look at.

## THE JITTER OUT BY THE CARRIER IS THE SIZE OF A FLOAT

Reported as jitter when flying far from the origin, near the aircraft carrier. Those are the
same place: the carrier is 9.46 km out, which is the farthest anybody normally goes, so the
ship is a landmark for the fault rather than a cause of it.

**It is not the simulation.** Measured with `tests/jitter.gd`, an aeroplane's drawn path is
as smooth at the far corner as at the origin -- to within three per cent on the same metric
-- and identical to four decimal places with the carrier in the world and with it removed.
The client is not rolled back at all out there. Position on the wire is a uniform 1 cm grid
over the whole map, so it is not distance-dependent either.

**It is the float.** A float32 holds about seven digits, so the gap between one
representable number and the next grows with the number. Every world position downstream
lands on that grid -- the vehicle, the seat, the panel, the camera matrix -- so your head
moves smoothly and the cockpit is redrawn on it. Measured through a real `Transform3D` at a
real cockpit offset:

| distance from origin | grid | at arm's length |
| --- | --- | --- |
| 500 m | 0.03 mm | 0.21 arcmin |
| 2000 m | 0.12 mm | 0.84 arcmin |
| 9460 m (the carrier) | 0.49 mm | 3.36 arcmin |
| 16000 m (map edge) | 0.98 mm | 6.71 arcmin |

Human vernier acuity is about half an arcmin, so out by the ship the cockpit is stepping
about seven times more than the eye can resolve, and in a headset you have two eyes on it at
half a metre.

### The answer taken: a double-precision engine

There were two ways out. A FLOATING ORIGIN keeps the drawn world near zero by shifting
everything under the player, which needs no toolchain change and no engine build, but it
also needs the shift adding back inside `ocean`, `grass` and `rock` -- all three derive
their noise from `MODEL_MATRIX * VERTEX`, so the ground would swim every time the origin
stepped -- and it is bookkeeping that every new drawn thing has to remember for ever.

A DOUBLE-PRECISION GODOT fixes it at the source and nothing downstream has to know. Godot
built with `precision=double` makes `real_t` a double, and because shaders cannot hold one
it emulates the camera and model matrices so the GPU is handed CAMERA-RELATIVE transforms
-- which is the actual fix, since a cockpit half a metre from the eye is then computed
around zero no matter where in the world it is.

That is the road taken, and the price is that the engine is no longer something you
download.

**What has to agree, and it is all of it.** The method hashes of anything taking a `real_t`
DIFFER between the two builds, so a library bound against the wrong `extension_api.json`
loads happily and then calls the wrong functions. So:

1. Godot is built from source at the same commit as the stock binary -- 4.7.2-stable,
   `ed1daf0` -- with `precision=double d3d12=yes`. D3D12 because the project asks for that
   driver, and its SDK is a separate download (`misc/scripts/install_d3d12_sdk_windows.py`).
2. `--dump-extension-api` from THAT editor, not from any other.
3. godot-cpp and the extension are built with `-DASHIATO_GD_DOUBLE=ON` and that API file,
   which `tools/build.ps1 -Double` does.

**Both libraries are installed side by side.** The double build is `ashiato_gd.double.dll`
and the ordinary one keeps its name, and the `.gdextension` picks between them by feature
tag. The `single` on the ordinary entries is the half that is easy to forget: a double
editor reports every tag a single one does EXCEPT `single`, so an untagged
`windows.editor.x86_64` matches it perfectly well and it would load the wrong library.

**Only this project moves.** `racer` and `vrplayground-2` share the same extension and both
carry precompiled third-party addons -- godotsteam, and a prebuilt godot-box3d -- which are
single-precision binaries and will not load in a double editor. They keep the stock Godot
and the stock DLL, and nothing about this build reaches them: the double library is an
extra file next to the one they already use, named differently, and their `.gdextension`
does not mention it. Moving them would mean building godotsteam and box3d for double as
well, which is a bigger job than either of them is worth today.

**Running the tests.** `tests/run_all.ps1` prefers `_tools/godot-4.7.2-double` and falls
back to the stock editor, so a checkout without the custom build still runs. Both libraries
are built and installed, and both are tagged, so either editor works -- all thirteen suites
pass on each.

**The result.** `tests/jitter.gd` measured half a millimetre at the carrier before and
reports nothing measurable at any distance now, out to the edge of the map:

| distance | float32 | double |
| --- | --- | --- |
| 2000 m | 0.12 mm | below measurement |
| 9460 m | 0.49 mm | below measurement |
| 16000 m | 0.98 mm | below measurement |

### What the double build does and does not steady

`jitter.gd` measures the PROCESSOR's sums, and there double is exact. What the eye sees is the GPU's, measured by
`tests/shake_shot.gd` (windowed, Forward+, RTX 5080): a craft, an eye in it, a panel half a metre ahead and a runway light
3 m ahead, all moved together by 0.37 mm a frame for 90 frames, every frame read back against the last in a box round
each. A scan at 0 / 2 / 7 / 9.46 / 16 km (2026-09-14), frames of 90 that changed:

| editor | panel (an ordinary mesh) | light, before the beacon fix | light, after it |
|---|---|---|---|
| double | 0 / 0 / 0 / 0 / 0 | 0 / 8 / 58 / 58 / 43 | 0 at 0 and 9460 m |
| stock | 0 / 0 / 0 / 0 / 0 | 0 / 0 / 0 / 0 / 0 | 0 at 0 and 9460 m |

**Ordinary meshes are steady far out on double.** The double build hands each instance's origin and the camera's to the
GPU as float plus remainder, and adds them there (`double_add_vec3`, `scene_forward_clustered.glsl`) into a camera-relative
translation. A build made to add 1,000 m in that function drew nothing where a box should be, so meshes do go through it.

**A billboard placed by `VIEW_MATRIX * centre` is not.** A `skip_vertex_transform` shader that takes its centre from
`MODEL_MATRIX` and places it with `VIEW_MATRIX * vec4(centre, 1.0)` is float32 on the GPU on either build: the light's
steps above, 8 frames at 2 km, 58 at 7 and 9.46 km, 43 at 16 km, where the step is twice as big and comes less often.
(Stock reads 0 for both only because its craft's own position is float32, so the whole set moves in whole steps and rounds
the same way each frame; a head moving inside the craft would show stock's grid. Stock is not steadier.)

**The lights are fixed (2026-09-14), in the shader, with no engine patch.** `beacon.gdshaderinc` reads the centre, the
distance and the PAPI's height from `MODELVIEW_MATRIX`, which a double build works out camera-relative in emulated double
precision, and writes the quad back in the instance's own space through `inverse(mat3(MODELVIEW_MATRIX))` for the engine's
transform to place. It must not use `skip_vertex_transform`: with it, a double build bakes a multimesh instance into
the model matrix and then applies it to `MODELVIEW_MATRIX` again (see "The fix is one include"); reading `MODEL_MATRIX`
without it is safe, since only the copy handed to the shader is baked.
`shake_shot`'s `nor_does_a_runway_light_on_double` went red first (58 frames) and reads 0. Stock unchanged: 32 pictures of
the lights, `--still` (runway lights) and `--parade --no-spotting` (aircraft lights), four views each, both finishes, day
and night, at most 8 px apart before and after and none past 8 of 255; the red-light readings the same to the hundredth
but for one, `traffic_near` FINE by day, 0.49 to 0.46 red px an aircraft light and 1.17 to 1.00 a runway light, which
double reads as before. `eye_shot` unchanged on both editors (1,280 and 5,776 px).

**And the sky's other billboards are fixed the same day, from one include.** `world/shaders/billboard.gdshaderinc`
holds the three lines -- the eye relative to the instance's origin, and a point relative to it placed in view space or in
the instance's own space -- and `contrail*`, `heavy_burst_*`, `missile_motor*`, `flame_fine` and `ember_fine` do their sums
relative to their own origin and hand the result over. Every MultiMesh -- `contrail*`, `heavy_burst_*`, `ember_fine`, like
the beacon -- drops `skip_vertex_transform` and goes through its instance's own space, so its placement is right whatever
its instances hold; the plain-mesh motors and flames keep it and place in view space. The instance basis has to invert:
the contrail and missile yards laid a segment as `Basis(along, (0, 0.001, 0), (0, 0, 0.001))`, singular for a trail along
Z, and the first run through the inverse drew every contrail as shattered triangles (108,245 px of a stock picture
changed); they lay `MissileYard.segment_basis` now, square columns, and stock is back within 650 px, none past 8 of 255.
REJECTED: keeping `skip_vertex_transform` on bursts and embers, whose instances happen to have no origin, and holding that
in `tests/bursts.gd` -- headless Godot's dummy renderer reads every MultiMesh instance back as the identity (an origin set
to (1, 2, 3) reads (0, 0, 0) headless, (1, 2, 3) windowed), so the check passed with the origin mutated in and was removed. `tests/billboards_shot.gd` rides a contrail segment, a burst's flash and a plume
6 to 10 m ahead of a creeping craft with their clocks held (and `Engine.time_scale` 0 for TIME), every pixel compared by
more than 3/255: before, on double, the contrail changed on 58 frames of 90 at 9.46 km and 48 at 60 km and the burst on 34
at 60 km, with every count 0 at the origin; after, 0 everywhere. The plume read 0 before as well -- its soft additive edge
stays under the threshold at 6 m -- and takes the same lines anyway. NEAR, BECAUSE THAT IS WHERE THE GRID SHOWS: the same
things 20 to 40 m off never moved at 9.46 km on either editor (a 0.49 mm step there is a hundredth of a pixel), and a first
version of the probe at 500 m up saw 8-bit rounding on soft edges at the origin, which is why it starts 50 m up.

**WHAT WENT WRONG FIRST, and was merged.** The first `shake_shot` stood the light 8 px outside the panel's counting box;
FINE's halo reached into it, and the light's steps were read as the panel's -- "58 of 90 frames at 9460 m, on D3D12 and
Vulkan alike". This section said, on that evidence, that the GPU drew everything on float32's grid and that the double build
bought "nothing on screen", and blamed Godot's emulated-double sums: a user shader running Godot's `two_sum` in one
stage does lose its error term on this GPU (a = 2^24, b = 1 gave 0; split across the vertex and fragment stages it gave 1,
so the simplification is within a stage). Marking the engine's sums `precise` and rebuilding changed nothing, and nor did
reordering them -- because they were never the fault: a model's origin and minus the camera nearly cancel, so their float
sum is exact (Sterbenz) and no error term needs recovering. Moved clear, the panel read 0 on the unpatched double editor.
The probe now checks its boxes are apart. A user shader that relies on an error-free sum should not trust one here.

### The boundary the compiler found for us

`real_t` becoming a double turned every implicit narrowing at the Godot boundary into a
compile error -- forty-five of them, in four files, all the same shape:
`b3Vec3{v.x, v.y, v.z}` from a `godot::Vector3`.

That is not an obstacle, it is the point. `src/core/from_godot.hpp` now names the crossing
once and every site goes through it, which is a better file in the single-precision build
too: it says where Godot stops and the simulation starts, and why nothing below that line
wants a double. Box3D is a float32 solver and always will be, the components are float32
because they are quantised onto the wire anyway, and a tick of travel at 150 m/s is 1.25 m
-- nowhere near a float's floor even at the far corner. The problem was never the
simulation's arithmetic. It was drawing, and drawing is Godot's side of the line.

## A RUNWAY, A TRAINER AND A TOWER

**The runway is generated from one number.** Every runway is a frame (`Terrain.runway_frame`), and the island's is built
from these constants; a generated world has one on each airfield strip (`Terrain.runways()`). `RUNWAY_LENGTH` decides the tarmac, how many
centreline stripes there are, where the threshold bars go and how much sky the scenery
generator has to leave clear at each end. Lengthen it and all of that follows. It is 42
pieces of flat box in one MultiMesh with no collision at all -- an aeroplane rolling down it
is held up by the same ground plane as everything else, because the tarmac is paint and not
a shelf.

The clearance is the largest in the world and it is not the strip, it is the APPROACH: an
aeroplane on short finals is low, slow and committed.

**A Cessna 172**, on the real one's numbers -- 8.3 m long under an 11 m high wing, a tonne
all up, nine kilonewtons against the fast aeroplane's forty-four. It tops out around 67 m/s
instead of 165 and answers its controls at half the rate, which is the aircraft: a 172 is
what people learn in because it does what you ask slowly enough to watch it happen.

TWO SEATS sharing ONE PLUNGER. A 172's throttle is a shaft through the middle of the panel
with a knob on the end, pushed IN for power and pulled OUT to close it -- backwards from
every lever in the game, and that is the aeroplane rather than a mistake. It is the second
craft with a shared control and the only one where the shared control is a knob.

### The 172S is drawn from its manuals (cockpit-skyhawk, 2026-09-17)

**It was a lofted oval, a plank wing and two crossed boxes, and it passed its 2% envelope check.**
`SkyhawkAirframe` replaces it through the package's `visual` boundary, as the fighter's airframe does.
It has a cowl with its inlets, a spinner and a two-blade propeller, a flat-sided cabin with its
windscreen, doors, side and rear windows, a constant-chord wing tapering outboard of WS 100 with its
dihedral, lift struts, Fowler flaps and ailerons, a swept fin with its dorsal fillet, a rudder,
elevators with a trim tab, and fixed gear on spring-steel legs in spats. `craft/cessna/sources.md`
records every reference: Cessna's information-manual three-view and maintenance manual, studied and
measured, never copied, and a CC BY photograph scaled off its own gear.

**THE PUBLISHED HEIGHT IS NOT THE AEROPLANE'S.** Textron's 2.72 m is labelled maximum. The manual's own
side view puts the beacon at 2.39 m, and the photograph at 2.34 m. It is built, and held by
`tests/aircraft_fidelity.gd`, at the measured 2.36 m. When a figure and its own drawing disagree,
measure the drawing against something the figure cannot move -- here the drawing's propeller against
its published 76 in, which is how the side view was shown to be to scale both ways.

**A THREE-VIEW IS NOT THREE SCALE DRAWINGS.** The same manual's front view makes the fuselage 1.11 m tall
outside a 1.22 m cabin, so it gives widths and angles only. Its side view is drawn about 1.5 degrees
nose-up against the photograph and the published 11.25 in propeller clearance. Both are listed in
sources.md as expected differences in the overlay, rather than modelled.

**Its moving parts are pure functions, drawn straight from what each machine holds.** The flaps and the
trim tab come from the bus; the ailerons, elevators and rudder come from `crew_controls`. The propeller
turns at a fixed 2.5 rev/s on the physics clock, with a disc fading in as the throttle opens, and stands
still when parked. THE STICK AND RUDDER ARE NOT ON THE REPLICATED BUS: a machine not aboard draws those
surfaces neutral. That is a follow-up for the timed-actuator wire work (`actuators_research.md`).

**How `tests/skyhawk.gd` measures, and the three checks it had to lose:**
- It slices the drawn triangles with planes. A vertex window found nothing at 1.5 m out, because the
  wing has no vertices there.
- A surface's travel is the rotation between its drawn poses. The angle between hinge-to-trailing-edge
  vectors read a 30-degree flap as 12.4, because a flap's furthest-aft vertex lies along its hinge.
- Two mutants survived the first version. With the main wheels 5 cm in the air it still passed, because
  the lowest tyre was the nose wheel. With flaps drawn as all-or-nothing it still passed, because the
  lever only ever went to full.
- A mutant that changes the drawn size is refused by `ModelAssetDefinition` before the envelope check
  runs, so its red is "no airframe", not the envelope.

**The seats did not fit the aeroplane.** On a parked Cessna resting 0.8499 m up, the package's eyes stood
1.90 m over the ground and 3.24 m aft of the spinner, 0.55 m either side: the rear seats, above the
window tops, inside the skin. The real front-seat eye is about 1.45 m up, 2.33 m aft and 0.27 m either
side. Moving them is a native shape change and a package migration of its own.

### An airframe declares the room round its crew (cockpit-skyhawk, 2026-09-17)

**Nothing that wants to put something in a cabin has any way to ask how much room there is.** A station is
sized for its occupant and knows nothing about the aeroplane; the aeroplane is drawn from a three-view and
knows nothing about the station. On nine of this game's craft the pilot's head is inside nothing the craft
draws at all (`lane/shell`). `VehicleView.cabin_room()` is the one call that answers, for every craft:

```
{"drawn": bool, "floor": float, "room": AABB, "why_not": String, "source": String}
```

**What `room` promises, and it is deliberately not "the shape of the cabin": every point inside it is inside
the skin this craft draws.** A cabin is a lofted section and no box describes one. A conservative box is the
thing a consumer can act on -- a floor, a seat or a rail that fits the room fits the aeroplane -- without
carrying any geometry of its own. A point OUTSIDE the room may or may not be outside the skin, and that
asymmetry is the point: the room is a promise that can be held against the drawn triangles rather than a
description that would be approximately true in both directions and checkable in neither.

**The frame is the craft's own** -- metres, +Y up, -Z forward, origin at the native hull's middle, the same
frame `Sim.geometry_of(kind)["seat_poses"]` uses -- so a seat pose and a room compare without a transform.
It is the PARKED airframe's and does not move with the flaps, the doors or the gear.

**A craft that encloses nobody says so.** `drawn` false, `room` empty, `why_not` a sentence: an absent answer
is indistinguishable from an oversight. Two reasons exist today and they are not the same fault -- drawn by
`HullSkin` as open plates that do not close, or drawn as a simulation box with `_greenhouse` cut into it,
which is derived from the same seat poses a station is and so can neither disagree with a station nor serve
as a datum for one. The airframe is asked BY METHOD NAME rather than by type, so a new airframe opts in by
growing `cabin_room()` and nothing central is edited: a roster of which craft have cabins is exactly the list
that goes out of date.

**`floor` IS PUBLISHED BESIDE `room` RATHER THAN BEING ITS BOTTOM**, because the drawn fuselage pinches in
below the cabin floor. Scanning outward from the centreline until a ray leaves the drawn skin, at the
narrowest station between s 1.95 and s 3.01:

| h | 0.56 | 0.62 | 0.70 | 0.90 | 1.30 | 1.60 | 1.75 | 1.80 | 1.86 |
|---|---|---|---|---|---|---|---|---|---|
| half-width | **0.35** | 0.42 | 0.48 | 0.52 | 0.54 | 0.53 | 0.52 | 0.51 | 0.38 |

So the Cessna promises `room` from h 0.72 to 1.78, +/-0.46, s 1.95 to 3.01, and publishes `floor` at h 0.56
beside it. **A consumer that assumed `room.position.y` was the floor would lay one 0.16 m too high.**

**AND A WARNING ABOUT THAT TABLE, because the first draft of this section drew the wrong conclusion from it
and very nearly had the aeroplane remodelled.** It read "[MM]'s 1.003 m floor needs 0.50 at h 0.56 and has
0.35, so by `modelling_here.md` section 5 the SHAPE is wrong" -- and team-lead approved flattening the belly
on the strength of it. [MM] says "cabin 39.5 in wide". **It never says that width is AT THE FLOOR.** It is a
maximum, and this model already reproduces it where a cabin is widest: 0.55 half-width at h 1.30 to 1.66, a
lining 1.04 to 1.06 m inside against 1.003 m published. A real 172's floor pan is narrower than its shoulder
room. Section 5 decides between the research and the shape when they genuinely disagree; here they never did.
**A published dimension has a datum, and "cabin width" is not "floor width".**

**Unresolved and not quietly corrected:** `CABIN_FLOOR` is 0.56 and is tagged ESTIMATE, but [MM]'s 48 in
(1.219 m) of cabin height under the drawn 1.875 m roof gives 0.656. The seats, the instrument panel and the
declared floor all stand on that constant, so it wants a measurement or a decision rather than a nudge.

**How the promise is held, in `tests/skyhawk.gd`.** The room is five typed numbers; the skin is 2,734
exterior triangles emitted by different code from different constants, and they never touch. The figures are
compared against the references typed at the top of the suite; the box is then sampled on a grid over its six
faces (1,802 points) and every sample put through plane-slice ray parity against the drawn triangles. Both
mutants land on exactly their own check: `ROOM_HALF` 0.46 to 0.50 fails the figures check AND puts 229 of
1,874 samples outside the skin, worst 0.050 m; `floor` collapsed to the room's own bottom fails the floor
check alone. The suite carries its own falsifiability proof as well -- a room deliberately bigger than the
aeroplane puts 4,837 of 5,734 samples outside, worst 0.718 m -- and asks every kind whether it answers at
all: 1 of 25 declares a cabin, 24 give one of 2 reasons, none is silent.

**And it is the right room, held to a point nothing in it produced:** [EALT]'s eye for a real 172S pilot,
h 1.45 and s 2.33, 0.27 m off the centreline, is inside it. **The package's own seat 0 eye is not** -- it
stands 0.12 m over the room's roof and 0.09 m outside its wall. That is the seat move, it is native
shape-table data, and it is printed by the check rather than asserted, because a check that demanded the bug
would go red the day somebody fixed it.

**A control tower is a vehicle that cannot move.** `Model::Fixed` gets no forces at all and
its pose is never read back out of the physics, for the same reason a train's is not: its
position is a fact rather than a result, and a merely very heavy building would still sink,
drift and eventually fall over. It has four seats round the cab facing four different ways,
which is the first real use of a seat's yaw for something other than a rear-facing gunner,
and its bus is a radio, a radar page and the runway lights.

A station may now have NO flight controls at all, because a tower does not fly.

### "On the ground" was keyed to the wrong number

It was half the control reference -- a number about when the SURFACES bite, which has
nothing to do with when the wheels stop mattering. On a Cessna that came to 12 m/s against a
wing that needs 38: the take-off roll handed over to the mixer at a third of flying speed,
the mixer commanded a climb, and the aeroplane was dragged off the runway at 27 m/s and
stalled straight back onto it. Every time, from a full-length strip.

`ground_speed` is its own number per kind now and it is always over what the wing needs. The
Cessna rolls to 49 m/s, rotates and climbs away.

### AND AN AIR BASE ROUND IT, FROM ONE FILE (2026-09-17)

The user asked for one: *"model an airbase, it should be similar to the runway, but with
hangers and rivetments ... taxi-ways so that planes can drive around to get to the runway
... a tower with controller seats"*.

**A base is laid on a RUNWAY FRAME and says nothing in world coordinates.**
`world/airbases/<id>/airbase.json` gives every number as ALONG and ACROSS a runway
`Terrain.runways()` already has, so the island's `RUNWAY_*` constants stay the one source
and the base's ends follow the runway if it is lengthened. It is Kunsan AB's pattern -- one
parallel taxiway with stubs, the apron between the middle stubs, the tower beside it -- and
every dimension in the file cites the public standard it comes from: the taxiway at 320 m,
outside UFC 3-260-01's 304.8 m lateral clearance zone; hold bars at 76.2 m; the enhanced
0.30 m paint of FAA AC 150/5340-1; Navy Type I and III hangars from UFC 4-211-01; 20 x 22 m
fighter revetments with 3.66 m walls 1.68 m thick from AFCESA's history of Bien Hoa.

**What a wing decides is worked out from the file's `apron_craft`, not typed** (2026-09-19,
lane/linersfix). An apron gives a COUNT of `spots`, spaced its craft's span plus
`wingtip_to_wingtip` apart, and a revetment block names the `taxilane` it opens onto and
stands its front that craft's half span plus `wingtip_to_taxilane` off it, plus `SET_OUT`
(0.1 m, because a wall laid exactly on 27.1 m read as inside it by a rounding). They were
typed, 33.1 m pitches and fronts at 420, round a 30 m airliner; when lane/liners drew the 737
at 35.8 m no apron spot held it and both revetment blocks stood 25.0 m from the ramp where
27.1 was wanted. `tests/airbase.gd` still holds its OWN design kind rather than reading the
file's, so a file that named a narrower craft is caught: laid for the fighter, the fronts
came to 16.1 m.

**Content is a folder scanned at boot, like everything else here** (`AirbasePlan.bases()`):
the folder name is the id, `_`-prefixed folders are skipped, and a malformed base refuses
itself in words. A base also refuses itself on a runway that is not a quarter turn -- a
static box takes no yaw -- and on ground not level with the runway, which is how the alpine
strips, flattened only 120 m either side, decline one by name.

**The route graph is derived from where the centrelines meet, not typed beside them**: 50
nodes and 51 edges. `tests/airbase_taxi.gd` searches it with Dijkstra and DRIVES it -- a
fighter out of a revetment bay to the hold bar on Shift, Ctrl and the rudder keys, 136
simulated seconds at no more than 8.5 m/s, on the pavement the whole way.

**The base's hull is a CLEARANCE, the sixth kind** (`&"airbase"`), so no town, wood or
mountain is ever generated onto a taxiway. And `AirbaseView` tells `smoke` which solid boxes
it drew (`drawn_solid`), because the picture-equals-physics count is kept by the yard and
the base's 30 boxes are not the yard's.

**Two things this work found that were not about air bases at all**, both in the commits
and in the repo root's learnings folder, under this lane's name and date: a player at a keyboard could not open the throttle
on ANY craft (the lever was wound on the render clock and drawn over from the wire on the
same clock -- see `PilotRig._wind_the_lever` and `VehicleControl.worked_here`), and no
control tower had ever been drawn as anything but its collision box (its stalk and cab sat
below `_build_wing`'s `if span <= 0.0: return`, and a tower has no span). Neither had a
suite: nothing here had ever pressed Shift, and every tower check asked where the SEATS
were.

## AIRPORT LIFE: TAXI, TAKE OFF, THE TRAFFIC PATTERN AND A LANDING (lane/pattern, 2026-09-19)

The user, 2026-09-19: *"research landing patterns for airports ... build a ai mode that can honor this (while avoiding
other planes). This same mode should be able to taxi and takeoff from an airport and start it's "fly to random
waypoints" mode."* The FAA's rules, with every paragraph number, are in `research/traffic_pattern.md`: AIM 4-3,
AC 90-66C, and the Airplane Flying Handbook chapters 8 and 9.

**Three pieces, and none of them flies anything.**
- `TrafficPattern` (`world/traffic_pattern.gd`) is geometry. For one runway end, one side and one kind it gives the
  legs' corners and the height and speed at any point. It never steers.
- `Airfield` (`world/airfields/<id>/airfield.json`, content scanned at boot) says which runway end is in use and which
  side each end's pattern lies on. The side is published per runway END ([AIM] 4-3-3 b), so it is data beside the
  runway, and no aeroplane has a side of its own. A file can lay a new runway: the island's second strip, on the south
  shore, is one, and `Terrain.runways()` adds it after the world's own, so runway 0 is still the island's.
- `AirportTraffic` (`world/airport_traffic.gd`) is the host's tactics, as combat's attackers are. It says where to
  go, how high and how fast (`steer_ai`), how steeply to bank (`set_ai_manners`), and what the wheels do
  (`steer_ai`'s "wheels"). Everything is flown by the mixers, through the levers a player's hands move. It runs as one
  "pattern" chore on the rota, about ten times a second.

**What it does, in order:** `depart` takes a parked aeroplane along the base's taxi graph (`AirbasePlan.route`, the
same Dijkstra `airbase_taxi` drives by keys) and holds short until the runway is clear. It lines up, aligns and takes
off down a carrot on the centreline. It climbs straight out to half a mile past the end and within 300 ft of pattern
height, turns 45 degrees to the pattern side, and after two miles is handed back to the random-waypoint wander, or
flies en route to another field (`fly_to`). `arrive` chooses the entry by geometry:
- a straight-in when it is within 30 degrees of the extended centreline, 5 km or more out, and tracking within 45
  degrees of the runway;
- otherwise the 45 entry on the pattern side;
- otherwise the teardrop from the far side, across mid-field 500 ft above.

Then downwind at pattern height to abeam the threshold, the descent through base, a stabilised 300 ft gate, the flare,
the roll-out, and a taxi clear to its own spot on the side away from the pattern.

**The numbers are the kind's, never a table.** The pattern height is 1,000 ft, or 1,500 ft for anything over 14 CFR
1.1's 12,500 lb. The speeds are multiples of the stall the library derives: downwind no faster than 1.6x, base 1.4x,
final 1.35x (1.3 VSO plus a little, because the mixer allows no climb at all at 1.3x). The downwind stands off 2.5 of
the kind's FLOWN turn radii at a bank of 30 to 45 degrees, chosen for a 0.75 NM downwind, and never nearer than half a
mile.

**A BANK BUYS ONLY PART OF A TURN IN THIS FLIGHT MODEL, AND THE PATTERN IS SIZED ON THE PART IT BUYS.** Measured on
2026-09-19 in a steady autopilot turn, the flown turn rate over g·tan(bank)/v is:

| kind | Cessna | light twin | Hawkeye | tanker | airliner |
|---|---|---|---|---|---|
| flown / coordinated | 0.53 | 0.60 | 0.63 | 0.54 | 0.34 |

Each is the same at 20, 30 and 45 degrees. A circuit sized on the textbook radius had the Cessna reach the 300 ft
gate 320 to 455 m off the centreline, still turning final. So every aeroplane gauges its own turn whenever it banks
past 10 degrees (`_gauge_the_turn`), and its pattern is sized on the flown radius until it joins the circuit.
`AirportTraffic.TURN_UNKNOWN` (0.5) sizes the first one of a kind, wide rather than tight. **The airliner's 0.34 at its
25-degree limit puts its downwind about 8 km out**: an airliner wants straight-ins, or a flight-model fix, and that is
the flight-model lane's. **On its lifting surfaces the Cessna turns at 0.99** (lane/cessnafm, `tests/cessna_book.gd`),
and its circuit is sized on 1 before the gauge reads it (`turn_expected`).

**The C++ it needed, on `steer_ai`: "wheels" and "approach"** (`AiPilot::Wheels`, `roll_on_the_ground`, `ai_wheels`).
Before it, every autopilot on its wheels was handed to `take_off()`, so an AI touchdown opened the throttle and took
off again. And on a 3-degree path the look-ahead saw the runway along the velocity and flew its escape climb below
55 m, flattening the final to 1.8 degrees. The landing's pieces:
- The flare holds a sink rate rather than a height: `Bugs.holds_climb`, because below 1.3x stall the altitude loop's
  slow rule commands a descent. It begins 1.5 s of sink above the wheels, aims to touch at 0.9 m/s, and closes the
  throttle.
- A landing is down only when its wheels say so. Taken as down under `ground_height` and below `ground_speed` (49 m/s
  on a Cessna, its whole flare), the first landings stopped flaring 4 m up and dropped in 800 m along the runway at
  14 m/s.

**Measured, in `tests/traffic_pattern.gd`:**
- On downwind it holds pattern height to 1.4 m.
- At the 300 ft gate it is 19 m off the centreline, at 51.4 m/s against a wanted 51.3.
- The final is 2.98 degrees; the straight-in's is 3.00.
- It touches down 296 m past the threshold at 1.08 m/s down and 43.8 m/s along.
- Two at once never come within 963 m in the air, and the later lands 112 s after the first is clear of the runway.
- Taxiing, it stays within 4.5 m of its route. It lifts off 1.0 m off the centreline and climbs out within 2 m of it.

Four mutants go red on their own checks: the side flipped, the descent begun at mid-field, the approach key dropped,
and the spacing off (80 m apart, both on base).

**Sequencing** (`_leader_of`, `_gap_to_leader`, `_downwind_conflict`, `_runway_taken`): one circuit per runway end,
ordered by the path still to fly.
- A follower extends its downwind for a 45 s gap. Nobody flies a 360 ([AIM] 4-3-5).
- An entrant that would cut in on the 45 turns away and comes back ([AFH] 8).
- It goes around at 300 ft if closer than 20 s behind the aircraft ahead, and at 100 ft if the runway is not clear.

**Large aeroplanes fly an instrument approach** (`world/instrument_approach.gd`, the user 2026-09-19: "something more
similar to a IFR approach which requires far less turning"). This covers every kind over 14 CFR 1.1's 12,500 lb:
the airliner, the transports, the Hawkeye and the jets. The light kinds keep the pattern. The approach, from
`research/traffic_pattern.md` section 9:
- vectors (downwind, base, a 30-degree intercept) or a straight-in, established 8 NM out;
- the glideslope met from below at the FAF, 5 NM out and 1,643 ft up;
- bank no more than 25 degrees, and a flown turn no faster than standard rate;
- every leg sized to the FLOWN turn radius.
An airliner started abeam on the wrong side is vectored in and established 7.6 NM out, never above 25 degrees of bank
or 2.31 degrees a second, and is stabilised at 300 ft. The same airliner on the VFR pattern (the mutant) goes around.
**Landing configuration** (C++, `publish_levers`): gear down on a steered approach and never stowed while landing;
flaps as a speed brake, eased out only past 3 m/s over the asked speed; and on touchdown, flaps in, spoilers out and
the stick a little forward while it is fast. Before it, no autopilot had ever lowered its gear ("none of them land"),
so the first airliner touched down gear up, and a Hawkeye reached its gate at 76 m/s against 65. Given full flaps as
a rule, the Cessna went around from every pattern at 43.8 m/s. Now the airliner and the Hawkeye both land gear down,
stay within 3.5 m of the runway after the touch, and stop. The Hawkeye reaches its gate at 67.1 m/s, and the Cessna
is unchanged, 18.8 m off the centreline at its gate.

**Climbing before the high ground** (`_high_ground_ahead`): out of the circuit it looks 3 km along its track every
second. If a steady 3 m/s would not clear that ground by 300 m in time, it circles left-handed to climb first. The
first trip's 45-degree departure pointed at the southern ring and hit it at 100 knots, because the look-ahead's escape
climb was begun 1.2 km short. `AirportTraffic.highest_ground` is the level's `Terrain.highest_near`, and a suite flying
over its own slab replaces it.

**Pictures:** `tests/pattern_shot.gd` (a probe; `--scene=one|two|trip`). It shows the south shore strip from straight
down, or from behind for the trip, as a still and under MovieWriter. A timelapse is `--write-movie` at a low
`--fixed-fps`, played back at 30. `Engine.time_scale` does not do it: at 8 the world still ran 203 simulated seconds
in 203.

**A probe's overlay is not the game (lane/seethrough, 2026-09-19).** The user reported "landing strips visible THROUGH the
mountains" on the P-51 trip and suspected the depth buffer. It was this probe: it drew the strip's outline, the legs and the
track with `no_depth_test`, which is right for a picture from straight down and wrong from the chase camera. The game itself
was measured from 134 eyes with a runway behind rock (`tests/seethrough_shot.gd`, 400 m and 150 m up, day and night, out to
30 km): the mountain hides the runway from every one, `MountainView` has no reach to run out, and only `mist.gdshader` and
`puff.gdshader` say `depth_test_disabled`. A line drawn for a chase now tests the depth buffer (`PatternShot.draws_on_top`);
`tests/seethrough.gd` holds that and the two-shader list. Before you look for a z-buffer fault, look at what the probe drew.

**Found on the way, not about airports:** `sky.gd` painted every runway as `Basis(yaw).scaled(size)`, and
`Basis.scaled` scales along the WORLD's axes. So every runway turned a quarter was painted across its own centreline:
the generated ground's east-west strips, and the new shore strip. It now scales in the mark's own frame.

## CAPE INTERNATIONAL: AN AIRLINER AIRPORT WITH CROSSING RUNWAYS (lane/airport, 2026-09-19)

The user, 2026-09-19: *"we'll need a model like the airbase but a civilian airport (with multiple runways, sometimes that
cross one another, they will need to be long enough for the 747 and 737 to takeoff and land."*

**Where and what.** It sits on the flat north-east cape, and is all data:
- `world/airfields/cape_09_27` and `cape_18_36` lay two 3,500 m by 45.72 m runways. 09/27 runs along the north shore at
  z -6,400; 18/36 runs down the east at x 6,100.
- They cross 2,450 m from 09's threshold and 2,850 m from 36's.
- `world/airbases/cape_international` lays the airport round them in 09/27's frame:
  - a parallel taxiway inside each runway, 400 ft off;
  - stubs with hold bars 280 ft off, including on the crossing runway;
  - three 30-degree high-speed exits, all turned off before the crossing;
  - an apron taxilane with power-out remote stands for 747s, and nose-in contact gates for 747s and 737s;
  - a 570 m two-storey terminal and a 37 m tower.

Every clearance is FAA AC 150/5300-13B's, for the 747-400 (design group V, taxiway design group 5, category D), and
each is cited in the file. The ends in use are 09 and 36. Finals into 27 and 18 would begin 21.7 km out, past the
world's soft edge at 19.3 km.

**What the plan learned to do** (`AirbasePlan`, `Airfield`, `Terrain`):
- A base names its runway by airfield id (`"runway": "cape_09_27"`) and may serve others (`also_runways`). Each other
  runway must lie a quarter turn from the base's own. Its places are `<id>.threshold`, `.far_end`, `.centreline` and
  `.edge`, and a taxiway ending on `<id>.edge` gets a hold bar for that runway. `laid["holds"]` says which runway each
  bar holds short of.
- `exits` are the one piece of a base off the frame's axes. They are pavement only, drawn turned. Walls still need
  quarter turns, because a static box has none.
- An apron may name its own `craft` (the plan spaces its stands by that craft's span) and may be `nose_in`. A nose-in
  stand keeps its tail `taxilane_obstacle_clearance` off the taxilane, and it can only be ARRIVED at: the autopilot's
  wheels drive forward, and a pushback is a C++ step not yet taken.
- `terminals`, and a `tower` with `"built": true`, are solid walls the view dresses. The island's first runway keeps its
  crewed TOWER craft instead.
- An airfield file may give `length_m`, `width_m` and `protection` (the runway object free area and protection zones).

**Three traps, each met on the way:**
- **The runway keep-out.** `Terrain._clearances` keeps a square of 0.9 x the runway's length clear round each end. At
  3,500 m that square is 6.3 km across, and it would have cut the northern ring away. A runway that names its
  `protection` keeps exactly that as one box. The 900 m strips keep their square.
- **The base's keep-out.** A base used to keep its hull clear. An airport laid round crossing runways is an L, and its
  hull took in the empty corner of the L, where the ring's north-east flank stands: 2,292 of the island's 332,929 rock
  samples came down by as much as 446 m. Now every slab and wall is kept clear, each grown by the taxiway obstacle
  clearance (`keep_clear`). The fighter base's rock is the same either way (0 points differ, measured).
- **The crossing's paint.** Two asphalt slabs with one top flicker where they cross. The later runway in
  `Terrain.runways()` lies `CROSSING_DROP` (1 cm) lower, and neither runway paints a stripe or stands a light on the
  other.

**The site's rock.** Within 600 m either side of both finals, the 3-degree path clears every rock sample, out to where
the 747 is established. At x 5,900, the first sketch's position for 36, the ring's east flank stood 5 m above the path
there, so 18/36 moved 200 m east. Beyond 600 m it does not clear: rock 364 m high stands 950 m beside 09's final,
3.7 km out.

**The 747 on it**, measured by `tests/airport.gd` on a runway as long as the file's:
- 1,223 m from brake release to 35 ft; with 14 CFR 25.113's 15 per cent, that is 1,406 m of 3,500.
- Down to taxi speed 1,171 m past the threshold, against 121.195's 60 per cent, 2,100 m.
- The game's 747 flies slower than a real one (it stalls at 50 m/s). The runway's length is the real aeroplane's: about
  3,380 m to take off at 875,000 lb on a hot day (Boeing D6-58326-1 rev F, 3.3.4).

**Pictures:** `tests/airport_shot.gd --scene=look` (a probe) takes stills from the air, with 747s and 737s standing at
the gates on their brakes.

**The traffic at it** (`AirportTraffic`, step 2):
- **Holds.** A departure taxis to a hold bar of ITS OWN runway, the one nearest the threshold in use. The nearest bar
  of any kind to 18's threshold holds short of 09/27, 745 m away.
- **Turning off.** A landing that comes down to taxi speed takes the first way off ahead: a high-speed exit's start,
  or a stub's join on its runway. From there it follows `AirbasePlan.route` to the nearest free nose-in gate its kind
  fits. `vacating` counts as on the runway until it is the hold bar's distance off the centreline, where it becomes
  `taxi_in`, and it ends `parked`. With no airport round the field it clears to the side as before.
- **Onto the stand.** The route's corner onto the stand is cut as a chord (`STAND_CHORD`). With a square corner a 747
  came onto its lead-in 12.7 m wide at 17 degrees and parked 3.5 m to one side; a shorter carrot oscillated to 8.5 m.
  It creeps onto its mark slower the nearer it gets. The measured result is 0.9 m from the mark and 3 degrees off the
  line.
- **Crossing runways** (`_crossing_busy`, FAA JO 7110.65BB 3-9-8 b and 3-10-4 b, simplified; no land-and-hold-short):
  a departure does not begin its roll, and an arrival goes around at 100 ft, while anybody on the other runway is:
  - departing and not yet past the intersection;
  - still rolling out, unless the roll is done short of it;
  - turning off by a way that lies past it.
  A departure also waits for an arrival on the other runway's final within `DEPARTURE_CLEAR_S`. Short of the
  intersection means the hold bar's distance before it, along the other runway.
- **Measured** (`tests/airport.gd`): a 737 taxis from a remote stand to 09's bar while a 747 is put on 36's final
  4 NM out. The 737 holds 47 s, then goes with 0 conflicts. The 747 turns off 1,911 m in, 939 m short of the
  crossing, never touches 09/27, and parks at gate heavy.1. With the rule removed, the 737 rolls with the 747 on
  short final.
- **The 747 turns at 0.28 of its bank, and the island is too small for that.** Its turn gauge settled at 0.28 of a
  coordinated turn: a 3.8 km flown radius at 25 degrees and 70 m/s. Vectors to 36 laid on that put the downwind 13.3 km
  east, at 19.4 km out per axis, past the island's warning (17.3 km) and on its turn-back (19.3). Two changes in the
  lane:
  - `InstrumentApproach.make` lays vectors on no less than `AirportTraffic.TURN_UNKNOWN` (0.5). `turn_expected` alone
    returns the gauged 0.28 once the kind has turned, so dropping the re-plan would not have been enough.
  - A heavy sent on to another field is handed to its approach at the end of the departure leg, not flown round the
    VFR 45's two miles, which pointed it the wrong way.

  The heavy then flies each corner wider than it was laid, and the carrot rejoins the next leg. **The real fix is the
  747 on its own lifting surfaces** (`research/real_wing_playbook.md`, the big-aeroplanes step, not started until the
  user says go). **0.28 is the measure that lane must beat**, and the Cessna went from 0.53 to 0.99 on its surfaces.
- **A trap in the check itself:** its conflicts first went into `(seen["conflicts"] as PackedStringArray).append()`,
  which appends to a copy, so the rule-less mutant passed with "0 conflicts". `-- --trace` printed both aeroplanes
  and showed the truth. Keep what a lambda writes in an Array.

## LEVELS: A FOLDER EACH, CHOSEN ON THE DESK, AND THE SAME ONE ON EVERY MACHINE

    Godot --path cockpit -- --world=alpine                 solo, on that level
    Godot --path cockpit -- --host=47970 --world=alpine    host it
    Godot --path cockpit -- --join=127.0.0.1:47970         a joiner flies the host's, and is told which

Asked for on 2026-09-15: "let's have multiple levels that can load". The island stays the default until the user accepts
the alpine world's pictures (team-lead, the same day).

**A level is a folder.** `levels/<id>/level.json` holds:
- a name and a one-line summary, for the desk and the clipboard;
- the world it stands on, `island`, `alpine` or `room` (`GroundTuning.World`, asked rather than listed);
- a generated world's three ground numbers, which it may leave to `GroundTuning.values()`;
- how far it asks to be drawn (`reach`, for cockpit-terrain's view distance);
- what an arriving player is put in (`arrive`), a `Sim.Kind` name, a pod unless the file says otherwise;
- the first arrival's spawn, and how far apart the rest stand (`apart`, 14 m unless the file says);
- the sea's colours (`water`, optional `deep` / `crest` / `foam`), three linear floats 0..1 each. A channel the file
  does not name is the shader's own default. A level that says nothing is the sea as it was.

The island takes no ground numbers. A generated world's are checked by `GroundField.configure` itself when the level is
read, whole JSON floats made ints first, so a world wider than the wire is refused in the ground's own words
("world_half 99999 clamped to 32768"). "places" stays out of the file (cockpit-terrain, 2026-09-15): the alpine world's
places come from its catalogue and one seating table in code.

`ChartDrawer` (`world/chart_drawer.gd`) scans the folder once and `LevelChart` (`world/level_chart.gd`) reads one level.
It is the workshop's rule 7:
- the folder name is the id: lower-case, digits and `_`, at most 24 characters, since it goes on the wire and onto a
  lobby;
- a `_` folder is skipped;
- a level that does not say what a level needs is kept off the desk, with its reason, said once as a warning.

A key the file does not know is a refusal, not a thing ignored: "spwan" read as no spawn at all would seat every joiner
at a default nobody wrote, and a misspelt `"watre"` would otherwise fly on navy blue. `tests/levels.gd` reads ten fixture
folders in `tests/level_fixtures/`: two good levels are kept beside seven refused in words (a folder name that is no id,
no file, not JSON, a misspelt key, a world nothing builds, no spawn, a ground wider than the wire) and one skipped.

**A level may say what colour its water is** (lane/watercolour, 2026-09-19). `"water": {"deep": [r,g,b], "crest": [...],
"foam": [...]}` -- every field optional, linear 0..1, the uniforms both `ocean.gdshader` and `ocean_fine.gdshader`
already declare as `source_color`. `WaterSurface.dressed` (`world/water_surface.gd`) is the one place any water is
dressed, so it reads the session's chart (`ChartDrawer.chart(Net.level)`) the way the sky reads haze, and writes only
the channels the level named. The defaults stay in the shaders; a copy in GDScript would be a second set that had to be
kept in step. `tests/water_surfaces.gd` holds every water surface in every level to those colours, lakes included --
the bug `WaterSurface` was created to stop. A level that says nothing is byte-for-byte the sea as it was: the uniforms
are never written.

**WHICH LEVEL A SESSION STARTS ON WHEN NOBODY HAS CHOSEN depends on the kind of session** (the user, 2026-09-15: "let's
make the lobby default when hosting a session. and island if they are playing alone"). So it is not one constant:
`ChartDrawer.DEFAULT` is the island and `ChartDrawer.HOSTING` is the lobby, and `Net.suit_the_session(hosting)` is the
rule. It is called by `play_solo`, `host` and `host_steam` and by nothing else, so the boot flags follow it without
`world/boot.gd` knowing it exists, and a JOINER is untouched -- it flies its host's level, which is what the hello is
for.

**It is not an override, and that is the half that would rot.** `Net.level` is kept between sessions so the desk
remembers what a player picked, so a player who chooses the island on the chart monitor and then presses HOST must get
the island. `Net.level_chosen` is what says somebody chose, set by `choose_level` (the monitor, and `--world=`). The
shape and the reason are `Finish.suit_the_display`'s: move an UNCHOSEN setting to the default of whatever is about to
happen, leave a chosen one where the player put it.

**And the monitor cannot mark a chosen level when nobody has chosen one**, because it does not know which button is
coming. With nothing chosen it marks no row, names the default on each of the two rows it belongs to ("The lobby ·
hosting", "The island · on your own") and says at the foot what each button will fly. Marking `Net.level` anyway would
tell a player they had picked the island while HOST was about to fly the lobby. `tests/lobby.gd` section 6 presses all
three buttons on the real screen with nothing chosen, then chooses the island and presses HOST. RED: "'Host a game'
left Net.level 'island'".

**Two suites had to name a level they had been getting by default**, which is the cost of the rule and is worth knowing
before the next one: `tests/crew_peers.gd` boards another player's craft and a segway has one seat, so it went red on
three checks and 90 s of timeouts until its child host was given `--world=island`; `tests/two_peers.gd` names it too, so
that the island's two-peer path stays covered now that the lobby's has a suite of its own. `tests/desk_join.gd`
deliberately does not: its child hosts the lobby and this machine arrives with the island chosen, which is the ordinary
joiner's case.

**Pressing "Host over Steam" in a headless suite starts the real Steam client.** `SteamLobbyDirectory.unavailable()`
calls `steamInitEx`, and GodotSteam's matching `steamShutdown` at exit then errors on a RenderingServer connection it
never made in a headless process -- "Attempt to disconnect a nonexistent connection ... Signal: 'frame_post_draw'" --
which fails the suite that provoked it. `tests/lobby.gd` stands `PaperLobbyDirectory` in its place for that one press,
as every other Steam suite here does.

**The session's level is `Net.level`.**
- The desk's left screen, WHICH LEVEL (`ChartMenu`, `ui/menus/chart_menu.gd`), chooses it. It shows one row per level
  `ChartDrawer.charts()` gives it, with the name as a button and the summary under it, so a new folder under `levels/`
  is a new row with no code. The screen announces `chose(id)` and the desk decides: `DeskRoom._choose_level` calls
  `Net.choose_level`, which is refused while a session is up, and the refusal is shown on that screen. The session
  screen's row of level buttons (morning of 2026-09-15) moved here.
- The chosen row reads "<name>   ·   chosen", and the foot of the screen reads "The next session flies <name>".
- About seven rows fit on the page. A level list longer than that needs pages or a scroll the beam can drive.
- The chosen level is amber in every state a button is drawn in, hovered included; a beam always hovers what it points
  at, which is how the quit button once lost its colour.
- `--world=<id>` chooses it from a command line, beside `--host`, `--steam-host`, a door or nothing. A level nobody has,
  or `--world=` beside a join, is a BOOT_ERROR, because a joiner flies the host's level.
- `--levels-from=res://...` points the drawer at another folder, which is how a suite makes a joiner with a different
  copy of a level.
- **The level says what its arrivals stand in and how far apart, not `Sim`.** `Sim._seat_new_clients` spawned
  `Kind.POD` and worked the spot out inline, four across and on down 14 m apart. Both are the level's answer now:
  `arrive` names a kind, checked when the level is read against `Sim.Kind` itself (`LevelChart.arrivals`), so a level
  that names a kind this build has not got takes itself off the desk instead of seating everybody in kind -1; and
  `LevelChart.spot_for(slot)` is the arithmetic, so the briefing room's floor marks are drawn from the same function
  that puts the players on them and a mark cannot stand where nobody is put. Both default to what was typed before --
  a pod, 14 m -- so `levels/island` and `levels/alpine` are byte for byte what they were and their hashes with them,
  and no suite's pods moved. RED (`tests/lobby.gd` section 2, 2026-09-15): a fixture level asking for segways "seated
  true in a pod, wanted a segway".
- The world reads its level at every build, and the clipboard's CREW page leads with it.

`tests/levels.gd` clicks a level with a real mouse event on the session screen, then "Fly on your own", and asks the
world it lands in which level it built. This machine's pod came down 0.0 m from that level's spawn; with the desk
ignoring the press, 581 m from it and on the other level (red on 5 checks).

**A level's hash is of what the file says, not of its bytes.** `core.autocrlf` is true here, so a Windows and a Linux
checkout of one commit differ in every byte of a text file. `LevelChart.canonical_hash` is SHA-256 of the parsed data
written back with sorted keys. A CRLF, space-indented copy of a fixture hashes the same (b572bc38...), and a spawn moved
1 m does not. Rejected:
- hashing the raw file, which would refuse a Linux joiner a Windows host's identical level;
- hashing the built collision alone, which catches code drift too, but only after a joiner has spent the seconds
  building a world it is about to be refused. The ground's own hash is checked after the build instead; see below.

**A world goes when you leave it (2026-09-15).** MAIN MENU only changed scene (`Doors.to_the_desk`), so a player back at
the desk was still in the solo or hosted session: `Sim` ticked the old world's collision and every pilot under the
menu, a host's socket stayed open with nobody flying, and the level row refused a level because a session was up.
`DeskRoom._ready` now ends any session the way every leave ends one, when the desk is the scene (a child of the root). A desk built inside something else is furniture: the first version of the line ended smoke's running world under the desk it stands beside to measure, 3 of 9 sections and then a null `Sim.server`. `tests/level_swap.gd` flies every usable level from
the desk five times through the real buttons and MAIN MENU's door, and reads the process at the desk after each round
(double editor):

| round | levels | nodes | objects | orphans | static memory after rounds 0, 2, 4 |
|---|---|---|---|---|---|
| island alone | island | 277 every round | 2,537 every round | 0 | 68.39, 68.48, 68.60 MB |
| island then alpine | both, each ground stood in both worlds and let go | 279 every round | 2,552 every round | 0 | 70.57, 70.75, 70.98 MB |

With the desk's leave taken out, `the_desk_holds_no_simulation` went red with client, server and session all still up.
The suite allows no node or object growth and half a megabyte over two rounds. The first allowance, 64 objects and 4 MB,
passed a mutant that kept each world's `WorldMap` in a static, which grew one object and about 1 MB a round.

### A LEVEL CAN BE A ROOM: THE LOBBY, AND ITS BRIEFING ROOM

    Godot --path cockpit -- --world=lobby                   stand in it on your own
    Godot --path cockpit -- --host=47970 --world=lobby      host it, and everybody who joins stands in it

Asked for on 2026-09-15: "let's make a lobby level, where players join ... that has a briefing room where all players
load ... there should be some joysticks and buttons (that don't do anything) in the lobby so players can prepare before
loading into the level."

**THE LOBBY IS A LEVEL, WHICH THE USER DECIDED**, and it is the decision the whole shape of this rests on. A level is
what the entire session agrees about -- `Net.level`, the hello, a joiner's refusal -- so a player standing in the
briefing room is an ordinary player in an ordinary session: the segway under them replicates because a level runs a
`Sim` world, the CREW page lists them, and joining a game already in progress is the join it has always been. The
rejected alternative was a room you visit, a bare scene like `hall.tscn`: nothing in one of those is simulated or
replicated, so two players in the same room would not see each other, and every piece of that machinery would have had
to be built a second time for one scene.

**So `room` is a WORLD**, the third `GroundTuning.World`: the island's slab, whose top is y = 0, with no country on it
at all -- no boxes, no scenery, no woods, no lift, no waypoints, no traffic, no fires, no sea and no mist. `FlightLevel`
asks the level once (`_indoors`, from `LevelChart.indoors`) and everything outdoors is now ONE function,
`_stand_the_country_up`, lifted out of `_build` unchanged, so a room skips the country in a line instead of in fifteen
guards -- a guard per thing is the guard somebody forgets to add to the sixteenth. `_on_sim_ready` returns early for the
same reason: every seeding call after it asks `Terrain` about a country this level has not got. **It needed no surgery
on the world**: the `island` branch already gated the boxes, the scenery, the woods, the railway and the places, and
what was left was the sea, the mist, the runways and the waypoints.

**`BriefingRoom` (`world/briefing_room.gd`) is built in code, sized from the level's own spawn data.** The room is 20 m
by 14 m and 2.6 m high, centred on the block of arrivals the level puts in it, with a mark on the floor for every player
a session holds (`Net.MAX_PLAYERS`) and four desks along the wall they face. Each desk carries a joystick and three
buttons. A level file that moves its arrivals moves the room, the marks and the desks with it; a hand-laid `.tscn` would
have been a second copy of the level's numbers.

- **Every mark is `LevelChart.spot_for(slot)`**, the same function `Sim` seats the arrivals with, so a mark cannot be
  drawn where nobody is put. Measured: the worst mark is 0.000 m from its spot.
- **One list of boxes for the collision and the picture**, as `Terrain.boxes()` is: the walls, the ceiling and the desks
  go into `Sim.add_static_box` and into the meshes from `BriefingRoom.boxes()`. Measured (`tests/lobby.gd` section 4): a
  segway walked at the far wall for six seconds stops at z -6.65 m against a wall face at -7.00 m; the same drive on a
  floor with no room on it reaches -19.49 m, 12.49 m past where the wall would be. The contrast is a CASE in the suite
  rather than a revert, the way `tests/segway.gd` keeps its pod.
- **The props do nothing, and what enforces it is what they are**: every desk, joystick and button is a
  `MeshInstance3D` with no script, so a rig looking for controls finds none. The suite fails if any of them has one.
- **The arrivals stand on segways and 1.8 m apart**, which is the level file saying `"arrive": "segway"` and
  `"apart": 1.8` -- see the bullet on arrivals above.

**Two peers in the briefing room see each other, which is the claim the whole decision rests on.**
`tests/lobby_peers.gd` is tests/two_peers.gd's shape on this level: a host (`--host=PORT --world=lobby --report=1`) and
a joiner, both headless, each read out of its own log. Measured: both machines name two sync clients, draw two pilots
and print `crew=segway:1/segway:2`, 3.8 s from launch. The ISLAND PAIR is kept in the same suite as the contrast rather
than as a revert -- `crew=pod:1.-.-.-/pod:2.-.-.-` -- so if `Sim` ever went back to seating a constant kind the lobby
case fails and the island case says what it now reads.

`tests/lobby.gd` is the gate, in four sections; `tests/lobby_shot.gd` is the picture, three PNGs from a standing eye, a
high corner and a desk (`screenshots/2026-09-15/cockpit-29`, `cockpit-30`). A level that is a room is skipped by
`tests/ship_legs.gd`, which sails every level the desk offers: there is no water in a briefing room, and an indoor level
is counted and skipped rather than quietly left out.

**Joining a game already in progress still works**, which is the part most easily broken by putting a room in front of
the world. `tests/lobby.gd` section 5: this machine chooses the lobby, then joins a bare host on the loopback that says
it is flying the island, and what comes up is the island with no briefing room in it. It passed the first time it ran --
a joiner has taken its host's level since the hello went in -- and it is here because the lobby is the first level that
is not a place to fly, so "the joiner kept its own level" stops being cosmetic and becomes a player standing in a room
while everybody else is in the air.

**AND THE WAY OUT IS THE LAUNCH BOARD.** On the wall the desks face hangs the desk's own WHICH LEVEL screen
(`ChartMenu` on a `TouchPanel`), listing every level `ChartDrawer` found. It is the same page, not a second one, so a
folder added under `levels/` is a row there too. The board announces and the level decides
(`FlightLevel._launch_the_level`): it asks `Net.change_level`, and whatever `Net` answers goes back on the glass, so a
player who is not the host presses a level and reads "Only the host changes the level" rather than nothing at all.

**It is worked without a headset, which is item 0.** The level hands the board to `PilotRig.pointer_panels`, the seam
the desk's own monitors use, so the MOUSE points at it on a desk (a ray from the eye through the cursor,
`GlassPointer`) and the pointing hand's beam does in a headset. Nothing about it is headset-only. The joysticks and
buttons on the desks stay inert on purpose; the board is the one thing in the room that does something, which is why it
is glass on a wall and they are shapes on a table.

`--launch=<level id>` after the bare `--` presses that level on the board once a second player is in the room, for a
harness -- the real `Button`, pressed the way `--board=` presses JOIN on a CREW page. Nothing in the game passes it;
`tests/no_vr_flight.gd` is what does.

### THE TEST FIELD: 65 KM OF FARMLAND, NO SEA, AND AN AIRPORT ON EACH SIDE (lane/testfield, 2026-09-19)

    Godot --path cockpit -- --world=testfield

The user, 2026-09-19: *"Could we have a larger map (with no ocean) that has runways on either side for better
testing?"* and then *"with two large airports a military base and a small civilian airport."*

**`levels/testfield` is the generated ground with its sea taken away.** It is `alpine`'s world (`GroundField`) with the
numbers `world_half` 32768, `peak_height` 300, `seed` 0, `coast` 96 and `sites_within` 20500. See "Three optional ground
keys" under THE WORLD.
- **The whole wire square is land**, ±32.768 km, so there is ground under the edge band too.
- **Everything placed stays inside about 21.6 km**, so the band starts at 23.6 km.
- **Peak 300 is rolling farmland with low ridges.** Measured at step 0 with a probe of the central 13 km: land from 57 to
  391 m, a median relief of 199 m in a 4 km square, and 5.3 % of it steeper than 15 degrees. Peak 0 gave 113 m of
  relief, peak 600 gave 345 m and 10.7 % steep.

**The size is the wire's, and the edge band is what limits it.** The last resort begins at 32,268 m. Two of the widest
turns and `CLEAR_OF_PLACES` must fit inside it, so everything placed has to stay inside about 21 to 25 km, depending on
the widest turn of the day. `tests/testfield.gd` prints the margin: placed within 21,646 m, the band from 23,646 m and
3,687 m deep (the widest turn on 2026-09-19), fitting by 1,248 m. A map bigger than the wire would need the `ground`
quantiser widened in C++ on both ends of the wire. That was not done.

**The runways are its own airfield files, `"world": "testfield"`** (`Airfield`, which now takes a level id as a world;
a level with any files of its own takes only those). Their numbers are the files' own:
- **West International:** parallel 3,500 m runways 36L/18R and 36R/18L, 1,310 m apart, at x -18 km.
- **East International:** Cape International's crossing pair, 18/36 and 09/27, at x +17 km.
- **The air base:** a 2,743 m 09/27 at z -14 km.
- **The small field:** a 900 m 09/27 at z +13 km.

**A runway laid across the map cannot take a final from outside it.** A 10 NM final ends 18.5 km past the runway's
end, so the side airports' runways run north-south, and East's 09/27 takes no final into 27: that final would begin
at x 36.6 km, past the wire. 27 is for take-offs. Every other end, 11 of 12, takes a final.

**The ground makes room for the airports; the airports do not go where the ground happens to be flat.**
`Airfield.pads_for` makes one pad per cluster of runways. Its rectangle is each runway's pavement grown by its object
free area. Its funnels run 10 NM off every runway end, 600 m either side. `GroundTuning.for_level` hands the pads to the
ground with the level's numbers, and a runway on a level's own ground stands at the level the ground found for its pad,
not at the file's y. The pads are not in `level.json`: they are the airfield files' numbers, and a copy there could
disagree with them.

**Measured (`tests/testfield.gd`, double editor):**
- **The ground takes 3.8 s to build per world, and 7.6 s for both.** 4,096 land cells, 81.4 MB a world, against
  alpine's 1,799 cells and 35.8 MB.
- **No sea anywhere.** 0 of 66,049 samples on a 256 m lattice of the whole square are sea (170 are a lake's), and the
  lowest ground is 1.5 m. `Terrain.has_sea()` is false, `open_sea_near` finds nothing without searching, and neither sea
  sheet is drawn. `has_sea` exists because `open_sea_near` on an all-land ground scanned 260 rings out to twice the
  half-width for every ship a level tried to place.
- **The pads stand at 90.2, 101.6, 114.3 and 137.2 m**, and every runway is flat along its centreline to the tick.
- **Every final is clear.** Off all 11 ends that take one, no ground within 600 m of the extended centreline stands
  above the threshold plus 1 m in 34, out to 10 NM. With the funnels taken out (the mutant), 10 of the 11 were blocked,
  by 8 to 150 m.
- **The trips, centre to centre:** west-east 35.7 km, west-base 23.3, west-small field 24.4, east-base 22.0, east-small
  field 19.8, base-small field 27.1.

**The airports are laid as data (S3)**, each from its own `world/airbases/testfield_*` file:
- **East International** is Cape International's file with its runways renamed.
- **The air base** is the fighter base's file on the test field's 9,000 ft runway, named by airfield id.
- **West International** is a midfield layout between the parallels, on the pattern of Atlanta's concourses. Each
  runway has a parallel taxiway on its inner side at 400 ft, stubs with hold bars, an exit for each direction of
  landing and an apron taxilane. There are two terminals back to back, with 747 and 737 gates and six remote stands on
  the west side. Remote stands laid facing 36R's taxilane did not hold a 747, because the plan points a remote stand's
  nose away from the base's own runway.

`tests/testfield.gd` holds each base to the standard its file cites, measured between rectangles the suite works out:
- every parallel taxiway off every runway the base serves;
- every wall and the tower off every taxiway and taxilane;
- no wall in a served runway's object free area;
- every stand fitting its craft, with a route to a hold bar;
- every slab on its pad's level.

It measured 314, 78 and 142 distances. The mutant (West's terminal moved onto its taxilane) went red on exactly those
distances.

**Three things changed to lay them:**
- **The pads cover the bases.** `Airfield.pads_for` lays each base in plan (`AirbasePlan.lay(..., on_ground = false)`)
  and grows the airport's pad by its hull. The air base's hangars stand 560 m off its runway and had been laid on an
  unflattened hillside.
- **`lay` checks the ground only when asked.** It refuses ground that is not level, and the pads are worked out
  before the ground exists, so every lay was refused.
- **A base that names its runway by INDEX is laid only on a world's own runways** (`AirbasePlan.runway_index`). On the
  test field, runway 0 is whichever of its files sorts first, and the island's fighter base, `"runway": 0`, was being
  laid round the test field's air base runway by the accident of that sort.

**Its air is its own (S3).** A level may now say `"haze"`, a share of the game's haze from 0.1 to 1. It multiplies the
depth fog's clear air (`Daylight.thin_the_air`) and the low mist's haze, stratus and town domes (`MistLayer.thin`).
Every level that says nothing gets 1, so the island's picture and every other level's hash are unchanged. The test
field says 0.35: at the island's clear air 5 % of the view is left at 18.7 km, and at 0.35 it is left at about 53 km.
**And a level's `reach` is now used.** It was read from every level file since cockpit-terrain and handed to nothing,
so every eye stopped at the rig's and the observer's 24 km. `FlightLevel._build` now sets every camera of the main
viewport to it before anything asks `_far()`. The level map's camera keeps its own. The test field asks for 42 km.

**No ship is offered on a level with no sea.** `VehicleCatalogue.craft_rows_for(Terrain.has_sea())` leaves the ships
group out, and the CRAFT page says "No ships on this level: it has no sea." The level hands the page its rows once the
ground stands, because the page is drawn before there is a level. A flying boat is an aeroplane and stays; the lakes are
its only water. Not done: the server does not refuse a ship asked for by some other path, and the rig's own craft keys
walk every pilotable kind.

**The cuts: a slope limit, not a wider blend.** The pads' 800 m blend and the funnels' 400 m side blend were
smoothsteps of a fixed width, and where a 300 m ridge crossed East's 36 final the cut stood at 49.9 degrees, which read
from the air as a scar. Now each pad and funnel only ever takes the lower of the ground and a cone rising 1 in 8 off
its edge (1 in 34 along a final), and for a pad also the higher of the ground and a cone below. The lower of two surfaces
is never steeper than the steeper of them, so no cut can be steeper than the bare ground was, or than 7.1 degrees.
- **Where the check looks.** `tests/ground_field.gd` holds it on a 16 m grid round a 4 km pad with two 10 NM finals:
  0 steps steeper than the bare ground or the cone.
- **The mutant.** The previous library, with the smoothsteps, gives 1,640 steps and a 49.9 degree one.
- **Over the whole test field**, the steepest ground the pads make is 7.1 degrees, and no sample they make is steeper
  than 1:8.
- **A trap in the measuring.** Compared naively against a field with no pads, the first counts said 22,357 and then
  20,531 samples steeper than 1:8, with the steepest 51 degrees 11 km from any airport. A padded world catalogues its
  towns and lakes elsewhere and finds no strips of its own, so near any site of EITHER catalogue the "bare" ground is
  not the ground the pad was laid on. Both the check and the probe skip samples beside a site, and say how many.

### THE TEST FIELD'S MOUNTAINS: THE ISLAND'S RANGES ON A GENERATED GROUND (lane/testfield, 2026-09-19)

The user: *"can you add some of our mountain ranges from the island map to the testfield?"* A level may now name
`"mountains"` in its file: ranges in the island's own format (`{salt, peak, saddle, points: [[x, z, crest, foot], ...]}`,
crests in metres above sea level). They are checked when the level is read by `MountainRange.configure` itself, and a
level on a world that is not generated ground refuses them. They live in the level file, not beside it, because every
machine must stand the same rock and the file's hash is what a joiner is checked against.
- **The same rock as the island's.** `Terrain.mountains()` on a generated ground builds the island's `MountainRange`
  from the level's ranges, so the same faceted, snow-capped surface is drawn by the same `MountainView` and handed to
  the simulation by the same `Sim.set_mountains`. No C++ changed.
- **Its keep-outs are the island's** (every clearance, town and wood), plus a staircase under every final of the level's
  own runways (`Terrain._final_keepouts`): 1 km steps, 300 m wider than the funnel either side, each floored at the pad's
  level plus the 34:1 rise at its near end. So no range the file lays can stand in an approach.
- **Terrain answers with the rock.** On a generated ground with a level's ranges, `ground_height`, `surface_heights` and
  `highest_near` take the higher of the ground and the rock, so the AI's climb-before-high-ground rule sees them.
  `land_height` stays the bare ground: it is what an air base and a runway frame stand on.
- **Two traps met on the way:**
  - *A runway frame that asked the rock laid every base twice.* Its height asked `ground_height`, which asked the rock,
    whose keep-outs ask the air bases, which are laid on runway frames. Frames ask `land_height`.
  - *The rock raised on a worker thread did the same.* The mist's worker asked `surface_heights` first, and its keep-outs
    called `AirbasePlan.bases()` while the main thread was inside it too, so both laid into one list. `Terrain.stand_on`
    now raises the level's rock on the main thread before any worker asks.
- **The test field's four:**
  - a ridge north of the air base's finals;
  - a range south of the small field;
  - a lone peak between West and the base;
  - a ridge north of East.

  Each lies beside a route, not across one. Measured (`tests/testfield.gd`): the tops stand at 900, 805, 631 and 860 m,
  537 to 782 m over the ground round them, and the simulation's own ray meets each top. All 11 finals stay clear at 34:1
  sampled WITH the rock.

### A CRAFT TAXIING ON THE GENERATED GROUND WAS DESTROYED AT EVERY 1,024 m SEAM (FIXED, lane/testfield, 2026-09-19)

Nothing had taxied on the generated ground before the test field; every airport test runs on the island's slab. On the
test field, every craft that taxied was destroyed within a minute: NET_CRASH `rule="struck its nose first at 4.1 m/s"`
for a fighter, and "struck its side first at 4.61 m/s" for a 747, cause ground.
- **It was positional.** Held still on the pad, three 747s lost nothing in 60 s. Driven, each fighter was struck as its
  nose reached x 0 or z -14,336 (14 x 1,024), with nothing solid standing there.
- **The cause.** `Bedrock` lays one Box3D height field per 1,024 m cell, and a hull box sliding across the edge two
  fields share met a speculative ghost contact there, side-on.
- **The fix.** `shape.enableSpeculativeContact = false` on Bedrock's height-field shapes. Box3D's own words for the
  switch: "Leave this true unless you care about reducing ghost collision more than continuous collision under rotation."
- **The check.** `tests/testfield.gd` drives two fighters across x 0 and z -14,336 at taxi speed, and neither is struck.
  Main's previous library is the mutant: its probe lost both.

### A LEVEL'S AIRPORT LIFE: `traffic.json` AND `TrafficPlan` (lane/testfield, 2026-09-19)

The user: *"let's have the basic test in testfield, but also have a stress test that increases the amount of ai traffic
on that map (not by default but runnable on request)"*.
- **A level folder may hold `traffic.json`.** It has a `basic` list, flown by default, and a `stress` list, flown
  instead with `--traffic=stress` after the bare `--`. A flight is `{kind, from, to, spot?}`.
- **`TrafficPlan`** (`world/traffic_plan.gd`) is the host's. It puts each flight on its stand (or lined up on the end in
  use), hands it to the level's own `AirportTraffic` with `depart(..., then_to)`, and once it has parked or stopped at
  its destination for 30 s sends it back the way it came, for ever.
- **Kept out of the level file on purpose.** AI traffic is the host's, and a joiner sees what replicates; a traffic list
  in `level.json` would refuse a joiner over flights it never flies.
- **A level may also say `"fleet": false`.** It then flies no ambient AI fleet, only its traffic file. The test field
  does: it is for testing, and the ambient fleet held a suite of three trips to 2.2 times real time.
- **A level may say `"fires": false`.** No fire is lit from the ground and no `FireFront` is built to spread one (`sky.front`
  stays null). The glider level does (the user, 2026-09-19: "remove fires from the glider level"): nothing there can put one out.
  Every level that says nothing keeps them. Held by `tests/gliderlevel.gd`.
- **The trips are their own suite, `testfield_traffic`**: solo, with a 1,800 s deadline. They take about 1,550 s of
  simulation at about 1.9 times real time. `testfield` itself runs in about 30 s.
  - A 747 goes from West's remote stand to East's 09: it takes off at 300 s and touches down at 1,544 s.
  - A Cessna flies circuits at the small field: it touches down at 597 s.
  - "Landed" is a touchdown at the destination, not parking. The first check counted only parked craft, and failed a
    747 that was taxiing in at the gate.
  - **The fighter is out of the basic trips.** It reaches its stabilised gate at 53.6 m/s against 48.2 and goes around
    every time (todo/testfield--traffic-ai-faults.md). It is still in the `stress` list.
- **Fast impacts stay honest without speculative contact.** Piloted fighters driven straight down into the air base's
  pad at 60 and 120 m/s, on the corner where four fields meet and on a field's middle, are all destroyed by the ground
  and stopped 1.3 to 1.7 m above it, the same on the seam as off it (`tests/testfield.gd`). Main's crashes, seabed,
  seabed_alpine, ground_collision and far_out also pass with the change. A 45-degree dive was tried first and never
  arrived: a craft is spawned level, so its wing pulled it out 65 m up.
- **THE STRESS TEST, ON REQUEST** (the user: "a stress test that increases the amount of ai traffic on that map (not
  by default but runnable on request)").

      powershell -File cockpit\tools\testfield_stress.ps1 -Scales 1,2,4

  - **How it runs.** `tests/testfield_stress.gd` is a probe, never a suite row. The tool runs it headless once per
    scale, under a MEASUREMENT line in `GPU_SLOT_HOLD`.
    - The stress list is 25 aircraft of six kinds at all four fields. `count` copies after the first start in the air
      along their route, and `--traffic-scale=K` multiplies every count.
    - Each run gives 60 s of simulation to spread out, then measures 120 s with the simulation's own tick breakdown.
      It watches once a second for go-arounds, holds, runway conflicts (two aircraft on one runway's pavement, either
      faster than a taxi) and losses.
  - **Measured on 2026-09-19,** double editor, on main d8133956's libraries, headless:

    | scale | aircraft | vehicles | tick | chores | forces | Box3D step | wall per simulated second | conflicts | losses |
    |---|---|---|---|---|---|---|---|---|---|
    | 1 | 25 | 67 | 1.82 ms | 1.22 ms | 0.03 ms | 0.09 ms | 0.72 s | 0 | 0 |
    | 2 | 50 | 90 | 3.89 ms | 3.07 ms | 0.05 ms | 0.11 ms | 1.14 s | 0 | 2 |
    | 4 | 100 | 134 | 8.84 ms | 7.24 ms | 0.15 ms | 0.17 ms | 2.92 s | 0 | 8 |

  - **The tick budget (8.33 ms at 120 Hz) breaks between 50 and 100 airport aircraft, about 95.**
    - The physics is not what costs: forces and the Box3D step together are under 0.35 ms at 100 aircraft.
    - The CHORES are: the rota's jobs, where every `AirportTraffic` pilot thinks. They grow faster than the count
      (x2.5, then x2.4, for x2 the aircraft), which points at the per-pilot sequencing that walks every other pilot
      (`_leader_of`, `_circuit_of`, `_runway_taken`).
    - Scale 8 was stopped rather than run for its 25 minutes. See todo/testfield--airport-chores-grow-faster-than-the-traffic.md.
  - **What the airports did under load.**
    - No runway conflict at any scale, and no holds in the measured window (it is minutes 1 to 3, before most arrive).
    - LOSSES, all "struck another aircraft first":
      - at scale 2, a Hawkeye and a 747 at 59 m/s, both arriving at West's 18L from different sides;
      - at scale 4, three more pairs in the air at 58 to 64 m/s, and a 737 and a 747 at 4 m/s taxiing into each other.
    - Nothing separates instrument arrivals from different directions, or two aircraft taxiing, and the circuit
      spacing is for the VFR pattern. See todo/testfield--traffic-ai-faults.md.
  - **Two traps in the setup, both fixed before the numbers above.**
    - The first run placed eastbound and westbound airborne copies on one line at one height, and two 747 pairs met
      head-on at 142 and 150 m/s. Copies now fly the semicircular rule: east 300 m higher, over three levels 150 m apart.
    - Two standless starts at the small field were lined up in one place and took off side by side. Now one lined-up
      start per field, and the rest in the air.
  - **Pictures,** windowed, `--scene=pictures`: `screenshots/2026-09-19/cockpit-testfield-16-stress-top-down-tracks.png`
    (every track at scale 2 after four minutes) and `-17-stress-west-international.png`. `--scene=lapse` orbits West
    under `--write-movie` for the time-lapse.
    - A `PackedVector3Array` is a value: appended through `Dictionary.get_or_add` it grew a copy, and the first top-down
      had no tracks.
    - A 1-pixel line strip is invisible at 50 km across the frame. The tracks are 90 m ribbons with no fog and no depth
      test.
    - The tool first killed its own PowerShell with a filter meant for its Godot child, after the first scale. It
      matches Godot processes other than itself now.
- **Two things the first trips found in the data.** A 747 from a stand on 36L's side had no route to 36R's hold bars and
  lined up across the grass, so West gained two taxiways across the field. And a vectored 36 final from the far side of
  East took the 747 past 1,500 s, so the basic flights land where their final is on their way: East's 09 from the west,
  and West's 18L from the north.

### THE GLIDER LEVEL: SIXTEEN KILOMETRES OF RIDGES, ITS OWN THERMALS AND A SKY TO FLY ROUND (lane/gliderlevel, 2026-09-19)

    Godot --path cockpit -- --world=gliders

The user, 2026-09-19: *"I'd like you to build a smaller level 16km that has our ridge mountains and is designed to be
flown by gliders, so we'll need lift zones that the gliders can fly to, make sure we have good clouds as well so that we
have to find our way around the clouds themselves ... The goal is to experiment with what the game is like with just
gliders."*

**`levels/gliders`, "The ridge country", is the generated ground at a quarter of the test field's size:** `world_half`
16384, `peak_height` 300, `seed` 15, `coast` 96 (no sea), `sites_within` 5000. Seed 15 was chosen from a probe of sixteen
seeds because it catalogues one town, one strip with two gliders parked beside it (a gliding club) and one lake, and puts
the band where the user asked for the level to end:
- **placed within 6,248 m, the band from 8,248 m: 16.5 km across**, 3,687 m deep, fitting the wire's last resort by
  16,646 m. Seed 0 put its only town 3.2 km out, and the band at 7.3 km;
- the ground is 20.4 MB a world and stands in 1.8 s for both worlds, against the test field's 81.4 MB and 7.6 s;
- the land is 33 to 350 m, with low hills through the middle.

**Its ridges are the island's kind of rock, as data** (the test field's `"mountains"` key): a north ridge of four points
along z -5.6 km, an east ridge of three along x +5.5 km, and a lone peak in the south-west. Measured (`tests/gliderlevel.gd`):
tops at 899, 880 and 523 m, 823, 733 and 412 m over the ground round them, and the simulation's ray meets each top. A
single-point range stands well under its crest (crest 900 gave a 523 m top), so the lone peak's crest is 1,250.

**THREE NEW LEVEL KEYS, each absent from every other level, whose hashes are therefore unchanged:**
- **`"lift"`: the level's own thermals**, `[{name, at: [x, z], radius, strength}]`, in the level file because every world
  simulates the air it holds. `Terrain.lift_zones()` on a level that lays them returns those first, in the file's order and
  named, each stood on the ground by `grounded_zone` exactly as the ground's scatter is (base on the ground, top
  `THERMAL_TOP` over it or higher until its cloud clears the rock), and NOTHING ELSE: not the ground's hashed scatter, and
  not the towns' own thermals either. The scatter is a hash over the land's reach, and a level that says where its lift is
  should have that lift and no other; the towns' are 260 m at 4.4 m/s, which a circling glider cannot climb in at all (see
  "A GLIDER THAT FLIES ITSELF"). The first zone is "the start", which arrivals are launched at. Refused on a world that is not generated
  ground, as `"mountains"` is.
- **`"cloud_cover"`: how many of the game's low clouds the sky holds**, a factor on `PuffSky.PER_100_KM2` for the kinds in
  `PuffSky.LOW` (cumulus, flat-based, towering), 0.25 to 4. At 1 the plan's draws are exactly what they were. The decks
  above stay the game's, since nothing that soars reaches them.
- **`"craft"`: the only craft a level offers, and why**, `{"kinds": ["glider"], "why": "it is for soaring"}`. The CRAFT
  page is handed only those rows and says "Only the glider on this level: it is for soaring." (`VehicleCatalogue.craft_note`),
  only those kinds get issue places, and `Terrain.spawns()` stands only those: the spawn table is one of every movement
  model, and a parked jet on the glider level is a jet a player can walk into from the seat buttons.

**The level's thermals, and why they are the size they are.** A zone lifts `S (1 - r/R)^2`, and a glider circling in one
sinks **2.66 m/s** -- measured, not its 1.05 m/s straight and level -- and settles **129 m** from the middle, so what its
vario reads is `S (1 - 129/R)^2 - 2.66`. The level's ten reach 550 to 650 m from the middle at 6.5 to 8.0 m/s, which is
**+1.1 to +2.5 m/s**, and `tests/gliderlevel.gd` prints that figure for each of them. Nothing already in the game passes
it: the island's scatter is 2.6 to 5.0 m/s over 200 to 330 m and a town's is 4.4 over 260, all negative. Why the circle
costs what it does, and why that is the flight model's fault rather than the sky's, is under "A GLIDER THAT FLIES
ITSELF". They lie in a loop round the ridges 2.4 to 3.5 km apart, the start in the middle; from 100 m under any cloud
base a 25:1 glide reaches another zone at least 300 m over the ground there, and all ten are joined up from the start.

**The sky.** At cover 2 the level's sky holds 123 cumulus, 61 flat-based and 20 towering against the game's 61, 31 and 10
over the same 32 km square, plus the ten thermals' own clouds, each based at its column's top (ground plus 1,500 m, about
1,590 to 1,850 m above sea level). The random cumulus stand at 1.0 to 1.4 km, below the thermal clouds, so a glider
climbing out of one thermal meets them on the way up and has to go round them, and a flat-based cloud higher than the rest
is where the next thermal is. It is still six draw calls.

**The arrival launches flying.** `Sim._seat_new_clients` hands `spawn_pilot` a velocity now (`Sim.arrival_velocity`): an
aeroplane whose spawn stands more than `ARRIVE_FLYING_OVER` (50 m) over the ground arrives at its cruise along the spawn's
heading, since a glider put in the air at a standstill has no engine to recover with. Every other level's arrivals stand
on the ground or are not aeroplanes, and arrive still as before.

`tests/gliderlevel.gd` (suite) holds all of it. Six mutants across the two steps, each red on exactly its own check: the
level's lift ignored (18 zones, five sound, the first nameless); the cover ignored (61, 31 and 10); the craft list ignored
(every craft on the page); the winch ignoring other players (1,231 m apart); the issue-place skip removed (a crashed pilot
back on the apron); and one thermal typed back to the island's size (-0.4 m/s at the circle). `tests/gliderlevel_shot.gd`
is the probe for eyes, and `tests/glider_polar.gd` the one that measures the aircraft.

**Seen in the first pictures and not changed:** a big flat-based cumulus seen from right under it draws as overlapping
discs, which is the puff clouds' own look from below; and the level's fires (`Terrain.fires()`, three smoke columns near
the middle) stand here as on every generated ground, each a thermal of its own.

### THE ADRIATIC: AN ARCHIPELAGO OF ISLANDS AND SEA STACKS (lane/adriatic, 2026-09-19)

    Godot --path cockpit -- --world=adriatic

The user, 2026-09-19: an archipelago of small islands and tall sea stacks in a warm blue sea, with pine forest on the
slopes, for low flying in a seaplane. Original scenery; the look is the Adriatic of a 1920s seaplane story, not a copy
of any film.

**`levels/adriatic`, "The archipelago", is the generated alpine world with a small home island and the rest of the
islands laid as the island's kind of rock.** `"world": "alpine"`, never `"island"`: the island world's geometry is
hard-coded in `world/terrain.gd` and shared by every island-world level. The alpine world is the data-driven one. The
trick is two independent layers:

1. **The generated ground** gives ONE home island, sized by `ground.coast` -- the coast's mean radius in 32nds of
   `world_half` (`ground_core.hpp`). `GroundField` will not take a coast below 16 (the brief asked for 6-10; 16 is the
   floor, so that is what the file says). At `world_half` 16384 that is a mean radius of 8,192 m, a modest island in a
   32 km square of sea.
2. **The `"mountains"` ranges are separate rock laid on top**, and `Terrain.ground_height` is the max of the generated
   ground and the mountain rock. A range placed out in the open sea, crest above zero, *is* an island or a sea stack.

**Seed 80, peak 600, coast 16**, chosen from a probe of fifty-six seeds. Seed 80 catalogues one town, one strip and three
lakes, and cuts a 2.2 km inlet into the east-south-east shore (bearing 40°, coast 5,248 m against a mean 7,816 m). The
spawn is on the water in that cove, `[4158, 1, 3489]`, yaw 230 -- facing out along the inlet, a metre over the surface,
so a Savoia arrives afloat rather than flying (`Sim.ARRIVE_FLYING_OVER` is 50 m). Peak 600 m is Mediterranean hills, not
Alps; the probe's highest ground on this seed was 559 m.

**Fifteen ranges.** Five broad low islands (measured tops 48 to 97 m) and ten stacks (measured 54 to 160 m). A sea stack
is a one-point range with a high crest, a small foot and a saddle close to the peak so the noise cannot pull it down
into a hill; a one-point range still stands well under its typed crest, as the glider level's lone peak did. The
fly-throughs are the point of the level; a gap is the distance between two control points less `1.175` times each foot
(range_core.hpp: a spur stands out at most 1.175 feet), computed from the file, never typed beside it:

| Gap | Where | Width |
|---|---|---|
| the needle channel | (10000, 8200) and (10000, 8335), on the way out of the cove | 17.5 m |
| the twin fangs | (-13500, -2800) and (-13500, -2907), west | 8.3 m |
| the sisters' tight gap | (-7200, 12200) and (-7200, 12318), south-west | 5.2 m |
| the sisters' wide gap | (-7200, 12318) and (-7200, 12455) | 19.5 m |

A seaplane at 5-20 m can thread all four. Three more lone stacks stand north, far east and far south.

**Forest is automatic** on the alpine world -- `Forests.stands_on_the_ground` throws up to eight rectangles on dry,
gentle ground. There is no `level.json` key for it. Measured (`tests/adriatic.gd`): 8 of 8 stands kept, all on the home
island (the tries land within about 6 km of the middle, which is `GROUND_SPREAD` of `land_reach`). 3 tries were too
steep, 3 wet, 9 on a town or strip. The outlying mountain-islands are outside that reach, so they come out bare even
with gentle tops; that is reported, not forced, and `forest_tuning.gd` is not edited.

**The Savoia is the aeroplane this level is for.** `"arrive": "savoia"`, and `"craft"` offers the Savoia, the tanker,
the small boat, the gunboat and the CB90 -- the sea looking alive, and nothing that belongs on a runway. The pirate
ship is not on the list: nobody may be put in one (`pilotable` false), and a craft list naming it refuses the whole
level. No ambient fleet. Haze 0.45 and cloud cover 0.6 for a clearer Mediterranean day than the island.

**`ship_legs` skips it, counted, because it flies no ship** (lane/shiplegs, 2026-09-20). `"fleet": false` and a craft list
that is the player's alone mean no ship ever has a route here; the suite had been red on the adriatic since this level
landed, all four kinds failing together on "0 legs" with 0 s waiting (232.6 s alone on a quiet machine, `main cae96fee`).
That was the check's scope and not shallow water: the suite now skips a sea level whose `fleet` is false, as it skips a
room and a level with no sea, and the last check counts it. Green after, 218 s.

`tests/adriatic.gd` holds that the drawer lists it, it has a sea, the spawn is on the water, every range stands in the
rock and the collision, and the four gaps are the widths above. `tests/adriatic_shot.gd` is the probe for eyes; the
pictures are `screenshots/2026-09-19/adriatic-look-*.png`, the viewport's own image, never a capture of the desktop.

### THE WINCH: WHERE A GLIDER LEVEL PUTS A PLAYER, JOINING OR AFTER A CRASH (lane/gliderlevel, 2026-09-19)

The user, 2026-09-19: *"Any player that joins or crashes should be respawned at the first zone at 1000 feet (or if there
are other players, within 100 meteres of that player) so they can start over."*

**`GliderWinch` (`world/glider_winch.gd`) is that rule, in one place, asked by both callers** --
`Sim._seat_new_clients` when somebody joins and `CrewRespawn` when a crew is put back -- so an arrival and a respawn
cannot disagree. Its numbers are the level's: `"launch": {"height": 304.8, "beside": 100}`, and the first zone is the
level's first thermal. A level that says nothing has no winch and behaves exactly as before.

- **Nobody else aloft:** over the first thermal's middle, 304.8 m over the ground under it, at the glider's cruise along
  the level's spawn heading -- inside the thermal, where a glider pilot starts a day.
- **Somebody else aloft:** beside whichever of them is nearest the first thermal, at their height and heading, 60 m out
  to the side and 40 m back (0.72 of `beside`, 72 m at 100). The side is the one AWAY from their turn, read off the
  craft's spin, so an arrival is never put inside the circle a thermalling glider is flying. "Aloft" is a craft that is
  not a wreck and stands 50 m or more over the ground: somebody who has landed is not somebody to be launched beside.
- **And always handed over flying**, at their speed or the kind's cruise, whichever is greater.

**THAT LAST LINE IS A BUG THAT WAS FOUND BY LOOKING AT WHERE A CRAFT TURNED UP.** `respawn_crew` ends in
`launch_if_grounded`, which RESCUES a craft handed to a crew below its own flying speed: it lifts it to `kLaunchAltitude`
(800 m) over the highest ground within 1.5 km and levels it. With the other player gliding at 38 m/s, the winch asked for
310 m and the crew arrived at 1,176 m -- 865 m over the player it was meant to be beside -- while the host's log said it
had asked for the right place. Nothing in GDScript can see the rescue happen. The same rescue is why the first thermal's
launch is at the cruise and not at rest.

**A LEVEL WITH A WINCH REGISTERS NO ISSUE PLACE FOR THE KIND IT LAUNCHES** (`FlightLevel._register_issue_places`),
because `respawn_crew` takes the kind's first clear issue place BEFORE the place the host asks for. With the glider's
apron places left in, a crashed glider pilot was put back on the ground beside the strip instead of at the thermal. The
cost is that a CRAFT-page press for a fresh glider on this level takes a free seat on an AI glider or is answered "no
clear issue place"; the C++ alternative (a flag on `respawn_crew` to prefer the host's place) was judged not worth
building until someone hits the seat-taking case.

### A GLIDER THAT FLIES ITSELF: `SoaringPilot` (lane/gliderlevel, 2026-09-19)

lane/glider left "there is no glider AI" with the reasons (learnings/2026-09-17-glider.md): an aeroplane's 3 km minimum
leg skips the nearest thermal, and `kArrived`'s 220 m counts a glider arrived before it reaches any lift. So
`SoaringPilot` (`world/soaring_pilot.gd`) uses no legs at all. It is the host's tactics, steering the ordinary autopilot
through `steer_ai` as `AirportTraffic` and `Attackers` do, and it flies the glider through the same mixer a player's
hands move -- which for a glider holds the SPEED with the stick and lets the height be whatever the air gives it.

- **Glide** to the chosen thermal at the kind's cruise; **climb** once inside it; **leave** 150 m under the cloud base,
  or when the last 40 s have carried it less than 0.2 m/s; then the next thermal.
- **The circle is a point steered at**, 0.9 rad round a 110 m circle ahead of the glider, moved ten times a second. Every
  glider circles LEFT, as a gaggle does.
- **The next thermal** is the nearest reachable at 25:1 arriving 300 m over the ground there, not one of the last three
  visited; the nearest unvisited when none is in reach.

**EVERY ONE OF THOSE NUMBERS IS MEASURED, AND THE MEASUREMENT IS THE STORY** (`tests/glider_polar.gd`, the committed
probe). **This glider sinks LESS the faster it flies**: 2.69 m/s at 22 m/s and 1.20 m/s at its 40 m/s cruise, 8:1 against
33:1. No sailplane does that; the handling table's `induced_drag` of 45 swamps the slow end, and it is the flight model's
to fix (todo/gliderlevel--the-gliders-polar-is-backwards.md). What matters here is what follows from it:

- **A circling glider sinks 2.66 m/s**, not the 1.05 m/s it sinks straight and level, and the best of six circles tried
  was 27 m/s round a 110 m ask, where it settles 129 m from the middle. Slower is worse (3.15 m/s at 24), and faster
  cannot hold a circle at all (asked 34 m/s round 140 m, it sat 291 m out).
- **So the thermals a glider can use are much stronger than the ones already in the game.** A zone lifts `S (1 - r/R)^2`,
  so what a circling glider gets is `S (1 - 129/R)^2 - 2.66`. The island's scatter (2.6 to 5.0 m/s over 200 to 330 m) and
  a town's (4.4 over 260 m) come out NEGATIVE: nothing can climb in them. The glider level's ten are 550 to 650 m at 6.5
  to 8.0 m/s, which give +1.1 to +2.5 m/s, and `tests/gliderlevel.gd` prints that figure for every one of them.
- **Measured on the level:** a robot glider launched where an arrival is climbed **1.77 m/s** for 198 s in the start's
  thermal, left it 1,350 m over the ground under the cloud, glided 2.4 km and climbed again at the middle hills.

**AND A LEVEL THAT LAYS ITS OWN THERMALS GETS THOSE AND NOTHING ELSE** -- not the ground's hashed scatter, and not the
towns' thermals either, for the reason above: a level for gliders that quietly added a town's 260 m at 4.4 m/s would be
offering a thermal nothing can climb in. A level that wants one over its town lays one, as the glider level does.

### AIR TRAFFIC THAT GOES NOWHERE IN PARTICULAR, AND GIVES WAY (lane/gliderlevel, 2026-09-19)

The user, with the glider level: *"There should be some airtraffic as well (25-30) planes and should mostly avoid the
players, but it'll be nice to have a level that lets users experience a non combat scenario."*

**`AirTraffic` (`world/air_traffic.gd`) is the host's, and it is NOT `TrafficPlan`.** That one flies a named aeroplane
from one airfield file to another and turns it round on the stand (lane/testfield); this one has no airfields in it at
all. They answer different questions -- "who is flying the pattern at the small field" and "what else is in the sky" --
and a level may have either, both or neither. A level folder may hold `air_traffic.json`:

    {"summary": "...", "flights": [{"kind": "CESSNA", "count": 8, "band": [600, 1000]}, ...]}

`band` is the height over the ground that flight wanders at; a glider ignores it and soars (`SoaringPilot`). It is kept
out of `level.json` for `TrafficPlan`'s reason: AI traffic is the host's, a joiner sees what replicates, and a traffic
list in the level file would refuse a joiner over flights it never flies. A malformed flight is left out with a warning
in its own words.

**The glider level's twenty-eight:** eight gliders soaring the same thermals as the players, eight Cessnas at 600-1,000 m,
six light twins at 1,800-2,100 m (the clear air between the cumulus and the stratocumulus), four helicopters at 150-300 m
and two airliners at 4 km. Nothing armed; `tests/gliderlevel_traffic.gd` fails on any kind that carries a gun.

**HOW IT GIVES WAY: a closest point of approach, twice a second.** Each machine works out, from both velocities, where it
and every player-crewed craft would pass over the next `LOOK_AHEAD` (30 s). If that pass comes inside `KEEP_CLEAR` (500 m)
horizontally and `KEEP_CLEAR_UP` (150 m) vertically, it turns `BREAK_OFF` (1.05 rad) AWAY FROM THE SIDE THE PLAYER IS
PASSING ON -- so it never turns across their nose -- and, with an engine, asks for a height `STEP_ASIDE` (200 m) away from
theirs, clamped into its own band. It holds that until the pass opens to `CLEAR_AGAIN` times the distance, which is what
stops it flipping every look. Nothing here separates AI from AI: they fly their own legs and the world is large.

**Measured (`tests/gliderlevel_traffic.gd`), with the encounters STAGED**, because waiting for a chance one in
256 square kilometres is waiting for nothing. The player's glider is put where it and a Cessna arrive at the same point
in 30 seconds -- head-on, crossing, and slower in front of it -- and put high by what a glider with nobody on the stick
sinks on the way:

| pass | rule on | rule off (`KEEP_CLEAR` 1 m) |
|---|---|---|
| head-on | 315 m | 315 m |
| crossing | 482 m | 341 m |
| overtaken from behind | 447 m | **7 m** |

The traffic broke off four times in that run, and nothing came nearer than 316 m to the player all run. **Aim the
encounter, or it proves nothing:** the first version put the player 3 km along the machine's track and let it come, and
the unavoided pass missed by 311 m on its own -- a green check with the rule switched off.

All twenty-eight were still flying after two minutes, each inside its band. That check is what would catch traffic
steered into a ridge: the machines are given legs inside the edge band's start less 1.5 km, so nothing is ever steered
into the turn-back, and their own look-ahead climbs them over the rock.

### WHAT A POWERED AEROPLANE MAKES OF A THERMAL, AND WHAT A PICTURE OF A LEVEL COSTS (lane/gliderlevel, 2026-09-19)

**A machine on an autopilot does not notice a thermal at all, and that is worth knowing before anybody calls it
turbulence.** The glider level's thermals are 6.5 to 8.0 m/s over 550 to 650 m, and its traffic's bands run right through
them. Measured, each kind steered straight across the start's column (8.0 m/s, 650 m) at its own band, 3 km in and 3 km
out, after 15 s to settle:

| kind | band, over the ground | height held | worst vertical |
|---|---|---|---|
| Cessna | 800 m | 1,154 to 1,155 m | 0.3 m/s |
| light twin | 1,950 m | 2,305 to 2,306 m | 0.8 m/s |
| airliner | 4,300 m | 4,655 to 4,656 m | 0.8 m/s |

At 216 m from the middle the Cessna is in air rising at 3.6 m/s and holds its height to ONE METRE: the mixer's altitude
loop trims it out on the stick as fast as the air pushes, so the lift shows in the elevator and never in the path. It is
neither turbulence nor a bug; it is an autopilot flying better than a person. **A player hand-flying a powered craft
through the same column would feel all 3.6 m/s of it**, which is the difference worth remembering when somebody reports
that "the AI ignores the weather". Making it read would mean slowing the autopilot's altitude loop, and that is a
flight-model decision, not a level one.

**A trap in measuring it, paid for once:** the first probe spawned each aeroplane with `yaw` of +PI/2 and a velocity
along +x, which is an aeroplane flying BACKWARDS -- `Terrain.nose_from_yaw` points the nose at `(-sin, 0, -cos)`. The
Cessna and the light twin sorted themselves out; the airliner fell 4.4 km at 138 m/s and read as a catastrophic
interaction with the thermal. Spawn a wing with `nose_from_yaw(yaw) * speed`, as `AirTraffic` and `Terrain.spawns` both
do, or the measurement is of the spawn.

**AND A PICTURE OF A WHOLE LEVEL IS NOT A PICTURE FROM HIGH UP.** `tests/gliderlevel_shot.gd --scene=map` draws the
16 km square with every machine's track behind it, and the first two attempts were useless:
- **From 12 km up, the frame was cloud tops.** An ORTHOGRAPHIC camera frames the same square from any height, so the eye
  belongs UNDER the cloud (1,500 m here, over the tallest ridge) with a near enough `far` to clip the sky out. Nothing is
  gained by height; it only adds what is in the way.
- **Then the ground was a grey sheet**, because sixteen kilometres seen through the level's own haze from 1,500 m is
  mostly haze. A map is a drawing, not a view: the scene turns the environment's fog off and hides the mist layer.
- **Tracks are drawn at one height** (1,300 m, over the ridges and under the eye), not at the height each machine flew,
  because two tracks at their own heights read as one crossing the other. A `PackedVector3Array` is a value: it is put
  back into its Dictionary after every append, or the ribbon stays empty (lane/pattern found this first).

`--scene=reel` is the other half: a robot glider chased from a wingman's place -- never from straight behind, where an
aeroplane's wingtip trails stream past the lens (lane/combat) -- through a climb and a glide, recorded at
`--fixed-fps 5` with `Engine.max_physics_steps_per_frame` at 64 and played back at 30, which is six times real speed and
the only way a 1.8 m/s climb is something to watch. 2,164 frames, every one unique through `mpdecimate`.

### THE HOST CHANGES THE LEVEL, AND EVERY CLIENT LOADS IT AND REJOINS

Item 11, asked for on 2026-09-15: "make sure that the server can 'change the level' and the clients correctly load that
level and join the game." And with the lobby being a level, this is also how a briefing room launches into a flight --
the two are one piece of machinery, which is why they were built together.

**A LEVEL CHANGE IS THE JOIN HANDSHAKE, RUN AGAIN**, and there is deliberately no second protocol (team-lead,
2026-09-15). `Net.change_level(id)` names the new level, then puts every admitted peer back where a joiner starts:
`admitted.clear()` and each peer back into `_telling`. From there the same four messages happen for the same reasons --
the host says `level` until it is answered, the peer says `loaded` when it has built it, the host checks the hash and
the ground and says `admitted`, and a peer that cannot fly the new level is refused in `why_not_the_level`'s own words.
`admits` holds a peer's packets meanwhile: the gate a joiner meets, **withdrawn rather than never granted**, so a
machine rebuilding is never simulated into a world it no longer has. Measured (`tests/no_vr_flight.gd`): the host held
74 packets from the client across one island launch.

Three things had to change in `net.gd` and no more:
- `change_level`, because `choose_level` refuses outright while a session is up;
- `_told_the_level` hearing a level hello **mid-session** as well as while joining -- it returned at once unless
  `_stage == "hello"`, which is the whole reason item 11 did not work;
- `_built_here`, which is the one that is easy to miss. Between the change and the host's OWN rebuild, `_ground_here`
  is still the old level's hash, so a peer that got there first would be sent away for ground that was not its fault.
  Until the host has built, a `loaded` is not answered at all -- not admitted and not refused -- and the peer says it
  again in 200 ms, which is what "said again until answered" is for.

**Each machine RELOADS THE SCENE rather than rebuilding in place** (`FlightLevel._on_the_level_changed`). `_build`
rebuilds the simulation, but the drawn world is built once per scene on purpose -- the scenery yard, the woods, the
ground view, the authored places, the mist's chart and the railway are all once-only, because rebuilding two hundred
boxes of scenery per join is work nobody asked for. So `_build` on a different level would stand a new simulation
inside the old level's scenery, which looks exactly like a networking fault. Reloading is the path
`tests/level_swap.gd` already measures, with no node, object or orphan growth over five rounds.

**The reload is covered by one persistent curtain** (`Transition`, `autoload/transition_curtain.gd`, 2026-09-17).
The host's structured level notice is also an explicit cue: `{kind: level, target, hash, revision, epoch, due}` after
receipt. It is resent/acknowledged on the existing hello carrier, only accepted from peer 1, checked against the local
level content hash, and rejected when malformed or stale. `due` is rebuilt from the remaining milliseconds on each
machine's monotonic clock. The autoload's `CanvasLayer` survives `change_scene_to_file`: it fades for 400 ms, reaches
black 50 ms before the advertised change, remains opaque while `sky.tscn` builds, and fades back only after
`Net.level_loaded_here`. A solo launch gets a 500 ms local cue; a session with peers keeps the 3 s warning.

A peer connecting during the countdown is owed the cue before admission. A delayed `loaded` for the old level is
ignored while that peer is in `_telling`, because the current hello is already being repeated; refusing it disconnected
a healthy late joiner. Join notices wait until the active level cue is no longer the latest notice, so they cannot
replace the transition command. `tests/notices.gd` runs real ENet clients with 125 and 175 ms artificial edge delay,
including one started after the countdown began, and holds cue -> fully black -> `NET_LEVEL_CHANGING` -> reveal on both.
`tests/transition_curtain.gd` holds stale duplicates and the session-revision reset. `tests/level_change_shot.gd` saves
the visible briefing/black/island sequence. CanvasLayer is the documented viewport-fixed overlay path; its desktop
render is photographed. XR presentation has not been started in this lane, by the user's instruction not to start XR.

RED, read before the change (`tests/level_hello.gd` section 5): a client told a new level mid-session kept the old one
and emitted nothing; a client told a level it has not got did nothing at all and would have flown on in a world its
host had left; and "Net has no change_level".

**One check was rewritten rather than kept.** `tests/level_hello.gd` used to hold that a level hello naming a DIFFERENT
level mid-session changed nothing. That was right while a level hello mid-session meant nothing, and is the bug now, so
it says the SAME level instead -- which is what the repeated hello actually carries (CLAUDE.md, rule 12).

### A LEVEL CHANGE IS ANNOUNCED BEFORE IT HAPPENS, AND WHO JOINED AND WHO LEFT IS SAID (2026-09-16, plan item 13)

    a line on the board above the code, and the first line of the flat status; tests/notices.gd

Item 13, asked for on 2026-09-15: "we need a notification system so we know when users join, leave, or other important
things happen." **Built against the level change first**, because that is the case somebody had already hit: `lane/lobby`
left "nothing yet says a level change is coming. The client learns about it when its screen goes away." Built the other
way round, "who joined" would have been a line that appears, and the one case anybody had complained about -- a line
that has to arrive BEFORE something -- would not have fitted it.

**The launch board CALLS the level; it does not change it** (`Net.call_the_level`). With anybody to tell
(`Net.has_anybody_to_tell`: a peer admitted or still being told the level) the host says a `level` notice to every
admitted peer and makes the change `Net.LEVEL_WARNING_MSEC` (3 s) later, and the board says "Launching The island in 3 s…".
**Alone it gets a 500 ms local cue**, enough to fade rather than cut without imposing the three-second multiplayer
warning. `change_level` itself is unchanged and immediate -- it is the handshake and retains the force-black fallback;
the user path calls `call_the_level` and therefore always animates.

**A notice is a KIND and its facts, never a sentence.** `{kind: level, level, hash, in}`, `{kind: joined | left, player}`,
or `{kind: sky, time, clouds}`, on
`notice` / `notice_heard` with a count, said again every 200 ms until heard -- the `sky` messages' shape exactly
("The host's sky", under THE TIME OF DAY). Each machine writes its own words (`Net.notice_words`), so nothing a host sends
is text another machine prints. `read_hello` drops a kind with no words, a level that is not a level id, a player
number outside 1 to 65535 or not a number, a count-down below nothing and a notice with no count; a count-down over the
warning is a magnitude and is CLAMPED to it, said. `in` is the time LEFT when that copy was said, so a copy said again
later says less and no two clocks have to agree. Only the latest notice is owed.

**Who joined is announced once a session, and only when sync has named the player** -- `Sim.client_of_peer`, the number
the CREW page prints. At admission it is still 0 (the host holds a joiner's packets until then), and "PLAYER 0 JOINED"
is a name nobody can find on any page. Held across level changes, which re-admit everybody and would otherwise announce
every player again on every launch. The joiner reads "YOU JOINED AS PLAYER n". **Who left** is said from
`_on_peer_gone`, and only for somebody who was announced.

**Where it shows: the board and the flat status line, not the HUD.** The HUD is off by default, so a notice there is
one nobody sees. The board's line is furniture, above the code and on every tab, hidden when there is none; the fit
check carries it in the worst case (the longest level name in a count-down, with the debrief and the code), where BUILD's
scrolling area is 609 px against 655 without it and every tab not in `MAY_SCROLL` still fits. The first line of the flat
status is what makes it testable without a headset (rule 0), and what `NOTICE_DRAWN` prints for a harness.

**The gate** (`tests/notices.gd`, this process hosting the lobby, joiners as children): alone, the island gets a 500 ms
cue and is black before replacement; with a joiner, both draw who joined ("PLAYER 2 JOINED" / "YOU JOINED AS PLAYER
2"), the press leaves the level on the lobby with 3000 ms called, and the joiner's log has the warning, cue and fully
black curtain before `NET_LEVEL_CHANGING`, then reveal after its build. A second peer starts 200 ms into the countdown
and proves the same order over a delayed carrier;
then it presses MAIN MENU on the island (`--leave-in`) and the host draws "PLAYER 2 LEFT". It passed first time, so:

| Mutant | Red on |
|---|---|
| the solo cue is removed | `alone_the_launch_gets_only_the_short_fade_cue`, `and_it_was_black_before_the_scene_changed` |
| `call_the_level` changes at once | `with_somebody_to_tell_the_press_does_not_change_the_level`, `and_the_host_changes_it_after_the_warning`, `the_joiner_drew_the_warning_in_the_lobby_before_its_level_changed` |
| nobody is told who left | `when_the_joiner_leaves_through_main_menu_the_host_draws_who_left` |
| the change waits until every peer has answered | `and_the_host_leaves_at_the_warning_all_the_same` -- a killed joiner held the host 42,093 ms, until ENet timed it out |

**THE COUNT-DOWN WAITS ON NOBODY, and a crashed joiner cannot hold the session.** `due` is fixed at the press and the
change is made when it passes, heard or not. Section 5 kills a joiner outright (ENet goes on counting it) and calls the
lobby: 3122 ms, against the 3000 ms warning plus a 2000 ms grace. **The grace is the host's own reload, not a wait:**
the suite once read "island after 3727 ms", and timestamping it showed `level_changing` firing 3003 ms after the press,
with the deferred reload of `sky.tscn` taking 564 to 832 ms of the same frame before the suite could look (`Sim.stop`,
0 to 1 ms). A number over the warning is worth asking about -- it could as easily have been a change waiting on answers,
which is exactly the mutant above.

**The host's latest sky choice is a notice too** (2026-09-17). Time and cloud changes already travel as acknowledged
`sky` state; the separate notice carries the same bounded facts through the notice stream so every board says, for
example, `SKY: NIGHT, CLOUDS OFF`. Rapid changes replace the outstanding revision, so only the newest is shown and
resent. A sky change made during a called level transition still changes the world but cannot replace the active level
cue: the cue owns the notice surface until its countdown ends. `tests/sky_peers.gd` reads the line on the other process,
and `tests/transition_curtain.gd` holds the cue's notice and revision still while the sky changes.

### EVERYTHING WITHOUT A HEADSET: tests/no_vr_flight.gd

> "Please make sure we have a way to (without vr) start up the game, join the lobby and start a island level, change
> seats and planes that way we can test this without VR which is a requirement for this coding agent, since it can't
> use a vr headset." -- the user, 2026-09-15

One suite walks the whole flow on two machines with no headset anywhere near it, and it is the acceptance gate for the
lobby work. This machine is the JOINER, which is the user's own order of events; the host is a child started with
`--host=PORT --launch=island --report=1`.

| Step | How it is pressed | Measured |
|---|---|---|
| Start the game and host | `--host` through `world/boot.gd` to `Net.host`, nothing chosen | the host reports `level=lobby pilots=1` |
| Join the lobby | the address typed into the real `LineEdit`, the real Join button pressed | this machine is in the host's briefing room, standing on a segway |
| Both there | each machine's own manifest | `crew=segway:1/segway:2` on both |
| The host starts the island | the real `Button` on the briefing room's launch board (`--launch=`) | `LAUNCHING island from the briefing room` |
| The client follows | nothing pressed on this machine at all | `level=island clients=2 pilots=2` on both, `crew=pod:1.-.-.-/pod:2.-.-.-` |
| Change seat | F, through `Input.parse_input_event` | seat 0 -> 1, the same craft |
| Change craft | G | craft 4294967382 -> 4294967395 |
| Change planes | H | a pod -> a plane |

`tests/level_change_shot.gd` is the picture of it, and the sequence is the point: the SAME client, on one socket, before,
during and after its host pressed a level -- briefing room, the persistent curtain fully black, then the island, with
nothing pressed on that machine in between.

**A DESK PRESSED TOO EARLY ANNOUNCES TO NOBODY.** `DeskRoom._ready` builds its three screens, waits a frame, and only
THEN connects `_menu.chose` to `_on_chose`. A suite that waits for the PANEL and presses at once emits into a signal
with no listener, and what it sees is a desk that was pressed and did nothing: "scene Desk, in session false, transport
none" after a Join (2026-09-15, the windowed probe; headless it had been passing on timing luck). Wait for
`desk.get("_menu")`, which is set after the connect.

**RED by mutation** (2026-09-15): with `Net.level_changing.connect(_on_the_level_changed)` commented out of
`world/sky.gd`, the host launched and this machine stayed in the briefing room -- "level lobby, room BriefingRoom,
seated true, in session true". Every step after it is skipped, which is what a gate that stops at the first broken link
should do.

**What it does NOT prove, said plainly: anything about a headset.** The same controls exist in one -- the launch board
goes to `pointer_panels`, which is what the hand beam points at, and F, G and H are buttons on the input frame that a
headset's controllers set through their own bindings -- but this suite presses the desk's half, because the desk's half
is the half a machine with no headset can press.

### A JOINER IS TOLD THE LEVEL BEFORE IT SIMULATES ANYTHING, AND THE HOST WAITS FOR IT

Static collision is not replicated: every machine builds a level's ground from its own files. So a joiner on another
level predicts itself through ground the server does not have, and before 2026-09-15 nothing told a joiner anything.
Peers agreed on a world only by running one build, which is what cockpit-terrain measured and made a boot refusal of.

**The hello: messages on the carriers sync's packets already ride.** They are UTF-8 JSON, told apart from sync's by a
bit count below zero (`Net.HELLO_BITS`). Sync never sends a packet of no bits, and no byte value inside a sync packet
could be reserved instead, because its first bits are data.

| who | says | when |
|---|---|---|
| joiner to host | `{"say": "hi", "protocol", "commit", "line"}` | its first word, again every 200 ms until answered (see the handshake below) |
| host to joiner | `{"say": "level", "protocol", "level", "hash", "name"}` | once the hi has passed, again every 200 ms until answered |
| joiner to host | `{"say": "loaded", "protocol", "level", "hash", "ground"}` | its world built, again every 200 ms until admitted |
| host to joiner | `{"say": "admitted"}` | to every "loaded", however often it comes |
| host to joiner | `{"say": "refused", "code", "why", "host", "client"}` | every refusal; said every 200 ms until the joiner goes, closed at 3 s |
| joiner to host | `{"say": "refused", "why"}` | once, on the way out |

- **A joiner connected is not in the session.** `Net` waits in the stage "hello", with its own ten-second deadline ("Connected
  to X, but the host said nothing for 10 s ..."), until the host names a level it has with the same hash.
- **Otherwise it is refused in words**, on the desk or as BOOT_ERROR:
  - "The host is flying Good B, a level this game does not have.";
  - "The host's copy of The island is not the same as yours.";
  - "Can't join: the host speaks network protocol 27 and you're running dev · 2b8ea870 · 2026-09-18 (protocol 28). Yours
    is the newer build: the host needs to update." (an older host; a newer one refuses the hi itself, see the
    handshake below. Since protocol 37 the sentence says who is behind, from the two protocol numbers);
  - "The ground under your Alpine is not the host's: the two builds make it differently.".
- **The host holds back every sync packet from a peer until that peer is admitted.** `Sim._on_packet` asks `Net.admits`
  and counts the rest in `Net.held_back`. Sync never makes, seats or simulates a joiner still building its world, so a
  slow ground cannot put a joiner in the air before it has anywhere to stand.
- **Lost and slow are both ordinary** (team-lead, 2026-09-15). A Steam session's carrier is unreliable and a ground takes
  seconds to stand, so everything that needs an answer is said again until it has one.
- **"ground" is the hash of the height fields a joiner's worlds stand on**, Box3D's own over every field and the same on
  both editors (cockpit-terrain); "" on the island. A level file cannot say that the function making its ground changed
  under one build, and this does. A generator version in `GroundField`, hashed with the file, is a DLL change left for
  the C++ queue.
- **What a peer sends is untrusted (rule 8).** `Net.read_hello` drops, with a warning, anything over 512 bytes, not a
  JSON object, saying nothing a hello says, or with a field of the wrong shape, and cuts a refusal's reason to 160
  letters. Only the keys a message has are kept.
- **A bit count below one is Net's, and nothing else may send one.** `Net.send_to` and `send_to_server`, sync's two ways
  out, refuse a count below one with an error. `tests/lint.gd`'s `and_only_the_packet_transport_sends_a_bit_count_below_one`
  fails any script but `autoload/net.gd` that names the hello's bit count, reaches the carriers past those two, or hands
  a send a negative count. Its first run caught its own regex spelling the name.
- **Steam writes the level on the lobby too**, as `level` and `level_hash`. A search result carries them, so a code join
  is refused before it enters, in the same words; the hello says it again inside, however a joiner came.
- Rejected:
  - a third Godot RPC, which lint refuses and which would be a second ordering model beside sync's;
  - sync's connect token, which travels joiner to host only, so a joiner could not learn a level before building one,
    and a refusal would need C++;
  - the lobby's data alone, which ENet does not have.

**Long documents share those two carriers without becoming large hellos (2026-09-16).** `Net.send_long(peer, kind,
bytes, stale_msec)` queues `layout` (at most 64 KiB / 15 s) or `clip` (host-only, at most 8 KiB / 3 s). `LONG_BITS =
-2` selects a compact binary envelope with at most 384 payload bytes; it always rides `_receive_unordered`, even on
ENet, because `unreliable_ordered` discards an older retry after a newer chunk. This adds no RPC and keeps lint's two
carrier boundary intact.

`LongTransfer` admits one active transfer per peer, sends one chunk per peer per deferred pump, uses a four-chunk
selective-repeat window, coalesces acknowledgements to 50 ms, and retries at 200 ms with capped exponential backoff.
The sender is capped at 12 KiB/s per peer and 48 KiB/s in total, with round-robin peer order under that host cap. A receiver validates the complete header, entitlement,
64 KiB cap, chunk arithmetic and lifetime before reserving bytes; completion also requires CRC32, the built-in kind
shape, and any semantic validator installed with `Net.set_long_validator`. Completion releases the payload reservation
immediately while retaining only an acknowledgement tombstone until the original expiry, so a lost final ACK cannot
deliver a document twice. Disconnect, replacement, expiry, level/session reset, malformed input and a bad CRC release
the reservation. Transfer ids are not reused during a process.

`Net.long_paused_for_peer` is the explicit sync-priority seam. It defaults to false; item 10's measured load path may
install a per-peer predicate when it has an actual loss/rollback signal. `traffic_sent` and `traffic_received` account
`sync`, `hello` and `long` separately. `tests/long_message.gd` drives two engines through a packet list: a 64 KiB layout
under loss/reordering/duplication in 8.2 s, an 8 KiB clip in 1.03 s, only-missing retry, duplicate-final delivery once,
pause, exact peer/host ceilings and every allocation cleanup/refusal path.

`tests/level_hello.gd` (38 checks) is one process:
- the validator against thirteen malformed hellos;
- the refusal words;
- a joiner connected over a real loopback socket to a bare host: not in the session until told, saying "loaded" until
  admitted, and leaving in the host's words;
- the host's gate: a peer that has not loaded, one that loaded another level, one on other ground (refused and told),
  and one on this level and ground (admitted, and answered again when it asks again).

`tests/level_join.gd` is two real processes on ports 47953-47959:
- **the same level**, with the joiner told to build slowly (`--load-slowly=2`, standing in for the alpine ground's four
  seconds): both machines at two clients and two pilots in 3.4 s, the host's NET_ADMITTED after the joiner's NET_LOADED
  with packets held, and no host report naming the joiner before it;
- **another copy of the island** (`--levels-from=res://tests/level_fixtures_other` on the joiner): refused in those words
  in 2.3 s, never let in;
- **a level the joiner does not have** (the host on a fixture's `good_b`): refused in 2.4 s, never let in.

Mutants, each restored and proved restored by SHA-256:

| broken on purpose | what failed |
|---|---|
| the handshake skipped: a joiner in the session on connecting, and the host taking every packet | level_join 6: nothing said loaded or let in, a host report naming the joiner before, and both joiners that should have been refused flying (the other copy, the level it did not have); level_hello 6, from `a_joiner_connected_is_not_yet_in_the_session` to the host's gate |
| the host admitting every peer | level_join 4: no packet held, and the joiner's client and pilot in the host's reports before it was built; level_hello 3 |
| the ground hash not checked | level_hello: a peer on other ground admitted |
| the level not written on a Steam lobby | steam_join: `written_on_the_lobby_with_the_game_the_build_who_hosts_and_the_level` |

**A session that ends against the player's will takes them back to the desk, which says why (2026-09-15).** Nothing in
the world listened when a session ended: a joiner whose host left, or who was refused after it had loaded, sat in a
world with no simulation and a line of text. `Net.parting_words` is set by a refusal and by the host leaving ("Host
left"), and by nothing the player chose -- MAIN MENU, Quit and every suite leave with none. `FlightLevel` takes
`Doors.to_the_desk` when a session ends with parting words, and the desk says them once and forgets them. A level
whose edge will not fit (see the world's edge) leaves the same way.
- `tests/levels.gd` drives both through a bare host on the loopback and a real world. A joiner told a level it has flies it; refused there ("The ground under your Good A is not the host's: the two builds make it differently.") it is taken back to the desk, the desk says those words, and they are gone after. A joiner whose host drops its peer while it flies is taken back to the desk, which says "Host left".
- Mutants, each restored and proved by SHA-256: the world not taking the door, 5 checks red, both joiners left in the world; the desk not saying the words, 2 red, the desk reading "Not in a session."; the host leaving not parting, 2 red, that joiner left in the world.

The desk's levels screen, the desk from the chair, the clipboard's LEVEL line and a refused join are photographed by
`tests/level_shot.gd` (`godotgames-drafts/2026-09-15/cockpit-levels/`, and the three-screen desk in `cockpit-menu/`).

### THE WORLD HAS A SOFT EDGE: A PILOT IS WARNED, THEN TURNED BACK, THE SAME ON EVERY MACHINE

Asked for on 2026-09-15: "the world edge gets a SOFT boundary: warn, then turn the craft back." Until then nothing held
a craft inside the wire's ±32,768 m. Past it the server flew a craft on while every other machine was sent it clamped at
the edge: a joined pilot flying +X was 1,032 m from the server after 10 s, with 18 to 24 rollbacks a second and about
190 wire clamps a second (cockpit-terrain's probe, 2026-09-14).

**The turn-back is in the simulation's shared step, on every world alike** (`CockpitWorld.set_boundary`, told with the
geometry like the wind). In `drive_vehicle`, after a human's or an autopilot's controls have become one demand and before
the movement model, a flown craft past the band's start has its controls blended toward a turn home. The blend grows
over the band's depth, and is weighted by how far the craft points away from the middle, so one already heading home is
handed back its pilot.
- An aeroplane or a tiltrotor banks toward home to its own autopilot's limit and holds its path level, with a pull for
  the bank.
- A helicopter or a pod yaws home with its wings levelled.
- A car steers home, and a boat or a ship puts its rudder over.

A client predicting its own aeroplane turns it back exactly as the server does. A push the server applied alone would be
a divergence every tick, which is what the mutant below shows.

**The band is worked out, not typed** (`WorldEdge`, team-lead's rule):
- it starts `CLEAR_OF_PLACES` (2 km) past `Terrain.placed_reach()`, so a pilot landing at an edge airfield is never
  turned away from it, and cockpit-pirate's brigs keep inside that same number;
- it is as deep as the widest turn any powered wing needs at its top speed and its own autopilot's bank limit
  (`CockpitWorld.turn_radii` and `worst_turn_radius`);
- a level whose band start plus two such turns would reach the last resort is refused, in words, when it is built, and
  leaves through the same door back to the desk as a refused joiner.

The widest turns, read from the simulation (`turn_radii`; top speed where full thrust meets drag, at each kind's own autopilot bank limit), and what they leave each level (2026-09-15, double editor):

| wing | top speed | bank | turn radius |
|---|---|---|---|
| hawkeye | 180.1 m/s | 51.6 degrees | 2,624 m, the widest |
| airliner | 109.5 m/s | 25.2 degrees | 2,598 m |
| osprey | 142.7 m/s | 40.1 degrees | 2,465 m |
| plane | 165.8 m/s | 51.6 degrees | 2,225 m |
| tanker | 102.2 m/s | 51.6 degrees | 844 m |
| gunship | 101.1 m/s | 51.6 degrees | 827 m |
| cessna | 67.1 m/s | 51.6 degrees | 364 m |

- The island: everything placed within 17,310 m, the band from 19,310 m, its start and two turns to 24,558 m against the last resort at 32,268 m. It fits by 7,711 m.
- Alpine: placed within 22,321 m, the band from 24,321 m, to 29,569 m. It fits by 2,700 m, and the widest turn it could take is 3,973 m.
- **`tests/terrain_level.gd`'s `every_level_fits_the_widest_turn` builds both real levels' bands** and prints these margins; no
  other suite does, so a wing whose top speed or bank widened the turn past a level's allowance would refuse that level only
  when somebody loaded it. The E-2D's real 180 m/s at the default bank made it 26 m deeper (cockpit-fleet, 2026-09-15); an
  airliner-like 0.44 rad Hawkeye case is a 7,023 m turn and refuses both levels: measured with it built in, the island by
  1,087 m and alpine by 6,098 m.

**A last resort at the wire's edge:** within 500 m of it on an axis, a body moving outward loses that part of its
velocity, on every world, and it is counted (`edge_guards`). It is for a craft nobody flies, or a band a level sized
wrongly, and it should never act on a craft the turn-back has hold of.

**The pilot is warned first.** The HUD's note leads with "WORLD EDGE IN 1.5 KM · TURN BACK" from `WARN_SECONDS` of the
fastest wing's top speed before the band, and "WORLD EDGE · TURNING YOU BACK" inside it.

`tests/world_edge.gd`, each powered wing flown out by its own pilot on a client beside its server:

Each pilot flies straight out at top speed, holding 1,500 m with wings level, from a kilometre short of a band starting at 18,000 m and 2,624 m deep. It is held to team-lead's rule, the band's depth plus the widest turn (5,248 m). Each wing is also measured flying the same bank for as long far inside, since a predicted craft in a turn is drawn off the server's path by its lead.

| wing | past the start | clamps | guards | client off the server's path: out, the same turn inside | rollbacks in 150 s: out, inside |
|---|---|---|---|---|---|
| plane | 2,577 m | 0 | 0 | 5.57 m, 5.56 m | 108, 144 |
| airliner | 2,944 m | 0 | 0 | 3.79, 3.76 | 129, 134 |
| osprey | 2,240 m | 0 | 0 | 4.96, 4.93 | 130, 142 |
| cessna | 1,536 m | 0 | 0 | 2.28, 2.26 | 102, 87 |
| gunship | 2,434 m | 0 | 0 | 3.52, 3.42 | 98, 78 |
| tanker | 2,440 m | 0 | 0 | 3.72, 3.65 | 106, 118 |
| hawkeye | 3,913 m | 0 | 0 | 6.69, 6.76 | 151, 147 |

Every wing came back inside the band's start after its furthest point out, and the client drew its own craft on the server's path to within 0.1 m of how it draws the same turn far inside.
- **Back inside after the furthest point, not inside at the end.** The turn-back lets go sixty degrees off home, and a
  craft with its wings levelled runs back along the edge, so whether the 150th second finds it in or out is a coin. With
  the band 26 m deeper for the Hawkeye, the plane ended 32 m past the start and the Hawkeye 1,858 m past it, each having
  been back to 12,477 and 13,326 m; flown 300 s instead, the airliner, gunship and tanker ended out (cockpit-fleet).
- **A submarine at its 8 m/s,** its autopilot sent to waypoints past the edge, is held 761 m inside a 2,624 m band by its
  rudder with no guard. A boat still steering for a waypoint outside settles where the turn-back's weight, which grows with
  depth, outweighs its autopilot; it does not come home, and the check asks only that it stays inside the band.

- **An autopilot** sent past the edge, its waypoints beyond it, turned back 1,815 m past the start with no guard.
- **A brig on a steady 8 m/s** made way and came back without the last resort, slowly. With the middle dead upwind, one sailed 776 m, got 567 m past the start and ended 458 m past it with 2.0 m/s of way. With the wind across, one got 574 m past and ended 377 m past. A world told no weather has still air, and the suite's first brig sailed on none: it coasted to a stop and passed for nothing.
- **A pod nobody flies,** drifting at 60 m/s, was stopped at 32,268.0 m by the last resort, with 1 guard and 0 clamps.
- The suite's first two runs were red for its own reasons, each written in its header:
  - a pilot with the stick let go sank heavy wings through the empty world's floor, making 6,584 to 8,994 clamps that were nothing to do with the edge;
  - a check that a craft ends heading home failed for fast wings that crossed the middle;
  - a path bound was typed before it was measured.

**The boundary on the server alone** (a mutant: the turn-back returns early on every world that is not the server, the double library built from it, and the source and the committed library restored and proved by SHA-256): every wing went red on its rollbacks, 1,617 to 2,297 in 150 s against 78 to 144 for the same turn far inside, 11 to 29 times as many. The drawn path did not go red: each rollback put the client's craft back on the server's path, so a turn-back one world does and the other does not shows as rollbacks every few ticks, not as a gap on screen.

### WHICH BUILD, BEFORE WHICH LEVEL: THE HANDSHAKE, ITS REFUSALS AND THE LOG TAB (lane/handshake, 2026-09-18)

The user, the day the game got release builds: "we need to reject connections from clients that are not running the
same version ... It should INCLUDE the version number of the server and client in the message. It's REALLY important
that a client (and the server) know why they can't play together. There should be a server log message that explains
why a user couldn't connect (we need a server log panel in the ipad). and the client MUST know why (if possible), it
couldn't connect."

- **A joiner's first word is `hi`: `{protocol, commit, line}`**, from `Net.identity()`, which is `BuildPlate` unless a
  suite pretends otherwise. The host names the level only once the hi passes. **So a refused joiner builds nothing, is
  told nothing about the session, and never reaches `admits`.** `_heard_loaded` does not answer a peer that was never
  put in `_telling`, so skipping the hi gets nobody in.
- **THE RULE: the same PROTOCOL and the same full COMMIT.** A release's version and name label the commit it was
  exported from. So two releases of one version from different commits are refused, a dev run meets a dev run only on
  the same commit, and a release meets a dev run of the same commit (the same code; team-lead ruled it admitted).
  `unknown` matches nothing. The LINE is shown and never compared. **Not
  covered:** a dev run from a modified tree has the same commit and different code, and there is no `+dirty`. See the
  learnings' What's next.
- **NO C++ WAS NEEDED, and the reason is worth knowing: the gate was already in GDScript.** `Sim._on_packet` hands a
  peer's sync packets to the server only once `Net.admits` says so, and counts the rest in `held_back`. Until then sync
  never learns the peer exists, so the version check could go in front of the level hello, over the existing carriers.
- **Every refusal is `{"say": "refused", code, why, host, client}`, and every `why` names both builds**, from
  `Net.refusal_words`:

  | code | when | words, abridged |
  |---|---|---|
  | `wrong_version` | another commit, or `unknown` | "Can't join: this game is H, and you're running C. Yours is 3 days older than the host's: update yours." |
  | `wrong_protocol` | another protocol | "... speaks network protocol 37 (H), and yours speaks 36 (C). Yours is the older build: update yours." |
  | `full` | counted after the hi: telling + admitted + the host | "Can't join: the session is full (2 of 2 players). This game is H; you're running C." |
  | `bad_hello` | a hello from a peer at the door that `read_hello` drops | "... your game's hello could not be read (a hello of 688 bytes, over 512) ..." |
  | `no_hello` | 5 s (`HI_WAIT_MSEC`) connected and silent: a build before protocol 28 | "... never said which build it is, so it is older than this one (H). Update yours." |
  | `wrong_level`, `wrong_ground` | the old `loaded` checks | their old sentence, then both builds |
  | `host_closed` | the host leaving with people connected | "The host closed the game (H)." |

  An older client reads only `why`, so it still gets the reason. A new client meeting an older host is refused by the
  level hello's protocol, in `Net.host_protocol_words`: the host's line is not known, so that sentence has only this
  build's line.
- **WHO NEEDS TO UPDATE (protocol 37, lane/buildtime, 2026-09-19).** A player asked for the date in the build id "so you
  can say who needs to update". The hi carries `built`, `BuildPlate.time()` in epoch seconds UTC (see "Which build is
  this"). **It decides nothing**: the rule above is the rule. `Net.update_words` ends both build refusals with who is
  behind: "Yours is 3 days older than the host's: update yours.", "Yours is 5 hours newer than the host's: the host
  needs to update.", or, with a time unknown, from the protocols ("Yours is the older build"). The words round DOWN to
  the largest whole unit (`BuildPlate.how_long`), and builds under a minute apart are the same age.
  - **An older joiner is refused cleanly.** `built` is optional in `_read_hi`, so a protocol-36 hi (no `built`) is
    refused `wrong_protocol` and told it is the older build, not `bad_hello`. Required, the mutant turned that joiner
    into a hello "that could not be read".
  - **A joiner let in is told how far apart the two builds are**, when they are: the level hello carries the host's
    `built`, and the "Connected. Flying X." line adds "Your build is 2 days newer than the host's." That is one commit
    built twice, such as a release beside a dev run of it. The host's GREETED row says `build="theirs is 2 days newer
    than this one"`.
  - **The CREW page draws one amber line per player on a build of another age**, "ALICE · BUILD 2 DAYS OLDER THAN
    YOURS", against this machine's own build, on every machine. It reads the ROSTER, whose cards carry each player's
    `built` as a fourth field. The HOST writes it from that player's hi, never from the card the player proposes, so a
    player cannot make themselves look up to date.
  - `--pretend-built=<epoch>` or `none` moves a suite process's time. `tests/handshake_peers.gd` runs an older, a
    newer, a protocol-36 and a same-commit-later joiner against one host. **Its trap:** two refusals are now
    `wrong_version`, and a check that took the first such row on the host read the newer build's row in two runs of
    four. Find a row by the build it names.
- **A refusal is said until the joiner goes, then closed: never the other way round.** The carriers are unordered (ENet)
  and unreliable (Steam), and lint allows no third RPC, so the host repeats the refusal every 200 ms. The joiner leaves
  the moment it hears one, and its going is the acknowledgement; the host closes the peer after `SENDING_AWAY_MSEC`
  (3 s) only if it is still there. It used to be said once, with a flat 500 ms: a lost packet read as "Host left". A host
  that quits sends `host_closed` to everyone and calls `poll()` before `close()`, because close drops ENet's queue.
- **Every way in ends in words, and Net says them.** `join()` has its own deadline (`PATIENCE["connect"]`, 10 s) and
  `too_long` / `connect_words` say where and how long: "No answer from 127.0.0.1:7788 after 10 s: the host may be down,
  the address wrong, or a firewall in the way." Steam has its own form. The hello stage says "Connected to X, but the
  host said nothing for 10 s". A host that vanishes without a refusal: "Lost the host at X without a reason: it may have
  crashed or quit, or the network dropped." **The desk and boot keep no deadline of their own.** The desk's ten seconds
  raced Net's and said "Nothing is listening there" over the real reason. They wait for `transport == "none"` and show
  what Net said.
- **`Net.logbook` (`net/logbook.gd`, class `Logbook`) is the door's record**: a ring of 200 rows, each printed as one
  grep-able line, `NET_REFUSED side=host code=wrong_version peer=… who="127.0.0.1:64548" host="…" client="…" words="…"`.
  Host rows: CONNECTED, GREETED, JOINED (RELOADED after a level change), REFUSED, LEFT (with `was`), CLOSED. Client rows:
  CONNECTING, CONNECTED, REFUSED, TIMED_OUT, DROPPED, PARTED. Every string is cleaned (`Logbook.clean`: no control
  characters, no double quotes, cut) before it is printed or drawn (rule 8). A joiner's line is cut to `LINE_MOST` (64).
- **The LOG tab** (`ClipboardPage.Tab.LOG`, the eleventh, beside HELP, so the grid is still four rows) is handed
  `Net.logbook.rows()` by `PilotRig._heard_at_the_door` and draws them newest first. Each row is a head (time, event,
  code, who) and the words; refusals and timeouts are amber, joins pale. It draws at most `LOG_DRAWN` (60) rows and
  scrolls like HELP. The same listener puts a client's own ending (REFUSED, TIMED_OUT, DROPPED, PARTED) on the board's
  answer line in amber, the words the desk shows.
- **A suite pretends to be another build** with `--pretend-build=<commit>|<line>` and `--pretend-protocol=N` after the
  bare `--`. In-process it sets `Net._pretend` (`silent` = never say hi, an older build as the host sees one). Nothing
  else reads them.

Gates: `handshake_peers` (a host and five joiners over real sockets: same build, another release, another protocol, a hi
with no commit, a 688-byte hi; then in-process a silent joiner and a dead port), `desk_join` (another build and a dead port
through the real field and Join button, on the screen and the board), `handshake_log` (the LOG tab through its own tab
button, on a host flying the real level and on a joiner at the desk; with `--out=` and a window it saves the pictures),
and `players_peers` for `full`. Mutants, each red: the version check skipped, the peer closed before its refusal, the
words without the joiner's build, the rig not listening, `join()` with no deadline, and the LOG page drawing nothing.

## THE AIR IS NOT STILL

Wind, columns of rising air, and a glider with no engine to make either of them matter.

**Everything aerodynamic is measured against the AIR and everything else against the
GROUND**, which is one line in the frame setup and the whole feature. `Frame::velocity` is
where the vehicle is going; `along`, `sideways`, `vertical` and `speed` are what it is doing
through the air, and every wing, rotor, drag term and damping term in the file already used
those four. Navigation, formation-keeping and the climb rate were already using the other.

Measured: an aeroplane doing ten metres a second downwind in a ten-metre wind falls exactly
as fast as one parked in still air -- 38.6 m in three seconds, both -- because a uniform wind
is a change of reference frame and an aeroplane moving with the air cannot tell. The same
aeroplane with forty metres a second of airspeed falls 8.7 m. Two aeroplanes at one throttle,
one upwind and one down, hold the same airspeed to a tenth and cross the ground exactly twice
the wind apart.

**An aeroplane nobody is flying does not get blown sideways -- it weathercocks.** The fin
turns the nose into the relative wind within a second or two and it flies a crab from then
on, four degrees of it in a ten-metre crosswind. Drift over the ground is what a PILOT gets
by holding a heading against that, not what an aircraft does on its own. Finding that out
cost a failing test that asserted the opposite.

**Not a car, and not the pod.** A crosswind on a lorry is a model this game does not have,
and a headwind in a tyre's rolling resistance is not what a headwind does to a car. The pod
is the surprising exclusion: its drag is the damping that makes a thruster craft
controllable, not air resistance, and it cancels its own weight -- so with wind it drifted at
exactly the speed of the wind until it fetched up against a building. The pod is the craft
you spawn in and the one that forgives you. A wind that took it away while you read the panel
would undo that.

### A LIFT ZONE IS A PLACE, AND IT HAS A CORE

A column of rising air with a radius, a strength and a top, tapered to nothing at the edge
and fading out over the last 150 m of its height. Both tapers are what make it flyable: a
cylinder with hard walls is something you fall out of, and a hard ceiling is something you
hit. A core only exists because the edges are weaker, and CIRCLING TO STAY IN THE CORE is the
whole of what a glider pilot does.

**Built with the scenery, on every peer, and never replicated** -- the same rule the mountains
follow, and for the same reason: it never changes. `Terrain.lift_zones()` generates them FROM
the terrain features rather than scattering them independently, because the ground is what
makes a thermal: one over each city, one over each inland range, a scatter over the open
ground, and ridge lift standing on the WINDWARD face of the ring. There is nothing at all on
the lee side, which is where a glider gets sink.

**And a fire makes its own.** A fire is a column of hot air with a flame at the bottom of it,
so `rising_at` adds one per fire, scaled by how hard it is burning and as tall. That is the
two features meeting: the smoke column over a fire is the best-marked thermal in the world,
a glider can work one, and a water bomber has to fly its drop run through rising air.

### THE SKY IS THE MAP

Rising air is invisible, and a game where it is invisible is one where a glider pilot flies
in circles hoping. Real pilots read the sky, so every lift zone in the world grows a CUMULUS
on top of itself, at the top of the column and sized by it: a big cloud is a strong wide
thermal, a low flat one is the ridge, and clear sky between them is sink.

Three marks, each for a different distance. **The cloud**, from kilometres away, is what you
turn towards. **The wisps** climbing the column are what you aim at once being accurate
matters. **The ring** on the ground is what you circle over, and it is the only one of the
three you can see when you are inside the thermal looking down past your own wing.

The cloud is downwind of the ring, because the column leans as it climbs and the wind is
stronger higher up -- which is the first thing anybody learns about reading them.

**Three MultiMeshes for the whole sky.** Thirty-one zones drawn as nodes is five hundred
draw calls; as one batch per mark it is three, and the wisps animate by rewriting a transform
buffer rather than two hundred node transforms. The same answer the scenery already gives for
two hundred mountains.

### A GLIDER IS AN AEROPLANE WITH THE THRUST SET TO ZERO

Which is exactly why this file keeps a MODEL apart from a KIND: nothing about the forces on
it is different from the light aeroplane, and one number in the handling table is.

Six hundred kilograms under twenty metres of wing, a tenth of the light aeroplane's drag, and
the number the whole aircraft is: **it sinks 1.05 m/s** measured. So a three-metre thermal is
a two-metre climb, a 4 m/s one is 3.14 m/s better off than still air, and anything else means
one of the two numbers is wrong. It has airbrakes instead of flaps and no throttle at all.

**It is spawned PARKED, and the craft browser launches it.** An aeroplane with no engine
cannot be launched by giving it speed on the ground, and "taking a parked aeroplane launches
it" -- at flying speed, wings level, well clear of the ground -- is the winch this game
already had and did not know it.

Two seats, in tandem, and not four. A glider is a glider; a craft reporting four would have
two of them sitting in the tailplane.

### AND A VARIOMETER ON EVERY PANEL

Climb rate, signed, to a tenth, on the flight page of every craft in the game. It is the one
instrument a glider is flown by and it is worth having in anything: a helicopter in a hover
reads its own drift on it, and a water bomber pulling off a drop reads whether it is going to
clear the ridge.

### AND THE WORLD IS CLEARED WHEN IT IS REBUILT

`teardown` did not clear the static boxes, the waypoint pools or the lift zones, all of which
are pushed in by the game layer AFTER `start`. A session restarted in place came back with
two of everything: twice the scenery for every leg check to walk, twice the waypoints in
every pool, and twice the lift in every thermal -- a world that flies differently after a
restart than it did before one.

### WHAT IS NOT HERE

**The wind a wing feels never changes.** It said "the wind never changes" and that a gust would
have to go on the wire. Neither holds now: the wind is a `WindField`, a function of the frame and
a seed (see "A SHIP UNDER SAIL"), so it wanders and is the same on every peer with nothing sent.
The level gives the aircraft still air, as it has since 4e76324.

**There is no sink between the thermals.** Real air that goes up somewhere comes down
somewhere else, and a day of strong thermals is a day of strong sink in between them. Adding
it is one more term in `rising_at` and a decision about how much punishment a crossing should
carry.

### THE KIND FIELD IS FULL

`VehicleKind` WAS four bits, sixteen kinds, sixteen used -- and this section said the
seventeenth vehicle would be a wire format change rather than a table entry. It was, and the
water bomber is it: five bits now, thirty-two kinds of room, and the sentinel beside it moved
with it. See "the seventeenth kind cost a bit" above for the half of that which was not
obvious in advance.

`kMaxTurrets` went from two to three for the gunship's third gunner, which is eleven bits on
a Step component that is only sent when somebody moves a gun.

### WHAT IS NOT HERE

**Nothing takes damage.** The impact record says what was hit -- ground, water, armour --
and nothing reads it but the explosion. Health is new replicated state, destruction needs a
wreck and a respawn rule, and the AI would have to react to being shot at; all of that is a
position of its own and this one is about the gun.

**The gunship's autopilot does not fly the orbit.** An unmanned one flies its waypoints like
any other aeroplane, and the pylon turn is something a player does. That is the next thing to
build, and it is the one that makes an unmanned gunship worth watching.
