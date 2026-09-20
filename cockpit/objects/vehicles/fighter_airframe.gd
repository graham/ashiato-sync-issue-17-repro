extends Node3D
class_name FighterAirframe
## AN F/A-18F SUPER HORNET, DRAWN: a flat-sided forebody under a tandem canopy, the leading-edge extensions running from
## the windscreen to the wing, caret intakes under them, a trapezoidal wing with its flaps, ailerons and fold line, twin
## fins canted outboard, all-moving stabilators, two nozzles, a twin-wheel nose gear with its launch bar, main gear that
## swing aft and lie flat under the intakes, and a tailhook. Presentation only: native CockpitWorld owns flight,
## collision, stations and replication.
##
## ORIGINAL GEOMETRY, measured from public references and recorded in `craft/fighter/sources.md`. No third-party mesh,
## photograph, texture or livery is incorporated. Every figure names its source:
## - [NAVY] the U.S. Navy fact file: 60.3 ft (18.38 m) long, 44.9 ft (13.68 m) span, 16 ft (4.87 m) high.
## - [HARV] NASA Armstrong's F-18 HARV three-view (public domain), measured at 0.0086 m/px. It is the LEGACY Hornet, so
##   plan-form figures taken from it are scaled by [WP]'s 25% larger wing, x1.118 linear.
## - [SHP] a Commons F/A-18E gear-down profile (CC BY-SA, studied for proportion only), measured at 0.0151 m/px; its
##   wheels come out at 0.77 and 0.57 m against the 30 in and 22 in tyres, which is the scale's check.
## - [F] a Commons photograph of an F/A-18F side-on (CC BY 2.0, studied only): the two crews' helmets are 0.32 of the
##   canopy's length apart, 1.09 m, and the back seat's eye is about 0.15 m higher.
## - [JB] Joe Baugher, "Structure of F/A-18 Hornet": the mains retract aft and turn 90 degrees to lie flat under the
##   intake ducts; the twin-wheel nose gear retracts forward.
## - [WP] Wikipedia's Super Hornet article: fuselage stretched 86 cm, wing area up 25%, enlarged LEX, caret intakes.
## ESTIMATE marks a figure no reference gives.
##
## LOW POLY ON PURPOSE, and flat-shaded on purpose: the user, 2026-09-17, "let's keep a somewhat lower poly look to
## models, not too many very round edges, this will keep a better 'old school feel' to things", with the E-2D named as
## the aircraft with the right approach. So every face here is flat -- one normal per triangle, no smoothing group
## anywhere -- and anything round is a few facets: sixteen sections round the fuselage, twelve round a nozzle, ten round
## a tyre, six round a strut. DO NOT SUBDIVIDE IT. Adding segments or smoothing the creases would lose the look the game
## is drawn in, and the measurements below do not need them: tessellation is not shape.
##
## STATIONS ARE METRES AFT OF THE NOSE TIP, so a station `s` is `z = s - LENGTH / 2`: the drawn aeroplane is centred on
## the native hull's middle. HEIGHTS ARE METRES ABOVE THE GROUND with the gear down, so `h` is `y = h - rest`, where
## `rest` is the native hull's half-height -- a parked fighter's origin rests 1.0998 m over flat ground (measured
## headless, 2026-09-17), which is where its wheels have to touch.
##
## WHAT THE FIRST MODEL GOT WRONG, and why this one was measured before it was built: it was a cylinder with a capsule
## on it at the right overall envelope, and "the recently added f-18 doesn't look very close to the real thing" (the
## user, 2026-09-17). Its envelope passed its 2% bounds check while nothing inside the box resembled a Hornet.
## And a true-scale fuselage exposed the SEATS: a real pilot's eye is about 3.05 m over the ground [F][SHP] and the
## package's 2.55, so the sill would be at the eye; the package migration that moves the seats is its own commit.
##
## TWO THINGS MOVE, and each is A PURE FUNCTION OF AN AMOUNT, 0 to 1, holding no memory and no timer
## (`cockpit/actuators_research.md` section 3.5): `set_gear(0.3)` then `set_gear(0.5)` draws exactly what `set_gear(0.5)`
## does. How long a part takes is the simulation's to say, once actuators are timed (section 3.8, step 3); until then
## VehicleView hands each the bus's command straight, 1 or 0, as the nacelles are handed theirs.
## - `set_gear`: doors over the first quarter, legs over the rest, so the amount read backwards raises the legs and then
##   shuts the doors. The main doors stay open with the gear down, as the photographs show them.
## - `set_hook`: the arresting hook. Until the bus has a hook channel it is stowed.

const LENGTH := 18.38  # [NAVY] 60.3 ft
const SPAN := 13.68    # [NAVY] 44.9 ft, over the wingtip launchers
const HEIGHT := 4.87   # [NAVY] 16 ft, fin tip over the ground with the gear down

## THE REFERENCE EYES, where a crew's eyes are in the real aircraft [F][SHP]: pilot 4.95 m aft of the nose and 3.05 m up,
## the back seat 1.09 m behind and 0.13 m higher. The canopy is drawn round these, and the seats are moved onto them.
const PILOT_EYE_STATION := 4.95
const PILOT_EYE_HEIGHT := 3.05
const WSO_EYE_STATION := 6.04
const WSO_EYE_HEIGHT := 3.18

## FS 36320 and FS 36375, the Navy's tactical greys over and under, as sRGB approximations: ESTIMATE.
const UPPER := Color(0.47, 0.50, 0.53)
const LOWER := Color(0.62, 0.64, 0.66)
const FRAME := Color(0.33, 0.35, 0.37)
const DARK := Color(0.045, 0.045, 0.05)
const METAL := Color(0.30, 0.28, 0.26)
const GEAR_WHITE := Color(0.84, 0.85, 0.84)
const TYRE := Color(0.06, 0.06, 0.06)
const COCKPIT := Color(0.12, 0.12, 0.13)

## THE FUSELAGE, as sections: [station, top, shoulder height, shoulder half-width, chine height, side half-width at the
## chine, LEX edge half-width, lower half-width, lower side height, bottom]. Heights over the ground.
## - The side and bottom lines are [SHP]'s profile: the nose tip 1.75 m up, the belly 0.97 m up under the intakes; the
##   windscreen foot is at 3.70 m.
## - THE DORSAL LINE is [SHP]'s top, column by column: 3.15 m over the ground at 8.2 m aft, 3.12 at 9.3, 2.94 at 12.0 and
##   2.88 at 12.8, and [HARV]'s legacy spine agrees to 0.1 m (3.10, 3.04, 2.92 at 8.5, 9.5, 11.5). The first draft ran it
##   at 2.82 falling to 2.58, 0.3 m low all the way to the fins, and the side overlay showed it.
## - Half-widths are [HARV]'s plan view: 0.55 m at the cockpit, 1.0 m over the engines.
## - THE LEX EDGE is [HARV]'s legacy edge scaled x1.118 about the wing's root leading edge (9.30 m aft [SHP]): measured
##   column by column it is a FULL CONVEX curve, 1.44 m out at the root, 1.33 at 1.07 m forward of it, 1.20 at 2.10, 0.99
##   at 3.13, 0.86 at 4.16 and 0.73 at 4.85, reaching the windscreen's sides. The first draft drew a straight strake that
##   was 0.07 to 0.12 m narrow forward of 8.2 m. It ends at the wing, so the row after it is bare.
## - Where `w_chine` equals `w_side` there is no strake, only the forebody's chine.
const SECTIONS: Array = [
	[0.00, 1.75, 1.75, 0.001, 1.75, 0.001, 0.001, 0.001, 1.75, 1.75],
	[0.50, 1.93, 1.86, 0.14, 1.76, 0.18, 0.18, 0.15, 1.64, 1.58],
	[1.40, 2.15, 2.02, 0.33, 1.80, 0.40, 0.40, 0.36, 1.52, 1.42],
	[2.60, 2.36, 2.20, 0.48, 1.86, 0.58, 0.60, 0.52, 1.36, 1.26],
	[3.70, 2.52, 2.40, 0.52, 1.90, 0.64, 0.74, 0.58, 1.28, 1.18],
	[4.40, 2.62, 2.58, 0.55, 1.93, 0.66, 0.94, 0.60, 1.22, 1.12],
	[5.60, 2.66, 2.62, 0.57, 1.96, 0.68, 1.07, 0.62, 1.16, 1.07],
	[7.09, 3.12, 2.66, 0.62, 1.99, 0.72, 1.36, 0.66, 1.10, 1.02],
	[8.20, 3.15, 2.66, 0.70, 2.02, 0.76, 1.50, 0.70, 1.06, 0.99],
	[9.30, 3.12, 2.64, 0.78, 2.05, 0.80, 1.61, 0.74, 1.03, 0.97],
	[9.36, 3.12, 2.64, 0.78, 2.05, 0.81, 0.81, 0.74, 1.03, 0.97],
	[11.0, 3.02, 2.56, 0.90, 2.05, 0.92, 0.92, 0.80, 1.02, 0.97],
	[13.0, 2.86, 2.45, 0.98, 2.02, 1.02, 1.02, 0.95, 1.12, 1.08],
	[15.0, 2.62, 2.35, 1.00, 2.00, 1.04, 1.04, 0.98, 1.35, 1.30],
	[16.8, 2.45, 2.30, 0.96, 2.00, 1.00, 1.00, 0.96, 1.60, 1.56],
	[17.3, 2.40, 2.28, 0.94, 2.00, 0.98, 0.98, 0.94, 1.62, 1.58],
]
## THE COCKPIT IS OPEN between these stations, under the canopy: a closed top there would bury the station's panels.
const COCKPIT_OPEN := Vector2(3.70, 7.09)
const COCKPIT_FLOOR := 1.35

