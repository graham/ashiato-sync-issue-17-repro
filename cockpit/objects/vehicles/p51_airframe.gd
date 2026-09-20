@tool
extends WarbirdAirframe
class_name P51Airframe
## A NORTH AMERICAN P-51D MUSTANG, DRAWN. Its first-glance features are the long nose with its four-bladed Hamilton
## Standard propeller and the chin intake under the spinner; the six exhaust stacks each side; the bubble canopy; the
## straight tapered laminar-flow wing with its root extension, set low; the radiator scoop under the belly behind the
## wing; the tall fin with its dorsal fillet; and the wide-tracked main gear folding INWARD into the wing's root. What
## MOVES:
## - THE GEAR (`set_gear`), in sequence: the two inner doors under the belly open, the mains fold inward and the tail
##   wheel forward into the fuselage, the inner doors shut again. Each main leg carries its own fairing door, which
##   closes the outer half of the well when the leg is up. The tail wheel's two doors open as it comes down and stay
##   open while it is down, as the drawing draws them;
## - THE SURFACES: the ailerons, the elevators, the rudder and the flaps;
## - THE PROPELLER (`set_props`), clockwise seen from the cockpit, as the Packard Merlin turned it.
##
## PRESENTATION ONLY. The native simulation owns the size, the flight, the collision, the stations and the wire: the kind
## is `Sim.Kind.P51` since lane/warbirds2, and the airframe dresses from its geometry, the box `draft()` gives and
## `p51_shape` was typed from. THE SIMULATION RESTS IT TAIL DOWN at its three-point rake (`roll_a_taildragger`), so the
## view draws it level in the body's frame and never through `parked()`, which is for a picture with no simulation.
## THE COCKPIT is the kit's (`WarbirdAirframe.cabin_room`): the eye under the bubble, the room, and a coaming.
##
## ORIGINAL GEOMETRY, MEASURED. No mesh, texture, photograph or livery is incorporated. Every size names its source:
## - [AN] the USAAF's own three-view, AN 01-60-3 p.30 (1945), after North American drawing 106-00001: "North American
##   P-51D Mustang 3-view line drawing.png" on Wikimedia Commons, {{PD-USGov-Military}}, with its printed dimensions;
##   and the same sheet with the dimension lines taken out ("... (no specs).png"), which the silhouettes are read off.
##   `craft/p51/measure_views.py` re-derives every MEASURED figure here from the two alone. EACH VIEW IS SCALED BY ITS OWN
##   PRINTED DIMENSION: the plan by the span (37 ft 0-5/16 in, 123.88 px a metre), which then gives the length to -0.30
##   per cent and the tailplane's span to +0.90; the side by the length (32 ft 3-5/16 in, 122.49 px a metre along it)
##   AND BY ITS PRINTED HEIGHTS UP IT (the fin's top 69-9/16 in over the reference line and the level ground 76-1/2 in
##   under it, 119.27 px a metre): THE SIDE VIEW IS DRAWN 2.6 PER CENT SHORT VERTICALLY. The front view's heights agree
##   with the side's at the side's vertical scale (the scoop's bottom 1.165 m under the thrust line in both), and its
##   width is read at its span's 124.08 px a metre over the 5-degree dihedral.
## - [WP] Wikipedia's P-51D specifications, after AN 01-60JE-2: 9.83 m long, 11.28 m span, 4.08 m (13 ft 4-1/2 in) high
##   tail down with a blade vertical, 21.8 m2 of wing.
## - ESTIMATE where nothing gives a figure, and it says what it was reasoned from.
##
## STATIONS ARE METRES AFT OF THE SPINNER'S TIP; HEIGHTS ARE METRES OVER THE THRUST LINE, the spinner tip's row, which
## [AN] draws within 5 px (0.04 m) of its fuselage reference line; OUT is metres to starboard. THE DRAWING DRAWS THE
## AEROPLANE LEVEL on its reference line and RAKES THE GROUND under it: the main tyres' bottom 2.00 m under the thrust
## line is the box's bottom face, and the three-point ground through both tyres' bottoms is `ground_at` (13.0 degrees
## worked out from the two tyres against the printed 13 deg 36 min). The model is built level and says so, and
## PARKS tail down on that ground (`parked`).
##
## TESSELLATION, STATED SO NOBODY SUBDIVIDES IT (the user, 2026-09-17: "a somewhat lower poly look", the Hawkeye the
## reference; 2026-09-19 "low-ish poly counts, although a little higher for these is okay"). The FUSELAGE is 18 facets a
## ring against the Hawkeye's 20, the canopy three of them each side; the SPINNER 12; the SCOOP 8; a TYRE 10; a blade
## four panels; a wing section seven points. The fin, rudder, tailplane, elevators, doors and mast are flat slabs.
## Every face carries its own normal; nothing is smoothed.

## [WP] The published envelope, held by `tests/p51.gd`.
const LENGTH: float = 9.83
const SPAN: float = 11.28
const HEIGHT: float = 4.08   # tail down, a blade vertical

## [AN] THE PRINTED DIMENSIONS the drawing is scaled by and checked against.
const PRINTED_SPAN: float = 11.286       # 37 ft 0-5/16 in
const PRINTED_LENGTH: float = 9.838     # 32 ft 3-5/16 in
const PRINTED_TRACK: float = 3.607      # 142 in, tyre to tyre
const PRINTED_TAILPLANE: float = 4.016  # 13 ft 2-1/8 in
const PRINTED_PROP: float = 3.404       # 11 ft 2 in; the drawn disc is 4.7 per cent small, so the model is built to this

## THE GROUND under the main tyres [AN side view]: the tyres' circle is centred 1.649 m under the thrust line and is
## 0.70 m across, so its bottom is 2.00 m under it. [AN] prints its level ground line 76-1/2 in under the reference line
## (1.94 m), 0.06 m higher: the tyre's circle crosses that line on the drawing too.
const GROUND: float = -2.00
## THE FIN'S TOP [AN side view, at its vertical scale]: 1.782 m over the thrust line.
const FIN_TOP: float = 1.78

## THE PAINT's own shades on the P-51D: natural metal, the olive drab anti-glare panel from the spinner to the windscreen.
const TOP := WarbirdAirframe.METAL
const LOWER := WarbirdAirframe.METAL_UNDER

## THE FUSELAGE [AN], as three profiles along it, every one off `measure_views.py`'s tables.
## - DECK is the side view's upper silhouette WITHOUT the canopy: the canopy stands on it from the windscreen's foot at
##   3.31 to its aft end at 5.68, and between those it is carried straight (0.607 to 0.625). Aft of 7.0 the dorsal fillet
##   and the fin hide the fuselage's own top in the side view; there it is carried down to the tail cone's 0.40 at the
##   rudder's hinge, an ESTIMATE the fin is drawn over.
## - BOTTOM is the side view's lower silhouette without the chin intake and the radiator scoop, which are parts of their
##   own. Under the scoop, 5.4 to 6.8, the belly is carried between the wing root's -0.78 and -0.566 behind the scoop's
##   exit (ESTIMATE; the scoop hides it).
## - HALF_W is the plan's half-width, without the exhaust stacks. Under the wing the plan cannot see it; the canopy's
##   plan lines give 0.46 m at 4.25, and it is carried 0.47 from 1.6 to 4.8.
const DECK_PROFILE: Array = [[0.70, 0.40], [0.80, 0.40], [1.00, 0.432], [1.20, 0.457], [1.40, 0.482], [1.60, 0.499],
	[1.80, 0.516], [2.00, 0.532], [2.20, 0.549], [2.40, 0.566], [2.60, 0.574], [2.80, 0.583], [3.00, 0.591],
	[3.20, 0.599], [3.31, 0.607], [5.68, 0.625], [5.80, 0.625], [6.00, 0.608], [6.20, 0.599], [6.40, 0.591],
	[6.60, 0.574], [6.80, 0.566], [7.00, 0.566], [7.40, 0.56], [8.00, 0.53], [8.60, 0.48], [9.00, 0.44], [9.21, 0.40]]
