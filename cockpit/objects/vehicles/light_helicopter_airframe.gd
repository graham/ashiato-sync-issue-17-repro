extends Node3D
class_name LightHelicopterAirframe
## THE LIGHT UTILITY HELICOPTER (`heli`), DRAWN: a Huey-style cabin with a glazed nose and chin windows, a pilot's
## door each side, the cargo doors slid open for the two door gunners, an engine doghouse on the roof, a two-blade
## teetering rotor with its stabiliser bar, a tail boom with a synchronised elevator, a swept fin carrying the tail
## rotor on its port side, a tail skid, and two skids on bent cross tubes. Presentation only: CockpitWorld owns
## flight, collision, stations and replication.
##
## WHAT IT REPLACED, AND WHY: until 2026-09-17 this craft was the simulation's own 1.9 x 2.1 x 5.2 m collision box,
## painted yellow, with a stick boom, three plank blades and two skids stuck on -- `craft_model_audit` put it last in
## the fleet and its own `craft/heli/sources.md` disclaimed it. A rotor craft never hid its cuboid.
##
## A FICTIONAL CRAFT, AND SAID SO: the package's 900 kg, 12 m rotor, four seats and 5.2 m box describe no real
## helicopter (`craft/heli/sources.md`), so this is shaped AFTER the Bell UH-1 family -- the look everybody knows as
## "a helicopter with door gunners" -- and not measured against one. The UH-1H's 14.6 m two-blade rotor, 2.6 m tail
## rotor and 12.8 m fuselage (Wikipedia, "Bell UH-1 Iroquois") are the proportions; the NATIVE 12 m rotor and the
## seat poses are the numbers, because they are what flies and where the crew are.
##
## THE CABIN IS WIDER THAN THE NATIVE BOX, ON PURPOSE: 2.44 m across and 2.22 m tall, so a VR player at every one of
## the four seats has room for a head and two arms, and the door gunners' stations -- which reach 1.12 m out from the
## centreline at the floor -- stand inside it. The UH-1H's own fuselage is about 2.6 m across. The user's rule is that a craft too small for its crew is enlarged
## (`craft_standard.md`).
##
## SEAT ANCHORS ARE FLOOR LEVEL (`CockpitStation`: the floor is 0.04 m over the anchor and the eye 1.35 m over it). The
## package puts all four at y -0.20, the pilots at z -0.85 and the gunners at z 0.55; the cabin is drawn round those.
## The ground is the native box's floor, y -1.05, and the skids stand on it.

const KIND_NAME := "heli"

const YELLOW := Color(0.85, 0.72, 0.30)
const BELLY := Color(0.23, 0.23, 0.22)
const GLASS := Color(0.18, 0.30, 0.32, 0.32)
const ROOF_GLASS := Color(0.12, 0.34, 0.22, 0.45)
const METAL := Color(0.34, 0.35, 0.36)
const DARK := Color(0.08, 0.08, 0.09)
const BLADE := Color(0.12, 0.12, 0.13)
const BLADE_TIP := Color(0.92, 0.85, 0.20)
const CANVAS := Color(0.30, 0.33, 0.26)

## THE GROUND, as the native box's floor: a parked helicopter stands its skids on it.
const GROUND := -1.05
## THE CABIN SECTION, where it is widest: half-width, keel and roof. Everything else is drawn from these.
const CABIN_HALF := 1.22
const KEEL := -0.42
const ROOF := 1.80
## A FLAT ROOF THIS WIDE, as a fraction of the half-width: wide enough that the pilot's station, 0.85 m out, is
## under the roof and not under the upper chamfer, which is glass there and therefore not a roof.
const CROWN := 0.86
const KEEL_WIDE := 0.92
## THE CHINE IS LOW, so the cabin is nearly full width at the floor: the door gunner's station reaches 1.12 m out at
## floor level (measured by `shell_room`, 2026-09-17) and has to stand on something.
const CHINE := 0.14
## THE SHOULDER IS HIGH, so the cargo door runs up past the gunners' eyes: at the section's default the side turned in
## at y 1.22, seven centimetres over a gunner's eye, and `seat_room` found his head against the skin 0.62 m out.
const SHOULDER := 0.12
## THE STATIONS OF THE CABIN, fore and aft: the pilots' doors run from the windscreen to the door post, the cargo doors
## from the post to the rear bulkhead.
const WINDSCREEN_BASE := -1.70
const DOOR_POST := -0.30
const BULKHEAD := 1.35