## THE CANOPY [SHP][F]: the windscreen foot at 3.70 m and the aft end at 7.09 m, its top 3.40 m over the ground. Rows are
## [station, top]; the base is the fuselage's shoulder. A frame at the windscreen arch, a bow between the two crews
## ([F]: at 5.50 m, between eyes at 4.95 and 6.04) and one at the aft end.
const CANOPY: Array = [[3.70, 2.40], [4.00, 2.80], [4.40, 3.10], [5.00, 3.32], [5.60, 3.40], [6.30, 3.38], [6.80, 3.28],
	[7.09, 3.16]]
const CANOPY_FRAMES: Array[Vector2] = [Vector2(4.28, 4.36), Vector2(5.46, 5.54), Vector2(7.01, 7.09)]

## THE WING [HARV]x1.118:
## - root leading edge at 9.30 m where the LEX meets it, 1.62 m out; inboard of that the root runs straight to the body;
## - leading edge swept 26.5 degrees ([HARV] measured 25.6, the legacy's published 26.7), so the tip's is at 11.81 m;
## - a tip chord of 2.05 m, and a trailing edge swept forward 2.6 degrees as [HARV]'s is;
## - 3 degrees of anhedral: ESTIMATE, from [HARV]'s front view;
## - thickness 5% at the root and about 3% at the tip: ESTIMATE.
const WING_ROOT_X := 0.80
const LEX_ROOT_X := 1.62
const WING_TIP_X := 6.66
const WING_ROOT_LE := 9.30
const WING_LE_SWEEP := 0.46251  # 26.5 degrees
const WING_TIP_CHORD := 2.05
const WING_TE_SWEEP := -0.04538  # 2.6 degrees forward
const WING_ROOT_H := 2.05
const WING_ANHEDRAL := -0.05236  # 3 degrees
const WING_ROOT_THICK := 0.24
const WING_TIP_THICK := 0.07
## THE FOLD LINE: [HARV]'s legacy fold is 4.0 m out; the Super Hornet folds to about 9.3 m across, so 4.45: ESTIMATE.
const FOLD_X := 4.45
## Leading-edge flaps over the front 17% of the chord and trailing-edge flaps and ailerons over the last 28% [HARV].
const LEF_CHORD := 0.17
const TEF_CHORD := 0.28
## The gap drawn at every hinge line, metres.
const HINGE_GAP := 0.025
## THE WINGTIP LAUNCHERS carry the span to [NAVY]'s 13.68 m.
const RAIL_WIDE := 0.18

## THE FINS [SHP][HARV]: canted 20 degrees outboard (the legacy's published figure; [HARV]'s front view measures 18 to 19),
## roots 0.90 m off the centreline on the engine shoulders, tips at the aircraft's height. Root chord from 12.9 to 16.6 m,
## tip from 15.3 to 16.65 m. Rudders over the aft 28% of the lower 60%.
const FIN_CANT := 0.34907  # 20 degrees
const FIN_ROOT_X := 0.90
const FIN_ROOT_H := 2.40
const FIN_ROOT_CHORD := Vector2(12.9, 16.6)
const FIN_TIP_CHORD := Vector2(15.3, 16.65)

## THE STABILATORS: [HARV]'s 6.5 m legacy span x1.118 is 7.3 m; root chord 14.8 to 17.9 m against the nacelle, tip chord
## 17.05 to 18.38 m, whose trailing tip is the aircraft's length. 2 degrees of anhedral: ESTIMATE.
const STAB_ROOT_X := 1.02
const STAB_TIP_X := 3.65
const STAB_ROOT_CHORD := Vector2(14.8, 17.9)
const STAB_TIP_CHORD := Vector2(17.05, 18.38)
const STAB_H := 1.95
const STAB_ANHEDRAL := -0.03491

## THE ENGINES: two nozzles 0.52 m either side and 2.02 m up, their exits 18.2 m aft [SHP][HARV].
const NOZZLE_X := 0.52
const NOZZLE_H := 2.02

## THE CARET INTAKES [WP][F]: under the LEX, 0.56 m wide and 1.0 m deep, their lips RAKED BACK in both planes from the
## top inboard corner -- the top edge 0.5 m back across the width, the outboard edge 0.55 m back down the depth -- and
## STOOD OFF THE FUSELAGE by a 0.14 m diverter gap. The first draft's lip was raked half as far and touched the side,
## and from a three-quarter view it read as a black box. Corners: inboard top, outboard top, outboard bottom, inboard
## bottom, as (x, h, station). ESTIMATE from photographs.
## The duct's box from the lip aft, closing on the fuselage as it goes back into the engine nacelle: [station, inboard
## x, outboard x, top, bottom]. Its underside stays flat over the main gear's bay, where the doors lie against it.
const DUCT: Array = [[10.6, 0.84, 1.42, 1.99, 1.00], [13.1, 0.80, 1.30, 1.99, 1.02], [14.6, 0.80, 0.94, 1.99, 1.32]]
const INTAKE_LIP: Array[Vector3] = [Vector3(0.88, 1.98, 8.90), Vector3(1.44, 1.98, 9.40), Vector3(1.44, 1.00, 9.95),
	Vector3(0.88, 1.00, 9.45)]

## THE NOSE GEAR [SHP][JB]: twin 22 in (0.56 m) wheels 5.87 m aft of the nose, on a leg raked forward from a pivot at
## 5.95 m. It retracts forward. Bay doors either side.
const NOSE_AXLE := Vector2(0.28, 5.87)  # (height, station)
const NOSE_PIVOT := Vector2(1.40, 6.42)
const NOSE_WHEEL_R := 0.28
const NOSE_WHEEL_WIDE := 0.16
const NOSE_WHEEL_X := 0.16
const NOSE_UP := Vector3(0.0, 0.06, -1.0)
const NOSE_BAY := Rect2(4.82, -0.21, 1.80, 0.42)  # station, x
## WHERE THE WHEELS ARE: [SHP]'s tyres located by the centroid of their dark pixels, 5.87 and 12.31 m aft of the nose (a
## 6.44 m wheelbase). The first draft read them off a grid at 5.40 and 11.90, and the side overlay showed both wheels
## half a metre forward of the profile's.
## THE MAIN GEAR [SHP][JB][HARV]: 30 in (0.76 m) wheels 12.31 m aft of the nose, 3.11 m apart (the legacy's published
## track; [HARV] measures 3.05). A splayed oleo from a pivot under the intake, a trailing arm to the axle, and the wheel
## outboard of it. Retracted, the leg lies aft along the duct and the wheel lies flat.
const MAIN_WHEEL_R := 0.38
const MAIN_WHEEL_WIDE := 0.29
const MAIN_TRACK := 3.11
const MAIN_AXLE_STATION := 12.31
const MAIN_PIVOT := Vector3(1.05, 1.30, 11.71)
const MAIN_KNEE := Vector3(1.30, 0.62, 11.96)
const MAIN_BAY := Rect2(11.56, 0.84, 1.80, 0.52)  # station, x: under the duct, inboard of its wall
## THE HOOK: a 2.1 m shank from a pivot 15.80 m aft and 1.45 m up, stowed along the belly between the nozzles [HARV];
## deployed, its shoe reaches the ground with the gear down. Length: ESTIMATE.
const HOOK_PIVOT := Vector2(1.45, 15.80)
const HOOK_LENGTH := 2.10
const HOOK_STOWED_RISE := 0.05
const HOOK_SHOE_DROP := 0.10