const BOTTOM_PROFILE: Array = [[0.70, -0.42], [0.80, -0.52], [1.00, -0.658], [1.20, -0.700], [1.40, -0.725],
	[1.60, -0.750], [1.80, -0.767], [2.00, -0.792], [2.20, -0.809], [2.40, -0.817], [3.20, -0.817], [3.60, -0.80],
	[4.00, -0.79], [5.40, -0.78], [6.00, -0.72], [6.60, -0.62], [6.80, -0.566], [7.00, -0.541], [7.20, -0.516],
	[7.40, -0.50], [8.00, -0.43], [8.20, -0.398], [8.40, -0.365], [8.60, -0.323], [8.80, -0.289], [9.00, -0.247],
	[9.21, -0.16]]
const HALF_W_PROFILE: Array = [[0.70, 0.40], [0.80, 0.392], [1.00, 0.42], [1.20, 0.43], [1.40, 0.45], [1.60, 0.47],
	[4.80, 0.47], [5.30, 0.43], [5.60, 0.40], [5.80, 0.39], [6.00, 0.38], [6.20, 0.367], [6.40, 0.351], [6.60, 0.335],
	[6.80, 0.319], [7.00, 0.30], [7.20, 0.29], [7.40, 0.275], [7.60, 0.254], [7.80, 0.242], [8.00, 0.23], [8.60, 0.20],
	[9.00, 0.16], [9.21, 0.10]]
## HOW SQUARE THE SECTION IS: a superellipse's exponent, 2 an ellipse. The P-51's is an upright oval with flat sides
## (ESTIMATE, from [AN]'s front view).
const SQUARENESS: float = 2.4
## THE RINGS THE FUSELAGE IS LOFTED THROUGH, stations; the canopy's ends and its frame are rings.
const RINGS: Array = [0.70, 0.80, 1.00, 1.20, 1.50, 1.80, 2.10, 2.40, 2.80, 3.20, 3.31, 3.45, 3.60, 3.79, 3.82, 4.00,
	4.25, 4.50, 4.80, 5.00, 5.20, 5.40, 5.55, 5.68, 5.90, 6.20, 6.60, 7.00, 7.40, 7.80, 8.20, 8.60, 9.00, 9.21]
const FUSELAGE_SIDES: int = 18
## THE TAIL CONE closes on a point under the rudder's hinge.
const TAIL_END: Vector2 = Vector2(9.27, 0.12)

## THE CANOPY [AN side view's frame lines and the plan's outline]: the windscreen's foot at 3.31, its frame at 3.79, the
## sliding hood's aft end at 5.68. Rows [station, sill height, the glass's half-width at the sill, the glass's top]:
## - the SILL is the windscreen's lower edge, falling from the deck at 3.31 to 0.33 at its frame, then the hood's rail,
##   rising in a straight line from 0.31 at 3.82 to 0.59 at 5.62, and the deck again at 5.68;
## - the HALF-WIDTH is the plan's: 0.22 at the windscreen's foot, 0.39 at the widest (4.25), closing aft;
## - the TOP is the side view's silhouette over the canopy, 0.943 at its highest.
const CANOPY: Vector2 = Vector2(3.31, 5.68)
const CANOPY_ROWS: Array = [[3.31, 0.607, 0.22, 0.607], [3.45, 0.53, 0.27, 0.66], [3.60, 0.44, 0.32, 0.79],
	[3.79, 0.33, 0.37, 0.89], [3.82, 0.31, 0.37, 0.90], [4.00, 0.338, 0.385, 0.935], [4.25, 0.377, 0.39, 0.943],
	[4.50, 0.415, 0.39, 0.943], [4.80, 0.462, 0.38, 0.91], [5.00, 0.493, 0.36, 0.86], [5.20, 0.524, 0.32, 0.801],
	[5.40, 0.555, 0.26, 0.734], [5.55, 0.578, 0.17, 0.68], [5.68, 0.625, 0.03, 0.625]]

## THE SPINNER [AN side view]: its tip at station 0 on the thrust line, its radius [distance aft, radius] off the side's
## silhouette, meeting the cowling's 0.40 at 0.70. 12 facets.
const SPINNER: Array = [[0.06, 0.12], [0.20, 0.239], [0.40, 0.331], [0.55, 0.37], [0.70, 0.40]]
const SPINNER_SIDES: int = 12
## THE PROPELLER [AN, WP]: four Hamilton Standard blades, 3.404 m across (printed), in the plane at station 0.51 (the side
## view's blades). Chords at the root, the widest and the tip, the root's pitch: ESTIMATE, the paddle blade from photographs.
const PROP_STATION: float = 0.51
const PROP_BLADES: int = 4
const PROP_CHORDS: Vector3 = Vector3(0.18, 0.29, 0.20)
const PROP_PITCH: float = deg_to_rad(45.0)

## THE CHIN INTAKE under the spinner [AN side view: the lower silhouette falls to -0.60 at 0.8 and meets the cowling by
## 1.0]: [fore, aft, half-width], its mouth dark. ESTIMATE: the width, from photographs.
const CHIN: Vector3 = Vector3(0.72, 1.05, 0.13)
## THE EXHAUST STACKS [AN plan and side]: six a side from 1.19 to 2.07, their middles 0.105 m over the thrust line.
const EXHAUSTS: Array = [1.22, 1.39, 1.56, 1.73, 1.90, 2.07]
const EXHAUST_H: float = 0.105

