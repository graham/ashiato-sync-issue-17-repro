# North American P-51D Mustang visual reference

The runtime exterior is an original procedural model made from Godot primitives
(`objects/vehicles/p51_airframe.gd`, on the shared kit `objects/vehicles/warbird_airframe.gd`). It contains no
downloaded mesh, photograph, texture, trademark or livery.

**It is the P-51D**, the bubble-canopy Mustang. The model shows what you notice first on the aircraft:
- the long nose with its four-bladed Hamilton Standard propeller and the chin intake under the spinner;
- six exhaust stacks a side;
- the bubble canopy;
- the straight, tapered laminar-flow wing, set low, with its root extension;
- the radiator scoop under the belly behind the wing;
- the tall fin with its dorsal fillet;
- the wide-tracked main gear folding inward into the wing's root, and the tail wheel folding forward.

There is no P-51 kind yet (lane/warbirds step 1, 2026-09-19): the airframe is drawn, and dresses from its own draft box.

## The authority for the shape

**[AN]** the USAAF's own three-view, AN 01-60-3 p.30 (1945), after North American drawing 106-00001:
"North American P-51D Mustang 3-view line drawing.png", Wikimedia Commons
(<https://commons.wikimedia.org/wiki/File:North_American_P-51D_Mustang_3-view_line_drawing.png>), 1905 x 2489 px,
**{{PD-USGov-Military}}**, with its printed dimensions; and the same sheet with the dimension lines taken out,
"North American P-51D Mustang 3-view line drawing (no specs).png"
(<https://upload.wikimedia.org/wikipedia/commons/7/7f/North_American_P-51D_Mustang_3-view_line_drawing_(no_specs).png>),
2489 x 1905 px, the same licence.
- The silhouettes are read off the clean sheet, since a dimension line across an outline lets no flood fill tell
  inside from out. The printed figures and two reference lines are read off the dimensioned one; its side view is the
  clean sheet's to a pixel (the fin stands 213 px over the spinner's tip on both).
- Both are study material, kept in `~/Desktop/godotgames-drafts/2026-09-19/cockpit-warbirds/research/` and not in the
  repo.

**[WP]** Wikipedia, "North American P-51 Mustang", its P-51D specifications (after AN 01-60JE-2):
- length **32 ft 3 in (9.83 m)**, span **37 ft 0 in (11.28 m)**, height **13 ft 4-1/2 in (4.08 m)** tail down with a
  propeller blade vertical;
- wing area 235 sq ft (21.8 m2), empty 7,635 lb, gross 9,200 lb, max 12,100 lb; 440 mph; stall 100 mph;
- the Packard V-1650-7; the propeller four-bladed, 11 ft 2 in.

**Cross-checks read, not incorporated:** the P-51D-5 pilot's manual, AN 01-60JE-1 (archive.org, public domain), which
gives 13 ft 8 in tail down (4.17 m) and 96 mph IAS stall gear and flaps down; NACA's rudder report (NTRS 20050019329),
which gives 240 sq ft of wing, 5 degrees of dihedral and the rudder's 30 degrees.

## Each view has its own scale, and the heights are drawn short

**Scale each view by its own printed dimension, and check it on one it was not set from** (`learnings/2026-09-19-liners.md`):
- **The plan** by its printed span, 37 ft 0-5/16 in (11.286 m): **123.88 px a metre**. The length then comes out
  9.808 m against the printed 9.838 (-0.30 per cent), and the tailplane 4.052 m against its printed 4.016 (+0.90).
- **The side** by its printed length, 32 ft 3-5/16 in (9.838 m): **122.49 px a metre along it**, 1.1 per cent under
  the plan's.
- **The side's heights by its printed heights**: the fin's top 69-9/16 in over the fuselage reference line and the level
  ground line 76-1/2 in under it, 146-1/16 in from one to the other, read on the dimensioned sheet: **119.27 px a
  metre up**, 2.6 per cent under the side's own length.
- **The front** by its span over the 5-degree dihedral: **124.08 px a metre across**, and its heights at the side's
  119.27. Its printed track, 142 in, comes out 3.575 m at that scale (-0.9 per cent).

**THE SHEET IS NOT STRETCHED; ITS HEIGHTS ARE DRAWN SHORT OF ITS OWN FIGURES.** The front view's dashed propeller disc,
a compass circle, fits an ellipse 201.74 px across and 201.39 up (0.2 per cent), so the reproduction is round. The two
printed heights still agree with each other that the side's heights are drawn at 119.3 px a metre, not 122.5. Two
more readings sit either side of it:
- the canopy's top, printed 36-1/2 in (0.927 m) over the thrust line, reads 0.943 at 119.27 and 0.918 at 122.49;
- **the published height tail down is the third quantity nobody set out to produce**: the model built to 119.27 stands
  **4.116 m** over the three-point ground against [WP]'s 4.08 (+0.9 per cent). At 122.49 it would be about 4.02
  (-1.5).
- The model is built to the printed heights, and this is the one measurement on the sheet whose scale is argued rather
  than read.

**AND THE DRAWN PROPELLER IS SMALL.** Its disc is 3.247 m across at the span's scale against the printed 11 ft 2 in
(3.404 m), -4.6 per cent. The model's is the printed one.

`measure_views.py` re-derives every MEASURED figure in the airframe from the two sheets alone, reading nothing out of
this file:
- the silhouettes, edge fits and circle fits are computed;
- the interior lines a silhouette cannot see (the canopy's frame, the hinge lines, the fin's outline, the gun muzzles)
  are HAND PICKS: sheet pixels written in the script, so each can be re-read and disputed.

`overlay_views.py` lays `tests/warbirds_shot.gd`'s silhouettes (123.88 px a metre, gear down, the propeller left out)
over the drawing at x1.000. Each view of the drawing is resampled to that scale by its own two scales, and laid on its
datum: the spinner's tip from the side and above, the propeller's axis from ahead. Nothing is fitted. **The side agrees
over 96.4 per cent of the two silhouettes' union, the plan 96.3, and the front 65.4, or 76.9 outside the propeller's
disc.** From ahead the wing is 20 to 45 px deep, and the pen is 3 px each side of it; the fin and the tailplane's tips
are the rest.

## Datum and axes

- Stations are metres aft of the spinner's tip; heights are metres over the thrust line; out is metres to starboard.
- The thrust line is the spinner tip's row. [AN] draws two lines within 6 px (0.05 m) of each other there, "THRUST"
  and the fuselage reference line, and the spinner's tip is on the upper.
- **[AN] draws the aeroplane LEVEL and rakes the ground under it** at the printed ground angle, 13 deg 36 min. The
  model is built level on the main tyres. The box's floor is the main tyres' bottom, 2.00 m under the thrust line (the
  side view's fitted tyre circle: its centre 1.649 under, 0.70 m across). `P51Airframe.ground_at(station)` is the
  three-point ground through both tyres' bottoms, **13.07 degrees** from the two fitted circles against the printed
  13.60.
- The printed level ground line is 76-1/2 in (1.94 m) under the reference line; the drawn tyre's circle crosses it by
  0.06 m.

## What is measured, and against what

| | the model | against |
|---|---|---|
| length | 9.820 m drawn | printed 9.838, [WP] 9.83 |
| span | 11.284 m | printed 11.286, [WP] 11.28 |
| height tail down, a blade vertical | 4.116 m | [WP] 4.08 |
| main tyre track | 3.607 m | printed 142 in |
| three-point rake | 12.99 deg (model), 13.07 (drawing) | printed 13 deg 36 min |
| tailplane span | 4.020 m | printed 4.016 |
| wing leading edge | 2.687 + 0.0671 x out, 340 port rows, 6.4 mm rms | -- |
| wing trailing edge | 5.416 - 0.1886 x out, both wings, 2.7 and 2.5 mm rms | -- |
| dihedral | 5.67 deg, the front's middles 2.0 to 5.4 m out | printed 5 |
| wing area | 22.63 m2 (model), 22.44 (drawn planform) | [WP] 21.8, NACA 22.3 |
| MAC | 2.10 m (drawn) | printed 79.60 in, 2.02 |
| scoop's bottom | 1.170 m under the thrust line | side 1.17, front 1.165 |
| canopy's top | 0.943 m over | side at its heights |
| fin's top | 1.775 m over | side 1.782 |
| six .50s | 2.06, 2.23, 2.41 m out, 0.286 under | front view's muzzles |

**The wing's chords are [AN]'s as drawn, and they are 3.4 per cent over the MAC printed on the same sheet** (2.10 m
drawn against 79.60 in). The planform integrates to 22.4 m2, against [WP]'s 21.8 and NACA's 22.3. The model is built as
drawn, and a drawn chord 3 per cent fat is not visible from a cockpit.

**The wing's thickness** falls from 16.5 per cent of the chord at the root to 12.5 at the tip. The front view's depths
at 2.0 and 5.0 m out are 16.6 and 14.5 per cent as drawn, 15.5 and 12.8 less the pen. The side view puts the root's
lower skin 0.78 to 0.82 m under the thrust line: 15.5 per cent missed that by 4 cm, 16.5 meets it. [WP] names the
section NAA/NACA 45-100.

## The gear, and where the model departs from the drawing

- **The main tyres** are 0.70 m across (the drawn circle; the P-51D's 27-inch tyre is 0.686), their axles 1.804 m either
  side at station 2.747.
- **The legs** stand upright (the front view draws them so) under pivots at the front spar, 0.50 m under the thrust
  line at station 2.95 (ESTIMATE). They fold inward through a quarter turn, each wheel lying flat in the wing's root at
  0.69 m out, station 3.40, with its fairing turned down to close the well.
- **[AN]'s plan draws the stowed wheels as dashed circles at station 3.13, 0.37 and 0.44 m either side. The model
  cannot put them there.** A wheel that lies flat after a quarter turn stows at its pivot's height, a leg's length
  inboard. A leg long enough to reach 0.4 m out would pivot 0.25 m under the thrust line, over the wing's upper skin.
  And at station 3.13, and again at 3.25, the tyre's front lay where the laminar root is thin: the first pictures from
  below showed both tyres through the skin, and `tests/p51.gd` now holds every stowed tyre vertex inside it. The real
  aircraft's root is deeper there than a laminar section scaled from the front view.
- **The inner doors** under the belly, hinged 0.02 m either side of the centreline, open for the legs and shut behind
  them.
- **The tail wheel** is 0.31 m across (the drawn circle; 12.5 in is 0.318), at station 7.874, 0.667 m under the thrust
  line. It retracts forward about a pivot at 7.60 (ESTIMATE). Its two doors open as it comes down and stay open, as
  [AN] draws them.

## What moves, and its travel

| surface | travel | source |
|---|---|---|
| ailerons | 15 deg each way | printed "10, 12 or 15 deg max" beside the wing, the largest taken; the sheet names neither which way nor which rigging |
| elevators | 30 up, 20 down | printed |
| rudder | 30 each way | printed; NACA's rudder report agrees |
| flaps | 47 down | printed |
| propeller | clockwise seen from the cockpit | the Merlin's; a VAT row count worked out from the hub's distance, 60 rows |
| gear | inner doors, legs, inner doors; tail doors open while down | -- |

Hinge lines, off [AN]'s plan: the flaps and ailerons share one straight line, station 4.80 - 0.108 x out (flap 0.51 to
3.30 m out, aileron 3.31 to 5.40). The elevators' hinge is 8.745, straight (plan 8.743, side 8.760). The rudder's is
9.21, upright.

## What stays authoritative whatever the model does

The simulation's geometry, mass, handling, stations and wire, once there is a kind; until then the draft box
(`P51Airframe.draft()`). The published envelope and the printed figures are held by `tests/p51.gd` against the drawn
vertices, and `craft/p51/mutants.py` turns each check red with the bug it exists to catch (8 of 8).

## Outstanding, with what would settle it

- **The side view's vertical scale.** The printed heights say 119.3 px a metre; the round compass circle says the
  sheet is not stretched. A second dimensioned drawing, an E&M manual's station diagram (AN 01-60JE-2, not free), would
  settle whether the heights or their figures are wrong.
- **The pilot's eye, the seat and the cockpit's room**: no station diagram is free. They are step 5's, with the view
  checks (over the nose, screens facing the eye, the hollow nose).
- **The P-51's parked attitude**: the model is drawn level on its mains, and the simulation will decide how a
  taildragger sits.
