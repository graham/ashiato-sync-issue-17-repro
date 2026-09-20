# Boeing 737-800W visual reference

Kind `airliner` is drawn as a Boeing 737-800 with blended winglets (the -800W) since 2026-09-19 (`lane/liners`), by
`objects/vehicles/boeing737_airframe.gd` (the table) and `objects/vehicles/jetliner_airframe.gd` (the drawing, shared with
the 747). The runtime exterior is an original procedural model made from Godot primitives. It contains no downloaded mesh,
photograph, texture, trademark, airline livery or line of any drawing.

**Why the -800W**: it is the 737 there are most of, and it is the one Boeing's own dimensioned drawing shows.

## The authority for the shape

**[ACAPS]** Boeing, *737 Airplane Characteristics for Airport Planning*, D6-58325-7 Rev C, October 2025, published by
Boeing for airport planners at
`https://www.boeing.com/content/dam/boeing/v2/airports/acaps/737NG_REV_C.pdf` (the older
`.../boeingdotcom/commercial/airports/acaps/737.pdf` link returns 404). Copyright Boeing; **used to MEASURE, not
incorporated**. The pages used:

- **2.2.6, "General Dimensions: Model 737-800W, BBJ2, -800BCF"** (page index 34): plan, side and front views at one scale,
  drawn as VECTORS, the aeroplane alone in blue. Printed on it: length 129 ft 6 in (39.47 m), span 117 ft 5 in (35.79 m),
  height 41 ft 2 in (12.55 m), fuselage 12 ft 4 in (3.76 m), tailplane 47 ft 1 in (14.35 m), wheelbase 51 ft 2 in (15.60
  m), nose gear 13 ft 5 in (4.09 m) aft of the nose, track 18 ft 9 in (5.72 m), the engine's centreline 15 ft 10 in (4.83
  m) out and its inlet 43 ft 10 in (13.36 m) aft, the wing tip's trailing edge 85 ft 4 in (26.01 m) aft.
- **2.3.3, ground clearances, -800W**, operating empty weight (max) and maximum taxi weight (min): top of fuselage 5.56 /
  5.41, entry door 1 sill 2.74 / 2.59, forward cargo door 1.45 / 1.30, engine 0.64 / 0.48, wingtip 6.76 / 6.50, aft cargo
  door 1.80 / 1.65, entry door 2 3.12 / 2.97, stabiliser 5.64 / 5.49, vertical tail 12.62 / 12.37, bottom of winglet 4.32
  / 4.06 m.
- **2.1.3**, the -800W: operating empty weight 41,412 kg, maximum take-off 79,015 kg, maximum landing 66,360 kg.
- **7**, tyres: nose 27 x 7.75-15 (0.686 m), mains H44.5 x 16.5-21 (1.13 m).

**[WP]** Wikipedia, "Boeing 737 Next Generation": fuselage 3.76 m wide and 4.01 m tall.

**[SC]** "Boeing 737 family v1.0.png", Julien.scavini, Wikimedia Commons, CC BY-SA 3.0: the -800's side view with its
printed 39m50 and 12m50, the NG plan and front. An INDEPENDENT drawing, studied as a cross-check, not measured into the
model: its own scale bar (21.3 px a metre) and its printed length (21.46) agree to 0.8 per cent, but its fin tip reads
12.12 m against its own printed 12.50, so its heights are not good to better than 3 per cent.

## Measured off [ACAPS] 2.2.6

`measure_views.py` re-derives every figure from the PDF alone (it redraws the page from its blue paths, `acaps.py`).
**One published number sets the scale**: the length, 39.47 m, over the plan's 2,963 px at 600 dpi, **75.07 px a metre,
13 mm a pixel**. The outline is a stroke 0.12 m thick, and the silhouettes are to its outer edge.

| cross-check (not used to set the scale) | measured | printed | |
|---|---|---|---|
| span, plan | 35.833 m | 35.79 | +0.12% |
| span, front | 35.793 | 35.79 | +0.01% |
| length, side | 39.363 | 39.47 | -0.27% |
| fin tip over the ground, side | 12.602 | 12.55 | +0.41% |
| wing tip's trailing edge aft of the nose | 25.989 | 26.01 | -0.08% |
| wheelbase | 15.512 | 15.60 | -0.56% |
| nose gear aft of the nose | 4.156 | 4.09 | +1.62% |
| main gear track, front | 5.64 | 5.72 | -1.4% |
| engine centreline out, plan | 4.87 | 4.83 | +0.8% |
| tailplane span, plan | 14.480 | 14.35 | +0.91% |

