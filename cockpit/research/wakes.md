# Wakes and low-pass spray

Asked for on 2026-09-17: moving boats and ships leave a noticeable wake, "shaded marks" and churned water that is
"lighter and white", drawn as a shader and built like the contrails; and an aircraft within 3 m of the water at more than
80 km/h "kicks up" dramatic whitewater. The reference image is a Porco Rosso seaplane skimming the sea. Neither has any
physics effect. The tanker does both. This note records what a real wake is made of, what was built and what was
rejected. The code is `WakeTuning`, `WakeYard`, `SprayYard`, `wake.gdshader`, `wake_bow.gdshader`, `spray.gdshader`
and `sea_surface.gdshaderinc`.

## What a real wake is

- **The Kelvin wedge.** A body moving over deep water leaves a V of waves whose arms stand at **19.47 degrees**
  (arcsin 1/3) either side of the track. The angle does not depend on speed or size, because in deep water the group
  velocity is half the phase velocity (Kelvin, 1887; Wikipedia, "Kelvin wake pattern").
- **Two families of waves.** *Divergent* waves form the arms, travelling about 35.26 degrees off the track, and are seen
  as an echelon of short crests along each arm. *Transverse* waves are curved arcs across the inside of the V, spaced by
  the wavelength a wave travelling at the ship's speed must have, lambda = 2 pi v^2 / g. That is 73 m at 10.7 m/s (the
  carrier) and 92 m at 12 m/s (the launch).
- **High Froude numbers narrow the V.** A small fast hull puts its energy into shorter waves, and the apparent wedge
  closes up (Rabaud and Moisy, 2013). Here that is why a divergent crest is never drawn longer than half the hull.
- **The turbulent wake.** Directly astern, the propellers and the hull's boundary layer churn the water white. The churn
  is about as wide as the hull at the stern and spreads slowly. It is solid foam near the stern, breaks up into lace and
  streaks, and leaves a smoothed "slick" that outlasts the foam. On radar it is the dark centreline of a ship's wake.
- **The bow wave.** White water piles up at the stem and is thrown out along the sides, and it builds again at the stern
  quarter.
- **A seaplane's spray.** A planing hull throws a fountain off its step, called the roach or rooster tail, and it
  lengthens with speed until lift-off. Low over the water, prop wash and downwash tear sheets of spray off the surface.

## How games draw them

- A wake mask or foam simulation rendered around the camera and read by the ocean shader. Crest and Sundog Triton work
  this way. Triton also displaces the ocean with 3D Kelvin waves and adds particle bow spray.
- A decal or ribbon trail behind the ship, textured with foam and aged over time. This is the common game approach.
- Particles for bow spray and rooster tails, drawn after the water.

## What was built

**Wakes: a contrail laid on the sea.** `WakeYard` lays a piece of wake behind each stern every 0.5 s into one MultiMesh.
The GPU widens and fades each piece from its own age, on `MissileYard`'s clock, exactly as `ContrailYard` does. The
newest piece is rewritten every frame so it reaches the stern. A second MultiMesh holds one quad under each moving hull
for the bow wave. That is **two draw calls for every wake in the sky**, and the processor's only per-frame work is two
instance writes per moving hull.

The wake shader draws four things:

- the churn: a boil that turns to lace, then a slick;
- the Kelvin arms at (hull length + distance run) x tan 19.47 degrees, measured from the STEM so the bow quad hands over
  cleanly, drawn as lighter crests and darker troughs;
- faint transverse arcs;
- band-limiting, so a far wake is a soft V rather than a moire.

Every look number is one constant in `WakeTuning`.

**It lies on the water the sea is drawn with.** `sea_surface.gdshaderinc` repeats the ocean shaders' vertex sums under
the same uniform names: the simulation's standing swell, the wind-sea the boats feel, and on FINE the chop's height.
`SeaSwell.hand_the_swell` hands the wake's material its swell just as it hands the seas theirs. Everything fades to still
water inside the coast band, which is where the lakes are. The still-water height comes from `Terrain.water_height`, so
a lake's level is used on a lake. The wake is drawn `WAKE_LIFT` over the water and `WAKE_PULL` toward the eye, so it
never fights the sea for depth.

**Spray: puffs thrown once, flown by the GPU.** `SprayYard` writes each puff once: where it left the water, when, and
its velocity. `spray.gdshader` flies it: slowed by the air, pulled down by gravity, grown into mist, drawn out along its
flight while young, and faded per pixel where it meets the water. That is **one draw call**.

**The rules go by position, never by kind** (`WakeTuning.wake_strength`, `spray_strength`):

- A craft wakes when the bottom of its hull box is within `WAKE_TOUCH` of the water, its top is not deep under it, and
  it is moving.
- A craft sprays when its lowest point is within `SPRAY_HEIGHT` of the water and it is faster than `SPRAY_SPEED`. The
  lowest point is one of the four bottom corners of its hull box or a wingtip, after its attitude.
- A craft that sprays also draws a streak of churn on the water under it, with no Kelvin waves.

So the tanker wakes afloat and sprays skimming without being named anywhere, and a new flying boat gets both for free.

