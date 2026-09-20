# Fairchild Republic A-10C Thunderbolt II visual reference

The runtime exterior is an original procedural model made from Godot primitives
(`objects/vehicles/warthog_airframe.gd`). It contains no downloaded mesh, photograph, texture, trademark or livery.

**It is the A-10C.** The model shows what you notice first on the aircraft:
- the straight, thick, low wing with drooped tips;
- two TF34s in pods high on the rear fuselage;
- twin fins on the ends of a straight tailplane;
- a bubble canopy set high and forward;
- main gear pods on the wing's leading edge, their wheels half out when retracted;
- the nose gear offset to starboard;
- the GAU-8/A's seven barrels under the nose, the cluster to port so the firing barrel is on the centreline.

The C differs from the A in its cockpit and avionics, not its outline.

## The authority for the shape

**[K]** Kaboldy, "Fairchild Republic A-10 Thunderbolt II 3-view.svg", Wikimedia Commons
(<https://commons.wikimedia.org/wiki/File:Fairchild_Republic_A-10_Thunderbolt_II_3-view.svg>), 2013, **CC BY-SA 3.0**.
- It is a vector three-view, 1481 x 1568 units, with the side view along the top (gear up, and the wheels drawn a
  second time below on ground lines), the plan under it, and the front view to its left, turned a quarter.
- It is studied and measured, not incorporated. The runtime model contains nothing from it, so its share-alike term
  does not reach the game.

**[A]** "Fairchild Republic A-10A Thunderbolt II diagram.svg", Wikimedia Commons, US Army (airdefense.bliss.army.mil),
**public domain**.
- It is 574 x 385 and traced coarsely, about 5 to 7 cm a pixel. It was used as a cross-check of proportion only.
- The brief asked for a public-domain three-view first. This is the only one on Commons, and it is too coarse to be
  the primary.

Both are rasterised by Godot's own SVG loader (`Image.load_svg_from_buffer`, [K] at x3 to 4442 x 4705 px) and kept in
`~/godotgames-drafts/2026-09-19/cockpit-warthog/research/`.

**The three views share ONE scale, checked before anything was measured from them:**
- the plan's span and the front view's are both 3,503 px;
- the plan's length is 3,238 px and the side view's 3,237 (0.03 per cent).

The scale is the published span over the plan's: **199.83 px a metre, 5 mm a pixel**.
- The length then comes out at **16.204 m against the published 16.26 (-0.35 per cent)**, a figure the scale was not
  set from.
- **The wing's planform, integrated row by row over the drawing** (the centre section's constant chord carried to the
  centreline), is **46.93 m2 against the printed 47.0 (-0.2 per cent)**. The model's, integrated from its drawn
  vertices by `tests/warthog.gd`, is 46.60.
- Area uses both of the plan's axes and neither of the lengths the scale came from, so it is the check that the
  view is not stretched.

`measure_views.py` re-derives every MEASURED figure in the airframe from [K] alone, reading nothing out of this file.
- The silhouettes and edge fits are computed.
- The interior lines a silhouette cannot see (the canopy frame, the fin and rudder, the aileron and flap spans) are
  HAND PICKS: sheet pixels written in the script, so each can be re-read and disputed.

`overlay_views.py` lays `tests/warthog_shot.gd`'s orthographic silhouettes, rendered at [K]'s own 199.83 px a metre,
over the drawing at x1.000 on a stated datum.

## The envelope, published

**[WP]** Wikipedia, "Fairchild Republic A-10 Thunderbolt II", its A-10C specifications:
- length **53 ft 4 in (16.26 m)**, span **57 ft 6 in (17.53 m)**, height **14 ft 8 in (4.47 m)**;
- wing area 506 sq ft (47.0 m2), NACA 6716 root and 6713 tip;
- empty 24,959 lb (11,321 kg), gross 30,384 lb (13,782 kg), maximum 46,000 lb (20,865 kg);
- two TF34-GE-100A of 9,065 lbf (40.32 kN);
- maximum speed 381 kt at sea level clean; cruise 300 kt; stall 120 kt at 30,000 lb; climb 6,000 ft/min.

