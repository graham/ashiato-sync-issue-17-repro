@tool
extends Node3D
class_name SailplaneAirframe
## A SCHEMPP-HIRTH DUO DISCUS, DRAWN: a 20 m two-seat high-performance sailplane. Two pilots in tandem under ONE long
## canopy, a slim pod running back into a thin tail boom, a T-tail, a long wing whose inner panels sweep slightly FORWARD
## (so the back-seat pilot sits ahead of the spar, which is the Duo's trademark) and whose tips turn up, with winglets.
##
## ASKED FOR ON 2026-09-18: "The current sailplane is not a very good model, could you model something like the photos on
## this page [Pajno's V 1/2 Rondine, on the cover of 'Sailplane Design Example'] ... it should be a two seater as well,
## with joysticks in both, the seat is even more reclined than the f16". The Rondine is the LOOK -- long slender tapered
## wings with the tips turned up, a slim boom, a T-tail, a big bubble canopy over a reclined pilot -- and the cover is
## copyrighted, so nothing is measured from it. The Duo Discus is the real two-seater with that look.
##
## THE SIMULATION GIVES THE SIZE, THIS GIVES THE SHAPE. The box is `kind_geometry`'s (kind 17, `glider_shape`); every
## other size is MEASURED off [SH], Schempp-Hirth's own three-view (Duo Discus flight manual section 1.5, October 1993),
## by `craft/glider/measure_duo.py`, which re-derives every table below from the drawing alone and prints them. The
## drawing is used to MEASURE FROM and is in no part of the game. ONE published number scales it: the 20.00 m span [SH
## 1.4.3]. The checks that the scale is honest, both run by the script:
##   - the side view then reads 8.605 m nose to rudder against the published 8.62 (0.2 per cent);
##   - the front view's span agrees with the plan view's to 0.2 per cent, so the scan is isotropic;
##   - the plan view's chords, taken between line centres, integrate to 16.67 m2 against the published 16.40 (1.6 per
##     cent over). THE PUBLISHED AREA IS THE STRONGER FIGURE, as it was for the DG before this (`sources.md`), so every
##     chord is scaled about its quarter-chord point by `chord_scale()`, COMPUTED from the table and the area, never typed.
##
## THE FRAME IS THE DRAWING'S, IN METRES: `x` aft of the nose tip, `y` over the ground under the main wheel with the
## aeroplane LEVEL (as the manual draws it: the tail wheel is 0.29 m clear, not on the ground), `out` to starboard.
## `at(out, x, y)` turns that into the craft's frame, the nose on the box's front face and the ground on its floor.
##
## DEVIATIONS FROM THE AEROPLANE, each stated where it is made:
##   - THE CANOPY IS A BUBBLE 0.10 m TALLER than the Duo's (`CANOPY_RAISE`), which is also the Rondine's look. The game's
##     rig puts a player's eye 1.35 m over the seat anchor and `tests/seat_room.gd` wants 0.25 m of glass over it; the
##     Duo's crown is 0.90 m over its belly at the front seat. A real pilot lies back with the eye 0.8 m over a pan on
##     the belly; this game's body is upright. See `crew_eyes` and `cabin_room`.
##   - THE FRONT COCKPIT IS FILLED OUT to the pod's full width (`COCKPIT_HALF`), where the Duo narrows towards its nose.
##   - WINGLETS, which the 1993 drawing does not have: the Duo Discus X, XL and XLT carry them. ESTIMATE from photographs
##     (`sources.md`), stood on the drawn 20 m tip so the span does not move.
##
## TESSELLATION, STATED SO NOBODY SUBDIVIDES IT (`modelling_here.md` section 4; the Hawkeye's fuselage ring is 20):
##   - FUSELAGE: 14 flat facets a ring through 26 measured sections; the top three each side are the canopy's glass.
##   - A wing, tail or fin section is SIX points: leading edge, two over, trailing edge, two under.
##   - WHEEL_SIDES 10.
## Every face carries its own normal (`Plating.facing`), so no edge is smoothed.
##
## FIVE THINGS MOVE, each on a hinge node carrying its axis: the ailerons and the elevator from the stick, the rudder
## from the pedals, the airbrake paddles from the airbrake lever, and the main wheel from the gear bit. Driven by
## `VehicleView.draw_the_sailplane_from`, as the F-16's are, from whichever seat's stick the linkage carries.
##
## NOT IN VehicleView's `_body`: `_show_body` paints one flat material over every mesh there, and this airframe's colour
## is in its vertices (`lane/fleet`, Hawkeye).

## ---- the aeroplane's published figures [SH 1.4.3] -----------------------------------------------------------------
const SPAN: float = 20.00
const WING_AREA: float = 16.40
const LENGTH: float = 8.62
const FUSELAGE_WIDTH: float = 0.71
const FUSELAGE_HEIGHT: float = 1.00
const ASPECT_RATIO: float = 24.4
const MAC: float = 0.875

const WHITE := Color(0.95, 0.95, 0.96)
const UNDER := Color(0.86, 0.87, 0.89)
const GLASS := Color(0.30, 0.38, 0.44)
const FRAME := Color(0.16, 0.17, 0.18)
const BLACK := Color(0.05, 0.05, 0.05)
const METAL := Color(0.45, 0.46, 0.47)
## THE WINGLETS' AND THE FIN TIP'S DAY-GLO, which is what most gliders wear to be seen by one another.
const DAYGLO := Color(0.93, 0.28, 0.12)

## THE FUSELAGE, MEASURED [SH]: at each station `x`, the top of the outline, the bottom of it (the belly, not a wheel),
## and the half-width in plan. Line centres, 132.95 px a metre. The top here is the Duo's own, before `CANOPY_RAISE`.
const SECTIONS: Array = [
	[0.10, 0.688, 0.496, 0.079], [0.30, 0.801, 0.440, 0.160], [0.50, 0.891, 0.395, 0.215], [0.70, 0.970, 0.357, 0.244],
	[1.00, 1.083, 0.301, 0.293], [1.30, 1.151, 0.267, 0.323], [1.60, 1.203, 0.252, 0.338], [1.90, 1.241, 0.244, 0.346],
	[2.30, 1.260, 0.233, 0.346], [2.70, 1.226, 0.237, 0.346], [3.10, 1.177, 0.259, 0.335], [3.50, 1.087, 0.286, 0.318],
	[3.90, 0.974, 0.316, 0.280], [4.30, 0.895, 0.346, 0.252], [4.90, 0.801, 0.372, 0.226], [5.50, 0.741, 0.380, 0.199],
	[6.10, 0.681, 0.376, 0.169], [6.70, 0.621, 0.376, 0.143], [7.30, 0.575, 0.376, 0.117], [7.90, 0.535, 0.380, 0.090],
	[8.22, 0.515, 0.400, 0.070],
]
## The nose tip [SH side view], where the first ring is fanned closed.
const NOSE: Vector2 = Vector2(0.0, 0.58)
## THE WAIST: where the fuselage is widest, as a share of the way up from belly to top. MEASURED off the front view: the
## egg is 0.72 m across at 0.59 to 0.63 m over the ground, with the belly at 0.21 and the top at 1.25.
const WAIST: float = 0.39
## THE RING'S SHAPE over the waist and under it: (share of the way from the waist to the top or bottom, share of the
## half-width), read off the front view's egg. The third point over the waist is the canopy's sill.
const UPPER: Array = [[0.12, 0.42], [0.35, 0.75], [0.70, 0.95]]
const LOWER: Array = [[0.35, 0.93], [0.72, 0.66]]
const FUSELAGE_SIDES: int = 14