## THE MAIN ROTOR: the native half-span is the rotor's radius (6.0 m), two blades, the UH-1's 0.53 m chord.
## THE MAST IS TALL, as a Huey's is: [3V] puts the rotor 1.22 m over the doghouse. This one stands 1.06 m over it,
## the three-view's gap at this model's 0.884 scale (see `_boom_and_tail`). It was 0.38 m.
const HUB := Vector3(0.0, 3.30, -0.15)
const BLADE_CHORD := 0.53
## THE TAIL ROTOR, on the port side of the fin, two blades: the UH-1's 2.59 m rotor.
const TAIL_HUB := Vector3(-0.30, 2.68, 7.87)
const TAIL_RADIUS := 1.30
## THE SKIDS stand this far either side of the centreline.
const SKID_X := 1.30

var exterior: Node3D
var interior: Node3D
var main_rotor: Node3D
var tail_rotor: Node3D
var _rotors_handed: Dictionary = {"turning": false, "collective": 0.0, "seconds": 0.0}


func dress(_geometry: Dictionary) -> void:
	if get_child_count() > 0:
		return
	exterior = Node3D.new()
	exterior.name = "Exterior"
	add_child(exterior)
	interior = Node3D.new()
	interior.name = "Interior"
	add_child(interior)
	_build()


func show_layers(show_exterior: bool, show_interior: bool) -> void:
	if exterior != null:
		exterior.visible = show_exterior
	if interior != null:
		interior.visible = show_interior


## THE ROOM PROMISED ROUND THE CREW: every point in it is under the roof, over the keel and between the sides.
## Measured off the section constants: at the keel chamfer's top (y 0.07) the side is 1.08 out and at the floor
## (y -0.20) the chamfer is still 0.92 out, so 0.90 holds all the way down; the roof is flat to 0.93 out.
func cabin_room() -> Dictionary:
	var low: float = -0.20
	return {
		"drawn": true,
		"floor": low,
		"room": AABB(Vector3(-0.90, low, WINDSCREEN_BASE + 0.05),
			Vector3(1.80, ROOF - 0.05 - low, BULKHEAD - WINDSCREEN_BASE - 0.10)),
		"because": &"",
		"why_not": "",
		"source": "the section constants of LightHelicopterAirframe, 2026-09-17",
	}


## WHERE THE LIGHTS GO, on the parts that carry them: the nav lights on the elevator's tips, the white light and the
## strobe at the top of the fin, a beacon on the doghouse and one under the belly. `VehicleLights` asks for these.
static func lights() -> Dictionary:
	return {"port": Vector3(-1.28, 1.12, 5.45), "starboard": Vector3(1.28, 1.12, 5.45), "tail": Vector3(0.0, 2.80, 8.17),
		"strobe": Vector3(0.0, 2.99, 7.90), "top": Vector3(0.0, 2.27, 0.9), "bottom": Vector3(0.0, KEEL - 0.06, 0.3)}


