# Boeing 747-400 visual reference

Kind `jumbo` -- `mercury`, an E-6B blockout, until 2026-09-19, and the same row and number -- is a Boeing 747-400, drawn
by `objects/vehicles/boeing747_airframe.gd` (the table) and `objects/vehicles/jetliner_airframe.gd` (the drawing, shared
with the 737) since `lane/liners`. The runtime exterior is an original procedural model made from Godot primitives. It
contains no downloaded mesh, photograph, texture, trademark, airline livery or line of any drawing.

**The simulation's shape is the drawing's since the lane's C++ step**: the box is `Boeing747Airframe.GEOMETRY` (6.5 x 10.05
x 70.67 m), the mass 280 t (178.8 empty and 396.9 at most, [ACAPS] 1.2), the pilots on the upper deck under the drawn eye
and the two operators on the upper deck behind them. The E-6B's handling and moments, tuned at 120 t, are carried to the
new mass by the mass ratio (`carry_to_mass` in cockpit_world.cpp). `tests/jumbo.gd` holds the figures.

## The authority for the shape

**[ACAPS]** Boeing, *747-400 Airplane Characteristics for Airport Planning*, D6-58326-1 Rev F, December 2024,
`https://www.boeing.com/content/dam/boeing/v2/airports/acaps/747-400_Rev_F.pdf`. Copyright Boeing; **used to MEASURE, not
incorporated**. The pages used:

- **2.2.1, "General Dimensions: Model 747-400, -400 Combi, -400ER"** (page index 30): plan, side and front at one scale, the
  aeroplane alone in blue, as the 737's. Printed: overall length 231 ft 10.25 in (70.67 m); span 211 ft 5 in (64.44 m) in
  the jig and 213 ft 0 in (64.92 m) at maximum gross weight; fuselage 21 ft 4 in (6.50 m); tailplane 72 ft 9 in (22.17
  m); the engines' centrelines 38 ft 4 in (11.68 m) and 69 ft (21 m) out; the CF6-80C2's inlets 75 ft 6 in (23.01 m) and
  105 ft 6 in (32.16 m) aft; the nose gear 25 ft 5 in (7.75 m) aft; the body gear 84 ft 0 in (25.60 m) behind it, the wing
  gear 10 ft 1 in (3.07 m) ahead of that; the body gear's track 12 ft 7 in (3.84 m) and the wing gear's 36 ft 1 in (11.00
  m); the GE nacelle 9 ft 4 in (2.84 m) across.
- **2.3.1, ground clearances** (min to max): A upper-deck crown 9.80 to 10.23, B upper-deck door 7.53 to 7.91, C main-deck
  door 1 4.74 to 5.18, D forward cargo door 2.71 to 3.11, H main-deck crown aft 9.02 to 9.56, K fin 18.80 to 19.51, L
  tailplane tip 8.39 to 9.09, M wing tip 6.71 to 7.32, N outboard nacelle 1.32 to 1.80, P inboard nacelle 0.71 to 0.93 m.
- **2.1.1**: operating empty weight 178,755 kg, maximum take-off 396,893 kg. **7**: every tyre H49 x 19.0-22 (1.245 m).

**[WP]** Wikipedia, "Boeing 747-400": height 19.41 m (63 ft 8 in).

**[KB]** "Boeing 747-400 3view.svg", Kaboldy, Wikimedia Commons, CC BY-SA 4.0, and **[SC]** "Boeing 747 family v1.0.png",
Julien.scavini, CC BY-SA 3.0: independent drawings, studied, not measured into the model.

## Measured off [ACAPS] 2.2.1

