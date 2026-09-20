@tool
extends Node3D
class_name WarbirdAirframe
## WHAT EVERY PISTON WARBIRD'S AIRFRAME SHARES: the P-51D, the P-47D, the P-38L and the B-17G are each a class of their
## own (`P51Airframe` and the rest) that holds its measured tables and builds its own parts, and this is the kit they are
## built with -- the craft frame, the loft and slab builders, hinges, gear legs and doors in sequence, propellers that
## turn, and the setters and `features()` a VAT is baked from.
##
## THE DECISION: A BASE CLASS OF TOOLS, NOT ONE TABLE-DRIVEN BUILDER. The liners' three aeroplanes are one builder and
## three tables (`JetlinerAirframe`), because a 737, a 747 and a C-130 are the same shapes at other sizes. These four are
## not: a single-engined fighter with a belly scoop, a twin-boomed fighter with a nacelle, and a four-engined bomber with
## five turrets share their wheels, doors, hinges and propellers and almost nothing else. So what they share lives here,
## once, and what makes each itself lives in its own class. It is `WarthogAirframe`'s method (lane/warthog), lifted out
## so that four aeroplanes do not carry four copies of it.
##
## PRESENTATION ONLY. The native simulation owns the size, the flight, the collision, the stations and the wire. Until a
## warbird has a kind of its own it dresses from a DRAFT geometry its class works out from its drawing (`draft()`).
##
## CONVENTIONS, every warbird: STATIONS are metres aft of the spinner's tip; HEIGHTS are metres over the thrust line (the
## propeller's axis, which each class states against its drawing's reference line); OUT is metres to starboard. `point`
## turns those into the craft's frame, with the ground under the main tyres on the box's bottom face.
##
## TESSELLATION: every face carries its own normal and nothing is smoothed (`modelling_here.md` section 4). Each class
## states its own segment counts in its doc block.

## The paint every warbird is drawn in: NATURAL METAL, the bare aluminium most of them flew in by 1944-45, with an olive
## drab anti-glare panel ahead of the pilot (sRGB approximations, ESTIMATE). A model here carries no markings.
const METAL := Color(0.70, 0.72, 0.74)
const METAL_UNDER := Color(0.62, 0.64, 0.66)
const OLIVE := Color(0.25, 0.26, 0.19)
const GLASS := Color(0.40, 0.46, 0.50)
const BLACK := Color(0.04, 0.04, 0.045)
const DARK := Color(0.12, 0.12, 0.13)
const GUNMETAL := Color(0.16, 0.16, 0.17)
const WELL := Color(0.52, 0.55, 0.40)      # zinc-chromate green inside the wheel wells
const GEAR_METAL := Color(0.58, 0.60, 0.62)
const TYRE_BLACK := Color(0.06, 0.06, 0.06)
const PROP_BLACK := Color(0.07, 0.07, 0.075)
const PROP_TIP := Color(0.85, 0.72, 0.10)   # the yellow blade tips every USAAF propeller carried, a safety marking
const COAMING := Color(0.10, 0.11, 0.12)     # the glare shield and the panel's back, flat black (`_coaming`)

## THE GEAR CYCLE AS SHARES OF ONE AMOUNT, 0 up and 1 down, lane/lightning's and the A-10's: the doors that close over a
## stowed wheel open over the first fifth, the legs travel over the middle three, and those doors shut over the last.
## Read backwards the same function retracts in the same order.
const DOORS_OPEN_BY: float = 0.2
const DOORS_SHUT_FROM: float = 0.8
## HOW LONG A WHOLE GEAR CYCLE IS DRAWN TAKING, seconds. ESTIMATE: the user's word on actuators is that the time "isn't
## important right now, we just need to be able to adjust it" (2026-09-17).
const GEAR_SECONDS: float = 8.0
## How far a door's shut face stands inside the skin it closes, so a shut door never shows through it.
const DOOR_DROP: float = 0.012
## Small fittings stop drawing once the aeroplane is a few pixels high.
const DETAIL_RANGE: float = 600.0
const DETAIL_HYSTERESIS: float = 60.0
## THE WORST A VAT MAY PUT A PROPELLER'S VERTEX OFF ITS PART, metres: the sample count of the `props` feature is worked out
## from it (`_prop_samples`), since the error is the sag of the hub's own circle between two samples.
const PROP_VAT_ERROR: float = 0.0004

var _half: Vector3 = Vector3.ONE
var _span: float = 1.0
var _hinges: Dictionary = {}
var _gear: float = 1.0
var _pitch: float = 0.0
var _roll: float = 0.0
var _yaw: float = 0.0
var _flaps: float = 0.0
var _prop: float = 0.0
## The legs, each a pivot node, with its turn from down to stowed and the share of the legs' travel it moves over.
var _legs: Array[Node3D] = []
var _stowed: Array[Quaternion] = []
## Doors on hinges: [name, open angle, how] -- `&"transit"` opens for the legs to pass and shuts behind them at both
## ends; `&"down"` opens as the gear comes down and stays open while it is down (the tail wheel's).
var _doors: Array = []
## The propellers: [spin node, +1 or -1 for which way it turns as seen from behind, blades].
var _props: Array = []
## Telescoping legs' lower halves: [slide node, the unit direction from the axle up the leg in the pivot's frame, how
## far it closes up with the gear up]. The P-47's mains shorten 9 in as they fold (`_leg`'s `telescope`).
var _slides: Array = []

