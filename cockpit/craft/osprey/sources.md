# Bell Boeing MV-22B Osprey visual reference

The runtime exterior is an original procedural model made from Godot primitives
(`objects/vehicles/osprey_airframe.gd`). It contains no downloaded mesh, photograph, texture, trademark or livery.

**It is the MV-22B**, the Marine Corps' tiltrotor. The things it is recognised by are drawn: the rounded nose with the
refuelling probe on its starboard side, the flight deck's glazing wrapped round it, the boxy cabin on a flat belly with a
sponson either side, the high wing on its centre fairing, swept forward and with dihedral, the aft fuselage sweeping up
into the loading ramp, the H-tail whose fins reach down below the tailplane, and **the nacelles on the wing tips, which
swing with their three-bladed proprotors from straight ahead to past vertical**, the proprotors turning.

Datum and axes: the craft origin is the centre of the collision box, forward is `-Z`, up is `+Y`, and one Godot unit is
one metre. The drawn length is centred on the box and the ground is the box's floor. Stations below are metres aft of
the nose tip, heights metres over the **belly datum** (the side view's flat belly), and out metres from the centreline.
The native collision box, handling, networking and station poses remain authoritative; the nacelles' angle is the bus's
`tilt` times the kind's travel, the same product `fly_tiltrotor` turns the thrust by.

## The authority for the shape

**[JJ]** "Bell Boeing MV-22 Osprey line drawing.svg", Jetijones, 2011-03-28, on Wikimedia Commons,
[CC BY 3.0](https://creativecommons.org/licenses/by/3.0/): a side, a front and a plan, **each drawn twice**, in aeroplane
mode and in helicopter mode. A vector drawing, rendered by Commons at 3840 x 4304 px. It is used for measuring only,
and the overlay pictures that lay the model over it carry its attribution. No public-domain orthographic set of the V-22
is on Commons (about ten searches, 2026-09-19); "MV-22 6 point drawing.png" (Vega61, CC BY-SA 3.0) is 403 px wide,
about 0.1 m a pixel, and is not used.

**The views do not all share one camera, and that was checked before anything was measured.** The plans and the fronts
do: the proprotor disc, face on in both front views (aeroplane mode) and both plans (helicopter mode), is the same number
of pixels across in all four. The sides are drawn **0.8 per cent shorter** than the plans, nose tip to tail (1,357 px
against 1,368). So each is scaled by the published fuselage length on its own: **77.63 px a metre for the sides, 78.26
for the plans and fronts** (1.29 and 1.28 cm a pixel). The disc then reads **11.665 m against the published 11.61
(+0.5 per cent)** in all four face-on views, a figure the scales were not set from.

**[NPS]** The V-22 Program Office's side view on page 97 of the Naval Postgraduate School thesis "The V-22 tilt rotor, a
comparison with existing Coast Guard aircraft" (Commons, public domain, rendered at 300 dpi). A poor scan, but the only
drawing with a **ground line**: the belly stands **0.45 m over the ground** (median of 24 columns). Its own vertical
scale, read at its printed height, is 0.965 of its horizontal, so only its clearance and its ratios are used.

`measure_views.py` re-derives every MEASURED figure below from the two drawings alone, reading nothing out of this file
or the airframe. `overlay_views.py` lays `tests/osprey_shot.gd`'s orthographic silhouettes over [JJ]'s six views at
x1.000. The drawings, the NASA paper and the Wikipedia text are in
`~/godotgames-drafts/2026-09-19/cockpit-osprey/research/`; none is incorporated into the game.

## The envelope, published

**[WP]** Wikipedia, "Bell Boeing V-22 Osprey", specifications (MV-22B; Norton 2004, Boeing): length **57 ft 4 in
(17.48 m)**, span **45 ft 10 in (13.97 m)**, width **84 ft 6.8 in (25.77 m) including rotors**, height **22 ft 1 in
(6.73 m) with the engine nacelles vertical** and **17 ft 7.8 in (5.38 m) to the top of the tailfins**, two three-bladed
proprotors **38 ft 1 in (11.61 m)** across. Folded: 62 ft 7.6 in long, 18 ft 5 in wide, 18 ft 1 in high. "The nacelles
can rotate past vertical to **97.5°** for rearward flight" (Norton p. 97). "For storage, the V-22's rotors fold in 90
seconds and its wing rotates to align, front-to-back, with the fuselage."

**[NASA]** C. W. Acree, "Effects of Blade Sweep on V-22 Whirl Flutter and Loads" (AHS Forum, 2004; NASA): "The
aerodynamic sections start with a **36-in chord at 5% radius, linearly tapering to a 22-in chord at the tip**. Total
effective blade **twist is 47.5 deg over a 228.5-in radius**." The radius is the published disc's to 0.02 per cent.

**[VM]** Vertical Mag, "The tiltrotor revolution: MV-22B Osprey": the refuelling probe is "almost directly in line with
the right seat pilot", so on the starboard side. **[JJ]'s plan draws it on the other side** (0.36 to 0.61 m out); the
side is [VM]'s.

## Measured off [JJ]

| | measured | model |
|---|---|---|
| Nose tip to fin trailing edge | the scale (see above) | 17.48 m |
| Probe | its tip 0.12 m ahead of the nose, 1.02 to 1.28 m up | 0.485 m out, 1.15 up |
| Fuselage side profile | top and bottom every 0.25 m (`SECTIONS`) | the same rings |
| Cabin | 1.33 m either side in plan from 2.5 to 11.0; the front view 1.19 m out at 2.15 m up | 1.18 at 2.18 |
| Ramp | the belly rising straight from 11.0 to 2.07 m at 15.25: 26 degrees | the same |
| Sponsons | the plan: 2.35 m out at 8.5 to 9.0, from 4.75 to 12.5 | the plan's outline |
| Wing leading edge | station 5.943 - 0.1157 x out, 146 rows, 28 mm rms: **6.6 degrees forward** | the same |
| Wing trailing edge | 8.507 - 0.1111 x out | the same |
| Wing, front view | top 3.289 + 0.078 x out, bottom 2.569 + 0.081 x out: **4.5 degrees of dihedral**, 0.72 m deep | the same |
| Conversion axis | the point a quarter turn carries the aeroplane-mode hub onto the helicopter-mode one: station 6.615, 3.48 m up | the same |
| Pivot to blade plane | 2.500 m in aeroplane mode, 2.500 in helicopter mode | 2.50 |
| Rotor axis | 0.16 m over the conversion axis (the front view's disc centres, 3.64 m up) | the same |
| Disc centres out | 6.94 and 6.86 (front), 7.25 and 7.11 (plan): 7.05 on average | [WP]'s 7.08 |
| Nacelle | its depth by height (helicopter-mode side), its width (helicopter-mode front), its top aft of the wing (aeroplane side) | `NACELLE` |
| Fins | out 2.55 (plan) to 2.67 (front); canted in 2.1 degrees; from 1.49 m up to 4.96 (front) | 2.61 out |
| Tailplane | 15.15 to 17.45, 2.25 to 2.75 m up across the fins | 2.50 up, 0.34 deep |
| Glazing | the windscreen 1.26 to 1.71, the side windows 1.93 to 2.77, the chin windows 0.94 to 1.65 | see below |

The overlays agree, outside the proprotors' discs, over **92.4 per cent from the side in helicopter mode, 88.3 in
aeroplane mode, 94.0 from the front in aeroplane mode, 77.1 in helicopter mode, 89.9 in plan in aeroplane mode and 97.4
in helicopter mode** (`overlay_views.py`). The discs are left out because where a blade stands in its disc is where
the draughtsman stopped it: in a face-on view the blades are a third of everything drawn. The side views' shortfall is
[JJ]'s blades drawn edge-on, not the airframe; the helicopter-mode front's is the blades too, which [JJ] draws drooping to
their tips and the model draws flat.

## The height, and where [JJ] is not followed

With [NPS]'s 0.45 m of clearance, [JJ]'s helicopter-mode blade plane stands 6.43 m over the ground ([NPS]: 6.32) and its
outer blades' tops 6.74 m, which is [WP]'s 6.73. But [JJ]'s spinner is a tall cone 0.95 m proud of the blades, which
would make the aircraft 7.38 m high; [NPS]'s is about 0.5 m proud, and its page prints 22 ft 7 in (6.88 m). The spinner
is drawn to **[WP]'s 6.73 m**, 0.30 m proud of the blade plane, and `tests/osprey.gd` holds that height.

[JJ]'s side view puts the fins' tops 0.17 m higher (5.13 m over the belly) than its own front view (4.96). The front's is
taken: 5.41 m over the ground against [WP]'s 5.38.

[JJ]'s front view is 7 per cent narrower across the sponsons (2.19 m out) than its plan (2.35); the plan is taken, since
the two views agree about everything else to 2 per cent and the plan is the view that sees a sponson's outline whole.

Past vertical the discs lean back: at the full 97.5 degrees the aft-pointing blades stand 0.65 m higher, and a model
parked there is 7.37 m high. **A V-22 parks with its nacelles straight up**, and the view draws it so with no bus.

## The windscreen, and the eye

The simulation seats the crew over station 2.34 with their eyes 2.30 m over the belly (`osprey_shape`, and
`CockpitStation.EYE_HEIGHT`). The roof there is 2.53 m. [JJ]'s windscreen ends at 1.71, and the roof from 1.75 to 2.00 is
2.29 to 2.46 m high, so a windscreen ending where [JJ]'s does put the view ahead through an opaque panel. The glazing
runs on to 2.00, where [JJ]'s side windows begin. That was with the eye 2.30 m up; step 2 moved it to 2.05.

## What moves, step 2 (2026-09-19)

**The gear.** Twin nose wheels and twin mains in each sponson. **[NPS]** puts the nose wheels under the chin at station
1.1 and the mains under the wing's trailing half at 7.5; the photographs (studied, not incorporated: Commons, US Navy and
USMC, public domain) put the nose leg just behind the chin turret and the mains half hidden in the sponsons. How they
retract is ESTIMATE: the nose leg aft into a well under the flight deck, the mains forward into the sponsons, each on a
hinge whose stowed turn is worked out from the leg's own geometry. The sequence is the F-35B's: the well doors open over
the first fifth of the cycle, the legs move over the middle three, the doors shut over the last, a whole cycle in
`GEAR_SECONDS` (8 s drawn, adjustable). **Each door stops short of where its leg leaves the skin**: the nose doors began at
1.35 and shut 3 cm into the nose tyres, which reach 1.38; they now begin at 1.42.

**The ramp and its upper door**, cut from the fuselage's lower facets aft. The ramp is hinged at 11.0 where the belly
starts up and lowers until its aft edge meets the ground (32 degrees, found by bisection over the drawn ramp); the upper
door, 14.0 to 15.25, swings up 20 degrees about a hinge at its chines' height. Hinged at the keel, its chines swung aft
through the tail cone; opened 30 degrees, level, its forward edge stood where the cabin wall has turned in to the
shoulder, and went through it. Both are drawn 1.5 per cent narrower than the skin. On the bus the ramp is the **drop**
channel's bit ("the doors a load leaves by"), fitted to the Osprey as "ramp": the simulation's water is gated on
`has_a_tank`, and the cockpit now asks that (`Sim.carries_water`) rather than the channel, which gave the first V-22
fitted with it a tank gauge.

**The crew door**, forward on the starboard side, [JJ]'s outline from 3.43 to 4.27: the lower half drops outward 100
degrees to hang as the steps, the upper half swings in and up 85 degrees under the roof, both ESTIMATE, each drawn 2 cm
shy of its opening's edges. No bus bit drives it yet: it is a VAT feature a later control can move.

**The cabin**: a floor 0.45 m up from the flight deck's bulkhead to the ramp's hinge, where the simulation stands the
crew chiefs, and a dark lining inside the skin (walls 1.22 m out, a ceiling 1.75 m over the floor; the published cabin
is 1.83 m high), because through the first open door the far wall's inside showed in the skin's own grey. A chin turret
(the FLIR ball, 0.52 m, ESTIMATE) ahead of the nose gear.

**The flight deck.** The simulation's seats moved in C++ (`osprey_shape`): **the pilot now flies from the right-hand
seat** and the copilot from the left, as in every V-22, and both eyes are 2.05 m over the belly, in the middle of [JJ]'s
side windows (1.70 to 2.47), where they were 2.30. The crew chiefs stand on the cabin floor. **[GS]** GlobalSecurity, "V-22
Osprey cockpit": two pilots side by side "in crashworthy seats", each "an armored bucket seat" -- so the chairs lane's
`heli_armoured` preset under both. **Both pilots have the thrust control lever under the LEFT hand**, with the nacelles'
thumbwheel, and a centre stick, so the right-hand seat is NOT the left one reflected (`VehicleCatalogue.same_hands`, read by
`VehicleView`, the package generator and `tests/stations.gd`). That left no room for the console row down the middle --
the pilot's lever and the tilt lever beside it stood 0.21 m from it -- so on this craft the flaps, gear and ramp run down
the pilot's right, as they do beside a lone seat.

**A hundred Ospreys** handed their buses every frame (`tests/osprey_shot.gd --only=crowd`) cost 2.4 ms a frame parked and
3.2 to 3.6 with the proprotors turning, 24 to 36 microseconds an aircraft, on a frame held at the 16.6 ms vsync. Before
the setters returned early on an unchanged amount it was 3.4 ms parked.

## ESTIMATE

- **The gear's tyres**: 0.56 m nose, 0.74 m mains; every tyre stands on the ground, an eight-sided tyre on a flat.
- **The nacelle's underside aft of the wing** is hidden in every view; it tapers to the exhaust.
- **The blades' pitch**: 14 degrees at three quarters of the radius, a hovering collective, twisted by [NASA]'s 47.5.
- **Which way each proprotor turns**: opposite ways, as they do; which is which is not settled here.
- **The paint**: two greys, darker above (FS 36118) than below (FS 36375), sRGB approximations.
- **The cabin floor** 0.45 m over the belly, and the flight deck's 0.70 (the pilots' seat anchors).
- **Tessellation**: 12 facets a fuselage ring, 8 a sponson, 12 a nacelle, a six-point airfoil at six stations a blade,
  an eight-point wing section at seven stations; 3,096 triangles in all, 16 draw surfaces as parts.

## Research files and licences

| file | source | licence | used for |
|---|---|---|---|
| v22_line.svg, v22_line_3840.png | Commons, "Bell Boeing MV-22 Osprey line drawing.svg", Jetijones | CC BY 3.0 | every MEASURED figure |
| v22_6pt.png | Commons, "MV-22 6 point drawing.png", Vega61 | CC BY-SA 3.0 | not used: 403 px |
| nps_coastguard_v22.pdf, nps_cg_page110.png | Commons, NPS thesis, V-22 Program Office diagram | public domain | the ground line |
| nps_training_v22.pdf | Commons, NPS thesis "Planning flight training for the transition to the V-22" | public domain | not used: no drawing |
| nasa_acree_v22_sf04.pdf | NASA Ames rotorcraft publications, Acree 2004 | public (NASA) | the blades' chord and twist |
| wikipedia_v22.wiki | Wikipedia "Bell Boeing V-22 Osprey" | CC BY-SA 4.0 (text) | the published envelope |

## Superseded: the reference model before 2026-09-19

Until 2026-09-19 the Osprey was drawn by `VehicleView._build_wing`'s TILTROTOR branch: five lofted rings for a fuselage,
a box for a wing, box pods, three flat 12.3 m planks for each proprotor that tilted with the nacelle but never turned, a
box tailplane with two box fins, and a nose wheel 1.49 m under the fuselage with no leg (`tests/joined_parts.gd` listed
it as nine of twenty parts adrift). It drew no sponsons, glazing, probe or ramp and had no suite of its own. It is
replaced, not kept beside the new model: the user asked that "the osprey should REPLACE the current tiltrotor".

Its sources were: Boeing's official [V-22 specification](https://www.boeing.com/defense/military-rotorcraft/v-22-osprey),
giving a 17.47 m fuselage length, 11.6 m proprotor diameter, 25.8 m overall width with rotors turning, 6.7 m height with
nacelles vertical, and two flight-deck seats for the MV-22 and CMV-22; and AFMAN 11-420, section 18-18, for the 11.6 m
rotor diameter and the high-wing, twin-tail layout. Boeing's figures agree with [WP]'s to the rounding.