## THE CANOPY [SH side view]: ONE piece, from the windscreen's foot 0.65 m aft of the nose to its rear edge at 2.75, over
## both seats, which is the Duo's and the reason the model's crew sit under one bubble. The sill runs at 0.75 to 0.80 m.
const CANOPY: Vector2 = Vector2(0.65, 2.75)
## THE BUBBLE, a DEVIATION (see the doc block): the crown raised this much over the Duo's across the cockpit, easing in
## ahead of the front pilot and out behind the canopy, so the turtle deck behind it is the Duo's again by x 3.4.
const CANOPY_RAISE: float = 0.10
const RAISE_RAMP: Array = [0.65, 1.20, 2.40, 3.40]
## THE FRONT COCKPIT FILLED OUT, a DEVIATION: from 0.85 m aft of the nose the pod is at least this half-width, blended in
## from 0.45 m, so the front seat's screens, trim wheel and crew board are inside it. The Duo's forward cockpit is 0.58 m
## across where the front pilot's panel is (0.293 m half-width at 1.0 m aft); this game's station furniture was laid out
## for wider cockpits, and `tests/sailplane.gd` found ten of its parts through the skin there (2026-09-19). The widest
## section, the published 0.71 m, is not moved.
const COCKPIT_HALF: float = 0.345
const COCKPIT_FILL: Vector2 = Vector2(0.45, 0.85)
## The rear edge's arch, a dark frame across the canopy's back.
const CANOPY_FRAME_X: float = 2.75

## THE WING PLANFORM [SH plan view]: `out` from the centreline, the leading edge and the trailing edge, aft of the nose,
## by line centres. The leading edge sweeps FORWARD 0.22 m from root to 5 m out, then runs straight, and the tip curves
## back; the trailing edge tapers all the way.
const WING_PLAN: Array = [
	[0.40, 2.776, 3.838], [1.00, 2.742, 3.783], [1.60, 2.712, 3.740], [2.20, 2.683, 3.695], [2.80, 2.646, 3.646],
	[3.40, 2.614, 3.599], [4.00, 2.580, 3.565], [4.60, 2.556, 3.516], [5.20, 2.554, 3.466], [5.80, 2.557, 3.415],
	[6.40, 2.559, 3.364], [7.00, 2.561, 3.298], [7.60, 2.559, 3.246], [8.20, 2.572, 3.195], [8.80, 2.657, 3.172],
	[9.40, 2.760, 3.169], [10.00, 2.868, 3.165],
]
## THE TIP IS SQUARED OFF FOR THE WINGLET, a DEVIATION from the 1993 drawing, whose round tip swings the leading edge back
## to 3.04 m and leaves 0.12 m of chord at the span -- nothing a winglet could stand on. The X and XL tip is a straight
## taper into the winglet's foot, so the last row runs the 9.4 m leading edge's slope on out to 10.0 (ESTIMATE, off
## photographs); the drawn rows there were [9.70, 2.840, 3.167], [9.90, 2.949, 3.165], [10.00, 3.040, 3.160].
## Where the wing roots in the fuselage: buried inside it at this `out`, so the panel grows out of the pod.
const WING_ROOT_OUT: float = 0.20
## THE WING'S HEIGHT [SH front view]: the middle of the section over the ground at each `out`, line centres. 4.2 degrees
## of dihedral from 1 m to 8 m, and then the tips turn up 11 degrees over their last two metres -- the drawn wing, not a
## loaded one in flight. The root is where the side view's fairing is, 0.70 to 0.88 m.
const WING_HEIGHT: Array = [
	[0.20, 0.770], [2.00, 0.878], [3.00, 0.942], [4.00, 1.000], [5.00, 1.065], [6.00, 1.143], [7.00, 1.224],
	[8.00, 1.304], [9.00, 1.442], [9.50, 1.548], [10.00, 1.668],
]
## THE AIRFOIL'S THICKNESS as a share of the chord, root to tip: 13 to 15 per cent MEASURED off the front view's line
## centres (0.154 m on 1.03 m of chord at 2 m out; 0.055 m on 0.42 m at 9.5), which is the DFVLR HX 83's family.
const THICK_ROOT: float = 0.14
const THICK_TIP: float = 0.12
## THE WING'S PARTING [SH plan view]: the joint between the inner panel and the tip panel, at 8.05 m.
const PARTING: float = 8.05

## THE AILERONS [SH plan view]: from 4.55 m out to 9.0 m, their chord from the hinge to the trailing edge 0.18 m at the
## inboard end and 0.10 m at the outboard. Travel ESTIMATE, a sailplane's usual +-20 degrees.
const AILERON_OUT: Vector2 = Vector2(4.55, 9.00)
const AILERON_CHORD: Vector2 = Vector2(0.18, 0.10)
const AILERON_TRAVEL: float = deg_to_rad(20.0)
## THE AIRBRAKES [SH plan view]: Schempp-Hirth paddles through the upper surface, their slot from 2.95 to 4.30 m out at
## 62 per cent of the chord. How high they stand when open is an ESTIMATE, 0.16 m, off photographs.
const AIRBRAKE_OUT: Vector2 = Vector2(2.95, 4.30)
const AIRBRAKE_AT: float = 0.62
const AIRBRAKE_RISE: float = 0.16
const AIRBRAKE_THICK: float = 0.012
## Each of the two stacked blades' height: shut, both are inside the wing's 0.09 m of depth at the slot; open, the upper
## one stands `AIRBRAKE_RISE` over the skin and the lower one half that, so the pair reads as one paddle.
const AIRBRAKE_BLADE: float = 0.075

## THE WINGLET, an ESTIMATE off Duo Discus X and XL photographs (`sources.md`): 0.40 m tall, 0.30 m of chord at its
## foot and 0.14 at its top, its outer face on the published 20 m span.
const WINGLET_HEIGHT: float = 0.40
const WINGLET_CHORD: Vector2 = Vector2(0.30, 0.14)
const WINGLET_THICK: float = 0.035

## THE TAILPLANE [SH plan view], on top of the fin: 3.13 m across, the leading edge from 7.96 at the root to 8.19 at
## 1.5 m out, the elevator's hinge straight across at 8.34 and the trailing edge 8.48 to 8.42. Its height [SH side view]
## is the fin's top: 1.84 to 1.91 m over the ground.
const TAIL_PLAN: Array = [[0.00, 7.955, 8.485], [0.30, 7.958, 8.485], [0.80, 8.018, 8.458], [1.20, 8.086, 8.439],
	[1.40, 8.124, 8.428], [1.50, 8.190, 8.418], [1.565, 8.290, 8.400]]
const TAIL_HINGE: float = 8.34
const TAIL_Y: float = 1.872
const TAIL_THICK: float = 0.09
const ELEVATOR_TRAVEL: float = deg_to_rad(25.0)