## Small fittings stop drawing once the whole aircraft is a few pixels high, with hysteresis; Mobile has no fade.
## https://docs.godotengine.org/en/stable/classes/class_geometryinstance3d.html
const DETAIL_RANGE := 600.0
const DETAIL_HYSTERESIS := 60.0

var exterior: Node3D
var interior: Node3D
## Every separately-drawn surface's bounds in the model's frame, by name, as its vertices were emitted: the check reads
## these rather than the constants that made them.
var surfaces: Dictionary = {}
var _rest: float = 1.10
var _gear_amount: float = 1.0
var _hook_amount: float = 0.0
var _nose_gear: MeshInstance3D
var _main_gear: Array[MeshInstance3D] = []
var _nose_doors: Array[MeshInstance3D] = []
var _main_doors: Array[MeshInstance3D] = []
var _hook: MeshInstance3D
var _main_retracted: Array[Quaternion] = []


func _ready() -> void:
	if get_child_count() == 0:
		_build()


func show_layers(show_exterior: bool, show_interior: bool) -> void:
	if exterior != null: exterior.visible = show_exterior
	if interior != null: interior.visible = show_interior


## Model-frame z of a station.
static func station(s: float) -> float:
	return s - LENGTH * 0.5


## Model-frame y of a height over the ground.
func height(h: float) -> float:
	return h - _rest


## WHERE THE WINGTIPS ARE, left then right: on the outer face of each launcher rail, a third of the tip's chord back, at
## the wing's height there. The nav lights and the contrails stand on them (`VehicleLights`), so they come from the wing
## the airframe draws; the plank's numbers put them 1.0 m low and 2.7 m forward of the drawn tips.
static func wingtips(geometry: Dictionary) -> Array[Vector3]:
	var rest: float = float((geometry.get("extents", Vector3(1.15, 1.10, 9.25)) as Vector3).y)
	var x: float = WING_TIP_X + RAIL_WIDE + 0.03
	var y: float = WING_ROOT_H + (WING_TIP_X - WING_ROOT_X) * tan(WING_ANHEDRAL) - rest
	var z: float = station(wing_leading_edge(WING_TIP_X) + WING_TIP_CHORD / 3.0)
	return [Vector3(-x, y, z), Vector3(x, y, z)]


## THE REST OF THE LIGHTS, in the airframe's frame: {tail, top, bottom}. A white tail light between the nozzles, and an
## anti-collision beacon on the spine and under the belly, both at the wing root: ESTIMATE, placed on the drawn skin.
static func beacons(geometry: Dictionary) -> Dictionary:
	var rest: float = float((geometry.get("extents", Vector3(1.15, 1.10, 9.25)) as Vector3).y)
	var at: float = WING_ROOT_LE + 0.6
	return {
		"tail": Vector3(0.0, NOZZLE_H - rest, station(SECTIONS[SECTIONS.size() - 1][0] + 0.10)),
		"top": Vector3(0.0, section_at(at, 1) - rest + 0.08, station(at)),
		"bottom": Vector3(0.0, section_at(at, 9) - rest - 0.08, station(at)),
	}


## THE NAMED SOCKETS, from the same constants the drawing uses: craft.json's copy is checked against these.
func sockets() -> Dictionary:
	return {
		"nose_gear": [0.0, _round(height(NOSE_AXLE.x)), _round(station(NOSE_AXLE.y))],
		"main_gear_port": [-MAIN_TRACK * 0.5, _round(height(MAIN_WHEEL_R)), _round(station(MAIN_AXLE_STATION))],
		"main_gear_starboard": [MAIN_TRACK * 0.5, _round(height(MAIN_WHEEL_R)), _round(station(MAIN_AXLE_STATION))],
		"arresting_hook": [0.0, _round(height(HOOK_PIVOT.x)), _round(station(HOOK_PIVOT.y))],
		"weapon_port": [-3.55, _round(height(1.65)), _round(station(11.9))],
		"weapon_starboard": [3.55, _round(height(1.65)), _round(station(11.9))],
	}


## THE M61A2's MUZZLE PORT on top of the nose, station and height: ESTIMATE. The simulation fires the gun from here
## (`loadout_of`, kind FIGHTER), and tests/jet_arms.gd holds every round to within a quarter of a metre of it.
const GUN_PORT := Vector2(1.90, 2.205)


## WHERE THE GUN PORT IS, in the craft's frame: what the rounds are held to, from the drawing and not from the loadout.
func gun_port() -> Vector3:
	return Vector3(0.0, height(GUN_PORT.y), station(GUN_PORT.x))


static func _round(value: float) -> float:
	return snappedf(value, 0.01)


func _build() -> void:
	var native: Dictionary = Sim.geometry_of(Sim.Kind.FIGHTER)
	_rest = float((native.get("extents", Vector3(1.15, 1.10, 9.25)) as Vector3).y)
	exterior = Node3D.new(); exterior.name = "Exterior"; add_child(exterior)
	interior = Node3D.new(); interior.name = "Interior"; add_child(interior)
	var paint := _paint(false)
	var both_sides := _paint(true)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.05, 0.14, 0.20, 0.45)
	glass.roughness = 0.08
	glass.metallic = 0.3
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	var body := _tool()
	_fuselage(body)
	_canopy_frames(body)
	for side in [1.0, -1.0]:
		_intake(body, side)
		_wing(body, side)
		_stabilator(body, side)
		_nozzle(body, side)
		_bays(body, side)
	_add(exterior, "Airframe", body, paint, false)

	var canopy := _tool()
	_canopy_glass(canopy)
	_add(exterior, "Canopy", canopy, glass, false)

	var tub := _tool()
	_cockpit_tub(tub)
	_add(exterior, "CockpitTub", tub, both_sides, false)

	for side in [1.0, -1.0]:
		var fin := _tool()
		_fin(fin, side)
		_add(exterior, "FinStarboard" if side > 0.0 else "FinPort", fin, paint, false)

	var details := _tool()
	_details(details)
	var fittings := _add(exterior, "Details", details, paint, true)
	fittings.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	_build_gear(paint)
	_build_hook(paint)

	# NO SEATS HERE. Two grey blocks stood behind the reference eyes until 2026-09-18; the craft now draws a Mk 14 on
	# each seat anchor, fitted to where the rig puts the crew rather than to this drawing's eyes (`PilotSeat`,
	# `VehicleCatalogue.chairs`).
	set_gear(1.0)
	set_hook(0.0)


## THE UNDERCARRIAGE, 0 up and 1 down. Doors open over the first quarter and the legs travel over the rest, so the same
## function read backwards raises the legs first and then shuts the doors.
func set_gear(amount: float) -> void:
	_gear_amount = clampf(amount, 0.0, 1.0)
	var doors: float = smoothstep(0.0, 0.25, _gear_amount)
	var legs: float = smoothstep(0.2, 1.0, _gear_amount)
	if _nose_gear != null:
		var up: Quaternion = Quaternion(Vector3.RIGHT, _nose_swing())
		_nose_gear.basis = Basis(Quaternion.IDENTITY.slerp(up, 1.0 - legs))
	for index in range(_main_gear.size()):
		_main_gear[index].basis = Basis(Quaternion.IDENTITY.slerp(_main_retracted[index], 1.0 - legs))
	for door in _nose_doors + _main_doors:
		var side: float = float(door.get_meta("side"))
		var open: float = float(door.get_meta("open"))
		door.basis = Basis(Vector3.RIGHT, float(door.get_meta("pitch"))) * Basis(Vector3.BACK, side * open * doors)


## THE HOOK, 0 stowed and 1 down.
func set_hook(amount: float) -> void:
	_hook_amount = clampf(amount, 0.0, 1.0)
	if _hook != null:
		_hook.basis = Basis(Vector3.RIGHT, hook_down_angle() * _hook_amount)


func gear_amount() -> float:
	return _gear_amount


