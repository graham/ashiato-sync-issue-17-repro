extends Node3D
class_name ChinookAirframe
## A CH-47F CHINOOK, DRAWN: a long square-sided cargo fuselage with a blunt glazed nose, a forward pylon over the
## cockpit and a TALL AFT PYLON over the tail, each carrying a three-blade rotor -- counter-rotating and meshing, the
## rear one higher -- joined by the drive-shaft tunnel along the spine; the two engines on stubs either side of the aft
## pylon; long fuel sponsons down both sides; four wheels; a row of cabin windows; and the loading ramp at the back,
## hinged at the tail and worked from the bus. Presentation only: CockpitWorld owns collision, mass, seats, flight and
## replication.
##
## WHAT IT REPLACED, AND WHY (2026-09-17): a lofted oval with two plank rotors on posts, a rear rotor standing on EMPTY
## AIR above the ramp because there was no aft pylon at all, and a ramp drawn 3.5 m behind the fuselage with nothing
## under it (`shell_room` excused the ramp gunner's floor for that). The user named it "not good".
##
## REFERENCES, FOR PROPORTION AND FEATURES: Boeing's CH-47F sheet (`craft/chinook/sources.md`): 15.6 m fuselage, 18.3 m
## rotors, 30.1 m rotors turning, 5.7 m to the top of the aft rotor head, 3.8 m across the sponsons. Wikipedia's "Boeing
## CH-47 Chinook" infobox for the 0.81 m blade chord's proportion and the cabin's 2.29 m width and 1.98 m height.
##
## THE FUSELAGE IS 16.4 m, HALF A METRE LONGER THAN THE NATIVE BOX, ON PURPOSE: the package seats the ramp gunner at z
## 7.20 facing aft and his gun at 7.80, and a roof has to be over both. The ramp hinges at the fuselage's end, behind
## the gun, so it swings clear of it.
##
## SEAT ANCHORS ARE FLOOR LEVEL (`CockpitStation`). The package puts all four at y -1.20; a parked Chinook's origin is
## the native box's half-height, 2.60 m, over the ground -- so the floor stands 1.4 m up, higher than a real Chinook's,
## and the wheels hang on longer legs to reach the ground.

const FUSELAGE_LENGTH := 15.9
const ROTOR_DIAMETER := 18.3
const HEIGHT := 5.7
const DETAIL_RANGE := RotorcraftKit.DETAIL_RANGE

const OLIVE := Color(0.28, 0.35, 0.29)
const BELLY := Color(0.20, 0.25, 0.21)
const GLASS := Color(0.10, 0.20, 0.20, 0.34)
const WINDOW := Color(0.06, 0.11, 0.11)
const METAL := Color(0.30, 0.33, 0.30)
const DARK := Color(0.05, 0.06, 0.05)
const BLADE := Color(0.09, 0.10, 0.09)
const BLADE_TIP := Color(0.85, 0.80, 0.25)
const CANVAS := Color(0.30, 0.30, 0.22)
const INTERIOR := Color(0.33, 0.36, 0.33)

## THE GROUND, as the native box's floor.
const GROUND := -2.60
## THE CABIN SECTION: half-width, keel, roof; the floor the crew stand on is 0.04 m under their anchors at -1.20.
const CABIN_HALF := 1.30
const KEEL := -1.70
const ROOF := 0.95
const FLOOR := -1.24
## WHERE THE FUSELAGE ENDS, and the ramp's hinge with it; how long the ramp is, and how far it swings.
const NOSE := -7.95
const TAIL := 8.45
const RAMP_LENGTH := 2.0
## THE ROTOR HEADS, 11.8 m apart so the tips are the published 30.1 m apart, the aft one's top at the published 5.7 m.
## THE AFT HEAD STANDS WELL ABOVE THE FORWARD ONE, which is most of a Chinook's side view. The first draw had them 0.52 m
## apart and it read as two equal masts (team-lead, from the side view, 2026-09-17). ESTIMATE, from the proportions of
## CH-47 side views: the forward head sits about as far over the cabin roof as the aft pylon's shoulder, some 1.1 m
## under the aft head. Only the aft head's height is published (5.7 m), so it stays fixed and the forward one comes down.
const FRONT_HUB := Vector3(0.0, 1.75, -5.90)
## The hub's own cap stands 0.285 m over its centre (`RotorcraftKit.rotor`, hub height 0.30).
const REAR_HUB := Vector3(0.0, GROUND + HEIGHT - 0.285, 5.90)
const BLADE_CHORD := 0.81
## THE SPINE: the drive-shaft tunnel along the roof between the pylons.
const TUNNEL_TOP := 1.25
## THE WHEELS: two pairs, on the sponsons, standing on the ground.
const WHEEL_RADIUS := 0.45
## An eight-sided tyre stands on a FLAT, r cos(22.5 deg) under its axle, not on a vertex.
const FRONT_WHEELS := Vector3(1.40, GROUND + WHEEL_RADIUS * 0.9239, -3.30)
const REAR_WHEELS := Vector3(1.50, GROUND + WHEEL_RADIUS * 0.9239, 2.70)

