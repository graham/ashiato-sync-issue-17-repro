extends Node3D
class_name Uh60Airframe
## A UH-60M BLACK HAWK, DRAWN: a low pointed nose under a stepped windscreen, chin windows, a pilot's door each side, the
## cabin's sliding doors run back open on their rails for the two crew chiefs, twin engines on the roof either side of
## the transmission fairing with their exhausts turned out, a four-blade rotor, the tail cone running up into a thick
## swept tail pylon, the TAIL ROTOR CANTED TWENTY DEGREES on the pylon's starboard side, a big stabilator at the pylon's
## foot, main wheels on their struts forward and a tail wheel aft. Presentation only: CockpitWorld owns collision, mass,
## seats, flight and replication.
##
## WHAT IT REPLACED, AND WHY (2026-09-17): the first model was a 7.8 m cylinder with a cone for a nose and another cone
## for a boom, so the rear fuselage ended in a flat-cut disc, the tail rotor stood square to the boom where nobody could
## read it at three-quarters, the tail wheel hung 0.74 m under the boom on nothing, and both door gunners' stations
## stood outboard of the fuselage (`shell_room` excused their floors and bars). The user named it "not good".
##
## REFERENCES, FOR PROPORTION AND FEATURES: U.S. Army FM 3-04 (`craft/uh60/sources.md`): 12.62 m fuselage, 16.36 m rotor,
## 5.16 m to the top of the tail rotor. Wikipedia's "Sikorsky UH-60 Black Hawk" infobox for the 3.35 m tail rotor and the
## 2.36 m fuselage width.
##
## IT IS WIDER THAN A BLACK HAWK, ON PURPOSE: 2.84 m across the cabin against 2.36 m, because the package puts each crew
## chief's seat 0.78 m off the centreline facing out and his station reaches 1.35 m out at the floor. The user's rule is
## that a craft too small for its crew is enlarged (`craft_standard.md`), and a door gunner whose floor is outside the
## helicopter is a door gunner standing on air. The cabin is 1.96 m tall inside where a real one is 1.37 m, for the
## same reason: the crew sit, and their eyes are 1.35 m over the floor.
##
## SEAT ANCHORS ARE FLOOR LEVEL (`CockpitStation`). The package puts all four at y -0.48: the pilots at z -3.55 and the
## crew chiefs at z 0.25. A parked UH-60's origin is the native box's half-height, 1.42 m, over the ground.

const FUSELAGE_LENGTH := 12.62
const ROTOR_DIAMETER := 16.36
const HEIGHT := 5.16
const DETAIL_RANGE := RotorcraftKit.DETAIL_RANGE

const GREEN := Color(0.19, 0.24, 0.17)
const BELLY := Color(0.14, 0.17, 0.13)
const GLASS := Color(0.10, 0.20, 0.20, 0.34)
const METAL := Color(0.26, 0.29, 0.25)
const DARK := Color(0.05, 0.06, 0.05)
const BLADE := Color(0.08, 0.09, 0.08)
const BLADE_TIP := Color(0.85, 0.80, 0.25)
const CANVAS := Color(0.24, 0.27, 0.20)
## A WINDOW IN A DOOR THAT IS RUN BACK OVER THE CABIN SIDE: there is skin behind it, so it is drawn dark and solid.
const WINDOW := Color(0.06, 0.12, 0.12)
const INTERIOR := Color(0.30, 0.33, 0.30)

## THE GROUND, as the native box's floor: the wheels stand on it.
const GROUND := -1.42
## THE CABIN SECTION where it is widest: half-width, keel, roof, how wide the keel and the roof run and how low the chine
## turns. See the doc block for why it is wider and taller than a Black Hawk.
const CABIN_HALF := 1.42
const KEEL := -0.95
const ROOF := 1.50
const KEEL_WIDE := 0.90
const CROWN := 0.80
const CHINE := 0.14
## THE SHOULDER IS HIGH, so the door opening runs up past the crew chiefs' eyes. `seat_room` measured the first draw:
## the side turned in at y 0.73, fourteen centimetres UNDER a crew chief's eye, and his head met the skin 0.44 m out,
## so a door gunner looked out of his door at a wall. Now the opening's top is 1.28, 0.41 m over his eye.
const SHOULDER := 0.12
## THE STATIONS OF THE FUSELAGE, fore and aft: the nose, the windscreen's step, the cockpit's rear bulkhead, the cabin
## door opening, and where the tail cone starts.
const NOSE := -6.31
const DOOR_FRONT := -1.00
const DOOR_BACK := 1.50
const TAIL_CONE := 2.85
## THE MAIN ROTOR HUB, from the first model's station (the native rotor sits over the centre of mass).
const HUB := Vector3(0.0, 2.50, -0.28)
const BLADE_CHORD := 0.53
## THE TAIL ROTOR: 3.35 m across, on the pylon's starboard side, its shaft canted twenty degrees up so the rotor also
## lifts. Its top is the published 5.16 m over the ground.
const TAIL_RADIUS := 1.675
const TAIL_CANT := deg_to_rad(20.0)
const TAIL_HUB := Vector3(0.36, GROUND + HEIGHT - TAIL_RADIUS * 0.9397, 6.02)
## THE MAIN WHEELS, 2.7 m apart, under the cockpit's rear bulkhead; and the tail wheel under the tail cone.
## An eight-sided tyre stands on a FLAT, r cos(22.5 deg) under its axle, not on a vertex.
const MAIN_WHEEL := Vector3(1.36, GROUND + 0.36 * 0.9239, -2.95)
const TAIL_WHEEL := Vector3(0.0, GROUND + 0.24 * 0.9239, 4.95)