## THE WING [AN plan and front], by `measure_views.py`:
## - THE LEADING EDGE is station 2.687 + 0.0671 x out, fitted over 340 rows of the port wing from 1.6 to 5.0 m out (6.4 mm
##   rms; the starboard's is spoilt by a drop tank's outline drawn across it). Inboard of 1.2 m the ROOT EXTENSION brings
##   it forward to 2.56 at the fuselage's side (the plan's rows 0.5 to 1.2).
## - THE TRAILING EDGE is 5.416 - 0.1886 x out, the two sides' fits over 340 rows each (2.7 and 2.5 mm rms) averaged.
## - THE TIP rounds from 5.40 m out to the half-span's 5.643 (the plan's rows every 3 cm, both sides averaged).
## - THE MIDDLE SURFACE is -0.593 + 0.0993 x out over the thrust line: the front view's middles from 2.0 to 5.4 m out, a
##   dihedral of 5.7 degrees against the printed 5 (which [AN] draws at the reference plane). The side view's root agrees:
##   it puts the wing's lower skin at the fuselage 0.78 to 0.82 m under the thrust line, the model 0.76.
## - THE THICKNESS falls from 16.5 per cent of the chord at the root to 12.5 at the tip. The front view's depths at 2.0
##   and 5.0 m out are 16.6 and 14.5 per cent as drawn (less the pen's 3 px, 15.5 and 12.8); the side view puts the root's
##   lower skin 0.78 to 0.82 m under the thrust line, which 15.5 per cent missed by 4 cm and 16.5 meets. [WP] names the
##   section NAA/NACA 45-100.
## - THE CHORDS ARE [AN]'s AS DRAWN, and they are 3.4 per cent over the MAC printed on the same sheet: the planform
##   integrates to 22.4 m2 against [WP]'s 21.8 (and NACA's 22.3) and a MAC of 2.10 m against the printed 2.02. Built as
##   drawn, and sources.md says so.
const WING_LE: Vector2 = Vector2(2.687, 0.0671)
const WING_TE: Vector2 = Vector2(5.416, -0.1886)
const ROOT_LE: Array = [[0.30, 2.53], [0.47, 2.56], [0.80, 2.70], [1.20, 2.768]]
const WING_ROOT: float = 0.30
const WING_OUTER: float = 5.40
const WING_TIP: float = 5.643
## The tip's rows [out, leading, trailing], rounding in to its point.
const TIP_ROWS: Array = [[5.44, 3.104, 4.371], [5.50, 3.132, 4.214], [5.56, 3.180, 4.004], [5.62, 3.294, 3.669],
	[5.642, 3.43, 3.51]]
const WING_MID: Vector2 = Vector2(-0.593, 0.0993)
const WING_THICK: Vector2 = Vector2(0.165, 0.125)
## THE HINGE LINE [AN plan's panel lines]: one straight line under both flaps and ailerons, station 4.80 - 0.108 x out
## (the flap's ends at 0.51 and 3.30, the aileron's at 3.31 and 5.40, read off the plan). TRAVELS: the flaps' printed 47
## degrees; the ailerons the printed "10, 12 or 15 degrees max", taken at 15 (the sheet names neither which way nor which
## rigging); the elevators the printed 30 up and 20 down; the rudder the printed 30 each way.
const HINGE: Vector2 = Vector2(4.80, -0.108)
const FLAP: Vector2 = Vector2(0.51, 3.30)
const AILERON: Vector2 = Vector2(3.31, 5.40)

## THE SIX .50s [AN front view]: three muzzles in each wing's leading edge, 2.06, 2.23 and 2.41 m out, 0.286 m under the
## thrust line. Drawn as short barrels standing 0.08 m proud of the leading edge (ESTIMATE, photographs).
const GUNS: Array = [2.06, 2.23, 2.41]
const GUN_H: float = -0.286
const GUN_PROUD: float = 0.08

## THE RADIATOR SCOOP [AN side and front]: its lip at 3.93, 0.10 m under the belly (the gap the boundary layer leaves by),
## its bottom off the side view's silhouette, 0.28 m either side at the bottom (the front view's -1.12 at 0.2 m out and
## -0.84 at 0.4), and its exit at 6.60. Rows [station, bottom, half-width]; its top is the belly, but at the lip 0.10
## under it, rising into it by 4.5.
const SCOOP: Array = [[3.93, -1.10, 0.27], [4.20, -1.153, 0.28], [4.50, -1.170, 0.28], [4.80, -1.161, 0.28],
	[5.10, -1.135, 0.28], [5.40, -1.069, 0.27], [5.80, -0.977, 0.26], [6.20, -0.843, 0.25], [6.60, -0.650, 0.24]]
const SCOOP_GAP: float = 0.10

## THE TAILPLANE [AN plan and side]: its middle 0.34 m over the thrust line (the side view's section 0.314, the front
## view's 0.357); its leading edge 7.84 + 0.213 x out and trailing edge 9.207 - 0.092 x out (the plan's rows 0.3 to 1.8
## m out), the tip rounding to 2.01 m; the ELEVATORS' hinge a straight 8.745 (plan and side agree, 8.74 and 8.76).
const TAIL_H: float = 0.34
const TAIL_LE: Vector2 = Vector2(7.84, 0.213)
const TAIL_TE: Vector2 = Vector2(9.207, -0.092)
const ELEVATOR_HINGE: float = 8.745
const TAIL_TIP: Array = [[1.80, 8.223, 9.041], [1.90, 8.26, 8.99], [1.97, 8.33, 8.87], [2.01, 8.46, 8.745]]
const ELEVATOR_ROOT: float = 0.20
## THE FIN AND ITS DORSAL FILLET [AN side view, hand picks in `measure_views.py`]: [station, height], from the fillet's
## start along the spine, up the leading edge, over the top to the rudder's hinge at 9.21 and down it into the fuselage.
const FIN: Array = [[6.90, 0.50], [7.40, 0.57], [8.21, 0.675], [8.43, 0.84], [8.73, 1.63], [8.82, 1.73], [8.92, 1.77],
	[9.20, 1.775], [9.20, 0.34], [8.60, 0.40], [7.40, 0.49]]
const RUDDER_HINGE: float = 9.21
const RUDDER: Array = [[9.215, 1.775], [9.49, 1.76], [9.58, 1.66], [9.71, 0.90], [9.82, 0.31], [9.79, 0.09],
	[9.63, -0.08], [9.36, -0.15], [9.215, -0.16]]
## THE RADIO MAST behind the canopy [AN side]: its foot 6.55 to 6.80 on the spine, its tip 1.07 up at 6.72.
const MAST: Array = [[6.55, 0.55], [6.80, 0.55], [6.74, 1.07], [6.68, 1.07]]

## THE GEAR [AN]:
## - THE MAIN TYRES are 0.70 m across (the side view's circle, 42.9 px; the P-51D's 27-inch tyre is 0.686), their axles
##   1.804 m either side (the printed 142 in track) at station 2.747, 1.649 m under the thrust line. Each LEG stands
##   upright under its pivot in the wing, 0.50 m under the thrust line at station 2.95 (ESTIMATE: at the front spar; the
##   front view draws the legs upright), and folds INWARD through a quarter turn about the line fore and aft, its wheel
##   coming to lie FLAT in the wing's root at 0.69 m out, station 3.40, its fairing turned down to close the well.
##   The plan's dashed circles put the stowed wheels 0.37 and 0.44 m either side at station 3.13; this model cannot put
##   them there. A wheel that lies flat after a quarter turn stows at its pivot's own height, one leg's length inboard,
##   and a leg long enough to reach 0.4 m out would have its pivot 0.25 m under the thrust line, over the wing's upper
##   skin; and at 3.13, and again at 3.25, the tyre's front lay where the laminar root is thin, and the first pictures
##   from below showed both tyres through it (`tests/p51.gd` holds every stowed tyre vertex inside the drawn skin).
## - THE INNER DOORS close the wells under the belly, hinged 0.02 m either side of the centreline and opening down; each
##   leg's own fairing closes the well's outer part.
## - THE TAIL WHEEL is 0.31 m across (the side view's circle, 18.5 px), its axle at 7.875, 0.666 under the thrust line;
##   it retracts FORWARD into the fuselage about a pivot at 7.60, 0.30 under (ESTIMATE), behind two doors hinged on the
##   belly's edges that open as it comes down and stay open.
const MAIN_TYRE: Vector2 = Vector2(0.70, 0.22)     # across, wide (the width an ESTIMATE)
const MAIN_AXLE: Vector3 = Vector3(1.8035, -1.649, 2.747)
const MAIN_PIVOT: Vector3 = Vector3(1.8035, -0.50, 2.95)
const MAIN_WELL: Vector3 = Vector3(0.69, -0.50, 3.40)
const INNER_DOOR: Vector4 = Vector4(3.02, 3.80, 0.02, 0.62)   # fore, aft, inner, outer
const TAIL_TYRE: Vector2 = Vector2(0.31, 0.10)
const TAIL_AXLE: Vector2 = Vector2(7.875, -0.666)
const TAIL_PIVOT: Vector2 = Vector2(7.60, -0.30)
const TAIL_STOWED: Vector2 = Vector2(7.20, -0.24)
const TAIL_DOOR: Vector3 = Vector3(7.42, 8.12, 0.13)   # fore, aft, half-width of the opening
const WHEEL_SIDES: int = 10
const DOOR_OPEN: float = deg_to_rad(85.0)