**[GAU]** Wikipedia, "GAU-8 Avenger":
- seven barrels; "a fixed rate of 3,900 rpm" (the original gun's 2,100 and 4,200 settings were changed by TO
  1A-10A-1);
- muzzle velocity 1,013 m/s (API), 1,174 rounds in the magazine;
- "mounted laterally off-center, slightly to the port side of the fuselage centerline, with the active firing barrel
  lying directly on the aircraft's centerline", "bore-sighted along a line 2 degrees below the aircraft's line of
  flight", and "the front landing gear, which is mounted slightly off-center on the starboard side of the nose".

## Measured off [K], at 199.83 px a metre

Stations are metres aft of the GAU-8's muzzle, [K]'s foremost point. Heights are metres over the **belly datum**, the
flat of the belly under the wing (sheet row 685).

| | measured | model |
|---|---|---|
| Muzzle to the tail cone | 16.204 m | 16.205 m drawn |
| Span, front view | 17.53 m (3,503 px, as the plan) | 17.528 m drawn |
| Wing centre section | CONSTANT CHORD: leading edge 6.84 on all 30 plan rows from 0.8 to 2.2 m out, trailing edge median 9.90 on the rows from 2.4 to 3.0; 3.06 m of chord; flat in the front view | the same, flat, to the break at 2.95 m out |
| Wing outer panels, leading edge | station 6.598 + 0.1056 x out, 250 rows each side, 3.2 to 8.2 m out, 16 mm rms | the same line |
| Wing outer panels, trailing edge | station 10.097 - 0.0653 x out, 7 mm rms: a taper from 2.99 m of chord at the break to 2.10 at 8.2 m out | the same line; taper 0.70 read back |
| Wing heights, front view | flat centre section; outboard the middle rises 0.114 a metre (6.5 degrees) to 0.89/1.28 at 8.2 m | the same; 6.5 degrees read back |
| Wing thickness | the front view's centre section is 0.69 m deep, 22 per cent of its chord, but that is the section, its incidence and the flap tracks seen end on | [WP]'s NACA 6716 at the root and 6713 at the tip |
| Drooped tips | 8.4 m out: 0.92 to 1.30; 8.6: 0.88 to 1.18; the planform rounds from 8.39 m out at 7.5 to 8.765 at 8.5 | a three-step tip whose middle falls to 0.93, 0.19 m under the panel's line |
| Fuselage | side view's top and bottom and plan's half-width every 0.25 m (0.69 m either side from 2.25 to 9.75) | 14 facets a ring through them |
| Canopy | windscreen foot 1.64 (1.32 up), frame 2.92 (1.42), bubble's aft point 4.80, 0.47 m either side at its widest | the same |
| Nacelles | front view: fan circles 1.47 m out, 1.63 up, 0.76 radius; plan: outer edge 2.20 m out from 10.0 to 12.25; lip 9.59 | 12 facets a ring through them |
| Gear pods | plan 2.25 to 2.91 m out; nose 5.86; bottom -0.24; the stowed wheel's bottom -0.56 under the datum | the same |
| Tailplane | 14.12 to the elevators; edge-on 0.62 m up; 2.98 m either side; elevators to 15.85 | the same |
| Fins | 2.84 m out, the plan's 2.75 to 2.93; leading edge (13.79, 0.43) to (14.19, 2.88); top 3.05; rudder hinge (15.09, 3.03) to (15.31, 0.33) | the same |
| Ailerons | 5.08 to 7.98 m out, hinge 8.68 | the same, split into two halves |
| Flaps | outer 2.87 to 4.93 m out, hinge 8.70; inner 0.75 to 2.80 | the same |
| Gun | the stippled muzzles -0.18 to -0.01 m out, 0.17 to 0.24 up | a 0.075 m circle of barrels 0.075 m to port, 0.21 up |
| Hardpoints | front view stubs at 1.6, 3.6, 4.8 and 5.9 m out each side, and three under the belly | eleven slabs |
| Fin tip over the datum | 3.063 m | 3.06 |

**The overlays agree over 96.1 per cent of the two silhouettes' union from the side, 96.0 in plan and 77.3 from the
front** (`overlay_views.py`).
- The front's shortfall is the main gear, the drooped tips' curl, and the wing's depth: the model is built to the
  published NACA sections, 0.49 m deep at the root, where the drawing's end-on depth is 0.69 (85.0 per cent with the
  drawing's depth, before the published sections replaced it).