## THE ROTORS, from what this machine holds: turning or parked, how far the collective is up, and the shared clock.
## A pure function of what it is handed, as the Cessna's propeller is.
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
	_cabin(paint, glass)
	_doghouse(paint)
	_boom_and_tail(paint)
	_skids(paint)
	# THE DOOR GUNS' ARMS, from the floor sill up to each pintle post.
	RotorcraftKit.door_gun_arms(exterior, Sim.Kind.HELI, 0.07, -0.22, paint, METAL)
	_interior(paint)
	main_rotor = RotorcraftKit.rotor(exterior, "MainRotor", HUB, Basis.IDENTITY, _rotor_radius(), 2,
		BLADE_CHORD, 0.24, 0.20, BLADE, BLADE_TIP, METAL, paint, 1.0, PI * 0.25)
	# THE BELL STABILISER BAR, across the blades with a weight at each end: what makes a Huey's head a Huey's.
	var bar := RotorcraftKit.tool()
	var across := Vector3(cos(PI * 0.75), 0.0, -sin(PI * 0.75))
	RotorcraftKit.rod(bar, Vector3(0.0, 0.14, 0.0) - across * 1.10, Vector3(0.0, 0.14, 0.0) + across * 1.10, 0.025,
		METAL, 6)
	for end in [-1.0, 1.0]:
		RotorcraftKit.rod(bar, Vector3(0.0, 0.14, 0.0) + across * (end * 0.92), Vector3(0.0, 0.14, 0.0)
			+ across * (end * 1.14), 0.06, DARK, 6)
	RotorcraftKit.part(main_rotor, "MainRotorStabiliserBar", bar, paint)
	var tail_shaft := Basis(Vector3(0.0, 1.0, 0.0), Vector3(-1.0, 0.0, 0.0), Vector3(0.0, 0.0, 1.0))
	tail_rotor = RotorcraftKit.rotor(exterior, "TailRotor", TAIL_HUB, tail_shaft, TAIL_RADIUS, 2, 0.21, 0.09, 0.10,
		BLADE, BLADE_TIP, METAL, paint, 1.0, PI * 0.5)


## THE NATIVE HALF-SPAN IS THE ROTOR'S RADIUS, asked of the simulation rather than typed here.
func _rotor_radius() -> float:
	return float(Sim.geometry_of(Sim.Kind.HELI).get("span", 6.0))


## THE CABIN, nose to tailcone, in one loft: glazed nose and chin, the pilots' door windows, open cargo doors.
func _cabin(paint: Material, glass: Material) -> void:
	var rings: Array = [
		RotorcraftKit.section(-3.02, 0.34, -0.02, 0.56, 0.70, 0.60, 0.25, 0.30),
		RotorcraftKit.section(-2.80, 0.74, -0.28, 1.00, KEEL_WIDE, 0.70),
		RotorcraftKit.section(-2.32, 1.10, -0.40, 1.52, 0.86, 0.78, 0.18),
		RotorcraftKit.section(WINDSCREEN_BASE, CABIN_HALF, KEEL, ROOF, KEEL_WIDE, CROWN, CHINE, SHOULDER),
		RotorcraftKit.section(DOOR_POST, CABIN_HALF, KEEL, ROOF, KEEL_WIDE, CROWN, CHINE, SHOULDER),
		RotorcraftKit.section(BULKHEAD, CABIN_HALF, KEEL, ROOF, KEEL_WIDE, CROWN, CHINE, SHOULDER),
		# THE ROOF RUNS ON NEARLY TO THE BOOM AND STEPS DOWN ONTO IT, and the belly sweeps up under it, as the UH-1H's
		# aft body does [3V].
		RotorcraftKit.section(1.95, 1.00, -0.30, 1.78, 0.80, 0.82),
		RotorcraftKit.section(2.50, 0.52, 0.18, 1.42, 0.70, 0.75),
	]
	var skin := RotorcraftKit.tool()
	var glazing := RotorcraftKit.tool()
	RotorcraftKit.loft(skin, glazing, rings, _cabin_panel)
	RotorcraftKit.part(exterior, "Cabin", skin, paint)
	RotorcraftKit.part(exterior, "CabinGlazing", glazing, glass)


## WHAT EACH CABIN PANEL IS. Spans: 0 nose, 1 windscreen, 2 overhead, 3 pilots' doors, 4 cargo doors, 5 and 6
## tailcone. Facets as `RotorcraftKit.facet_is` names them.
func _cabin_panel(span: int, facet: int) -> Variant:
	var named: StringName = RotorcraftKit.facet_is(facet)
	var side: bool = named == &"lower" or named == &"upper"
	if span < 0:
		return YELLOW
	if named == &"keel":
		return BELLY
	match span:
		0:
			# THE NOSE IS YELLOW with glass in the chin. A black anti-glare panel over it was tried first and from the
			# front it read as a mouth.
			return GLASS if named == &"chine" else YELLOW
		1:
			return GLASS
		2:
			return ROOF_GLASS if named == &"roof" else GLASS
		3:
			return GLASS if side or named == &"shoulder" else YELLOW
		4:
			return null if side else YELLOW
	return BELLY if named == &"chine" else YELLOW


