# Clouds, round two: transparent puffs at six heights

Asked for on 2026-09-17: "more work on clouds, i realize we can't use volumetrics, but perhaps transparent spheres in the
right orientation will feel like clouds, i'd like to have more variations on clouds and have them at different altitudes
so planes can fly through, around them."

This note covers how games draw a cloud you can fly into without raymarching, what was chosen here, what was turned
down and why, and what each option costs on the Mobile renderer and in a headset. The prototype is `world/puff_cloud.gd`
(`PuffCloud`), `world/puff_sky.gd` (`PuffSky`) and `world/shaders/puff.gdshaderinc`. Its pictures come from
`tests/puff_shot.gd` and its rules are held by `tests/puff_sky.gd`.

## What was already here, and the constraint

- `LiftYard`'s cumulus is 24 opaque spheres a cloud with a blended rim (`cumulus_lump.gdshaderinc`), lit as a volume
  through an envelope (`cloud_light.gdshaderinc`). Far off it is good. Close to it is a pile of skins. From inside one the
  island stays in plain view, because back faces are culled. That is why "whiteout" is the depth fog turned up by
  `FlightLevel._on_eye_in_cloud` rather than anything the cloud draws.
- The FogVolume clouds (`CloudBank`) are off. The game went back to the Mobile renderer on 2026-09-15, and Mobile has
  no volumetric fog. `agents.md` rejects raymarching because "a cloud you fly through fills both eyes".
- The rules for the headset: nothing that belongs to one eye (no screen-space trick, no per-pixel hash); on the double
  build nothing reads `CAMERA_POSITION_WORLD` (`eye.gdshaderinc`); a standalone headset's default is PLAIN, which has
  no MSAA and forced vertex shading.

## How other games do it