## THE HINGED SURFACES' TRAVELS, radians, each class's own: the ailerons each way, the elevators up and down, the
## rudders each way, the flaps down.
var aileron_travel: float = deg_to_rad(15.0)
var elevator_up: float = deg_to_rad(30.0)
var elevator_down: float = deg_to_rad(20.0)
var rudder_travel: float = deg_to_rad(30.0)
var flap_travel: float = deg_to_rad(45.0)


# ---- the frame, each class's own -----------------------------------------------------------------------------------

## THE HEIGHT OF THE GROUND under the main tyres, over the thrust line: where the box's bottom face is.
func ground_height() -> float:
	return -2.0


## THE AEROPLANE PARKED: the transform that stands the level-built frame on its gear on level ground. A tricycle stands
## as built. A TAILDRAGGER overrides it with `_three_point`: tail down on its tail wheel, the real way. Built level
## and pictured so, the P-51 sat on its mains with the tail wheel in the air, and read as floating (team-lead,
## 2026-09-19).
func parked() -> Transform3D:
	return Transform3D.IDENTITY


## THE THREE-POINT STANCE from the main and tail axles, each as (station, height), and their tyres' radii. The frame
## is turned nose up about the main axle until the lower common tangent of the two tyres lies level. A tyre turned
## about its own axle keeps its bottom, so the main tyres stay on the box's floor and the tail wheel comes down onto it.
## BUT A TYRE IS `sides` FACETS with a flat at the bottom, and turned, a corner comes round below the flat's line: the
## P-51's main by 1.6 cm and the P-47's by 2.0 at their rakes. So the frame is lifted by the deeper of the two corners,
## and the other tyre stands that much less a centimetre off the floor.
func _three_point(main: Vector2, main_radius: float, tail: Vector2, tail_radius: float, sides: int = 10) -> Transform3D:
	var apart: Vector2 = tail - main
	var rake: float = atan2(apart.y, apart.x) + asin((main_radius - tail_radius) / apart.length())
	var axle: Vector3 = point(0.0, main.y, main.x)
	var turn := Basis(Vector3.RIGHT, rake)
	var half_facet: float = PI / float(sides)
	var off: float = absf(fposmod(rake + half_facet * 2.0, half_facet * 2.0) - half_facet)
	var corner: float = cos(off) / cos(half_facet) - 1.0
	var lift: float = maxf(main_radius, tail_radius) * corner
	return Transform3D(turn, axle - turn * axle + Vector3.UP * lift)


## THE DRAFT GEOMETRY while the warbird has no kind: {"extents": half box, "span": metres}.
##
## MIND THE SPAN'S CONVENTION, WHICH IS NOT THE KIND'S. A draft says the WHOLE span, as an aeroplane's dimensions are
## printed; `Shape::span`, which `Sim.geometry_of` hands back, is the SEMI-span (`cockpit_world.cpp` places a flying
## boat's wing floats at 0.79 of it, one a side). So `_take` reads a number twice the size when it falls back to the
## draft, and `tests/p47.gd` holds the two together with the factor written down. A warbird with a kind never reaches
## this.
func draft() -> Dictionary:
	return {"extents": Vector3.ONE, "span": 1.0}


## A POINT: `out` metres to starboard, `station` aft of the spinner's tip and `high` over the thrust line, in the craft's
## frame: the spinner's tip at the box's front face and the ground under the main tyres at its bottom.
func point(out: float, high: float, station: float) -> Vector3:
	return Vector3(out, -_half.y + high - ground_height(), -_half.z + station)


## THE KIND THIS AIRFRAME DRAWS, or -1 while it has none and dresses from its `draft()` (lane/warbirds2). A class whose
## kind exists answers it, and its box is then the simulation's and nobody's copy of it.
func kind_id() -> int:
	return -1


## The simulation's geometry: handed in, or the kind's, or the draft until the kind exists.
func _take(geometry: Dictionary) -> void:
	var native: Dictionary = geometry
	if not native.has("extents"):
		native = Sim.geometry_of(kind_id()) if kind_id() >= 0 else draft()
	_half = native["extents"] as Vector3
	_span = float(native["span"])


# ---- the cockpit, each class's own numbers -----------------------------------------------------------------------------
# The warthog lane's checks (`tests/warthog.gd`), lifted into the kit so every warbird's seat is held the same way: the eye
# sees over the nose, the room it promises is inside the drawn skin, and a coaming closes the hollow nose off from the eye.

## THE PILOT'S EYE, (station, height over the thrust line); Vector2.ZERO for an airframe with no seat of its own yet.
func eye_at() -> Vector2:
	return Vector2.ZERO


## THE ROOM a crew is promised round the eye, as (out, height over the thrust line, station) corners.
func room() -> AABB:
	return AABB()


## THE INSTRUMENT PANEL'S STATION, a ring station, where the coaming ends; 0 for none.
func panel_station() -> float:
	return 0.0