var exterior: Node3D
var interior: Node3D
var main_rotor: Node3D
var tail_rotor: Node3D
var _rotors_handed: Dictionary = {"turning": false, "collective": 0.0, "seconds": 0.0}


func dress(_geometry: Dictionary) -> void:
	if get_child_count() > 0:
		return
	exterior = Node3D.new(); exterior.name = "Exterior"; add_child(exterior)
	interior = Node3D.new(); interior.name = "Interior"; add_child(interior)
	_build()


func show_layers(show_exterior: bool, show_interior: bool) -> void:
	if exterior != null: exterior.visible = show_exterior
	if interior != null: interior.visible = show_interior


## THE ROOM PROMISED ROUND THE CREW, from the cockpit's windscreen step to the cabin's rear: under the roof, over the
## floor, and 1.20 m either side, which the section holds from the floor (y -0.48) to the roof.
func cabin_room() -> Dictionary:
	var low: float = -0.48
	return {
		"drawn": true,
		"floor": low,
		"room": AABB(Vector3(-1.20, low, -4.20), Vector3(2.40, ROOF - 0.08 - low, TAIL_CONE - 0.2 + 4.20)),
		"because": &"",
		"why_not": "",
		"source": "the section constants of Uh60Airframe, 2026-09-17",
	}


## WHERE THE LIGHTS GO, on the parts that carry them: the nav lights on the stabilator's tips, the white light on the
## pylon's trailing edge, the strobe on its head, a beacon on the fairing and one under the belly.
static func lights() -> Dictionary:
	return {"port": Vector3(-2.20, 0.66, 5.85), "starboard": Vector3(2.20, 0.66, 5.85), "tail": Vector3(0.0, 1.40, 6.33),
		"strobe": Vector3(0.0, TAIL_HUB.y + 0.97, 6.16), "top": Vector3(0.0, ROOF + 0.62, 0.8),
		"bottom": Vector3(0.0, KEEL - 0.05, 0.0)}


## THE ROTORS, from what this machine holds, as `LightHelicopterAirframe.set_rotors`.
func set_rotors(turning: bool, collective: float, seconds: float) -> void:
	_rotors_handed = {"turning": turning, "collective": clampf(collective, 0.0, 1.0), "seconds": seconds}
	var shown: float = smoothstep(0.05, 0.6, collective) if turning else 0.0
	RotorcraftKit.turn(main_rotor, seconds * RotorcraftKit.MAIN_TURNS if turning else 0.0, shown)
	RotorcraftKit.turn(tail_rotor, seconds * RotorcraftKit.TAIL_TURNS if turning else 0.0, 0.0)


func rotors_state() -> Dictionary:
	return _rotors_handed.duplicate()


func _build() -> void:
	var paint := RotorcraftKit.paint()
	var glass := RotorcraftKit.glass()
	_fuselage(paint, glass)
	_tail(paint)
	_engines(paint)
	_gear(paint)
	_doors(paint)
	RotorcraftKit.door_gun_arms(exterior, Sim.Kind.UH60, 0.10, -0.50, paint, METAL)
	_interior(paint)
	# FOUR BLADES, parked at forty-five degrees to the fuselage.
	main_rotor = RotorcraftKit.rotor(exterior, "MainRotor", HUB, Basis.IDENTITY, ROTOR_DIAMETER * 0.5, 4, BLADE_CHORD,
		0.36, 0.26, BLADE, BLADE_TIP, METAL, paint, 1.0, PI * 0.25)
	# THE TAIL ROTOR'S SHAFT points out to starboard and twenty degrees up; its blades turn in the plane square to it,
	# parked with one blade straight up, where the published height is measured to.
	var out := Vector3(cos(TAIL_CANT), sin(TAIL_CANT), 0.0)
	var shaft := Basis(out.cross(Vector3.BACK), out, Vector3.BACK)
	tail_rotor = RotorcraftKit.rotor(exterior, "TailRotor", TAIL_HUB, shaft, TAIL_RADIUS, 4, 0.26,
		0.14, 0.16, BLADE, BLADE_TIP, METAL, paint, -1.0, 0.0)