## BUILT IN PLACE, after `new()`, from the simulation's geometry, or the draft until the kind exists.
func dress(geometry: Dictionary = {}) -> void:
	name = "P51"
	_take(geometry)
	aileron_travel = deg_to_rad(15.0)
	elevator_up = deg_to_rad(30.0)
	elevator_down = deg_to_rad(20.0)
	rudder_travel = deg_to_rad(30.0)
	flap_travel = deg_to_rad(47.0)
	var paint: StandardMaterial3D = _paint()
	# THE SKIN SEEN FROM THE SEAT: double-sided, or from inside the one closed solid the pilot sees no aeroplane at all.
	var inside: StandardMaterial3D = _paint()
	inside.cull_mode = BaseMaterial3D.CULL_DISABLED

	# THE CANOPY IS THE FUSELAGE'S SECOND SURFACE, so the skin round the pilot is one closed solid (lane/warthog).
	var body := _tool()
	var canopy := _tool()
	_fuselage(body, canopy)
	var fuselage := _add(self, "Fuselage", body, paint)
	fuselage.material_override = null
	fuselage.mesh = canopy.commit(fuselage.mesh as ArrayMesh)
	fuselage.set_surface_override_material(0, inside)
	fuselage.set_surface_override_material(1, _glass())
	# THE COAMING closes the nose off from the eye (`WarbirdAirframe._coaming`, lane/warbirds2).
	var coaming := _tool()
	_coaming(coaming)
	_add(self, "Coaming", coaming, paint)
	var spinner := _tool()
	_spinner(spinner, point(0.0, 0.0, 0.0), point(0.0, 0.0, float(SPINNER[-1][0])), SPINNER, SPINNER_SIDES, TOP)
	_add(self, "Spinner", spinner, paint)
	_propeller("Propeller", point(0.0, 0.0, PROP_STATION), PRINTED_PROP * 0.5, PROP_BLADES, PROP_CHORDS, PROP_PITCH,
		1.0, 0.30, paint)
	var chin := _tool()
	_chin(chin)
	_add(self, "ChinIntake", chin, paint)
	var exhausts := _tool()
	_exhausts(exhausts)
	_small(_add(self, "Exhausts", exhausts, paint))
	var scoop := _tool()
	_scoop(scoop)
	_add(self, "Scoop", scoop, paint)
	var mast := _tool()
	_slab(mast, _outline(MAST), func(p: Vector2) -> Vector3: return point(0.0, p.y, p.x), Vector3.RIGHT, 0.012, DARK)
	_small(_add(self, "Mast", mast, paint))
	var wells := _tool()
	_wells(wells)
	_add(self, "Wells", wells, paint)

	for side in [1.0, -1.0]:
		var named: String = "Starboard" if side > 0.0 else "Port"
		var wing := _tool()
		_wing(wing, side)
		_add(self, "Wing" + named, wing, paint)
		var guns := _tool()
		_guns(guns, side)
		_small(_add(self, "Guns" + named, guns, paint))
		_aileron(side, named, paint)
		_flap(side, named, paint)
		_elevator(side, named, paint)
	var tail := _tool()
	_tailplane(tail)
	_add(self, "Tailplane", tail, paint)
	var fin := _tool()
	_slab(fin, _outline(FIN), func(p: Vector2) -> Vector3: return point(0.0, p.y, p.x), Vector3.RIGHT, 0.045, TOP)
	_add(self, "Fin", fin, paint)
	_rudder(paint)
	_build_gear(paint)
	set_gear(1.0)


## THE DRAFT: the box from the spinner's tip to the rudder's trailing edge, the main tyres' ground to the fin's top, the
## fuselage's 0.47 m half-width with a margin; the span [AN]'s printed one. SINCE THE KIND (lane/warbirds2) it is what
## `p51_shape` was typed from, and `tests/p51.gd` holds the two together; the airframe dresses from the kind's.
func draft() -> Dictionary:
	return {"extents": Vector3(0.50, (FIN_TOP - GROUND) * 0.5, PRINTED_LENGTH * 0.5), "span": PRINTED_SPAN}


func kind_id() -> int:
	return Sim.Kind.P51


# ---- the cockpit ------------------------------------------------------------------------------------------------------

## THE PILOT'S EYE, ESTIMATE: 0.70 m over the thrust line at station 4.35, 0.24 m under the bubble's top at its highest,
## over the seat's drawn place between the canopy's frame and its widest; no station diagram is public. `p51_shape` puts
## the seat `CockpitStation.EYE_HEIGHT` under it.
const EYE: Vector2 = Vector2(4.35, 0.70)
## THE INSTRUMENT PANEL at station 3.60, a ring station 0.75 m ahead of the eye, 0.29 m aft of the windscreen's foot; the
## glare shield's deck runs forward from it to the foot (ESTIMATE, photographs of a P-51D's cockpit).
const PANEL: float = 3.60
## THE ROOM promised round the pilot, (out, height over the thrust line, station): held inside the drawn skin, canopy
## included, by `tests/p51.gd`.
const ROOM: AABB = AABB(Vector3(-0.24, -0.66, 3.95), Vector3(0.48, 1.14, 0.85))


func eye_at() -> Vector2:
	return EYE


func room() -> AABB:
	return ROOM


func panel_station() -> float:
	return PANEL


func ring_stations() -> Array:
	return RINGS


func section_at(s: float) -> Array:
	return half_section(s)


func sill_index() -> int:
	return 3


func windscreen_foot() -> float:
	return CANOPY.x


## THE STARBOARD MAIN'S, THE PORT MAIN'S AND THE TAIL WHEEL'S TYRE BOTTOMS, each under its axle.
func wheel_contacts() -> Array:
	return [point(MAIN_AXLE.x, MAIN_AXLE.y - MAIN_TYRE.x * 0.5, MAIN_AXLE.z),
		point(-MAIN_AXLE.x, MAIN_AXLE.y - MAIN_TYRE.x * 0.5, MAIN_AXLE.z),
		point(0.0, TAIL_AXLE.y - TAIL_TYRE.x * 0.5, TAIL_AXLE.x)]


## THE SIX MUZZLES, craft-local, starboard and port alternately inboard to outboard: each gun barrel's front end as
## `_guns` draws it, GUN_PROUD ahead of the leading edge. `loadout_of`'s battery is typed from these, and
## `tests/p51_seat.gd` holds every round's birth to one of them.
func muzzles() -> Array:
	var out: Array = []
	for g in GUNS:
		for side in [1.0, -1.0]:
			out.append(point(side * float(g), GUN_H, wing_le(float(g)) - GUN_PROUD))
	return out