## THE FUSELAGE'S RINGS and one ring's half-section, (half-width, height) from the top centreline down to the keel, and
## which point of it is the canopy's sill: what the skin is lofted from, so `skin_out_at` and `_coaming` read the very
## triangles `_fuselage` draws.
func ring_stations() -> Array:
	return []


func section_at(_s: float) -> Array:
	return []


func sill_index() -> int:
	return 0


## THE WINDSCREEN'S FOOT, a station: where the glass meets the nose's top.
func windscreen_foot() -> float:
	return 0.0


## THE TYRES' BOTTOMS, craft-local, gear down, each under its axle: what the simulation's resting aeroplane is held to
## (`tests/taildragger.gd`). Empty for an airframe with no kind.
func wheel_contacts() -> Array:
	return []


## THE PILOT'S EYE, craft-local.
func eye() -> Vector3:
	return point(0.0, eye_at().y, eye_at().x)


## The seat under that eye, as a height over the thrust line.
func seat_height() -> float:
	return eye_at().y - CockpitStation.EYE_HEIGHT


## THE ROOM A CREW SITS IN, in the shape `VehicleView.cabin_room()` asks for.
func cabin_room() -> Dictionary:
	var r: AABB = room()
	var low: Vector3 = point(r.position.x, r.position.y, r.position.z)
	var high: Vector3 = point(r.end.x, r.end.y, r.end.z)
	return {
		"drawn": true,
		"floor": point(0.0, seat_height() + 0.04, eye_at().x).y,
		"room": AABB(low, high - low).abs(),
		"because": &"",
		"why_not": "",
		"source": "the eye under the drawn canopy, ESTIMATE; the seat EYE_HEIGHT under it; the room MEASURED against the skin",
	}


## WHETHER A BOX, craft-local, IS INSIDE THE DRAWN FUSELAGE, the canopy counted in: every corner no further out than the
## skin at its station and height, a centimetre kept for the skin. Asked by `VehicleView.holster_fits`.
func encloses(box: AABB) -> bool:
	var rings: Array = ring_stations()
	if rings.is_empty():
		return false
	for corner in range(8):
		var p: Vector3 = box.get_endpoint(corner)
		var s: float = p.z + _half.z
		if s < float(rings[0]) or s > float(rings[-1]):
			return false
		if absf(p.x) > skin_out_at(s, p.y + _half.y + ground_height(), p.x < 0.0) - 0.01:
			return false
	return true


## THE SKIN'S HALF-WIDTH at station `s` and `high` over the thrust line, on the `port` side or starboard, off the very
## triangles `_quad` draws between the rings either side (each quad cut corner to corner the way `_quad` cuts it); 0 above
## or below it. The warthog's (`WarthogAirframe.skin_out_at`), read through `section_at`.
func skin_out_at(s: float, high: float, port: bool = false) -> float:
	var rings: Array = ring_stations()
	var i: int = 0
	while i < rings.size() - 2 and s > float(rings[i + 1]):
		i += 1
	var fore: Array = section_at(float(rings[i]))
	var aft: Array = section_at(float(rings[i + 1]))
	var at := Vector2(s, high)
	for k in range(fore.size() - 1):
		var a0 := Vector3(float(rings[i]), (fore[k] as Vector2).y, (fore[k] as Vector2).x)
		var a1 := Vector3(float(rings[i]), (fore[k + 1] as Vector2).y, (fore[k + 1] as Vector2).x)
		var b0 := Vector3(float(rings[i + 1]), (aft[k] as Vector2).y, (aft[k] as Vector2).x)
		var b1 := Vector3(float(rings[i + 1]), (aft[k + 1] as Vector2).y, (aft[k + 1] as Vector2).x)
		# Starboard, `_quad` cuts from the upper point fore to the lower aft; port, where the ring is walked back up, from
		# the lower point fore to the upper aft.
		var cut: Array = [[a1, a0, b0], [a1, b0, b1]] if port else [[a0, a1, b1], [a0, b1, b0]]
		for triangle in cut:
			var p: Vector3 = triangle[0]
			var q: Vector3 = triangle[1]
			var r: Vector3 = triangle[2]
			var area: float = (q.x - p.x) * (r.y - p.y) - (r.x - p.x) * (q.y - p.y)
			if absf(area) < 1e-9:
				continue
			var u: float = ((q.x - at.x) * (r.y - at.y) - (r.x - at.x) * (q.y - at.y)) / area
			var v: float = ((r.x - at.x) * (p.y - at.y) - (p.x - at.x) * (r.y - at.y)) / area
			var w: float = 1.0 - u - v
			if u >= -1e-6 and v >= -1e-6 and w >= -1e-6:
				return u * p.z + v * q.z + w * r.z
	return 0.0