## THE FUSELAGE, nose to tail cone, in one loft; the windscreen, chin and pilots' door windows in another.
func _fuselage(paint: Material, glass: Material) -> void:
	var rings: Array = [
		RotorcraftKit.section(NOSE, 0.22, -0.58, -0.18, 0.7, 0.6),
		RotorcraftKit.section(-5.85, 0.78, -0.86, 0.22, 0.8, 0.6),
		RotorcraftKit.section(-5.15, 1.12, -0.95, 0.56, 0.86, 0.62),
		RotorcraftKit.section(-4.30, 1.28, KEEL, 1.36, KEEL_WIDE, 0.72, CHINE),
		RotorcraftKit.section(-2.70, 1.36, KEEL, ROOF, KEEL_WIDE, CROWN, CHINE, SHOULDER),
		RotorcraftKit.section(DOOR_FRONT, CABIN_HALF, KEEL, ROOF, KEEL_WIDE, CROWN, CHINE, SHOULDER),
		RotorcraftKit.section(DOOR_BACK, CABIN_HALF, KEEL, ROOF, KEEL_WIDE, CROWN, CHINE, SHOULDER),
		RotorcraftKit.section(TAIL_CONE, 1.30, -0.80, 1.44, 0.85, 0.76, CHINE, SHOULDER),
		RotorcraftKit.section(3.95, 0.56, 0.02, 1.12, 0.75, 0.70),
	]
	var skin := RotorcraftKit.tool()
	var glazing := RotorcraftKit.tool()
	RotorcraftKit.loft(skin, glazing, rings, _panel)
	RotorcraftKit.part(exterior, "CabinFuselage", skin, paint)
	RotorcraftKit.part(exterior, "SteppedCockpitNose", glazing, glass)


## WHAT EACH FUSELAGE PANEL IS. Spans: 0 nose, 1 chin and lower windscreen, 2 windscreen, 3 pilots' doors, 4 cabin
## ahead of the doors, 5 the open cabin doors, 6 cabin behind them, 7 the tail cone.
func _panel(span: int, facet: int) -> Variant:
	var named: StringName = RotorcraftKit.facet_is(facet)
	var side: bool = named == &"lower" or named == &"upper"
	if span < 0:
		return GREEN
	if named == &"keel":
		return BELLY
	match span:
		1:
			return GLASS if named == &"shoulder" or named == &"upper" or named == &"chine" else GREEN
		2:
			return GLASS if named != &"roof" else GREEN
		3:
			return GLASS if named == &"upper" or named == &"shoulder" else GREEN
		4:
			return GLASS if named == &"upper" else GREEN
		5:
			return null if side else GREEN
	return GREEN


## THE TAIL: the boom, the thick swept pylon at its end, the stabilator at the pylon's foot, the tail rotor's gearbox.
func _tail(paint: Material) -> void:
	var boom := RotorcraftKit.tool()
	RotorcraftKit.loft(boom, boom, [
		RotorcraftKit.section(3.70, 0.62, -0.02, 1.10, 0.75, 0.70),
		RotorcraftKit.section(5.30, 0.34, 0.30, 0.98, 0.75, 0.70),
		RotorcraftKit.section(6.05, 0.26, 0.40, 0.96, 0.75, 0.70),
	], func(_s, facet): return BELLY if RotorcraftKit.facet_is(facet) == &"keel" else GREEN)
	RotorcraftKit.part(exterior, "TailBoom", boom, paint)
	# THE PYLON: thick, swept back, standing on the boom's end and carrying the tail rotor at its head.
	var pylon := RotorcraftKit.tool()
	RotorcraftKit.loft(pylon, pylon, [
		_pylon_ring(0.62, 5.10, 6.31, 0.20),
		_pylon_ring(TAIL_HUB.y + 0.30, 5.76, 6.31, 0.15),
		_pylon_ring(TAIL_HUB.y + 0.95, 6.02, 6.31, 0.10),
	], func(_s, _f): return GREEN)
	RotorcraftKit.part(exterior, "SweptTailFin", pylon, paint)
	var stabilator := RotorcraftKit.tool()
	var outline: Array[Vector3] = [Vector3(-2.185, 0.66, 5.50), Vector3(-2.185, 0.66, 6.20), Vector3(2.185, 0.66, 6.20),
		Vector3(2.185, 0.66, 5.50)]
	RotorcraftKit.plate(stabilator, outline, Vector3.UP, 0.10, GREEN)
	RotorcraftKit.part(exterior, "FoldingStabilator", stabilator, paint)
	var gearbox := RotorcraftKit.tool()
	RotorcraftKit.rod(gearbox, Vector3(0.06, TAIL_HUB.y, TAIL_HUB.z), TAIL_HUB - Vector3(0.06, 0.02, 0.0), 0.17, METAL, 6)
	RotorcraftKit.part(exterior, "TailRotorGearbox", gearbox, paint, true)