var exterior: Node3D
var interior: Node3D
var front_rotor: Node3D
var rear_rotor: Node3D
var ramp: Node3D
var _rotors_handed: Dictionary = {"turning": false, "collective": 0.0, "seconds": 0.0}
var _ramp_down: float = 1.0


func dress(_geometry: Dictionary) -> void:
	if get_child_count() > 0:
		return
	exterior = Node3D.new(); exterior.name = "Exterior"; add_child(exterior)
	interior = Node3D.new(); interior.name = "Interior"; add_child(interior)
	_build()


func show_layers(show_exterior: bool, show_interior: bool) -> void:
	if exterior != null: exterior.visible = show_exterior
	if interior != null: interior.visible = show_interior


## THE ROOM PROMISED ROUND THE CREW: the whole cabin from the cockpit to the tail, 1.10 m either side, floor to roof.
func cabin_room() -> Dictionary:
	var low: float = FLOOR + 0.04
	return {
		"drawn": true,
		"floor": low,
		"room": AABB(Vector3(-1.10, low, -7.0), Vector3(2.20, ROOF - 0.08 - low, TAIL - 0.1 + 7.0)),
		"because": &"",
		"why_not": "",
		"source": "the section constants of ChinookAirframe, 2026-09-17",
	}


## WHERE THE LIGHTS GO, on the parts that carry them: the nav lights on the sponsons' flanks, the white light over the
## open tail, the strobe on the aft pylon, a beacon on the spine and one under the belly.
static func lights() -> Dictionary:
	return {"port": Vector3(-1.91, -1.25, -0.3), "starboard": Vector3(1.91, -1.25, -0.3),
		"tail": Vector3(0.0, ROOF - 0.10, TAIL + 0.04), "strobe": Vector3(0.0, REAR_HUB.y - 0.90, TAIL - 0.30),
		"top": Vector3(0.0, TUNNEL_TOP + 0.05, 0.0), "bottom": Vector3(0.0, KEEL - 0.05, 0.0)}


## THE ROTORS, from what this machine holds, as `LightHelicopterAirframe.set_rotors`: the two counter-rotate.
func set_rotors(turning: bool, collective: float, seconds: float) -> void:
	_rotors_handed = {"turning": turning, "collective": clampf(collective, 0.0, 1.0), "seconds": seconds}
	var shown: float = smoothstep(0.05, 0.6, collective) if turning else 0.0
	var turns: float = seconds * RotorcraftKit.MAIN_TURNS if turning else 0.0
	RotorcraftKit.turn(front_rotor, turns, shown)
	RotorcraftKit.turn(rear_rotor, turns, shown)


func rotors_state() -> Dictionary:
	return _rotors_handed.duplicate()


## THE RAMP, straight from the bus's "ramp" bit, as the fighter's gear is: 1 is down, level with the cabin floor where the
## ramp gunner works over it; 0 is up, swung square to close the tail. A pure function of what it is handed.
func set_ramp(down: float) -> void:
	_ramp_down = clampf(down, 0.0, 1.0)
	if ramp != null:
		ramp.rotation = Vector3(lerpf(-PI * 0.5, 0.0, _ramp_down), 0.0, 0.0)


func ramp_amount() -> float:
	return _ramp_down


