@tool
extends Node3D
class_name FalconAirframe
## A GENERAL DYNAMICS F-16A FIGHTING FALCON, BLOCK 15, DRAWN: SINGLE SEAT. The chin intake under the forward fuselage,
## the frameless bubble canopy sitting high on the spine, the leading-edge root extensions curving into a blended wing
## body, one fin, two ventral fins, all-moving tailplanes on booms beside the one nozzle.
##
## NOT AN F-16B OR D. The canopy here is one transparency 3.66 m long closing over one seat, with its fixed aft frame
## 2.4 m behind the windscreen foot; a two-seater's is half a metre longer and covers a second cockpit where this one
## has the spine. Commons holds more two-seat photographs than single-seat ones and captions mix them, which is why the
## reference is a drawing and not a photograph (`craft/falcon/sources.md`).
##
## THE SIMULATION GIVES THE SIZE, THIS GIVES THE SHAPE, as for every airframe here. The fuselage box and the span are
## `kind_geometry`'s `extents` and `span`, kind 27's since 2026-09-18. Every other
## size is MEASURED off [CEL], Marek Cel's CC0 three-view of the F-16A Block 15, a VECTOR drawing in millimetres at 1:100,
## read from its own coordinates by `craft/falcon/measure_threeview.py` -- so no pixel was picked, and a drawing unit is
## 0.1 m. Figures that are not on the drawing say ESTIMATE and what they were reasoned from.
##
## THE FRAME IS THE DRAWING'S OWN. Every constant here is an x or a y that can be found on [CEL] with a ruler: `station(x)`
## turns the drawing's x (mm, increasing aft) into a z, and `height(y)` turns its y (mm, increasing DOWN the page) into a
## y. The side view's datum is y = 60.0, the bottom of both drawn tyres (59.91 and 60.03), so heights are over the ground
## with the gear down, as the Hawkeye's are.
##
## TESSELLATION, STATED SO NOBODY SUBDIVIDES IT. The user's direction of 2026-09-17 -- "a somewhat lower poly look ... not
## too many very round edges" -- and, for this aircraft, "prefer the lower poly model without smooth edges, but still high
## quality and high fidelity". The Hawkeye is the reference and every count here is AT OR BELOW its count for the same
## kind of part:
## - FUSELAGE: 18 facets a ring (the Hawkeye's fuselage has 20), through 26 measured rings. Each half-ring is nine flat
##   panels between named points -- spine, canopy crown, canopy sill, deck, blend, chine, under-chine, duct, keel -- so the
##   creases fall where the aeroplane has them: the chine along the nose and the LERX edge are hard edges, not a curve.
## - NOZZLE_SIDES 12 (the Hawkeye's nacelle round is 16). WHEEL_SIDES 10. PITOT_SIDES 6.
## - A wing or tail section is SIX points: leading edge, two on top, trailing edge, two below.
## Every face carries its own normal (`Plating`), so no edge is smoothed. TESSELLATION IS NOT SHAPE: `tests/falcon.gd`
## asserts measured dimensions that must pass unchanged across a retessellation.
##
## FIDELITY MEANS THE FEATURES, NOT THE TRIANGLES. The first-glance cues, each a named part `tests/falcon.gd` counts:
## `Intake` (the chin intake, with a dark throat set back inside a lip so it reads as a hole), the canopy (the
## `Fuselage`'s second surface, `CANOPY_SURFACE`, glazing with no bow in front of the pilot), the LERX (in `Fuselage`: the chine runs out from 0.58 m at the windscreen to
## 1.41 m at the wing root), `Fin`, `VentralFin*`, `Stabilator*` and one `Nozzle`.
##
## THREE THINGS MOVE, each on a hinge measured off [CEL]: the flaperons, the all-moving stabilators and the rudder,
## driven from the pilot's stick and rudder by `VehicleView.draw_the_falcon_from` as the Cessna's are. The gear is shown
## or stowed from the bus's gear bit (`set_gear`).
##
## NOT IN VehicleView's `_body`: `_show_body` paints one flat material over every mesh there, and this airframe's colour
## is in its vertices, so a crew that boarded and left would bring it back plain grey (`lane/fleet`, Hawkeye).

## THE SIMULATION'S SHAPE IS KIND 27, FALCON (`cockpit_world.cpp`, `falcon_shape`), and this reads it: the box is the
## tail booms' 2.20 m across, the ground to the canopy's top, and the radome tip to the nozzle's exit; the span is the
## wingtip rails'. Until 2026-09-18 those numbers lived here as a draft; the kind owns them now and the draft is gone,
## as `tests/falcon.gd` required.

## The drawing's scale: 1:100 in millimetres, so one unit is 0.1 m.
const MM: float = 0.1
## THE DATUMS, on [CEL]. The radome tip is where the plan outline leaves the pitot boom; the ground is the tyres' bottoms.
const RADOME_X: float = 13.30
const PITOT_X: float = 8.06
const NOZZLE_X: float = 160.0
const GROUND_Y: float = 60.0

## THE M61A1's MUZZLE PORT, `at(out, x, y)` in drawing millimetres: ESTIMATE. Wikipedia has the gun "mounted inside the
## fuselage to the left of the cockpit"; the port is on the left shoulder, between the deck line and the strake, abeam
## the back of the pilot's seat. The first guess, 0.45 m up, was 0.43 m inside the skin the SECTIONS draw there. The
## simulation fires the gun from here (`loadout_of`, kind FALCON), and tests/jet_arms.gd holds every round to it.
const GUN_PORT: Vector3 = Vector3(-7.2, 57.5, 38.0)

## THE PAINT. The F-16A's "Hill Gray II" is FS 36270 Medium Gray over the top and FS 36375 Light Ghost Gray on the sides
## and underneath; the radome was painted to match. sRGB approximations: ESTIMATE.
const TOP := Color(0.46, 0.49, 0.51)
const LIGHT := Color(0.62, 0.64, 0.66)
## The canopy's gold tint is its signature at any range: the transparency is coated against radar return.
const GLASS := Color(0.34, 0.29, 0.14)
const FRAME := Color(0.20, 0.21, 0.22)
const BLACK := Color(0.05, 0.05, 0.05)
const METAL := Color(0.34, 0.32, 0.30)
const GEAR := Color(0.82, 0.82, 0.80)

