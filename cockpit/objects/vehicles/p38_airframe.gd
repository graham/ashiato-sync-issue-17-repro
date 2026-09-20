@tool
extends WarbirdAirframe
class_name P38Airframe
## A LOCKHEED P-38L LIGHTNING, DRAWN. Its first-glance features are the two booms, each an Allison V-1710 in a nacelle with
## its turbocharger on top and its radiators in the cheeks behind the wing, ending in an oval fin and rudder; the short
## central gondola with the guns in its nose and the canopy on top; the straight centre section and the tapered outer
## panels with dihedral; the tailplane between the booms' ends; the tricycle gear; and the two propellers, which turn
## OPPOSITE WAYS, their blades rising outboard, away from the gondola. What MOVES:
## - THE GEAR (`set_gear`): the nose leg folds AFT into the gondola and the mains fold AFT into the booms, each behind
##   doors that open as it comes down and stay open while it is down;
## - THE SURFACES: the ailerons, the elevator, both rudders and the flaps;
## - THE PROPELLERS (`set_props`): the starboard clockwise and the port anticlockwise seen from behind (the Training
##   Manual: "the right propeller turns clockwise and the left counter-clockwise, seen from the cockpit").
##
## PRESENTATION ONLY. There is no P-38 kind yet (lane/warbirds, step 3): the airframe dresses from `draft()`.
##
## ORIGINAL GEOMETRY, MEASURED. No mesh, texture, photograph or livery is incorporated. Every size names its source:
## - [AN] the USAAF's own three-view, AN 01-75FF-2 p.2: "Lockheed P-38L Lightning 3-view line drawing.png" on Wikimedia
##   Commons, {{PD-USGov-Military}}, with a great many printed dimensions. `craft/p38/measure_views.py` re-derives every
##   MEASURED figure here. THE VIEWS ARE TURNED ON THE SHEET, each by its own amount, and each is read square: the plan
##   0.92 degrees (its wing's halves then agree to 1 to 3 cm), the side 0.85 (two printed heights then agree), the front
##   not at all (its spinners are level to 0.2 px). The plan is scaled by its printed 52 ft 0 in span (94.07 px a
##   metre), which gives the tailplane's printed 261 in to -0.3 per cent and the booms' printed 2 x 96 in to -0.7; the
##   side by its printed 37 ft 9-15/16 in (94.97 along, and up, where nothing printed says otherwise).
## - [TM] the P-38 Pilot Training Manual (archive.org, public domain): the propellers' ways of turning.
## - [WP] Wikipedia's P-38L specifications: 11.53 m long, 15.85 m span, 27" nose and 36" main tyres are [AN]'s.
## - ESTIMATE where nothing gives a figure, and it says what it was reasoned from.
##
## STATIONS ARE METRES AFT OF THE GONDOLA'S NOSE; HEIGHTS ARE METRES OVER THE FUSELAGE REFERENCE LINE (the thrust line is
## printed 5.078 in, 0.129 m, under it); OUT is metres to starboard. [AN] draws the reference line level and the static
## ground raked under it, the nose tyre lower (printed 5 deg 33 min 46 s): the model is built level, the box's floor the
## main tyres' bottom, and `ground_at` is the static ground through all three tyres. PARKED (`parked()`) it is turned onto
## that ground, nose up, every tyre on the floor.
##
## TESSELLATION, STATED SO NOBODY SUBDIVIDES IT: the GONDOLA 16 facets a ring, the canopy three of them each side; a BOOM
## 12; a SPINNER 12; a TYRE 10; a blade four panels; a wing section seven points. The fins, rudders, tailplane, elevator
## and doors are flat slabs. Every face carries its own normal; nothing is smoothed.

const LENGTH: float = 11.53
const SPAN: float = 15.85

## [AN] THE PRINTED DIMENSIONS the model is built to.
const PRINTED_LENGTH: float = 11.530      # 37 ft 9-15/16 in
const PRINTED_SPAN: float = 15.850        # 52 ft 0 in
const PRINTED_BOOM_OUT: float = 2.438     # 96 in, each boom's centreline
const PRINTED_TRACK: float = 5.029        # 198 in
const PRINTED_TAILPLANE: float = 6.629    # 261 in
const PRINTED_PROP: float = 3.505         # 11 ft 6 in
const PRINTED_PROP_STATION: float = 1.572 # 61.875 in aft of the gondola's nose
const THRUST_H: float = -0.129            # 5.078 in under the reference line

## THE GROUND under the main tyres: the bottom of the real 36 in tyres on their drawn circles' centres (1.917 under the
## reference line).
const GROUND: float = MAIN_AXLE.y - MAIN_TYRE.x * 0.5
## THE FIN'S TOP [AN side]: 1.643 m over the reference line (`measure_views.py`).
const FIN_TOP: float = 1.643

const TOP := WarbirdAirframe.METAL
const LOWER := WarbirdAirframe.METAL_UNDER

## THE GONDOLA [AN side and plan], rows [station, value]: its TOP without the canopy, its BOTTOM and its half-width.
## The side's silhouette is the gondola's alone ahead of the nacelles' spinners (1.05); from there to the wing the
## nacelles stand beside it, lower, and the gondola's own bottom is carried on the same line (ESTIMATE).
const G_TOP: Array = [[0.02, -0.19], [0.25, 0.09], [0.50, 0.184], [0.75, 0.258], [1.00, 0.321], [1.25, 0.353],
	[1.50, 0.395], [1.75, 0.426], [2.00, 0.437], [2.25, 0.448], [2.50, 0.46], [4.75, 0.42], [5.25, 0.30], [5.80, 0.08]]
const G_BOTTOM: Array = [[0.02, -0.23], [0.25, -0.521], [0.50, -0.637], [0.75, -0.700], [1.00, -0.753], [1.25, -0.806],
	[1.50, -0.837], [1.75, -0.858], [2.00, -0.879], [2.50, -0.90], [3.00, -0.89], [3.50, -0.869], [4.00, -0.806],
	[4.50, -0.690], [5.00, -0.55], [5.50, -0.38], [5.80, -0.22]]