func _build() -> void:
	var paint := RotorcraftKit.paint()
	var glass := RotorcraftKit.glass()
	_fuselage(paint, glass)
	_pylons(paint)
	_engines(paint)
	_sponsons_and_gear(paint)
	_windows(paint)
	_ramp(paint)
	# THE RAMP GUN'S PEDESTAL, from the floor up to its pintle post: the gun and post are VehicleView's.
	RotorcraftKit.door_gun_arms(exterior, Sim.Kind.CHINOOK, 0.0, FLOOR + 0.02, paint, METAL)
	_interior(paint)
	# THE ROTORS COUNTER-ROTATE AND MESH: the rear one turns the other way and is parked sixty degrees round, so its
	# blades sit between the front one's.
	front_rotor = RotorcraftKit.rotor(exterior, "ChinookFrontRotor", FRONT_HUB, Basis.IDENTITY, ROTOR_DIAMETER * 0.5, 3,
		BLADE_CHORD, 0.42, 0.30, BLADE, BLADE_TIP, METAL, paint, 1.0, 0.0)
	rear_rotor = RotorcraftKit.rotor(exterior, "ChinookRearRotor", REAR_HUB, Basis.IDENTITY, ROTOR_DIAMETER * 0.5, 3,
		BLADE_CHORD, 0.42, 0.30, BLADE, BLADE_TIP, METAL, paint, -1.0, PI)
	set_ramp(_ramp_down)


## THE FUSELAGE, nose to tail, in one loft: glazed nose, chin and cockpit; the tail left open over the ramp.
func _fuselage(paint: Material, glass: Material) -> void:
	var rings: Array = [
		RotorcraftKit.section(NOSE, 0.60, -1.48, -0.50, 0.7, 0.6),
		# THE ROOF RUNS WIDE OVER THE PILOTS: their stations reach 0.90 m out at z -7.17, and under glass there is nothing
		# over them (`shell_room`, first draw, 2026-09-17).
		RotorcraftKit.section(-7.55, 1.08, -1.66, 0.34, 0.85, 0.82),
		RotorcraftKit.section(-6.95, 1.26, KEEL, 0.86, 0.9, 0.80, 0.14),
		RotorcraftKit.section(-6.10, CABIN_HALF, KEEL, ROOF, 0.92, 0.74, 0.12, 0.14),
		RotorcraftKit.section(-5.00, CABIN_HALF, KEEL, ROOF, 0.92, 0.74, 0.12, 0.14),
		RotorcraftKit.section(5.40, CABIN_HALF, KEEL, ROOF, 0.92, 0.74, 0.12, 0.14),
		# THE BELLY SWEEPS UP TO THE RAMP'S HINGE under the aft pylon.
		RotorcraftKit.section(TAIL, CABIN_HALF, FLOOR - 0.10, ROOF, 0.96, 0.74, 0.06, 0.14),
	]
	var skin := RotorcraftKit.tool()
	var glazing := RotorcraftKit.tool()
	RotorcraftKit.loft(skin, glazing, rings, _panel)
	RotorcraftKit.part(exterior, "ChinookFuselage", skin, paint)
	RotorcraftKit.part(exterior, "ChinookGlazing", glazing, glass)


## WHAT EACH FUSELAGE PANEL IS. Spans: 0 nose, 1 windscreen, 2 overhead, 3 cockpit, 4 cabin, 5 over the ramp. The
## back cap is left open: that is the tail the ramp gunner looks out of.
func _panel(span: int, facet: int) -> Variant:
	var named: StringName = RotorcraftKit.facet_is(facet)
	if span == -1:
		return OLIVE
	if span == 6:
		return null
	if named == &"keel":
		return BELLY
	match span:
		0:
			# THE WINDSCREEN AND THE CHIN, round the blunt nose: a Chinook's nose is mostly glass.
			return OLIVE if named == &"roof" else GLASS
		1:
			return GLASS if named != &"roof" else OLIVE
		2:
			return GLASS if named == &"upper" or named == &"shoulder" else OLIVE
		3:
			return GLASS if named == &"upper" else OLIVE
	return OLIVE