- **Microsoft Flight Simulator 2004 (Niniane Wang, SIGGRAPH 2003; GDC 2004 "Realistic and Fast Cloud Rendering in
  Computer Games").** Each cloud is authored as a few boxes filled with 5 to 400 camera-facing sprites cut from a
  16-image atlas. Colour comes from height in the cloud and from the angle between the sun and the view. Far clouds
  are rendered to impostors, and sprites fade out as the camera nears them. Cheap and art-directable. The costs are
  sorting (sprites are alpha-blended in order) and the camera-facing quads, which in a headset turn with the head and
  differ between the eyes.
- **Sea of Thieves (Rare, SIGGRAPH 2018 "The Technical Art of Sea of Thieves").** Mesh clouds with a light-occlusion
  lobe baked into each vertex, then blurred and distorted in screen space and composited behind the scene. Beautiful
  far off, but the blur is a screen-space pass (per eye in a headset, and it smears in stereo), and the clouds are
  never flown through.
- **Soft particles / depth fade** (the standard technique). A blended surface fades where it nears the depth buffer's
  surface, and near the camera, so it meets the world softly and never clips at the near plane. It needs the depth
  texture.
- **Raymarched volumes** (Horizon Zero Dawn's Nubis, Microsoft Flight Simulator 2020, UE's Volumetric Cloud) are the
  right answer and the one this project has ruled out: tens of density samples a pixel, and the pixels are the whole
  screen in both eyes when you are inside.

## What was chosen: a puff is a transparent ellipsoid, integrated exactly

The user's "transparent spheres", with the one trick that makes them read as air: **each pixel's opacity is the
optical depth of the eye's ray through the ellipsoid, worked out in closed form.** The density is 1 - r^2 in the puff's
unit sphere, so the integral along the chord is a cubic in the ray parameter, and alpha is 1 - exp(-depth). No
raymarch: one quadratic, one cubic, a noise lookup and a depth sample a pixel.

What falls out of it:

1. **Soft edges by construction.** A grazing ray crosses almost no cloud, so the silhouette fades to nothing.
2. **No sorting within a cloud.** Two layers blend to 1 - (1 - a1)(1 - a2) = 1 - exp(-(d1 + d2)) in either order, so a
   heap of puffs is one volume of summed depth. No puff's skin shows through another. Only colour depends on the order,
   and one cloud's colours are close.
3. **Flying in is flying in.** The mesh is drawn by its back faces (`cull_front`), so every pixel inside a puff's
   outline has exactly one fragment whether the eye is outside or inside, and once the eye is inside, the chord starts
   at the eye. Nothing is near the near plane, so nothing clips or pops. The view fades to grey-white as the depth ahead
   grows, and back as it shrinks (pictures 10 to 17).
4. **Meeting the world softly.** The depth test is off, and each chord is cut where the depth buffer's surface is. A
   hillside inside a cloud, or an aeroplane inside it, is fogged by exactly the cloud in front of it.
5. **A flat base.** Each chord is also cut at the cloud's base height, so a heap of round puffs has one level floor.
6. **Both eyes.** The ray is each eye's own, from `EYE_OFFSET` in view space to the fragment. The two eyes see one
   solid in the world, not two pictures. The noise is sampled in the world. `MODELVIEW_MATRIX` without
   `skip_vertex_transform` is the double build's precise transform (`billboard.gdshaderinc`).

**Lighting is the cloud's, not the puff's.** Round one lit each puff as its own sphere. Every heap read as a pile of
balls, and a ray through a puff's middle pinched its normal into a star (`godotgames-drafts/2026-09-17/cockpit-clouds2/
round1-before-cloud-lighting`). Each instance now carries its offset within its cloud in the instance colour, and the
shader places the point in the cloud and lights the cloud:
- a sunlit side;
- a Beer's-law share of the sun through the cloud's own sphere, with a floor for light scattered many times;
- height in the cloud, and a darker base the thicker the kind;
- a 0.4 share of the puff's own modelling for florets, from an offset that is never normalised, so a puff's middle has
  no direction.
A sheet (stratocumulus, altocumulus, cirrus) is lit by height alone.

## The six kinds, and their heights

Every number is in `PuffCloud.KINDS`, one row a kind. The heights are the textbook bands, pulled in so the island's
layers leave clear air between them.

| kind | base band | shape | why |
|---|---|---|---|
| cumulus (humilis) | 1,000–1,400 m | 10–16 puffs, a core and a heap, 450–800 m wide | the fair-weather cloud, a thermal's cap |
| towering cumulus (congestus) | 1,100–1,400 m | 8–10 tiers of a ring round a middle puff, 1.3–1.7 times as tall as wide | the one kind that climbs through the layers |
| flat-based cumulus (mediocris) | 1,200–1,500 m | 16–22 puffs, about 1 km wide, dark base | the classic cumulus with its condensation-level floor |
| stratocumulus | 2,200–2,500 m | a jittered grid of broad flat puffs where a smooth cover field says so, 5 km across | a deck to fly under, over or through |
| altocumulus | 4,200–4,800 m | small puffs in rows (mackerel sky) | the middle layer |
| cirrus | 8,200–9,400 m | chains of long thin puffs curling up at one end | the high ice |

**Clear air between the layers** (`PuffCloud.CLEAR_AIR`, 300 m). A heap with an `under` is squashed towards its base
until its top clears the lowest base the layer above can have. This was found by `tests/puff_sky.gd`, not by looking:
the largest flat-based heaps topped out at 2,208 m, into the stratocumulus band's 2,200. **Never in the ground**
(`PuffCloud.CLEARANCE`, 250 m): each cloud is lifted to clear the highest ground under any puff, and on the island's
3,000 m peaks the ground wins over the band.

## What it costs

Measured by `tests/puff_shot.gd --only=time`: the stage viewport's own GPU timer, 120 frames after 30 warm-up frames,
three rounds interleaved (360 frames a case), RTX 5080, D3D12, Mobile renderer, double editor, 2026-09-17 21:38 to
21:40 under an exclusive MEASUREMENT hold (`tools\gate_run.ps1 -Perf`). On the machine at the start: one headless
`--import` in the main checkout (no GPU), finished by the end; tomcat's lane may have been compiling C++ on the CPU. A
smoke run without the hold 20 minutes earlier agreed to 0.002 ms in every case, and p95 is within 1 % of the median.

| view | 1600x900 cut | 1600x900 depth-tested | 2880x1620 cut | 2880x1620 depth-tested |
|---|---|---|---|---|
| no clouds (ground and sky) | 0.031 ms | 0.031 ms | 0.082 ms | 0.082 ms |
| layered sky, 3,303 puffs in 6 draws | 0.161 ms | 0.139 ms | 0.321 ms | 0.278 ms |
| inside a flat-based cumulus | 0.429 ms | 0.402 ms | 1.333 ms | 1.258 ms |

- **Draw calls: one a kind.** A whole sky is six MultiMesh draws, however many clouds.
- **The worst case is inside a cloud.** Every puff holding the eye covers the whole screen, and each runs the whole
  shader. At 2880x1620 (4.7 MP, about half a headset's two eyes) that is 1.3 ms, so a headset's two eyes are about
  2.5 ms on this GPU. It is the one number that must come down before this ships to VR. The obvious remedy is already
  in the level: past a depth where the view is all cloud anyway, fade the puffs holding the eye out and let the depth
  fog's whiteout (`Daylight.show_in_cloud`) carry it.
- **The depth copy.** On PLAIN nothing reads the depth texture today, so the engine skips the copy (`tests/lint.gd`,
  "only the spatial mist reads the depth texture"). The puff shader brings it back. Priced here as "cut" against
  "depth tested" (`puff_depth_tested.gdshader`, the same body with no depth read): +0.022 ms (1600x900) and +0.043 ms
  (2880x1620) on the sky view, +0.027 and +0.075 ms inside. The depth-tested shader is worse to look at: a cloud's far
  half behind a hill is lost, and an aeroplane inside a cloud is not fogged by the cloud in front of it.
  **RECOMMENDED: the cut shader, depth copy and all.** Under a tenth of a millisecond at about half a headset's pixels
  buys the two things a flyable cloud is for -- an aeroplane in the cloud is in the cloud, and a cloud on a hillside
  meets the hill -- and on FINE the copy is already paid by the spatial mist.
- **Vertices.** A puff is a 16 by 8 sphere, so the sky is about 3,300 x 153 vertices, in both eyes. Cheap next to its
  pixels.

## Rejected, and why

- **Raymarching**, again: the right look and the wrong cost, since a cloud you fly through fills both eyes.
- **Camera-facing sprites (the Flight Simulator 2004 way).** A quad that faces the camera turns with the head in a
  headset and is a different quad in each eye. The puffs are solids in the world.
- **Screen-space blur and composite (Sea of Thieves).** It is per eye by nature.
- **Opaque lumps with a blended rim (`LiftYard`, today's).** They have a skin, and there is no inside to them.
- **Lighting each puff as its own sphere.** It gives balls and pinched stars (round one).
- **Dithered or hashed coverage.** It crawls between the eyes, and `agents.md` already has it on record.
- **Metaballs as a surface.** A marching-cubes or signed-distance surface of the same puffs gives a smooth blob with a
  skin, the very thing a cloud does not have. The summed-density field here is metaballs' own field, drawn as depth
  rather than as a surface.

## The inside, timed again with the puffs given way (2026-09-17, 22:33 to 22:35)

This is the same method, under an exclusive MEASUREMENT hold. On the machine at the start: a headless suite in the wakes
lane and a headless import in the tomcat lane, both CPU only. `inside-given-way` is the inside view with the puffs
holding the eye given way as the level gives them. The eye's depth was 1.00, so they are wholly given way.

| view | 1600x900 cut | 1600x900 depth-tested | 2880x1620 cut | 2880x1620 depth-tested |
|---|---|---|---|---|
| no clouds | 0.031 ms | 0.031 ms | 0.082 ms | 0.081 ms |
| layered sky | 0.185 ms | 0.162 ms | 0.378 ms | 0.330 ms |
| inside a cloud, drawn whole | 0.439 ms | 0.412 ms | 1.367 ms | 1.285 ms |
| **inside a cloud, given way** | **0.192 ms** | 0.173 ms | **0.558 ms** | 0.498 ms |

- **Giving way takes 59 % off the inside at 2880x1620:** 1.367 down to 0.558 ms, so about 1.1 ms for a headset's two
  eyes rather than 2.7.
- **What is left** is the cloud's other puffs, which still cover much of the view from inside it. The given-way puffs'
  fragments are still rasterised and discarded at once.
- **The layered sky costs 0.024 to 0.057 ms more than the first timing.** Since then the puffs have taken the mist once a
  vertex, and this hold had other lanes' CPU work beside it.

## Wired in (2026-09-17), and what is still open

The user saw pictures 01 to 23 and said "all clouds look good". `FlightLevel` now wears `PuffSky.level_sky`, with a cloud
over every thermal and the layered plan. See `agents.md`, "The clouds are puffs", and the level pictures 30 to 39. Open:

- **A light or a contrail BEHIND a cloud shows through it.** The puffs are drawn straight after the mist and before every
  other see-through thing, because drawn after them they painted over lights in front of the cloud (the first level
  pictures lost every red light in the cloud_near and cloud_edge views at night). The fix would be a cloud term in each
  see-through shader, as the mist is, or a depth the puffs could write.
- **The sky covers 16 km from the world's middle** (`PuffSky.SKY_REACH`). The 64 km alpine world wants the sky streamed
  round the eye.
- **Tuning, as the user left it:** A and B a little grey on their sunlit side, F more dashes than wisps, and the crispness
  close to. The knobs are named constants in `PuffCloud.KINDS` and the uniforms of `puff.gdshaderinc`.
- **Nothing has been seen in a headset.**