const G_HALF_W: Array = [[0.02, 0.03], [0.25, 0.228], [0.50, 0.297], [0.75, 0.356], [1.00, 0.399], [1.25, 0.45],
	[1.75, 0.49], [2.50, 0.505], [3.00, 0.51], [4.50, 0.48], [5.00, 0.44], [5.50, 0.36], [5.80, 0.20]]
const G_RINGS: Array = [0.02, 0.12, 0.25, 0.50, 0.75, 1.00, 1.25, 1.50, 1.75, 2.00, 2.30, 2.55, 2.75, 3.00, 3.25, 3.50,
	3.75, 4.00, 4.25, 4.50, 4.75, 5.00, 5.25, 5.50, 5.80]
const G_SIDES: int = 16
const G_TAIL: Vector2 = Vector2(5.95, -0.08)
## THE CANOPY [AN side's silhouette over the gondola, 2.55 to 4.75; its half-width ESTIMATE, the plan's framing lines]:
## rows [station, sill height, the glass's half-width at the sill, the glass's top].
const CANOPY: Vector2 = Vector2(2.55, 4.90)
const CANOPY_ROWS: Array = [[2.55, 0.46, 0.20, 0.46], [2.75, 0.43, 0.30, 0.595], [3.00, 0.40, 0.36, 0.742],
	[3.25, 0.38, 0.38, 0.869], [3.50, 0.38, 0.38, 0.858], [3.75, 0.38, 0.38, 0.827], [4.00, 0.38, 0.37, 0.774],
	[4.25, 0.39, 0.35, 0.690], [4.50, 0.40, 0.30, 0.627], [4.75, 0.41, 0.20, 0.553], [4.90, 0.42, 0.06, 0.45]]

## THE BOOMS [AN plan and side], rows [station, centre height, half-height, half-width]. The nacelle's front is the
## spinner's base at 1.75; the engine to the wing is 1.2 m deep round the thrust line with the intercooler's chin under
## it (the side's -0.90 at 2.25 to 2.75); the turbo stands on top over the wing; behind the wing the boom's top is flat at
## 0.416 (the side) and its bottom rises straight to the tail; the radiators' cheeks are 0.60 m either side at 7.0 (the
## plan). The half-widths are the plan's, both booms averaged.
const BOOM_ROWS: Array = [[1.75, -0.13, 0.36, 0.40], [2.00, -0.18, 0.60, 0.515], [2.50, -0.21, 0.68, 0.52],
	[3.00, -0.18, 0.66, 0.56], [3.50, -0.14, 0.62, 0.56], [4.00, -0.10, 0.60, 0.52], [4.60, -0.06, 0.60, 0.48],
	[5.20, -0.05, 0.53, 0.44], [5.75, -0.10, 0.50, 0.40], [6.25, -0.03, 0.44, 0.365], [6.60, 0.01, 0.41, 0.36],
	[6.75, 0.02, 0.40, 0.575], [7.00, 0.03, 0.385, 0.605], [7.25, 0.06, 0.36, 0.56], [7.50, 0.08, 0.35, 0.45],
	[7.75, 0.10, 0.32, 0.32], [8.00, 0.11, 0.31, 0.25], [8.50, 0.14, 0.28, 0.22], [9.00, 0.18, 0.23, 0.19],
	[9.50, 0.22, 0.19, 0.155], [10.20, 0.26, 0.15, 0.12], [10.70, 0.28, 0.10, 0.07]]
const BOOM_SIDES: int = 12
## THE SPINNERS: their tips 1.05 aft of the gondola's nose (the plan's nacelles' points), their bases 0.30 m round at 1.75.
const SPINNER: Array = [[0.08, 0.10], [0.25, 0.20], [0.45, 0.27], [0.70, 0.30]]
const SPINNER_TIP: float = 1.05
## THE PROPELLERS: three Curtiss Electric blades each, 11 ft 6 in across, in the plane at the printed 61.875 in.
const PROP_BLADES: int = 3
const PROP_CHORDS: Vector3 = Vector3(0.22, 0.30, 0.22)
const PROP_PITCH: float = deg_to_rad(42.0)
## THE TURBOS on top of the booms over the wing [AN side's humps]: [fore, aft, how high over the boom's top].
const TURBO: Vector3 = Vector3(4.70, 5.30, 0.14)

## THE WING [AN plan and front], rows [out, leading station, trailing station], both wings averaged (to 1 to 3 cm once the
## plan is read square); inside the booms the plan cannot see it and it is carried straight. The CENTRE SECTION is flat on
## the reference line (the root chord is printed rotated about the reference line at 35 per cent); the OUTER PANELS rise
## at the printed 5 deg 40 min from the wing joint at the printed station 115 in (2.921 m out). NACA 23016 at the root,
## 12 per cent at the tip (ESTIMATE).
const WING_ROWS: Array = [[0.45, 2.99, 5.66], [1.00, 3.003, 5.639], [1.50, 3.030, 5.549], [2.92, 3.085, 5.470],
	[3.50, 3.210, 5.219], [4.00, 3.258, 5.134], [4.50, 3.301, 5.060], [5.00, 3.349, 4.975], [5.50, 3.391, 4.890],
	[6.00, 3.434, 4.805], [6.50, 3.476, 4.725], [7.00, 3.513, 4.629], [7.20, 3.535, 4.582], [7.40, 3.556, 4.481],
	[7.50, 3.577, 4.422], [7.60, 3.598, 4.364], [7.70, 3.614, 4.284], [7.80, 3.657, 4.167], [7.90, 3.758, 3.859],
	[7.925, 3.80, 3.82]]