func ground_height() -> float:
	return GROUND


## PARKED TAIL DOWN on the three-point ground (`ground_at`).
func parked() -> Transform3D:
	return _three_point(Vector2(MAIN_AXLE.z, MAIN_AXLE.y), MAIN_TYRE.x * 0.5, TAIL_AXLE, TAIL_TYRE.x * 0.5)


## THE THREE-POINT GROUND, as a height over the thrust line at `station`: the line under both tyres' bottoms, the main
## tyre's at its axle's station and the tail wheel's at its own.
static func ground_at(station: float) -> float:
	var main_bottom := Vector2(MAIN_AXLE.z, MAIN_AXLE.y - MAIN_TYRE.x * 0.5)
	var tail_bottom := Vector2(TAIL_AXLE.x, TAIL_AXLE.y - TAIL_TYRE.x * 0.5)
	return lerpf(main_bottom.y, tail_bottom.y, (station - main_bottom.x) / (tail_bottom.x - main_bottom.x))


# ---- the shapes, read off the tables ----------------------------------------------------------------------------------

static func deck_at(s: float) -> float:
	return _profile(DECK_PROFILE, s)


static func bottom_at(s: float) -> float:
	return _profile(BOTTOM_PROFILE, s)


static func half_width_at(s: float) -> float:
	return _profile(HALF_W_PROFILE, s)


## THE CANOPY at a station: (sill height, the glass's half-width at the sill, the glass's top).
static func canopy_at(s: float) -> Vector3:
	for i in range(CANOPY_ROWS.size() - 1):
		var a: Array = CANOPY_ROWS[i]
		var b: Array = CANOPY_ROWS[i + 1]
		if s <= float(b[0]):
			var t: float = clampf((s - float(a[0])) / (float(b[0]) - float(a[0])), 0.0, 1.0)
			return Vector3(lerpf(float(a[1]), float(b[1]), t), lerpf(float(a[2]), float(b[2]), t),
				lerpf(float(a[3]), float(b[3]), t))
	var last: Array = CANOPY_ROWS[-1]
	return Vector3(float(last[1]), float(last[2]), float(last[3]))


static func glazed(s: float) -> bool:
	return s >= CANOPY.x - 0.001 and s <= CANOPY.y + 0.001


## THE FUSELAGE'S SECTION as a superellipse from the deck to the bottom, `w` wide either side: the point at angle `theta`
## from the top, (half-width, height).
static func _oval(s: float, theta: float) -> Vector2:
	var top: float = deck_at(s)
	var bottom: float = bottom_at(s)
	var w: float = half_width_at(s)
	var c: float = (top + bottom) * 0.5
	var b: float = (top - bottom) * 0.5
	var e: float = 2.0 / SQUARENESS
	var sn: float = sin(theta)
	var cs: float = cos(theta)
	return Vector2(w * pow(absf(sn), e), c + b * signf(cs) * pow(absf(cs), e))


## ONE RING's half-section, (half-width, height), from the top centreline down to the keel: ten points, nine facets. OVER
## THE CANOPY the first four are the glass -- its top, two points round its shoulder and the sill -- and the fifth, the
## fuselage's shoulder, is kept under and outboard of the sill so the deck the canopy stands on is a face, not a fold.
static func half_section(s: float) -> Array:
	var half: Array = []
	for k in range(10):
		half.append(_oval(s, PI * float(k) / 9.0))
	if glazed(s):
		var c: Vector3 = canopy_at(s)
		var sill: float = c.x
		var gw: float = c.y
		var top: float = c.z
		half[0] = Vector2(0.0, top)
		# ROUNDER THAN AN ELLIPSE AT THE TOP: the front view's glass stands 0.81 m up at 0.2 m out and falls to the sill's
		# height by 0.4 (the first bubble, 0.55 and 0.92 of the width, stood 0.66 up at 0.36 m out).
		half[1] = Vector2(0.50 * gw, top - 0.14 * (top - sill))
		half[2] = Vector2(0.80 * gw, sill + 0.45 * (top - sill))
		half[3] = Vector2(gw, sill)
		var shoulder: Vector2 = half[4]
		half[4] = Vector2(maxf(shoulder.x, gw + 0.015), minf(shoulder.y, sill - 0.015))
	return half


func _fuselage_ring(s: float) -> Array:
	var half: Array = half_section(s)
	var points: Array = []
	for i in range(half.size() - 1):
		points.append(point((half[i] as Vector2).x, (half[i] as Vector2).y, s))
	for i in range(half.size() - 1, 0, -1):
		points.append(point(-(half[i] as Vector2).x, (half[i] as Vector2).y, s))
	return points


## THE FUSELAGE: 18 flat facets a ring through `RINGS`. Over the canopy the three upper facets each side are GLASS and go
## into `canopy`. Upward-facing panels ahead of the windscreen take the olive drab anti-glare panel.
func _fuselage(tool: SurfaceTool, canopy: SurfaceTool) -> void:
	var rings: Array = []
	for s in RINGS:
		rings.append(_fuselage_ring(float(s)))
	var n: int = FUSELAGE_SIDES
	for r in range(rings.size() - 1):
		var here: float = (float(RINGS[r]) + float(RINGS[r + 1])) * 0.5
		var glass: bool = here > CANOPY.x and here < CANOPY.y
		var a: Array = rings[r]
		var b: Array = rings[r + 1]
		var centre: Vector3 = point(0.0, (deck_at(here) + bottom_at(here)) * 0.5, here)
		for k in range(n):
			var quad: Array = [a[k], a[(k + 1) % n], b[(k + 1) % n], b[k]]
			var mid: Vector3 = ((quad[0] as Vector3) + quad[1] + quad[2] + quad[3]) * 0.25
			var out: Vector3 = Vector3(mid.x - centre.x, mid.y - centre.y, 0.0)
			# Facets 0 to 2 are the starboard glass, 15 to 17 the port.
			if glass and (k <= 2 or k >= n - 3):
				_quad(canopy, quad, out, GLASS)
				continue
			var normal: Vector3 = ((quad[2] as Vector3) - (quad[0] as Vector3)).cross(
				(quad[1] as Vector3) - (quad[0] as Vector3)).normalized()
			if normal.dot(out) < 0.0:
				normal = -normal
			var tint: Color = TOP if normal.y > 0.2 else LOWER
			if here < CANOPY.x and normal.y > 0.55:
				tint = OLIVE
			_quad(tool, quad, out, tint)
	# THE NOSE: the cowling's front ring closed behind the spinner. THE TAIL: a fan to the tail cone's point.
	var first: Array = rings[0]
	var front: Vector3 = point(0.0, 0.0, float(RINGS[0]))
	for k in range(n):
		_fan(tool, front, first[k], first[(k + 1) % n], Vector3.FORWARD, DARK)
	var last: Array = rings[rings.size() - 1]
	var end: Vector3 = point(0.0, TAIL_END.y, TAIL_END.x)
	for k in range(n):
		_fan(tool, end, last[k], last[(k + 1) % n], Vector3.BACK, LOWER)