## Rejected

- **A foam mask around the eye, read by both ocean shaders.** This is the best picture close to, because the wake is IN
  the water: no lift, no pull, no sorting. It costs a second camera pass every frame, and both ocean shaders (owned by
  other lanes, and gold on the carrier) would need editing. Worth doing if the ribbon's lift ever shows. It is the
  natural next step.
- **Displacing the sea with real Kelvin waves.** The simulation floats no hull on them, and must not, or a replayed tick
  would meet a different sea. So a wave drawn over a deck the simulation keeps dry would swamp it on screen, which is
  exactly what `ocean_fine.gdshader`'s `swell_steepness` note warns about.
- **Particles for the churn.** They cannot lie flat on a swell, and a kilometre of carrier wake would be thousands of
  sprites.
- **GPUParticles3D for the spray.** Each emitter is one draw call and one process pass per aircraft, and its particles
  sit in world space in float32. On the double build that steps anything far from the origin onto float32's grid
  (`billboard.gdshaderinc`). The MultiMesh puffs place themselves through `MODELVIEW_MATRIX` as every billboard here
  does.
- **Squaring each wake piece to its own chord.** On a turn, neighbouring pieces fanned apart. At the carrier's 117 m arms,
  half a degree between pieces was a metre of gap on one side and a metre of double-drawn overlap on the other, and the
  wedge read as a venetian blind (pictures, round 1). Each piece now carries the across direction at both of its ends,
  and neighbours share one.
- **A roster of kinds that wake or spray.** It would miss the tanker and the Savoia, and `tests/wakes.gd` has a mutant for
  it.

## What it costs (measured 2026-09-18)

Measured in a measurement slot held with `GPU_SLOT_HOLD`, with `wake_shot --views=cost`, on the double editor, Mobile,
D3D12, RTX 5080, at 1600x900. The watch level's own ships were topped up to 20 under way (14 launches added), with 5
light aeroplanes skimming 1.5 m over the sea at 45 m/s among them: 101 vehicles.

| | Cost |
|---|---|
| Draw calls added | **3** for every wake and every spray in the sky: the wake trail, the bow waves and the spray |
| Primitives added | 31,458, with 351 wake pieces laid |
| CPU, `wakes` lap | **0.100 ms** a frame, median of 120 |
| CPU, `spray` lap | **0.056 ms** a frame, median of 120 |
| GPU | **0.001 to 0.002 ms**: the viewport's GPU time with both yards shown, less both hidden, frozen so every round draws the same pieces, three interleaved rounds (0.430/0.428, 0.429/0.428, 0.429/0.428 ms) |

Nothing else was drawing: nvidia-smi showed only the desktop's standing apps at the start and the end. Two headless
imports from other checkouts were running on the CPU (main's and `lane/tomcat`'s), so the CPU laps are, if anything,
high. Before the look-ten-times-a-second change (dcd4d2b1) the same scene's laps were 0.18 and 0.17 ms, unofficial.
The lakes are one more draw call on the alpine world, 44,629 vertices.

## Spray, round 2: the wall (2026-09-18)

Asked for with a Porco Rosso still: the Savoia skimming at speed, and behind it ONE SOLID CURTAIN of white spray
several times its height. Its face is flat, bright and near white, its top edge crisp and scalloped in cartoon-cloud
lobes, its base and the lower side of each lobe pale blue, with small ragged holes. It reads as one shaped, cel-lit
sheet, not as particles and not as mist. Slow on the water keeps only the wake.

**How stylised games do it.** The pattern is the same everywhere a splash has to read as a shape: **geometry for the
body, a noise-eroded alpha for the edge, and particles only for detail.** Trifox's splash is cone meshes scaled up
and out, with panning textures whose lower half is empty to fake the water growing. It is dissolved by Perlin noise
with a vertex-colour gradient, so the middle goes first, and has foam billboards and drops on top. Their reason is
the one that applies here: large simple shapes read as impact, and high-frequency detail reads as noise. Toon water
shaders band their colour by the normal against a light, in two or three flat steps.