func hook_amount() -> float:
	return _hook_amount


## THE ANGLE THE HOOK SWINGS THROUGH so its shoe reaches the ground with the gear down.
##
## Solved for the shoe's lowest corner by bisection: the first version took the shank's own angle and left the shoe
## 4.2 cm under the deck, because the shoe's corner swings lower than the shank's end.
static func hook_down_angle() -> float:
	var low: float = 0.0
	var high: float = 1.4
	for step in range(40):
		var middle: float = (low + high) * 0.5
		if _hook_lowest(middle) > -HOOK_PIVOT.x:
			low = middle
		else:
			high = middle
	return low


## The hook's lowest point relative to its pivot, turned down by `angle`.
static func _hook_lowest(angle: float) -> float:
	var lowest: float = INF
	var turn := Basis(Vector3.RIGHT, angle)
	for corner in _hook_shoe_corners():
		lowest = minf(lowest, (turn * corner).y)
	return lowest


static func _hook_shoe_corners() -> Array[Vector3]:
	var centre := Vector3(0.0, HOOK_STOWED_RISE - HOOK_SHOE_DROP * 0.5, HOOK_LENGTH + 0.02)
	var half := Vector3(0.06, HOOK_SHOE_DROP * 0.5, 0.08)
	var corners: Array[Vector3] = []
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				corners.append(centre + Vector3(sx * half.x, sy * half.y, sz * half.z))
	return corners


## ---- the fuselage -------------------------------------------------------------------------------------------------

## One section as a closed ring: the top centre, down the starboard side to the bottom centre, and up the port side.
func _ring(row: Array) -> Array[Vector3]:
	var s: float = float(row[0])
	var top: float = row[1]; var sh: float = row[2]; var w_sh: float = row[3]; var chine: float = row[4]
	var w_side: float = row[5]; var w_chine: float = row[6]; var w_low: float = row[7]; var low: float = row[8]
	var bottom: float = row[9]
	var strake: bool = w_chine > w_side + 0.02
	var edge: float = 0.03 if strake else 0.0
	var root: float = 0.12 if strake else 0.0
	var half: Array[Vector2] = [
		Vector2(0.0, top),
		Vector2(w_sh * 0.70, top - 0.12 * (top - sh)),
		Vector2(w_sh, sh),
		Vector2(w_side, chine + root),
		Vector2(w_chine, chine + edge),
		Vector2(w_chine, chine - edge),
		Vector2(w_side, chine - root),
		Vector2(w_low, low),
		Vector2(w_low * 0.65, bottom + 0.12 * (low - bottom)),
		Vector2(0.0, bottom),
	]
	var ring: Array[Vector3] = []
	for point in half:
		ring.append(Vector3(point.x, height(point.y), station(s)))
	for index in range(half.size() - 2, 0, -1):
		ring.append(Vector3(-half[index].x, height(half[index].y), station(s)))
	return ring


func _fuselage(tool: SurfaceTool) -> void:
	var rings: Array = []
	for row in SECTIONS:
		rings.append(_ring(row as Array))
	var count: int = (rings[0] as Array).size()
	for i in range(rings.size() - 1):
		var a: Array[Vector3] = rings[i]
		var b: Array[Vector3] = rings[i + 1]
		var s0: float = float((SECTIONS[i] as Array)[0])
		var s1: float = float((SECTIONS[i + 1] as Array)[0])
		var open: bool = s0 >= COCKPIT_OPEN.x - 0.001 and s1 <= COCKPIT_OPEN.y + 0.001
		var centre := Vector3(0.0, height((float((SECTIONS[i] as Array)[4]) + float((SECTIONS[i + 1] as Array)[4])) * 0.5),
			(a[0].z + b[0].z) * 0.5)
		for j in range(count):
			var k: int = j if j < 9 else 17 - j
			if open and k <= 1:
				continue
			var next: int = (j + 1) % count
			var tint: Color = UPPER if k <= 3 else LOWER
			_quad(tool, a[j], a[next], b[next], b[j], (a[j] + b[next]) * 0.5 - centre, tint)
	# THE TAIL CAP between the nozzles.
	var last: Array[Vector3] = rings[rings.size() - 1]
	var middle := Vector3.ZERO
	for point in last:
		middle += point
	middle /= float(last.size())
	for j in range(count):
		_tri(tool, middle, last[j], last[(j + 1) % count], Vector3.BACK, DARK)
	_record("Fuselage", rings)


## A section's value at any station, linearly between rows: 1 top, 2 shoulder height, 3 shoulder half-width, 9 bottom...
static func section_at(s: float, column: int) -> float:
	for i in range(SECTIONS.size() - 1):
		var a: Array = SECTIONS[i]
		var b: Array = SECTIONS[i + 1]
		if s <= float(b[0]) or i == SECTIONS.size() - 2:
			var t: float = clampf((s - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.0001), 0.0, 1.0)
			return lerpf(float(a[column]), float(b[column]), t)
	return 0.0


## ---- the canopy ---------------------------------------------------------------------------------------------------

func _canopy_arc(s: float, top: float, scale: float) -> Array[Vector3]:
	const SEGMENTS := 8
	var sill: float = section_at(s, 2)
	var wide: float = section_at(s, 3) * 0.985
	var arc: Array[Vector3] = []
	for k in range(SEGMENTS + 1):
		var t: float = PI * float(k) / float(SEGMENTS)
		arc.append(Vector3(cos(t) * wide * scale, height(sill + sin(t) * maxf(top - sill, 0.0) * scale), station(s)))
	return arc


func _canopy_top(s: float) -> float:
	for i in range(CANOPY.size() - 1):
		var a: Array = CANOPY[i]
		var b: Array = CANOPY[i + 1]
		if s <= float(b[0]):
			return lerpf(float(a[1]), float(b[1]), clampf((s - float(a[0])) / (float(b[0]) - float(a[0])), 0.0, 1.0))
	return float((CANOPY[CANOPY.size() - 1] as Array)[1])


func _canopy_glass(tool: SurfaceTool) -> void:
	var arcs: Array = []
	for row in CANOPY:
		arcs.append(_canopy_arc(float(row[0]), float(row[1]), 1.0))
	for i in range(arcs.size() - 1):
		var a: Array[Vector3] = arcs[i]
		var b: Array[Vector3] = arcs[i + 1]
		for k in range(a.size() - 1):
			var axis := Vector3(0.0, height(section_at((float((CANOPY[i] as Array)[0]) + float((CANOPY[i + 1] as Array)[0])) * 0.5, 2)),
				(a[k].z + b[k].z) * 0.5)
			_quad(tool, a[k], a[k + 1], b[k + 1], b[k], (a[k] + b[k + 1]) * 0.5 - axis, Color.WHITE)
	_record("Canopy", arcs)


## THE FRAMES AND SILLS, each band a closed tube so it is seen from inside the cockpit as well.
func _canopy_frames(tool: SurfaceTool) -> void:
	for band in CANOPY_FRAMES:
		var s0: float = band.x
		var s1: float = band.y
		var outer0 := _canopy_arc(s0, _canopy_top(s0), 1.03)
		var outer1 := _canopy_arc(s1, _canopy_top(s1), 1.03)
		var inner0 := _canopy_arc(s0, _canopy_top(s0), 0.96)
		var inner1 := _canopy_arc(s1, _canopy_top(s1), 0.96)
		var axis := Vector3(0.0, height(section_at(s0, 2)), station((s0 + s1) * 0.5))
		for k in range(outer0.size() - 1):
			_quad(tool, outer0[k], outer0[k + 1], outer1[k + 1], outer1[k], outer0[k] - axis, FRAME)
			_quad(tool, inner0[k], inner0[k + 1], inner1[k + 1], inner1[k], axis - inner0[k], FRAME)
			_quad(tool, outer0[k], outer0[k + 1], inner0[k + 1], inner0[k], Vector3.FORWARD, FRAME)
			_quad(tool, outer1[k], outer1[k + 1], inner1[k + 1], inner1[k], Vector3.BACK, FRAME)
	# The aft end of the canopy closes onto the spine.
	var end := _canopy_arc(COCKPIT_OPEN.y, _canopy_top(COCKPIT_OPEN.y), 1.0)
	var foot := Vector3(0.0, end[0].y, end[0].z)
	for k in range(end.size() - 1):
		_tri(tool, foot, end[k], end[k + 1], Vector3.BACK, UPPER)
	for side in [1.0, -1.0]:
		var a := Vector3(side * section_at(COCKPIT_OPEN.x, 3), height(section_at(COCKPIT_OPEN.x, 2)), station(COCKPIT_OPEN.x))
		var b := Vector3(side * section_at(COCKPIT_OPEN.y, 3), height(section_at(COCKPIT_OPEN.y, 2)), station(COCKPIT_OPEN.y))
		var run: Vector3 = b - a
		_box(tool, (a + b) * 0.5 + Vector3(0.0, 0.02, 0.0), Vector3(0.06, 0.05, run.length()), FRAME,
			Basis.looking_at(run.normalized(), Vector3.UP))


