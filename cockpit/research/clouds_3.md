# Clouds, round three: a lit side, a shaded side, and lobes

Asked for on 2026-09-18, with a Porco Rosso still as the reference: "Can we use a shader to improve how they look? The
water shader is so good, if we could use a shader for clouds that an inexpensive way to make them way better." The still
was used for looking only. It is not in the repo, and nothing was traced from it.

**What the reference has that clouds2 did not.** Near-white sunlit cauliflower crowns. Shaded flanks in a clear blue-grey,
not a neutral grey. A visible line between the lit lobes and the shaded ones. Crisp, billowing edges at several scales.
Flat, dark bases over a hazy horizon. clouds2's puffs (`research/clouds_2.md`) read as soft grey smoke up close, with the
sunlit side a little grey. The user had said as much on 09-17: "A and B a bit grey on their sunlit side".

The constraint is unchanged: no raymarching, both eyes see one world-space shape, nothing screen-space, and on the double
build nothing reads `CAMERA_POSITION_WORLD`.

## How others do it, and what each costs

- **Ghibli and Makoto Shinkai clouds, painted.** An art direction rather than a technique. Hard terminators, a shadow
  colour that is the sky's blue rather than black, rim light on the edges against the sun, and lobes at two or three
  scales. The Blender and Unreal recreations (80.lv, "Tutorial: Creating Ghibli-Style Clouds in Blender"; "Ghibli-Style
  Stylized Shader Made in Unreal Engine 5") use either many cards with painted normal maps, or a volume with a stepped
  ramp. Cards are camera-facing, which is ruled out for a headset. A volume is a raymarch, also ruled out. **What we take
  from them is the look, not the method: a lit/shade ramp with a controllable softness, and a tinted shadow colour.**
- **Horizon Zero Dawn's Nubis (Schneider, SIGGRAPH 2015 and 2017).** Three terms worth taking without the raymarch:
  1. **Beer's law** for the light through the cloud. clouds2 already had it, across the cloud's sphere.
  2. **Henyey-Greenstein phase** for the silver lining, with g around 0.6 for forward scattering. Cheap: one `pow`.
  3. **The powder effect**, which darkens thin edges that face the sun. **Rejected.** It is correct for a real cloud, but
     it is the opposite of the reference, whose sunlit edges are its brightest part.
- **Value noise with analytic derivatives (Quilez, "value noise derivatives", 2008).** The gradient of the noise comes out
  of the same eight hashes as its value. **Chosen.** It is what lets one noise lookup scallop the outline and also bend
  the normal of every lobe, at the same cost as clouds2's noise.
- **A normal from a signed distance field of the whole puff union.** It needs every puff of the cloud in one pass, or a
  baked 3D texture per cloud. **Rejected.** A MultiMesh instance knows only itself, and a 3D texture per cloud costs
  memory and a bake. The union's roundness is approximated instead by blending the puff's own normal with the point's
  place in its cloud (`puff_modelling`).
- **Screen-space normals from derivatives (dFdx/dFdy) of depth.** **Rejected.** They are per eye, blocky on 2x2 quads,
  and they differ between the two eyes.

## What was built

Everything is in `world/shaders/puff.gdshaderinc`. The geometry (`PuffCloud`) and the layout (`PuffSky`) are unchanged.

1. **Lit at the skin the eye sees, not at the chord's middle.** The shader takes the first point where the ray comes
   within `skin` (0.8) of the puff's radius, or the ray's closest approach if it never does, or the base plane where the
   ray comes up through it. The flat base now lights as a surface facing down, which makes it dark.
2. **One noise, three jobs.** The noise is sampled at that skin, in world metres, so both eyes see the same lobes.
   - Its value bites into the outline: the edge is a level set of the ray's closest approach to the puff's middle, faded
     across `crisp`.
   - Its gradient leans the normal (`relief`), so each lobe has its own terminator.
   - Its value still thins the depth, which is the texture of the fly-through.
   - FINE adds a second octave at 2.31 times the frequency. PLAIN takes one octave.
3. **Light.**
   - Sun: `smoothstep(-terminator, terminator, N·L)`, times the cloud's own shadow (Beer's law over `shadow_depth` of
     the cloud's reach, with a floor of 0.15 for light scattered many times), times a brighter crown (`top`).
   - Shade: the sky's light from above and the haze's from below, tinted by `PuffSky.SHADE_COLOUR` (0.62, 0.84, 1.0) at
     `shade_light` (0.4 to 0.58 on the heaps and sheets).
   - Foot: `shade` darkens the lowest 300 m at most, and the base itself.
   - Silver lining: Henyey-Greenstein at g 0.6, only where the cloud as a whole is thin.
4. **From outside, a body.** Seen from outside, the optical depth is multiplied by `body` (1 to 4 by kind), so a cumulus
   reads as a solid with a crisp edge.
5. **Close to, and inside, what clouds2 had.** From 40 to 200 m in to the chord's middle, and whenever the eye is in a
   puff, every one of the above fades back to clouds2's soft depth-only cloud lit at the chord's middle.

Every knob is named. Per kind, in `PuffCloud.KINDS`: `crisp`, `bump`, `relief`, `body`, `shade_light`, `terminator` and
`top`, beside the existing `shade` (base darkness) and `noise_cell` (lobe size). Global: `PuffSky.SHADE_COLOUR`, and the
shader's `shadow_depth`, `lining` and `lining_g`.

## Three things that went wrong on the way

- **`MODEL_MATRIX` in `fragment()` is the batch's, not the instance's.** In a MultiMesh the instance transform is applied
  in the vertex stage only. clouds2 multiplied the point's offset in its puff by `mat3(MODEL_MATRIX)` in the fragment
  shader, so every puff's modelling came out turned by that puff's own random yaw, and lit sides faced every way. It was
  hidden by clouds2's softness. clouds3's first wall had its sun-facing fronts in shade, and the cause was found by
  drawing the lit share as a colour over the picture: the fronts read 0. The instance basis now reaches the fragment in
  three flat varyings.
- **A straight line across the view from inside a cloud.** From inside a puff, rays whose closest approach to the
  middle lies behind the eye had their "skin" at the eye. The view split along the plane through the eye perpendicular
  to the puff's middle. Found by drawing `t_close < 0` as red. Inside a puff the light is now the chord's middle's.
- **A backlit heap was a froth of outlined bubbles.** Every lobe kept a bright crescent on its top. There were two
  causes: the silver lining was drawn at every puff's own edge, and clouds2's multiple-scattering floor (0.55) kept too
  much sun deep in the cloud. The lining is now weighted by how near the point is to the cloud's own edge, and the floor
  is 0.3. A faint crescent is left, and that is a tuning question for the user.

## The check

`tests/puff_shot.gd`, group `look`, renders a towering cumulus side-on from 4 km with the sun low on the right, once with
the cloud and once without it, and cuts the cloud's pixels into bands. It asks for three things:

| check | least | clouds2 | clouds3 |
|---|---|---|---|
| sunlit side brighter than the shaded side | 0.12 | **0.028** | 0.238 |
| crown brighter than foot | 0.25 | **0.143** | 0.402 |
| shade's blue over its red | 0.14 | **0.094** | 0.181 |

It has three mutants, each the bug it guards, and each fails on its own check. Lighting through the batch's
`MODEL_MATRIX` gives 0.112 (the narrowest). A neutral-grey shade gives 0.105. No crown and no foot gives 0.150.

## What it costs

Measured by `puff_shot --only=time` on 2026-09-18, 13:09 to 13:17, under one MEASUREMENT hold kept for the whole slot.
The script is `godotgames-drafts/2026-09-18/cockpit-clouds3/measure.ps1`. It ran A/B/A: clouds3's shader, then
clouds2's three files (a37a86e6) swapped in, then clouds3's again, then clouds3 on PLAIN. Each case is the median GPU time
of 360 frames (three rounds of 120 after 30 warm-up frames). Setup: RTX 5080, D3D12, Mobile renderer, double editor,
`cut` shader.

On the machine at the start and end: GPU 1 % and 2 %, no new GPU process between the two nvidia-smi lists, and two
headless suites from another lane (`kinds`), which use the CPU only. The two clouds3 runs agree to within 0.004 ms in
every case, and p95 is within 0.004 ms of the median everywhere.

| view | clouds2 1600x900 | clouds3 FINE 1600x900 | clouds3 PLAIN 1600x900 | clouds2 2880x1620 | clouds3 FINE 2880x1620 | clouds3 PLAIN 2880x1620 |
|---|---|---|---|---|---|---|
| no clouds | 0.029 | 0.029 | 0.029 | 0.081 | 0.080 / 0.081 | 0.080 |
| layered sky, 3,303 puffs in 6 draws | 0.183 | **0.192** / 0.192 | 0.176 | 0.373 | **0.375** / 0.377 | 0.338 |
| inside a flat-based cumulus | 0.436 | 0.431 / 0.431 | 0.357 | 1.363 | 1.351 / 1.351 | 1.107 |
| inside, given way | 0.189 | 0.187 / 0.187 | 0.165 | 0.555 | 0.537 / 0.537 | 0.469 |

(clouds3 FINE shows the first and second run as A / A.)

- **The layered sky costs +0.009 ms at 1600x900 and +0.002 to +0.004 ms at 2880x1620** on FINE. That is well under the
  0.5 ms brief, at 0.192 ms. The new lighting's arithmetic replaced clouds2's three-octave fbm plus an extra octave
  (32 hashes) with two value-noise-with-gradient lookups (16 hashes), so it is close to free.
- **Inside a cloud it is a little cheaper**, by 0.005 and 0.012 ms (and 0.018 ms given way), for the same reason: close to
  and inside, the lighting is clouds2's, and the noise is cheaper.
- **PLAIN** (one octave) is 0.016 ms cheaper than FINE on the sky at 1600x900 and 0.244 ms cheaper inside at 2880x1620.
  PLAIN on clouds2 was not timed; it was one octave of `value_noise3` there too.
- This hold's layered sky reads about 0.02 to 0.05 ms higher than clouds2's 09-17 table (0.161 / 0.321). The clouds2
  shader itself reads 0.183 / 0.373 today, so the difference is the day and the machine, not this lane. Compare within
  the table, not across tables.

## Step 2, after the user's answers (2026-09-18)

The user saw pictures 01 to 14 and answered three questions:
- Shade: "darker bluer yes, more contrast might look good".
- Edges: "keep them, blurry and whispy is good".
- Towers: grouped into fuller masses. That is step 3, and it is geometry.

Step 2 changed only the shade; `crisp` and `bump` are untouched.
- `shade_light` went from 0.55–0.7 to 0.4–0.58 on the heaps and sheets.
- `SHADE_COLOUR` went from (0.8, 0.95, 1.0) to (0.62, 0.84, 1.0).
- The crowns' `top` went up by 0.05 to 0.1.
- The cloud's own shadow went deeper: `shadow_depth` from 0.6 to 0.8, and the scattering floor from 0.3 to 0.15. Without
  that last change, the flanks turned away from the sun stayed the sun's light dimmed, a neutral grey, and the new blue
  barely showed (a tower body moved 8 levels in 255).

The look check reads 0.207, 0.391 and 0.186. Its three mutants are all still killed (0.100, 0.102 and 0.171 against
floors of 0.12, 0.14 and 0.25). Only constants changed, so the cost is unchanged. Pictures: 15 to 20.

## Step 3, towers in walls, and step 4, the altocumulus (2026-09-18)

**Step 3.** A tower is now 5 to 7 overlapping masses. Each mass is a big puff with 3 to 5 lobes bulging out at random
heights, and a cauliflower crown sits on top. The old tiers of rings read as a stack of pancakes up close.
`PuffSky.plan` groups its towers into walls of about four, 0.6 of a width apart (`PuffSky.wall`). It takes the same
random draws as before, so no other cloud moved.

The wider towers lost every face to their own shadow. The cloud's self-shadow is taken across the sphere of its
reach, and a tower's reach is its height. The self-shadow is now capped at `SHADOW_MOST`, 600 m.

puff_sky's `the_towers_stand_in_walls` fails the row: 6 alone, the farthest 11,843 m from its nearest neighbour.

**Step 4.** Seen from the flight level, the altocumulus read as bubble wrap. There were two causes:
- Each puff was one cell of the deck with gaps round it. A puff is now `spread` 1.4 to 2.0 cells wide, and the deck's
  look is softer.
- Every sheet puff cut by the deck's base drew a dark disc facing down, with its lit side as a rim round it. Only a
  heap's base faces down now.

`an_altocumulus_deck_is_rolls_not_bubbles` reads 0 of 108 puffs apart. At the old spread it reads 16.

**Cost of step 3, and a CROSS-HOLD comparison, labelled as such.** Step 3's towers were timed twice in one MEASUREMENT
hold (14:22). The two runs agree:

| view | step 3, run 1 | step 3, run 2 |
|---|---|---|
| layered sky, 1600x900 | 0.192 ms | 0.192 ms |
| layered sky, 2880x1620 | 0.352 ms | 0.354 ms |
| inside, 1600x900 / 2880x1620 | 0.431 / 1.351 ms | 0.432 / 1.352 ms |

The same-hold "before" run parse-errored (see the learnings), and team-lead ruled against a second slot. The before
figure therefore comes from the 13:09 hold: 0.192 and 0.375 ms for step 1's towers, and step 2 changed only constants.

So, across two holds: the walls read the same at 1600x900 and about 0.02 ms cheaper at 2880x1620. The probe sky has
2,997 puffs, against 3,046 before.

**The worst case for step 4: under the altocumulus deck, looking up** (`puff_shot --only=time --time-views=deck-overhead`),
timed in ONE hold, 16:10:51 to 16:13:08 (`measure6.ps1`). The runs were interleaved A/B/W/A: the chosen spread, step 3
(`342f4a4e^`), step 4's first wide spread, then the chosen spread again. Windowed Godots and GPU use were logged before
and after every run: no other windowed Godot at any bracket, and GPU 0 to 4 %.

This is a REDO. The first slot (15:59) was overlapped by another lane's CAPTURE render from about 16:00:10 to 16:00:40
and is void. Its numbers are not used, though they agreed to 0.001 ms.

| altocumulus `spread` | deck overhead, 1600x900 | deck overhead, 2880x1620 | layered sky, 1600x900 / 2880x1620 |
|---|---|---|---|
| 0.7–1.05 (step 3, bubble wrap) | 0.103 ms | 0.280 ms | 0.183 / 0.350 ms |
| **1.15–1.45 (chosen), run 1 / run 2** | **0.173 / 0.174 ms** | **0.493 / 0.492 ms** | 0.193 / 0.368 ms, both runs |
| 1.4–2.0 (step 4's first) | 0.254 ms | 0.743 ms | 0.200 / 0.386 ms |

Overdraw goes as spread squared. The first step 4 cost 2.5 times clouds2 under the deck: about +0.46 ms at 2880x1620,
or +0.9 ms for a headset's two eyes. The chosen spread halves that increase, and it still reads as a soft mackerel sheet
(picture 30 has all three). It still passes `an_altocumulus_deck_is_rolls_not_bubbles` (1 of 108 apart, one in twenty
allowed). The wider spread is one row key away if the user prefers it.

**Steps 3 and 4 against step 2, in ONE hold (16:05, 8 minutes granted, 372 s used, A/B/A).** Step 2 is 85256c63's
three world files and its `puff_shot.gd`. The two "after" runs agree to 0.000 ms on the sky; GPU was 0 % at the start
and 4 % at the end.

| view | step 2 (before) | steps 3+4, run 1 / run 2 | difference |
|---|---|---|---|
| layered sky, 1600x900 | 0.191 ms | 0.206 / 0.206 ms | **+0.015 ms** |
| layered sky, 2880x1620 | 0.376 ms | 0.388 / 0.388 ms | **+0.012 ms** |
| inside a cloud, 1600x900 / 2880x1620 | 0.431 / 1.351 ms | 0.437 / 1.368 ms | +0.006 / +0.017 ms |
| inside, given way, 1600x900 / 2880x1620 | 0.187 / 0.537 ms | 0.188 / 0.542 ms | +0.001 / +0.005 ms |

Set beside the cross-hold step 3 figures above (0.192 / 0.353 ms), step 4's bigger altocumulus puffs cost about 0.014
and 0.035 ms. The layered sky, all four steps in, is **0.206 ms at 1600x900**, well under the 0.5 ms brief, and 0.388 ms
at 2880x1620, against clouds2's 0.183 and 0.373 ms measured the same day.

## Rejected

- **Raymarching, camera-facing cards and screen-space passes.** Rejected for the reasons in `clouds_2.md`, all still
  true.
- **The powder effect**, which is the opposite of the reference (above).
- **A signed-distance union normal**, which needs every puff of a cloud in one pass.
- **Changing the towering cumulus's shape in step 1.** That was geometry, and the brief was the shader. The user then
  asked for it, and it became step 3.