## THE FIN AND THE RUDDER [SH side view], as outlines in (x, y). The fin's leading edge leans back 19.5 degrees from the
## boom at 7.32 m to the tailplane at 7.77; the rudder's hinge runs from 8.18 m at the foot to 8.29 at the top, and the
## rudder hangs 0.12 m below the boom's end, as the Duo's does.
const FIN: Array = [[7.20, 0.52], [7.32, 0.575], [7.77, 1.845], [8.29, 1.845], [8.18, 0.44], [8.18, 0.40]]
const RUDDER: Array = [[8.18, 0.40], [8.29, 1.845], [8.52, 1.845], [8.59, 0.46]]
const FIN_THICK: Vector2 = Vector2(0.11, 0.05)
const RUDDER_TRAVEL: float = deg_to_rad(30.0)

## THE WHEELS [SH side view], as (x, y of the axle, radius): the main wheel under the wing's leading edge, retracting;
## the small nose wheel, fixed, under the front seat; the tail wheel, fixed, under the fin.
const MAIN_WHEEL: Vector3 = Vector3(2.78, 0.19, 0.19)
const MAIN_WHEEL_WIDE: float = 0.13
const NOSE_WHEEL: Vector3 = Vector3(0.79, 0.325, 0.09)
const TAIL_WHEEL: Vector3 = Vector3(7.95, 0.345, 0.06)
const WHEEL_SIDES: int = 10
## THE TOW HOOK: the nose release, under the nose ahead of the nose wheel. ESTIMATE of where, off photographs.
const TOW_HOOK: Vector2 = Vector2(0.34, 0.43)

## THE CREW. Two seats in tandem, the eyes 1.00 m apart along the canopy: the front one over the front seat, the back one
## at the rear of the canopy, which is where a Duo's back-seat pilot sits, just ahead of the wing's leading edge. ESTIMATE
## of where along the canopy, off the cockpit photographs. Each eye is `HEADROOM` under the crown the bubble gives, so
## the back seat's eye is 0.05 m higher than the front's, as the canopy rises there -- the back-seat pilot looking over
## the front one's head.
const EYE_X: Array = [1.50, 2.50]
const HEADROOM: float = 0.25

## Small fittings stop drawing once the aeroplane is a few pixels long.
const DETAIL_RANGE: float = 600.0
const DETAIL_HYSTERESIS: float = 60.0

var _half: Vector3 = Vector3.ONE
var _pivots: Dictionary = {}
var _airbrakes: float = 0.0


## BUILT IN PLACE, after `new()`, from the simulation's geometry: the view's, or the kind's own when none is handed.
func dress(geometry: Dictionary = {}) -> void:
	name = "Sailplane"
	var native: Dictionary = geometry if geometry.has("extents") else Sim.geometry_of(Sim.Kind.GLIDER)
	_half = native["extents"] as Vector3
	var paint: StandardMaterial3D = ShipHull.painted()
	paint.roughness = 0.35
	# THE CANOPY IS GLASS, drawn from both sides and half see-through, as the F-16's is (`FalconAirframe.dress`).
	var glass := StandardMaterial3D.new()
	glass.vertex_color_use_as_albedo = true
	glass.vertex_color_is_srgb = true
	glass.albedo_color = Color(1.0, 1.0, 1.0, 0.42)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	glass.roughness = 0.05
	glass.metallic = 0.3
	# THE SKIN SEEN FROM THE SEAT: every face is wound outward, so from inside the one closed solid the pilot saw no
	# aeroplane at all until the fuselage was drawn from both sides (`FalconAirframe`, `TomcatAirframe`).
	var inside: StandardMaterial3D = ShipHull.painted()
	inside.roughness = 0.35
	inside.cull_mode = BaseMaterial3D.CULL_DISABLED

	# ONE MESH, TWO SURFACES: the pod and its glass, so the fuselage is one closed solid a crew can be inside.
	var body := _tool()
	var canopy := _tool()
	_fuselage(body, canopy)
	var fuselage := _add(self, "Fuselage", body, inside)
	fuselage.material_override = null
	fuselage.mesh = canopy.commit(fuselage.mesh as ArrayMesh)
	fuselage.set_surface_override_material(0, inside)
	fuselage.set_surface_override_material(1, glass)
	var frame := _tool()
	_canopy_frame(frame)
	_add(self, "CanopyFrame", frame, paint)

	for side in [1.0, -1.0]:
		var named: String = "Starboard" if side > 0.0 else "Port"
		var wing := _tool()
		_wing(wing, side)
		_add(self, "Wing" + named, wing, paint)
		var winglet := _tool()
		_winglet(winglet, side)
		_add(self, "Winglet" + named, winglet, paint)
		_aileron(side, named, paint)
		_airbrake(side, named, paint)
	var fin := _tool()
	_fin(fin)
	_add(self, "Fin", fin, paint)
	_rudder(paint)
	var tailplane := _tool()
	_tailplane(tailplane)
	_add(self, "Tailplane", tailplane, paint)
	_elevator(paint)

	var nose_gear := _tool()
	_wheel(nose_gear, NOSE_WHEEL, 0.07)
	_hook(nose_gear)
	_detail(_add(self, "NoseWheel", nose_gear, paint))
	var tail_gear := _tool()
	_wheel(tail_gear, TAIL_WHEEL, 0.05)
	_detail(_add(self, "TailWheel", tail_gear, paint))
	_main_wheel(paint)


## ---- the frame ------------------------------------------------------------------------------------------------------

## A DRAWING x (metres aft of the nose) as a z: the nose on the box's front face.
func station(x: float) -> float:
	return -_half.z + x


## A DRAWING y (metres over the ground, level) as a y: the ground on the box's floor.
func height(y: float) -> float:
	return -_half.y + y


func at(out: float, x: float, y: float) -> Vector3:
	return Vector3(out, height(y), station(x))


## THE TABLES, READ BETWEEN THEIR ROWS: a row's `column` at `key`, straight-line between the rows either side.
static func between(table: Array, key: float, column: int, key_column: int = 0) -> float:
	if key <= float(table[0][key_column]):
		return float(table[0][column])
	for i in range(table.size() - 1):
		var a: float = float(table[i][key_column])
		var b: float = float(table[i + 1][key_column])
		if key <= b:
			return lerpf(float(table[i][column]), float(table[i + 1][column]), (key - a) / maxf(b - a, 1e-6))
	return float(table[-1][column])


## HOW MUCH THE BUBBLE RAISES THE CROWN at `x`: none ahead of the windscreen, all of it over both seats, none by x 3.4.
static func raise_at(x: float) -> float:
	var r: Array = RAISE_RAMP
	if x <= float(r[0]) or x >= float(r[3]):
		return 0.0
	if x < float(r[1]):
		return CANOPY_RAISE * smoothstep(float(r[0]), float(r[1]), x)
	if x <= float(r[2]):
		return CANOPY_RAISE
	return CANOPY_RAISE * (1.0 - smoothstep(float(r[2]), float(r[3]), x))