const WING_JOINT: float = 2.921
const DIHEDRAL: float = deg_to_rad(5.0 + 40.0 / 60.0)
const WING_THICK: Vector2 = Vector2(0.16, 0.12)
## THE SURFACES [AN plan]: the aileron 107 in long ending 182 in out... its inner end at the printed 182 in (4.623 m) and
## its outer 107 in beyond (7.341), hinged at 70 per cent of the chord; the flaps the centre section's and the outer panel's
## inner part, their printed 23.5 in chord, from the gondola to the booms and from the booms to the aileron.
const AILERON_SPAN: Vector2 = Vector2(4.623, 7.341)
const AILERON_HINGE_SHARE: float = 0.70
const FLAP_INNER: Vector2 = Vector2(0.55, 1.95)
const FLAP_OUTER: Vector2 = Vector2(2.95, 4.60)
const FLAP_CHORD: float = 0.597

## THE GUNS [AN; WP: four .50s and a 20 mm]: in the gondola's nose, their muzzles at station 0.05 (ESTIMATE).
const GUNS: Array = [Vector3(-0.09, 0.04, 0.05), Vector3(0.09, 0.04, 0.05), Vector3(-0.07, -0.08, 0.05),
	Vector3(0.07, -0.08, 0.05), Vector3(0.0, -0.17, 0.10)]

## THE TAILPLANE [AN plan; side's printed 21.099 in over the thrust line, 0.407 m over the reference line]: its leading
## edge 9.684, its trailing edge 10.800 (the printed 45 in chord, 20 in fixed and 25 in elevator), its tips rounding to the
## printed 261 in span; the ELEVATOR from boom to boom, hinged 20 in behind the leading edge.
const TAIL_H: float = 0.407
const TAIL_LE: float = 9.684
const TAIL_TE: float = 10.800
const TAIL_TIP: Array = [[2.75, 9.690, 10.790], [3.00, 9.743, 10.731], [3.20, 9.86, 10.60], [3.314, 10.20, 10.26]]
const ELEVATOR_HINGE: float = 10.19
const ELEVATOR_OUT: float = 2.30
## THE FINS [AN side, read square]: an oval on each boom's end, [station, height], and the rudder behind the hinge at 10.73.
const FIN: Array = [[9.94, 0.742], [10.05, 1.058], [10.26, 1.427], [10.45, 1.60], [10.62, 1.648], [10.725, 1.64],
	[10.725, -0.469], [10.41, -0.363], [10.15, 0.005], [10.01, 0.268]]
const RUDDER_HINGE: float = 10.73
const RUDDER: Array = [[10.735, 1.64], [11.05, 1.585], [11.36, 1.269], [11.53, 0.742], [11.53, 0.426], [11.41, 0.005],
	[11.15, -0.311], [10.735, -0.469]]

## THE GEAR [AN]: 36 in main and 27 in nose tyres.
## - THE MAINS: axles at the printed 198 in track (2.515 m out), their drawn circles' centres at station 4.366 and 1.460
##   under the reference line (`measure_views.py`, a circle fit to the dashes at rms 1.6 px); each leg pivots in its boom at 4.30, 0.30 under (ESTIMATE) and folds AFT into the boom,
##   the wheel standing upright in it on the boom's own centreline, station 5.44 and 0.06 under. The stowed point only
##   aims the leg, which keeps its length. Aimed 0.022 outboard and 0.01 lower, the tyre's lower outer shoulder stood
##   1.4 cm out through the boom's sloping lower facet; aimed higher, its top stood out (tests/p38.gd).
## - THE NOSE: axle at station 1.351, 1.838 m under ([AN]'s circle); the leg pivots at 1.20, 0.50 under (ESTIMATE) and folds
##   AFT into the gondola.
const MAIN_TYRE: Vector2 = Vector2(0.914, 0.24)
const MAIN_AXLE: Vector3 = Vector3(2.515, -1.460, 4.366)
const MAIN_PIVOT: Vector3 = Vector3(2.46, -0.30, 4.30)
const MAIN_STOWED: Vector3 = Vector3(2.438, -0.06, 5.44)
## The main well's doors: [fore, aft, half-width of the opening]. 0.28 m either side of the boom's middle: at 0.20 the
## tyre's outer face, 0.077 m outboard of the boom's middle with the gear down, swung through the outer door (tests/p38.gd,
## 34 to 38 per cent of the cycle).
const MAIN_DOOR: Vector3 = Vector3(4.20, 5.95, 0.28)
const NOSE_TYRE: Vector2 = Vector2(0.686, 0.18)
const NOSE_AXLE: Vector3 = Vector3(0.0, -1.838, 1.351)
const NOSE_PIVOT: Vector3 = Vector3(0.0, -0.50, 1.20)
const NOSE_DOOR: Vector3 = Vector3(1.05, 2.30, 0.17)
const WHEEL_SIDES: int = 10