## THE COCKPIT'S INSIDE: walls down each sill to a floor, and a bulkhead at each end up to the fuselage top, drawn
## double-sided so the open top never shows the ground through the far wall.
func _cockpit_tub(tool: SurfaceTool) -> void:
	const STEPS := 6
	var floor_y: float = height(COCKPIT_FLOOR)
	for side in [1.0, -1.0]:
		for i in range(STEPS):
			var s0: float = lerpf(COCKPIT_OPEN.x, COCKPIT_OPEN.y, float(i) / STEPS)
			var s1: float = lerpf(COCKPIT_OPEN.x, COCKPIT_OPEN.y, float(i + 1) / STEPS)
			var w0: float = section_at(s0, 3) - 0.01
			var w1: float = section_at(s1, 3) - 0.01
			_quad(tool, Vector3(side * w0, height(section_at(s0, 2)), station(s0)),
				Vector3(side * w1, height(section_at(s1, 2)), station(s1)),
				Vector3(side * w1, floor_y, station(s1)), Vector3(side * w0, floor_y, station(s0)),
				Vector3(-side, 0.0, 0.0), COCKPIT)
			_quad(tool, Vector3(w0, floor_y, station(s0)), Vector3(w1, floor_y, station(s1)),
				Vector3(-w1, floor_y, station(s1)), Vector3(-w0, floor_y, station(s0)), Vector3.UP, COCKPIT)
	for s in [COCKPIT_OPEN.x, COCKPIT_OPEN.y]:
		var w: float = section_at(s, 3)
		var top: float = maxf(section_at(s, 1), section_at(s, 2))
		_quad(tool, Vector3(w, floor_y, station(s)), Vector3(-w, floor_y, station(s)),
			Vector3(-w, height(top), station(s)), Vector3(w, height(top), station(s)),
			Vector3.BACK if s < 5.0 else Vector3.FORWARD, COCKPIT)


## ---- the intakes, wing, tail and engines ---------------------------------------------------------------------------

func _intake(tool: SurfaceTool, side: float) -> void:
	var rows: Array = DUCT
	var rings: Array = []
	var lip: Array[Vector3] = []
	for corner in INTAKE_LIP:
		lip.append(Vector3(side * corner.x, height(corner.y), station(corner.z)))
	rings.append(lip)
	for row in rows:
		var r: Array = row
		rings.append([Vector3(side * float(r[1]), height(float(r[3])), station(float(r[0]))),
			Vector3(side * float(r[2]), height(float(r[3])), station(float(r[0]))),
			Vector3(side * float(r[2]), height(float(r[4])), station(float(r[0]))),
			Vector3(side * float(r[1]), height(float(r[4])), station(float(r[0])))])
	var outward: Array[Vector3] = [Vector3.UP, Vector3(side, 0, 0), Vector3.DOWN, Vector3(-side, 0, 0)]
	for i in range(rings.size() - 1):
		var a: Array = rings[i]
		var b: Array = rings[i + 1]
		for k in range(4):
			var tint: Color = LOWER
			_quad(tool, a[k], a[(k + 1) % 4], b[(k + 1) % 4], b[k], outward[k], tint)
	# THE INLET: a duct painted like the skin running back from the raked lip and darkening into the engine face. The
	# first draft set a black face a hand's width inside the lip, and from a quarter it read as a black slab stuck on the
	# side of the aircraft rather than as a hole.
	const DEPTH := 0.9

	var face: Array[Vector3] = []
	for k in range(4):
		var corner: Vector3 = lip[k]
		var toward_middle := Vector3((0.02 if k == 0 or k == 3 else -0.02) * side, -0.02 if k <= 1 else 0.02, 0.0)
		face.append(corner + toward_middle + Vector3(0.0, 0.0, DEPTH))
	var inward: Array[Vector3] = [Vector3.DOWN, Vector3(-side, 0, 0), Vector3.UP, Vector3(side, 0, 0)]
	for k in range(4):
		var shade: Color = LOWER.darkened(0.45) if k != 2 else LOWER.darkened(0.25)
		_quad(tool, lip[k], lip[(k + 1) % 4], face[(k + 1) % 4], face[k], inward[k], shade)
	_quad(tool, face[0], face[1], face[2], face[3], Vector3.FORWARD, DARK)
	# The lip itself, a band the colour of the skin round the opening, so the edge reads from the side.
	for k in range(4):
		var a: Vector3 = lip[k]
		var b: Vector3 = lip[(k + 1) % 4]
		_quad(tool, a, b, b + Vector3(0.0, 0.0, 0.06), a + Vector3(0.0, 0.0, 0.06), inward[k], FRAME)

	_record("IntakeStarboard" if side > 0.0 else "IntakePort", rings)


## THE DUCT'S UNDERSIDE at a station, over the ground.
static func duct_bottom(s: float) -> float:
	var rows: Array = [[INTAKE_LIP[3].z, INTAKE_LIP[3].y]]
	for row in DUCT:
		rows.append([float(row[0]), float(row[4])])
	for i in range(rows.size() - 1):
		if s <= float(rows[i + 1][0]):
			return lerpf(float(rows[i][1]), float(rows[i + 1][1]),
				clampf((s - float(rows[i][0])) / (float(rows[i + 1][0]) - float(rows[i][0])), 0.0, 1.0))
	return float(rows[rows.size() - 1][1])


## THE WING'S PLAN: leading edge and chord at a distance out.
static func wing_leading_edge(x: float) -> float:
	return WING_ROOT_LE + maxf(x - LEX_ROOT_X, 0.0) * tan(WING_LE_SWEEP)


static func wing_trailing_edge(x: float) -> float:
	var tip_te: float = WING_ROOT_LE + (WING_TIP_X - LEX_ROOT_X) * tan(WING_LE_SWEEP) + WING_TIP_CHORD
	# Swept forward, so the trailing edge moves aft toward the root.
	return tip_te + (WING_TIP_X - x) * tan(-WING_TE_SWEEP)


## A point on the wing: `x` out, `c` along the chord 0 to 1, `face` +1 on top and -1 underneath.
func _wing_point(side: float, x: float, c: float, face: float) -> Vector3:
	var le: float = wing_leading_edge(x)
	var chord: float = wing_trailing_edge(x) - le
	var thick: float = lerpf(WING_ROOT_THICK, WING_TIP_THICK, clampf((x - WING_ROOT_X) / (WING_TIP_X - WING_ROOT_X), 0.0, 1.0))
	var h: float = WING_ROOT_H + (x - WING_ROOT_X) * tan(WING_ANHEDRAL)
	return Vector3(side * x, height(h) + face * 0.5 * thick * _airfoil(c), station(le + c * chord))


## A thin symmetric section's thickness along the chord, 0 at the nose, full at 45%.
static func _airfoil(c: float) -> float:
	if c <= 0.45:
		return sin(clampf(c / 0.45, 0.0, 1.0) * PI * 0.5)
	return lerpf(1.0, 0.10, (c - 0.45) / 0.55)