## THE CHIN INTAKE: a wedge under the cowling, its mouth a dark face.
func _chin(tool: SurfaceTool) -> void:
	var loops: Array = []
	for row in [[CHIN.x, -0.60, CHIN.z * 0.9], [0.88, -0.63, CHIN.z], [CHIN.y, bottom_at(CHIN.y) + 0.02, CHIN.z * 0.8]]:
		var s: float = float(row[0])
		var low: float = float(row[1])
		var w: float = float(row[2])
		var high: float = bottom_at(s) + 0.10
		loops.append([point(w, high, s), point(w, low, s), point(-w, low, s), point(-w, high, s)])
	_loft(tool, loops, [LOWER], false)
	var mouth: Array = loops[0]
	_quad(tool, [mouth[0], mouth[1], mouth[2], mouth[3]], Vector3.FORWARD, BLACK)
	var back: Array = loops[-1]
	_quad(tool, [back[0], back[1], back[2], back[3]], Vector3.BACK, LOWER)


## THE EXHAUST STACKS: six dark stubs each side, 0.03 m proud of the cowling.
func _exhausts(tool: SurfaceTool) -> void:
	for side in [1.0, -1.0]:
		for s in EXHAUSTS:
			var w: float = half_width_at(float(s)) * pow(1.0 - pow(absf(EXHAUST_H - (deck_at(float(s))
				+ bottom_at(float(s))) * 0.5) / ((deck_at(float(s)) - bottom_at(float(s))) * 0.5), SQUARENESS),
				1.0 / SQUARENESS)
			Plating.box(tool, point(side * (w + 0.005), EXHAUST_H, float(s)), Vector3(0.07, 0.07, 0.12), DARK)


## THE RADIATOR SCOOP: 8 facets a ring through `SCOOP`, its top buried in the belly but at the lip, where it stands
## `SCOOP_GAP` under it; the intake a dark face set back in the lip and the exit dark.
func _scoop(tool: SurfaceTool) -> void:
	var loops: Array = []
	for row in SCOOP:
		var s: float = float(row[0])
		var low: float = float(row[1])
		var w: float = float(row[2])
		var belly: float = bottom_at(s)
		var high: float = lerpf(belly - SCOOP_GAP, belly + 0.06, clampf((s - 3.93) / (4.50 - 3.93), 0.0, 1.0))
		var mid: float = (low + high) * 0.5
		loops.append([point(w * 0.55, high, s), point(w, mid + (high - mid) * 0.4, s), point(w, low + 0.10, s),
			point(w * 0.6, low, s), point(-w * 0.6, low, s), point(-w, low + 0.10, s), point(-w, mid + (high - mid) * 0.4, s),
			point(-w * 0.55, high, s)])
	var tints: Array = [LOWER, LOWER, LOWER, LOWER, LOWER, LOWER, LOWER, LOWER]
	_loft(tool, loops, tints, false)
	for end in [[0, Vector3.FORWARD], [loops.size() - 1, Vector3.BACK]]:
		var loop: Array = loops[end[0]]
		var centre := Vector3.ZERO
		for p in loop:
			centre += p
		centre /= float(loop.size())
		for k in range(loop.size()):
			_fan(tool, centre, loop[k], loop[(k + 1) % loop.size()], end[1], BLACK)


## THE MAIN WHEEL WELLS: a green patch 1 cm inside the belly over each well, hidden by the doors until they open. A PART
## OF ITS OWN, not the fuselage's: the skin is one closed solid and a point is inside it by ray parity (lane/lightning).
func _wells(tool: SurfaceTool) -> void:
	for side in [1.0, -1.0]:
		var corners: Array = []
		for c in [[INNER_DOOR.z, INNER_DOOR.x], [INNER_DOOR.w, INNER_DOOR.x], [INNER_DOOR.w, INNER_DOOR.y],
				[INNER_DOOR.z, INNER_DOOR.y]]:
			corners.append(point(side * float(c[0]), _underside(float(c[0]), float(c[1])) + 0.02, float(c[1])))
		_quad(tool, corners, Vector3.DOWN, WELL)
	var tail: Array = []
	for c in [[TAIL_DOOR.z, TAIL_DOOR.x], [-TAIL_DOOR.z, TAIL_DOOR.x], [-TAIL_DOOR.z, TAIL_DOOR.y], [TAIL_DOOR.z, TAIL_DOOR.y]]:
		tail.append(point(float(c[0]), bottom_at(float(c[1])) + 0.02, float(c[1])))
	_quad(tool, tail, Vector3.DOWN, WELL)


## THE UNDERSIDE a door closes, at `out` and `station`: the fuselage's keel inboard, the wing's lower skin outboard,
## whichever is lower.
static func _underside(out: float, station: float) -> float:
	var keel: float = bottom_at(station)
	var wing: float = wing_mid(out) - wing_thick_at(out) * 0.5
	var t: float = clampf(absf(out) / 0.47, 0.0, 1.0)
	return minf(lerpf(keel, keel + 0.06, t * t), wing) if absf(out) < 0.47 else wing


# ---- the wing -------------------------------------------------------------------------------------------------------

static func wing_le(out: float) -> float:
	var a: float = absf(out)
	if a <= float(ROOT_LE[-1][0]):
		return _profile(ROOT_LE, a)
	if a > WING_OUTER:
		return _tip(a).x
	return WING_LE.x + WING_LE.y * a


static func wing_te(out: float) -> float:
	var a: float = absf(out)
	if a > WING_OUTER:
		return _tip(a).y
	return WING_TE.x + WING_TE.y * a


static func _tip(a: float) -> Vector2:
	var rows: Array = [[WING_OUTER, WING_LE.x + WING_LE.y * WING_OUTER, WING_TE.x + WING_TE.y * WING_OUTER]]
	rows.append_array(TIP_ROWS)
	for i in range(rows.size() - 1):
		if a <= float(rows[i + 1][0]):
			var t: float = clampf((a - float(rows[i][0])) / (float(rows[i + 1][0]) - float(rows[i][0])), 0.0, 1.0)
			return Vector2(lerpf(float(rows[i][1]), float(rows[i + 1][1]), t), lerpf(float(rows[i][2]), float(rows[i + 1][2]), t))
	return Vector2(float(rows[-1][1]), float(rows[-1][2]))


static func wing_mid(out: float) -> float:
	return WING_MID.x + WING_MID.y * absf(out)


static func wing_thick_at(out: float) -> float:
	var a: float = absf(out)
	return lerpf(WING_THICK.x, WING_THICK.y, clampf(a / WING_TIP, 0.0, 1.0)) * (wing_te(a) - wing_le(a))


static func hinge_at(out: float) -> float:
	return HINGE.x + HINGE.y * absf(out)


## A SEVEN-POINT WING SECTION at `out` from the leading edge to `end` along a chord whose trailing edge is the wing's: the
## leading edge, the upper surface at 15 and 40 per cent, the upper and lower surface at `end`, and the lower at 40 and
## 15. Thickest at 40 per cent, the laminar section's, tapering to a 1 cm trailing edge, so a section cut at a hinge is as
## thick there as the surface hinged behind it.
func _section(out: float, end: float, side: float) -> Array:
	var le: float = wing_le(out)
	var te: float = wing_te(out)
	var c: float = te - le
	var mid: float = wing_mid(out)
	var t: float = wing_thick_at(out)
	var at_end: float = _depth_at(out, end)
	return [point(side * out, mid, le), point(side * out, mid + 0.40 * t, le + 0.15 * c),
		point(side * out, mid + 0.5 * t, le + 0.40 * c), point(side * out, mid + at_end, end),
		point(side * out, mid - at_end, end), point(side * out, mid - 0.5 * t, le + 0.40 * c),
		point(side * out, mid - 0.40 * t, le + 0.15 * c)]