## A SECTION OF THE PYLON at height `y`, from `front` to `back` along z, `thick` across.
func _pylon_ring(y: float, front: float, back: float, thick: float) -> PackedVector3Array:
	var chord: float = back - front
	return PackedVector3Array([
		Vector3(0.0, y, front), Vector3(thick * 0.5, y, front + chord * 0.25), Vector3(thick * 0.5, y, front + chord * 0.75),
		Vector3(0.0, y, back), Vector3(-thick * 0.5, y, front + chord * 0.75), Vector3(-thick * 0.5, y, front + chord * 0.25),
	])


## TWIN ENGINES either side of the transmission fairing, their intakes forward and their suppressed exhausts turned out.
func _engines(paint: Material) -> void:
	var fairing := RotorcraftKit.tool()
	RotorcraftKit.loft(fairing, fairing, [
		RotorcraftKit.section(-2.40, 0.30, ROOF - 0.12, ROOF + 0.18, 0.9, 0.7),
		RotorcraftKit.section(-1.70, 0.66, ROOF - 0.12, ROOF + 0.60, 0.9, 0.62),
		RotorcraftKit.section(1.50, 0.66, ROOF - 0.12, ROOF + 0.60, 0.9, 0.62),
		RotorcraftKit.section(3.30, 0.40, 0.95, ROOF + 0.20, 0.9, 0.62),
	], func(_s, _f): return GREEN)
	RotorcraftKit.part(exterior, "TransmissionFairing", fairing, paint)
	var mast := RotorcraftKit.tool()
	RotorcraftKit.rod(mast, Vector3(HUB.x, ROOF + 0.50, HUB.z), HUB, 0.13, METAL, 6)
	RotorcraftKit.part(exterior, "MainRotorMast", mast, paint)
	for side in [-1.0, 1.0]:
		var named := "Port" if side < 0.0 else "Starboard"
		var housing := RotorcraftKit.tool()
		var along := [Vector3(side * 0.78, ROOF + 0.36, -1.55), Vector3(side * 0.80, ROOF + 0.38, -1.25),
			Vector3(side * 0.80, ROOF + 0.38, 0.90), Vector3(side * 0.74, ROOF + 0.32, 1.35)]
		var sizes := [0.28, 0.40, 0.40, 0.30]
		var rings: Array = []
		for index in range(along.size()):
			rings.append(RotorcraftKit.ring(along[index], Vector3.BACK, sizes[index], sizes[index] * 0.9, 8, PI / 8.0))
		RotorcraftKit.loft(housing, housing, rings, func(span, _f): return DARK if span == -1 else GREEN)
		RotorcraftKit.part(exterior, named + "EngineHousing", housing, paint)
		var intake := RotorcraftKit.tool()
		RotorcraftKit.rod(intake, Vector3(side * 0.78, ROOF + 0.36, -1.62), Vector3(side * 0.78, ROOF + 0.36, -1.50),
			0.26, DARK, 8)
		RotorcraftKit.part(exterior, named + "EngineIntake", intake, paint, true)
		# THE EXHAUST SUPPRESSOR, turned outboard and a little up so the hot gas misses the tail cone.
		var exhaust := RotorcraftKit.tool()
		RotorcraftKit.rod(exhaust, Vector3(side * 0.74, ROOF + 0.32, 1.25), Vector3(side * 1.28, ROOF + 0.44, 2.05),
			0.22, DARK, 8, 0.19)
		RotorcraftKit.part(exterior, named + "UpturnedExhaust", exhaust, paint, true)