func _wing(tool: SurfaceTool, side: float) -> void:
	var named := "Starboard" if side > 0.0 else "Port"
	var point := func(x: float, c: float, face: float) -> Vector3: return _wing_point(side, x, c, face)
	var g: float = HINGE_GAP
	var lef: float = LEF_CHORD
	var tef: float = 1.0 - TEF_CHORD
	# The fixed wing: the root inboard of the LEX, and the box either side of the fold.
	_slab(tool, point, WING_ROOT_X, LEX_ROOT_X + 0.04, 0.0, 1.0, "WingRoot" + named, side)
	_slab(tool, point, LEX_ROOT_X, FOLD_X - g * 0.5, lef, tef, "WingInboard" + named, side)
	_slab(tool, point, FOLD_X + g * 0.5, WING_TIP_X, lef, tef, "WingOutboard" + named, side)
	# The moving surfaces, each its own slab with a gap at its hinge.
	_slab(tool, point, LEX_ROOT_X + 0.04, FOLD_X - g * 0.5, 0.0, lef - g / 3.0, "LeadingEdgeFlapInboard" + named, side)
	_slab(tool, point, FOLD_X + g * 0.5, WING_TIP_X, 0.0, lef - g / 3.0, "LeadingEdgeFlapOutboard" + named, side)
	_slab(tool, point, LEX_ROOT_X + 0.04, FOLD_X - g * 0.5, tef + g / 3.0, 1.0, "TrailingEdgeFlap" + named, side)
	_slab(tool, point, FOLD_X + g * 0.5, WING_TIP_X - 0.30, tef + g / 3.0, 1.0, "Aileron" + named, side)
	_slab(tool, point, WING_TIP_X - 0.30, WING_TIP_X, tef, 1.0, "WingTip" + named, side)
	# THE FOLD'S DOGTOOTH [WP]: a snag forward of the outer leading edge at the fold.
	var snag_at: Vector3 = point.call(FOLD_X + 0.10, 0.0, 0.0)
	_box(tool, snag_at + Vector3(0.0, 0.0, -0.05), Vector3(0.20, 0.03, 0.10), UPPER)
	# THE TIP LAUNCHER: a rail along the tip that carries the span to 13.68 m.
	var tip_le: Vector3 = point.call(WING_TIP_X, 0.0, 0.0)
	var tip_te: Vector3 = point.call(WING_TIP_X, 1.0, 0.0)
	var rail_length: float = (tip_te.z - tip_le.z) + 1.3
	var rail := Vector3(side * (WING_TIP_X + RAIL_WIDE * 0.5 - 0.001), tip_le.y, tip_le.z - 0.9 + rail_length * 0.5)
	_box(tool, rail, Vector3(RAIL_WIDE, 0.16, rail_length), LOWER)
	surfaces["LauncherRail" + named] = AABB(rail - Vector3(RAIL_WIDE, 0.16, rail_length) * 0.5,
		Vector3(RAIL_WIDE, 0.16, rail_length))


func _stabilator(tool: SurfaceTool, side: float) -> void:
	var named := "Starboard" if side > 0.0 else "Port"
	var point := func(x: float, c: float, face: float) -> Vector3:
		var t: float = (x - STAB_ROOT_X) / (STAB_TIP_X - STAB_ROOT_X)
		var le: float = lerpf(STAB_ROOT_CHORD.x, STAB_TIP_CHORD.x, t)
		var te: float = lerpf(STAB_ROOT_CHORD.y, STAB_TIP_CHORD.y, t)
		var thick: float = lerpf(0.13, 0.04, t)
		return Vector3(side * x, height(STAB_H + (x - STAB_ROOT_X) * tan(STAB_ANHEDRAL)) + face * 0.5 * thick * _airfoil(c),
			station(lerpf(le, te, c)))
	_slab(tool, point, STAB_ROOT_X - 0.10, STAB_TIP_X, 0.0, 1.0, "Stabilator" + named, side)


## A CANTED FIN: `u` up its span, `c` along its chord, `face` +1 outboard. The rudder is a slab of its own.
func _fin(tool: SurfaceTool, side: float) -> void:
	var named := "Starboard" if side > 0.0 else "Port"
	var span: float = (HEIGHT - FIN_ROOT_H) / cos(FIN_CANT)
	var up := Vector3(side * sin(FIN_CANT), cos(FIN_CANT), 0.0)
	var out := Vector3(side * cos(FIN_CANT), -sin(FIN_CANT), 0.0)
	var root := Vector3(side * FIN_ROOT_X, height(FIN_ROOT_H), 0.0)
	var point := func(u: float, c: float, face: float) -> Vector3:
		var le: float = lerpf(FIN_ROOT_CHORD.x, FIN_TIP_CHORD.x, clampf(u, 0.0, 1.0))
		var te: float = lerpf(FIN_ROOT_CHORD.y, FIN_TIP_CHORD.y, clampf(u, 0.0, 1.0))
		var thick: float = lerpf(0.13, 0.05, clampf(u, 0.0, 1.0))
		var at: Vector3 = root + up * (u * span) + out * (face * 0.5 * thick * _airfoil(c))
		at.z = station(lerpf(le, te, c))
		return at
	var tef: float = 0.72
	var g: float = HINGE_GAP / 3.0
	# The fin's root starts a little inside the engine shoulder so no light shows under it.
	_slab_about(tool, point, -0.03, 1.0, 0.0, tef, "Fin" + named, out, up)
	_slab_about(tool, point, -0.03, 0.05, tef, 1.0, "FinRootAft" + named, out, up)
	_slab_about(tool, point, 0.05 + g, 0.60, tef + g, 1.0, "Rudder" + named, out, up)
	_slab_about(tool, point, 0.60 + g, 1.0, tef, 1.0, "FinTipAft" + named, out, up)


func _nozzle(tool: SurfaceTool, side: float) -> void:
	const SIDES := 12
	var centre := Vector3(side * NOZZLE_X, height(NOZZLE_H), 0.0)
	var rows: Array = [[17.10, 0.46, LOWER], [17.60, 0.47, METAL], [18.20, 0.41, METAL]]
	var rings: Array = []
	for row in rows:
		var ring: Array[Vector3] = []
		for k in range(SIDES):
			var t: float = TAU * float(k) / SIDES
			ring.append(centre + Vector3(cos(t) * float(row[1]), sin(t) * float(row[1]), station(float(row[0]))))
		rings.append(ring)
	for i in range(rings.size() - 1):
		for k in range(SIDES):
			var a: Vector3 = (rings[i] as Array)[k]
			var b: Vector3 = (rings[i] as Array)[(k + 1) % SIDES]
			var c: Vector3 = (rings[i + 1] as Array)[(k + 1) % SIDES]
			var d: Vector3 = (rings[i + 1] as Array)[k]
			var hint := Vector3(a.x - centre.x, a.y - centre.y, 0.0)
			_quad(tool, a, b, c, d, hint, (rows[i + 1] as Array)[2])
	var exit: Vector3 = centre + Vector3(0.0, 0.0, station(18.05))
	for k in range(SIDES):
		var t0: float = TAU * float(k) / SIDES
		var t1: float = TAU * float(k + 1) / SIDES
		_tri(tool, exit, exit + Vector3(cos(t0), sin(t0), 0.0) * 0.40, exit + Vector3(cos(t1), sin(t1), 0.0) * 0.40,
			Vector3.BACK, DARK)
	_record("Nozzle" + ("Starboard" if side > 0.0 else "Port"), rings)


## THE BAYS' DARK INSIDES, just under the belly, where the doors close over them.
func _bays(tool: SurfaceTool, side: float) -> void:
	var bay_front: float = height(duct_bottom(MAIN_BAY.position.x)) - 0.008
	var bay_back: float = height(duct_bottom(MAIN_BAY.end.x)) - 0.008
	_quad(tool, Vector3(side * MAIN_BAY.position.y, bay_front, station(MAIN_BAY.position.x)),
		Vector3(side * MAIN_BAY.end.y, bay_front, station(MAIN_BAY.position.x)),
		Vector3(side * MAIN_BAY.end.y, bay_back, station(MAIN_BAY.end.x)),
		Vector3(side * MAIN_BAY.position.y, bay_back, station(MAIN_BAY.end.x)), Vector3.DOWN, DARK)
	if side > 0.0:
		var s0: float = NOSE_BAY.position.x
		var s1: float = NOSE_BAY.end.x
		var y0: float = height(section_at(s0, 9)) - 0.006
		var y1: float = height(section_at(s1, 9)) - 0.006
		_quad(tool, Vector3(NOSE_BAY.position.y, y0, station(s0)), Vector3(NOSE_BAY.end.y, y0, station(s0)),
			Vector3(NOSE_BAY.end.y, y1, station(s1)), Vector3(NOSE_BAY.position.y, y1, station(s1)), Vector3.DOWN, DARK)