## HALF THE WING'S DEPTH at station `at`, `out` metres out: full aft to 40 per cent, then falling straight to 1 cm at the
## trailing edge.
static func _depth_at(out: float, at: float) -> float:
	var le: float = wing_le(out)
	var te: float = wing_te(out)
	var f: float = clampf((at - le) / (te - le), 0.4, 1.0)
	return maxf(wing_thick_at(out) * 0.5 * (1.0 - f) / 0.6, 0.005)


const _SURFACE_TINTS: Array = [TOP, TOP, TOP, LOWER, LOWER, LOWER, LOWER]


## WHETHER A SURFACE IS HINGED BEHIND THE WING at `out`.
static func _hinged(out: float) -> bool:
	return (out >= FLAP.x - 0.001 and out <= FLAP.y + 0.001) or (out >= AILERON.x - 0.001 and out <= AILERON.y + 0.001)


## THE WING, one side: lofted through a section at every break -- the root inside the fuselage, each surface's ends and
## the tip's rows -- each bay to the hinge where a surface is hinged behind it and to the trailing edge where none is.
## Each bay is its own closed loft, so a step in the chord is a closed end, not a hole.
func _wing(tool: SurfaceTool, side: float) -> void:
	var breaks: Array = [WING_ROOT, float(ROOT_LE[1][0]), FLAP.x, float(ROOT_LE[2][0]), float(ROOT_LE[3][0]), FLAP.y,
		AILERON.x, AILERON.y]
	breaks.sort()
	for i in range(breaks.size() - 1):
		var a: float = float(breaks[i])
		var b: float = float(breaks[i + 1])
		if b - a < 0.005:
			continue
		var hinged: bool = _hinged((a + b) * 0.5)
		var loops: Array = []
		for out in [a, b]:
			loops.append(_section(float(out), hinge_at(float(out)) if hinged else wing_te(float(out)), side))
		_loft(tool, loops, _SURFACE_TINTS)
	# THE TIP, from the aileron's end out to the point, through the tip's rows.
	var tips: Array = []
	var outs: Array = [WING_OUTER]
	for row in TIP_ROWS:
		outs.append(float(row[0]))
	for out in outs:
		tips.append(_section(float(out), wing_te(float(out)), side))
	_loft(tool, tips, _SURFACE_TINTS)


## A HINGED SURFACE'S PANEL at `out`, hinge to trailing edge, in its hinge's frame `at`: [upper at the hinge, the upper
## trailing edge, the lower trailing edge, lower at the hinge].
func _surface_loop(side: float, out: float, at: Vector3) -> Array:
	var h: float = hinge_at(out)
	var te: float = wing_te(out)
	var mid: float = wing_mid(out)
	var d: float = _depth_at(out, h + 0.01)
	return [point(side * out, mid + d, h + 0.01) - at, point(side * out, mid + 0.005, te) - at,
		point(side * out, mid - 0.005, te) - at, point(side * out, mid - d, h + 0.01) - at]


## THE AILERON, one side, on the hinge line's middle surface.
func _aileron(side: float, named: String, paint: Material) -> void:
	var inner: Vector3 = point(side * AILERON.x, wing_mid(AILERON.x), hinge_at(AILERON.x))
	var outer: Vector3 = point(side * AILERON.y, wing_mid(AILERON.y), hinge_at(AILERON.y))
	var mid: Vector3 = (inner + outer) * 0.5
	var hinge := _hinge("Aileron" + named, self, mid, outer - inner, mid + Vector3.BACK, Vector3.DOWN)
	var tool := _tool()
	_loft(tool, [_surface_loop(side, AILERON.x + 0.02, mid), _surface_loop(side, AILERON.y - 0.02, mid)],
		[TOP, TOP, LOWER, LOWER])
	_add(hinge, "Aileron" + named, tool, paint)


## THE FLAP, one side, hinged UNDER the wing on its lower skin at the hinge line, so 47 degrees down drops its nose away
## from the wing rather than folding it through the skin.
func _flap(side: float, named: String, paint: Material) -> void:
	var inner: Vector3 = point(side * FLAP.x, wing_mid(FLAP.x) - _depth_at(FLAP.x, hinge_at(FLAP.x)), hinge_at(FLAP.x))
	var outer: Vector3 = point(side * FLAP.y, wing_mid(FLAP.y) - _depth_at(FLAP.y, hinge_at(FLAP.y)), hinge_at(FLAP.y))
	var mid: Vector3 = (inner + outer) * 0.5
	var hinge := _hinge("Flap" + named, self, mid, outer - inner, mid + Vector3.BACK, Vector3.DOWN)
	var tool := _tool()
	_loft(tool, [_surface_loop(side, FLAP.x + 0.02, mid), _surface_loop(side, FLAP.y - 0.02, mid)],
		[TOP, TOP, LOWER, LOWER])
	_add(hinge, "Flap" + named, tool, paint)


## THE SIX .50s, three each side: six-sided barrels from inside the leading edge to `GUN_PROUD` ahead of it.
func _guns(tool: SurfaceTool, side: float) -> void:
	for out in GUNS:
		var le: float = wing_le(float(out))
		var loops: Array = []
		for s in [le - GUN_PROUD, le + 0.25]:
			loops.append(_ring(point(side * float(out), GUN_H, float(s)), Vector3.BACK, 0.022, 0.022, 6))
		_loft(tool, loops, [GUNMETAL])


# ---- the tail -------------------------------------------------------------------------------------------------------

## THE TAILPLANE, both sides in one slab through the fuselage, from its leading edge to the elevators' hinge.
func _tailplane(tool: SurfaceTool) -> void:
	var starboard: Array = [[0.0, TAIL_LE.x]]
	for row in TAIL_TIP:
		starboard.append([float(row[0]), float(row[1])])
	starboard.append([float(TAIL_TIP[-1][0]), ELEVATOR_HINGE])
	starboard.append([ELEVATOR_ROOT - 0.01, ELEVATOR_HINGE])
	starboard.append([ELEVATOR_ROOT - 0.01, TAIL_TE.x + TAIL_TE.y * ELEVATOR_ROOT])
	starboard.append([0.0, TAIL_TE.x])
	var outline: Array = []
	for p in starboard:
		outline.append(p)
	for i in range(starboard.size() - 2, 0, -1):
		outline.append([-float(starboard[i][0]), float(starboard[i][1])])
	var place := func(p: Vector2) -> Vector3: return point(p.x, TAIL_H, p.y)
	_slab(tool, _outline(outline), place, Vector3.UP, 0.05, TOP, LOWER)