## THE FUSELAGE, ring by ring [CEL]. Each row is
##   [x, top, sill_w, sill_y, deck_w, deck_y, chine_w, chine_y, duct_w, duct_y, keel_w, bottom]
## in drawing millimetres, half-widths out from the centreline and heights down the page:
## - `top` is the side view's upper silhouette: the canopy over the cockpit and the spine elsewhere.
## - `sill` is where the canopy meets the fuselage (in front of and behind the canopy, the spine's shoulder). Its width
##   over the cockpit is the canopy's own outline in plan -- rounded at the front, 0.93 m across at x 48.7 to 59.1 and
##   tapering to a point at x 73.1 -- and its height the glazing's lower edge in the side view.
## - `deck` is the fuselage's top shoulder, the plan's line at 4.8 mm out behind the canopy.
## - `chine` is the plan outline itself: the nose chine forward of x 36.5 and the LEADING-EDGE ROOT EXTENSION aft of it,
##   growing from 5.82 mm out to 14.1 at the wing's leading edge, on the side view's LERX line at y 40.8. At the wing's
##   trailing edge it STEPS in to the tail boom's edge at 11.0 -- the plan draws a corner there, and the first build's
##   taper over 3.5 mm left a triangle of body standing proud behind the wing that only the plan overlay showed.
## - `duct` and `keel` are the lower fuselage: the forward fuselage's rounded belly to x 56.3, and from x 59.9 the intake
##   duct's D section, 1.56 m across (the front view's D, 7.8 mm out) with its bottom on the side view's line at y 50.
## Two measured points between each pair are placed rather than typed: the BLEND on the upper surface sags towards the
## chine (70 per cent of the way down), and the UNDER-CHINE rises towards it (30 per cent), which is what makes the
## LERX a thin shelf and not a wedge.
const SECTIONS: Array = [
	[14.0, 42.03, 0.55, 42.40, 0.72, 42.65, 0.80, 42.90, 0.60, 43.40, 0.30, 43.73],
	[16.5, 40.93, 1.40, 41.40, 1.75, 42.00, 1.90, 42.60, 1.50, 43.60, 0.80, 44.15],
	[21.5, 39.04, 2.80, 39.80, 3.40, 40.80, 3.67, 41.90, 3.00, 43.90, 1.60, 44.69],
	[26.5, 37.50, 3.70, 38.30, 4.40, 39.80, 4.76, 41.50, 3.90, 44.00, 2.10, 44.78],
	[31.5, 36.19, 4.20, 37.00, 5.00, 38.90, 5.32, 41.10, 4.40, 43.90, 2.40, 44.62],
	[36.5, 35.23, 1.50, 35.40, 5.00, 36.60, 5.82, 40.80, 4.60, 43.60, 2.60, 44.37],
	[38.5, 33.21, 2.90, 35.30, 5.40, 36.40, 6.58, 40.80, 4.80, 43.50, 2.70, 44.18],
	[41.5, 31.57, 3.90, 35.20, 5.80, 36.20, 6.98, 40.80, 5.00, 43.30, 2.80, 43.97],
	[46.0, 29.45, 4.50, 34.90, 6.10, 35.90, 7.55, 40.80, 5.20, 43.10, 3.00, 43.70],
	[50.5, 28.30, 4.65, 34.40, 6.30, 35.60, 7.90, 40.80, 5.40, 42.90, 3.20, 43.47],
	[56.3, 28.07, 4.65, 33.80, 6.40, 35.25, 8.40, 40.80, 5.50, 42.80, 3.20, 43.30],
	[59.9, 28.45, 4.50, 33.15, 6.40, 35.05, 9.20, 40.80, 7.80, 45.80, 5.40, 50.15],
	[60.6, 28.55, 4.45, 33.00, 6.40, 35.00, 9.35, 40.80, 7.80, 45.80, 5.40, 50.20],
	[61.9, 28.80, 4.25, 32.90, 6.30, 34.90, 9.70, 40.80, 7.80, 45.80, 5.40, 50.25],
	[67.0, 29.66, 2.90, 32.50, 6.00, 34.60, 10.96, 40.80, 7.80, 45.80, 5.40, 50.39],
	[70.4, 30.40, 1.06, 32.30, 5.60, 34.40, 12.00, 40.80, 7.80, 45.70, 5.40, 50.35],
	[73.1, 31.05, 0.60, 31.30, 5.00, 33.50, 12.77, 40.80, 7.70, 45.60, 5.30, 50.30],
	[81.6, 31.90, 2.60, 32.30, 5.00, 33.60, 14.10, 40.80, 7.40, 45.50, 5.20, 50.00],
	[90.0, 32.51, 3.00, 32.80, 5.00, 33.70, 13.90, 40.80, 7.30, 45.40, 5.20, 49.75],
	[104.6, 32.55, 3.20, 32.80, 5.20, 33.60, 13.80, 40.80, 7.30, 45.20, 5.30, 49.43],
	[121.3, 32.58, 3.40, 32.80, 5.50, 33.50, 13.80, 40.80, 7.30, 45.00, 5.40, 49.20],
	[121.7, 32.58, 3.40, 32.80, 5.50, 33.50, 11.00, 40.80, 7.30, 45.00, 5.40, 49.18],
	[125.0, 32.58, 3.40, 32.80, 5.50, 33.50, 11.00, 40.80, 7.20, 44.80, 5.30, 48.90],
	[132.0, 32.60, 3.40, 32.90, 5.50, 33.60, 11.00, 40.80, 7.00, 44.60, 5.00, 48.55],
	[140.0, 33.00, 3.40, 33.20, 5.40, 34.00, 10.00, 40.80, 6.80, 44.50, 4.80, 47.90],
	[146.0, 33.60, 3.20, 33.80, 5.00, 34.60, 8.40, 40.60, 6.40, 44.20, 4.40, 47.20],
]
const FUSELAGE_SIDES: int = 18
## THE CANOPY [CEL]: glass from the windscreen's foot to the aft point in plan, except the fixed frame BEHIND the pilot.
## There is no bow in front of the pilot -- the F-16's whole forward transparency is one piece -- so nothing is drawn
## between x 36.5 and the frame.
const CANOPY: Vector2 = Vector2(36.5, 73.1)
const CANOPY_FRAME: Vector2 = Vector2(60.6, 61.9)

## THE CHIN INTAKE [CEL]: a D section, flat on top under the fuselage and round below, 1.56 m across and 0.67 m deep, its
## lip RAKED -- the upper lip at x 52.8 stands 0.34 m ahead of the lower. Points are [half width, y] from the top centre.
const INTAKE_D: Array = [[0.0, 43.35], [7.40, 43.35], [7.80, 44.60], [7.80, 46.40], [7.20, 48.20], [5.60, 49.50],
	[3.00, 50.05], [0.0, 50.15]]
const INTAKE_LIP: Vector2 = Vector2(52.8, 56.2)  # upper lip x, lower lip x
const INTAKE_BACK: float = 61.0
## How far aft the dark throat sits behind the lip: enough that a lit mouth reads as a hole from ahead and from the front
## quarter, and NO FURTHER than the fuselage's own step down into the duct, which runs parallel to the lip 3.5 mm behind
## it (rows 56.3 and 59.9). A deeper throat put that step -- a grey face -- inside the mouth, in front of the black.
const THROAT_DEPTH: float = 3.0