func dress(geometry: Dictionary = {}) -> void:
	name = "P38"
	_take(geometry)
	# TRAVELS, ESTIMATE: the manuals read give none.
	aileron_travel = deg_to_rad(15.0)
	elevator_up = deg_to_rad(28.0)
	elevator_down = deg_to_rad(20.0)
	rudder_travel = deg_to_rad(25.0)
	flap_travel = deg_to_rad(45.0)
	var paint: StandardMaterial3D = _paint()
	var inside: StandardMaterial3D = _paint()
	inside.cull_mode = BaseMaterial3D.CULL_DISABLED
	var body := _tool()
	var canopy := _tool()
	_gondola(body, canopy)
	var gondola := _add(self, "Gondola", body, paint)
	gondola.material_override = null
	gondola.mesh = canopy.commit(gondola.mesh as ArrayMesh)
	gondola.set_surface_override_material(0, inside)
	gondola.set_surface_override_material(1, _glass())
	var guns := _tool()
	for g in GUNS:
		var at: Vector3 = g as Vector3
		var loops: Array = []
		for s in [at.z, at.z + 0.45]:
			loops.append(_ring(point(at.x, at.y, s), Vector3.BACK, 0.025, 0.025, 6))
		_loft(guns, loops, [GUNMETAL])
	_small(_add(self, "Guns", guns, paint))
	var wells := _tool()
	_wells(wells)
	_add(self, "Wells", wells, paint)
	for side in [1.0, -1.0]:
		var named: String = "Starboard" if side > 0.0 else "Port"
		var boom := _tool()
		_boom(boom, side)
		_add(self, "Boom" + named, boom, paint)
		var turbo := _tool()
		_turbo(turbo, side)
		_small(_add(self, "Turbo" + named, turbo, paint))
		var spinner := _tool()
		var tip: Vector3 = point(side * PRINTED_BOOM_OUT, THRUST_H, SPINNER_TIP)
		_spinner(spinner, tip, point(side * PRINTED_BOOM_OUT, THRUST_H, SPINNER_TIP + float(SPINNER[-1][0])), SPINNER, 12,
			TOP)
		_add(self, "Spinner" + named, spinner, paint)
		# THE PROPELLERS TURN OUTBOARD AT THE TOP, AWAY FROM THE GONDOLA [TM]: the starboard clockwise seen from behind.
		_propeller("Propeller" + named, point(side * PRINTED_BOOM_OUT, THRUST_H, PRINTED_PROP_STATION),
			PRINTED_PROP * 0.5, PROP_BLADES, PROP_CHORDS, PROP_PITCH, side, 0.26, paint)
		var wing := _tool()
		_wing(wing, side)
		_add(self, "Wing" + named, wing, paint)
		_aileron(side, named, paint)
		_flap("FlapInner" + named, side, FLAP_INNER, paint)
		_flap("FlapOuter" + named, side, FLAP_OUTER, paint)
		var fin := _tool()
		_slab(fin, _outline(FIN), func(p: Vector2) -> Vector3: return point(side * PRINTED_BOOM_OUT, p.y, p.x),
			Vector3.RIGHT, 0.06, TOP)
		_add(self, "Fin" + named, fin, paint)
		_rudder(side, named, paint)
	var tail := _tool()
	_tailplane(tail)
	_add(self, "Tailplane", tail, paint)
	_elevator(paint)
	_build_gear(paint)
	set_gear(1.0)


func draft() -> Dictionary:
	return {"extents": Vector3(PRINTED_BOOM_OUT + 0.65, (FIN_TOP - GROUND) * 0.5, PRINTED_LENGTH * 0.5),
		"span": PRINTED_SPAN}


func ground_height() -> float:
	return GROUND


## THE AEROPLANE PARKED ON ITS STATIC GROUND, ALL THREE TYRES ON IT: the level-built frame turned nose up about the main
## axles until the nose tyre's bottom comes up level with the mains'. [AN] draws the reference line level and prints the
## static ground 5 deg 33 min 46 s to it, the nose tyre lower, and the tyres drawn put it at 5.00. Left at the kit's
## tricycle default (as built, level), the mains stood on the floor and the NOSE TYRE WENT 0.26 m THROUGH IT: the user,
## 2026-09-19, "the front wheel on the p-38 doesn't seem to be colliding with the floor correctly". `tests/p38.gd` holds
## every tyre's lowest drawn vertex on the floor.
##
## THE TURN, from the axles and radii: the nose tyre's centre, `ahead` of the main axle and `below` it, must stand its own
## radius less the main tyre's over the main axle, so ahead sin(t) - below cos(t) = r_nose - r_main, which is
## t = atan2(below, ahead) + asin((r_nose - r_main) / |(ahead, below)|). A ten-facet tyre turned by t brings a corner
## round under its flat, so the frame is lifted by the deeper of the two, as `_three_point` does for a taildragger.
func parked() -> Transform3D:
	var ahead: float = MAIN_AXLE.z - NOSE_AXLE.z
	var below: float = MAIN_AXLE.y - NOSE_AXLE.y
	var main_radius: float = MAIN_TYRE.x * 0.5
	var nose_radius: float = NOSE_TYRE.x * 0.5
	var rake: float = atan2(below, ahead) + asin((nose_radius - main_radius) / Vector2(ahead, below).length())
	var axle: Vector3 = point(0.0, MAIN_AXLE.y, MAIN_AXLE.z)
	var turn := Basis(Vector3.RIGHT, rake)
	var half_facet: float = PI / float(WHEEL_SIDES)
	var off: float = absf(fposmod(rake + half_facet * 2.0, half_facet * 2.0) - half_facet)
	var lift: float = maxf(main_radius, nose_radius) * (cos(off) / cos(half_facet) - 1.0)
	return Transform3D(turn, axle - turn * axle + Vector3.UP * lift)


## THE STATIC GROUND, as a height over the reference line at `station`: the line under the nose tyre's and the main tyres'
## bottoms.
static func ground_at(station: float) -> float:
	var nose := Vector2(NOSE_AXLE.z, NOSE_AXLE.y - NOSE_TYRE.x * 0.5)
	var main := Vector2(MAIN_AXLE.z, MAIN_AXLE.y - MAIN_TYRE.x * 0.5)
	return lerpf(nose.y, main.y, (station - nose.x) / (main.x - nose.x))


# ---- the gondola ----------------------------------------------------------------------------------------------------

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


## THE GONDOLA'S HALF-SECTION at `s`: nine points, eight facets, an upright oval; over the canopy the first four are glass.
static func half_section(s: float) -> Array:
	var top: float = _profile(G_TOP, s)
	var bottom: float = _profile(G_BOTTOM, s)
	var w: float = _profile(G_HALF_W, s)
	var c: float = (top + bottom) * 0.5
	var b: float = (top - bottom) * 0.5
	var half: Array = []
	for k in range(9):
		var theta: float = PI * float(k) / 8.0
		half.append(Vector2(w * pow(absf(sin(theta)), 0.85), c + b * signf(cos(theta)) * pow(absf(cos(theta)), 0.85)))
	if glazed(s):
		var cp: Vector3 = canopy_at(s)
		half[0] = Vector2(0.0, cp.z)
		half[1] = Vector2(0.50 * cp.y, cp.z - 0.12 * (cp.z - cp.x))
		half[2] = Vector2(0.85 * cp.y, cp.x + 0.45 * (cp.z - cp.x))
		half[3] = Vector2(cp.y, cp.x)
		var shoulder: Vector2 = half[4]
		half[4] = Vector2(maxf(shoulder.x, cp.y + 0.015), minf(shoulder.y, cp.x - 0.015))
	return half