## THE ENGINE AND TRANSMISSION DOGHOUSE on the roof, the mast out of it and the exhaust at its back.
func _doghouse(paint: Material) -> void:
	var house := RotorcraftKit.tool()
	var rings: Array = [
		RotorcraftKit.section(-0.60, 0.30, ROOF - 0.10, 1.96, 0.9, 0.7),
		RotorcraftKit.section(-0.20, 0.54, ROOF - 0.10, 2.24, 0.9, 0.72),
		RotorcraftKit.section(1.60, 0.54, ROOF - 0.10, 2.24, 0.9, 0.72),
		RotorcraftKit.section(2.40, 0.36, 1.40, 2.04, 0.9, 0.70),
	]
	RotorcraftKit.loft(house, house, rings, func(span, facet):
		if span == 3: return DARK
		return BELLY if span == 1 and RotorcraftKit.facet_is(facet) == &"upper" else YELLOW)
	RotorcraftKit.part(exterior, "EngineDoghouse", house, paint)
	var mast := RotorcraftKit.tool()
	RotorcraftKit.rod(mast, Vector3(HUB.x, 2.18, HUB.z), HUB, 0.10, METAL, 6)
	RotorcraftKit.part(exterior, "MainRotorMast", mast, paint)
	var exhaust := RotorcraftKit.tool()
	RotorcraftKit.rod(exhaust, Vector3(0.0, 1.86, 2.20), Vector3(0.0, 2.02, 2.78), 0.17, DARK, 8, 0.15)
	RotorcraftKit.part(exterior, "EngineExhaust", exhaust, paint, true)


## THE TAIL BOOM, the synchronised elevator, the swept fin, the tail rotor gearbox and the tail skid, MEASURED OFF [3V]:
## the public-domain "Bell UH-1H Iroquois 3-view line drawing" on Wikimedia Commons. Its side view gives 41 ft 5 in
## nose to tail over 1,268 px (100.5 px/m), and its plan view gives 99.3 px/m. The user said "the tail boom is not correct
## compared to the real thing" (2026-09-17). Measured, the first boom's TOP DROOPED 0.24 m toward the tail where a
## UH-1's runs level; its root was 0.84 m deep and started too high up the aft body where [3V]'s is 0.85 m and rises
## out of it; the fin and tail rotor stood 0.8 m too low for the cabin (the rotor's hub at the roof's height where
## [3V]'s is 1.32 roofs up); the elevator's chord was 0.40 m against [3V]'s 0.78; and the tail skid hung 0.26 m too low.
##
## HOW [3V] MAPS ONTO THIS MODEL: along the length, x metres aft of [3V]'s nose is z = -3.02 + 0.884 x. This fuselage is
## 11.16 m against the UH-1H's 12.62, because the native 12 m rotor sets the scale. Heights are mapped through the
## CABIN, y = -0.42 + 1.175 (h - 0.47), because the cabin was enlarged upward for VR players and the tail has to sit on
## that cabin rather than on a smaller one. [3V], height over the ground -> here:
##   boom root top 1.91 -> 1.27 (1.30), bottom 1.06 -> 0.27 (0.26); boom at the fin top 1.98 -> 1.35 (1.36), bottom 1.68
##   -> 1.00; elevator 1.78 -> 1.12, at 9.2 to 10.0 m aft -> z 5.11 to 5.80, span 2.85 x 0.884 -> 2.52; tail rotor hub
##   3.11 -> 2.68, 12.32 m aft -> z 7.87; fin top about 3.3 -> 2.91; tail skid tip 1.45 -> 0.72.
## THE TAIL ROTOR IS ON THE PORT SIDE of the fin, as on a UH-1H.
func _boom_and_tail(paint: Material) -> void:
	var boom := RotorcraftKit.tool()
	RotorcraftKit.loft(boom, boom, [
		RotorcraftKit.section(2.40, 0.38, 0.26, 1.30, 0.70, 0.70),
		RotorcraftKit.section(7.72, 0.20, 1.00, 1.36, 0.70, 0.70),
	], func(_s, facet): return BELLY if RotorcraftKit.facet_is(facet) == &"keel" else YELLOW)
	RotorcraftKit.part(exterior, "TailBoom", boom, paint)
	var elevator := RotorcraftKit.tool()
	var outline: Array[Vector3] = [Vector3(-1.26, 1.12, 5.11), Vector3(-1.26, 1.12, 5.80), Vector3(1.26, 1.12, 5.80),
		Vector3(1.26, 1.12, 5.11)]
	RotorcraftKit.plate(elevator, outline, Vector3.UP, 0.08, YELLOW)
	RotorcraftKit.part(exterior, "SynchronisedElevator", elevator, paint)
	var fin := RotorcraftKit.tool()
	var profile: Array[Vector3] = [Vector3(0.0, 1.30, 6.70), Vector3(0.0, 2.95, 7.78), Vector3(0.0, 2.90, 8.14),
		Vector3(0.0, 1.02, 7.72)]
	RotorcraftKit.plate(fin, profile, Vector3.RIGHT, 0.14, YELLOW)
	RotorcraftKit.part(exterior, "TailFin", fin, paint)
	var gearbox := RotorcraftKit.tool()
	RotorcraftKit.box(gearbox, Vector3(-0.05, TAIL_HUB.y, TAIL_HUB.z), Vector3(0.20, 0.26, 0.30), METAL)
	RotorcraftKit.rod(gearbox, Vector3(-0.10, TAIL_HUB.y, TAIL_HUB.z), TAIL_HUB, 0.04, METAL, 6)
	RotorcraftKit.part(exterior, "TailRotorGearbox", gearbox, paint, true)
	var skid := RotorcraftKit.tool()
	RotorcraftKit.rod(skid, Vector3(0.0, 1.06, 7.55), Vector3(0.0, 0.72, 8.10), 0.03, METAL, 6)
	RotorcraftKit.part(exterior, "TailSkid", skid, paint, true)