## THE WING [CEL], fitted by `measure_threeview.py` over 67 rows at 0.009 mm rms: leading edge x = 70.287 + 0.8058 h, a
## 38.9 degree sweep, and a trailing edge unswept at x 121.49. Its root is buried in the body at 12.0 mm out, the LERX's
## edge is at 14.1, and its tip is at the launcher rail's inner face, 48.1. Flat -- the F-16 has no dihedral, and the
## front view draws the wing level.
const WING_LE: Vector2 = Vector2(70.287, 0.8058)
const WING_TE: float = 121.49
const WING_ROOT: float = 12.0
const WING_TIP: float = 48.1
const WING_Y: float = 40.9
## Thickness as a share of chord: the F-16's NACA 64A204 is 4 per cent. ESTIMATE from the section's published name, which
## has not been read from a source this session.
const WING_THICK: float = 0.04
## THE FLAPERONS [CEL]: the plan's hinge line at x 116.3, from 14.5 mm out to 37.9.
const FLAPERON: Vector3 = Vector3(14.5, 37.9, 116.3)  # inner, outer, hinge x
## Travel, ESTIMATE: 20 degrees each way, as roll; 20 down as a flap.
const FLAPERON_TRAVEL: float = deg_to_rad(20.0)
## THE WINGTIP LAUNCHER RAILS [CEL]: 48.1 to 49.8 mm out, x 95.7 to 123.4, hung under the tip; the plan draws the first
## 3.3 mm as a taper to a point, so the bar starts at x 99.0 and a wedge runs forward from it.
const RAIL: Rect2 = Rect2(99.0, 48.1, 24.4, 1.7)
const RAIL_NOSE: float = 95.7
const RAIL_Y: Vector2 = Vector2(40.9, 42.3)

## THE TAILPLANES [CEL], all-moving: leading edge x = 124.46 + 0.8931 h at 0.009 mm rms, 41.8 degrees; trailing edge
## unswept at 159.84, its outer corner cropped from 26.5 mm out to the tip at 29.45. ANHEDRAL 10 DEGREES, measured off the
## front view, where the tailplane runs from 15.3 mm out at y 42.0 to 29.5 at 44.5.
const TAIL_LE: Vector2 = Vector2(124.46, 0.8931)
const TAIL_TE: float = 159.84
const TAIL_ROOT: float = 10.0
const TAIL_CROP: float = 26.5
const TAIL_TIP: float = 29.45
const TAIL_TIP_TE: float = 157.5
const TAIL_Y: float = 40.8
const TAIL_ANHEDRAL: float = deg_to_rad(10.0)
## The pivot: ESTIMATE, at 47 per cent of the root chord, where an all-moving surface balances.
const TAIL_PIVOT_X: float = 146.0
const TAIL_TRAVEL: float = deg_to_rad(25.0)
## THE TAIL BOOMS the tailplanes pivot on, beside the nozzle [CEL]: the plan's strakes 8.2 to 11.0 mm out, to x 156.
const BOOM: Vector4 = Vector4(121.5, 156.0, 8.2, 11.0)  # fore x, aft x, inner, outer
const BOOM_Y: Vector2 = Vector2(39.9, 42.0)

## THE FIN [CEL], side view: root leading edge at (127.0, 28.1) on the dorsal fairing, tip leading edge at (152.2, 5.76),
## and the tip cap run aft to x 165.0 above y 7.66. The RUDDER hinges on the line (144.7, 28.1) to (158.9, 7.66) and its
## trailing edge runs (153.75, 28.1) to (163.9, 7.66).
const FIN: Array = [[127.0, 28.1], [152.2, 5.76], [165.0, 5.76], [165.0, 7.66], [158.9, 7.66], [144.7, 28.1]]
const RUDDER: Array = [[144.7, 28.1], [158.9, 7.66], [163.9, 7.66], [153.75, 28.1]]
## The dorsal fairing the fin stands on: it leaves the spine at x 104.6 and reaches the fin's root at 127.
const DORSAL: Array = [[104.6, 32.9], [104.6, 32.5], [127.0, 28.1], [153.75, 28.1], [153.75, 33.2], [140.0, 33.4]]
## Half-thickness at the fin's root and tip, ESTIMATE from the front view: 0.24 m and 0.08 m through.
const FIN_HALF: Vector2 = Vector2(1.2, 0.4)
const RUDDER_TRAVEL: float = deg_to_rad(30.0)

## THE VENTRAL FINS [CEL], side view: root x 117.1 to 131.9 at y 47.3, lower edge (121.1, 54.4) to (131.9, 52.1). Front
## view: root 5.4 mm out, splayed outwards 16 degrees.
const VENTRAL: Array = [[117.1, 47.3], [131.9, 47.3], [131.9, 52.1], [121.1, 54.4]]
const VENTRAL_ROOT_OUT: float = 5.4
const VENTRAL_SPLAY: float = deg_to_rad(16.0)

## THE NOZZLE [CEL]: from x 144.2, 1.42 m across, to the exit at x 160.0, 0.92 m across, on the axis at y 40.4.
const NOZZLE: Array = [[144.2, 7.1], [152.0, 6.0], [160.0, 4.6]]
const NOZZLE_Y: float = 40.4
const NOZZLE_SIDES: int = 12

## THE GEAR [CEL]: the side view draws the tyres as circles. Nose: centre (62.21, 57.27), 5.29 mm across. Main: centre
## (104.04, 56.37), 7.33 mm. THE TRACK is the front view's, which draws the tyres as three rounded bars: the mains' middles
## at y 100.58 and 126.00, 25.42 mm apart, each 1.99 mm wide, the nose's 1.50. The front view puts the nose tyre 0.77 mm
## off its own wing-tip centreline, and the mains symmetric about the nose tyre, so the gear is drawn shifted and the
## track is taken as the distance between the mains, not twice one of them. The first draft typed 2.36 m from memory,
## and it was 0.18 m narrow.
const NOSE_TYRE: Vector3 = Vector3(62.21, 57.27, 5.29)
const MAIN_TYRE: Vector3 = Vector3(104.04, 56.37, 7.33)
const TRACK: float = 25.42
const WHEEL_SIDES: int = 10
const PITOT_SIDES: int = 6

## THE COCKPIT, DERIVED FROM THE AIRFRAME AND NOT TUNED. The F-16's cockpit is shallow -- the canopy's top is 1.55 m
## over the belly under it -- and every station here puts its occupant's eye `CockpitStation.EYE_HEIGHT` (1.35 m) over
## the seat and its floor 4 cm over the seat. So the floor goes as LOW AS THE BELLY LETS IT, 0.3 m inside the keel at
## y 43.0 where the station's 0.6 m floor still fits between the lower facets, and the eye follows: y 29.9, 0.18 m under
## the canopy's top at x 54. The first seat was typed from an eye "0.30 m under the canopy" and put the station's floor
## through the belly; `tests/shell_room.gd` found it, 8 of 8 corners outside.
## The ROOM is the largest box promised inside the drawn skin there, held to the triangles by `tests/falcon.gd`: x 47 to
## 58.5, 0.58 m across, from the floor up to y 31.0.
const CANOPY_SURFACE: int = 1
const CABIN_FLOOR: float = 43.0
const SEAT_Y: float = 43.4
const EYE: Vector2 = Vector2(54.0, SEAT_Y - CockpitStation.EYE_HEIGHT / MM)
const ROOM: Rect2 = Rect2(47.0, 31.0, 11.5, 12.0)  # x from, y from, x length, y length
const ROOM_HALF: float = 2.9

