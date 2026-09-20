# Lockheed P-38L Lightning visual reference

The runtime exterior is an original procedural model made from Godot primitives
(`objects/vehicles/p38_airframe.gd`, on the shared kit `objects/vehicles/warbird_airframe.gd`). It contains no
downloaded mesh, photograph, texture, trademark or livery.

**It is the P-38L**, the last and most numerous Lightning. The model shows what you notice first on the aircraft:
- the two booms, each an Allison in a nacelle with its turbocharger's hood and turbine wheel on top and its radiators'
  cheeks behind the wing, ending in an oval fin and rudder;
- the short central gondola with the guns in its nose and the canopy on top;
- the flat centre section and the tapered outer panels rising from the wing joint;
- the tailplane and elevator between the booms' ends;
- the tricycle gear: the nose leg folding aft into the gondola, the mains aft into the booms;
- the two three-bladed propellers turning **opposite ways**, their blades rising outboard, away from the gondola.

There is no P-38 kind yet (lane/warbirds step 3, 2026-09-19): the airframe is drawn, and dresses from its own draft box.

## The authorities for the shape

**[AN]** the USAAF's three-view from AN 01-75FF-2 p.2: "Lockheed P-38L Lightning 3-view line drawing.png", Wikimedia
Commons (<https://commons.wikimedia.org/wiki/File:Lockheed_P-38L_Lightning_3-view_line_drawing.png>), 1929 x 2362 px,
**{{PD-USGov-Military}}**. It is the most heavily dimensioned of the four sheets: the span, the half-span, the length,
the booms' 96 in either side, the track, the tailplane, the propeller, the root chord, the stations of the propeller, the
wing's leading edge, the aileron and the wing joint, the tyres, the dihedral and the static ground's angle are all
printed on it.

**[TM]** the P-38 Pilot Training Manual (archive.org, public domain): "the right propeller turns clockwise and the left
counter-clockwise, seen from the cockpit".

**[WP]** Wikipedia, "Lockheed P-38 Lightning", its P-38L specifications: 37 ft 10 in (11.53 m) long, 52 ft (15.85 m)
span, 9 ft 10 in (3.00 m) high.

The drawing is study material, kept in `~/Desktop/godotgames-drafts/2026-09-19/cockpit-warbirds/research/` and not in the
repo.

## Reading the sheet

**The sheet has no dimension-free copy.** Each view is FENCED by a hull drawn by hand a few pixels outside the aeroplane
(`tools/three_view.py`), the scan's gaps are closed by growing the ink 2 px before the fill, and the pen's stubs are opened
off. Two things this sheet needed that the others did not:
- **THE PLAN'S RING.** The booms, the tailplane and the wing close a ring round the space between the booms, which no
  fill from the border reaches: it came out solid. `solid()` takes `holes`, points in white the aeroplane encloses.
- **THE VIEWS ARE TURNED ON THE SHEET, each by its own amount.** The plan is turned 0.92 degrees: read square, its two
  wings' edges agree to 1 to 3 cm, where unturned they are 12 px apart at the tips. The front is square as scanned: its
  spinners' circles are level to 0.2 px over 452. Its fins lean 0.8 degrees, and turning by them made the two outer
  panels' dihedral 5.53 and 4.21 degrees where unturned they are 4.76 and 5.00, so the fins are drawn leaning.
- **The side's turn is the one open question.** Its dash-dot reference and thrust lines lean 0.44 degrees (one slope
  through 19 dashes, rms 0.4 px, 12.1 px apart for the printed 5.078 in). But read square by them, the tail stands 6 cm
  higher than two printed figures. Read at 0.85 degrees, both agree: the boom's top under the tailplane 0.41 to 0.42 m
  over the reference line against the tailplane's printed 0.407, and the fin 3.006 m over the static ground against the
  printed 9 ft 10-3/8 in, 3.007. The model uses 0.85. The sheet's NOTE 2 turns the empennage 1 deg 15 min on purpose,
  and the lines may have been laid by it; `measure_views.py` prints both readings.
- **The side view overlaps the gondola and the near boom**, so it is used whole: for the length, the fin, the tyres and
  the overlay. The gondola's and the booms' own sections come from the plan and the front.

## Each view has its own scale

**The plan is scaled by its printed 52 ft span: 94.07 px a metre.** At that scale:
- the tailplane is 6.612 m against its printed 261 in, 6.629 (-0.3 per cent);
- the booms' middles are 4.842 m apart against the printed 2 x 96 in, 4.877 (-0.7 per cent).
The model is built to the printed booms, and `tests/p38.gd` holds them to 5 mm: at 2 cm a model built to the drawing
passed, and the mutant that does exactly that goes red.

**The side, 94.97 px a metre** by its printed 37 ft 9-15/16 in (+0.95 per cent on the plan). The heights are read at the
same scale, since nothing printed says otherwise, and they agree with the printed height above.

**The front, 93.52 px a metre** at the printed span foreshortened by the printed dihedral. Its outer panels' middles rise
4.88 degrees (42 columns, rms 9.7 mm) against the printed 5 deg 40 min; the model is built to the printed figure.

## Datum and axes

- Stations are metres aft of the gondola's nose; heights are metres over the fuselage reference line; out is metres to
  starboard. The thrust line is printed 5.078 in (0.129 m) under the reference line.
- [AN] draws the reference line level and the static ground raked under it, nose low. The model is built level, the
  box's floor the main tyres' bottom, 1.917 m under the reference line; `ground_at` is the static ground through the
  drawn tyres.