## Pylons, antennae and the gun port: small things, range-culled.
func _details(tool: SurfaceTool) -> void:
	for side in [1.0, -1.0]:
		# THREE UNDERWING PYLONS each side, toed out 4 degrees as the Super Hornet's are [WP]. Stations: ESTIMATE.
		for x in [2.40, 3.55, 5.05]:
			var mid: Vector3 = _wing_point(side, x, 0.42, -1.0)
			var toe := Basis(Vector3.UP, -side * deg_to_rad(4.0))
			_box(tool, mid + Vector3(0.0, -0.17, 0.0), Vector3(0.12, 0.34, 2.10), LOWER, toe)
		# The LEX fence-less spoilers are left out; the AoA probe on each side of the nose is in.
		_box(tool, Vector3(side * 0.30, height(1.92), station(2.10)), Vector3(0.05, 0.03, 0.22), METAL)
	# Blade antennae on the spine, and the gun's muzzle port on the nose's top: ESTIMATE.
	_box(tool, Vector3(0.0, height(section_at(8.6, 1) + 0.11), station(8.6)), Vector3(0.03, 0.26, 0.30), FRAME)
	_box(tool, Vector3(0.0, height(section_at(12.2, 1) + 0.08), station(12.2)), Vector3(0.03, 0.20, 0.26), FRAME)
	_box(tool, gun_port(), Vector3(0.10, 0.02, 0.16), DARK)


## ---- gear and hook ------------------------------------------------------------------------------------------------

func _build_gear(paint: Material) -> void:
	# NOSE GEAR, built in its down pose relative to its pivot.
	var nose := _tool()
	var pivot := Vector3(0.0, height(NOSE_PIVOT.x), station(NOSE_PIVOT.y))
	var axle := Vector3(0.0, height(NOSE_AXLE.x), station(NOSE_AXLE.y))
	var knee: Vector3 = axle + Vector3(0.0, 0.16, 0.05)
	_rod(nose, pivot - pivot, knee - pivot, 0.07, GEAR_WHITE)
	_rod(nose, Vector3(-NOSE_WHEEL_X, axle.y, axle.z) - pivot, Vector3(NOSE_WHEEL_X, axle.y, axle.z) - pivot, 0.04, METAL)
	for side in [1.0, -1.0]:
		_wheel(nose, Vector3(side * NOSE_WHEEL_X, axle.y, axle.z) - pivot, NOSE_WHEEL_R, NOSE_WHEEL_WIDE)
	# THE LAUNCH BAR, stowed up the front of the strut, and the torque links behind it.
	_rod(nose, knee + Vector3(0.0, 0.05, -0.10) - pivot, pivot + Vector3(0.0, -0.35, -0.30) - pivot, 0.035, GEAR_WHITE)
	_box(nose, (knee + pivot) * 0.5 + Vector3(0.0, -0.10, 0.12) - pivot, Vector3(0.06, 0.30, 0.05), METAL)
	_box(nose, knee + Vector3(0.0, 0.22, -0.02) - pivot, Vector3(0.06, 0.05, 0.08), GEAR_WHITE)
	_nose_gear = _add(exterior, "NoseGear", nose, paint, true, pivot)

	for side in [1.0, -1.0]:
		var named := "Starboard" if side > 0.0 else "Port"
		var main_pivot := Vector3(side * MAIN_PIVOT.x, height(MAIN_PIVOT.y), station(MAIN_PIVOT.z))
		var main_knee := Vector3(side * MAIN_KNEE.x, height(MAIN_KNEE.y), station(MAIN_KNEE.z))
		var wheel_centre := Vector3(side * MAIN_TRACK * 0.5, height(MAIN_WHEEL_R), station(MAIN_AXLE_STATION))
		var axle_root: Vector3 = wheel_centre - Vector3(side * (MAIN_WHEEL_WIDE * 0.5 + 0.06), 0.0, 0.0)
		var leg := _tool()
		_rod(leg, Vector3.ZERO, main_knee - main_pivot, 0.09, GEAR_WHITE)
		_rod(leg, main_knee - main_pivot, axle_root - main_pivot, 0.07, GEAR_WHITE)
		_rod(leg, axle_root - main_pivot, wheel_centre - main_pivot, 0.05, METAL)
		_wheel(leg, wheel_centre - main_pivot, MAIN_WHEEL_R, MAIN_WHEEL_WIDE)
		_box(leg, (main_knee - main_pivot) * 0.55 + Vector3(-side * 0.08, 0.0, -0.08), Vector3(0.05, 0.28, 0.05), METAL)
		var node := _add(exterior, "MainGear" + named, leg, paint, true, main_pivot)
		_main_gear.append(node)
		_main_retracted.append(_main_retraction(side))

		# THE MAIN DOOR, hinged along its inboard edge, hanging straight down when open.
		var door := _tool()
		var door_h: float = height(duct_bottom(MAIN_BAY.end.x)) - 0.015
		var width: float = MAIN_BAY.size.y
		_box(door, Vector3(side * width * 0.5, 0.0, MAIN_BAY.size.x * -0.5), Vector3(width, 0.025, MAIN_BAY.size.x), LOWER)
		var hinge := Vector3(side * MAIN_BAY.position.y, door_h, station(MAIN_BAY.end.x))
		var door_node := _add(exterior, "MainDoor" + named, door, paint, true, hinge)
		door_node.set_meta("side", side)
		door_node.set_meta("open", -deg_to_rad(92.0))
		door_node.set_meta("pitch", atan2(duct_bottom(MAIN_BAY.position.x) - duct_bottom(MAIN_BAY.end.x), MAIN_BAY.size.x))
		_main_doors.append(door_node)

		var nose_door := _tool()
		var nose_h: float = height(section_at(NOSE_BAY.end.x, 9)) - 0.012
		_box(nose_door, Vector3(-side * NOSE_BAY.size.y * 0.25, 0.0, NOSE_BAY.size.x * -0.5),
			Vector3(NOSE_BAY.size.y * 0.5, 0.02, NOSE_BAY.size.x), LOWER)
		var nose_hinge := Vector3(side * NOSE_BAY.end.y, nose_h, station(NOSE_BAY.end.x))
		var nose_door_node := _add(exterior, "NoseDoor" + named, nose_door, paint, true, nose_hinge)
		nose_door_node.set_meta("side", side)
		nose_door_node.set_meta("open", deg_to_rad(88.0))
		nose_door_node.set_meta("pitch", atan2(section_at(NOSE_BAY.position.x, 9) - section_at(NOSE_BAY.end.x, 9),
			NOSE_BAY.size.x))
		_nose_doors.append(nose_door_node)


## THE NOSE LEG'S SWING, from its raked-forward down pose to lying forward in its bay, about the pivot's x axis.
static func _nose_swing() -> float:
	var down := Vector2(NOSE_AXLE.x - NOSE_PIVOT.x, NOSE_AXLE.y - NOSE_PIVOT.y)  # (up, aft)
	# In the model frame aft is +z, so the pivot-to-axle vector is (y, z) = (down.x, down.y) and forward is -z.
	var from: float = atan2(down.y, down.x)
	var to: float = atan2(NOSE_UP.z, NOSE_UP.y)
	return wrapf(to - from, -PI, PI)


## THE MAIN LEG'S RETRACTION as one rotation about its pivot: the leg from its splayed down pose to lying aft along the
## duct, and the wheel's axle from outboard to vertical, so the wheel lies flat [JB].
static func _main_retraction(side: float) -> Quaternion:
	var leg_down: Vector3 = Vector3(side * (MAIN_KNEE.x - MAIN_PIVOT.x), MAIN_KNEE.y - MAIN_PIVOT.y,
		MAIN_KNEE.z - MAIN_PIVOT.z).normalized()
	var axle_down := Vector3(side, 0.0, 0.0)
	var leg_up := Vector3(0.0, 0.0, 1.0)
	var axle_up := Vector3.UP
	var down := _frame(leg_down, axle_down)
	var up := _frame(leg_up, axle_up)
	return Quaternion((up * down.transposed()).orthonormalized())


static func _frame(leg: Vector3, axle: Vector3) -> Basis:
	var e1: Vector3 = leg.normalized()
	var e2: Vector3 = (axle - e1 * axle.dot(e1)).normalized()
	return Basis(e1, e2, e1.cross(e2))