## THE TWO PYLONS AND THE SPINE: the forward pylon over the cockpit, the tall aft pylon over the tail -- which is what
## the rear rotor stands on, and which the first model did not have -- and the drive-shaft tunnel between them.
func _pylons(paint: Material) -> void:
	var front := RotorcraftKit.tool()
	RotorcraftKit.loft(front, front, [
		RotorcraftKit.section(-7.10, 0.40, ROOF - 0.30, ROOF + 0.10, 0.9, 0.7),
		RotorcraftKit.section(-6.60, 0.62, ROOF - 0.10, FRONT_HUB.y - 0.55, 0.9, 0.66),
		RotorcraftKit.section(-5.20, 0.62, ROOF - 0.10, FRONT_HUB.y - 0.35, 0.9, 0.66),
		RotorcraftKit.section(-4.30, 0.46, ROOF - 0.10, TUNNEL_TOP, 0.9, 0.66),
	], func(_s, _f): return OLIVE)
	RotorcraftKit.part(exterior, "ChinookFrontPylon", front, paint)
	var tunnel := RotorcraftKit.tool()
	RotorcraftKit.loft(tunnel, tunnel, [
		RotorcraftKit.section(-4.60, 0.40, ROOF - 0.10, TUNNEL_TOP, 0.9, 0.7),
		RotorcraftKit.section(3.60, 0.40, ROOF - 0.10, TUNNEL_TOP, 0.9, 0.7),
	], func(_s, _f): return OLIVE)
	RotorcraftKit.part(exterior, "ChinookSpineTunnel", tunnel, paint)
	# THE AFT PYLON: rising out of the spine, tall and swept back, standing over the tail and the ramp.
	var rear := RotorcraftKit.tool()
	RotorcraftKit.loft(rear, rear, [
		RotorcraftKit.section(3.20, 0.44, ROOF - 0.10, TUNNEL_TOP, 0.9, 0.7),
		RotorcraftKit.section(4.60, 0.66, ROOF - 0.10, REAR_HUB.y - 0.50, 0.9, 0.62),
		RotorcraftKit.section(6.90, 0.66, ROOF - 0.10, REAR_HUB.y - 0.40, 0.9, 0.62),
		RotorcraftKit.section(TAIL - 0.05, 0.40, ROOF - 0.10, REAR_HUB.y - 0.95, 0.9, 0.62),
	], func(_s, _f): return OLIVE)
	RotorcraftKit.part(exterior, "ChinookRearPylon", rear, paint)
	var masts := RotorcraftKit.tool()
	RotorcraftKit.rod(masts, Vector3(0.0, FRONT_HUB.y - 0.50, FRONT_HUB.z), FRONT_HUB, 0.16, METAL, 6)
	RotorcraftKit.rod(masts, Vector3(0.0, REAR_HUB.y - 0.55, REAR_HUB.z), REAR_HUB, 0.16, METAL, 6)
	RotorcraftKit.part(exterior, "ChinookRotorMasts", masts, paint)


## THE TWO ENGINES, on stubs either side of the aft pylon, intakes forward and exhausts aft.
func _engines(paint: Material) -> void:
	for side in [-1.0, 1.0]:
		var named := "Port" if side < 0.0 else "Starboard"
		var pod := RotorcraftKit.tool()
		var centre_x: float = side * 1.18
		var y: float = ROOF + 0.62
		var rings: Array = []
		var along: Array = [[3.40, 0.36], [3.70, 0.46], [5.60, 0.46], [6.20, 0.32]]
		for station in along:
			rings.append(RotorcraftKit.ring(Vector3(centre_x, y, float(station[0])), Vector3.BACK, float(station[1]),
				float(station[1]), 8, PI / 8.0))
		RotorcraftKit.loft(pod, pod, rings, func(span, _f): return DARK if span == -1 or span == 3 else OLIVE)
		RotorcraftKit.box(pod, Vector3(side * 0.76, y - 0.05, 4.60), Vector3(0.62, 0.18, 1.4), OLIVE)
		RotorcraftKit.part(exterior, "Chinook%sEngine" % named, pod, paint)