## Small fittings stop drawing once the whole 15 m aeroplane is a few pixels high. The disabled fade mode uses
## hysteresis and is the fast manual-LOD path; SELF and DEPENDENCIES fades are not supported by Mobile.
const DETAIL_RANGE: float = 700.0
const DETAIL_HYSTERESIS: float = 70.0

var _half: Vector3 = Vector3.ONE
var _span: float = 1.0
var _pivots: Dictionary = {}


## BUILT IN PLACE, after `new()`, from the simulation's geometry: the view's, or the kind's own when none is handed.
func dress(geometry: Dictionary = {}) -> void:
	name = "Falcon"
	var native: Dictionary = geometry if geometry.has("extents") else Sim.geometry_of(Sim.Kind.FALCON)
	_half = native["extents"] as Vector3
	_span = float(native["span"])
	var paint: StandardMaterial3D = ShipHull.painted()
	paint.roughness = 0.55
	# THE CANOPY IS GLASS THE PILOT SEES OUT THROUGH, and it is drawn from both sides. Opaque, it would be a gold lid
	# over the pilot's head; single-sided, it vanishes from inside, which is right for glass and wrong for everything
	# else -- see `inside` below. Half see-through, so it still reads as the F-16's gold bubble from outside.
	var glass := StandardMaterial3D.new()
	glass.vertex_color_use_as_albedo = true
	glass.vertex_color_is_srgb = true
	glass.albedo_color = Color(1.0, 1.0, 1.0, 0.55)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	glass.roughness = 0.08
	glass.metallic = 0.35
	# THE SKIN SEEN FROM THE SEAT. Every face here is wound to look outward, so from the pilot's eye -- inside the one
	# closed solid the fuselage is -- back faces are culled and the pilot saw NO aircraft at all: no nose, no canopy
	# rails, no LERX, only the reference room's markers and the station's own panel (the first station picture,
	# 2026-09-18). The Tomcat's crew saw the same and it was fixed the same way (`TomcatAirframe._add_fuselage`).
	var inside: StandardMaterial3D = ShipHull.painted()
	inside.roughness = 0.55
	inside.cull_mode = BaseMaterial3D.CULL_DISABLED

	# THE CANOPY IS THE FUSELAGE'S SECOND SURFACE, not a part of its own. Two meshes left each one open -- the fuselage
	# with a hole where the glass goes and the glass with no bottom -- and a point is inside a craft only if it is inside
	# one closed solid (`tests/shell_room.gd`), so the pilot's head was inside nothing. One mesh, two materials, closed.
	var body := _tool()
	var canopy := _tool()
	_fuselage(body, canopy)
	_pitot(body)
	var fuselage := _add(self, "Fuselage", body, paint)
	fuselage.material_override = null
	fuselage.mesh = canopy.commit(fuselage.mesh as ArrayMesh)
	fuselage.set_surface_override_material(0, inside)
	fuselage.set_surface_override_material(1, glass)

	var intake := _tool()
	_intake(intake)
	_add(self, "Intake", intake, paint)

	for side in [1.0, -1.0]:
		var named: String = "Starboard" if side > 0.0 else "Port"
		var wing := _tool()
		_wing(wing, side)
		_add(self, "Wing" + named, wing, paint)
		var boom := _tool()
		_boom(boom, side)
		_add(self, "TailBoom" + named, boom, paint)
		var ventral := _tool()
		_ventral(ventral, side)
		_add(self, "VentralFin" + named, ventral, paint)
		_flaperon(side, named, paint)
		_stabilator(side, named, paint)

	var fin := _tool()
	_fin(fin)
	_add(self, "Fin", fin, paint)
	_rudder(paint)

	var nozzle := _tool()
	_nozzle(nozzle)
	_add(self, "Nozzle", nozzle, paint)

	# THE GUN PORT, a dark slot in the left shoulder: a part of its own, because the gear's mesh is what the tyres are
	# measured from (tests/falcon.gd), and a slot in it moved the "lowest tyre" to the gun.
	var port := _tool()
	Plating.box(port, gun_port() + Vector3(-0.02, 0.0, 0.0), Vector3(0.06, 0.10, 0.30), BLACK)
	var gun := _add(self, "GunPort", port, paint)
	gun.visibility_range_end = DETAIL_RANGE
	gun.visibility_range_end_margin = DETAIL_HYSTERESIS
	gun.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	gun.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var gear := _tool()
	_gear(gear)
	var fittings := _add(self, "Gear", gear, paint)
	fittings.visibility_range_end = DETAIL_RANGE
	fittings.visibility_range_end_margin = DETAIL_HYSTERESIS
	fittings.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	fittings.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## A DRAWING X (mm, increasing aft) as a z: the radome tip is at the box's front face.
func station(x: float) -> float:
	return -_half.z + (x - RADOME_X) * MM


## A DRAWING Y (mm, increasing down the page) as a y: the ground under the tyres is at the box's bottom face.
func height(y: float) -> float:
	return -_half.y + (GROUND_Y - y) * MM


## A point on the drawing: `out` mm from the centreline (positive to starboard), at drawing x and y.
func at(out: float, x: float, y: float) -> Vector3:
	return Vector3(out * MM, height(y), station(x))


func wing_le(out: float) -> float:
	return WING_LE.x + WING_LE.y * out


func tail_le(out: float) -> float:
	return TAIL_LE.x + TAIL_LE.y * out


## THE ROOM A CREW SITS IN, in the shape `VehicleView.cabin_room()` asks for (`SkyhawkAirframe.cabin_room` is the worked
## example). `room` is the largest box PROMISED inside the drawn skin, and `tests/falcon.gd` holds it to the triangles.
func cabin_room() -> Dictionary:
	var fore: float = station(ROOM.position.x)
	var low: float = height(ROOM.position.y + ROOM.size.y)
	return {
		"drawn": true,
		"floor": height(CABIN_FLOOR),
		"room": AABB(Vector3(-ROOM_HALF * MM, low, fore),
			Vector3(ROOM_HALF * 2.0 * MM, height(ROOM.position.y) - low, station(ROOM.end.x) - fore)),
		"because": &"",
		"why_not": "",
		"source": "floor as low as the belly lets the station's floor fit, eye EYE_HEIGHT over the seat (see CABIN_FLOOR); the room MEASURED against the drawn skin, 2026-09-18",
	}


## THE PILOT'S EYE, craft-local: where a seat for this aircraft should put a head, derived from the canopy.
## WHERE THE GUN PORT IS, in the craft's frame: what the rounds are held to, from the drawing and not from the loadout.
func gun_port() -> Vector3:
	return at(GUN_PORT.x, GUN_PORT.y, GUN_PORT.z)


func eye() -> Vector3:
	return at(0.0, EYE.x, EYE.y)


## THE GEAR, 1 down and 0 up. Shown or stowed: the F-16's legs fold into wells a few pixels across at any range the
## difference would show, and a leg drawn half-retracted is geometry nobody would see.
func set_gear(amount: float) -> void:
	var gear := get_node_or_null("Gear") as Node3D
	if gear != null:
		gear.visible = amount >= 0.5