## THE MAIN WHEELS on struts braced to the fuselage side, and the tail wheel on its long leg under the tail cone.
func _gear(paint: Material) -> void:
	for side in [-1.0, 1.0]:
		var named := "Port" if side < 0.0 else "Starboard"
		var wheel := Vector3(side * MAIN_WHEEL.x, MAIN_WHEEL.y, MAIN_WHEEL.z)
		var legs := RotorcraftKit.tool()
		RotorcraftKit.rod(legs, wheel + Vector3(-side * 0.10, 0.0, 0.0), Vector3(side * 1.18, -0.50, MAIN_WHEEL.z - 0.35),
			0.07, METAL, 6)
		RotorcraftKit.rod(legs, wheel + Vector3(-side * 0.10, 0.0, 0.0), Vector3(side * 1.00, KEEL + 0.12,
			MAIN_WHEEL.z + 0.55), 0.06, METAL, 6)
		RotorcraftKit.part(exterior, named + "MainGearStrut", legs, paint, true)
		var tyre := RotorcraftKit.tool()
		RotorcraftKit.wheel(tyre, wheel, 0.36, 0.22, DARK)
		RotorcraftKit.part(exterior, named + "MainWheel", tyre, paint, true)
	var leg := RotorcraftKit.tool()
	RotorcraftKit.rod(leg, Vector3(0.0, 0.16, TAIL_WHEEL.z - 0.70), TAIL_WHEEL + Vector3(0.0, 0.10, 0.0), 0.07, METAL, 6)
	RotorcraftKit.rod(leg, TAIL_WHEEL + Vector3(-0.10, 0.0, 0.0), TAIL_WHEEL + Vector3(0.10, 0.0, 0.0), 0.04, METAL, 6)
	RotorcraftKit.part(exterior, "TailGearStrut", leg, paint, true)
	var tail_tyre := RotorcraftKit.tool()
	RotorcraftKit.wheel(tail_tyre, TAIL_WHEEL, 0.24, 0.15, DARK)
	RotorcraftKit.part(exterior, "TailWheel", tail_tyre, paint, true)


## THE CABIN'S SLIDING DOORS, RUN BACK OPEN on their rails along the cabin side behind the opening, with the rails.
func _doors(paint: Material) -> void:
	for side in [-1.0, 1.0]:
		var named := "Port" if side < 0.0 else "Starboard"
		var door := RotorcraftKit.tool()
		var x: float = side * (CABIN_HALF + 0.03)
		RotorcraftKit.box(door, Vector3(x, 0.05, (DOOR_BACK + TAIL_CONE) * 0.5 + 0.02),
			Vector3(0.05, 1.46, TAIL_CONE - DOOR_BACK - 0.10), GREEN)
		# The window in the door.
		RotorcraftKit.box(door, Vector3(x + side * 0.03, 0.48, (DOOR_BACK + TAIL_CONE) * 0.5),
			Vector3(0.02, 0.42, 0.62), WINDOW)
		# THE UPPER RAIL, along the top of the opening where the side turns in -- NOT across it: the first draw put it
		# at y 0.88, eye height, and `seat_room` found the crew chief's head against it 0.58 m out.
		RotorcraftKit.box(door, Vector3(side * (CABIN_HALF - 0.01), ROOF - (ROOF - KEEL) * SHOULDER + 0.05,
			(DOOR_FRONT + TAIL_CONE) * 0.5), Vector3(0.08, 0.06, TAIL_CONE - DOOR_FRONT), METAL)
		RotorcraftKit.part(exterior, named + "SlidingDoorFrame", door, paint)


## THE CABIN FLOOR, THE CREW SEATS AND THE TROOP SEATS ON THE REAR BULKHEAD.
func _interior(paint: Material) -> void:
	var floor := RotorcraftKit.tool()
	RotorcraftKit.box(floor, Vector3(0.0, -0.53, -1.0), Vector3(2.30, 0.09, 7.6), INTERIOR)
	RotorcraftKit.part(interior, "CabinFloor", floor, paint)
	RotorcraftKit.crew_seats(interior, Sim.Kind.UH60, paint, CANVAS, METAL)
	var bench := RotorcraftKit.tool()
	RotorcraftKit.box(bench, Vector3(0.0, -0.08, TAIL_CONE - 0.45), Vector3(2.20, 0.08, 0.44), CANVAS)
	RotorcraftKit.box(bench, Vector3(0.0, 0.34, TAIL_CONE - 0.22), Vector3(2.20, 0.70, 0.06), CANVAS)
	RotorcraftKit.part(interior, "TroopSeats", bench, paint)