- **The static ground through the drawn tyres is raked 5.00 degrees** against the printed 5 deg 33 min 46 s. The
  circles are fitted to the dashes at rms 1.6 px; the printed angle would need the nose tyre 3 cm lower or the mains 3 cm
  higher than drawn. The suite allows a degree, and says which it read.

## What is measured, and against what

| | the model | against |
|---|---|---|
| length | 11.530 m | printed 37 ft 9-15/16 in, 11.530 |
| span | 15.850 m | printed 52 ft 0 in |
| fin's top over the static ground | 3.006 m | printed 9 ft 10-3/8 in, 3.007 |
| propeller arc's top over the static ground | 3.77 m (12 ft 4-1/2 in) | the user's 12 ft 10 in, 3.912 (-3.5 per cent; see below) |
| booms' middles | 2.438 m either side | printed 96 in; drawn 2.414 and 2.428 |
| track | 5.030 m | printed 198 in, 5.029 |
| tailplane | 6.628 m | printed 261 in, 6.629 |
| static ground's rake | 5.00 deg | printed 5 deg 33 min 46 s |
| wing, 1.0 / 4.0 / 7.5 m out | 3.003-5.639 / 3.258-5.134 / 3.577-4.422 | [AN] plan, both halves averaged |
| dihedral | flat to the joint 2.921 m out, then 5 deg 40 min | printed; the front draws 4.88 |
| propellers | 3.512 m across, at station 1.572 | printed 11 ft 6 in, 3.505, and 61.875 in |

**Laid over the drawing at x1.000** (`overlay_views.py`, the silhouettes at 94.07 px a metre, gear up since [AN] draws it
dashed, the propellers left out, the datum the gondola's nose on the reference line), **the plan agrees over 95.6 per
cent, the side over 87.6 and the front over 63.5.** From ahead the sheet's thin tailplane is opened off with the pen's
stubs, and its fins are drawn about 0.15 m shorter than its own side view draws them; the model's fins are the side's.

## The gear

- **The tyres** are the printed 36 in mains and 27 in nose tyre. Their drawn dashed circles put the main axles at station
  4.366, 1.460 m under the reference line, and the nose axle at 1.351, 1.838 under.
- **The mains** pivot in the booms at station 4.30, 0.30 m under (ESTIMATE), and fold AFT, the wheel standing upright on
  the boom's own centreline at station 5.44. The stowed point only aims the leg, which keeps its length: aimed low or 2 cm
  outboard, the tyre's lower shoulder stood 1.4 cm out through the boom's sloping lower facet, and `tests/p38.gd`
  found every such vertex by ray parity.
- **The main doors** are two per boom, hinged along the well's edges 0.28 m either side of the boom's middle. At 0.20 m
  the tyre's outer face swung through the outer door at 34 to 38 per cent of the cycle.
- **The nose leg** pivots at station 1.20, 0.50 m under (ESTIMATE), and folds AFT into the gondola behind two doors.
- **The VAT samples the gear cycle 257 times**, not 33: at 33 the doors sagged 1.88 mm between samples, over the
  suite's 1 mm.

## What moves, and its travel

| surface | travel | source |
|---|---|---|
| ailerons | 15 deg each way | ESTIMATE |
| elevator | 28 up, 20 down | ESTIMATE |
| rudders | 25 each way | ESTIMATE |
| flaps | 45 down | ESTIMATE |
| propellers | opposite ways, outboard at the top | [TM]; 83 VAT rows, from the hub's distance |

- The ailerons run from the printed 182 in out to 107 in beyond, hinged at 70 per cent of the chord (the plan's printed
  "hinge at 70% C").
- The flaps have the printed 23.5 in chord. The inner flap runs from the gondola to the boom, the outer from the boom to
  the aileron.
- The flaps and ailerons are lofted through every row of the wing they span, so their trailing edges are the wing's. The
  outer flap lofted between its ends only stood 6 cm inside the drawn edge 4.0 m out, and its mutant goes red.
- One elevator spans boom to boom, hinged 20 in behind the tailplane's leading edge (printed).

## Outstanding, with what would settle it

- **The side's turn**, 0.85 or 0.44 degrees; see above. A second dimensioned side view would settle it.
- **The static ground's rake**, 5.00 degrees through the drawn tyres against the printed 5.56.
- **The pilot's eye, the seat and the cockpit's room** are step 5's.

## The two heights the user gave (2026-09-19)

"The height of the Lockheed P-38 Lightning is 9 feet 10 inches from the ground to the tail fin, and 12 feet 10 inches from
the ground to the tip of the propeller arc." Both are held by `tests/p38.gd`:
- **the fin, 9 ft 10 in:** the sheet's printed 9 ft 10-3/8 in (3.007 m), which the model stands at 3.006. The two agree, and
  the question the previous lane parked (the user had once said 12 ft 10 in for the height) is closed: that figure was
  the propeller arc's.
- **the propeller arc, 12 ft 10 in (3.912 m):** the model's arc, every drawn blade vertex turned through a revolution,
  stands 3.77 m (12 ft 4-1/2 in) over the static ground, 3.5 per cent under. It is the sheet's own printed 11 ft 6 in
  propeller, at its printed 5.078 in under the reference line, on its printed 36 in and 27 in tyres: the hub is 2.025 m
  over the static ground, and 3.91 would need it 14 cm higher than those printed tyres allow. The check holds "about
  12 ft 10 in" to 4 per cent and prints both. The model is not stretched for it: the fin, the tyres and the propeller
  are all printed on one sheet that agrees with itself.