## THE FLAPERONS: `roll` -1 left wing down to +1 right wing down, and `flap` 0 to 1 drooping both. The down-going wing's
## flaperon rises. Summed and clamped to the travel, as a flaperon's two jobs are.
func set_flaperons(roll: float, flap: float = 0.0) -> void:
	var r: float = clampf(roll, -1.0, 1.0)
	var f: float = clampf(flap, 0.0, 1.0)
	# Trailing edge DOWN is a positive turn about +X for a surface whose trailing edge is at +z from its hinge.
	_swing("FlaperonStarboard", clampf(f - r, -1.0, 1.0) * FLAPERON_TRAVEL)
	_swing("FlaperonPort", clampf(f + r, -1.0, 1.0) * FLAPERON_TRAVEL)


## THE STABILATORS: `pitch` -1 nose down to +1 nose up (trailing edges down to up), and `roll` differential, as the F-16's
## tailplanes help roll.
func set_stabilators(pitch: float, roll: float = 0.0) -> void:
	var p: float = clampf(pitch, -1.0, 1.0)
	var r: float = clampf(roll, -1.0, 1.0) * 0.5
	_swing("StabilatorStarboard", clampf(-p - r, -1.0, 1.0) * TAIL_TRAVEL)
	_swing("StabilatorPort", clampf(-p + r, -1.0, 1.0) * TAIL_TRAVEL)


## THE RUDDER: -1 nose left to +1 nose right; its trailing edge goes to starboard for right rudder.
func set_rudder(yaw: float) -> void:
	_swing("Rudder", clampf(yaw, -1.0, 1.0) * RUDDER_TRAVEL)


## A hinge turned by `angle` about its own axis. The axis is stored on the pivot when it is built, so a caller never
## restates a hinge line.
func _swing(named: String, angle: float) -> void:
	var pivot: Node3D = _pivots.get(named) as Node3D
	if pivot == null:
		return
	var axis: Vector3 = pivot.get_meta("axis") as Vector3
	pivot.basis = Basis(axis, angle)


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


## A LOFT through matching loops, each quad wound to face away from its own loop's middle, and both ends closed by fans
## facing out along the loft. Used for the wing, the tailplanes, the nozzle and the tyres: anything whose section is
## convex. `tints` gives each facet's colour, by the facet's index round the loop, or one colour for all.
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


## A FLAT SLAB from a 2D outline: `place` turns an outline point into its middle-surface position, `across` is the slab's
## normal and `half` its half-thickness at each point. Both faces are triangulated by the engine's own ear clipper, so a
## concave outline -- the fin with its tip cap -- is right, and every edge gets a wall.
static func _slab(tool: SurfaceTool, outline: PackedVector2Array, place: Callable, across: Vector3, half: Callable,
		tint: Color) -> void:
	var tris: PackedInt32Array = Geometry2D.triangulate_polygon(outline)
	var top: Array = []
	var under: Array = []
	for p in outline:
		var h: float = float(half.call(p))
		top.append((place.call(p) as Vector3) + across * h)
		under.append((place.call(p) as Vector3) - across * h)
	for t in range(0, tris.size(), 3):
		_fan(tool, top[tris[t]], top[tris[t + 1]], top[tris[t + 2]], across, tint)
		_fan(tool, under[tris[t]], under[tris[t + 1]], under[tris[t + 2]], -across, tint)
	var area: float = 0.0
	var n: int = outline.size()
	for i in range(n):
		area += outline[i].x * outline[(i + 1) % n].y - outline[(i + 1) % n].x * outline[i].y
	for i in range(n):
		var a2: Vector2 = outline[i]
		var b2: Vector2 = outline[(i + 1) % n]
		var edge: Vector2 = b2 - a2
		# Outward in the outline's plane: the edge turned a quarter away from the polygon's inside.
		var out2: Vector2 = Vector2(edge.y, -edge.x) if area > 0.0 else Vector2(-edge.y, edge.x)
		var mid2: Vector2 = (a2 + b2) * 0.5
		var out3: Vector3 = (place.call(mid2 + out2.normalized() * 0.01) as Vector3) - (place.call(mid2) as Vector3)
		Plating.facing(tool, [top[i], top[(i + 1) % n], under[(i + 1) % n], under[i]], out3, tint)


## ONE RING's points round from the top centreline, starboard side first then port, from a SECTIONS row.
func _ring(row: Array) -> Array:
	var x: float = row[0]
	var top: float = row[1]
	var sill := Vector2(row[2], row[3])
	var deck := Vector2(row[4], row[5])
	var chine := Vector2(row[6], row[7])
	var duct := Vector2(row[8], row[9])
	var keel := Vector2(row[10], row[11])
	var crown := Vector2(sill.x * 0.62, top + 0.22 * (sill.y - top))
	var blend := Vector2((deck.x + chine.x) * 0.5, deck.y + 0.70 * (chine.y - deck.y))
	var under := Vector2((chine.x + duct.x) * 0.5, chine.y + 0.30 * (duct.y - chine.y))
	var half: Array = [Vector2(0.0, top), crown, sill, deck, blend, chine, under, duct, keel, Vector2(0.0, row[11])]
	var points: Array = []
	# Starboard from the top down to the keel, then port back up: 18 distinct points, 18 facets.
	for i in range(half.size() - 1):
		points.append(at((half[i] as Vector2).x, x, (half[i] as Vector2).y))
	for i in range(half.size() - 1, 0, -1):
		points.append(at(-(half[i] as Vector2).x, x, (half[i] as Vector2).y))
	return points


## THE FUSELAGE: 18 flat facets a ring through the measured sections. The two upper facets each side between the windscreen
## and the canopy's aft point are GLASS and go into `canopy` -- its own mesh -- except over the frame behind the pilot.
## Upward-facing panels take the darker top grey, as the paint scheme does.
func _fuselage(tool: SurfaceTool, canopy: SurfaceTool) -> void:
	var rings: Array = []
	for row in SECTIONS:
		rings.append(_ring(row))
	var n: int = FUSELAGE_SIDES
	for r in range(rings.size() - 1):
		var here: float = (float(SECTIONS[r][0]) + float(SECTIONS[r + 1][0])) * 0.5
		var glazed_span: bool = here > CANOPY.x and here < CANOPY.y \
			and not (here > CANOPY_FRAME.x and here < CANOPY_FRAME.y)
		var a: Array = rings[r]
		var b: Array = rings[r + 1]
		var centre: Vector3 = at(0.0, here, (float(SECTIONS[r][1]) + float(SECTIONS[r][11])) * 0.5)
		for k in range(n):
			var quad: Array = [a[k], a[(k + 1) % n], b[(k + 1) % n], b[k]]
			var mid: Vector3 = ((quad[0] as Vector3) + quad[1] + quad[2] + quad[3]) * 0.25
			# The outward direction is away from the ring's own middle in the section's plane.
			var out: Vector3 = Vector3(mid.x - centre.x, mid.y - centre.y, 0.0)
			# Facets 0,1 are the starboard crown and canopy side; 16,17 the port ones.
			var upper: bool = k <= 1 or k >= n - 2
			if glazed_span and upper:
				Plating.facing(canopy, quad, out, GLASS)
				continue
			var normal: Vector3 = ((quad[2] as Vector3) - (quad[0] as Vector3)).cross(
				(quad[1] as Vector3) - (quad[0] as Vector3)).normalized()
			if normal.dot(out) < 0.0:
				normal = -normal
			var tint: Color = FRAME if (upper and here > CANOPY_FRAME.x and here < CANOPY_FRAME.y) \
				else (TOP if normal.y > 0.55 else LIGHT)
			Plating.facing(tool, quad, out, tint)
	# THE NOSE: a fan from the first ring to the radome tip. THE TAIL: closed round the nozzle's root, inside it.
	var tip: Vector3 = at(0.0, RADOME_X, (float(SECTIONS[0][1]) + float(SECTIONS[0][11])) * 0.5)
	var first: Array = rings[0]
	for k in range(n):
		_fan(tool, tip, first[k], first[(k + 1) % n], Vector3.FORWARD, LIGHT)
	var last: Array = rings[rings.size() - 1]
	var back: Vector3 = at(0.0, float(SECTIONS[-1][0]), NOZZLE_Y)
	for k in range(n):
		_fan(tool, back, last[k], last[(k + 1) % n], Vector3.BACK, METAL)