## THE FUSELAGE'S OUTLINE AT `x`, with the bubble: {top, bottom, half}.
static func section_at(x: float) -> Dictionary:
	var filled: float = COCKPIT_HALF * smoothstep(COCKPIT_FILL.x, COCKPIT_FILL.y, x) if x < 3.0 else 0.0
	return {"top": between(SECTIONS, x, 1) + raise_at(x), "bottom": between(SECTIONS, x, 2),
		"half": maxf(between(SECTIONS, x, 3), filled), "waist": between(SECTIONS, x, 2) + WAIST * (between(SECTIONS, x, 1)
			- between(SECTIONS, x, 2))}


## ---- the wing's planform, and the one number that makes it the published one ---------------------------------------

## THE DRAWN CHORDS' AREA, both wings, the root chord carried across the fuselage to the centreline as a reference area
## is: trapezoids over `WING_PLAN`.
static func measured_area() -> float:
	var area: float = float(WING_PLAN[0][0]) * (float(WING_PLAN[0][2]) - float(WING_PLAN[0][1]))
	for i in range(WING_PLAN.size() - 1):
		var a: Array = WING_PLAN[i]
		var b: Array = WING_PLAN[i + 1]
		area += (float(b[0]) - float(a[0])) * ((float(a[2]) - float(a[1])) + (float(b[2]) - float(b[1]))) * 0.5
	return area * 2.0


## EVERY CHORD'S SCALE, so the drawn wing's area is the published 16.40 m2: COMPUTED, never typed. 0.984 on 2026-09-18.
static func chord_scale() -> float:
	return WING_AREA / measured_area()


## THE LEADING AND TRAILING EDGES AT `out`, after `chord_scale`, each chord scaled about its quarter-chord point.
static func wing_edges(out: float) -> Vector2:
	var le: float = between(WING_PLAN, out, 1)
	var te: float = between(WING_PLAN, out, 2)
	var c: float = te - le
	var quarter: float = le + 0.25 * c
	var k: float = chord_scale()
	return Vector2(quarter - 0.25 * c * k, quarter + 0.75 * c * k)


static func wing_height(out: float) -> float:
	return between(WING_HEIGHT, out, 1)


static func thickness(out: float) -> float:
	return lerpf(THICK_ROOT, THICK_TIP, clampf(out / (SPAN * 0.5), 0.0, 1.0))


## THE AILERON'S HINGE, aft of the nose, at `out`.
static func aileron_hinge(out: float) -> float:
	var share: float = clampf((out - AILERON_OUT.x) / (AILERON_OUT.y - AILERON_OUT.x), 0.0, 1.0)
	return wing_edges(out).y - lerpf(AILERON_CHORD.x, AILERON_CHORD.y, share)


## ---- what the flight model will read (`cockpit/research/flight_model_plan.md`, step 3) -------------------------------

## THE SURFACES, MEASURED OFF THE DRAWN AIRFRAME, for the surface-driven flight model to read rather than retype: areas
## in m2 and arms in metres, aft of the wing's quarter-chord point at its mean chord (+ is aft). Integrated from the
## same tables the model is drawn from.
static func surfaces() -> Dictionary:
	var wing_ac: float = _quarter_chord_at_mac()
	var tail: Dictionary = _integrate(TAIL_PLAN, 0.0, float(TAIL_PLAN[-1][0]))
	var elevator_area: float = 0.0
	for i in range(TAIL_PLAN.size() - 1):
		var a: Array = TAIL_PLAN[i]
		var b: Array = TAIL_PLAN[i + 1]
		elevator_area += (float(b[0]) - float(a[0])) * (maxf(float(a[2]) - TAIL_HINGE, 0.0)
			+ maxf(float(b[2]) - TAIL_HINGE, 0.0)) * 0.5
	var aileron: float = 0.0
	var steps: int = 40
	for s in range(steps):
		var o: float = lerpf(AILERON_OUT.x, AILERON_OUT.y, (float(s) + 0.5) / steps)
		aileron += (wing_edges(o).y - aileron_hinge(o)) * (AILERON_OUT.y - AILERON_OUT.x) / steps
	var fin_area: float = _polygon_area(FIN) + _polygon_area(RUDDER)
	return {
		"wing_area": WING_AREA, "span": SPAN, "mac": MAC, "aspect_ratio": SPAN * SPAN / WING_AREA,
		"wing_quarter_chord_x": wing_ac,
		"tailplane_area": float(tail["area"]) * 2.0, "tailplane_span": float(TAIL_PLAN[-1][0]) * 2.0,
		"elevator_area": elevator_area * 2.0,
		"tailplane_arm": float(tail["quarter_x"]) - wing_ac,
		"fin_area": fin_area, "rudder_area": _polygon_area(RUDDER),
		"fin_arm": _centroid(FIN + RUDDER).x - wing_ac, "fin_height_over_boom": 1.845 - 0.55,
		"aileron_area_each": aileron, "aileron_span": [AILERON_OUT.x, AILERON_OUT.y],
		"airbrake_area_each": (AIRBRAKE_OUT.y - AIRBRAKE_OUT.x) * AIRBRAKE_RISE,
		"source": "SailplaneAirframe tables, MEASURED off Schempp-Hirth's Duo Discus three-view; see craft/glider/sources.md",
	}


static func _quarter_chord_at_mac() -> float:
	# The wing's quarter-chord line averaged over the span weighted by chord squared -- where the MAC sits.
	var num: float = 0.0
	var den: float = 0.0
	for s in range(100):
		var o: float = (float(s) + 0.5) * 0.1
		var e: Vector2 = wing_edges(o)
		var c: float = e.y - e.x
		num += (e.x + 0.25 * c) * c * c
		den += c * c
	return num / den


static func _integrate(table: Array, from: float, to: float) -> Dictionary:
	var area: float = 0.0
	var moment: float = 0.0
	for i in range(table.size() - 1):
		var a: Array = table[i]
		var b: Array = table[i + 1]
		var w: float = float(b[0]) - float(a[0])
		var ca: float = float(a[2]) - float(a[1])
		var cb: float = float(b[2]) - float(b[1])
		var piece: float = w * (ca + cb) * 0.5
		area += piece
		moment += piece * ((float(a[1]) + 0.25 * ca + float(b[1]) + 0.25 * cb) * 0.5)
	return {"area": area, "quarter_x": moment / maxf(area, 1e-6)}


static func _polygon_area(points: Array) -> float:
	var area: float = 0.0
	for i in range(points.size()):
		var a: Array = points[i]
		var b: Array = points[(i + 1) % points.size()]
		area += float(a[0]) * float(b[1]) - float(b[0]) * float(a[1])
	return absf(area) * 0.5


static func _centroid(points: Array) -> Vector2:
	var sum := Vector2.ZERO
	for p in points:
		sum += Vector2(float(p[0]), float(p[1]))
	return sum / float(points.size())


## ---- the crew -------------------------------------------------------------------------------------------------------

## THE TWO EYES, craft-local, front seat first: `HEADROOM` under the bubble's crown at `EYE_X`. The C++ seat table is held
## to these (`tests/sailplane.gd`), so the seats follow the canopy and never the other way round.
func crew_eyes() -> Array:
	var eyes: Array = []
	for x in EYE_X:
		eyes.append(at(0.0, float(x), float(section_at(float(x))["top"]) - HEADROOM))
	return eyes