## AN ELEVATOR, one side, on the hinge at 8.745, from the fuselage's side to the tip, its trailing edge the tailplane's.
func _elevator(side: float, named: String, paint: Material) -> void:
	var inner: Vector3 = point(side * ELEVATOR_ROOT, TAIL_H, ELEVATOR_HINGE)
	var outer: Vector3 = point(side * float(TAIL_TIP[-1][0]), TAIL_H, ELEVATOR_HINGE)
	var mid: Vector3 = (inner + outer) * 0.5
	var hinge := _hinge("Elevator" + named, self, mid, outer - inner, mid + Vector3.BACK, Vector3.DOWN)
	var tool := _tool()
	var tip: float = float(TAIL_TIP[-1][0])
	var outline: Array = [[ELEVATOR_ROOT, ELEVATOR_HINGE + 0.01], [tip - 0.01, ELEVATOR_HINGE + 0.01],
		[float(TAIL_TIP[2][0]), float(TAIL_TIP[2][2])], [float(TAIL_TIP[1][0]), float(TAIL_TIP[1][2])],
		[float(TAIL_TIP[0][0]), float(TAIL_TIP[0][2])], [ELEVATOR_ROOT, TAIL_TE.x + TAIL_TE.y * ELEVATOR_ROOT]]
	var place := func(p: Vector2) -> Vector3: return point(side * p.x, TAIL_H, p.y) - mid
	_slab(tool, _outline(outline), place, Vector3.UP, 0.035, TOP, LOWER)
	_add(hinge, "Elevator" + named, tool, paint)


## THE RUDDER, on its upright hinge at 9.21, from the fin's top to under the tail cone.
func _rudder(paint: Material) -> void:
	var foot: Vector3 = point(0.0, float(RUDDER[-1][1]), RUDDER_HINGE)
	var head: Vector3 = point(0.0, float(RUDDER[0][1]), RUDDER_HINGE)
	# A positive turn swings the trailing edge to STARBOARD, for right rudder.
	var hinge := _hinge("Rudder", self, foot, head - foot, foot + Vector3.BACK, Vector3.RIGHT)
	var tool := _tool()
	var local := func(p: Vector2) -> Vector3: return point(0.0, p.y, p.x) - foot
	_slab(tool, _outline(RUDDER), local, Vector3.RIGHT, 0.035, TOP)
	_add(hinge, "Rudder", tool, paint)


# ---- the gear -------------------------------------------------------------------------------------------------------

## THE GEAR: two main legs folding inward, the tail wheel folding forward, the two inner doors over the wells and the
## tail wheel's two doors.
func _build_gear(paint: Material) -> void:
	for side in [1.0, -1.0]:
		var named: String = "Starboard" if side > 0.0 else "Port"
		var pivot: Vector3 = point(side * MAIN_PIVOT.x, MAIN_PIVOT.y, MAIN_PIVOT.z)
		var axle: Vector3 = point(side * MAIN_AXLE.x, MAIN_AXLE.y, MAIN_AXLE.z)
		var well: Vector3 = point(side * MAIN_WELL.x, MAIN_WELL.y, MAIN_WELL.z)
		# THE STOWED AXLE is where the leg, at its own length, points at the well's middle.
		var stowed: Vector3 = pivot + (well - pivot).normalized() * (axle - pivot).length()
		# LYING FLAT, its outboard face -- the fairing -- turned DOWN to close the well's outer part.
		_leg("MainGear" + named, pivot, axle, stowed, _main_leg.bind(side), paint, Vector3(0.0, -side, 0.0))
		# THE INNER DOOR, hinged near the centreline, its outer edge dropping.
		var at := func(o: float, s: float) -> Vector3: return point(side * o, _underside(o, s) - DOOR_DROP, s)
		var fore: float = INNER_DOOR.x
		var aft: float = INNER_DOOR.y
		_door("InnerDoor" + named, [at.call(INNER_DOOR.z, fore), at.call(INNER_DOOR.w, fore), at.call(INNER_DOOR.w, aft),
			at.call(INNER_DOOR.z, aft)], at.call(INNER_DOOR.z, fore), at.call(INNER_DOOR.z, aft), Vector3.DOWN,
			Vector3.DOWN, DOOR_OPEN, &"transit", LOWER, paint)
	var tail_pivot: Vector3 = point(0.0, TAIL_PIVOT.y, TAIL_PIVOT.x)
	var tail_axle: Vector3 = point(0.0, TAIL_AXLE.y, TAIL_AXLE.x)
	var tail_stowed: Vector3 = point(0.0, TAIL_STOWED.y, TAIL_STOWED.x)
	var reach: float = (tail_axle - tail_pivot).length()
	tail_stowed = tail_pivot + (tail_stowed - tail_pivot).normalized() * reach
	_leg("TailGear", tail_pivot, tail_axle, tail_stowed, _tail_leg, paint)
	for side in [1.0, -1.0]:
		var named: String = "Starboard" if side > 0.0 else "Port"
		var at := func(o: float, s: float) -> Vector3: return point(o, bottom_at(s) - DOOR_DROP, s)
		var edge: float = side * TAIL_DOOR.z
		var inner: float = side * 0.004
		_door("TailDoor" + named, [at.call(inner, TAIL_DOOR.x), at.call(edge, TAIL_DOOR.x), at.call(edge, TAIL_DOOR.y),
			at.call(inner, TAIL_DOOR.y)], at.call(edge, TAIL_DOOR.x), at.call(edge, TAIL_DOOR.y), Vector3.DOWN,
			Vector3.DOWN, deg_to_rad(80.0), &"down", LOWER, paint)


## A MAIN LEG in its pivot's frame: the oleo from the pivot to the axle, the tyre on the axle's outboard side, and the
## fairing door on the leg's outer face from the pivot down to the tyre's top.
func _main_leg(tool: SurfaceTool, axle: Vector3, side: float) -> void:
	_strut(tool, Vector3.ZERO, axle + Vector3(-side * 0.10, 0.0, 0.0), 0.05, GEAR_METAL)
	_tyre(tool, axle, Vector3.RIGHT, MAIN_TYRE.x, MAIN_TYRE.y, WHEEL_SIDES)
	# THE FAIRING DOOR: a plate on the leg's outboard face, 0.36 m wide, from the pivot to just over the tyre.
	var down: Vector3 = axle.normalized()
	var top: Vector3 = Vector3(side * 0.06, 0.0, 0.0)
	var bottom: Vector3 = down * ((axle.length()) - MAIN_TYRE.x * 0.20) + Vector3(side * 0.06, 0.0, 0.0)
	var fore := Vector3(0.0, 0.0, -0.20)
	var aft := Vector3(0.0, 0.0, 0.16)
	var plate: Array = [top + fore, top + aft, bottom + aft, bottom + fore]
	var thick := Vector3(side * 0.008, 0.0, 0.0)
	var face: Array = []
	var back: Array = []
	for p in plate:
		face.append((p as Vector3) + thick)
		back.append((p as Vector3) - thick)
	_quad(tool, face, Vector3(side, 0.0, 0.0), LOWER)
	_quad(tool, back, Vector3(-side, 0.0, 0.0), WELL)
	for k in range(4):
		var k2: int = (k + 1) % 4
		var mid: Vector3 = ((face[k] as Vector3) + face[k2]) * 0.5
		var centre: Vector3 = ((plate[0] as Vector3) + plate[2]) * 0.5
		_quad(tool, [face[k], face[k2], back[k2], back[k]], mid - centre, LOWER)


## THE TAIL WHEEL in its pivot's frame: a fork from the pivot to the axle and the tyre.
func _tail_leg(tool: SurfaceTool, axle: Vector3) -> void:
	for w in [-0.07, 0.07]:
		_strut(tool, Vector3(w, 0.0, 0.0), axle + Vector3(w, 0.0, 0.0), 0.02, GEAR_METAL)
	_tyre(tool, axle, Vector3.RIGHT, TAIL_TYRE.x, TAIL_TYRE.y, WHEEL_SIDES)