## THE PITOT BOOM, from the radome tip forward to x 8.06: a six-sided taper, bedded half a millimetre into the radome.
func _pitot(tool: SurfaceTool) -> void:
	var y: float = (float(SECTIONS[0][1]) + float(SECTIONS[0][11])) * 0.5
	var loops: Array = []
	for step in [[RADOME_X + 0.6, 0.35], [PITOT_X + 1.0, 0.18], [PITOT_X, 0.05]]:
		var loop: Array = []
		for k in range(PITOT_SIDES):
			var t: float = TAU * float(k) / PITOT_SIDES
			loop.append(at(float(step[1]) * cos(t), float(step[0]), y + float(step[1]) * sin(t)))
		loops.append(loop)
	_loft(tool, loops, [METAL])


## THE CHIN INTAKE. The outer D from the raked lip back into the duct, a grey lip face, and the duct walls running in to a
## dark throat: without the recess a dark patch under the nose is a panel, and with it there is a mouth.
func _intake(tool: SurfaceTool) -> void:
	var outer_at := func(i: int, x: float, scale: float) -> Array:
		# The D's point `i`, starboard then port, at drawing x; `scale` shrinks it about the D's middle.
		var mid_y: float = (float(INTAKE_D[0][1]) + float(INTAKE_D[-1][1])) * 0.5
		var w: float = float(INTAKE_D[i][0]) * scale
		var y: float = mid_y + (float(INTAKE_D[i][1]) - mid_y) * scale
		return [w, y]
	var lip_x := func(y: float) -> float:
		var share: float = (y - float(INTAKE_D[0][1])) / (float(INTAKE_D[-1][1]) - float(INTAKE_D[0][1]))
		return lerpf(INTAKE_LIP.x, INTAKE_LIP.y, share)
	var ring := func(scale: float, x_of: Callable) -> Array:
		var points: Array = []
		for i in range(INTAKE_D.size() - 1):
			var p: Array = outer_at.call(i, 0.0, scale)
			points.append(at(float(p[0]), float(x_of.call(float(p[1]))), float(p[1])))
		for i in range(INTAKE_D.size() - 1, 0, -1):
			var p: Array = outer_at.call(i, 0.0, scale)
			points.append(at(-float(p[0]), float(x_of.call(float(p[1]))), float(p[1])))
		return points
	var lip: Array = ring.call(1.0, lip_x)
	var back: Array = ring.call(0.995, func(_y: float) -> float: return INTAKE_BACK)
	var inner: Array = ring.call(0.86, func(y: float) -> float: return float(lip_x.call(y)) + 0.4)
	var throat: Array = ring.call(0.80, func(y: float) -> float: return float(lip_x.call(y)) + THROAT_DEPTH)
	var n: int = lip.size()
	var mid_y: float = (float(INTAKE_D[0][1]) + float(INTAKE_D[-1][1])) * 0.5
	var axis_at := func(x: float) -> Vector3: return at(0.0, x, mid_y)
	for k in range(n):
		var k2: int = (k + 1) % n
		# The outer skin, lip to duct, facing away from the D's axis.
		var quad: Array = [lip[k], lip[k2], back[k2], back[k]]
		var mid: Vector3 = ((quad[0] as Vector3) + quad[1] + quad[2] + quad[3]) * 0.25
		var axis: Vector3 = axis_at.call((INTAKE_LIP.x + INTAKE_BACK) * 0.5)
		Plating.facing(tool, quad, Vector3(mid.x - axis.x, mid.y - axis.y, 0.0), LIGHT)
		# The lip's face, looking forward.
		Plating.facing(tool, [lip[k], lip[k2], inner[k2], inner[k]], Vector3.FORWARD, LIGHT)
		# The duct wall, looking IN towards the axis: it is the inside of the mouth.
		var wall: Array = [inner[k], inner[k2], throat[k2], throat[k]]
		var wmid: Vector3 = ((wall[0] as Vector3) + wall[1] + wall[2] + wall[3]) * 0.25
		Plating.facing(tool, wall, Vector3(axis.x - wmid.x, axis.y - wmid.y, 0.0), BLACK)
	# The throat, closed, looking forward out of the mouth; and the back, closed inside the fuselage.
	var throat_mid: Vector3 = Vector3.ZERO
	for p in throat:
		throat_mid += p
	throat_mid /= float(n)
	var back_mid: Vector3 = Vector3.ZERO
	for p in back:
		back_mid += p
	back_mid /= float(n)
	for k in range(n):
		_fan(tool, throat_mid, throat[k], throat[(k + 1) % n], Vector3.FORWARD, BLACK)
		_fan(tool, back_mid, back[k], back[(k + 1) % n], Vector3.BACK, LIGHT)


## A SIX-POINT SECTION of a flat lifting surface at `out` mm from the centreline, chord from `le` to `te` at height `y`
## (drawing mm), `thick` as a share of the chord: leading edge, two on top at 15 and 50 per cent, trailing edge, two below.
func _section(out: float, le: float, te: float, y: float, thick: float, side: float) -> Array:
	var c: float = te - le
	var t: float = c * thick * 0.5
	return [at(side * out, le, y), at(side * out, le + 0.15 * c, y - t * 0.8), at(side * out, le + 0.50 * c, y - t),
		at(side * out, te, y), at(side * out, le + 0.50 * c, y + t), at(side * out, le + 0.15 * c, y + t * 0.8)]


const _SURFACE_TINTS: Array = [TOP, TOP, TOP, LIGHT, LIGHT, LIGHT]