func _gondola(tool: SurfaceTool, canopy: SurfaceTool) -> void:
	var rings: Array = []
	for s in G_RINGS:
		var half: Array = half_section(float(s))
		var ring: Array = []
		for i in range(half.size() - 1):
			ring.append(point((half[i] as Vector2).x, (half[i] as Vector2).y, float(s)))
		for i in range(half.size() - 1, 0, -1):
			ring.append(point(-(half[i] as Vector2).x, (half[i] as Vector2).y, float(s)))
		rings.append(ring)
	var n: int = G_SIDES
	for r in range(rings.size() - 1):
		var here: float = (float(G_RINGS[r]) + float(G_RINGS[r + 1])) * 0.5
		var glass: bool = here > CANOPY.x and here < CANOPY.y
		var centre: Vector3 = point(0.0, (_profile(G_TOP, here) + _profile(G_BOTTOM, here)) * 0.5, here)
		for k in range(n):
			var quad: Array = [rings[r][k], rings[r][(k + 1) % n], rings[r + 1][(k + 1) % n], rings[r + 1][k]]
			var mid: Vector3 = ((quad[0] as Vector3) + quad[1] + quad[2] + quad[3]) * 0.25
			var out: Vector3 = Vector3(mid.x - centre.x, mid.y - centre.y, 0.0)
			if glass and (k <= 2 or k >= n - 3):
				_quad(canopy, quad, out, GLASS)
				continue
			var normal: Vector3 = ((quad[2] as Vector3) - (quad[0] as Vector3)).cross(
				(quad[1] as Vector3) - (quad[0] as Vector3)).normalized()
			if normal.dot(out) < 0.0:
				normal = -normal
			var tint: Color = TOP if normal.y > 0.2 else LOWER
			if here > 1.2 and here < CANOPY.x and normal.y > 0.6:
				tint = OLIVE
			_quad(tool, quad, out, tint)
	var nose: Vector3 = point(0.0, -0.21, 0.0)
	for k in range(n):
		_fan(tool, nose, rings[0][k], rings[0][(k + 1) % n], Vector3.FORWARD, TOP)
	var end: Vector3 = point(0.0, G_TAIL.y, G_TAIL.x)
	for k in range(n):
		_fan(tool, end, rings[-1][k], rings[-1][(k + 1) % n], Vector3.BACK, LOWER)


# ---- the booms ------------------------------------------------------------------------------------------------------

## A BOOM'S SECTION at `s`: (centre height, half-height, half-width).
static func _boom_at(s: float) -> Vector3:
	for i in range(BOOM_ROWS.size() - 1):
		var a: Array = BOOM_ROWS[i]
		var b: Array = BOOM_ROWS[i + 1]
		if s <= float(b[0]):
			var t: float = clampf((s - float(a[0])) / (float(b[0]) - float(a[0])), 0.0, 1.0)
			return Vector3(lerpf(float(a[1]), float(b[1]), t), lerpf(float(a[2]), float(b[2]), t),
				lerpf(float(a[3]), float(b[3]), t))
	var last: Array = BOOM_ROWS[-1]
	return Vector3(float(last[1]), float(last[2]), float(last[3]))


## ONE BOOM: 12 facets a ring through its rows, an oval a little flattened on top; closed at the spinner's base (the
## nacelle's front) and at the tail.
func _boom(tool: SurfaceTool, side: float) -> void:
	var loops: Array = []
	for row in BOOM_ROWS:
		var s: float = float(row[0])
		var loop: Array = []
		for k in range(BOOM_SIDES):
			var t: float = TAU * (float(k) + 0.5) / float(BOOM_SIDES)
			var y: float = cos(t)
			loop.append(point(side * PRINTED_BOOM_OUT + float(row[3]) * sin(t),
				float(row[1]) + float(row[2]) * signf(y) * pow(absf(y), 0.8), s))
		loops.append(loop)
	var tints: Array = []
	for k in range(BOOM_SIDES):
		tints.append(TOP if cos(TAU * (float(k) + 0.5) / float(BOOM_SIDES)) > 0.3 else LOWER)
	_loft(tool, loops, tints)
	# THE INTERCOOLER'S MOUTH under the spinner: a dark face on the nacelle's lower front.
	var s0: float = float(BOOM_ROWS[0][0]) + 0.02
	var w: float = 0.22
	Plating.facing(tool, [point(side * PRINTED_BOOM_OUT - w, THRUST_H - 0.25, s0 + 0.25),
		point(side * PRINTED_BOOM_OUT + w, THRUST_H - 0.25, s0 + 0.25),
		point(side * PRINTED_BOOM_OUT + w, THRUST_H - 0.55, s0 + 0.28),
		point(side * PRINTED_BOOM_OUT - w, THRUST_H - 0.55, s0 + 0.28)], Vector3.FORWARD, BLACK)