## TWO SKIDS ON BENT CROSS TUBES, standing on the ground the native box stands on.
func _skids(paint: Material) -> void:
	var low: float = GROUND + 0.05
	for side in [-1.0, 1.0]:
		var tube := RotorcraftKit.tool()
		var points: Array[Vector3] = [Vector3(side * SKID_X, low + 0.28, -2.40), Vector3(side * SKID_X, low + 0.05, -2.10),
			Vector3(side * SKID_X, low, -1.75), Vector3(side * SKID_X, low, 1.55),
			Vector3(side * SKID_X, low + 0.04, 1.78)]
		RotorcraftKit.bent_rod(tube, points, 0.05, METAL, 6)
		RotorcraftKit.part(exterior, "%sSkid" % ("Port" if side < 0.0 else "Starboard"), tube, paint)
	for z in [-1.05, 0.95]:
		var cross := RotorcraftKit.tool()
		var points: Array[Vector3] = [Vector3(-SKID_X, low, z), Vector3(-1.22, -0.64, z), Vector3(-0.90, KEEL + 0.06, z),
			Vector3(0.90, KEEL + 0.06, z), Vector3(1.22, -0.64, z), Vector3(SKID_X, low, z)]
		RotorcraftKit.bent_rod(cross, points, 0.045, METAL, 6)
		RotorcraftKit.part(exterior, "%sCrossTube" % ("Front" if z < 0.0 else "Rear"), cross, paint)


## THE CABIN FLOOR, THE CREW SEATS AND THE REAR BENCH, where the crew can see them.
func _interior(paint: Material) -> void:
	var floor := RotorcraftKit.tool()
	RotorcraftKit.box(floor, Vector3(0.0, -0.265, (WINDSCREEN_BASE + BULKHEAD) * 0.5 - 0.3),
		Vector3(1.70, 0.09, BULKHEAD - WINDSCREEN_BASE + 0.6), BELLY)
	RotorcraftKit.part(interior, "CabinFloor", floor, paint)
	RotorcraftKit.crew_seats(interior, Sim.Kind.HELI, paint, CANVAS, METAL)
	var bench := RotorcraftKit.tool()
	RotorcraftKit.box(bench, Vector3(0.0, 0.20, BULKHEAD - 0.26), Vector3(1.80, 0.08, 0.44), CANVAS)
	RotorcraftKit.box(bench, Vector3(0.0, 0.62, BULKHEAD - 0.06), Vector3(1.80, 0.70, 0.06), CANVAS)
	RotorcraftKit.part(interior, "TroopBench", bench, paint)