## THE COAMING, the warthog's (lane/warthog): the glare shield's deck across between the canopy's sills from the
## windscreen's foot aft to the panel, facing up; the panel, the ring's section below the sills closed across, facing aft;
## and the lip at the windscreen's foot. WHY: the canopy is the fuselage's second surface, one closed solid with the nose,
## and without it the eye looked down past the windscreen's foot into the hollow nose. A PART OF ITS OWN, so the
## fuselage's solid is still closed for ray parity.
func _coaming(tool: SurfaceTool) -> void:
	var foot: float = windscreen_foot()
	var panel: float = panel_station()
	var sill: int = sill_index()
	var stations: Array = []
	for s in ring_stations():
		if float(s) >= foot - 0.001 and float(s) <= panel + 0.001:
			stations.append(float(s))
	for i in range(stations.size() - 1):
		var a: Vector2 = section_at(stations[i])[sill]
		var b: Vector2 = section_at(stations[i + 1])[sill]
		var quad: Array = [point(-a.x, a.y, stations[i]), point(a.x, a.y, stations[i]), point(b.x, b.y, stations[i + 1]),
			point(-b.x, b.y, stations[i + 1])]
		_fan(tool, quad[0], quad[1], quad[2], Vector3.UP, COAMING)
		_fan(tool, quad[0], quad[2], quad[3], Vector3.UP, COAMING)
	var half: Array = section_at(panel)
	var outline: Array = []
	for i in range(sill, half.size()):
		outline.append(point((half[i] as Vector2).x, (half[i] as Vector2).y, panel))
	for i in range(half.size() - 2, sill - 1, -1):
		outline.append(point(-(half[i] as Vector2).x, (half[i] as Vector2).y, panel))
	var middle: Vector3 = point(0.0, ((half[sill] as Vector2).y + (half[-1] as Vector2).y) * 0.5, panel)
	for i in range(outline.size()):
		_fan(tool, middle, outline[i], outline[(i + 1) % outline.size()], Vector3.BACK, COAMING)
	var at_foot: Array = section_at(foot)
	var lip: Array = []
	for i in range(sill + 1):
		lip.append(point((at_foot[i] as Vector2).x, (at_foot[i] as Vector2).y, foot))
	for i in range(sill, 0, -1):
		lip.append(point(-(at_foot[i] as Vector2).x, (at_foot[i] as Vector2).y, foot))
	var lip_middle: Vector3 = point(0.0, ((at_foot[0] as Vector2).y + (at_foot[sill] as Vector2).y) * 0.5, foot)
	for i in range(lip.size()):
		_fan(tool, lip_middle, lip[i], lip[(i + 1) % lip.size()], Vector3.BACK, COAMING)


func geometry() -> Dictionary:
	return {"extents": _half, "span": _span}


# ---- what moves ----------------------------------------------------------------------------------------------------

## THE GEAR, 0 up and 1 down, IN SEQUENCE: the doors that close over the stowed wheels open, the legs travel, those doors
## shut again; a tail wheel's doors open as it comes down and stay open.
func set_gear(amount: float) -> void:
	_gear = clampf(amount, 0.0, 1.0)
	var legs: float = legs_down(_gear)
	for index in range(_legs.size()):
		_legs[index].basis = Basis(Quaternion.IDENTITY.slerp(_stowed[index], 1.0 - legs))
	for slide in _slides:
		(slide[0] as Node3D).position = (slide[1] as Vector3) * float(slide[2]) * (1.0 - legs)
	for door in _doors:
		var open: float = transit_doors_open(_gear) if door[2] == &"transit" else down_doors_open(_gear)
		_turn(String(door[0]), open * float(door[1]))


func gear() -> float:
	return _gear


## HOW FAR DOWN THE LEGS ARE at a gear amount: still over the doors' shares, eased over the middle.
static func legs_down(amount: float) -> float:
	return smoothstep(DOORS_OPEN_BY, DOORS_SHUT_FROM, amount)


## HOW OPEN THE DOORS OVER A STOWED WHEEL ARE: opening over the first share, open, shutting over the last.
static func transit_doors_open(amount: float) -> float:
	if amount <= DOORS_OPEN_BY:
		return smoothstep(0.0, DOORS_OPEN_BY, amount)
	if amount >= DOORS_SHUT_FROM:
		return 1.0 - smoothstep(DOORS_SHUT_FROM, 1.0, amount)
	return 1.0


## HOW OPEN A DOOR THAT STAYS OPEN WITH THE GEAR DOWN IS: it opens over the first share and stays open.
static func down_doors_open(amount: float) -> float:
	return smoothstep(0.0, DOORS_OPEN_BY, amount)


## THE STICK'S AND PEDALS' SURFACES: `roll` -1 left wing down to +1 right, `pitch` -1 nose down to +1 nose up, `yaw` -1
## nose left to +1 nose right. Every warbird is flown by cables: one surface each, and nothing mixes.
func set_ailerons(roll: float) -> void:
	_roll = clampf(roll, -1.0, 1.0)
	# A positive turn is trailing edge DOWN: right roll raises the right aileron and lowers the left.
	_turn("AileronStarboard", -_roll * aileron_travel)
	_turn("AileronPort", _roll * aileron_travel)


func set_elevators(pitch: float) -> void:
	_pitch = clampf(pitch, -1.0, 1.0)
	# Nose up is trailing edge UP, through the elevators' UP travel; nose down through their DOWN travel.
	var angle: float = -_pitch * (elevator_up if _pitch > 0.0 else elevator_down)
	for named in ["ElevatorStarboard", "ElevatorPort"]:
		_turn(named, angle)