## ONE TURBO: a metal hood rising out of the boom's top, flat over its aft two thirds, with the turbine's dark wheel lying
## in its top. A plain dark box read as a black crate from every quarter.
func _turbo(tool: SurfaceTool, side: float) -> void:
	var o: float = side * PRINTED_BOOM_OUT
	var loops: Array = []
	for row in [[0.0, 0.1, 0.4], [0.25, 0.8, 0.9], [0.5, 1.0, 1.0], [1.0, 1.0, 0.95]]:
		var s: float = lerpf(TURBO.x, TURBO.y, float(row[0]))
		var base: float = _boom_at(s).x + _boom_at(s).y - 0.04
		var high: float = TURBO.z * float(row[1]) + 0.04
		var w: float = 0.19 * float(row[2])
		loops.append([point(o - w, base, s), point(o - w * 0.8, base + high * 0.75, s), point(o - w * 0.35, base + high, s),
			point(o + w * 0.35, base + high, s), point(o + w * 0.8, base + high * 0.75, s), point(o + w, base, s)])
	_loft(tool, loops, [TOP])
	var s_wheel: float = lerpf(TURBO.x, TURBO.y, 0.72)
	var wheel: Vector3 = point(o, _boom_at(s_wheel).x + _boom_at(s_wheel).y + TURBO.z + 0.005, s_wheel)
	var rim: Array = _ring(wheel, Vector3.UP, 0.12, 0.12, 10)
	for k in range(rim.size()):
		_fan(tool, wheel, rim[k], rim[(k + 1) % rim.size()], Vector3.UP, GUNMETAL)


# ---- the wing -------------------------------------------------------------------------------------------------------

static func _wing_row(out: float) -> Vector2:
	var a0: float = clampf(absf(out), float(WING_ROWS[0][0]), float(WING_ROWS[-1][0]))
	for i in range(WING_ROWS.size() - 1):
		var a: Array = WING_ROWS[i]
		var b: Array = WING_ROWS[i + 1]
		if a0 <= float(b[0]):
			var t: float = (a0 - float(a[0])) / (float(b[0]) - float(a[0]))
			return Vector2(lerpf(float(a[1]), float(b[1]), t), lerpf(float(a[2]), float(b[2]), t))
	return Vector2(float(WING_ROWS[-1][1]), float(WING_ROWS[-1][2]))


static func wing_le(out: float) -> float:
	return _wing_row(out).x


static func wing_te(out: float) -> float:
	return _wing_row(out).y


## THE WING'S MIDDLE SURFACE over the reference line: flat on it to the joint, then the dihedral.
static func wing_mid(out: float) -> float:
	var a: float = absf(out)
	return 0.0 if a <= WING_JOINT else (a - WING_JOINT) * tan(DIHEDRAL)


static func wing_thick_at(out: float) -> float:
	var a: float = absf(out)
	return lerpf(WING_THICK.x, WING_THICK.y, clampf((a - WING_JOINT) / (SPAN * 0.5 - WING_JOINT), 0.0, 1.0)) \
		* (wing_te(a) - wing_le(a))


## WHERE THE FIXED WING ENDS at `out`: a flap's or the aileron's hinge where one is hinged behind it, else the trailing edge.
static func hinge_at(out: float) -> float:
	var a: float = absf(out)
	if a >= AILERON_SPAN.x - 0.001 and a <= AILERON_SPAN.y + 0.001:
		return wing_le(a) + AILERON_HINGE_SHARE * (wing_te(a) - wing_le(a))
	for span in [FLAP_INNER, FLAP_OUTER]:
		if a >= (span as Vector2).x - 0.001 and a <= (span as Vector2).y + 0.001:
			return wing_te(a) - FLAP_CHORD
	return wing_te(a)


static func _surface_rows(a: float) -> int:
	if a > AILERON_SPAN.x and a < AILERON_SPAN.y:
		return 2
	if (a > FLAP_INNER.x and a < FLAP_INNER.y) or (a > FLAP_OUTER.x and a < FLAP_OUTER.y):
		return 1
	return 0


static func _depth_at(out: float, at: float) -> float:
	var le: float = wing_le(out)
	var te: float = wing_te(out)
	var f: float = clampf((at - le) / (te - le), 0.30, 1.0)
	return maxf(wing_thick_at(out) * 0.5 * (1.0 - f) / 0.70, 0.005)


func _section(out: float, end: float, side: float) -> Array:
	var le: float = wing_le(out)
	var te: float = wing_te(out)
	var c: float = te - le
	var mid: float = wing_mid(out)
	var t: float = wing_thick_at(out)
	var at_end: float = _depth_at(out, end)
	return [point(side * out, mid, le), point(side * out, mid + 0.42 * t, le + 0.12 * c),
		point(side * out, mid + 0.5 * t, le + 0.30 * c), point(side * out, mid + at_end, end),
		point(side * out, mid - at_end, end), point(side * out, mid - 0.5 * t, le + 0.30 * c),
		point(side * out, mid - 0.42 * t, le + 0.12 * c)]


const _SURFACE_TINTS: Array = [TOP, TOP, TOP, LOWER, LOWER, LOWER, LOWER]


## THE WING, one side: from inside the gondola to the tip, a closed loft between each pair of sections, each bay cut at
## the hinge of the surface behind it.
func _wing(tool: SurfaceTool, side: float) -> void:
	var outs: Array = []
	for row in WING_ROWS:
		outs.append(float(row[0]))
	for x in [FLAP_INNER.x, FLAP_INNER.y, FLAP_OUTER.x, FLAP_OUTER.y, AILERON_SPAN.x, AILERON_SPAN.y, WING_JOINT]:
		outs.append(float(x))
	outs.sort()
	var clean: Array = []
	for o in outs:
		if clean.is_empty() or float(o) - float(clean[-1]) > 0.005:
			clean.append(o)
	for i in range(clean.size() - 1):
		var a: float = float(clean[i])
		var b: float = float(clean[i + 1])
		var kind: int = _surface_rows((a + b) * 0.5)
		var loops: Array = []
		for out in [a, b]:
			var end: float = wing_te(float(out))
			if kind == 2:
				end = wing_le(float(out)) + AILERON_HINGE_SHARE * (wing_te(float(out)) - wing_le(float(out)))
			elif kind == 1:
				end = wing_te(float(out)) - FLAP_CHORD
			loops.append(_section(float(out), end, side))
		_loft(tool, loops, _SURFACE_TINTS)