## THE ROOM A CREW SITS IN, in the shape `VehicleView.cabin_room()` asks for: the largest box PROMISED inside the drawn
## skin, from over the belly up to under the glass, between the two seats' shoulders. Held to the triangles by
## `tests/sailplane.gd`.
func cabin_room() -> Dictionary:
	var fore: float = 1.00
	var aft: float = 2.60
	var low: float = 0.34
	var high: float = 1.10
	var half: float = 0.22
	return {
		"drawn": true,
		"floor": height(0.30),
		"room": AABB(at(-half, fore, low), Vector3(half * 2.0, high - low, aft - fore)),
		"because": &"",
		"why_not": "",
		"source": "MEASURED off Schempp-Hirth's Duo Discus three-view, the crown raised CANOPY_RAISE (2026-09-18)",
	}


## WHETHER A BOX, craft-local, IS INSIDE THE DRAWN POD: every corner between the belly and the top of the section at its
## station, and no further out than the section is wide at its height. Asked by `VehicleView.holster_fits`, so a signal
## lamp's holster is put inside the 0.71 m pod rather than through its side (2026-09-19). The same `section_at` and ring
## the fuselage is drawn from, so the answer cannot disagree with the picture. A centimetre is kept for the skin.
func encloses(box: AABB) -> bool:
	for corner in range(8):
		var p: Vector3 = box.get_endpoint(corner)
		var x: float = p.z + _half.z
		var y: float = p.y + _half.y
		if x < float(SECTIONS[0][0]) or x > float(SECTIONS[-1][0]):
			return false
		if absf(p.x) > half_width_at(x, y) - 0.01:
			return false
	return true


## THE POD'S HALF-WIDTH at station `x` and height `y` over the ground, off the ring `_ring` draws; 0 above or below it.
static func half_width_at(x: float, y: float) -> float:
	var s: Dictionary = section_at(x)
	var top: float = s["top"]
	var bottom: float = s["bottom"]
	var waist: float = s["waist"]
	var w: float = s["half"]
	if y >= top or y <= bottom:
		return 0.0
	var outline: Array = [Vector2(0.0, top)]
	for p in UPPER:
		outline.append(Vector2(w * float(p[1]), top - (top - waist) * float(p[0])))
	outline.append(Vector2(w, waist))
	for p in LOWER:
		outline.append(Vector2(w * float(p[1]), waist - (waist - bottom) * float(p[0])))
	outline.append(Vector2(0.0, bottom))
	for i in range(outline.size() - 1):
		var a: Vector2 = outline[i]
		var b: Vector2 = outline[i + 1]
		if y <= a.y and y >= b.y:
			return lerpf(a.x, b.x, (a.y - y) / maxf(a.y - b.y, 1e-6))
	return 0.0


## ---- moving it --------------------------------------------------------------------------------------------------------

## THE AILERONS: `roll` -1 left wing down to +1 right wing down. The down-going wing's aileron rises.
func set_ailerons(roll: float) -> void:
	var r: float = clampf(roll, -1.0, 1.0)
	_swing("AileronStarboard", -r * AILERON_TRAVEL)
	_swing("AileronPort", r * AILERON_TRAVEL)


## THE ELEVATOR: `pitch` -1 nose down to +1 nose up; stick back raises the trailing edge.
func set_elevator(pitch: float) -> void:
	_swing("Elevator", -clampf(pitch, -1.0, 1.0) * ELEVATOR_TRAVEL)


## THE RUDDER: -1 nose left to +1 nose right; its trailing edge to starboard for right rudder.
func set_rudder(yaw: float) -> void:
	_swing("Rudder", clampf(yaw, -1.0, 1.0) * RUDDER_TRAVEL)


## THE AIRBRAKES, 0 shut to 1 out: both paddles rise out of the upper surface together.
func set_airbrakes(amount: float) -> void:
	_airbrakes = clampf(amount, 0.0, 1.0)
	for named in ["AirbrakeStarboard", "AirbrakePort", "AirbrakeStarboardLower", "AirbrakePortLower"]:
		var pivot: Node3D = _pivots.get(named) as Node3D
		if pivot != null:
			pivot.position = pivot.get_meta("shut") as Vector3 				+ Vector3.UP * AIRBRAKE_RISE * _airbrakes * float(pivot.get_meta("share", 1.0))


func airbrakes() -> float:
	return _airbrakes


## THE MAIN WHEEL, 1 down and 0 up. Shown or stowed, as the F-16's gear is: a wheel half-retracted into its well is a
## difference nobody would see at any range the gear is drawn.
func set_gear(amount: float) -> void:
	var gear := get_node_or_null("MainWheel") as Node3D
	if gear != null:
		gear.visible = amount >= 0.5


## HOW FAR A SURFACE IS TURNED, in radians about its hinge: what a check reads to know the stick moved it.
func deflection(named: String) -> float:
	var pivot: Node3D = _pivots.get(named) as Node3D
	if pivot == null:
		return 0.0
	return pivot.basis.get_rotation_quaternion().get_angle()


func _swing(named: String, angle: float) -> void:
	var pivot: Node3D = _pivots.get(named) as Node3D
	if pivot == null:
		return
	pivot.basis = Basis(pivot.get_meta("axis") as Vector3, angle)


## ---- building it ------------------------------------------------------------------------------------------------------

static func _tool() -> SurfaceTool:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	return tool