func _build_hook(paint: Material) -> void:
	var tool := _tool()
	var tip := Vector3(0.0, HOOK_STOWED_RISE, HOOK_LENGTH)
	_rod(tool, Vector3.ZERO, tip, 0.045, FRAME)
	# The shoe: a black and white point turned down [HARV].
	var shoe: Array[Vector3] = _hook_shoe_corners()
	_box(tool, (shoe[0] + shoe[7]) * 0.5, shoe[7] - shoe[0], DARK)
	_box(tool, tip + Vector3(0.0, 0.0, -0.18), Vector3(0.10, 0.10, 0.20), GEAR_WHITE)
	var pivot := Vector3(0.0, height(HOOK_PIVOT.x), station(HOOK_PIVOT.y))
	_hook = _add(exterior, "Hook", tool, paint, true, pivot)


## ---- shapes -------------------------------------------------------------------------------------------------------

## A SLAB OVER A PLAN PATCH: `point.call(x, c, face)` gives the surface, and the patch from `x0` to `x1` and chord `c0`
## to `c1` is closed with its four edges. Split at 45% of the chord so the ridge is drawn. Flat-shaded.
func _slab(tool: SurfaceTool, point: Callable, x0: float, x1: float, c0: float, c1: float, label: String, side: float) -> void:
	_slab_about(tool, point, x0, x1, c0, c1, label, Vector3.UP, Vector3(side, 0.0, 0.0))


func _slab_about(tool: SurfaceTool, point: Callable, x0: float, x1: float, c0: float, c1: float, label: String,
		top: Vector3, outward: Vector3) -> void:
	var cuts: Array[float] = [c0]
	if c0 < 0.45 and c1 > 0.45:
		cuts.append(0.45)
	cuts.append(c1)
	var box := AABB()
	var found := false
	for i in range(cuts.size() - 1):
		var a: float = cuts[i]
		var b: float = cuts[i + 1]
		for face in [1.0, -1.0]:
			var p: Array[Vector3] = [point.call(x0, a, face), point.call(x1, a, face), point.call(x1, b, face),
				point.call(x0, b, face)]
			_quad(tool, p[0], p[1], p[2], p[3], top * face, UPPER if face > 0.0 else LOWER)
			for corner in p:
				box = box.expand(corner) if found else AABB(corner, Vector3.ZERO)
				found = true
		# The inboard and outboard edges.
		_quad(tool, point.call(x0, a, 1.0), point.call(x0, b, 1.0), point.call(x0, b, -1.0), point.call(x0, a, -1.0),
			-outward, LOWER)
		_quad(tool, point.call(x1, a, 1.0), point.call(x1, b, 1.0), point.call(x1, b, -1.0), point.call(x1, a, -1.0),
			outward, LOWER)
	_quad(tool, point.call(x0, c0, 1.0), point.call(x1, c0, 1.0), point.call(x1, c0, -1.0), point.call(x0, c0, -1.0),
		Vector3.FORWARD, LOWER)
	_quad(tool, point.call(x0, c1, 1.0), point.call(x1, c1, 1.0), point.call(x1, c1, -1.0), point.call(x0, c1, -1.0),
		Vector3.BACK, LOWER)
	surfaces[label] = box


## A ROD from `a` to `b`, six-sided.
func _rod(tool: SurfaceTool, a: Vector3, b: Vector3, radius: float, tint: Color) -> void:
	const SIDES := 6
	var along: Vector3 = (b - a).normalized()
	var across: Vector3 = along.cross(Vector3.FORWARD if absf(along.y) > 0.9 or absf(along.x) > 0.9 else Vector3.UP)
	if across.length_squared() < 1e-6:
		across = along.cross(Vector3.RIGHT)
	across = across.normalized()
	var other: Vector3 = along.cross(across)
	for k in range(SIDES):
		var t0: float = TAU * float(k) / SIDES
		var t1: float = TAU * float(k + 1) / SIDES
		var r0: Vector3 = (across * cos(t0) + other * sin(t0)) * radius
		var r1: Vector3 = (across * cos(t1) + other * sin(t1)) * radius
		_quad(tool, a + r0, a + r1, b + r1, b + r0, r0 + r1, tint)
	for k in range(SIDES):
		var t0: float = TAU * float(k) / SIDES
		var t1: float = TAU * float(k + 1) / SIDES
		var r0: Vector3 = (across * cos(t0) + other * sin(t0)) * radius
		var r1: Vector3 = (across * cos(t1) + other * sin(t1)) * radius
		_tri(tool, b, b + r0, b + r1, along, tint)
		_tri(tool, a, a + r0, a + r1, -along, tint)


## A WHEEL on an axle along x: a tyre band and two hubs, ten-sided. A vertex sits at the top and at the bottom, so a
## ten-sided tyre still stands exactly its own diameter tall.
func _wheel(tool: SurfaceTool, centre: Vector3, radius: float, wide: float) -> void:
	const SIDES := 10
	for k in range(SIDES):
		var t0: float = TAU * float(k) / SIDES
		var t1: float = TAU * float(k + 1) / SIDES
		var r0 := Vector3(0.0, cos(t0), sin(t0)) * radius
		var r1 := Vector3(0.0, cos(t1), sin(t1)) * radius
		var h := Vector3(wide * 0.5, 0.0, 0.0)
		_quad(tool, centre - h + r0, centre - h + r1, centre + h + r1, centre + h + r0, r0 + r1, TYRE)
		for face in [1.0, -1.0]:
			var hub: Vector3 = centre + h * face
			_tri(tool, hub, hub + r0 * 0.62, hub + r1 * 0.62, Vector3(face, 0.0, 0.0), GEAR_WHITE)
			_quad(tool, hub + r0 * 0.62, hub + r1 * 0.62, hub + r1, hub + r0, Vector3(face, 0.0, 0.0), TYRE)


func _box(tool: SurfaceTool, at: Vector3, size: Vector3, tint: Color, turn: Basis = Basis.IDENTITY) -> void:
	var half: Vector3 = size * 0.5
	for axis in range(3):
		for sign in [1.0, -1.0]:
			var n := Vector3.ZERO
			n[axis] = sign
			var u := Vector3.ZERO
			u[(axis + 1) % 3] = 1.0
			var v := Vector3.ZERO
			v[(axis + 2) % 3] = 1.0
			var c: Vector3 = n * half[axis]
			var du: Vector3 = u * half[(axis + 1) % 3]
			var dv: Vector3 = v * half[(axis + 2) % 3]
			_quad(tool, at + turn * (c - du - dv), at + turn * (c + du - dv), at + turn * (c + du + dv),
				at + turn * (c - du + dv), turn * n, tint)


## A QUAD from four corners in order round it, wound to face `out`.
func _quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, out: Vector3, tint: Color) -> void:
	_tri(tool, a, b, c, out, tint)
	_tri(tool, a, c, d, out, tint)


## ONE TRIANGLE, wound clockwise as seen from `out` -- Godot's front face -- or skipped if it has no area.
func _tri(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, out: Vector3, tint: Color) -> void:
	var normal: Vector3 = (c - a).cross(b - a)
	if normal.length_squared() < 1e-12:
		return
	if normal.dot(out) < 0.0:
		var swap: Vector3 = b
		b = c
		c = swap
	tool.set_color(tint)
	tool.add_vertex(a)
	tool.set_color(tint)
	tool.add_vertex(b)
	tool.set_color(tint)
	tool.add_vertex(c)


func _record(label: String, rings: Array) -> void:
	var box := AABB()
	var found := false
	for ring in rings:
		for corner in ring:
			box = box.expand(corner) if found else AABB(corner, Vector3.ZERO)
			found = true
	surfaces[label] = box


## A SURFACE TOOL WHOSE EVERY FACE IS FLAT: smooth group -1 is Godot's "do not smooth this vertex with its neighbours",
## so `generate_normals` gives each triangle its own normal and every crease stays a crease.
## https://docs.godotengine.org/en/stable/classes/class_surfacetool.html
func _tool() -> SurfaceTool:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_smooth_group(-1)
	return tool


func _add(parent: Node3D, label: String, tool: SurfaceTool, material: Material, detail: bool,
		at: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	tool.generate_normals()
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = tool.commit()
	node.material_override = material
	node.position = at
	if detail:
		node.visibility_range_end = DETAIL_RANGE
		node.visibility_range_end_margin = DETAIL_HYSTERESIS
		node.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	parent.add_child(node)
	return node


func _paint(double_sided: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.62
	material.metallic = 0.12
	if double_sided:
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material