## A SURFACE'S LOOP at `out`, hinge `h` to the trailing edge, in the hinge's frame.
func _surface_loop(side: float, out: float, h: float, at: Vector3) -> Array:
	var te: float = wing_te(out)
	var m: float = wing_mid(out)
	var d: float = _depth_at(out, h + 0.01)
	return [point(side * out, m + d, h + 0.01) - at, point(side * out, m + 0.005, te) - at,
		point(side * out, m - 0.005, te) - at, point(side * out, m - d, h + 0.01) - at]


func _aileron(side: float, named: String, paint: Material) -> void:
	var o0: float = AILERON_SPAN.x + 0.02
	var o1: float = AILERON_SPAN.y - 0.02
	var h := func(o: float) -> float: return wing_le(o) + AILERON_HINGE_SHARE * (wing_te(o) - wing_le(o))
	var inner: Vector3 = point(side * o0, wing_mid(o0), h.call(o0))
	var outer: Vector3 = point(side * o1, wing_mid(o1), h.call(o1))
	var mid: Vector3 = (inner + outer) * 0.5
	var hinge := _hinge("Aileron" + named, self, mid, outer - inner, mid + Vector3.BACK, Vector3.DOWN)
	var tool := _tool()
	var loops: Array = []
	var outs: Array = [o0]
	for row in WING_ROWS:
		if float(row[0]) > o0 + 0.01 and float(row[0]) < o1 - 0.01:
			outs.append(float(row[0]))
	outs.append(o1)
	for o in outs:
		loops.append(_surface_loop(side, float(o), h.call(float(o)), mid))
	_loft(tool, loops, [TOP, TOP, LOWER, LOWER])
	_add(hinge, "Aileron" + named, tool, paint)


## A FLAP, hinged under the wing's lower skin at its printed chord ahead of the trailing edge (the P-38's are Fowler flaps,
## which slide back as they go down: drawn turning about a hinge, as the house draws flaps).
func _flap(named: String, side: float, span: Vector2, paint: Material) -> void:
	var o0: float = span.x + 0.02
	var o1: float = span.y - 0.02
	var at := func(o: float) -> Vector3:
		var h: float = wing_te(o) - FLAP_CHORD
		return point(side * o, wing_mid(o) - _depth_at(o, h), h)
	var inner: Vector3 = at.call(o0)
	var outer: Vector3 = at.call(o1)
	var mid: Vector3 = (inner + outer) * 0.5
	var hinge := _hinge(named, self, mid, outer - inner, mid + Vector3.BACK, Vector3.DOWN)
	var tool := _tool()
	# A SECTION AT EACH OF THE WING'S ROWS it spans, so its trailing edge is the wing's: lofted between its ends only, it
	# stood 6 cm off the drawn edge 4.0 m out.
	var outs: Array = [o0]
	for row in WING_ROWS:
		if float(row[0]) > o0 + 0.01 and float(row[0]) < o1 - 0.01:
			outs.append(float(row[0]))
	outs.append(o1)
	var loops: Array = []
	for o in outs:
		loops.append(_surface_loop(side, float(o), wing_te(float(o)) - FLAP_CHORD, mid))
	_loft(tool, loops, [TOP, TOP, LOWER, LOWER])
	_add(hinge, named, tool, paint)


# ---- the tail -------------------------------------------------------------------------------------------------------

## THE TAILPLANE from tip to tip across the booms' ends, its leading edge to the elevator's hinge between the booms and to
## its own trailing edge outboard of them.
func _tailplane(tool: SurfaceTool) -> void:
	var starboard: Array = [[0.0, TAIL_LE]]
	for row in TAIL_TIP:
		starboard.append([float(row[0]), float(row[1])])
	for i in range(TAIL_TIP.size() - 1, -1, -1):
		starboard.append([float(TAIL_TIP[i][0]), float(TAIL_TIP[i][2])])
	starboard.append([ELEVATOR_OUT + 0.01, TAIL_TE])
	starboard.append([ELEVATOR_OUT + 0.01, ELEVATOR_HINGE])
	starboard.append([0.0, ELEVATOR_HINGE])
	var outline: Array = starboard.duplicate()
	for i in range(starboard.size() - 2, 0, -1):
		outline.append([-float(starboard[i][0]), float(starboard[i][1])])
	var place := func(p: Vector2) -> Vector3: return point(p.x, TAIL_H, p.y)
	_slab(tool, _outline(outline), place, Vector3.UP, 0.05, TOP, LOWER)


## THE ELEVATOR, one piece across between the booms, on its hinge 20 in behind the leading edge.
func _elevator(paint: Material) -> void:
	var inner: Vector3 = point(-ELEVATOR_OUT, TAIL_H, ELEVATOR_HINGE)
	var outer: Vector3 = point(ELEVATOR_OUT, TAIL_H, ELEVATOR_HINGE)
	var mid: Vector3 = (inner + outer) * 0.5
	var hinge := _hinge("ElevatorStarboard", self, mid, outer - inner, mid + Vector3.BACK, Vector3.DOWN)
	var tool := _tool()
	var place := func(p: Vector2) -> Vector3: return point(p.x, TAIL_H, p.y) - mid
	_slab(tool, _outline([[-ELEVATOR_OUT, ELEVATOR_HINGE + 0.01], [ELEVATOR_OUT, ELEVATOR_HINGE + 0.01],
		[ELEVATOR_OUT, TAIL_TE], [-ELEVATOR_OUT, TAIL_TE]]), place, Vector3.UP, 0.035, TOP, LOWER)
	_add(hinge, "Elevator", tool, paint)


func _rudder(side: float, named: String, paint: Material) -> void:
	var foot: Vector3 = point(side * PRINTED_BOOM_OUT, float(RUDDER[-1][1]), RUDDER_HINGE)
	var head: Vector3 = point(side * PRINTED_BOOM_OUT, float(RUDDER[0][1]), RUDDER_HINGE)
	var hinge := _hinge("Rudder" + named, self, foot, head - foot, foot + Vector3.BACK, Vector3.RIGHT)
	var tool := _tool()
	var local := func(p: Vector2) -> Vector3: return point(side * PRINTED_BOOM_OUT, p.y, p.x) - foot
	_slab(tool, _outline(RUDDER), local, Vector3.RIGHT, 0.04, TOP)
	_add(hinge, "Rudder" + named, tool, paint)