## THE SPONSONS, long fuel tanks down the lower sides, and the wheels on them: two pairs, on legs to the ground.
func _sponsons_and_gear(paint: Material) -> void:
	for side in [-1.0, 1.0]:
		var named := "Port" if side < 0.0 else "Starboard"
		var tank := RotorcraftKit.tool()
		RotorcraftKit.loft(tank, tank, [
			RotorcraftKit.section(-4.20, 0.26, KEEL + 0.06, -0.95, 0.8, 0.6, 0.22, 0.26, side * 1.52),
			RotorcraftKit.section(-3.60, 0.34, KEEL + 0.02, -0.80, 0.8, 0.6, 0.22, 0.26, side * 1.56),
			RotorcraftKit.section(2.90, 0.34, KEEL + 0.02, -0.80, 0.8, 0.6, 0.22, 0.26, side * 1.56),
			RotorcraftKit.section(3.60, 0.26, KEEL + 0.06, -0.95, 0.8, 0.6, 0.22, 0.26, side * 1.52),
		], func(_s, _f): return OLIVE)
		RotorcraftKit.part(exterior, "Chinook%sSponson" % named, tank, paint)
		for pair in [FRONT_WHEELS, REAR_WHEELS]:
			var fore: bool = pair == FRONT_WHEELS
			var wheel := Vector3(side * pair.x, pair.y, pair.z)
			var gear := RotorcraftKit.tool()
			RotorcraftKit.rod(gear, Vector3(side * (pair.x - 0.05), KEEL + 0.20, pair.z), wheel, 0.10, METAL, 6)
			RotorcraftKit.wheel(gear, wheel, WHEEL_RADIUS, 0.30, DARK)
			RotorcraftKit.part(exterior, "Chinook%s%sWheel" % [named, "Front" if fore else "Rear"], gear, paint, true)


## A ROW OF CABIN WINDOWS each side, and the crew door on the starboard side forward, drawn dark on the skin.
func _windows(paint: Material) -> void:
	var panes := RotorcraftKit.tool()
	for side in [-1.0, 1.0]:
		for index in range(7):
			var z: float = -3.9 + float(index) * 1.35
			RotorcraftKit.box(panes, Vector3(side * (CABIN_HALF + 0.005), 0.05, z), Vector3(0.03, 0.42, 0.42), WINDOW)
	RotorcraftKit.box(panes, Vector3(CABIN_HALF + 0.01, -0.35, -4.55), Vector3(0.03, 1.55, 0.80), BELLY)
	RotorcraftKit.part(exterior, "ChinookCabinWindows", panes, paint, true)


## THE RAMP, a pivot at the fuselage's end with the deck hung aft of it, swung by `set_ramp`.
func _ramp(paint: Material) -> void:
	ramp = Node3D.new()
	ramp.name = "RampHinge"
	ramp.position = Vector3(0.0, FLOOR - 0.06, TAIL)
	exterior.add_child(ramp)
	var deck := RotorcraftKit.tool()
	RotorcraftKit.box(deck, Vector3(0.0, 0.0, RAMP_LENGTH * 0.5 - 0.05), Vector3(CABIN_HALF * 1.72, 0.14, RAMP_LENGTH),
		BELLY)
	for side in [-1.0, 1.0]:
		RotorcraftKit.box(deck, Vector3(side * CABIN_HALF * 0.84, 0.16, RAMP_LENGTH * 0.5 - 0.05),
			Vector3(0.06, 0.20, RAMP_LENGTH), OLIVE)
	RotorcraftKit.part(ramp, "Ramp", deck, paint)


## THE CABIN FLOOR, THE CREW SEATS AND THE TROOP SEATS DOWN BOTH SIDES.
func _interior(paint: Material) -> void:
	var floor := RotorcraftKit.tool()
	RotorcraftKit.box(floor, Vector3(0.0, FLOOR - 0.045, 0.60), Vector3(2.40, 0.09, 15.4), INTERIOR)
	RotorcraftKit.part(interior, "CabinFloor", floor, paint)
	RotorcraftKit.crew_seats(interior, Sim.Kind.CHINOOK, paint, CANVAS, METAL)
	var benches := RotorcraftKit.tool()
	for side in [-1.0, 1.0]:
		RotorcraftKit.box(benches, Vector3(side * 1.02, FLOOR + 0.44, 1.2), Vector3(0.44, 0.08, 7.4), CANVAS)
		RotorcraftKit.box(benches, Vector3(side * 1.24, FLOOR + 0.86, 1.2), Vector3(0.06, 0.70, 7.4), CANVAS)
	RotorcraftKit.part(interior, "TroopSeats", benches, paint)
