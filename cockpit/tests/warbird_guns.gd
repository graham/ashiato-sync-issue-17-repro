extends Node
## Headless: A WARBIRD'S GUNS FIRE FROM THE MUZZLES ITS MODEL DRAWS (lane/warbirds2): the brief's "the P-51's six .50s ... at
## their drawn muzzles".
##
##   Godot --headless --path cockpit res://tests/warbird_guns.tscn
##
## Parked on its wheels with the master arm made through the bus and the trigger held through the pilot's frame, each kind's
## battery (`Gun::battery`) is held, round by round, to its airframe's drawn `muzzles()` in the craft's frame:
## - EVERY ROUND is born within a centimetre of one of the drawn muzzles, and every drawn muzzle fires;
## - each leaves at the gun's muzzle speed, BORE-SIGHTED IN: its line crosses the craft's centreline at the harmonised range;
## - the battery fires at its published rate.
## Read RESULT=, not the exit code.

const TICK: float = 1.0 / 120.0
const CLIENT: int = 60
## How near a parked round's birth must be to a drawn muzzle, metres (the A-10's check, `warthog_seat.gd`).
const PARKED_MUZZLE: float = 0.01
## THE BATTERIES, a kind each: the rate (rounds a second, all the guns), the muzzle speed and the harmonised range.
## - P-51D: six Browning AN/M2s at about 800 a minute each, 870 m/s, harmonised at 300 yards (`loadout_of`).
const BATTERIES: Dictionary = {
	"p51": {"per_second": 6.0 * 800.0 / 60.0, "muzzle": 870.0, "converge": 274.0},
	# - P-47D-30: EIGHT of the same guns, the heaviest weight of fire of any craft here bar the A-10's cannon.
	"p47": {"per_second": 8.0 * 800.0 / 60.0, "muzzle": 870.0, "converge": 274.0},
}

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	if not ClassDB.class_exists("CockpitWorld"):
		_check("extension_loaded", false, "no CockpitWorld")
		_finish()
		return
	for kind in Sim.Kind.values():
		var name: String = Sim.kind_name(kind)
		if BATTERIES.has(name):
			_fire(kind, name, BATTERIES[name])
	_finish()


func _fire(kind: int, name: String, battery: Dictionary) -> void:
	var world: Object = ClassDB.instantiate("CockpitWorld")
	world.set_tick_rate(120.0)
	world.start(0)
	world.add_static_box(Vector3(0.0, -400.0, 0.0), Vector3(40000.0, 400.0, 40000.0))
	var hy: float = float((Sim.geometry_of(kind).get("extents", Vector3.ONE) as Vector3).y)
	var made: Dictionary = world.spawn_pilot(CLIENT, kind, Vector3(0.0, hy + 0.05, 0.0), 0.0, Vector3.ZERO)
	var craft: int = int(made.get("vehicle", 0))
	var pilot: int = int(made.get("pilot", 0))
	var input: Dictionary = {"throttle": 0.0, "pitch": 0.0, "roll": 0.0, "rudder": 0.0, "brake": 1.0, "trigger": 0.0}
	for i in range(240):
		world.set_pilot_input(pilot, input)
		world.tick(TICK)
	# MASTER ARM, as the switch sends it: a bus command.
	input["command_channel"] = Sim.Channel.MASTER
	input["command_value"] = 1
	input["command_seq"] = 1
	for i in range(30):
		world.set_pilot_input(pilot, input)
		world.tick(TICK)
	# THE LINES ARE MEASURED DEAD TRUE, AND SCATTER IS NOT BROKEN HERE: the .50s scatter 3 mrad (held by
	# `tests/gun_scatter.gd`), a metre at the crossing range, and it is where the six lines cross that is asked about.
	world.set_gun_scatter_scale(0.0)
	var frame: WarbirdAirframe = VehicleView.warbird_for(kind)
	add_child(frame)
	frame.dress()
	var muzzles: Array = frame.muzzles()
	frame.queue_free()
	var seen: Dictionary = {}
	for row in world.shot_states():
		seen[int((row as Dictionary).get("entity", 0))] = true
	var born: int = 0
	var worst: float = 0.0
	var used: Dictionary = {}
	var worst_cross: float = 0.0
	var slowest: float = INF
	var fastest: float = 0.0
	input["trigger"] = 1.0
	for i in range(120):
		world.set_pilot_input(pilot, input)
		world.tick(TICK)
		var state: Dictionary = world.vehicle_state(craft)
		var basis := Basis(state["basis"] as Quaternion)
		var at: Vector3 = state["position"]
		var moving: Vector3 = state.get("velocity", Vector3.ZERO)
		for row in world.shot_states():
			var shot: Dictionary = row
			var entity: int = int(shot.get("entity", 0))
			if seen.has(entity):
				continue
			seen[entity] = true
			born += 1
			var local: Vector3 = basis.inverse() * ((shot["from"] as Vector3) - at)
			var nearest: int = 0
			for m in range(muzzles.size()):
				if local.distance_to(muzzles[m]) < local.distance_to(muzzles[nearest]):
					nearest = m
			used[nearest] = true
			worst = maxf(worst, local.distance_to(muzzles[nearest]))
			var own: Vector3 = basis.inverse() * ((shot["velocity"] as Vector3) - moving)
			slowest = minf(slowest, own.length())
			fastest = maxf(fastest, own.length())
			# WHERE ITS LINE CROSSES THE CENTRELINE, metres ahead of the muzzle: straight ahead is -Z.
			if absf(own.x) > 1e-4:
				var ahead: float = -local.x / own.x * -own.z
				worst_cross = maxf(worst_cross, absf(ahead - float(battery["converge"])))
	world.teardown()
	_check("%s_every_round_is_born_at_a_drawn_muzzle" % name, born > 0 and worst <= PARKED_MUZZLE,
		"%d rounds in a second, the worst born %.4f m from its drawn muzzle (within %.2f)" % [born, worst, PARKED_MUZZLE])
	_check("%s_every_drawn_muzzle_fires" % name, used.size() == muzzles.size(),
		"%d of the %d drawn muzzles fired" % [used.size(), muzzles.size()])
	# WITHIN 5 PER CENT OF THE RANGE: a round's birth goes through the wire's quantiser, and its velocity's quantum, 0.25 m/s,
	# is 3 per cent of the 7.6 m/s across that an outboard gun's 0.5 degrees of toe-in gives it (3.5 m at 274, measured).
	_check("%s_its_guns_are_harmonised_to_cross_at_their_range" % name,
		born > 0 and worst_cross < float(battery["converge"]) * 0.05,
		"every line crosses the centreline within %.2f m of %.0f m ahead" % [worst_cross, battery["converge"]])
	_check("%s_leaves_at_its_muzzle_speed" % name, born > 0 and absf(slowest - float(battery["muzzle"])) <= 1.0
		and absf(fastest - float(battery["muzzle"])) <= 1.0, "%.1f to %.1f m/s against %.0f" % [slowest, fastest,
			battery["muzzle"]])
	_check("%s_fires_at_its_rate" % name, absf(float(born) - float(battery["per_second"])) <= 2.0,
		"%d rounds in 120 ticks, wanted %.0f" % [born, battery["per_second"]])


func _check(name: String, ok: bool, detail: String) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
	print("[warbird_guns] %s %s (%s)" % ["PASS" if ok else "FAIL", name, detail])


func _finish() -> void:
	print("[warbird_guns] %d passed, %d failed" % [_passed, _failed])
	print("RESULT=%s" % ("PASS" if _failed == 0 else "FAIL"))
	get_tree().quit(0 if _failed == 0 else 1)