| shape | measured |
|---|---|
| wing leading edge, 6.0 to 15.5 m out | station 14.583 + 0.5152 x out, 475 rows a side, rms 4.4 mm: **27.26 degrees** |
| wing leading edge, inboard of the kink at 5.67 m out | 0.70 a metre (35 degrees), 14.93 at 2.0 m out |
| wing trailing edge | 21.47 square across to 5.5 m out; then 19.889 + 0.2881 x out (16.07 degrees, rms 4.0 mm) |
| wing lower surface, front, 7 to 16.5 m out | height 1.263 + 0.1092 x out: **6.2 degrees** of dihedral |
| tailplane leading / trailing edge | 32.649 + 0.7193 x out (35.73 degrees) / 37.146 + 0.3190 x out; tip 7.24 m out |
| tailplane, front | its silhouette's middle 4.37 m up at 1.8 m out to 5.13 at 7.0 (8.3 degrees) |
| fin leading / trailing edge, side | 28.016 + 0.7302 x height (36.1 degrees) / 36.011 + 0.2012 x height |
| dorsal fillet | 28.60 at the crown to 32.90 at 6.7 m up |
| nacelle | plan 3.68 to 6.05 m out, inlet lip 13.28; side 0.32 to 2.22 m up; cowl to 16.3, nozzle 17.1, plug 18.1 |
| winglet, front | 16.98 to 17.34 m out at 4.4 m up, 17.64 to 17.88 at 6.1, top 6.2 |

The model's silhouettes, rendered by `tests/liners_shot.gd` at the drawing's own 75.07 px a metre and laid over it by
`overlay_views.py` at x1.000, agree over **96.3 per cent** of their union in plan, **88.0** from the side and **63.2** from the
front. The side's shortfall is the 0.25 m raise below, which the overlay is aligned to SHOW rather than fit away. The
front's is mostly the thin wing and winglet edges, where a 0.25 m shift of a 0.3 m-deep silhouette halves its overlap,
and the nacelles, drawn at their measured size and raised with the body.

## Two disagreements, and what was done

1. **The fuselage's width.** The plan's outline is 3.97 m across and the front's 3.66: the drawing's two views disagree
   by 8 per cent, either side of the printed 3.76, which the plan's own dimension arrows span. The model is 3.76 wide
   ([WP] and the printed figure); the plan's taper is kept by scaling its half-widths by 3.76 / 3.97.
2. **The body's height over the ground.** Against the mean of 2.3.3's two columns, the drawing's own features sit LOW by
   a nearly constant amount: entry door 1's sill by 0.245 m (drawn 2.42, table 2.665), the forward cargo door's by 0.245
   (1.13 / 1.375), the engine's lowest point by 0.24 (0.32 / 0.56) and the stabiliser by 0.265 (5.30 / 5.565). **Four
   features agreeing to 25 mm is a datum, not noise**, so the body is raised 0.25 m and the gear lengthened to match. The
   fin tip is the one thing not raised with it, because the drawing (12.60), the printed height (12.55) and the table
   (12.50) agree on it; the fin is drawn from its raised root to a tip at the published 12.55 m, 3 per cent shorter than
   the drawing's. **Unexplained, and left out of the fit**: entry door 2's sill and the aft cargo door's read 0.63 and
   0.49 m over the drawn ones, where a level aeroplane would give 0.25; and the table's top of fuselage, 5.485, is 0.33
   over the drawn crown raised. **What would settle it**: a true broadside photograph of a parked 737-800 with both door
   sills visible, or a published belly height.

## ESTIMATE

- The flight-deck eyes, 0.53 m either side, 2.7 m aft of the nose and 3.75 m up: placed under [ACAPS]'s drawn
  windscreen panes (stations 1.3 to 3.0, 3.13 to 3.86 m up before the raise). Captain LEFT.
- The cabin windows: [ACAPS] draws the doors and not the windows. 20 inches apart, their middle a metre over the drawn
  door sill.
- The control surfaces (inboard and outboard flaps either side of the thrust gate, the aileron, six spoilers a side, the
  elevators at 30 per cent of the chord, the rudder at 30 per cent of the fin's): [ACAPS] draws no panel lines.
- The wing's thickness, 15 per cent of the chord at the root to 11 at the tip; the tailplane's 12.
- The gear's pivots and stowed places. The nose leg folds FORWARD into a well closed by two doors that open and shut again
  (the doors, legs, doors sequence); the mains fold INBOARD into the belly with NO well doors, as every 737's do, so their
  tyres are seen in the belly. Drawing doors over them would be drawing a different aeroplane.
- The wing-to-body fairing, round the measured wing root.
- The livery: original, white over light grey, the game's airliner blue on the fin and in a cheatline. No airline's marks.

## Datum and axes

- origin: the centre of the draft box `Boeing737Airframe.GEOMETRY`, 3.76 x 5.156 x 39.47 m (the fuselage's width, the ground
  to the raised crown, the length); forward `-Z`, up `+Y`, metres.
- **The C++ box is still the old airliner's (5.2 x 5.2 x 26 m) until the shape is changed** (the lane's C++ step). Until
  then the drawn aeroplane is bigger than the thing that collides, and the seats are the old ones.

## Research files and licences

In `~/godotgames-drafts/2026-09-19/cockpit-liners/research/`, none incorporated into the game:

| file | source | licence | used for |
|---|---|---|---|
| 737NG_REV_C.pdf | Boeing ACAPS D6-58325-7 Rev C | Boeing copyright, published for airport planning | every MEASURED figure; the clearances, weights and tyres |
| Boeing_737_family_v1.0.png | Julien.scavini via Commons | CC BY-SA 3.0 | an independent cross-check (above) |
| American_Boeing_737-800_N886NN_planform.jpg | 4300streetcar via Commons | CC BY 4.0 | studied: a planform photograph from below |