static func _add(parent: Node3D, title: String, tool: SurfaceTool, material: Material,
		at_position: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = title
	mesh.mesh = Plating.weld(tool)
	mesh.material_override = material
	mesh.position = at_position
	parent.add_child(mesh)
	return mesh


static func _detail(mesh: MeshInstance3D) -> void:
	mesh.visibility_range_end = DETAIL_RANGE
	mesh.visibility_range_end_margin = DETAIL_HYSTERESIS
	mesh.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## ONE TRIANGLE, wound so its face looks along `out`.
static func _fan(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, out: Vector3, tint: Color) -> void:
	var normal: Vector3 = (c - a).cross(b - a)
	if normal.length_squared() < 1e-12:
		return
	if normal.dot(out) < 0.0:
		var swap: Vector3 = b
		b = c
		c = swap
		normal = -normal
	tool.set_color(tint)
	for corner in [a, b, c]:
		tool.set_normal(normal.normalized())
		tool.add_vertex(corner)


## A LOFT through matching convex loops, each quad facing away from its loops' middle, both ends closed by fans.
static func _loft(tool: SurfaceTool, loops: Array, tints: Array, close: bool = true) -> void:
	var n: int = (loops[0] as Array).size()
	var centres: Array = []
	for loop in loops:
		var c := Vector3.ZERO
		for p in loop:
			c += p
		centres.append(c / float(n))
	for i in range(loops.size() - 1):
		var a: Array = loops[i]
		var b: Array = loops[i + 1]
		var mid_centre: Vector3 = ((centres[i] as Vector3) + centres[i + 1]) * 0.5
		for k in range(n):
			var quad: Array = [a[k], a[(k + 1) % n], b[(k + 1) % n], b[k]]
			var mid: Vector3 = ((quad[0] as Vector3) + quad[1] + quad[2] + quad[3]) * 0.25
			Plating.facing(tool, quad, mid - mid_centre, tints[k % tints.size()])
	if not close:
		return
	for end in [0, loops.size() - 1]:
		var along: Vector3 = (centres[end] as Vector3) - centres[1 if end == 0 else loops.size() - 2]
		var loop: Array = loops[end]
		for k in range(n):
			_fan(tool, centres[end], loop[k], loop[(k + 1) % n], along, tints[k % tints.size()])


## A FLAT SLAB from a 2D outline in (x, y): each face triangulated by the engine's ear clipper, every edge walled.
func _slab(tool: SurfaceTool, outline: PackedVector2Array, offset: Vector3, half: Callable, tint: Color) -> void:
	var tris: PackedInt32Array = Geometry2D.triangulate_polygon(outline)
	var right: Array = []
	var left: Array = []
	for p in outline:
		var h: float = float(half.call(p))
		right.append(at(h, p.x, p.y) - offset)
		left.append(at(-h, p.x, p.y) - offset)
	for t in range(0, tris.size(), 3):
		_fan(tool, right[tris[t]], right[tris[t + 1]], right[tris[t + 2]], Vector3.RIGHT, tint)
		_fan(tool, left[tris[t]], left[tris[t + 1]], left[tris[t + 2]], Vector3.LEFT, tint)
	var middle := Vector2.ZERO
	for p in outline:
		middle += p
	middle /= float(outline.size())
	var n: int = outline.size()
	for i in range(n):
		var a2: Vector2 = outline[i]
		var b2: Vector2 = outline[(i + 1) % n]
		var edge: Vector2 = b2 - a2
		var normal2 := Vector2(edge.y, -edge.x)
		if normal2.dot((a2 + b2) * 0.5 - middle) < 0.0:
			normal2 = -normal2
		# x runs aft (+z) and y up, so an outline normal (dx, dy) is the craft's (0, dy, dx).
		Plating.facing(tool, [right[i], right[(i + 1) % n], left[(i + 1) % n], left[i]],
			Vector3(0.0, normal2.y, normal2.x), tint)


## ONE FUSELAGE RING at `x`, round from the top centreline down the starboard side to the keel and back up the port:
## 14 points. The first three facets each side are the canopy wherever it is glazed.
func _ring(x: float) -> Array:
	var s: Dictionary = section_at(x)
	var top: float = s["top"]
	var bottom: float = s["bottom"]
	var waist: float = s["waist"]
	var w: float = s["half"]
	var half: Array = [Vector2(0.0, top)]
	for p in UPPER:
		half.append(Vector2(w * float(p[1]), top - (top - waist) * float(p[0])))
	half.append(Vector2(w, waist))
	for p in LOWER:
		half.append(Vector2(w * float(p[1]), waist - (waist - bottom) * float(p[0])))
	half.append(Vector2(0.0, bottom))
	var points: Array = []
	for i in range(half.size() - 1):
		points.append(at((half[i] as Vector2).x, x, (half[i] as Vector2).y))
	for i in range(half.size() - 1, 0, -1):
		points.append(at(-(half[i] as Vector2).x, x, (half[i] as Vector2).y))
	return points


## THE POD AND THE BOOM, one closed solid: a loft through the rings, fanned shut to the nose tip and across the boom's
## end under the rudder. The glass goes into `canopy`, the fuselage's second surface.
func _fuselage(tool: SurfaceTool, canopy: SurfaceTool) -> void:
	var xs: Array = []
	for row in SECTIONS:
		xs.append(float(row[0]))
	# THE CANOPY'S ENDS ARE RINGS, so the glass stops on a facet edge and not across the middle of one.
	for extra in [CANOPY.x, CANOPY.y, float(RAISE_RAMP[1]), float(RAISE_RAMP[2]), float(RAISE_RAMP[3]),
			COCKPIT_FILL.x, (COCKPIT_FILL.x + COCKPIT_FILL.y) * 0.5, COCKPIT_FILL.y]:
		if not xs.has(extra):
			xs.append(extra)
	xs.sort()
	var rings: Array = []
	for x in xs:
		rings.append(_ring(float(x)))
	var n: int = FUSELAGE_SIDES
	for r in range(rings.size() - 1):
		var here: float = (float(xs[r]) + float(xs[r + 1])) * 0.5
		var glazed: bool = here > CANOPY.x and here < CANOPY.y
		var s: Dictionary = section_at(here)
		var centre: Vector3 = at(0.0, here, (float(s["top"]) + float(s["bottom"])) * 0.5)
		var a: Array = rings[r]
		var b: Array = rings[r + 1]
		for k in range(n):
			var quad: Array = [a[k], a[(k + 1) % n], b[(k + 1) % n], b[k]]
			var mid: Vector3 = ((quad[0] as Vector3) + quad[1] + quad[2] + quad[3]) * 0.25
			var out := Vector3(mid.x - centre.x, mid.y - centre.y, 0.0)
			# Facets 0 to 2 are the starboard glass, 11 to 13 the port.
			var upper: bool = k <= 2 or k >= n - 3
			if glazed and upper:
				Plating.facing(canopy, quad, out, GLASS)
				continue
			Plating.facing(tool, quad, out, WHITE if out.y > -0.2 * out.length() else UNDER)
	var first: Array = rings[0]
	var tip: Vector3 = at(0.0, NOSE.x, NOSE.y)
	for k in range(n):
		_fan(tool, tip, first[k], first[(k + 1) % n], Vector3.FORWARD, WHITE)
	var last: Array = rings[rings.size() - 1]
	var end: float = float(xs[-1])
	var s_end: Dictionary = section_at(end)
	var back: Vector3 = at(0.0, end, (float(s_end["top"]) + float(s_end["bottom"])) * 0.5)
	for k in range(n):
		_fan(tool, back, last[k], last[(k + 1) % n], Vector3.BACK, UNDER)


## THE CANOPY'S FRAME: a dark arch across its rear edge and a thin rail along each sill, standing 6 mm proud of the skin.
func _canopy_frame(tool: SurfaceTool) -> void:
	var ring: Array = _ring(CANOPY_FRAME_X)
	var n: int = FUSELAGE_SIDES
	for k in [0, 1, 2, n - 3, n - 2, n - 1]:
		var p: Vector3 = ring[k]
		var q: Vector3 = ring[(k + 1) % n]
		var centre: Vector3 = at(0.0, CANOPY_FRAME_X, float(section_at(CANOPY_FRAME_X)["waist"]))
		var out_p: Vector3 = (p - centre).normalized() * 0.006
		var out_q: Vector3 = (q - centre).normalized() * 0.006
		var quad: Array = [p + out_p, q + out_q, q + out_q + Vector3.FORWARD * 0.05, p + out_p + Vector3.FORWARD * 0.05]
		Plating.facing(tool, quad, ((p + q) * 0.5 - centre), FRAME)
		# The frame's thickness, so it is a solid and not a decal.
		var back_quad: Array = [p, q, q + out_q, p + out_p]
		Plating.facing(tool, back_quad, Vector3.BACK, FRAME)
	for side in [1.0, -1.0]:
		var rail: Array = []
		for x in [CANOPY.x + 0.10, CANOPY.y]:
			var r: Array = _ring(float(x))
			var sill: Vector3 = r[3] if side > 0.0 else r[n - 3]
			rail.append(sill)
		var a: Vector3 = rail[0]
		var b: Vector3 = rail[1]
		var outward := Vector3(side, 0.0, 0.0)
		Plating.facing(tool, [a + outward * 0.006, b + outward * 0.006, b + outward * 0.006 + Vector3.UP * 0.025,
			a + outward * 0.006 + Vector3.UP * 0.025], outward, FRAME)
		Plating.facing(tool, [a, b, b + outward * 0.006, a + outward * 0.006], Vector3.DOWN, FRAME)
		Plating.facing(tool, [a + Vector3.UP * 0.025, b + Vector3.UP * 0.025, b + outward * 0.006 + Vector3.UP * 0.025,
			a + outward * 0.006 + Vector3.UP * 0.025], Vector3.UP, FRAME)


## ONE WING SECTION at `out` from `le` to `te`, six points, in the craft's frame.
func _section(out: float, le: float, te: float, y: float, thick: float, side: float) -> Array:
	var c: float = te - le
	var t: float = c * thick * 0.5
	return [at(side * out, le, y), at(side * out, le + 0.15 * c, y + t * 0.85), at(side * out, le + 0.45 * c, y + t),
		at(side * out, te, y + t * 0.1), at(side * out, le + 0.45 * c, y - t * 0.8), at(side * out, le + 0.15 * c, y - t * 0.7)]


const _TINTS: Array = [WHITE, WHITE, WHITE, UNDER, UNDER, UNDER]


## THE WING, one side, root to tip: full chord inboard of the aileron and outboard of it, to the aileron's hinge across
## its span. A section every 0.6 m or so, and at every station the planform or the dihedral changes.
func _wing(tool: SurfaceTool, side: float) -> void:
	var outs: Array = [WING_ROOT_OUT]
	for row in WING_PLAN:
		outs.append(float(row[0]))
	for row in WING_HEIGHT:
		outs.append(float(row[0]))
	for extra in [AILERON_OUT.x, AILERON_OUT.y, PARTING]:
		outs.append(extra)
	var unique: Array = []
	for o in outs:
		if o >= WING_ROOT_OUT and o <= SPAN * 0.5 and not unique.has(o):
			unique.append(o)
	unique.sort()
	var loops: Array = []
	var gap: float = 0.004
	for o in unique:
		var out: float = float(o)
		var e: Vector2 = wing_edges(out)
		var inside_aileron: bool = out > AILERON_OUT.x + gap * 0.5 and out < AILERON_OUT.y - gap * 0.5
		# AT EACH END OF THE AILERON THE TRAILING EDGE STEPS, so the station is doubled a few millimetres apart: one
		# section to the full trailing edge and one to the hinge.
		if is_equal_approx(out, AILERON_OUT.x):
			loops.append(_section(out - gap, e.x, e.y, wing_height(out), thickness(out), side))
			loops.append(_section(out, e.x, aileron_hinge(out), wing_height(out), thickness(out), side))
			continue
		if is_equal_approx(out, AILERON_OUT.y):
			loops.append(_section(out, e.x, aileron_hinge(out), wing_height(out), thickness(out), side))
			loops.append(_section(out + gap, e.x, e.y, wing_height(out), thickness(out), side))
			continue
		var te: float = aileron_hinge(out) if inside_aileron else e.y
		loops.append(_section(out, e.x, te, wing_height(out), thickness(out), side))
	# THE TIP, closed to a short edge at the published span rather than to a point.
	_loft(tool, loops, _TINTS)


## THE WINGLET, standing up from the tip with its outer face on the 20 m span.
func _winglet(tool: SurfaceTool, side: float) -> void:
	var tip: float = SPAN * 0.5
	var e: Vector2 = wing_edges(tip)
	var foot_y: float = wing_height(tip) - 0.01
	var foot_aft: float = e.y
	var foot_le: float = foot_aft - WINGLET_CHORD.x
	var top_le: float = foot_aft - WINGLET_CHORD.y
	var out: float = tip - WINGLET_THICK * 0.5
	var loops: Array = []
	for step in [[foot_y, foot_le, foot_aft, 1.0], [foot_y + WINGLET_HEIGHT, top_le, foot_aft + 0.02, 0.6]]:
		var y: float = float(step[0])
		var le: float = float(step[1])
		var te: float = float(step[2])
		var h: float = WINGLET_THICK * 0.5 * float(step[3])
		var c: float = te - le
		loops.append([at(side * out, le, y), at(side * (out + h), le + 0.3 * c, y), at(side * out, te, y),
			at(side * (out - h), le + 0.3 * c, y)])
	_loft(tool, loops, [DAYGLO, DAYGLO, DAYGLO, DAYGLO])


## THE AILERON, one side, in its own pivot on the hinge line, which runs between its two ends along the wing.
func _aileron(side: float, named: String, paint: Material) -> void:
	var inner: Vector3 = at(side * AILERON_OUT.x, aileron_hinge(AILERON_OUT.x), wing_height(AILERON_OUT.x))
	var outer: Vector3 = at(side * AILERON_OUT.y, aileron_hinge(AILERON_OUT.y), wing_height(AILERON_OUT.y))
	var pivot := Node3D.new()
	pivot.name = "Aileron" + named + "Hinge"
	pivot.position = inner
	# Trailing edge DOWN is a positive turn about the hinge pointing OUTBOARD on the starboard wing (aft is +z; a turn
	# about +x carries +z to -y); the port hinge is flipped so the same sign means the same thing on both.
	pivot.set_meta("axis", (outer - inner).normalized() * side)
	add_child(pivot)
	var tool := _tool()
	var loops: Array = []
	for o in [AILERON_OUT.x + 0.004, (AILERON_OUT.x + PARTING) * 0.5, PARTING, AILERON_OUT.y - 0.004]:
		var out: float = float(o)
		var e: Vector2 = wing_edges(out)
		var hinge: float = aileron_hinge(out)
		var y: float = wing_height(out)
		var t: float = thickness(out) * (e.y - e.x) * 0.5 * 0.55
		var local: Array = []
		for p in [at(side * out, hinge, y + t), at(side * out, e.y, y + 0.002), at(side * out, hinge, y - t * 0.8)]:
			local.append((p as Vector3) - inner)
		loops.append(local)
	_loft(tool, loops, [WHITE, UNDER, UNDER])
	_add(pivot, "Aileron" + named, tool, paint)
	_pivots["Aileron" + named] = pivot


## THE AIRBRAKE PADDLE, one side: two thin blades stacked in a slot on top of the wing, their tops flush with the skin
## when shut. They RISE rather than turn (`set_airbrakes`), as a Schempp-Hirth paddle does: the upper blade the whole
## way, the lower one half of it, so the paddle is a single plate with no gap under it.
func _airbrake(side: float, named: String, paint: Material) -> void:
	for blade in [["", 1.0], ["Lower", 0.5]]:
		var holder := Node3D.new()
		holder.name = "Airbrake" + named + String(blade[0]) + "Slide"
		add_child(holder)
		holder.set_meta("shut", Vector3.ZERO)
		holder.set_meta("share", float(blade[1]))
		var tool := _tool()
		var loops: Array = []
		for o in [AIRBRAKE_OUT.x, AIRBRAKE_OUT.y]:
			var out: float = float(o)
			var e: Vector2 = wing_edges(out)
			var x: float = e.x + AIRBRAKE_AT * (e.y - e.x)
			# The upper skin at 62 per cent of the chord, between the section's points at 45 per cent and the trailing edge.
			var skin: float = wing_height(out) + thickness(out) * (e.y - e.x) * 0.5 * 0.72
			var thick: float = AIRBRAKE_THICK * (1.0 if float(blade[1]) > 0.9 else 0.8)
			var shift: float = 0.0 if float(blade[1]) > 0.9 else AIRBRAKE_THICK * 1.9
			loops.append([at(side * out, x - thick + shift, skin + 0.002), at(side * out, x + thick + shift, skin + 0.002),
				at(side * out, x + thick + shift, skin - AIRBRAKE_BLADE), at(side * out, x - thick + shift, skin - AIRBRAKE_BLADE)])
		_loft(tool, loops, [WHITE, WHITE, UNDER, WHITE])
		_add(holder, "Airbrake" + named + String(blade[0]), tool, paint)
		_pivots["Airbrake" + named + String(blade[0])] = holder


## THE FIN, a slab in the side view's plane, thinning from its root to its top, bedded into the boom.
func _fin(tool: SurfaceTool) -> void:
	var half := func(p: Vector2) -> float:
		return lerpf(FIN_THICK.x, FIN_THICK.y, clampf((p.y - 0.55) / (1.845 - 0.55), 0.0, 1.0)) * 0.5
	_slab(tool, _outline(FIN), Vector3.ZERO, half, WHITE)


## THE RUDDER in its pivot on the raked hinge line, its tip day-glo.
func _rudder(paint: Material) -> void:
	var foot: Vector3 = at(0.0, float(RUDDER[0][0]), float(RUDDER[0][1]))
	var head: Vector3 = at(0.0, float(RUDDER[1][0]), float(RUDDER[1][1]))
	var pivot := Node3D.new()
	pivot.name = "RudderHinge"
	pivot.position = foot
	# Right rudder swings the trailing edge (+z of the hinge) to starboard (+x): a positive turn about the hinge pointing
	# UP it, since a turn about +y carries +z towards +x. `tests/sailplane.gd` holds the sign.
	pivot.set_meta("axis", (head - foot).normalized())
	add_child(pivot)
	var half := func(p: Vector2) -> float:
		return lerpf(FIN_THICK.x * 0.6, FIN_THICK.y * 0.6, clampf((p.y - 0.4) / (1.845 - 0.4), 0.0, 1.0)) * 0.5
	var tool := _tool()
	_slab(tool, _outline(RUDDER), foot, half, WHITE)
	_add(pivot, "Rudder", tool, paint)
	_pivots["Rudder"] = pivot


## THE TAILPLANE'S FIXED PART, both sides as one piece across the fin's top, to the elevator's hinge.
func _tailplane(tool: SurfaceTool) -> void:
	for side in [1.0, -1.0]:
		var loops: Array = []
		for row in TAIL_PLAN:
			var out: float = maxf(float(row[0]), 0.0)
			var le: float = float(row[1])
			var hinge: float = minf(TAIL_HINGE, float(row[2]) - 0.01)
			loops.append(_section(out, le, hinge, TAIL_Y, TAIL_THICK * (float(row[2]) - le) / maxf(hinge - le, 0.01), side))
		_loft(tool, loops, _TINTS)


## THE ELEVATOR, one piece across both sides, on the straight hinge at 8.34.
func _elevator(paint: Material) -> void:
	var tip: float = float(TAIL_PLAN[-2][0])
	var pivot := Node3D.new()
	pivot.name = "ElevatorHinge"
	pivot.position = at(0.0, TAIL_HINGE, TAIL_Y)
	# Trailing edge UP for stick back: a turn about -x carries +z (aft) towards +y.
	pivot.set_meta("axis", Vector3.RIGHT)
	add_child(pivot)
	var tool := _tool()
	var loops: Array = []
	for o in [-tip, 0.0, tip]:
		var out: float = float(o)
		var te: float = between(TAIL_PLAN, absf(out), 2)
		var t: float = TAIL_THICK * 0.5 * 0.35 * (te - between(TAIL_PLAN, absf(out), 1))
		var local: Array = []
		for p in [at(out, TAIL_HINGE, TAIL_Y + t), at(out, te, TAIL_Y), at(out, TAIL_HINGE, TAIL_Y - t)]:
			local.append((p as Vector3) - pivot.position)
		loops.append(local)
	_loft(tool, loops, [WHITE, UNDER, UNDER])
	_add(pivot, "Elevator", tool, paint)
	_pivots["Elevator"] = pivot


## A WHEEL: a ten-sided prism whose flats circumscribe the drawn circle, so its bottom flat sits on the drawn ground.
func _wheel(tool: SurfaceTool, wheel: Vector3, wide: float) -> void:
	var corner: float = wheel.z / cos(PI / WHEEL_SIDES)
	var loops: Array = []
	for w in [-wide * 0.5, wide * 0.5]:
		var loop: Array = []
		for k in range(WHEEL_SIDES):
			var t: float = TAU * (float(k) + 0.5) / WHEEL_SIDES
			loop.append(at(w, wheel.x + corner * sin(t), wheel.y + corner * cos(t)))
		loops.append(loop)
	_loft(tool, loops, [BLACK])


## THE MAIN WHEEL, which retracts: its own node, so the gear bit can stow it.
func _main_wheel(paint: Material) -> void:
	var tool := _tool()
	_wheel(tool, MAIN_WHEEL, MAIN_WHEEL_WIDE)
	var hub := func(a: Vector3, b: Vector3) -> void:
		_loft(tool, [[a + Vector3(0.0, 0.03, 0.03), a + Vector3(0.0, 0.03, -0.03), a + Vector3(0.0, -0.03, -0.03),
			a + Vector3(0.0, -0.03, 0.03)], [b + Vector3(0.0, 0.03, 0.03), b + Vector3(0.0, 0.03, -0.03),
			b + Vector3(0.0, -0.03, -0.03), b + Vector3(0.0, -0.03, 0.03)]], [METAL])
	# THE LEG, from the axle up into the belly, either side of the tyre.
	for side in [1.0, -1.0]:
		var axle: Vector3 = at(side * (MAIN_WHEEL_WIDE * 0.5 + 0.02), MAIN_WHEEL.x, MAIN_WHEEL.y)
		var belly: Vector3 = at(side * (MAIN_WHEEL_WIDE * 0.5 + 0.02), MAIN_WHEEL.x,
			float(section_at(MAIN_WHEEL.x)["bottom"]) + 0.05)
		hub.call(axle, belly)
	var node := _add(self, "MainWheel", tool, paint)
	_detail(node)


## THE TOW HOOK: a small dark box under the nose.
func _hook(tool: SurfaceTool) -> void:
	var belly: float = float(section_at(TOW_HOOK.x)["bottom"])
	Plating.box(tool, at(0.0, TOW_HOOK.x, belly - 0.015), Vector3(0.05, 0.05, 0.08), FRAME)


static func _outline(points: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(Vector2(float(p[0]), float(p[1])))
	return out