func set_rudders(yaw: float) -> void:
	_yaw = clampf(yaw, -1.0, 1.0)
	for named in ["Rudder", "RudderStarboard", "RudderPort"]:
		_turn(named, _yaw * rudder_travel)


## THE FLAPS, 0 up to 1 fully down. Every hinge whose name begins "Flap".
func set_flaps(amount: float) -> void:
	_flaps = clampf(amount, 0.0, 1.0)
	for named in _hinges:
		if String(named).begins_with("Flap"):
			_turn(String(named), _flaps * flap_travel)


## THE PROPELLERS, `phase` 0 to 1 is one blade's pitch -- a quarter turn for four blades -- which is the whole of a turn as
## far as identical blades can show, so a VAT bakes it in one blade's worth of rows and the view hands it the phase. Each
## turns its own way.
func set_props(phase: float) -> void:
	_prop = fposmod(phase, 1.0)
	for entry in _props:
		# A POSITIVE TURN ABOUT +z (aft) IS ANTICLOCKWISE SEEN FROM BEHIND, so a clockwise propeller turns negative.
		(entry[0] as Node3D).basis = Basis(Vector3.BACK, -float(entry[1]) * _prop * TAU / float(entry[2]))


func stick_roll() -> float:
	return _roll


func stick_pitch() -> float:
	return _pitch


func stick_yaw() -> float:
	return _yaw


func flaps() -> float:
	return _flaps


func props() -> float:
	return _prop


## THE FEATURES A VAT BAKES (`VatCasting`), each this airframe's own setter and getter. A class with more to move appends
## its own.
func features() -> Array:
	return [
		# 257 ROWS FOR THE GEAR: its doors swing through their whole travel in a fifth of it, and a door hinged 5 m from
		# the craft's origin sags 1.9 mm between two of 129 rows (the P-38's main doors, lane/warbirds).
		{"name": "gear", "set": set_gear, "get": gear, "low": 0.0, "high": 1.0, "samples": 257},
		{"name": "pitch", "set": set_elevators, "get": stick_pitch, "low": -1.0, "high": 1.0, "samples": 33},
		{"name": "roll", "set": set_ailerons, "get": stick_roll, "low": -1.0, "high": 1.0, "samples": 33},
		{"name": "rudder", "set": set_rudders, "get": stick_yaw, "low": -1.0, "high": 1.0, "samples": 33},
		{"name": "flaps", "set": set_flaps, "get": flaps, "low": 0.0, "high": 1.0, "samples": 33},
		{"name": "props", "set": set_props, "get": props, "low": 0.0, "high": 1.0, "samples": _prop_samples()},
	]


## HOW MANY ROWS THE PROPELLERS' FEATURE NEEDS: a VAT blends two samples' offsets in a straight line, so a hub `r` metres
## from the craft's origin is drawn on the chord of its own circle between them, `r (1 - cos(step / 2))` off. The rows are
## as many as keep that under `PROP_VAT_ERROR` for the furthest hub (lane/warbirds: 17 rows put a P-51's blades 5 mm off).
func _prop_samples() -> int:
	var furthest: float = 0.0
	var pitch: float = TAU
	for entry in _props:
		furthest = maxf(furthest, (entry[0] as Node3D).position.length())
		pitch = minf(pitch, TAU / float(entry[2]))
	if furthest <= 0.0:
		return 17
	var step: float = 2.0 * acos(1.0 - PROP_VAT_ERROR / furthest)
	return clampi(int(ceil(pitch / step)) + 1, 17, 257)


## A HINGE turned `angle` radians from where it was built, about the axis stored on it when it was built.
func _turn(named: String, angle: float) -> void:
	var hinge: Node3D = _hinges.get(named) as Node3D
	if hinge != null:
		hinge.basis = Basis(hinge.get_meta("axis") as Vector3, angle)


## A HINGE at `at` (in `parent`'s frame), turning about `along`, wound so a small positive turn carries `probe` towards
## `wanted` (a direction): the Tomcat's way, so the builder never reasons about which way a mirrored hinge turns.
func _hinge(named: String, parent: Node3D, at: Vector3, along: Vector3, probe: Vector3, wanted: Vector3) -> Node3D:
	var hinge := Node3D.new()
	# "HINGE" ON THE END, so a hinge is never found in place of the part it carries (lane/tomcat2).
	hinge.name = named + "Hinge"
	hinge.position = at
	var axis: Vector3 = along.normalized()
	if axis.cross(probe - at).dot(wanted) < 0.0:
		axis = -axis
	hinge.set_meta("axis", axis)
	parent.add_child(hinge)
	_hinges[named] = hinge
	return hinge


# ---- building --------------------------------------------------------------------------------------------------------

static func _tool() -> SurfaceTool:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	return tool