- **[K]'s own two views disagree about the main wheels**: from the front they are inside their pods (the lowest point
  3.30 m under the fin tips); from the side they are 0.36 m out of the pods (3.62 m under).
- The model follows the side view, which agrees with photographs of A-10s with the gear up. The front overlay is laid
  on the fin tips, which both views agree on.

## The height

The published 4.47 m is to the fin tip WITH THE GEAR DOWN.
- [K] draws the gear up, and draws the wheels a second time on ground lines 1.536 m under the datum. That stands the
  fin tip 4.60 m up, 2.9 per cent over [WP].
- [K]'s wheels are also too big: circles 1.006 and 0.691 m across against the A-10's 36 x 11 and 24 x 7.7 in tyres
  (0.91 and 0.61 m).
- **The model is built to the published height**: the ground is 1.41 m under the datum, and the real tyres stand on it.
- That makes the height a figure the model is built to, not one it can be checked against. `tests/warthog.gd` checks
  the tyres against the ground instead, and prints the height (4.46 m).

## The gear, partly ESTIMATE

The axles' stations with the gear down are [K]'s wheel circles: 8.21 for the mains and 3.06 for the nose.

- **The mains fold FORWARD through 90 degrees into their pods, and stay half out** [WP, K side view]. The stowed wheel
  is [K]'s bulge under the pod at 6.72, its bottom 0.56 m under the datum. The pivot is where the two axles are equally
  far, 7.88 and 0.20 m up. There are no main well doors.
- **The nose leg is 0.40 m to starboard** (ESTIMATE). The plan's nose fairing stands 0.78 m out against the fuselage's
  0.69 either side. The leg folds forward through 90 degrees into a well from 1.35 to 3.35.
  - The well has two doors, hinged on their outer edges. They stop short of 3.35, where the leg leaves the belly: a door
    that shuts after the gear is down cannot shut across the leg (lane/lightning). The leg's own door, on the back of
    its strut, faces down when the gear is up.
- The cycle is lane/lightning's shares: nose doors open over the first fifth, the legs travel over the middle three,
  the doors shut over the last. The time is `GEAR_SECONDS`, 6 s, the user's to adjust.

## The wing's other parts, ESTIMATE

- **The leading-edge slats**, on the inner end of each outer panel, 3.05 to 4.70 m out and 14 per cent of the chord
  deep, from photographs. [K] draws the panel's leading edge as a double line along its whole length and does not say
  where the slat ends. They are drawn retracted.
- **The flaps are slotted**: hinged under the wing, so turning down opens a slot between them and the wing's upper skin.
  Their spans are [K]'s panel lines (hand picks).

## The rest, ESTIMATE

- **Travels**:
  - ailerons 25 degrees each way;
  - each deceleron half 40 degrees open (80 in all);
  - flaps 20 degrees fully down, with the manoeuvre setting's 7 at 0.35;
  - elevators and rudders 25 degrees.
  No A-10 rigging table could be read.
- **The paint**: the A-10C's greys, FS 36118 on top and a lighter grey under it. No markings.
- **The eye**: 0.32 m under the bubble's top at station 3.30, 1.95 m up.
- **Tessellation**: 14 facets a fuselage ring, 12 a nacelle ring, 8 a gear pod ring and a tyre, 6 a gun barrel;
  3,176 triangles in all.

## What would settle the estimates

- An A-10 flight manual's control surface travel table (TO 1A-10C-1, section 1). It is not freely readable.
- A true broadside photograph of a parked A-10, with the nose leg's lateral offset measured from the front.

## Research files and licences

| file | source | licence | used for |
|---|---|---|---|
| a10_3view_kaboldy.svg / .png | Kaboldy via Commons | CC BY-SA 3.0 | every MEASURED figure, studied only |
| a10a_diagram_army.svg / .png | US Army via Commons | public domain | proportion cross-check |
| a10.wiki, gau8.wiki | Wikipedia's article text, fetched raw | CC BY-SA, quoted for figures only | [WP], [GAU] |