## THE WING, one side: the panel to the flaperon's hinge across the flaperon's span, and to the full trailing edge inboard
## and outboard of it, plus the launcher rail under the tip. The root is buried 2.1 mm inside the LERX's edge.
func _wing(tool: SurfaceTool, side: float) -> void:
	# Inboard of the flaperon, full chord.
	_loft(tool, [_section(WING_ROOT, wing_le(WING_ROOT), WING_TE, WING_Y, WING_THICK, side),
		_section(FLAPERON.x, wing_le(FLAPERON.x), WING_TE, WING_Y, WING_THICK, side)], _SURFACE_TINTS)
	# Across the flaperon, to its hinge.
	_loft(tool, [_section(FLAPERON.x, wing_le(FLAPERON.x), FLAPERON.z, WING_Y, WING_THICK * 1.15, side),
		_section(FLAPERON.y, wing_le(FLAPERON.y), FLAPERON.z, WING_Y, WING_THICK * 1.15, side)], _SURFACE_TINTS)
	# Outboard of it, full chord, to the tip.
	_loft(tool, [_section(FLAPERON.y, wing_le(FLAPERON.y), WING_TE, WING_Y, WING_THICK, side),
		_section(WING_TIP, wing_le(WING_TIP), WING_TE, WING_Y, WING_THICK, side)], _SURFACE_TINTS)
	# The launcher rail, a bar under the tip bedded into it.
	Plating.box(tool, at(side * RAIL.get_center().y, RAIL.get_center().x,
		(RAIL_Y.x + RAIL_Y.y) * 0.5), Vector3(RAIL.size.y * MM, (RAIL_Y.y - RAIL_Y.x) * MM, RAIL.size.x * MM), LIGHT)
	# Its nose, a short wedge ahead of it so it does not read as a plank.
	var nose := RAIL.position.x
	var mid_y: float = (RAIL_Y.x + RAIL_Y.y) * 0.5
	var out_mid: float = side * RAIL.get_center().y
	_loft(tool, [[at(out_mid - RAIL.size.y * 0.5, nose + 0.01, RAIL_Y.x), at(out_mid + RAIL.size.y * 0.5, nose + 0.01, RAIL_Y.x),
		at(out_mid + RAIL.size.y * 0.5, nose + 0.01, RAIL_Y.y), at(out_mid - RAIL.size.y * 0.5, nose + 0.01, RAIL_Y.y)],
		[at(out_mid - 0.2, RAIL_NOSE, mid_y), at(out_mid + 0.2, RAIL_NOSE, mid_y), at(out_mid + 0.2, RAIL_NOSE, mid_y + 0.3),
			at(out_mid - 0.2, RAIL_NOSE, mid_y + 0.3)]], [LIGHT])


## THE FLAPERON, one side, in its own pivot on the hinge line: the pivot turns about +X, which is along the unswept hinge.
func _flaperon(side: float, named: String, paint: Material) -> void:
	var pivot := Node3D.new()
	pivot.name = "Flaperon" + named + "Hinge"
	pivot.position = at(side * (FLAPERON.x + FLAPERON.y) * 0.5, FLAPERON.z, WING_Y)
	pivot.set_meta("axis", Vector3.RIGHT)
	add_child(pivot)
	var tool := _tool()
	var loops: Array = []
	for out in [FLAPERON.x + 0.1, FLAPERON.y - 0.1]:
		var section: Array = _section(out, FLAPERON.z - 1.2, WING_TE, WING_Y, WING_THICK * 1.4, side)
		var local: Array = []
		for p in section:
			local.append((p as Vector3) - pivot.position)
		loops.append(local)
	_loft(tool, loops, _SURFACE_TINTS)
	_add(pivot, "Flaperon" + named, tool, paint)
	_pivots["Flaperon" + named] = pivot


## THE TAIL BOOM, one side: the strake beside the nozzle the tailplane pivots on, bedded into the aft fuselage.
func _boom(tool: SurfaceTool, side: float) -> void:
	var fore: float = BOOM.x
	var aft: float = BOOM.y
	var inner: float = BOOM.z
	var outer: float = BOOM.w
	var mid_y: float = (BOOM_Y.x + BOOM_Y.y) * 0.5
	var loops: Array = []
	for step in [[fore, 0.5], [fore + 6.0, 1.0], [aft - 3.0, 1.0], [aft, 0.6]]:
		var x: float = float(step[0])
		var s: float = float(step[1])
		var half_y: float = (BOOM_Y.y - BOOM_Y.x) * 0.5 * s
		loops.append([at(side * inner, x, mid_y - half_y), at(side * outer, x, mid_y - half_y * 0.4),
			at(side * outer, x, mid_y + half_y * 0.4), at(side * inner, x, mid_y + half_y)])
	_loft(tool, loops, [TOP, LIGHT, LIGHT, LIGHT])


## THE STABILATOR, one side, in its own pivot: an all-moving tailplane with 10 degrees of anhedral, turning about a
## spanwise axis through `TAIL_PIVOT_X` that droops with it.
func _stabilator(side: float, named: String, paint: Material) -> void:
	var droop := func(out: float) -> float: return TAIL_Y + (out - TAIL_ROOT) * tan(TAIL_ANHEDRAL)
	var pivot := Node3D.new()
	pivot.name = "Stabilator" + named + "Pivot"
	pivot.position = at(side * TAIL_ROOT, TAIL_PIVOT_X, TAIL_Y)
	var axis: Vector3 = (at(side * TAIL_TIP, TAIL_PIVOT_X, float(droop.call(TAIL_TIP))) - pivot.position).normalized()
	pivot.set_meta("axis", axis * side)
	add_child(pivot)
	var tool := _tool()
	var loops: Array = []
	for step in [[TAIL_ROOT, TAIL_TE, 0.045], [TAIL_CROP, TAIL_TE, 0.04], [TAIL_TIP, TAIL_TIP_TE, 0.04]]:
		var out: float = float(step[0])
		var section: Array = _section(out, tail_le(out), float(step[1]), float(droop.call(out)), float(step[2]), side)
		var local: Array = []
		for p in section:
			local.append((p as Vector3) - pivot.position)
		loops.append(local)
	_loft(tool, loops, _SURFACE_TINTS)
	_add(pivot, "Stabilator" + named, tool, paint)
	_pivots["Stabilator" + named] = pivot


## THE FIN and the dorsal fairing it stands on, as slabs in the side view's plane, thinning from root to tip.
func _fin(tool: SurfaceTool) -> void:
	var place := func(p: Vector2) -> Vector3: return at(0.0, p.x, p.y)
	var fin_half := func(p: Vector2) -> float:
		var share: float = clampf((28.1 - p.y) / (28.1 - 5.76), 0.0, 1.0)
		return lerpf(FIN_HALF.x, FIN_HALF.y, share) * MM
	_slab(tool, _outline(FIN), place, Vector3.RIGHT, fin_half, TOP)
	_slab(tool, _outline(DORSAL), place, Vector3.RIGHT, func(_p: Vector2) -> float: return 1.5 * MM, TOP)