`measure_views.py` re-derives every figure from the PDF alone, through `craft/airliner/acaps.py`. **One published number
sets the scale**: the overall length, 70.67 m, over the side view's 2,271 px at 600 dpi, **32.135 px a metre, 31 mm a
pixel** (the 737's drawing is 2.3 times finer).

| cross-check (not used to set the scale) | measured | printed | |
|---|---|---|---|
| span, plan | 64.944 m | 64.92 at max gross weight (64.44 jig) | +0.04% (+0.78) |
| span, front | 64.913 | 64.92 | -0.01% |
| length, plan | 70.577 | 70.67 | -0.13% |
| fin tip over the ground, side | 19.262 | 19.41 [WP] | -0.76% |
| fuselage width at station 18, plan | 6.566 | 6.50 | +1.02% |
| tailplane span, plan | 22.100 | 22.17 | -0.32% |
| inboard / outboard engine centreline out | 11.92 / 21.13 | 11.68 / 21.0 | +2.0 / +0.6% |
| inboard / outboard inlet aft of the nose | 23.2 / 32.1 | 23.01 / 32.16 | +0.8 / -0.2% |

| shape | measured |
|---|---|
| wing leading edge, 6 to 19.5 m out | station 18.028 + 0.9121 x out, 230 rows, rms 12 mm: **42.4 degrees**, kinked at 21.6 m out to 39.8 |
| wing trailing edge | 34.872 + 0.3229 x out inboard of 12.9 m out; 31.806 + 0.5685 x out (29.6 degrees) outboard |
| wing, front | drawn as its upper and lower edges: 4.70 and 2.83 m up at 4 m out, 5.54 and 4.85 at 18, 6.36 and 6.01 at 31 |
| tailplane leading / trailing edge | 56.956 + 0.9228 x out (42.7 degrees) / 66.862 + 0.2649 x out; tip 11.05 m out |
| fin leading / trailing edge, side | 43.649 + 1.1879 x height (49.9 degrees) / 62.723 + 0.4112 x height; tip 19.26 m |
| the hump, side | crown 10.05 from station 11 to 21, falling to the main deck's 9.21 by 30 |
| the hump, front | half-width 2.54 m at 8.0 m up, 2.04 at 9.0, 1.6 at 9.5: a lobe of 2.5 m radius on the 3.25 m main lobe |
| flight-deck windows, side | stations 4.64 to 6.25, 8.31 to 8.74 m up |

Laid over the drawing at x1.000 (`craft/airliner/overlay_views.py ... 747`), the model's silhouettes agree over **98.6 per
cent** of their union in plan and **97.8** from the side. The front view's 50.6 is not a measure of the model: Boeing draws
the 747's front view as outlines that do not close, so its silhouette is lines rather than areas, and a filled model laid
on lines agrees with them over half their union at best.

## Against the clearance table

The body agrees with [ACAPS] 2.3.1 within its ranges, so **nothing is raised**, unlike the 737: the hump's crown 10.05
against 9.80 to 10.23, the aft crown 9.21 against 9.02 to 9.56, the fin 19.26 against 18.80 to 19.51; the doors' sills
read 0.17 to 0.22 m under the table's means. **The wing does not agree**: the drawing puts the inboard nacelles' bottoms
1.09 m up against 0.71 to 0.93, the outboard ones' 2.10 against 1.32 to 1.80, and the winglet's top 7.5 against 6.71 to
7.32. The table's figures are at attitudes and weights where the wing is bent down under fuel; the drawing's wing is
higher than even the table's lightest. **Left as drawn**, and written here: bending the wing to the table would be a second
drawing of the wing rather than a measurement of this one. What would settle it: a broadside photograph of a parked
747-400 at a known weight.

## ESTIMATE

- The flight-deck eyes, 0.55 m either side, 6.9 m aft of the nose tip and 8.55 m up, level with the drawn windows; the
  glass carried aft to 7.8 m over the side windows. Captain LEFT, on the upper deck.
- The windows' pitch (20 inches) and size; their rows' heights are the drawn ones.
- The control surfaces: inboard and outboard flaps, the high-speed inboard aileron between them behind the inboard
  engine, the low-speed outboard aileron, six spoilers a side, the elevators at 28 per cent, the rudder.
- The nozzles and plugs behind the cowls, hidden by the wing in plan.
- The gear's pivots and stowed places: the nose and body gear fold forward, the wing gear inboard, and every well has
  doors that open, let the leg through and shut again. The bogies' axles 1.47 m apart and their tyres 1.12 m apart.
- The livery: original, white over light grey with a deep red fin and cheatline. No airline's marks.

## Datum and axes

- origin: the centre of the draft box `Boeing747Airframe.GEOMETRY`, 6.50 x 10.05 x 70.67 m; forward `-Z`, up `+Y`, metres.
- the C++ box is still the E-6B's, 5.3 x 5.3 x 45.8 m, until the lane's C++ step.

## Research files and licences

In `~/godotgames-drafts/2026-09-19/cockpit-liners/research/`, none incorporated into the game:

| file | source | licence | used for |
|---|---|---|---|
| 747-400_acaps.pdf | Boeing ACAPS D6-58326-1 Rev F | Boeing copyright, published for airport planning | every MEASURED figure |
| Boeing_747-400_3view.svg | Kaboldy via Commons | CC BY-SA 4.0 | studied |
| Boeing_747_family_v1.0.png | Julien.scavini via Commons | CC BY-SA 3.0 | studied |