**What was built.** `SprayYard` lays a strip of pieces along the track where the craft meets the water, each one
MultiMesh instance written once when laid, with the newest stretched to the hull every frame. `spray_sheet.gdshader`
raises each piece from its age: it rises over `SHEET_RISE`, opens with `SHEET_SPREAD` and dissolves in its last
`SHEET_DISSOLVE`. It works in world metres along and up the sheet, so the lobes are fixed to the water they were
thrown from and the wall is the same shape for each eye. Across the track the strip is a V (`STEEP` 0.6: a wall that
stands up, then leans out). The top edge is a row of circles, and a lower row of billows is drawn in front, each lit
in a circle raised `SHEET_LOBE_SHADE` of its radius and shaded in the crescent under it: the look of a cartoon
cumulus. The base is shaded up to `SHEET_BASE` of the height, in a band that wavers along the track. The sun is the
mist's `mist_towards_sun`, and a face turned from it is shaded a little. The light is the contrails' (clouds')
`ContrailYard.light_at`, which keeps it matched to the clouds lanes' Ghibli look: sun-lit near-white faces and
blue-grey sky-lit shade.

**Rejected.**
- **More, smaller puffs** (round 1's direction, 420 a second). However many there were, overlapping translucent
  billboards gave a soft edge, and the still's edge is a drawn line. At the wall's edge they drew a grey fuzz, and
  from behind their speckled jets made dotted arcs. They are down to 160 a second now, as the splash at the hull.
- **A blended sheet faded by age.** Blending means sorting against the other see-through things, and a cel sheet
  turned grey as it faded, which the still never does. The sheet is opaque with an alpha scissor, and it goes by being
  eaten: the rim sinks and the holes spread.
- **A camera-facing ribbon** (as the contrails are). It gives each eye a slightly different shape, and it lies flat
  when seen from above. The V is a real shape in the world.
- **A flipbook or a painted texture.** It is not tileable along a wall of any length, it blurs up close in a
  headset, and the still is not ours to trace. The lobes are sums, so they stay crisp at any distance.
- **GPUParticles3D ribbons (trails).** One emitter per craft, and float32 world positions on the double build
  (billboard.gdshaderinc).

**Two shader traps**, both paid for in pictures: an interpolated per-craft seed wobbled in its last bits, and the
lobe hash turned that into a different lobe on every pixel. It looked like screen-print stipple, and it is a `flat`
varying now. An `fwidth` in the edge's smoothstep left edge-on faces at alpha 0.5 against a 0.5 scissor, with the
same stipple.

## Water audit (2026-09-17)

After the first pictures the user said: "they look great, let's make sure we always use the good water shader". So
every place water is drawn was listed, and each now goes through `WaterSurface`, the one place water is dressed. The
ocean shader family is `ocean.gdshader` on PLAIN and `ocean_fine.gdshader` on FINE, chosen by the finish.
`tests/water_surfaces.gd` holds all of them to it, and each check has a mutant.

| Where | Before | Now | Wakes and spray |
|---|---|---|---|
| Every level's sea (island, alpine, builder, device yard, hangar yard, lobby, stress): the `Sea` node on PLAIN and `SeaSwell` on FINE | ocean family | unchanged | drawn (FlightLevel) |
| Alpine lakes, 13 of them | **not drawn as water at all**: GroundView coloured the lake bed by height and slope, and the tanker floated on green ground | `LakeSheets`: every lake's water cells in ONE indexed mesh (one draw call; 44,629 vertices for the 13), exactly at `Terrain.water_height`, in the family, following the finish | drawn, and lying flat on still water |
| Carrier deck scene (`CarrierDeck._sea`, marshalling) | plain `ocean.gdshader` whatever the finish, with a StandardMaterial3D fallback | `WaterSurface.wear` by finish | not drawn: the deck scene has no WakeYard |
| The reel's stage river (`tests/craft_video_demo.gd`) | flat blue BoxMesh with a StandardMaterial3D | a PlaneMesh wearing the family by the reel's finish | not drawn: the reel has no WakeYard |
| Savoia probe pond (`tests/savoia_shot.gd`) | flat blue PlaneMesh | the family | not drawn (probe) |
| Probes that load the level (ocean_shot, ship_shot, scenery_shot, wake_shot and others) | the level's sea | unchanged | as the level |

A lake's level is the ground's own water at the lake's middle, from `water_ticks_at` in 1/32 m. The catalogue's
"level" is in 1/1024 m, and read as the same unit it drew no lake at all. That is what the check's first run found.

## Sources

- [Kelvin wake pattern](https://en.wikipedia.org/wiki/Kelvin_wake_pattern): the 19.47 degree angle, divergent and
  transverse waves, and high-Froude narrowing (Rabaud and Moisy, 2013).
- [Physicists rethink the Kelvin wake](https://physicsworld.com/a/physicists-rethink-celebrated-kelvin-wake-pattern-for-ships/).
- [Kelvin wake of transverse and divergent waves (figure)](https://www.researchgate.net/figure/Kelvin-wake-pattern-of-transverse-and-divergent-waves_fig1_303485966).
- [Ship wakes in Triton 2.3](https://sundog-soft.com/2013/07/ship-wakes-in-triton-2-3-kelvin-wakes-bow-wakes-propeller-wash-and-more/):
  Kelvin wakes, propeller wash, bow spray and foam in a game ocean SDK.
- [Ogre forums, technique for a ship's wake](https://forums.ogre3d.org/viewtopic.php?t=47645): a foam-textured trail
  drawn after the water.
- [Shadertoy, Kelvin waves](https://www.shadertoy.com/view/4llBRl): semi-analytic Kelvin waves in a shader.
- [Rooster tail](https://en.wikipedia.org/wiki/Rooster_tail): a seaplane's "roach" off its step.
- [Trifox, "Splash!"](https://www.trifox-game.com/splash/): a stylised splash from scaled cone meshes, empty-bottomed
  panning textures and a Perlin-noise dissolve, with particles only for the foam and the drops.
- [Stylized toon water (godotshaders)](https://godotshaders.com/shader/stylized-toon-water/): colour banded by the
  normal against the view, the flat steps of a cel look.
