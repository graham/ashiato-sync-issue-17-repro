extends Node
## Headless: does every boat's crew stand in a room that is part of the boat, where its helm really is?
##
##   Godot --headless --path cockpit --fixed-fps 120 res://tests/boat_seats.tscn
##
## Asked for on 2026-09-15: "the pilot seats should be higher and part of the boat as well". Every boat seated its crew on
## the top of a box -- the launch's driver on a hull roof 0.55 m up, the patrol boat's on a roof 1.2 m up, the
## battleship's on its forecastle in the open -- with nothing round them. Each boat is now built from parts in the
## simulation's shape table, a helm is placed with `seat_in` on the floor of a `bridge` part (a carrier's navigation
## bridge, a battleship's pilot house, a patrol boat's wheelhouse, a launch's T-top), a gunner on the floor of a `station`.
##
## WHAT IT HOLDS, for the launch, the patrol boat, the battleship, the carrier and the submarine:
##   - the boat is built from parts, and its seats keep EXACTLY the indices and roles they had, because the crew page, the
##     join path and every gunner's mount are keyed by them;
##   - every pilot and copilot stands on a bridge floor with the eye under its roof, every gunner on a station floor;
##   - no seated head, nor a head's width round the eye, is inside a part the physics calls solid;
##   - its draught, worked out from the parts (`waterline` less the lowest hull bottom), is the one the research gives;
##   - and it floats at that draught: a minute on the swell, the origin within a physical tolerance of the sea.
##
## THE EXPECTATIONS ARE TYPED HERE ON PURPOSE, from the fact sheets (research-boats.md, research.md): the shape table is
## the one place the boats are built, and this is the independent statement they are checked against.
##
## Read RESULT=, not the exit code.

const TICK: float = 1.0 / 120.0
const EYE: float = 1.35
const HEAD: float = 0.25

## Each boat: its kind, the stations its seats must keep in order (with the yaw of each, in radians), its draught from
## the research, and how far its origin may stray from the sea and how far it may lean while floating stopped.
const BOATS: Dictionary = {
	"boat": {"kind": 2, "stations": ["pilot", "copilot", "turret", "turret"], "yaws": [0.0, 0.0, 0.0, PI],
		"draught": 0.40, "float": 0.25, "lean": 12.0},
	"gunboat": {"kind": 9, "stations": ["pilot", "turret", "turret", "copilot"], "yaws": [0.0, 0.0, PI, 0.0],
		"draught": 1.74, "float": 0.4, "lean": 6.0},
	# THE CB90: helm and weapons officer side by side, and a gunner over each after quarter (lane/boats, 2026-09-18).
	"cb90": {"kind": Sim.Kind.CB90, "stations": ["pilot", "copilot", "turret", "turret"], "yaws": [0.0, 0.0, PI * 0.75, -PI * 0.75],
		"draught": 0.80, "float": 0.4, "lean": 6.0},
	"battleship": {"kind": 13, "stations": ["pilot", "copilot", "turret", "turret"], "yaws": [0.0, 0.0, 0.0, PI],
		"draught": 11.33, "float": 0.6, "lean": 2.0},
	# THE PORT-QUARTER TUB'S SEAT WENT TO THE FLAG PLOT on 2026-09-17, so the fourth station is an
	# operator and not a second gunner. Its YAW is unchanged -- the gunner faced aft and so does the
	# operator, who looks out over the landing area past the plot table.
	"carrier": {"kind": 12, "stations": ["pilot", "copilot", "turret", "operator"], "yaws": [0.0, 0.0, 0.0, PI],
		"draught": 11.9, "float": 0.6, "lean": 2.0},
	# A VIRGINIA-CLASS SUBMARINE, conned from a well in its sail: 29 ft of draught, between the published 32 ft and the 28 ft
	# of a surfaced photograph (research-submarine.md, godotgames-drafts/2026-09-15/cockpit-fleet). A round hull is tender:
	# if it leans past this, the fix is its `righting`, not the tolerance.
	"submarine": {"kind": 20, "stations": ["pilot", "copilot"], "yaws": [0.0, 0.0],
		"draught": 8.84, "float": 0.6, "lean": 2.0},
}

var _failures: PackedStringArray = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[boat_seats] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	for boat in BOATS:
		var want: Dictionary = BOATS[boat]
		var geometry: Dictionary = Sim.geometry_of(int(want["kind"]))
		var parts: Array = geometry.get("parts", []) as Array
		_check("the_%s_is_built_from_parts" % boat, not parts.is_empty(), "%d parts" % parts.size())
		if parts.is_empty():
			continue
		_the_seats_keep_their_roles(boat, want, geometry)
		_the_crew_stand_in_their_rooms(boat, geometry, parts)
		_the_draught(boat, want, geometry, parts)
		await _it_floats(boat, want)
	_finish()


