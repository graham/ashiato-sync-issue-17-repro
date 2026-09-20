extends Node
## Headless: WHAT A CARRIER UNDER WAY, WITH AEROPLANES PARKED ON ITS DECK, COSTS THE SIMULATION A TICK.
##
##   Godot --headless --path cockpit res://tests/deck_cost_probe.tscn
##
## A PROBE, NOT A SUITE: a microsecond has no right answer on a machine other lanes are timing on. It exists because the
## carrier stopped being one box -- it is fifteen parts now, a compound body of fourteen convex hulls -- and every
## aeroplane standing on it is a contact against those hulls, every tick. It prints the median and worst of 120-tick
## batches for the carrier alone and for the carrier with `PLANES` aeroplanes parked on its deck, and says which
## library it ran on (the parts carrier or the box one, and the library's SHA-256), so the same probe run on main's
## library and on the lane's is the before and after. `carrier-scripts/cost.ps1` interleaves the two.
##
## Prints RESULT=PASS once it has measured, or RESULT=FAIL if an aeroplane fell off the deck while it did.

const TICK: float = 1.0 / 120.0
const CARRIER: int = 12
const PLANE: int = 1
const PLANES: int = 12
const BATCH: int = 120
const BATCHES: int = 20

var _failures: PackedStringArray = []


func _ready() -> void:
	var library: String = "res://addons/ashiato/bin/ashiato_gd.double.dll" if OS.has_feature("double") \
		else "res://addons/ashiato/bin/ashiato_gd.dll"
	var parts: int = (Sim.geometry_of(CARRIER).get("parts", []) as Array).size()
	print("[deck_cost] library %s sha256 %s, carrier of %d parts" % [library.get_file(),
		FileAccess.get_sha256(library).substr(0, 8), parts])
	for planes in [0, PLANES]:
		var world: Object = ClassDB.instantiate("CockpitWorld")
		world.set_tick_rate(120.0)
		world.start(0)
		var made: Dictionary = world.spawn_pilot(80, CARRIER, Vector3.ZERO, 0.0, Vector3.ZERO)
		var ship: int = int(made.get("vehicle", 0))
		var helm: int = int(made.get("pilot", 0))
		for i in range(240):
			world.set_pilot_input(helm, {"throttle": 1.0})
			world.tick(TICK)
		var deck: float = float((Sim.geometry_of(CARRIER).get("extents", Vector3.ONE) as Vector3).y)
		var half: float = float((Sim.geometry_of(PLANE).get("extents", Vector3.ONE) as Vector3).y)
		var parked: Array[int] = []
		var state: Dictionary = world.vehicle_state(ship)
		for i in range(planes):
			var local := Vector3(-10.0 + 10.0 * float(i % 3), deck + half + 0.3, -60.0 + 40.0 * float(i / 3))
			var at: Vector3 = (state["position"] as Vector3) + (state["basis"] as Quaternion) * local
			parked.append(int(world.spawn_vehicle(PLANE, at, 0.0, state["velocity"])))
		var costs: Array[float] = []
		for batch in range(BATCHES):
			var began: int = Time.get_ticks_usec()
			for i in range(BATCH):
				world.set_pilot_input(helm, {"throttle": 1.0})
				world.tick(TICK)
			costs.append(float(Time.get_ticks_usec() - began) / float(BATCH) / 1000.0)
		costs.sort()
		var still: int = 0
		var ship_now: Dictionary = world.vehicle_state(ship)
		for plane in parked:
			var up: float = ((world.vehicle_state(plane)["position"] as Vector3) - (ship_now["position"] as Vector3)).y
			if up > deck - 2.0:
				still += 1
		print("[deck_cost] carrier with %d aeroplanes: median %.3f ms a tick, worst batch %.3f, best %.3f; %d still on deck"
			% [planes, costs[costs.size() / 2], costs[costs.size() - 1], costs[0], still])
		if still != planes:
			_failures.append("aeroplanes_left_the_deck")
		world.teardown()
		if not (world is RefCounted):
			world.free()
	print("RESULT=%s" % ("PASS" if _failures.is_empty() else "FAIL %s" % ", ".join(_failures)))
	get_tree().quit()