## THE RUDDER in its pivot on the hinge line, which is raked, so it turns about that line and not about the vertical.
func _rudder(paint: Material) -> void:
	var pivot := Node3D.new()
	pivot.name = "RudderHinge"
	var foot: Vector3 = at(0.0, float(RUDDER[0][0]), float(RUDDER[0][1]))
	var head: Vector3 = at(0.0, float(RUDDER[1][0]), float(RUDDER[1][1]))
	pivot.position = foot
	# Right rudder swings the trailing edge to starboard (+x): a positive turn about the hinge pointing UP it, since the
	# trailing edge is aft (+z) of the hinge and a turn about +y carries +z towards +x.
	pivot.set_meta("axis", (head - foot).normalized())
	add_child(pivot)
	var tool := _tool()
	var place := func(p: Vector2) -> Vector3: return at(0.0, p.x, p.y) - foot
	var half := func(p: Vector2) -> float:
		var share: float = clampf((28.1 - p.y) / (28.1 - 7.66), 0.0, 1.0)
		return lerpf(FIN_HALF.x * 0.6, FIN_HALF.y * 0.6, share) * MM
	_slab(tool, _outline(RUDDER), place, Vector3.RIGHT, half, TOP)
	_add(pivot, "Rudder", tool, paint)
	_pivots["Rudder"] = pivot


## THE VENTRAL FIN, one side: a slab splayed outward 16 degrees about its root line under the aft fuselage.
func _ventral(tool: SurfaceTool, side: float) -> void:
	var top_y: float = float(VENTRAL[0][1])
	var place := func(p: Vector2) -> Vector3:
		return at(side * (VENTRAL_ROOT_OUT + (p.y - top_y) * tan(VENTRAL_SPLAY)), p.x, p.y)
	var across: Vector3 = Vector3(cos(VENTRAL_SPLAY) * side, sin(VENTRAL_SPLAY), 0.0).normalized()
	# The root is bedded 1.5 mm up into the belly so the fin grows out of it.
	var outline: Array = [[117.1, top_y - 1.5], [131.9, top_y - 1.5], VENTRAL[2], VENTRAL[3]]
	_slab(tool, _outline(outline), place, across, func(_p: Vector2) -> float: return 0.45 * MM, LIGHT)


## THE NOZZLE: twelve flat petals from the aft fuselage out to the exit, and a dark disc set back inside it.
func _nozzle(tool: SurfaceTool) -> void:
	var loops: Array = []
	for row in NOZZLE:
		var loop: Array = []
		for k in range(NOZZLE_SIDES):
			var t: float = TAU * (float(k) + 0.5) / NOZZLE_SIDES
			loop.append(at(float(row[1]) * cos(t), float(row[0]), NOZZLE_Y + float(row[1]) * sin(t)))
		loops.append(loop)
	_loft(tool, loops, [METAL], false)
	# The exit: a lip ring and the dark inside, set back 1.5 mm.
	var exit: Array = loops[-1]
	var inside: Array = []
	var deep: Array = []
	for k in range(NOZZLE_SIDES):
		var t: float = TAU * (float(k) + 0.5) / NOZZLE_SIDES
		var r: float = float(NOZZLE[-1][1])
		inside.append(at(r * 0.88 * cos(t), NOZZLE_X, NOZZLE_Y + r * 0.88 * sin(t)))
		deep.append(at(r * 0.80 * cos(t), NOZZLE_X - 1.5, NOZZLE_Y + r * 0.80 * sin(t)))
	var axis: Vector3 = at(0.0, NOZZLE_X, NOZZLE_Y)
	for k in range(NOZZLE_SIDES):
		var k2: int = (k + 1) % NOZZLE_SIDES
		Plating.facing(tool, [exit[k], exit[k2], inside[k2], inside[k]], Vector3.BACK, METAL)
		var wall: Array = [inside[k], inside[k2], deep[k2], deep[k]]
		var mid: Vector3 = ((wall[0] as Vector3) + wall[1] + wall[2] + wall[3]) * 0.25
		Plating.facing(tool, wall, Vector3(axis.x - mid.x, axis.y - mid.y, 0.0), BLACK)
		_fan(tool, at(0.0, NOZZLE_X - 1.5, NOZZLE_Y), deep[k], deep[k2], Vector3.BACK, BLACK)
	# The front, closed inside the fuselage.
	var front: Array = loops[0]
	for k in range(NOZZLE_SIDES):
		_fan(tool, at(0.0, float(NOZZLE[0][0]), NOZZLE_Y), front[k], front[(k + 1) % NOZZLE_SIDES], Vector3.FORWARD, METAL)


## THE GEAR, DOWN. The nose leg stands under the intake, as the F-16's does; the mains splay out from the fuselage's belly
## to the track. Every tyre bottom is on the ground, y 60.0.
func _gear(tool: SurfaceTool) -> void:
	_tyre(tool, 0.0, NOSE_TYRE.x, NOSE_TYRE.z, 1.5)
	_strut(tool, at(0.0, NOSE_TYRE.x - 0.8, 49.5), at(0.0, NOSE_TYRE.x, GROUND_Y - NOSE_TYRE.z * 0.5), 0.9)
	for side in [1.0, -1.0]:
		var out: float = side * TRACK * 0.5
		_tyre(tool, out, MAIN_TYRE.x, MAIN_TYRE.z, 1.99)
		var axle: Vector3 = at(out - side * 1.4, MAIN_TYRE.x, GROUND_Y - MAIN_TYRE.z * 0.5)
		_strut(tool, at(side * 6.2, MAIN_TYRE.x - 1.5, 47.5), axle, 1.1)
		_strut(tool, at(side * 6.2, MAIN_TYRE.x + 3.0, 47.8), axle, 0.8)


## A TYRE: a ten-sided prism whose FLATS circumscribe the drawn circle, so the faceted wheel contains the real one and its
## bottom flat sits exactly on the ground; `wide` mm across.
func _tyre(tool: SurfaceTool, out: float, x: float, diameter: float, wide: float) -> void:
	var apothem: float = diameter * 0.5
	var corner: float = apothem / cos(PI / WHEEL_SIDES)
	var axle_y: float = GROUND_Y - apothem
	var loops: Array = []
	for w in [-wide * 0.5, wide * 0.5]:
		var loop: Array = []
		for k in range(WHEEL_SIDES):
			# Offset by half a step so a FLAT, not a corner, is at the bottom.
			var t: float = TAU * (float(k) + 0.5) / WHEEL_SIDES
			loop.append(at(out + w, x + corner * sin(t), axle_y + corner * cos(t)))
		loops.append(loop)
	_loft(tool, loops, [BLACK])


## A LEG from `top` to `foot`, a square bar `thick` mm across.
func _strut(tool: SurfaceTool, top: Vector3, foot: Vector3, thick: float) -> void:
	var along: Vector3 = (foot - top).normalized()
	var side: Vector3 = along.cross(Vector3.FORWARD).normalized()
	if side.length_squared() < 0.5:
		side = Vector3.RIGHT
	var up: Vector3 = side.cross(along).normalized()
	var h: float = thick * 0.5 * MM
	var loops: Array = []
	for p in [top, foot]:
		loops.append([p + side * h + up * h, p - side * h + up * h, p - side * h - up * h, p + side * h - up * h])
	_loft(tool, loops, [GEAR])


static func _outline(points: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(Vector2(float(p[0]), float(p[1])))
	return out