func _the_seats_keep_their_roles(boat: String, want: Dictionary, geometry: Dictionary) -> void:
	var poses: Array = geometry.get("seat_poses", []) as Array
	var got: Array[String] = []
	var wrong: Array[String] = []
	for seat in range(poses.size()):
		got.append(String(poses[seat]["station"]))
		if seat < (want["yaws"] as Array).size() \
				and absf(angle_difference(float(poses[seat]["yaw"]), float(want["yaws"][seat]))) > 0.01:
			wrong.append("seat %d faces %.2f" % [seat, float(poses[seat]["yaw"])])
	_check("the_%s_seats_keep_their_order_roles_and_facing" % boat, got == Array(want["stations"]) and wrong.is_empty(),
		"%s%s" % [got, "" if wrong.is_empty() else " %s" % [wrong]])


func _the_crew_stand_in_their_rooms(boat: String, geometry: Dictionary, parts: Array) -> void:
	var outside: Array[String] = []
	var in_solid: Array[String] = []
	var poses: Array = geometry.get("seat_poses", []) as Array
	for seat in range(poses.size()):
		var at: Vector3 = poses[seat]["position"]
		var station: String = String(poses[seat]["station"])
		var room: String = "station" if station == "turret" else "bridge"
		var stands: bool = false
		for part in parts:
			if String(part["part"]) != room or not Geometry2D.is_point_in_polygon(Vector2(at.x, at.z), part["outline"]):
				continue
			if absf(at.y - float(part["bottom"])) < 0.01 and (room == "station" or at.y + EYE < float(part["top"])):
				stands = true
		if not stands:
			outside.append("seat %d (%s) at %s" % [seat, station, at])
		var eye: Vector3 = at + Vector3(0.0, EYE, 0.0)
		for offset in [Vector3.ZERO, Vector3.RIGHT * HEAD, Vector3.LEFT * HEAD, Vector3.UP * HEAD, Vector3.DOWN * HEAD,
				Vector3.FORWARD * HEAD, Vector3.BACK * HEAD]:
			var p: Vector3 = eye + offset
			for part in parts:
				if bool(part.get("solid", false)) and p.y > float(part["bottom"]) and p.y < float(part["top"]) \
						and Geometry2D.is_point_in_polygon(Vector2(p.x, p.z), part["outline"]):
					in_solid.append("seat %d's head at %s is in the %s" % [seat, p, part["part"]])
	_check("every_%s_helm_is_on_its_bridge_and_every_gunner_in_a_tub" % boat, outside.is_empty(),
		"%s" % ["all seats in their rooms" if outside.is_empty() else outside])
	_check("and_no_%s_head_is_inside_anything_solid" % boat, in_solid.is_empty(),
		"%s" % ["clear" if in_solid.is_empty() else in_solid])


## THE DRAUGHT FROM THE PARTS: `waterline` less the lowest bottom of a hull part -- the formula cockpit-terrain spawns ships by.
func _the_draught(boat: String, want: Dictionary, geometry: Dictionary, parts: Array) -> void:
	var lowest: float = INF
	for part in parts:
		if String(part["part"]) == "hull":
			lowest = minf(lowest, float(part["bottom"]))
	var draught: float = float(geometry.get("waterline", 0.625)) - lowest
	_check("the_%s_draws_what_the_research_says" % boat, absf(draught - float(want["draught"])) < 0.05,
		"%.2f m against %.2f" % [draught, float(want["draught"])])


## A MINUTE STOPPED ON THE SWELL: the origin, on the design waterline, stays within `float` of the sea on average and the
## hull leans no more than `lean` degrees. A hull whose waterline were typed apart from its parts, or whose probes pushed
## on air, would ride high or low by more than that.
func _it_floats(boat: String, want: Dictionary) -> void:
	var world: Object = ClassDB.instantiate("CockpitWorld")
	world.set_tick_rate(120.0)
	world.start(0)
	var ship: int = int(world.spawn_vehicle(int(want["kind"]), Vector3(500.0, 1.0, 500.0), 0.0, Vector3.ZERO))
	var heights: Array[float] = []
	var worst: float = 0.0
	for i in range(int(60.0 / TICK)):
		world.tick(TICK)
		if i >= int(20.0 / TICK) and i % 30 == 0:
			var state: Dictionary = world.vehicle_state(ship)
			heights.append(float((state["position"] as Vector3).y))
			worst = maxf(worst, rad_to_deg(Basis(state["basis"] as Quaternion).y.angle_to(Vector3.UP)))
	var mean: float = 0.0
	for h in heights:
		mean += h
	mean /= maxf(float(heights.size()), 1.0)
	_check("the_%s_floats_at_its_waterline" % boat, absf(mean) < float(want["float"]),
		"its origin %.2f m from the sea on average, over %d samples" % [mean, heights.size()])
	_check("and_the_%s_stays_upright" % boat, worst < float(want["lean"]),
		"%.2f degrees off level at the worst, against %.0f" % [worst, float(want["lean"])])
	world.teardown()
	if not (world is RefCounted):
		world.free()


func _finish() -> void:
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit()