# ---- the gear -------------------------------------------------------------------------------------------------------

func _wells(tool: SurfaceTool) -> void:
	for side in [1.0, -1.0]:
		var bottom: float = _boom_at((MAIN_DOOR.x + MAIN_DOOR.y) * 0.5).x - _boom_at((MAIN_DOOR.x + MAIN_DOOR.y) * 0.5).y
		var o: float = side * PRINTED_BOOM_OUT
		Plating.facing(tool, [point(o - MAIN_DOOR.z, bottom + 0.03, MAIN_DOOR.x), point(o + MAIN_DOOR.z, bottom + 0.03, MAIN_DOOR.x),
			point(o + MAIN_DOOR.z, bottom + 0.03, MAIN_DOOR.y), point(o - MAIN_DOOR.z, bottom + 0.03, MAIN_DOOR.y)],
			Vector3.DOWN, WELL)
	# THE NOSE WELL'S ROOF follows the gondola's bottom at each end: laid level at the middle's depth, its front stood 4 cm
	# out under the rising nose, an olive patch in the picture from below with the gear up.
	var g0: float = _profile(G_BOTTOM, NOSE_DOOR.x) + 0.06
	var g1: float = _profile(G_BOTTOM, NOSE_DOOR.y) + 0.06
	Plating.facing(tool, [point(-NOSE_DOOR.z, g0, NOSE_DOOR.x), point(NOSE_DOOR.z, g0, NOSE_DOOR.x),
		point(NOSE_DOOR.z, g1, NOSE_DOOR.y), point(-NOSE_DOOR.z, g1, NOSE_DOOR.y)], Vector3.DOWN, WELL)


func _build_gear(paint: Material) -> void:
	for side in [1.0, -1.0]:
		var named: String = "Starboard" if side > 0.0 else "Port"
		var pivot: Vector3 = point(side * MAIN_PIVOT.x, MAIN_PIVOT.y, MAIN_PIVOT.z)
		var axle: Vector3 = point(side * MAIN_AXLE.x, MAIN_AXLE.y, MAIN_AXLE.z)
		var stowed: Vector3 = point(side * MAIN_STOWED.x, MAIN_STOWED.y, MAIN_STOWED.z)
		stowed = pivot + (stowed - pivot).normalized() * (axle - pivot).length()
		_leg("MainGear" + named, pivot, axle, stowed, _main_leg.bind(side), paint)
		_boom_doors(side, named, MAIN_DOOR, paint)
	var npivot: Vector3 = point(0.0, NOSE_PIVOT.y, NOSE_PIVOT.z)
	var naxle: Vector3 = point(0.0, NOSE_AXLE.y, NOSE_AXLE.z)
	var nstowed: Vector3 = npivot + Vector3(0.0, 0.0, 1.0) * (naxle - npivot).length()
	_leg("NoseGear", npivot, naxle, nstowed, _nose_leg, paint)
	for side in [1.0, -1.0]:
		var named: String = "Starboard" if side > 0.0 else "Port"
		var g := func(s: float) -> float: return _profile(G_BOTTOM, s) - DOOR_DROP
		var edge: float = side * NOSE_DOOR.z
		var inner: float = side * 0.004
		_door("NoseDoor" + named, [point(inner, g.call(NOSE_DOOR.x), NOSE_DOOR.x), point(edge, g.call(NOSE_DOOR.x), NOSE_DOOR.x),
			point(edge, g.call(NOSE_DOOR.y), NOSE_DOOR.y), point(inner, g.call(NOSE_DOOR.y), NOSE_DOOR.y)],
			point(edge, g.call(NOSE_DOOR.x), NOSE_DOOR.x), point(edge, g.call(NOSE_DOOR.y), NOSE_DOOR.y), Vector3.DOWN,
			Vector3.DOWN, deg_to_rad(85.0), &"down", LOWER, paint)


## A BOOM'S TWO DOORS under the main well, hinged on the well's edges and opening down; open while the gear is down.
func _boom_doors(side: float, named: String, span: Vector3, paint: Material) -> void:
	var o: float = side * PRINTED_BOOM_OUT
	var b := func(s: float) -> float: return _boom_at(s).x - _boom_at(s).y - DOOR_DROP
	for half in [1.0, -1.0]:
		var edge: float = o + half * span.z
		var inner: float = o + half * 0.004
		var which: String = "Outer" if half * side > 0.0 else "Inner"
		_door("MainDoor" + which + named, [point(inner, b.call(span.x), span.x), point(edge, b.call(span.x), span.x),
			point(edge, b.call(span.y), span.y), point(inner, b.call(span.y), span.y)], point(edge, b.call(span.x), span.x),
			point(edge, b.call(span.y), span.y), Vector3.DOWN, Vector3.DOWN, deg_to_rad(85.0), &"down", LOWER, paint)


func _main_leg(tool: SurfaceTool, axle: Vector3, side: float) -> void:
	_strut(tool, Vector3.ZERO, axle + Vector3(-side * 0.14, 0.0, 0.0), 0.06, GEAR_METAL)
	_tyre(tool, axle, Vector3.RIGHT, MAIN_TYRE.x, MAIN_TYRE.y, WHEEL_SIDES)


func _nose_leg(tool: SurfaceTool, axle: Vector3) -> void:
	for w in [-0.11, 0.11]:
		_strut(tool, Vector3(w * 0.3, 0.0, 0.0), axle + Vector3(w, 0.0, 0.0), 0.035, GEAR_METAL)
	_tyre(tool, axle, Vector3.RIGHT, NOSE_TYRE.x, NOSE_TYRE.y, WHEEL_SIDES)