static func _add(parent: Node3D, title: String, tool: SurfaceTool, material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = title
	mesh.mesh = Plating.weld(tool)
	mesh.material_override = material
	parent.add_child(mesh)
	return mesh


## A fitting that stops drawing at range.
static func _small(mesh: MeshInstance3D) -> MeshInstance3D:
	mesh.visibility_range_end = DETAIL_RANGE
	mesh.visibility_range_end_margin = DETAIL_HYSTERESIS
	mesh.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	return mesh


## The natural metal the body is drawn in, its colour in its vertices.
static func _paint() -> StandardMaterial3D:
	var paint: StandardMaterial3D = ShipHull.painted()
	paint.roughness = 0.45
	paint.metallic = 0.35
	return paint


## THE CANOPY'S GLASS: drawn from both sides and mostly see-through, as the A-10's is (0.30; at 0.45 the station's picture
## was the whole world through a grey film, lane/warthog).
static func _glass() -> StandardMaterial3D:
	var glass := StandardMaterial3D.new()
	glass.vertex_color_use_as_albedo = true
	glass.vertex_color_is_srgb = true
	glass.albedo_color = Color(1.0, 1.0, 1.0, 0.28)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	glass.roughness = 0.08
	glass.metallic = 0.35
	return glass


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


## A QUAD as two triangles, each wound out along `out` on its own: a quad between two rings is not always flat, and one
## normal for both halves wound one of them inwards (lane/warthog).
static func _quad(tool: SurfaceTool, quad: Array, out: Vector3, tint: Color) -> void:
	_fan(tool, quad[0], quad[1], quad[2], out, tint)
	_fan(tool, quad[0], quad[2], quad[3], out, tint)


## A LOFT through matching loops, each quad facing away from its own loops' middle, both ends closed by fans unless
## `close` is false.
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
			_quad(tool, quad, mid - mid_centre, tints[k % tints.size()])
	if not close:
		return
	for end in [0, loops.size() - 1]:
		var along: Vector3 = (centres[end] as Vector3) - centres[1 if end == 0 else loops.size() - 2]
		var loop: Array = loops[end]
		for k in range(n):
			_fan(tool, centres[end], loop[k], loop[(k + 1) % n], along, tints[k % tints.size()])


## A FLAT SLAB from a 2D outline: `place` turns an outline point into its middle-surface position, `across` is the slab's
## normal and `half` its half-thickness. The engine's ear clipper triangulates both faces, so a concave outline is right.
static func _slab(tool: SurfaceTool, outline: PackedVector2Array, place: Callable, across: Vector3, half: float,
		tint: Color, under_tint: Color = Color(-1, 0, 0)) -> void:
	var tris: PackedInt32Array = Geometry2D.triangulate_polygon(outline)
	var top: Array = []
	var under: Array = []
	for p in outline:
		top.append((place.call(p) as Vector3) + across * half)
		under.append((place.call(p) as Vector3) - across * half)
	var below: Color = tint if under_tint.r < 0.0 else under_tint
	for t in range(0, tris.size(), 3):
		_fan(tool, top[tris[t]], top[tris[t + 1]], top[tris[t + 2]], across, tint)
		_fan(tool, under[tris[t]], under[tris[t + 1]], under[tris[t + 2]], -across, below)
	var area: float = 0.0
	var n: int = outline.size()
	for i in range(n):
		area += outline[i].x * outline[(i + 1) % n].y - outline[(i + 1) % n].x * outline[i].y
	for i in range(n):
		var a2: Vector2 = outline[i]
		var b2: Vector2 = outline[(i + 1) % n]
		var edge: Vector2 = b2 - a2
		var out2: Vector2 = Vector2(edge.y, -edge.x) if area > 0.0 else Vector2(-edge.y, edge.x)
		var mid2: Vector2 = (a2 + b2) * 0.5
		var out3: Vector3 = (place.call(mid2 + out2.normalized() * 0.01) as Vector3) - (place.call(mid2) as Vector3)
		_quad(tool, [top[i], top[(i + 1) % n], under[(i + 1) % n], under[i]], out3, tint)


static func _outline(points: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(Vector2(float(p[0]), float(p[1])))
	return out


## ONE PROFILE, [[station, value], ...], read at `s` by straight lines between its rows.
static func _profile(rows: Array, s: float) -> float:
	for i in range(rows.size() - 1):
		var a: Array = rows[i]
		var b: Array = rows[i + 1]
		if s <= float(b[0]):
			return lerpf(float(a[1]), float(b[1]), clampf((s - float(a[0])) / (float(b[0]) - float(a[0])), 0.0, 1.0))
	return float(rows[-1][1])


## A RING of `sides` points round `centre` in the plane square to `axis`, radii `across` (sideways) and `up`, the first
## point half a facet off the top so a flat faces straight up and one straight down.
static func _ring(centre: Vector3, axis: Vector3, across: float, up: float, sides: int) -> Array:
	var z: Vector3 = axis.normalized()
	var side: Vector3 = Vector3.UP.cross(z)
	if side.length_squared() < 1e-6:
		side = Vector3.RIGHT
	side = side.normalized()
	var upward: Vector3 = z.cross(side).normalized()
	var loop: Array = []
	for k in range(sides):
		var t: float = TAU * (float(k) + 0.5) / float(sides)
		loop.append(centre + side * across * sin(t) + upward * up * cos(t))
	return loop


## A SPINNER: a cone of `sides` facets from its `tip` back to a ring of `radius` at `base`, and on through `rows` of
## [distance aft of the tip, radius] between. Closed behind.
static func _spinner(tool: SurfaceTool, tip: Vector3, base: Vector3, rows: Array, sides: int, tint: Color) -> void:
	var axis: Vector3 = (base - tip).normalized()
	var loops: Array = []
	for row in rows:
		loops.append(_ring(tip + axis * float(row[0]), axis, float(row[1]), float(row[1]), sides))
	for k in range(sides):
		_fan(tool, tip, loops[0][k], loops[0][(k + 1) % sides], -axis, tint)
	_loft(tool, loops, [tint], false)
	var back: Array = loops[-1]
	var centre: Vector3 = tip + axis * float(rows[-1][0])
	for k in range(sides):
		_fan(tool, centre, back[k], back[(k + 1) % sides], axis, tint)


## A PROPELLER of `blades` flat paddle blades on a node at `hub` (in the craft's frame) that `set_props` turns about the
## thrust line, `turns` +1 clockwise and -1 anticlockwise seen from behind. Each blade is a slab from its root to `radius`,
## its chord from `chords` [root, widest, tip] as the Hamilton Standard paddle blade is, twisted to `pitch` at its root and
## flattening outboard, the last 0.15 m painted yellow. Blade 0 stands straight up at phase 0.
func _propeller(named: String, hub: Vector3, radius: float, blades: int, chords: Vector3, pitch: float, turns: float,
		root: float, paint: Material) -> Node3D:
	var spin := Node3D.new()
	spin.name = named + "Spin"
	spin.position = hub
	add_child(spin)
	_props.append([spin, turns, blades])
	var tool := _tool()
	for b in range(blades):
		var around: float = TAU * float(b) / float(blades)
		var radial := Vector3(sin(around), cos(around), 0.0)
		var tangent := Vector3(cos(around), -sin(around), 0.0)
		# FOUR STATIONS ALONG THE BLADE: the root, the widest, where the yellow tip starts, and the tip.
		var along: Array = [root, lerpf(root, radius, 0.45), radius - 0.15, radius]
		var widths: Array = [chords.x, chords.y, lerpf(chords.y, chords.z, 0.8), chords.z]
		var twists: Array = [pitch, pitch * 0.55, pitch * 0.3, pitch * 0.25]
		for i in range(3):
			var loops: Array = []
			for j in [i, i + 1]:
				var r: float = float(along[j])
				var w: float = float(widths[j]) * 0.5
				var twist: float = float(twists[j]) * turns
				# The blade's face, its leading edge (the side it moves towards) turned forward by the twist.
				var face: Vector3 = (tangent * cos(twist) - Vector3.BACK * sin(twist)).normalized()
				var thick: Vector3 = radial.cross(face).normalized() * 0.018
				var c: Vector3 = radial * r
				loops.append([c + face * w + thick, c - face * w + thick, c - face * w - thick, c + face * w - thick])
			_loft(tool, loops, [PROP_TIP if i == 2 else PROP_BLACK], i == 0 or i == 2)
	_add(spin, named, tool, paint)
	return spin


## A DOOR: a flat plate on its own hinge along `hinge_a`..`hinge_b`, painted `outside` on the face that faces `out` when
## shut and the well's green inside. Recorded in `_doors` so `set_gear` turns it `open` radians `how` (see `_doors`).
func _door(named: String, corners: Array, hinge_a: Vector3, hinge_b: Vector3, opens_towards: Vector3, out: Vector3,
		open: float, how: StringName, outside: Color, paint: Material) -> Node3D:
	var mid: Vector3 = Vector3.ZERO
	for c in corners:
		mid += c
	mid /= float(corners.size())
	var at: Vector3 = (hinge_a + hinge_b) * 0.5
	var hinge := _hinge(named, self, at, hinge_b - hinge_a, mid, opens_towards)
	var tool := _tool()
	var thick: Vector3 = out.normalized() * 0.008
	var face: Array = []
	var back: Array = []
	for c in corners:
		face.append((c as Vector3) - at + thick)
		back.append((c as Vector3) - at - thick)
	var n: int = corners.size()
	var middle: Vector3 = mid - at
	for k in range(1, n - 1):
		_fan(tool, face[0], face[k], face[k + 1], out, outside)
		_fan(tool, back[0], back[k], back[k + 1], -out, WELL)
	for k in range(n):
		var k2: int = (k + 1) % n
		var edge_mid: Vector3 = ((face[k] as Vector3) + face[k2]) * 0.5
		_quad(tool, [face[k], face[k2], back[k2], back[k]], edge_mid - middle, outside)
	_add(hinge, named, tool, paint)
	_doors.append([named, open, how])
	return hinge


## ONE LEG: a pivot at `pivot` (craft frame), built with the axle down at `axle` and stowed by the turn that carries the
## axle to `stowed` -- by the shortest arc, or, given `lie`, by the turn that also brings the wheel's axle line (+x down)
## as near as it can to `lie`, so a wheel that must lie FLAT in its well does (lane/warbirds: the P-51's shortest arc
## left its wheel tilted 0.34 m deep in a root 0.25 m thick). `build` draws the leg's own meshes into a tool in the
## PIVOT's frame, given the axle there; the leg is one mesh, `named`, so it is one column of a VAT.
func _leg(named: String, pivot_at: Vector3, axle: Vector3, stowed: Vector3, build: Callable, paint: Material,
		lie: Vector3 = Vector3.ZERO) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = named + "Pivot"
	pivot.position = pivot_at
	add_child(pivot)
	_legs.append(pivot)
	if lie == Vector3.ZERO:
		_stowed.append(Quaternion((axle - pivot_at).normalized(), (stowed - pivot_at).normalized()))
	else:
		_stowed.append(turn_between(axle - pivot_at, Vector3.RIGHT, stowed - pivot_at, lie))
	var tool := _tool()
	build.call(tool, axle - pivot_at)
	_small(_add(pivot, named, tool, paint))
	return pivot


## A TELESCOPING LEG: `_leg`'s, but its lower half -- drawn by `lower` into its own mesh, `named` + "Wheel" -- slides
## `telescope` metres up the leg towards the pivot as the leg folds, so it stows that much shorter (the P-47's mains, 9 in,
## Wikipedia after Friedman). `stowed` is where the SHORTENED leg puts the axle. Both halves are moved by the gear alone,
## the lower through its slide and the pivot's turn together, so a VAT bakes them as one feature.
func _telescoping_leg(named: String, pivot_at: Vector3, axle: Vector3, stowed: Vector3, telescope: float, upper: Callable,
		lower: Callable, paint: Material, lie: Vector3 = Vector3.ZERO) -> Node3D:
	var reach: float = (axle - pivot_at).length()
	# The turn is the one that carries the full-length axle's DIRECTION onto the stowed axle's; the slide does the rest.
	var pivot := _leg(named, pivot_at, axle, pivot_at + (stowed - pivot_at).normalized() * reach, upper, paint, lie)
	var slide := Node3D.new()
	slide.name = named + "Slide"
	pivot.add_child(slide)
	_slides.append([slide, -(axle - pivot_at).normalized(), telescope])
	var tool := _tool()
	lower.call(tool, axle - pivot_at)
	_small(_add(slide, named + "Wheel", tool, paint))
	return pivot


## THE TURN THAT CARRIES `v` ONTO `w` and, as nearly as that allows, `a` onto `b`: the two frames each pair makes, one
## taken to the other. `v` lands exactly; `a` lands on `b`'s part square to `w`.
static func turn_between(v: Vector3, a: Vector3, w: Vector3, b: Vector3) -> Quaternion:
	var v1: Vector3 = v.normalized()
	var w1: Vector3 = w.normalized()
	var a1: Vector3 = (a - v1 * a.dot(v1)).normalized()
	var b1: Vector3 = (b - w1 * b.dot(w1)).normalized()
	var from := Basis(v1, a1, v1.cross(a1))
	var to := Basis(w1, b1, w1.cross(b1))
	return (to * from.inverse()).get_rotation_quaternion()


## A TYRE on an axle across `across`, `diameter` over its tread and `width` wide, `sides` flats round, with a hub in the
## gear's metal: an N-sided prism whose bottom FLAT stands on the ground when the axle is level.
static func _tyre(tool: SurfaceTool, centre: Vector3, across: Vector3, diameter: float, width: float, sides: int) -> void:
	var axis: Vector3 = across.normalized()
	var apothem: float = diameter * 0.5
	var corner: float = apothem / cos(PI / float(sides))
	var up: Vector3 = Vector3.UP if absf(axis.dot(Vector3.UP)) < 0.9 else Vector3.BACK
	var side: Vector3 = up.cross(axis).normalized()
	up = axis.cross(side).normalized()
	var loops: Array = []
	for w in [-width * 0.5, width * 0.5]:
		var loop: Array = []
		for k in range(sides):
			var t: float = TAU * (float(k) + 0.5) / float(sides)
			loop.append(centre + axis * w + up * corner * cos(t) + side * corner * sin(t))
		loops.append(loop)
	_loft(tool, loops, [TYRE_BLACK])
	# THE HUB: a small raised disc each side.
	for w in [-width * 0.5 - 0.01, width * 0.5 + 0.01]:
		var hub: Array = []
		for k in range(6):
			var t: float = TAU * (float(k) + 0.5) / 6.0
			hub.append(centre + axis * w + up * apothem * 0.42 * cos(t) + side * apothem * 0.42 * sin(t))
		for k in range(6):
			_fan(tool, centre + axis * w, hub[k], hub[(k + 1) % 6], axis * signf(w), GEAR_METAL)


## A STRUT: a square bar `half` across from `a` to `b`.
static func _strut(tool: SurfaceTool, a: Vector3, b: Vector3, half: float, tint: Color) -> void:
	var along: Vector3 = (b - a).normalized()
	var across: Vector3 = along.cross(Vector3.FORWARD)
	if across.length_squared() < 1e-6:
		across = along.cross(Vector3.RIGHT)
	across = across.normalized()
	var up: Vector3 = across.cross(along).normalized()
	var loops: Array = []
	for p in [a, b]:
		loops.append([p + across * half + up * half, p - across * half + up * half, p - across * half - up * half,
			p + across * half - up * half])
	_loft(tool, loops, [tint])
